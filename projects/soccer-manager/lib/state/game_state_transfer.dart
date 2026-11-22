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
    if (!_wageBudgetAllowsSigning(player.wage)) return false;
    _book(LedgerCategory.transfers, -(player.marketValue));
    _bookAgentFee(player, fee);
    ContractEngine.applyTransferContract(player);
    _takeFromSeller(target);
    userTeam.players.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// 18歳未満の国際移籍の禁止に当たらないか。当たれば理由を
  /// [lastSigningBlockReason]に入れる。
  bool _minorRuleAllows(Player player) {
    if (!_isInternationalMinor(player)) return true;
    lastSigningBlockReason = Tr.pick('18歳未満の選手は国をまたいで移籍できません。',
        'Players under 18 cannot move between countries.');
    _notify();
    return false;
  }

  /// 登録の決まり([SquadRegistration])で加えられるか。加えられないときは
  /// 理由を[lastSigningBlockReason]に入れる(押しても何も起きない状態にしない)。
  bool _registrationAllows(Player player) {
    // アルビオン式のリーグでは、外国籍の選手に労働許可が要る。
    final reason = SquadRegistration.blockReason(userTeam, player) ??
        workPermitBlock(player);
    if (reason == null) return true;
    lastSigningBlockReason = reason;
    _notify();
    return false;
  }

  /// 代理人手数料を払う(移籍金とは別の費用)。
  void _bookAgentFee(Player player, int fee) {
    if (fee <= 0) return;
    _book(LedgerCategory.transfers, -fee);
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
  /// 他のクラブの選手([player])なら、そのクラブの事情も少し効く。先発の
  /// 選手は安くは手放さず(-15%)、契約が今季で切れる選手は今のうちに
  /// 売りたい(+15%)。
  double transferOfferAcceptChance(int marketValue, int offer,
      {Player? player}) {
    if (marketValue <= 0) return 1.0;
    final ratio = offer / marketValue;
    if (ratio >= 1.0) return 1.0;
    var chance = (ratio - 0.55) / 0.45;
    if (ratio > 0.55 && player != null) {
      final club = _sellingClubOf(player.id);
      if (club != null) {
        if (club.startingXI.contains(player.id)) chance -= 0.15;
        if (player.contractYearsRemaining <= 1) chance += 0.15;
      }
    }
    return chance.clamp(0.0, 1.0);
  }

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
                !(p.age < 18 && (foreign[t.id] ?? home) != home))
              p,
    ];
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

  /// 獲得した選手を、元のクラブ(または作り物の市場)から外す。
  void _takeFromSeller(({Player player, Team? club}) target) {
    final p = target.player;
    final club = target.club;
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
          label: Tr.pick('${home.label} $tier部', '${home.label} tier $tier'),
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
    if (!_wageBudgetAllowsSigning(player.wage)) {
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
    _book(LedgerCategory.transfers, -(offer));
    _bookAgentFee(player, TransferTermsEngine.agentFee(offer));
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
    _takeFromSeller(target);
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
    final outstanding =
        rows.fold<int>(0, (sum, i) => sum + i.weeklyAmount * i.weeksRemaining);
    _save!.pendingInstallments.removeWhere((i) => i.playerId == playerId);
    if (outstanding <= 0) return;
    _book(LedgerCategory.transfers, -(outstanding));
    _logNews(Tr.pick('移籍に伴い、分割払いの残金${formatMoney(outstanding)}を一括で精算した。',
        'The remaining ${formatMoney(outstanding)} of the instalment plan was settled in full on his departure.'));
  }

  /// 放出(売却)により実際に得られる額。売却では契約を買い手が引き継ぐので、
  /// 売り手は残りの年俸の違約金を払わない(払うのは合意解除のときだけ)。
  int netReleaseValueFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.salePrice(player);
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

  Future<bool> sellPlayer(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final team = userTeam;
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan) return false; // ローン選手は他クラブの所有物のため放出できない
    if (player.isLoanedOut) return false; // ローン放出中の選手は貸出先が保有しているため放出できない
    final net = netReleaseValueFor(playerId);
    final wasTeamLeader = DynamicsEngine.isTeamLeader(team, playerId);
    team.players.removeWhere((p) => p.id == playerId);
    team.startingXI.remove(playerId);
    _clearPlayerRoleReferences(team, playerId);
    _book(LedgerCategory.playerSales, net);
    _paySellOn(player, net);
    _placeSoldPlayerAtCpuClub(player);
    _friendsMissPlayer(player);
    // ダイナミクス: チームリーダーの放出はロッカールーム全体を動揺させる。
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

  /// 放出した選手を消滅させず、実力に見合うリーグ内のCPUクラブへ移籍させる
  /// (受け入れ余地のあるクラブがなければやむなく引退扱い=移動なし)。
  void _placeSoldPlayerAtCpuClub(Player player) {
    lastSaleNews = null;
    // 自クラブの選手は自国の扱い。他のクラブへ移る前に国籍を確定させる
    // (確定させないと、移った先のクラブの選手として国籍を引き直してしまう)。
    _fixNationality(player);
    final destinations = _save!.league.teams
        .where((t) => t.id != _save!.userTeamId && t.players.length < 26)
        .toList();
    if (destinations.isEmpty) return;
    final fitting = destinations
        .where((t) => t.overallRating >= player.overall - 5)
        .toList();
    final pool = fitting.isNotEmpty ? fitting : destinations;
    final dest = pool[GameState._transferOfferRng.nextInt(pool.length)];
    ContractEngine.applyCpuClubContract(
        player, 2 + GameState._transferOfferRng.nextInt(3));
    player.happiness = (player.happiness + 5).clamp(40, 90);
    dest.players.add(player);
    lastSaleNews = Tr.pick('${player.name}は${dest.name}へ移籍した。',
        '${player.name} has joined ${dest.name}.');
    _logNews(lastSaleNews!, context: Tr.pick('移籍', 'Transfer'));
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
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
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

  /// 分割払い(頭金3割 + 残額を4週で均等払い)で移籍市場の選手を獲得する。
  Future<bool> buyPlayerOnInstallments(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final player = target.player;
    if (!_minorRuleAllows(player)) return false;
    if (!_registrationAllows(player)) return false;
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    final fee = TransferTermsEngine.agentFee(total);
    if (_save!.budget < downPayment + fee) return false;
    lastSigningBlockReason = null;
    if (!_wageBudgetAllowsSigning(player.wage)) return false;

    _book(LedgerCategory.transfers, -(downPayment));
    _bookAgentFee(player, fee);
    const weeks = 4;
    final remaining = total - downPayment;
    _save!.pendingInstallments.add(
      Installment(
        description: Tr.pick(
            '${player.name} 分割払い残金', '${player.name} instalments outstanding'),
        weeklyAmount: (remaining / weeks).ceil(),
        weeksRemaining: weeks,
        playerId: player.id,
      ),
    );
    ContractEngine.applyTransferContract(player);
    _takeFromSeller(target);
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

    _book(LedgerCategory.transfers, -(fee));
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
    final infra = _save!.infrastructure;
    final cost = scoutCost;
    final maxP = ScoutingEngine.maxProspectsFor(
      infra.facilityLevel(FacilityType.youthFacility),
    );
    if (_save!.budget < cost) return false;
    if (_save!.youthProspects.length >= maxP) return false;
    _book(LedgerCategory.facilities, -(cost));
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
          'You cannot cover the ${formatMoney(terms.signingBonus)} signing fee (funds ${formatMoney(_save!.budget)}).');
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
          '${player.name} signed his first professional contract (no. ${terms.squadNumber}, salary ${formatMoney(annualFromWeekly(terms.weeklyWage))}, ${terms.years} years) and joined the first team'),
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

  /// フリーエージェントを新規契約で獲得する(移籍金は発生しない)。
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
    final player = _save!.freeAgents.removeAt(idx);
    player.wage = wage;
    ContractEngine.renewContract(player, endYear: endYear, option: option);
    userTeam.players.add(player);
    _notify();
    await _persist();
    return true;
  }

  /// 選手のリリース条項(解放金額)を設定・解除する。nullで解除。
  Future<void> setReleaseClause(String playerId, int? amount) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.releaseClause = amount;
    _notify();
    await _persist();
  }

  /// 選手の移籍リスト登録状態を切り替える。登録中は他クラブからのオファーが来やすくなる。
  Future<void> setTransferListed(String playerId, bool listed) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
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
    // 18歳未満は国をまたいで移れない。他の国のクラブには売れない。
    if (player.age < 18 && _isForeignClub(offer.buyerClubName)) return false;
    if (player.isLoanedOut) {
      // ローン放出中の選手は貸出先クラブが保有しているため、その間はオファーを
      // 承諾できない(貸出期間が終われば復帰するので、オファー自体は保持する)。
      return false;
    }
    // 同じ選手への他クラブからの対抗オファーは、選手が既に売却されるため無効になる。
    _save!.incomingOffers.removeWhere((o) => o.playerId == offer.playerId);
    team.players.removeWhere((p) => p.id == offer.playerId);
    final wasStarter = team.startingXI.remove(offer.playerId);
    _clearPlayerRoleReferences(team, offer.playerId);
    if (wasStarter) {
      LineupUtils.autoFill(team);
    }
    _movePlayerToBuyer(player, offer.buyerClubName);
    _friendsMissPlayer(player);
    _book(LedgerCategory.playerSales, offer.amount);
    // 移籍金を受け取る売却: 連帯貢献金と、簿価との差(売却益)。
    _onPlayerSold(player, offer.amount);
    _paySellOn(player, offer.amount);
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
  /// ときは、従来どおりどこにも移さない。
  void _movePlayerToBuyer(Player player, String buyerClubName) {
    if (_save == null) return;
    // 自クラブの選手は自国の扱い。他のクラブへ移る前に国籍を確定させる
    // (確定させないと、移った先のクラブの選手として国籍を引き直してしまう)。
    _fixNationality(player);
    Team? buyer;
    for (final t in _save!.allTeams) {
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

    final rivals =
        _save!.league.teams.where((t) => t.id != _save!.userTeamId).toList();
    if (rivals.isEmpty) return null;
    final buyer = rivals[GameState._offerRng.nextInt(rivals.length)];

    return IncomingOffer(
      id: 'deadline${_incomingOfferSeq++}',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: buyer.name,
      amount: MarketTrendEngine.apply(
          (target.marketValue * deadlineDayPremium).round(), marketIndex),
      weeksRemaining: 1,
    );
  }

  /// 締切の節に駆け込みオファーが入る確率。
  static const double deadlineDayOfferChance = 0.35;

  /// 駆け込みオファーの上乗せ率。相場より高いから迷う。
  static const double deadlineDayPremium = 1.35;

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
        final rivalCandidates = _save!.league.teams
            .where(
              (t) =>
                  t.id != _save!.userTeamId && t.name != existing.buyerClubName,
            )
            .toList();
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
      final eligible = team.players
          .where(
            (p) =>
                !p.isLoan &&
                !p.isLoanedOut &&
                !_save!.incomingOffers.any((o) => o.playerId == p.id),
          )
          .toList();
      // 移籍リストに登録している選手がいるとオファーが来やすくなる。
      final hasListed = eligible.any((p) => p.isTransferListed);
      final triggerChance = hasListed ? 0.30 : 0.12;
      if (eligible.isNotEmpty &&
          GameState._offerRng.nextDouble() < triggerChance) {
        final weights = eligible
            .map(
              (p) =>
                  (p.overall - 30).clamp(1, 99) * (p.isTransferListed ? 3 : 1),
            )
            .toList();
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

        final buyerCandidates = _save!.league.teams
            .where((t) => t.id != _save!.userTeamId)
            .toList();
        final buyer = buyerCandidates[
            GameState._offerRng.nextInt(buyerCandidates.length)];

        if (chosen.releaseClause != null) {
          // リリース条項がある場合は交渉なしで即成立する。
          final amount = chosen.releaseClause!;
          team.players.removeWhere((p) => p.id == chosen.id);
          final wasStarter = team.startingXI.remove(chosen.id);
          if (wasStarter) {
            // スタメンが抜けた穴を自動で埋める(次の試合が即座に行われるため、
            // ユーザーが手動で編成を直す猶予がない)。
            LineupUtils.autoFill(team);
          }
          _clearPlayerRoleReferences(team, chosen.id);
          _movePlayerToBuyer(chosen, buyer.name);
          _book(LedgerCategory.playerSales, amount);
          _onPlayerSold(chosen, amount);
          autoSold.add(chosen.name);
        } else {
          final amount = MarketTrendEngine.apply(
              (chosen.marketValue *
                      (0.9 + GameState._offerRng.nextDouble() * 0.4))
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

  /// 代表召集の週次処理: 期間終了・新規招集抽選を行う(ユーザークラブのみ)。
  /// スタメンから招集された場合は自動で欠員を埋める。招集された選手名を返す(UI通知用)。
  List<String> _advanceInternationalDuty() {
    final team = userTeam;
    for (final p in team.players) {
      if (p.internationalDutyWeeksRemaining > 0) {
        p.internationalDutyWeeksRemaining -= 1;
      }
    }

    final called = <String>[];
    var lineupChanged = false;
    final eligible = team.players.where(
      (p) =>
          !p.isInjured &&
          !p.isLoan &&
          !p.isOnInternationalDuty &&
          p.overall >= 78,
    );
    for (final p in eligible) {
      if (GameState._dutyRng.nextDouble() < 0.06) {
        p.internationalDutyWeeksRemaining = 1 + GameState._dutyRng.nextInt(2);
        called.add(p.name);
        if (team.startingXI.contains(p.id)) lineupChanged = true;
      }
    }
    if (lineupChanged) {
      LineupUtils.autoFill(team);
    }
    return called;
  }
}
