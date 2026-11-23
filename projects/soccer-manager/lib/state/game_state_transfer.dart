part of 'game_state.dart';

/// 移籍市場・契約交渉・スカウト・ユース・フリーエージェント・受信オファー・国際試合。
extension GameStateTransfer on GameState {
  Future<bool> buyPlayer(String playerId) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    if (!isTransferWindowOpen) return false;
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final player = target.player;
    if (!_minorRuleAllows(player)) return false;
    final fee = TransferTermsEngine.agentFee(player.marketValue);
    if (_save!.budget < player.marketValue + fee) return false;
    if (!_registrationAllows(player)) return false;
    final wageHere = (player.wage *
            (target.club == null
                ? 1.0
                : wageScaleToHome(_foreignTeamIds()[target.club!.id])))
        .round();
    if (!_wageBudgetAllowsSigning(wageHere, fee: player.marketValue)) {
      return false;
    }
    _convertArrivingWage(target);
    _payTransferFee(player.marketValue);
    _bookAgentFee(player, fee);
    ContractEngine.applyTransferContract(player);
    _recordPlayerBook(player, player.marketValue,
        announce: false, agentFee: fee);
    _takeFromSeller(target);
    _supportersOnSigning(player);
    userTeam.players.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// 18歳未満の国際移籍の禁止に当たらないか。当たれば理由を
  /// [lastSigningBlockReason]に入れる。
  bool _minorRuleAllows(Player player) {
    if (!_isInternationalMinor(player)) return true;
    lastSigningBlockReason = Tr.pick(
        '18歳未満の選手は国をまたいで移籍できません(EU の中の16〜17歳は除く)。',
        'Players under 18 cannot move between countries (16 and 17-year-olds may move within the EU).');
    _notify();
    return false;
  }

  /// 登録の決まり([SquadRegistration])で加えられるか。加えられないときは
  /// 理由を[lastSigningBlockReason]に入れる(押しても何も起きない状態にしない)。
  bool _registrationAllows(Player player) {
    // アルビオン式のリーグでは、外国籍の選手に労働許可が要る。
    final reason = registrationBlockFor(player) ?? workPermitBlock(player);
    if (reason == null) return true;
    lastSigningBlockReason = reason;
    _notify();
    return false;
  }

  /// 代理人手数料を払う。移籍金と同じく資産になる支払い(資金はいま減り、
  /// 損益には償却で入る)。呼び出し元は、同じ額を [_recordPlayerBook] の
  /// agentFee に渡して簿価に足すこと(2026-11-22。以前はその季の費用)。
  void _bookAgentFee(Player player, int fee) {
    if (fee <= 0) return;
    _payTransferFee(fee);
    _logNews(
        Tr.pick('${player.name}の代理人に手数料${formatMoney(fee)}を支払った。',
            'Paid ${formatMoney(fee)} in agent fees for ${player.name}.'),
        context: Tr.pick('移籍', 'Transfer'));
  }

  /// 売却条項が付いた選手を売るとき、売却額の一部を元のクラブへ払う。
  void _paySellOn(Player player, int salePrice) {
    final percent = _save!.sellOnClauses.remove(player.id);
    if (percent == null) return;
    final pay = TransferTermsEngine.sellOnPayment(
        salePrice: salePrice, percent: percent);
    if (pay <= 0) return;
    _book(LedgerCategory.transfers, -pay);
    _logNews(
        Tr.pick('${player.name}の売却条項により、元のクラブへ${formatMoney(pay)}を支払った。',
            'Paid ${formatMoney(pay)} to his former club under the sell-on clause for ${player.name}.'),
        context: Tr.pick('移籍', 'Transfer'));
  }

  /// 値切りオファーが受け入れられる確率(0.0〜1.0)。市場価値の満額なら
  /// 必ず成立し、55%以下なら必ず拒否される。UIで交渉前に提示する。
  ///
  /// 選手([player])が分かれば、相手が比べるのは市場価値ではなく、契約の
  /// 残り年数の係数を掛けた相場([TransferValue.worth]。言い値と同じ係数)。
  /// 契約が残り半年なら市場価値の2割で応じ、4年以上残っていれば1割増しを
  /// 求める。他のクラブの先発の選手は安くは手放さない(-15%)。
  double transferOfferAcceptChance(int marketValue, int offer,
      {Player? player}) {
    final worth = player == null
        ? marketValue
        : (marketValue * TransferValue.factorFor(player, seasonProgress))
            .round();
    if (worth <= 0) return 1.0;
    final ratio = offer / worth;
    if (ratio >= 1.0) return 1.0;
    var chance = (ratio - 0.55) / 0.45;
    if (ratio > 0.55 && player != null) {
      final club = _sellingClubOf(player.id);
      if (club != null && club.startingXI.contains(player.id)) chance -= 0.15;
    }
    return chance.clamp(0.0, 1.0);
  }

  /// 今のシーズンがどこまで進んだか(0=開幕前・日程なし、1=全節を終えた)。
  /// 契約の残り(半端な年数)を出すのに使う。冬の窓のころは約0.5。
  double get seasonProgress {
    if (_save == null) return 0;
    final total = _totalMatchdaysThisSeason;
    if (total == 0) return 0;
    return ((total - remainingMatchdaysThisSeason) / total).clamp(0.0, 1.0);
  }

  /// [p]の契約の残り(年。今のシーズンの進みを引いた半端な年数)。
  double contractYearsLeftOf(Player p) =>
      TransferValue.yearsLeft(p.contractYearsRemaining, seasonProgress);

  /// 監督が補強の案に挙げられる選手(ある程度見えている選手だけ)。
  List<Player> get proposalTargets {
    final same = sameLeaguePlayerIds();
    return [
      for (final p in transferTargets)
        if (knowledgeOf(p, sameLeagueIds: same) >=
            ScoutKnowledge.proposalMinimum)
          p,
    ];
  }

  /// 他のクラブが手放せる最少の人数。これを割るなら売らない。
  static const int minSquadToSell = 18;

  /// 獲得を申し込める他のクラブの選手(自国の全部と、他の4か国の1部)。
  /// 借りている・貸している選手、ほかのクラブと仮契約を結んだ選手、
  /// 国をまたげない18歳未満は出さない。人数が少ないクラブは売らない。
  List<Player> get transferTargets {
    if (_save == null) return const [];
    final foreign = _foreignTeamIds();
    final home = currentLeagueTheme.name;
    final taken = {for (final c in preContracts) c.playerId};
    return [
      ...transferMarket,
      for (final t in _worldTeams)
        if (t.id != _save!.userTeamId && t.players.length > minSquadToSell)
          for (final p in t.players)
            if (_isTransferTarget(p, taken) &&
                !(p.age < 18 &&
                    (foreign[t.id] ?? home) != home &&
                    _minorBlockedFromClub(p, t.id)))
              p,
    ];
  }

  /// 他の国のクラブの名前から、その国を引く(自国のクラブなら null)。
  LeagueTheme? _foreignLeagueOfClubName(String clubName) {
    for (final e in _save!.foreignLeagues.entries) {
      if (e.value.teams.any((t) => t.name == clubName)) {
        return LeagueTheme.values.where((t) => t.name == e.key).firstOrNull;
      }
    }
    return null;
  }

  /// 他の国のクラブの id → その国([LeagueTheme]の name)。
  Map<String, String> _foreignTeamIds() => {
        for (final e in _save!.foreignLeagues.entries)
          for (final t in e.value.teams) t.id: e.key,
      };

  bool _isTransferTarget(Player p, Set<String> preContracted) =>
      !p.isLoan && !p.isLoanedOut && !preContracted.contains(p.id);

  /// [playerId]の選手が今いる他のクラブ(自クラブ・作り物の市場なら null)。
  Team? _sellingClubOf(String playerId) {
    if (_save == null) return null;
    for (final t in _worldTeams) {
      if (t.id == _save!.userTeamId) continue;
      if (t.players.any((p) => p.id == playerId)) return t;
    }
    return null;
  }

  /// 画面に出す、その選手の所属クラブの名前。
  String? clubNameOf(String playerId) =>
      _sellingClubOf(playerId)?.name ??
      transferMarket
          .where((p) => p.id == playerId)
          .map((p) => p.originClubName)
          .firstOrNull;

  /// 獲得の相手。作り物の市場(テスト・旧セーブの名残)にいればそこ、
  /// いなければ他のクラブの選手から探す。申し込めない選手なら null。
  ({Player player, Team? club})? _acquisitionTarget(String playerId) {
    final i = transferMarket.indexWhere((p) => p.id == playerId);
    if (i >= 0) return (player: transferMarket[i], club: null);
    final club = _sellingClubOf(playerId);
    if (club == null || club.players.length <= minSquadToSell) return null;
    final player = club.players.firstWhere((p) => p.id == playerId);
    final taken = {for (final c in preContracts) c.playerId};
    if (!_isTransferTarget(player, taken)) return null;
    // 18歳未満の国際移籍の判定と、画面の「元の所属」に使う。
    player.originClubName = club.name;
    player.originLeague = _foreignTeamIds()[club.id] ?? currentLeagueTheme.name;
    return (player: player, club: club);
  }

  /// 他国のクラブから買う選手の週俸を、こちらの国の水準に直す
  /// ([wageScaleToHome]。交渉を経ずに買う道で使う)。同じ国なら変えない。
  void _convertArrivingWage(({Player player, Team? club}) target) {
    final club = target.club;
    if (club == null) return;
    final scale = wageScaleToHome(_foreignTeamIds()[club.id]);
    if (scale == 1.0) return;
    final p = target.player;
    p.wage = max(minWeeklyWage, (p.wage * scale).round());
  }

  /// 獲得した選手を、元のクラブ(または作り物の市場)から外す。
  /// [toUser]は自クラブが取るとき true(他のクラブが横取りしたときは false)。
  void _takeFromSeller(({Player player, Team? club}) target,
      {bool toUser = true}) {
    final p = target.player;
    final club = target.club;
    // イタリアの「EU 外の選手は1季に2人まで」を数える(国籍を覚える前に)。
    if (toUser) _noteSigningFromAbroad(p);
    // 国をまたいで移ることがあるので、先に国籍を覚えさせる。
    _fixNationality(p);
    if (club == null) {
      transferMarket.removeWhere((q) => q.id == p.id);
      return;
    }
    club.players.remove(p);
    club.startingXI.remove(p.id);
    if (club.captainId == p.id) club.captainId = null;
    if (club.viceCaptainId == p.id) club.viceCaptainId = null;
    if (club.penaltyTakerId == p.id) club.penaltyTakerId = null;
    if (club.freeKickTakerId == p.id) club.freeKickTakerId = null;
    if (club.cornerTakerId == p.id) club.cornerTakerId = null;
    if (club.manMarkerId == p.id) club.manMarkerId = null;
    if (club.setPieceDefenderId == p.id) club.setPieceDefenderId = null;
    LineupUtils.fillVacancies(club);
  }

  /// 他のクラブから借りていた選手を、ローンの終わりに元のクラブへ戻す。
  void _returnLoanToParent(Player p) {
    final id = p.loanFromClubId;
    if (id == null) return;
    p.isLoan = false;
    p.loanEndDate = null;
    p.loanBuyOptionFee = null;
    if (p.loanBaseWage != null) p.wage = p.loanBaseWage!;
    p.loanFromClubId = null;
    p.loanBaseWage = null;
    final club = _worldTeams.where((t) => t.id == id).firstOrNull;
    if (club == null || club.id == _save!.userTeamId) return;
    club.players.add(p);
    _logNews(
      Tr.pick('${p.name}のローンが終わり、${club.name}へ戻りました。',
          '${p.name}\'s loan is over and he has gone back to ${club.name}.'),
      context: Tr.pick('ローン', 'Loan'),
    );
  }

  // ---- スカウト(どれだけ見えているか) ----

  /// スカウトを送れる地域(自国の各部と、他の国の1部)。
  List<({String key, String label, List<Team> teams})> get scoutRegions {
    if (_save == null) return const [];
    final s = _save!;
    final home = currentLeagueTheme;
    return [
      for (var tier = 1; tier <= s.otherDivisionLeagues.length; tier++)
        (
          key: 'home:$tier',
          label: Tr.pick('${home.label} $tier部', '${home.label} Tier $tier'),
          teams: tier == s.currentDivisionTier
              ? s.league.teams
              : s.otherDivisionLeagues[tier - 1]?.teams ?? const <Team>[],
        ),
      for (final e in s.foreignLeagues.entries)
        (
          key: 'foreign:${e.key}',
          label: Tr.pick(
              '${LeagueTheme.values.firstWhere((t) => t.name == e.key, orElse: () => home).label} 1部',
              '${LeagueTheme.values.firstWhere((t) => t.name == e.key, orElse: () => home).label} top flight'),
          teams: e.value.teams,
        ),
    ];
  }

  /// 同じ部の他のクラブの選手(試合で見ているので最初から見えている)。
  Set<String> sameLeaguePlayerIds() => _save == null
      ? const {}
      : {
          for (final t in _save!.league.teams)
            if (t.id != _save!.userTeamId)
              for (final p in t.players) p.id,
        };

  /// [p]がどれだけ見えているか(0〜100%)。多くの選手を続けて見るときは
  /// [sameLeagueIds]に[sameLeaguePlayerIds]を渡すと速い。
  int knowledgeOf(Player p, {Set<String>? sameLeagueIds}) {
    if (_save == null) return 0;
    if (userTeam.players.contains(p)) return 100;
    // 作り物の市場(テストが置く)の選手は、報告が揃っている扱い。
    if (transferMarket.contains(p)) return 100;
    final stored = _save!.scoutKnowledge[p.id] ?? 0;
    final same = sameLeagueIds ?? sameLeaguePlayerIds();
    final base = same.contains(p.id) ? ScoutKnowledge.sameLeagueBase : 0;
    return max(stored, base).clamp(0, 100);
  }

  /// 総合力の見立て(幅)。見えていなければ null。
  (int, int)? overallEstimate(Player p, {Set<String>? sameLeagueIds}) =>
      ScoutKnowledge.range(
          p.overall, knowledgeOf(p, sameLeagueIds: sameLeagueIds), p.id, 1);

  /// 伸びしろ(潜在)の見立て(幅)。見えていなければ null。
  (int, int)? potentialEstimate(Player p, {Set<String>? sameLeagueIds}) =>
      ScoutKnowledge.range(
          p.potential, knowledgeOf(p, sameLeagueIds: sameLeagueIds), p.id, 2);

  int get _scoutJudging => _save!.infrastructure
      .staffAttributeLevel(StaffRole.scout, StaffAttribute.judging);

  /// 同時に送れる地域の数(1〜3)。
  int get scoutSlots =>
      _save == null ? 0 : ScoutKnowledge.slotsFor(_scoutJudging);

  /// 1か所あたりの1週の出張費。
  int get scoutTripCostPerWeek => _save == null
      ? 0
      : ScoutKnowledge.weeklyTripCost(_save!.currentDivisionTier);

  /// 送った地域で1週に見えてくる量(%)。
  int get scoutWeeklyGain =>
      _save == null ? 0 : ScoutKnowledge.weeklyGain(_scoutJudging);

  bool isScoutRegionActive(String key) =>
      _save?.scoutRegionKeys.contains(key) ?? false;

  /// 地域にスカウトを送る・引き上げる。送れる数を超えるなら送らない(false)。
  Future<bool> toggleScoutRegion(String key) async {
    if (_save == null) return false;
    final keys = _save!.scoutRegionKeys;
    if (!keys.remove(key)) {
      if (keys.length >= scoutSlots) return false;
      if (!scoutRegions.any((r) => r.key == key)) return false;
      keys.add(key);
    }
    _notify();
    await _persist();
    return true;
  }

  /// 地域の選手が平均でどれだけ見えているか(%)。
  int regionKnowledgePercent(String key) {
    final region = scoutRegions.where((r) => r.key == key).firstOrNull;
    if (region == null) return 0;
    final same = sameLeaguePlayerIds();
    var sum = 0;
    var n = 0;
    for (final t in region.teams) {
      if (t.id == _save!.userTeamId) continue;
      for (final p in t.players) {
        sum += knowledgeOf(p, sameLeagueIds: same);
        n++;
      }
    }
    return n == 0 ? 0 : (sum / n).round();
  }

  /// 日付が進んだぶん、送った地域と注目の選手が見えてくる。出張費を払う。
  void _advanceScouting(DateTime before, DateTime after) {
    if (_save == null) return;
    final days = TransferWindowCalendar.daysBetween(before, after);
    if (days <= 0) return;
    final weeks = days / 7;
    final k = _save!.scoutKnowledge;
    final same = sameLeaguePlayerIds();
    void raise(String id, int gain) {
      final base = same.contains(id) ? ScoutKnowledge.sameLeagueBase : 0;
      k[id] = min(100, max(k[id] ?? 0, base) + gain);
    }

    final regions = {for (final r in scoutRegions) r.key: r};
    final active = _save!.scoutRegionKeys.where(regions.containsKey).toList();
    final gain = (scoutWeeklyGain * weeks).round();
    if (active.isNotEmpty && gain > 0) {
      for (final key in active) {
        for (final t in regions[key]!.teams) {
          if (t.id == _save!.userTeamId) continue;
          for (final p in t.players) {
            raise(p.id, gain);
          }
        }
      }
      final cost = (scoutTripCostPerWeek * active.length * weeks).round();
      if (cost > 0) _book(LedgerCategory.facilities, -cost);
    }
    final watchGain = (ScoutKnowledge.watchWeeklyGain * weeks).round();
    if (watchGain > 0) {
      final mine = {for (final p in userTeam.players) p.id};
      for (final id in _save!.watchlistPlayerIds) {
        if (!mine.contains(id)) raise(id, watchGain);
      }
    }
  }

  /// もういない選手(引退・作り直し)の見え方を捨てる。7月1日に呼ぶ。
  void _pruneScoutKnowledge() {
    final k = _save!.scoutKnowledge;
    if (k.isEmpty) return;
    final alive = {for (final p in _save!.allPlayers) p.id};
    k.removeWhere((id, _) => !alive.contains(id));
  }

  /// 市場の選手に移籍金[offer](万円)の値切りオファーを出す。成立すれば
  /// その額で獲得し、拒否されればこの週は同じ選手に再交渉できない。
  /// attempted=false は交渉自体が行えなかった場合(移籍ウィンドウ外・
  /// 資金不足・スカッド満員・今週拒否済みなど)。
  Future<({bool attempted, bool accepted})> makeTransferOffer(
    String playerId,
    int offer,
  ) async {
    if (_save == null || !isTransferWindowOpen) {
      return (attempted: false, accepted: false);
    }
    if (transferOffersRejectedThisWeek.contains(playerId)) {
      return (attempted: false, accepted: false);
    }
    final target = _acquisitionTarget(playerId);
    if (target == null) return (attempted: false, accepted: false);
    final player = target.player;
    lastSigningBlockReason = null;
    if (!_minorRuleAllows(player)) return (attempted: false, accepted: false);
    if (offer <= 0 ||
        _save!.budget < offer + TransferTermsEngine.agentFee(offer)) {
      return (attempted: false, accepted: false);
    }
    lastSigningBlockReason = null;
    if (!_registrationAllows(player)) {
      return (attempted: false, accepted: false);
    }
    if (!_wageBudgetAllowsSigning(player.wage, fee: offer)) {
      return (attempted: false, accepted: false);
    }
    final chance =
        transferOfferAcceptChance(player.marketValue, offer, player: player);
    final accepted = GameState._transferOfferRng.nextDouble() < chance;
    if (!accepted) {
      transferOffersRejectedThisWeek.add(playerId);
      _notify();
      return (attempted: true, accepted: false);
    }
    _convertArrivingWage(target);
    _payTransferFee(offer);
    final agentFee = TransferTermsEngine.agentFee(offer);
    _bookAgentFee(player, agentFee);
    final clause = TransferTermsEngine.sellOnPercent(
        offer: offer, marketValue: player.marketValue);
    if (clause > 0) {
      _save!.sellOnClauses[player.id] = clause;
      _logNews(
          Tr.pick('${player.name}の獲得で、売り手に売却条項($clause%)を約束した。',
              'To land ${player.name} we agreed a $clause% sell-on clause with the seller.'),
          context: Tr.pick('移籍', 'Transfer'));
    }
    ContractEngine.applyTransferContract(player);
    _recordPlayerBook(player, offer, announce: false, agentFee: agentFee);
    _takeFromSeller(target);
    _supportersOnSigning(player);
    userTeam.players.add(player);
    if (offer < player.marketValue) {
      _save!.negotiationSignings++;
      _evaluateAchievements();
    }
    _notify();
    await _persist();
    return (attempted: true, accepted: true);
  }

  /// 選手がチームを離れる際、キャプテンやセットプレー担当など個別の役割
  /// 指名にその選手のIDが残ったままにならないよう解除する。あわせて、
  /// その選手を対象にした契約交渉・分割払い残金が進行中であれば破棄する。
  void _clearPlayerRoleReferences(Team team, String playerId) {
    if (team.captainId == playerId) team.captainId = null;
    if (team.viceCaptainId == playerId) team.viceCaptainId = null;
    if (team.penaltyTakerId == playerId) team.penaltyTakerId = null;
    if (team.freeKickTakerId == playerId) team.freeKickTakerId = null;
    if (team.cornerTakerId == playerId) team.cornerTakerId = null;
    if (team.manMarkerId == playerId) team.manMarkerId = null;
    if (team.setPieceDefenderId == playerId) team.setPieceDefenderId = null;
    if (_save?.pendingContractNegotiation?.playerId == playerId) {
      _save!.pendingContractNegotiation = null;
    }
    // 7月1日より前に出ていった(売った・解除した)選手の仮契約は無くなる。
    _save?.preContracts
        .removeWhere((c) => c.playerId == playerId && c.fromClubId == team.id);
    // 自クラブから抜けた選手の、監督の更新の提案は消す(残すと承認したとき
    // 更新する相手がいない)。
    if (team.id == _save?.userTeamId) {
      _save!.proposals.removeWhere(
          (p) => p.kind == ProposalKind.renew && p.playerId == playerId);
    }
    _settleInstallmentsFor(playerId);
  }

  /// 手放した選手の分割払いが残っていれば、その場で残金を精算する。
  ///
  /// 以前は残金を破棄していた。そのため「分割で買って(頭金30%)すぐ売る
  /// (市場価値の70%)」を繰り返すだけで資金が増えた。実測で1回あたり
  /// 市場価値の21%が手元に残り、市場の選手全員に対して何度でもできた。
  /// 資金のやりくりという土台が無くなるうえ、資金パックを買う理由も消える。
  ///
  /// 売った相手が誰であれ、買ったときの残金は元のクラブに支払う。
  void _settleInstallmentsFor(String playerId) {
    if (_save == null) return;
    final rows = _save!.pendingInstallments
        .where((i) => i.playerId == playerId)
        .toList();
    if (rows.isEmpty) return;
    final outstanding = rows.fold<int>(0, (sum, i) => sum + i.outstanding);
    _save!.pendingInstallments.removeWhere((i) => i.playerId == playerId);
    if (outstanding <= 0) return;
    for (final i in rows) {
      _payInstallment(i, i.outstanding);
    }
    _logNews(Tr.pick('移籍に伴い、分割払いの残金${formatMoney(outstanding)}を一括で精算した。',
        'The remaining ${formatMoney(outstanding)} of the instalment plan was settled in full on his departure.'));
  }

  /// 売りに出したときの移籍金の相場(市場価値×契約の残り年数の係数)。
  /// 実際の額は届くオファーごとにばらつく。売却では契約を買い手が引き継ぐ
  /// ので、売り手は残りの年俸の違約金を払わない(払うのは合意解除のときだけ)。
  int netReleaseValueFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.salePrice(player, seasonProgress: seasonProgress);
  }

  /// クラブニュース履歴に1件追加する(先頭が最新)。SnackBarやダイアログで
  /// 一度だけ流れる通知を、ニュース画面で後から見返せるようにする記録。
  void _logNews(String text, {String? context}) {
    if (_save == null || text.isEmpty) return;
    _save!.newsTotal++;
    _save!.newsLog.insert(
      0,
      NewsItem(
        season: _save!.league.season,
        context: context ??
            Tr.pick('第$_currentLeagueMatchdayMarker節',
                'Matchday $_currentLeagueMatchdayMarker'),
        text: text,
      ),
    );
    if (_save!.newsLog.length > GameState.newsLogLimit) {
      _save!.newsLog.removeRange(GameState.newsLogLimit, _save!.newsLog.length);
    }
  }

  // 2026-11-23: その場で売れる sellPlayer をやめた。買い手の有無を見ずに
  // 相場の7割で即成立し、行き先は同じリーグの CPU だけだった。いまは
  // 移籍リストに載せ([setTransferListed])、他の部・他の国を含む買い手から
  // 届いたオファー([_offerFor])を受ける([acceptIncomingOffer])形だけにした。

  /// CPU のクラブ[t]が、今の窓の補強に使える資金(万円)。資金の分かる
  /// 自国のクラブは手元の資金の6割、分からないクラブ(他の国・まだ季を
  /// 締めていない)は年俸総額から見積もる([AiTransferEngine.defaultBudget])。
  int _aiTransferBudget(Team t) {
    final cash = _save!.clubCash[t.id];
    if (cash == null) return AiTransferEngine.defaultBudget(t);
    return cash <= 0 ? 0 : (cash * 0.6).round();
  }

  /// 移籍金のやり取りを、資金の分かるクラブ(自国)の手元に入れる。
  void _moveAiClubCash(Team t, int delta) {
    final s = _save!;
    final isHome = s.allTeams.any((x) => x.id == t.id);
    if (!isHome) return;
    final cash = s.clubCash[t.id] ??
        (ContractEngine.weeklyWageBill(t) * 52 / 0.6 * 0.5).round();
    s.clubCash[t.id] = cash + delta;
  }

  /// 1週に、リーグのニュースに出す CPU どうしの移籍の上限(多すぎると
  /// 自クラブの出来事が流れてしまう)。
  static const int aiTransferHeadlinesPerWeek = 3;

  /// 窓の1週ぶんの CPU どうしの移籍を動かす。移籍金は両クラブの資金に
  /// 入れる。返すのは、ニュースに出す主力の移籍の文言。
  List<String> _advanceAiTransfers() {
    final s = _save!;
    final window = currentTransferWindow;
    if (window?.opens != s.aiMovedWindowOpens) {
      s.aiMovedWindowOpens = window?.opens;
      s.aiMovedThisWindow.clear();
    }
    final foreign = _foreignTeamIds();
    final home = currentLeagueTheme;
    final moves = AiTransferEngine.runWeek(
      s.league.teams,
      s.userTeamId,
      GameState._aiTransferRng,
      seasonProgress: seasonProgress,
      budgetOf: _aiTransferBudget,
      // 冬の窓は夏より動きが少ない。
      intensity: window?.kind == TransferWindowKind.winter ? 0.6 : 1.0,
      // 行き先のクラブも国の登録の決まりを守る(同じ国の中の移籍)。
      canRegister: (to, p) =>
          _cpuCanRegister(to, p, fromCountry: home, foreign: foreign),
      recentlyMoved: s.aiMovedThisWindow,
      // 仮契約を結んだ選手は動かさない(動くと 7月1日に元のクラブに
      // いないため、仮契約が黙って消えていた)。
      reserved: {for (final c in s.preContracts) c.playerId},
    );
    if (moves.isEmpty) return const [];
    for (final m in moves) {
      _moveAiClubCash(m.to, -m.fee);
      _moveAiClubCash(m.from, m.fee);
    }
    final headlines = moves.where((m) => m.headline).toList()
      ..sort((a, b) => b.fee.compareTo(a.fee));
    final news = [
      for (final m in headlines.take(aiTransferHeadlinesPerWeek))
        m.newsWith(formatMoney(m.fee)),
    ];
    // ホームの知らせには、いちばん大きな移籍と件数を出す。
    final top = headlines.isNotEmpty
        ? headlines.first
        : ([...moves]..sort((a, b) => b.fee.compareTo(a.fee))).first;
    final others = moves.length - 1;
    lastAiTransferNews = others <= 0
        ? top.newsWith(formatMoney(top.fee))
        : Tr.pick(
            '${top.newsWith(formatMoney(top.fee))}ほか、今週は$others件の移籍が成立した。',
            '${top.newsWith(formatMoney(top.fee))} ${Tr.plural(others, 'other deal')} went through this week.');
    return news;
  }

  int renewalCostFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.renewalCost(player);
  }

  /// 契約更新時に一括で必要なサインボーナス(万円)。
  int signingBonusFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.signingBonusFor(player);
  }

  /// 契約更新後、リーグ公式戦にスタメン出場するたびに支払う出場手当(万円)。
  int appearanceFeeFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.appearanceFeeFor(player);
  }

  /// 指定選手の今シーズンの成績(出場・得点・カード・平均採点)を、
  /// リーグ戦の消化済み試合結果から都度集計する。
  PlayerSeasonStats seasonStatsFor(String playerId) {
    if (_save == null) return const PlayerSeasonStats();
    int appearances = 0, goals = 0, yellowCards = 0, redCards = 0;
    double ratingSum = 0;
    for (final f in _save!.league.fixtures) {
      final r = f.result;
      if (r == null) continue;
      final rating = r.playerRatings[playerId];
      if (rating != null) {
        appearances++;
        ratingSum += rating;
      }
      for (final e in r.events) {
        if (e.scorerId != playerId) continue;
        switch (e.type) {
          case MatchEventType.goal:
            goals++;
            break;
          case MatchEventType.yellowCard:
            yellowCards++;
            break;
          case MatchEventType.redCard:
            redCards++;
            break;
          case MatchEventType.chance:
          case MatchEventType.substitution:
            break;
        }
      }
    }
    return PlayerSeasonStats(
      appearances: appearances,
      goals: goals,
      yellowCards: yellowCards,
      redCards: redCards,
      averageRating: appearances == 0 ? null : ratingSum / appearances,
    );
  }

  /// 契約を更新する。満了の年は[endYear](省略時は年齢に応じた年数)。
  /// ローン選手・仮契約で出ていく選手・「延長しない」選手とは更新できない
  /// (理由は[lastSigningBlockReason])。
  Future<bool> renewContract(
    String playerId, {
    int? endYear,
    bool option = false,
  }) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    // もう手放した選手(提案が残っていた・画面が古い)は更新できない。
    final player =
        userTeam.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null) return false;
    final blocked = renewalBlockReason(player);
    if (blocked != null) {
      lastSigningBlockReason = blocked;
      _notify();
      return false;
    }
    final cost = ContractEngine.renewalCost(player) +
        ContractEngine.signingBonusFor(player);
    if (_save!.budget < cost) return false;
    _book(LedgerCategory.transfers, -(cost));
    ContractEngine.renewContract(player, endYear: endYear, option: option);
    _notify();
    await _persist();
    return true;
  }

  /// 進行中の契約交渉(週俸の駆け引き)。ない場合はnull。
  ContractNegotiation? get pendingContractNegotiation =>
      _save?.pendingContractNegotiation;

  /// 選手との週俸交渉を開始する(現在の週俸を起点に、選手側の最低希望額を提示する)。
  ///
  /// 満了の年([endYear])と延長オプション([option])は交渉の前に決める。
  /// オプションを付けると選手の求める週俸が5%上がる。更新できない選手
  /// ([renewalBlockReason])とは始めない。
  void startContractNegotiation(
    String playerId, {
    int? endYear,
    bool option = false,
  }) {
    if (_save == null) return;
    lastSigningBlockReason = null;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final blocked = renewalBlockReason(player);
    if (blocked != null) {
      lastSigningBlockReason = blocked;
      _notify();
      return;
    }
    final negotiation = ContractNegotiation(
      playerId: playerId,
      initialWage: player.wage,
      offeredWage: player.wage,
      counterWage: 0,
      endYear: endYear,
      option: option,
    );
    negotiation.counterWage =
        (ContractEngine.initialDemand(player) * _optionFactor(negotiation))
            .round();
    _save!.pendingContractNegotiation = negotiation;
    _notify();
    _persist();
  }

  /// 交渉に延長オプションが付いていれば、求める週俸の倍率。
  double _optionFactor(ContractNegotiation n) =>
      n.option ? ContractEngine.optionWageFactor : 1.0;

  /// 交渉中の満了の年・延長オプションを変える(求める週俸も合わせて変わる)。
  void setNegotiationTerms({int? endYear, bool? option}) {
    final n = _save?.pendingContractNegotiation;
    if (n == null) return;
    final player =
        userTeam.players.where((p) => p.id == n.playerId).firstOrNull;
    if (player == null) return;
    final before = _optionFactor(n);
    if (endYear != null) n.endYear = endYear;
    if (option != null) n.option = option;
    final end = n.endYear ??
        Player.contractClockYear + ContractEngine.negotiatedYears(player);
    if (n.option && !ContractEngine.canAttachOption(end, player.age)) {
      n.option = false;
    }
    n.counterWage = (n.counterWage / before * _optionFactor(n)).round();
    _notify();
    _persist();
  }

  /// 交渉中の選手に週俸を提示する。選手の最低希望額以上ならその場で合意成立
  /// (契約更新の基本費用・サインボーナスの支払いが必要)。届かなければ選手側
  /// から対案が届き交渉が続く。規定回数を超えると選手は交渉から離脱する。
  Future<ContractOfferResult> offerContractWage(int wage) async {
    if (_save == null || _save!.pendingContractNegotiation == null) {
      return ContractOfferResult.walkedAway;
    }
    final negotiation = _save!.pendingContractNegotiation!;
    Player? player;
    for (final p in userTeam.players) {
      if (p.id == negotiation.playerId) {
        player = p;
        break;
      }
    }
    if (player == null) {
      // 交渉相手が何らかの理由で既にチームを離れている(インポートされた
      // セーブなど)場合は、交渉自体を破棄して安全に終了する。
      _save!.pendingContractNegotiation = null;
      _notify();
      await _persist();
      return ContractOfferResult.walkedAway;
    }
    final minAcceptable = (ContractEngine.minimumAcceptableWage(player) *
            _optionFactor(negotiation))
        .round();
    if (wage >= minAcceptable) {
      final cost = ContractEngine.renewalCost(player) +
          ContractEngine.signingBonusFor(player);
      if (_save!.budget < cost) return ContractOfferResult.insufficientFunds;
      _book(LedgerCategory.transfers, -(cost));
      player.wage = wage;
      ContractEngine.renewContract(
        player,
        endYear: negotiation.endYear,
        option: negotiation.option,
      );
      // この週俸は今の序列で求められた額(のちに上げると見直しを求める)。
      player.wageStatus = player.squadStatus;
      _save!.pendingContractNegotiation = null;
      _notify();
      await _persist();
      return ContractOfferResult.accepted;
    }
    negotiation.roundsUsed += 1;
    if (negotiation.roundsUsed >= ContractEngine.maxNegotiationRounds) {
      _save!.pendingContractNegotiation = null;
      _notify();
      await _persist();
      return ContractOfferResult.walkedAway;
    }
    negotiation.offeredWage = wage;
    negotiation.counterWage = max(
        minAcceptable,
        (ContractEngine.counterOffer(player, wage) * _optionFactor(negotiation))
            .round());
    _notify();
    await _persist();
    return ContractOfferResult.countered;
  }

  /// 契約交渉を打ち切る。
  void cancelContractNegotiation() {
    if (_save == null) return;
    _save!.pendingContractNegotiation = null;
    _notify();
    _persist();
  }

  /// スカッド全体で戦術ミーティングを行い、判断力・位置取り・チームワークを
  /// 小幅に伸ばす。クールダウン中は実施できない。
  Future<bool> holdTacticalMeeting() async {
    if (_save == null) return false;
    if (userTeam.tacticalMeetingCooldownWeeks > 0) return false;
    TrainingEngine.applyTacticalMeeting(userTeam.players);
    userTeam.tacticalMeetingCooldownWeeks =
        GameState.tacticalMeetingCooldownWeeks;
    _notify();
    await _persist();
    return true;
  }

  /// 分割払いで移籍市場の選手を獲得する。頭金3割、残りは契約の年数
  /// (2〜5年)に合わせて、季の締めに毎年同じ額を払う(2026-11-22 から。
  /// 以前は残りを4週で払っていた。実際の移籍金の分割は年単位)。
  Future<bool> buyPlayerOnInstallments(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final player = target.player;
    if (!_minorRuleAllows(player)) return false;
    if (!_registrationAllows(player)) return false;
    final total = player.marketValue;
    final downPayment =
        (total * GameStateMoneyRules.installmentDownPercent / 100).round();
    final fee = TransferTermsEngine.agentFee(total);
    if (_save!.budget < downPayment + fee) return false;
    lastSigningBlockReason = null;
    if (!_wageBudgetAllowsSigning(player.wage, fee: total)) return false;

    _convertArrivingWage(target);
    _payTransferFee(downPayment);
    _bookAgentFee(player, fee);
    ContractEngine.applyTransferContract(player);
    _addAnnualInstallment(player, total - downPayment,
        player.contractEndYear - Player.contractClockYear + 1);
    _recordPlayerBook(player, total, announce: false, agentFee: fee);
    _takeFromSeller(target);
    _supportersOnSigning(player);
    userTeam.players.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// ローンで市場の選手を借りる。[length]が半年なら冬の窓が開く日まで、
  /// 1年ならシーズン末(6月30日)まで。冬の窓より後に組む半年は1年と同じ。
  ///
  /// 窓の外でも、登録中の GK が全員出られないときは GK を1人だけ借りられる
  /// ([isGoalkeeperEmergency])。
  Future<bool> signLoanPlayer(
    String playerId, {
    bool withBuyOption = false,
    LoanLength length = LoanLength.full,
    bool withObligation = false,
  }) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final player = target.player;
    if (!_windowAllowsSigning(player, permanent: false)) return false;
    if (!_minorRuleAllows(player)) return false;
    if (userTeam.players.where((p) => p.isLoan).length >=
        GameState.maxLoansIn) {
      lastSigningBlockReason = Tr.pick(
          '借りていられるのは同時に${GameState.maxLoansIn}人までです。',
          'You can only have ${GameState.maxLoansIn} players in on loan at once.');
      _notify();
      return false;
    }
    if (!_registrationAllows(player)) return false;
    // 買取義務付きは、借り賃が半分(満了したら必ず買い取る)。
    // 貸し出すときに受け取るレンタル料([standardLoanFeePercent])と同じ決まり。
    final fee = (player.marketValue *
            GameState.loanFeeRatioPercent /
            100 *
            (withObligation ? GameStateForms.obligationLoanFeeFactor : 1))
        .round();
    if (_save!.budget < fee) return false;
    lastSigningBlockReason = null;
    if (!_wageBudgetAllowsSigning((player.wage * 0.6).round())) return false;

    _book(LedgerCategory.transfers, -(fee));
    player.isLoan = true;
    player.loanFromClubId = target.club?.id;
    player.loanBaseWage = player.wage;
    player.loanWeeksRemaining = 0;
    player.loanEndDate =
        TransferWindowCalendar.loanEndDate(today, currentLeagueTheme, length);
    player.wage = max(1, (player.wage * 0.6).round());
    player.loanBuyOptionFee = withBuyOption || withObligation
        ? (player.marketValue * GameState.loanBuyOptionRatio).round()
        : null;
    player.loanObligation = withObligation;
    // 前クラブで設定されていた解放条項が残っていると、ローン中の選手が
    // 自動移籍オファーの対象になってしまうため解除する。
    player.releaseClause = null;
    _takeFromSeller(target);
    _supportersOnSigning(player);
    userTeam.players.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// ローン契約に付いている買取オプションを行使し、ローン中の選手を恒久的に
  /// 完全移籍(自クラブの正式な選手)に切り替える。
  Future<bool> exerciseLoanBuyOption(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (!player.isLoan || player.loanBuyOptionFee == null) return false;
    final fee = player.loanBuyOptionFee!;
    if (_save!.budget < fee) return false;

    _payTransferFee(fee);
    player.isLoan = false;
    player.loanWeeksRemaining = 0;
    player.loanEndDate = null;
    player.loanBuyOptionFee = null;
    // ローン中は週俸を6割に軽減していた(signLoanPlayer)ため、完全移籍化に
    // あたって元の水準に戻す。そのままだと恒久的に割引契約のままになる。
    player.wage = player.loanBaseWage ?? max(1, (player.wage / 0.6).round());
    player.loanFromClubId = null;
    player.loanBaseWage = null;
    // 年数そのものを入れると今シーズンぶんが足りず、例えば32歳以上は1年で
    // 境界を迎えてその場で退団していた。獲得と同じ考え方で結ぶ。
    player.contractYearsRemaining = 0;
    ContractEngine.applyTransferContract(player);
    _recordPlayerBook(player, fee, announce: false);
    _notify();
    await _persist();
    return true;
  }

  /// 契約中のスポンサーがなければ、次に選べる候補を返す(既に選択済みならnull)。
  List<SponsorDeal> get pendingSponsorOffers =>
      _save?.pendingSponsorOffers ?? [];

  Future<bool> chooseSponsor(int offerIndex) async {
    if (_save == null) return false;
    if (offerIndex < 0 || offerIndex >= _save!.pendingSponsorOffers.length) {
      return false;
    }
    _save!.sponsorDeal = _save!.pendingSponsorOffers[offerIndex];
    _save!.pendingSponsorOffers = [];
    _notify();
    await _persist();
    return true;
  }

  int get scoutCost => _save == null
      ? 0
      : scaledMoney(ScoutingEngine.scoutCostFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        ));

  int get maxYouthProspects => _save == null
      ? 0
      : ScoutingEngine.maxProspectsFor(
          _save!.infrastructure.facilityLevel(FacilityType.youthFacility),
        );

  /// 昇格候補がユース施設で育つ速さの係数(表示用)。ユース施設のレベルが
  /// 高いほど、昇格を焦らずじっくり育てる価値が生まれる。
  double get youthAcademyGrowthFactor => _save == null
      ? 0
      : TrainingEngine.youthAcademyGrowthFactor(
          _save!.infrastructure.facilityLevel(FacilityType.youthFacility),
        );

  /// スカウト網が一度に見つけてくる候補選手の人数(スカウトのレベルが高いほど広がる)。
  int get scoutCandidateCount => _save == null
      ? 0
      : ScoutingEngine.scoutCandidateCountFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        );

  /// 現在のスカウトのレベル。潜在能力の推定レンジの精度にも影響する。
  /// ユースコーチの見極めのレベル。アカデミーの新人をどれだけ正確に
  /// 見立てられるか(推定幅の狭さ)と、どれだけ有望な子が集まるかに効く。
  ///
  /// 役職の総合力ではなく見極めだけを見る。混ぜて使っていたため、指導だけが
  /// 高いコーチでも見立てが鋭くなり、能力の説明と噛み合っていなかった。
  int get youthCoachJudgingLevel =>
      _save?.infrastructure
          .staffAttributeLevel(StaffRole.youthCoach, StaffAttribute.judging) ??
      1;

  /// ユースコーチの指導のレベル。アカデミーでの伸びに効く。
  int get youthCoachCoachingLevel =>
      _save?.infrastructure
          .staffAttributeLevel(StaffRole.youthCoach, StaffAttribute.coaching) ??
      1;

  int get scoutLevel =>
      _save == null ? 1 : _save!.infrastructure.staffLevel(StaffRole.scout);

  void _refreshScoutCandidates() {
    if (_save == null) {
      scoutCandidates = [];
      return;
    }
    final scoutLevel = _save!.infrastructure.staffLevel(StaffRole.scout);
    final count = ScoutingEngine.scoutCandidateCountFor(scoutLevel);
    // 18歳未満は国をまたいで移れないので、スカウト網は国内の有望株だけを
    // 探す(どの国の子かを付けておく)。
    scoutCandidates = List.generate(
      count,
      (_) => ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel)
        ..originLeague = currentLeagueTheme.name,
    );
    // 水準3以上のスカウトは、他のクラブで出番の無い即戦力も見つけてくる
    // (候補の一部を置き換える。顔ぶれの人数は変えない)。
    scoutedProClubs = {};
    final gems = min(ScoutingEngine.hiddenGemCountFor(scoutLevel), count);
    final clubs = [
      for (final t in _save!.league.teams)
        if (t.id != _save!.userTeamId) t,
    ];
    if (gems == 0 || clubs.isEmpty) return;
    final target = _divisionTop11Median().round();
    final rng = Random();
    for (var i = 0; i < gems; i++) {
      final club = clubs[rng.nextInt(clubs.length)];
      final p = _generatingFor(club,
          () => ScoutingEngine.generateHiddenGem(targetOverall: target))
        ..originLeague = currentLeagueTheme.name;
      scoutCandidates[count - 1 - i] = p;
      scoutedProClubs[p.id] = club.name;
    }
  }

  /// 自クラブの部の CPU のクラブの、上位11人の総合力の平均の中央。
  double _divisionTop11Median() {
    final xs = <double>[];
    for (final t in _save!.league.teams) {
      if (t.id == _save!.userTeamId || t.players.isEmpty) continue;
      final o = t.players.map((p) => p.overall).toList()
        ..sort((a, b) => b.compareTo(a));
      final top = o.take(11).toList();
      xs.add(top.reduce((a, b) => a + b) / top.length);
    }
    if (xs.isEmpty) return userTeam.overallRating.toDouble();
    xs.sort();
    final m = xs.length ~/ 2;
    return xs.length.isOdd ? xs[m] : (xs[m - 1] + xs[m]) / 2;
  }

  /// [p]がスカウト網の「埋もれた即戦力」(移籍で獲るプロ)か。
  bool isScoutedPro(Player p) => scoutedProClubs.containsKey(p.id);

  /// 「埋もれた即戦力」の移籍金(万円)。相場([TransferValue.worth])から
  /// スカウトの水準に応じて2〜4割引く。
  int scoutedProFeeFor(Player p) =>
      (TransferValue.worth(p, seasonProgress) *
              (1 - ScoutingEngine.hiddenGemDiscount(scoutLevel)))
          .round();

  /// 「埋もれた即戦力」を移籍で獲る。移籍の窓が開いていて、移籍金と
  /// 代理人手数料が払え、登録と週給の枠が足りるときだけ。
  bool _signScoutedPro(int idx) {
    final p = scoutCandidates[idx];
    final clubName = scoutedProClubs[p.id] ?? '-';
    if (!isTransferWindowOpen) {
      lastSigningBlockReason = Tr.pick('移籍の窓が閉じているので、所属先のある選手は獲れません。',
          'The transfer window is closed, so you cannot sign a player under contract.');
      return false;
    }
    if (userTeam.players.length >= maxSquadSize) {
      lastSigningBlockReason = Tr.pick('一軍の人数が上限です。',
          'Your first-team squad is full.');
      return false;
    }
    final fee = scoutedProFeeFor(p);
    final agentFee = TransferTermsEngine.agentFee(fee);
    if (_save!.budget < fee + agentFee) {
      lastSigningBlockReason = Tr.pick('資金が足りません。', 'Not enough funds.');
      return false;
    }
    if (!_registrationAllows(p)) return false;
    if (!_wageBudgetAllowsSigning(p.wage, fee: fee)) return false;
    _payTransferFee(fee);
    _bookAgentFee(p, agentFee);
    ContractEngine.applyTransferContract(p);
    _recordPlayerBook(p, fee, announce: false, agentFee: agentFee);
    scoutCandidates.removeAt(idx);
    scoutedProClubs.remove(p.id);
    _supportersOnSigning(p);
    userTeam.players.add(p);
    _logNews(
        Tr.pick('スカウトが見つけた$clubNameの${p.name}を、${formatMoney(fee)}で獲得した。',
            'Signed ${p.name} from $clubName for ${formatMoney(fee)}, found by your scouts.'),
        context: Tr.pick('移籍', 'Transfer'));
    return true;
  }

  /// スカウト網を手動で更新する1回あたりの費用(万円)。
  int get scoutRefreshCost => _save == null
      ? 0
      : scaledMoney(ScoutingEngine.refreshCostFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        ));

  /// 費用を払ってスカウト網を更新し、候補選手の顔ぶれを一新する。
  /// 資金が足りない場合は何もせずfalseを返す。
  Future<bool> refreshScoutCandidates() async {
    if (_save == null) return false;
    final cost = scoutRefreshCost;
    if (_save!.budget < cost) return false;
    _book(LedgerCategory.facilities, -(cost));
    _refreshScoutCandidates();
    _notify();
    await _persist();
    return true;
  }

  /// 候補選手一覧から1人選んでスカウト費用を払い、ユース昇格候補として迎える。
  Future<bool> scoutProspect(String candidateId) async {
    if (_save == null) return false;
    final idx = scoutCandidates.indexWhere((p) => p.id == candidateId);
    if (idx < 0) return false;
    if (isScoutedPro(scoutCandidates[idx])) {
      lastSigningBlockReason = null;
      final ok = _signScoutedPro(idx);
      _notify();
      if (ok) await _persist();
      return ok;
    }
    final infra = _save!.infrastructure;
    final cost = scoutCost;
    final maxP = ScoutingEngine.maxProspectsFor(
      infra.facilityLevel(FacilityType.youthFacility),
    );
    if (_save!.budget < cost) return false;
    if (_save!.youthProspects.length >= maxP) return false;
    // ユースの候補を迎える費用はアカデミーへの投資(規則の判定で赤字に数えない)。
    _book(LedgerCategory.infrastructure, -(cost));
    if (_isInternationalMinor(scoutCandidates[idx])) return false;
    final signed = scoutCandidates.removeAt(idx);
    _save!.youthProspects.add(signed);
    final scoutLevel = infra.staffLevel(StaffRole.scout);
    scoutCandidates.add(
      ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel)
        ..originLeague = currentLeagueTheme.name,
    );
    _notify();
    await _persist();
    return true;
  }

  /// 昇格の条件(週俸・契約金・年数・背番号)。押す前に見せるため、
  /// 実行と分けて計算できるようにしてある。
  YouthPromotionTerms? youthPromotionTermsFor(
    String playerId, {
    int? years,
    bool option = false,
  }) {
    if (_save == null) return null;
    final player =
        _save!.youthProspects.where((p) => p.id == playerId).firstOrNull;
    if (player == null) return null;
    return YouthPromotionEngine.termsFor(userTeam, player,
        years: years, option: option);
  }

  /// ユースから一軍へ上げる。プロ契約を結ぶので、契約金と週給予算の枠が
  /// 必要になる。足りない場合は[lastSigningBlockReason]に理由を入れて
  /// false を返す(押しても何も起きない状態にしない)。
  ///
  /// プロ契約は16歳から。契約の年数([years]、今のシーズンを含める)と
  /// 延長オプション([option])を選べる。
  Future<bool> promoteYouthProspect(
    String playerId, {
    int? years,
    bool option = false,
  }) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    if (userTeam.players.length >= maxSquadSize) {
      lastSigningBlockReason = Tr.pick('スカッドが上限です。誰かを放出してから昇格させてください。',
          'Your squad is full. Release someone before promoting him.');
      _notify();
      return false;
    }
    final idx = _save!.youthProspects.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.youthProspects[idx];
    if (!YouthPromotionEngine.oldEnough(player)) {
      lastSigningBlockReason = Tr.pick(
          'プロ契約は${ContractEngine.minProfessionalAge}歳から結べます(${player.name}は${player.age}歳)。',
          'Professional contracts start at ${ContractEngine.minProfessionalAge} (${player.name} is ${player.age}).');
      _notify();
      return false;
    }
    final terms = YouthPromotionEngine.termsFor(userTeam, player,
        years: years, option: option);

    if (_save!.budget < terms.signingBonus) {
      lastSigningBlockReason = Tr.pick(
          '契約金${formatMoney(terms.signingBonus)}が払えません(資金${formatMoney(_save!.budget)})。',
          'You cannot cover the ${formatMoney(terms.signingBonus)} signing bonus (funds ${formatMoney(_save!.budget)}).');
      _notify();
      return false;
    }
    if (!_wageBudgetAllowsSigning(terms.weeklyWage)) {
      _notify();
      return false;
    }

    _save!.youthProspects.removeAt(idx);
    YouthPromotionEngine.applyPromotion(player, terms);
    _book(LedgerCategory.transfers, -(terms.signingBonus));
    userTeam.players.add(player);
    _logNews(
      Tr.pick(
          'ユースの${player.name}がプロ契約(背番号${terms.squadNumber}・年俸${formatMoney(annualFromWeekly(terms.weeklyWage))}・${terms.years}年)を結び、一軍に昇格しました',
          '${player.name} signed his first professional contract (no. ${terms.squadNumber}, salary ${formatMoney(annualFromWeekly(terms.weeklyWage))}, ${Tr.plural(terms.years, 'year')}) and joined the first team'),
      context: Tr.pick('ユース', 'Youth'),
    );
    _notify();
    await _persist();
    return true;
  }

  Future<void> releaseYouthProspect(String playerId) async {
    if (_save == null) return;
    _save!.youthProspects.removeWhere((p) => p.id == playerId);
    _notify();
    await _persist();
  }

  /// シーズン終了時に一括生成された、選抜待ちのユースインテーク候補。
  List<Player> get pendingYouthIntake => _save?.pendingYouthIntake ?? [];

  /// ユースインテーク候補をユース昇格候補として引き取る(枠が一杯なら失敗)。
  Future<bool> keepYouthIntakePlayer(String playerId) async {
    if (_save == null) return false;
    if (_save!.youthProspects.length >= maxYouthProspects) return false;
    final idx = _save!.pendingYouthIntake.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.pendingYouthIntake.removeAt(idx);
    _save!.youthProspects.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// ユースインテーク候補を解雇する。
  Future<void> releaseYouthIntakePlayer(String playerId) async {
    if (_save == null) return;
    _save!.pendingYouthIntake.removeWhere((p) => p.id == playerId);
    _notify();
    await _persist();
  }

  /// 契約満了で放出された選手やベテラン選手からなる、移籍金なし(週俸のみ)
  /// で獲得できるフリーエージェントのプール。
  List<Player> get freeAgents => _save?.freeAgents ?? [];

  /// フリーエージェントを新規契約で獲得する(移籍金は発生しない。契約金と
  /// 代理人手数料は払う)。
  ///
  /// 所属の無い選手は移籍ではないので、窓の外でも取れる(実在の決まりと
  /// 同じ)。登録の枠と年俸の枠は窓の中と同じに見る。
  ///
  /// 満了の年は[endYear](省略時は年齢に応じた年数)。延長オプション
  /// ([option])を付けると週俸が5%上がる。
  Future<bool> signFreeAgent(
    String playerId, {
    int? endYear,
    bool option = false,
  }) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    final idx = _save!.freeAgents.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (!_registrationAllows(_save!.freeAgents[idx])) return false;
    final candidate = _save!.freeAgents[idx];
    final wage = option
        ? (candidate.wage * ContractEngine.optionWageFactor).round()
        : candidate.wage;
    if (!_wageBudgetAllowsSigning(wage)) return false;
    // 移籍金は要らないが、契約金(サイン料)と代理人手数料は払う。
    final bonus = freeAgentSigningFeeFor(candidate);
    final agentFee = freeAgentAgentFeeFor(candidate, wage);
    if (_save!.budget < bonus + agentFee) {
      lastSigningBlockReason = Tr.pick(
          '資金が足りません(契約金${formatMoney(bonus)}と代理人手数料${formatMoney(agentFee)}が要ります)。',
          'You cannot afford it: the signing bonus (${formatMoney(bonus)}) and agent fee (${formatMoney(agentFee)}) are paid up front.');
      _notify();
      return false;
    }
    // イタリアの「EU 外は1季2人まで」は所属なしの選手も数える(外す前に)。
    _noteSigningFromAbroad(candidate);
    final player = _save!.freeAgents.removeAt(idx);
    player.wage = wage;
    ContractEngine.renewContract(player, endYear: endYear, option: option);
    if (bonus > 0) _book(LedgerCategory.transfers, -bonus);
    _bookAgentFee(player, agentFee);
    _recordPlayerBook(player, 0, announce: false, agentFee: agentFee);
    _supportersOnSigning(player);
    userTeam.players.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// 選手のリリース条項(解放金額)を設定・解除する。nullで解除。
  /// スペインでは条項が必ず付くので、解除すると既定の額(市場価値の数倍)に戻る。
  Future<void> setReleaseClause(String playerId, int? amount) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.releaseClause = amount;
    _notify();
    await _persist();
  }

  /// 選手の移籍リスト登録状態を切り替える。選手を売るのはこの形だけで、
  /// 登録中は窓のあいだ、人気に応じて他のクラブ(他の部・他の国も)から
  /// オファーが届く([_rollListedOffers])。借りている・貸している選手は
  /// 載せられない。
  Future<void> setTransferListed(String playerId, bool listed) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (listed && (player.isLoan || player.isLoanedOut)) return;
    player.isTransferListed = listed;
    _notify();
    await _persist();
  }

  /// 若手有望株ランキングで選手を追跡対象(ウォッチリスト)に指定しているか。
  /// 自クラブ以外の選手も、将来獲得を検討するために追跡できる。
  bool isWatched(String playerId) =>
      _save?.watchlistPlayerIds.contains(playerId) ?? false;

  /// ウォッチリストへの追加・削除を切り替える。
  Future<void> toggleWatched(String playerId) async {
    if (_save == null) return;
    if (!_save!.watchlistPlayerIds.remove(playerId)) {
      _save!.watchlistPlayerIds.add(playerId);
    }
    _notify();
    await _persist();
  }

  /// 出場機会を約束させた貸出でクラブが受け取るレンタル料の割合。
  ///
  /// 0 は「受け取らない」。約束させるぶん、貸出先はこちらに払わない。
  static const int developmentLoanFeePercent = 0;

  /// 通常の貸出で受け取るレンタル料の割合(市場価値に対する百分率)。
  ///
  /// 貸し出したときに一度だけ受け取る。借りる側(自クラブが借りる
  /// [signLoanPlayer])が払う契約金と同じ決まり([GameState.loanFeeRatioPercent])。
  /// 以前は「週次 2%」と書かれていたが一度も使われておらず、そのまま週次で
  /// 入れると1年の貸し出しで市場価値とほぼ同じ額が入り、借りる側の2割と
  /// 釣り合わないため、借りる側に揃えた。
  static const int standardLoanFeePercent = GameState.loanFeeRatioPercent;

  /// [p]を貸し出したときに受け取るレンタル料。出場機会を約束させると0。
  /// 系列クラブへの貸し出しは必ず約束付きになる([loanOutPlayer])。
  int loanOutFeeFor(Player p, {bool guaranteePlayingTime = false}) {
    final percent = guaranteePlayingTime || affiliateClub != null
        ? developmentLoanFeePercent
        : standardLoanFeePercent;
    return (p.marketValue * percent / 100).round();
  }

  /// 自クラブの選手を期限付きで他クラブへローン放出する。放出中は週俸を放出先が
  /// 負担し、自クラブの試合には出場できない。スタメンだった場合は自動で欠員を埋める。
  /// 通常の貸出(出場機会の約束なし)では、レンタル料([loanOutFeeFor])が入る。
  ///
  /// [length]が半年なら冬の窓が開く日、1年ならシーズン末に戻る。
  /// [recallClause]を付けると、冬の窓のあいだに呼び戻せる
  /// ([recallLoanedOutPlayer])。
  Future<bool> loanOutPlayer(
    String playerId, {
    LoanLength length = LoanLength.half,
    bool guaranteePlayingTime = false,
    bool recallClause = false,
  }) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final team = userTeam;
    // 既に貸し出している選手は手元に居ないので数えない。数えると、貸し出しを
    // 重ねるうちに試合に出せる人数が最低人数を割り込む。
    final available = team.players.where((p) => !p.isLoanedOut).length;
    if (available <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan || player.isLoanedOut) return false;
    if (team.players.where((p) => p.isLoanedOut).length >=
        GameState.maxLoansOut) {
      lastSigningBlockReason = Tr.pick(
          '貸し出していられるのは同時に${GameState.maxLoansOut}人までです。',
          'You can only have ${GameState.maxLoansOut} players out on loan at once.');
      _notify();
      return false;
    }

    final candidates =
        _save!.league.teams.where((t) => t.id != _save!.userTeamId).toList();
    if (candidates.isEmpty) return false;
    // 系列クラブがあれば、そこへ出場機会付きで送る。
    final affiliate = affiliateClub;
    final destination =
        affiliate ?? candidates[Random().nextInt(candidates.length)];
    if (affiliate != null) guaranteePlayingTime = true;

    final until =
        TransferWindowCalendar.loanEndDate(today, currentLeagueTheme, length);
    player.loanedOutUntil = until;
    player.loanedOutWeeksRemaining =
        max(1, (TransferWindowCalendar.daysBetween(today, until) / 7).ceil());
    player.loanRecallClause = recallClause;
    player.loanedOutToClubName = destination.name;
    // 育成型かどうか。約束させると成長は大きいが、レンタル料は入らない。
    player.loanedWithPlayingTime = guaranteePlayingTime;
    // レンタル料。選手から入るお金なので、売却と同じ区分に入れる
    // (借りるときの契約金は「補強費」に入れているのと対になる)。
    final loanFee =
        loanOutFeeFor(player, guaranteePlayingTime: guaranteePlayingTime);
    if (loanFee > 0) _book(LedgerCategory.playerSales, loanFee);
    // 復帰時の成長レポートのために放出時点の総合力を記録しておく。
    player.loanStartOverall = player.overall;
    final wasStarter = team.startingXI.remove(player.id);
    if (wasStarter) {
      LineupUtils.autoFill(team);
    }
    _notify();
    await _persist();
    return true;
  }

  /// 呼び戻しの条項が付いた貸し出しを、冬の窓のあいだに打ち切って戻す。
  bool canRecallLoanedOutPlayer(Player p) =>
      p.isLoanedOut &&
      p.loanRecallClause &&
      currentTransferWindow?.kind == TransferWindowKind.winter;

  Future<bool> recallLoanedOutPlayer(String playerId) async {
    if (_save == null) return false;
    final p = userTeam.players.where((p) => p.id == playerId).firstOrNull;
    if (p == null || !canRecallLoanedOutPlayer(p)) return false;
    lastLoanReturns = [];
    _returnFromLoan(p);
    _notify();
    await _persist();
    return true;
  }

  /// プレシーズン親善試合(1試合分)を消化する。順位やカップ戦には影響しない。
  Future<MatchResult?> playFriendly(int index) async {
    if (_save == null) return null;
    if (index < 0 || index >= _save!.friendlies.length) return null;
    final f = _save!.friendlies[index];
    if (f.result != null) return null;
    _advanceTodayTo(
        seasonCalendar.friendlyDate(index, _save!.friendlies.length));
    final league = _save!.league;
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
    // MatchEngine.simulate()は内部でapplyPostMatchEffects()を呼び疲労蓄積・
    // 負傷判定を行ってしまうため、プレシーズン親善試合では使わない。前半・後半を
    // simulateMinutesで直接シミュレートし、疲労・負傷への影響を与えないようにする。
    final weather = WeatherEngine.roll(month: today.month);
    f.weather = weather;
    final first = MatchEngine.simulateMinutes(
      home: home,
      away: away,
      startMinute: 1,
      endMinute: 45,
      weather: weather,
    );
    final second = MatchEngine.simulateMinutes(
      home: home,
      away: away,
      startMinute: 46,
      endMinute: 90,
      weather: weather,
    );
    final friendlyChanceCount = first.chanceCount + second.chanceCount;
    final friendlyHomePossession = friendlyChanceCount > 0
        ? ((first.possessionShareSum + second.possessionShareSum) /
                friendlyChanceCount *
                100)
            .round()
            .clamp(0, 100)
        : 50;
    final result = MatchResult(
      matchday: 0,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: first.homeGoals + second.homeGoals,
      awayGoals: first.awayGoals + second.awayGoals,
      events: [...first.events, ...second.events],
      weather: weather,
      homePossession: friendlyHomePossession,
      awayPossession: 100 - friendlyHomePossession,
      homeShots: first.homeShots + second.homeShots,
      awayShots: first.awayShots + second.awayShots,
      homeShotsOnTarget: first.homeShotsOnTarget + second.homeShotsOnTarget,
      awayShotsOnTarget: first.awayShotsOnTarget + second.awayShotsOnTarget,
    );
    f.result = result;
    // 実戦感覚を養う程度の軽い士気向上(疲労・負傷への影響は与えない)。
    for (final p in MatchEngine.lineupOf(userTeam)) {
      p.morale = (p.morale + 3).clamp(0, 100);
    }
    _notify();
    await _persist();
    return result;
  }

  /// 他クラブから届いている、自クラブ選手への移籍オファー。
  List<IncomingOffer> get incomingOffers => _save?.incomingOffers ?? [];

  Future<bool> acceptIncomingOffer(String offerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = _save!.incomingOffers.indexWhere((o) => o.id == offerId);
    if (idx < 0) return false;
    final offer = _save!.incomingOffers[idx];
    final team = userTeam;
    // 対象選手が既にチームを離れている場合(他クラブへの就任・別オファーの
    // 承諾などで既に放出済み)は、対価を得ずにオファーだけを破棄する。
    if (!team.players.any((p) => p.id == offer.playerId)) {
      _save!.incomingOffers.removeAt(idx);
      _notify();
      await _persist();
      return false;
    }
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == offer.playerId);
    // 18歳未満は国をまたいで移れない。他の国のクラブには売れない
    // (EU の中の16〜17歳は例外)。
    if (player.age < 18 && _isForeignClub(offer.buyerClubName)) {
      final to = _foreignLeagueOfClubName(offer.buyerClubName);
      if (to == null ||
          !minorMayMoveBetween(player.age, currentLeagueTheme, to)) {
        return false;
      }
    }
    if (player.isLoanedOut) {
      // ローン放出中の選手は貸出先クラブが保有しているため、その間はオファーを
      // 承諾できない(貸出期間が終われば復帰するので、オファー自体は保持する)。
      return false;
    }
    // 同じ選手への他クラブからの対抗オファーは、選手が既に売却されるため無効になる。
    _save!.incomingOffers.removeWhere((o) => o.playerId == offer.playerId);
    final wasTeamLeader = DynamicsEngine.isTeamLeader(team, offer.playerId);
    team.players.removeWhere((p) => p.id == offer.playerId);
    final wasStarter = team.startingXI.remove(offer.playerId);
    _clearPlayerRoleReferences(team, offer.playerId);
    if (wasStarter) {
      LineupUtils.autoFill(team);
    }
    _movePlayerToBuyer(player, offer.buyerClubName, fee: offer.amount);
    _friendsMissPlayer(player);
    _book(LedgerCategory.playerSales, offer.amount);
    // 移籍金を受け取る売却: 連帯貢献金と、簿価との差(売却益)。
    _onPlayerSold(player, offer.amount, buyerClubName: offer.buyerClubName);
    _paySellOn(player, offer.amount);
    // 人気の選手(上位・長く在籍・生え抜き)を売ると、サポーターが嘆く。
    // オーナーが選んで受けた売却だけ(リリース条項は止められず、エースの
    // 移籍志願は事件の答えに増減が入っている)。
    _supportersOnSale(player);
    // ダイナミクス: チームリーダーの放出はロッカールーム全体を動揺させる
    // (その場で売れる形をやめたので、オファーを受けた売却で見る)。
    if (wasTeamLeader) {
      for (final p in team.players) {
        p.happiness =
            (p.happiness - DynamicsEngine.leaderSalePenalty).clamp(0, 100);
      }
      _logNews(
          Tr.pick('チームリーダーの${player.name}を放出。ロッカールームに動揺が走っている',
              "You sold ${player.name}, one of the dressing room's leaders, and it has unsettled the squad"),
          context: Tr.pick('移籍', 'Transfer'));
    }
    _notify();
    await _persist();
    return true;
  }

  Future<void> declineIncomingOffer(String offerId) async {
    if (_save == null) return;
    _save!.incomingOffers.removeWhere((o) => o.id == offerId);
    _notify();
    await _persist();
  }

  /// 売った選手を、買ったクラブへ移す。
  ///
  /// 以前は自クラブから外すだけで、選手はゲームから消えていた。売った選手が
  /// 相手のクラブで戦い、対戦で顔を合わせるほうが自然で、相手の戦力も
  /// 移籍金に見合って上がる。買い手が見つからない(既にリーグを去った等)
  /// ときは、従来どおりどこにも移さない。[fee]は買い手が払った移籍金で、
  /// 資金の分かるクラブ(自国)の手元から引く。
  void _movePlayerToBuyer(Player player, String buyerClubName, {int fee = 0}) {
    if (_save == null) return;
    // 自クラブの選手は自国の扱い。他のクラブへ移る前に国籍を確定させる
    // (確定させないと、移った先のクラブの選手として国籍を引き直してしまう)。
    _fixNationality(player);
    Team? buyer;
    // 他の国のクラブも買いに来る(2026-11-23)。
    for (final t in _worldTeams) {
      if (t.id == _save!.userTeamId || t.name != buyerClubName) continue;
      buyer = t;
      break;
    }
    // 選手データを持たないクラブ(他ディビジョン)に1人だけ入れると、
    // 強度がその1人の総合力になってしまう。
    if (buyer == null || buyer.players.isEmpty) return;
    player.isTransferListed = false;
    player.releaseClause = null;
    ContractEngine.applyTransferContract(player);
    buyer.players.add(player);
    if (fee > 0) _moveAiClubCash(buyer, -fee);
  }

  /// 締切の節に入る駆け込みオファー。
  ///
  /// 相場より高い額を出してくる代わりに、有効期間は1週しかない。
  /// 締切を過ぎれば同じ相手は現れないので、その場で決めることになる。
  IncomingOffer? _rollDeadlineDayOffer(Team team) {
    if (_save == null) return null;
    if (GameState._offerRng.nextDouble() >= deadlineDayOfferChance) return null;

    final eligible = team.players
        .where((p) =>
            !p.isLoan &&
            !p.isLoanedOut &&
            !_save!.incomingOffers.any((o) => o.playerId == p.id))
        .toList();
    if (eligible.length <= minSquadSize) return null;

    // 狙われるのは主力。控えを高値で買いに来るのは不自然。
    eligible.sort((a, b) => b.overall.compareTo(a.overall));
    final target = eligible[
        GameState._offerRng.nextInt(eligible.length < 5 ? eligible.length : 5)];

    // 登録の決まりで加えられないクラブは買いに来ない。
    final rivals = _cpuClubsThatCanRegister(
        _save!.league.teams.where((t) => t.id != _save!.userTeamId), target,
        fromCountry: currentLeagueTheme);
    if (rivals.isEmpty) return null;
    final buyer = rivals[GameState._offerRng.nextInt(rivals.length)];

    return IncomingOffer(
      id: 'deadline${_incomingOfferSeq++}',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: buyer.name,
      // 相場は契約の残り年数の係数込み([TransferValue.worth])。
      amount: MarketTrendEngine.apply(
          (TransferValue.worth(target, seasonProgress) * deadlineDayPremium)
              .round(),
          marketIndex),
      weeksRemaining: 1,
    );
  }

  /// 締切の節に駆け込みオファーが入る確率。
  static const double deadlineDayOfferChance = 0.35;

  /// 駆け込みオファーの上乗せ率。相場より高いから迷う。
  static const double deadlineDayPremium = 1.35;

  /// 売りに出していない選手に、1週のうちに引き抜きのオファーが来る確率。
  static const double unsolicitedOfferChance = 0.12;

  /// 移籍リストの選手に、1週に新しく届くオファーの上限。
  static const int maxListedOffersPerWeek = 2;

  /// 移籍リストに載せた選手に、人気に応じてオファーを届ける
  /// ([TransferValue.listedInterestChance])。人気のない選手には、窓の
  /// あいだ一度も来ないこともある。
  void _rollListedOffers(Team team) {
    final s = _save!;
    final listed = team.players
        .where((p) =>
            p.isTransferListed &&
            !p.isLoan &&
            !p.isLoanedOut &&
            !s.incomingOffers.any((o) => o.playerId == p.id))
        .toList();
    if (listed.isEmpty) return;
    final median = _squadMedianOverall ?? 0;
    var added = 0;
    for (final p in listed) {
      if (added >= maxListedOffersPerWeek) break;
      final chance = TransferValue.listedInterestChance(p, median);
      if (GameState._offerRng.nextDouble() >= chance) continue;
      final o = _offerFor(p, listed: true);
      if (o == null) continue;
      s.incomingOffers.add(o);
      added++;
      _logNews(
          Tr.pick(
              '${o.buyerClubName}が移籍リストの${p.name}に${formatMoney(o.amount)}を提示した。',
              '${o.buyerClubName} bid ${formatMoney(o.amount)} for ${p.name}, who is on the transfer list.'),
          context: Tr.pick('移籍', 'Transfer'));
    }
  }

  /// [p]へのオファーを作る(買い手が見つからなければ null)。額は相場
  /// (市場価値×契約の残り年数の係数)にばらつきと移籍の相場を掛けたもの。
  /// 買い手は他の部・他の国のクラブも含めて、力の合う・払えるクラブから選ぶ。
  IncomingOffer? _offerFor(Player p, {required bool listed}) {
    final rng = GameState._offerRng;
    final spread = listed
        ? TransferValue.listedOfferSpread(rng.nextDouble())
        : TransferValue.unsolicitedOfferSpread(rng.nextDouble());
    final amount = MarketTrendEngine.apply(
        (TransferValue.worth(p, seasonProgress) * spread).round(), marketIndex);
    if (amount <= 0) return null;
    final buyer = _buyerFor(p, amount, rng);
    if (buyer == null) return null;
    return IncomingOffer(
      id: 'offer${_incomingOfferSeq++}',
      playerId: p.id,
      playerName: p.name,
      buyerClubName: buyer.name,
      amount: amount,
    );
  }

  /// 自クラブの[p]を[amount]で買いに来るクラブ。自国の各部と他の国の
  /// クラブのうち、選手を持ち、人数に空きがあり、力が合い(その選手が
  /// 戦力になる・格上すぎない)、資金が足り、国の登録の決まりで加えられる
  /// クラブ。18歳未満は国をまたげない(EU の中の16〜17歳は除く)。
  Team? _buyerFor(Player p, int amount, Random rng) {
    final s = _save!;
    final home = currentLeagueTheme;
    final foreign = _foreignTeamIds();
    final pool = <Team>[];
    for (final t in _worldTeams) {
      if (t.id == s.userTeamId || t.players.isEmpty) continue;
      if (t.players.length >= AiTransferEngine.maxSquadSize) continue;
      final level = t.overallRating;
      if (p.overall < level - 4 || p.overall > level + 12) continue;
      final country = foreign[t.id];
      if (p.age < 18 && country != null && country != home.name) {
        final to =
            LeagueTheme.values.where((x) => x.name == country).firstOrNull;
        if (to == null || !minorMayMoveBetween(p.age, home, to)) continue;
      }
      if (_aiTransferBudget(t) < amount) continue;
      pool.add(t);
    }
    pool.shuffle(rng);
    // 登録の判定は重いので、選んだ数クラブにだけ掛ける。
    for (final t in pool.take(6)) {
      if (_cpuCanRegister(t, p, fromCountry: home, foreign: foreign)) return t;
    }
    return null;
  }

  /// テスト用: 来たオファーの週の処理だけを走らせる。
  @visibleForTesting
  List<String> debugAdvanceIncomingOffers() => _advanceIncomingOffers();

  /// テスト用: CPU どうしの移籍の1週ぶんだけを走らせる。
  @visibleForTesting
  List<String> debugAdvanceAiTransfers() => _advanceAiTransfers();

  /// テスト用: [playerId]の選手に、今すぐオファーを1件届ける(人気の抽選を
  /// 飛ばす)。力の合う買い手がいなければ、登録できる同じ部のクラブが
  /// 買い手になる(テストで作った選手は力が極端なことがあるため)。
  /// それもいなければ null。
  @visibleForTesting
  IncomingOffer? debugOfferFor(String playerId) {
    if (_save == null) return null;
    final p = userTeam.players.where((x) => x.id == playerId).firstOrNull;
    if (p == null) return null;
    var o = _offerFor(p, listed: p.isTransferListed);
    if (o == null) {
      final clubs = _cpuClubsThatCanRegister(
          _save!.league.teams.where((t) =>
              t.id != _save!.userTeamId &&
              t.players.isNotEmpty &&
              t.players.length < AiTransferEngine.maxSquadSize),
          p,
          fromCountry: currentLeagueTheme);
      if (clubs.isEmpty) return null;
      o = IncomingOffer(
        id: 'offer${_incomingOfferSeq++}',
        playerId: p.id,
        playerName: p.name,
        buyerClubName: clubs.first.name,
        amount: max(1, (TransferValue.worth(p, seasonProgress) * 0.9).round()),
      );
    }
    _save!.incomingOffers.add(o);
    return o;
  }

  List<String> _advanceIncomingOffers() {
    final autoSold = <String>[];
    for (final o in List<IncomingOffer>.from(_save!.incomingOffers)) {
      // 対案の返事を待っているあいだは、オファーは消えない。
      if (o.askedAmount != null) continue;
      o.weeksRemaining -= 1;
      if (o.weeksRemaining <= 0) {
        _save!.incomingOffers.remove(o);
      }
    }

    final team = userTeam;

    // 移籍リストに載せた選手には、人気に応じて買い手からオファーが届く
    // (売るのはこの形だけ。2026-11-23)。
    if (isTransferWindowOpen) _rollListedOffers(team);

    // 締切の節には、相場より高い駆け込みのオファーが入ることがある。
    // 期限があるだけでは判断が変わらない。締切間際に「今なら高く売れる」
    // 場面が来るから、期限を意識することになる。
    if (isTransferDeadlineDay) {
      final deadlineOffer = _rollDeadlineDayOffer(team);
      if (deadlineOffer != null) {
        _save!.incomingOffers.add(deadlineOffer);
        _logNews(
          Tr.pick(
              '締切間際: ${deadlineOffer.buyerClubName}が${deadlineOffer.playerName}に'
                  '${formatMoney(deadlineOffer.amount)}を提示しました。',
              'Deadline day: ${deadlineOffer.buyerClubName} bid '
                  '${formatMoney(deadlineOffer.amount)} for ${deadlineOffer.playerName}.'),
          context: Tr.pick('移籍', 'Transfers'),
        );
        return autoSold;
      }
    }

    if (isTransferWindowOpen && _save!.incomingOffers.length < 3) {
      // 既に1クラブからオファーが来ている選手に、別クラブから対抗の競合
      // オファーが届くことがある(入札合戦。同一選手へのオファーは最大2件まで)。
      final offersByPlayer = <String, List<IncomingOffer>>{};
      for (final o in _save!.incomingOffers) {
        offersByPlayer.putIfAbsent(o.playerId, () => []).add(o);
      }
      final biddablePlayerIds = offersByPlayer.entries
          .where((e) => e.value.length == 1 && !e.value.first.viaReleaseClause)
          .map((e) => e.key)
          .where((id) => team.players.any((p) => p.id == id))
          .toList();
      if (biddablePlayerIds.isNotEmpty &&
          GameState._offerRng.nextDouble() < 0.20) {
        final targetId = biddablePlayerIds[
            GameState._offerRng.nextInt(biddablePlayerIds.length)];
        final target = team.players.firstWhere((p) => p.id == targetId);
        final existing = offersByPlayer[targetId]!.first;
        final rivalCandidates = _cpuClubsThatCanRegister(
            _save!.league.teams.where(
              (t) =>
                  t.id != _save!.userTeamId && t.name != existing.buyerClubName,
            ),
            target,
            fromCountry: currentLeagueTheme);
        if (rivalCandidates.isNotEmpty) {
          final rival = rivalCandidates[
              GameState._offerRng.nextInt(rivalCandidates.length)];
          final outbid =
              (existing.amount * (1.1 + GameState._offerRng.nextDouble() * 0.2))
                  .round();
          _save!.incomingOffers.add(
            IncomingOffer(
              id: 'offer${_incomingOfferSeq++}',
              playerId: target.id,
              playerName: target.name,
              buyerClubName: rival.name,
              amount: outbid,
            ),
          );
          return autoSold;
        }
      }
    }
    if (isTransferWindowOpen &&
        team.players.length > minSquadSize + 2 &&
        _save!.incomingOffers.length < 3) {
      // 売りに出していない選手への引き抜き。移籍リストの選手には
      // [_rollListedOffers]で別に届く。
      final eligible = team.players
          .where(
            (p) =>
                !p.isLoan &&
                !p.isLoanedOut &&
                !p.isTransferListed &&
                !_save!.incomingOffers.any((o) => o.playerId == p.id),
          )
          .toList();
      if (eligible.isNotEmpty &&
          GameState._offerRng.nextDouble() < unsolicitedOfferChance) {
        final weights =
            eligible.map((p) => (p.overall - 30).clamp(1, 99)).toList();
        final totalWeight = weights.fold<int>(0, (s, w) => s + w);
        var r = GameState._offerRng.nextInt(totalWeight);
        var chosen = eligible.last;
        for (int i = 0; i < eligible.length; i++) {
          if (r < weights[i]) {
            chosen = eligible[i];
            break;
          }
          r -= weights[i];
        }

        // 登録の決まりで加えられないクラブは買いに来ない。
        final buyerCandidates = _cpuClubsThatCanRegister(
            _save!.league.teams.where((t) => t.id != _save!.userTeamId), chosen,
            fromCountry: currentLeagueTheme);
        if (buyerCandidates.isEmpty) return autoSold;
        final buyer = buyerCandidates[
            GameState._offerRng.nextInt(buyerCandidates.length)];

        // リリース条項(スペインでは必ず付く)。条項の額が市場価値に比べて
        // 高すぎれば払いに来ない。払っても、移るかは選手が決める
        // (2026-11-22。以前は額を問わず、選手の同意なしにその場で売れていた)。
        final clause = releaseClauseOf(chosen);
        final paysClause = clause != null &&
            GameState._offerRng.nextDouble() <
                GameStateReleaseClause.aiClausePayChance(
                    clause, chosen.marketValue);
        final consents = paysClause &&
            GameState._offerRng.nextDouble() <
                GameStateReleaseClause.releaseClauseConsentChance(chosen);
        if (paysClause && !consents) {
          _logNews(
              Tr.pick(
                  '${buyer.name}が${chosen.name}のリリース条項(${formatMoney(clause)})を払うと言ってきたが、${chosen.name}は残ることを選んだ。',
                  '${buyer.name} offered to pay the release clause for ${chosen.name} (${formatMoney(clause)}), but he chose to stay.'),
              context: Tr.pick('移籍', 'Transfer'));
        } else if (consents) {
          // 条項の額を払われ、選手も同意したので、交渉なしで成立する。
          final amount = clause;
          team.players.removeWhere((p) => p.id == chosen.id);
          final wasStarter = team.startingXI.remove(chosen.id);
          if (wasStarter) {
            // スタメンが抜けた穴を自動で埋める(次の試合が即座に行われるため、
            // ユーザーが手動で編成を直す猶予がない)。
            LineupUtils.autoFill(team);
          }
          _clearPlayerRoleReferences(team, chosen.id);
          _movePlayerToBuyer(chosen, buyer.name, fee: amount);
          _book(LedgerCategory.playerSales, amount);
          // オファーを受けた売却と同じく、売却条項の支払いと、仲の良い
          // 選手の気落ちも通す。
          _onPlayerSold(chosen, amount, buyerClubName: buyer.name);
          _paySellOn(chosen, amount);
          _friendsMissPlayer(chosen);
          autoSold.add(chosen.name);
        } else {
          // 相場(契約の残り年数の係数込み)より上を出してくることが多い。
          final amount = MarketTrendEngine.apply(
              (TransferValue.worth(chosen, seasonProgress) *
                      TransferValue.unsolicitedOfferSpread(
                          GameState._offerRng.nextDouble()))
                  .round(),
              marketIndex);
          _save!.incomingOffers.add(
            IncomingOffer(
              id: 'offer${_incomingOfferSeq++}',
              playerId: chosen.id,
              playerName: chosen.name,
              buyerClubName: buyer.name,
              amount: amount,
            ),
          );
        }
      }
    }
    return autoSold;
  }

  /// 代表に呼ばれる力(総合力)。この国々はどれも強豪なので、同じ線にする。
  static const int internationalCallUpMinOverall = 75;

  /// 1つの代表がこのリーグから呼ぶ人数の上限。代表は23〜26人で、その国の
  /// リーグにいる選手が多く、外国のリーグの選手は少ない。
  static const int homeNationCallUpQuota = 18;
  static const int foreignNationCallUpQuota = 5;

  /// 代表召集の週次処理(2026-11-22 に作り直した)。
  ///
  /// 以前は一年中、自クラブの選手(総合力78以上)だけを週6%の抽選で1〜2週
  /// 呼んでいて、リーグ戦の週にも抜けていた。いまは実際の FIFA の国際
  /// マッチウィーク(9・10・11・3月。暦の[SeasonCalendar.isInternationalWindow]
  /// で、リーグ戦を入れない週)に入った最初の週の処理で、リーグの全クラブ
  /// から代表に入る力の選手を一斉に呼ぶ。選手の国籍ごとに総合力の高い順に、
  /// その国の枠まで。代表ウィークが終われば戻る([_releaseInternationalDuty])。
  /// 6月の代表ウィーク(リーグ戦が終わった後のオフ)は週の処理が止まって
  /// いるので、今日を進めたときに[_callUpForJuneWindow]で呼ぶ(2026-11-22)。
  /// 奇数年の1〜2月のアフリカネイションズカップには、アフリカの代表の選手
  /// ([GameStateNation.africanTeamFor])が大会の間クラブを離れる
  /// ([_callUpForAfricaCup]。リーグ戦は止まらない)。
  /// 自クラブで呼ばれた選手の名前を返す(通知用)。
  List<String> _advanceInternationalDuty() {
    final s = _save!;
    final teams = s.league.teams;
    for (final t in teams) {
      for (final p in t.players) {
        if (p.internationalDutyWeeksRemaining > 0) {
          p.internationalDutyWeeksRemaining -= 1;
          if (p.internationalDutyWeeksRemaining == 0) {
            _returnFromInternationalDuty(t, p);
          }
        }
      }
    }
    final cal = seasonCalendar;
    final day = today;
    final weekBefore = DateTime(day.year, day.month, day.day - 7);
    final called = <String>[];
    // 代表ウィークに入った最初の週の処理だけで呼ぶ(9日間の代表ウィークに
    // 週の処理が2回入っても、二度呼ばない)。
    if (cal.isInternationalWindow(day) &&
        !cal.isInternationalWindow(weekBefore)) {
      called.addAll(_callUpInternationals());
    }
    // アフリカネイションズカップも、期間に入った最初の週の処理で呼ぶ。
    if (cal.isAfricaCupOfNations(day) &&
        !cal.isAfricaCupOfNations(weekBefore)) {
      called.addAll(_callUpForAfricaCup());
    }
    return called;
  }

  /// 代表に入る力の選手を、リーグの全クラブから一斉に呼ぶ(代表ウィーク)。
  /// 選手の代表ごと(国籍の国、アフリカの代表の選手はその代表)に総合力の
  /// 高い順に、その代表の枠まで。[africaOnly]ならアフリカの代表だけ。
  /// [weeks]は呼ぶ週数。自クラブで呼ばれた選手を返す。
  List<Player> _selectInternationals({bool africaOnly = false, int weeks = 1}) {
    final s = _save!;
    final foreign = _foreignTeamIds();
    final home = currentLeagueTheme;
    final bySquad = <String, List<Player>>{};
    final teamOf = <String, Team>{};
    for (final t in s.league.teams) {
      final club = t.id == s.userTeamId ? null : t;
      for (final p in t.players) {
        if (p.isInjured ||
            p.isLoanedOut ||
            p.isOnInternationalDuty ||
            p.overall < internationalCallUpMinOverall) {
          continue;
        }
        final nation = _nationalityAt(p, club, foreign);
        final african = GameStateNation.africanTeamFor(p.id, nation);
        if (africaOnly && african == null) continue;
        final key = african != null
            ? 'africa$african'
            : nation == home
                ? 'home'
                : nation.name;
        bySquad.putIfAbsent(key, () => []).add(p);
        teamOf[p.id] = t;
      }
    }
    final mine = <Player>[];
    for (final entry in bySquad.entries) {
      final quota = entry.key == 'home'
          ? homeNationCallUpQuota
          : foreignNationCallUpQuota;
      final pool = entry.value..sort((a, b) => b.overall.compareTo(a.overall));
      for (final p in pool.take(quota)) {
        p.internationalDutyWeeksRemaining = weeks;
        if (teamOf[p.id]?.id == s.userTeamId) mine.add(p);
      }
    }
    return mine;
  }

  /// 代表ウィークの召集。自クラブで呼ばれた選手の名前を返す。
  List<String> _callUpInternationals() =>
      [for (final p in _selectInternationals()) p.name];

  /// アフリカネイションズカップの召集。大会が終わるまで(週の処理で先に
  /// 戻らないよう、残りの日数ぶんの週を入れる)クラブを離れる。ニュースで
  /// 知らせ、自クラブで呼ばれた選手の名前を返す。
  List<String> _callUpForAfricaCup() {
    final range = SeasonCalendar.africaCupOfNations(_save!.league.season);
    if (range == null) return const [];
    final daysLeft = range.$2.difference(SeasonCalendar.dateOnly(today)).inDays;
    final weeks = max(1, (daysLeft + 7) ~/ 7);
    final mine = _selectInternationals(africaOnly: true, weeks: weeks);
    final until = TransferWindowCalendar.formatMonthDay(range.$2);
    if (mine.isEmpty) {
      _logNews(
          Tr.pick('アフリカネイションズカップが始まった($untilまで)。自クラブから呼ばれた選手はいない。',
              'The Africa Cup of Nations has begun (until $until). None of our players were called up.'),
          context: Tr.pick('代表', 'International'));
      return const [];
    }
    LineupUtils.autoFill(userTeam);
    final names = [for (final p in mine) p.name];
    _logNews(
        Tr.pick(
            'アフリカネイションズカップ($untilまで)に${names.join('、')}が呼ばれた。期間中のリーグ戦には出られない。',
            "${names.join(', ')} ${names.length == 1 ? 'has' : 'have'} been called up for the Africa Cup of Nations (until $until) and will miss league games in the meantime."),
        context: Tr.pick('代表', 'International'));
    return names;
  }

  /// シーズンが終わった後(オフ)の6月の代表ウィーク。オフは週の処理が
  /// 止まっているので、今日が[before]から[after]へ進むあいだに6月の
  /// 代表ウィークが始まったら、ここで呼ぶ。代表ウィークが終わった日まで
  /// 一気に進んだときは、呼んですぐ戻す(疲れ・まれな怪我は残る)。
  void _callUpForJuneWindow(DateTime before, DateTime after) {
    final s = _save!;
    if (s.league.nextUnplayedFixture != null) return;
    final june = SeasonCalendar.juneWindowDays(s.league.season);
    final start = june.reduce((a, b) => a.isBefore(b) ? a : b);
    if (!before.isBefore(start) || after.isBefore(start)) return;
    final called = _callUpInternationals();
    lastInternationalCallUps = [...lastInternationalCallUps, ...called];
  }

  /// 代表から戻った選手に足す疲れの幅(この値〜+[internationalReturnFatigueSpread])。
  /// 代表ウィークは約9日で2試合。移動と試合の疲れが少し残って戻る
  /// (試合1つの疲れは12〜19。戻るまでに日数ぶん抜けるので、それより小さい)。
  static const int internationalReturnFatigue = 8;
  static const int internationalReturnFatigueSpread = 7;

  /// 代表から軽い怪我を負って戻る確率(1回の代表ウィークで呼ばれた選手の
  /// うち)。実際は2〜3%ほど。
  static const double internationalInjuryChance = 0.025;

  /// 代表から戻るときの疲れ・怪我の抽選(テストで差し替える)。
  static Random internationalReturnRng = Random();

  /// 代表ウィークが終わったら(今日が代表ウィークの外なら)、代表に行って
  /// いる選手を戻す。週の処理の曜日と代表ウィークの終わりがずれても、
  /// 次のリーグ戦の前に必ず戻るように、今日を進めるたびに見る。
  ///
  /// 戻った選手には疲れを少し足し、まれに([internationalInjuryChance])
  /// 軽い怪我(打撲・肉離れ、1〜2週)で戻る(2026-11-22)。自クラブの選手の
  /// 怪我はニュースに出す。
  ///
  /// アフリカネイションズカップの間は、アフリカの代表の選手は戻らない
  /// (ほかの選手は戻る)。
  void _releaseInternationalDuty() {
    final s = _save!;
    final cal = seasonCalendar;
    if (cal.isInternationalWindow(today)) return;
    final afcon = cal.isAfricaCupOfNations(today);
    final foreign = afcon ? _foreignTeamIds() : const <String, String>{};
    for (final t in s.league.teams) {
      final club = t.id == s.userTeamId ? null : t;
      for (final p in t.players) {
        if (p.internationalDutyWeeksRemaining <= 0) continue;
        if (afcon &&
            GameStateNation.africanTeamFor(
                    p.id, _nationalityAt(p, club, foreign)) !=
                null) {
          continue;
        }
        p.internationalDutyWeeksRemaining = 0;
        _returnFromInternationalDuty(t, p);
      }
    }
  }

  /// 代表から戻った[p]([t]の選手)に、疲れを足し、まれに軽い怪我を負わせる。
  /// 代表ウィークの途中の週の処理で戻る選手と、代表ウィークが終わって
  /// 戻る選手の両方で呼ぶ。
  void _returnFromInternationalDuty(Team t, Player p) {
    final rng = internationalReturnRng;
    p.fatigue = (p.fatigue +
            internationalReturnFatigue +
            rng.nextInt(internationalReturnFatigueSpread + 1))
        .clamp(0, 100);
    if (p.isInjured || rng.nextDouble() >= internationalInjuryChance) return;
    final type = rng.nextBool() ? InjuryType.bruise : InjuryType.muscle;
    p.injuryWeeks = 1 + rng.nextInt(2);
    p.injuryDays = 0;
    p.injuryType = type;
    p.injuryHistoryCounts[type.name] =
        (p.injuryHistoryCounts[type.name] ?? 0) + 1;
    if (t.id != _save!.userTeamId) return;
    if (t.startingXI.remove(p.id)) LineupUtils.autoFill(t);
    _logNews(
        Tr.pick(
            '${p.name}は代表で${type.label}を負って戻った(全治${p.injuryWeeks}週)。',
            '${p.name} came back from international duty with a ${type.label.toLowerCase()} (out for ${Tr.plural(p.injuryWeeks, 'week')}).'),
        context: Tr.pick('代表', 'International'));
  }

  /// テスト用: 代表召集の週次処理を、今日の日付で走らせる。
  @visibleForTesting
  List<String> debugAdvanceInternationalDuty() => _advanceInternationalDuty();

  /// テスト用: 今日が[before]から[after]へ進んだとして、オフの6月の
  /// 代表ウィークの召集を走らせる。
  @visibleForTesting
  void debugCallUpForJuneWindow(DateTime before, DateTime after) =>
      _callUpForJuneWindow(before, after);

  /// テスト用: 代表ウィークの外なら代表の選手を戻す。
  @visibleForTesting
  void debugReleaseInternationalDuty() => _releaseInternationalDuty();
}
