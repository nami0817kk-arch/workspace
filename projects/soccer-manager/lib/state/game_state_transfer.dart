part of 'game_state.dart';

/// 移籍市場・契約交渉・スカウト・ユース・フリーエージェント・受信オファー・国際試合。
extension GameStateTransfer on GameState {
  Future<bool> buyPlayer(String playerId) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    if (!isTransferWindowOpen) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = transferMarket[idx];
    if (_save!.budget < player.marketValue) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    if (!_wageBudgetAllowsSigning(player.wage)) return false;
    _save!.budget -= player.marketValue;
    userTeam.players.add(player);
    transferMarket.removeWhere((p) => p.id == playerId);
    _notify();
    await _persist();
    return true;
  }

  /// 値切りオファーが受け入れられる確率(0.0〜1.0)。市場価値の満額なら
  /// 必ず成立し、55%以下なら必ず拒否される。UIで交渉前に提示する。
  double transferOfferAcceptChance(int marketValue, int offer) {
    if (marketValue <= 0) return 1.0;
    final ratio = offer / marketValue;
    return ((ratio - 0.55) / 0.45).clamp(0.0, 1.0);
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
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return (attempted: false, accepted: false);
    final player = transferMarket[idx];
    if (offer <= 0 || _save!.budget < offer) {
      return (attempted: false, accepted: false);
    }
    if (userTeam.players.length >= maxSquadSize) {
      return (attempted: false, accepted: false);
    }
    lastSigningBlockReason = null;
    if (!_wageBudgetAllowsSigning(player.wage)) {
      return (attempted: false, accepted: false);
    }
    final chance = transferOfferAcceptChance(player.marketValue, offer);
    final accepted = GameState._transferOfferRng.nextDouble() < chance;
    if (!accepted) {
      transferOffersRejectedThisWeek.add(playerId);
      _notify();
      return (attempted: true, accepted: false);
    }
    _save!.budget -= offer;
    userTeam.players.add(player);
    transferMarket.removeWhere((p) => p.id == playerId);
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
    _save?.pendingInstallments.removeWhere((i) => i.playerId == playerId);
  }

  /// 放出により実際に得られる(あるいは支払う)純額。移籍金収入から
  /// 契約解除の違約金を差し引いたもので、負の値になり得る。
  int netReleaseValueFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final sellPrice = (player.marketValue * 0.7).round();
    return sellPrice - ContractEngine.releaseSeverance(player);
  }

  /// クラブニュース履歴に1件追加する(先頭が最新)。SnackBarやダイアログで
  /// 一度だけ流れる通知を、ニュース画面で後から見返せるようにする記録。
  void _logNews(String text, {String? context}) {
    if (_save == null || text.isEmpty) return;
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
    _save!.budget += net;
    _placeSoldPlayerAtCpuClub(player);
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
    final destinations = _save!.league.teams
        .where((t) => t.id != _save!.userTeamId && t.players.length < 26)
        .toList();
    if (destinations.isEmpty) return;
    final fitting = destinations
        .where((t) => t.overallRating >= player.overall - 5)
        .toList();
    final pool = fitting.isNotEmpty ? fitting : destinations;
    final dest = pool[GameState._transferOfferRng.nextInt(pool.length)];
    // 自クラブ専用の育成設定(メンター等)は移籍先では引き継がない。
    player.mentorId = null;
    player.contractYearsRemaining = 2 + GameState._transferOfferRng.nextInt(3);
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

  Future<bool> renewContract(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan) return false; // ローン選手には通常の契約更新は適用されない
    final cost = ContractEngine.renewalCost(player) +
        ContractEngine.signingBonusFor(player);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    ContractEngine.renewContract(player);
    _notify();
    await _persist();
    return true;
  }

  /// 進行中の契約交渉(週俸の駆け引き)。ない場合はnull。
  ContractNegotiation? get pendingContractNegotiation =>
      _save?.pendingContractNegotiation;

  /// 選手との週俸交渉を開始する(現在の週俸を起点に、選手側の最低希望額を提示する)。
  void startContractNegotiation(String playerId) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan) return;
    _save!.pendingContractNegotiation = ContractNegotiation(
      playerId: playerId,
      initialWage: player.wage,
      offeredWage: player.wage,
      counterWage: ContractEngine.initialDemand(player),
    );
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
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);
    if (wage >= minAcceptable) {
      final cost = ContractEngine.renewalCost(player) +
          ContractEngine.signingBonusFor(player);
      if (_save!.budget < cost) return ContractOfferResult.insufficientFunds;
      _save!.budget -= cost;
      player.wage = wage;
      ContractEngine.renewContract(player);
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
    negotiation.counterWage = ContractEngine.counterOffer(player, wage);
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

  /// 選手と話し合い、不満度を引き上げる。既に十分満足している場合は失敗する。
  Future<bool> reassurePlayer(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final ok = HappinessEngine.reassure(player);
    if (ok) {
      _notify();
      await _persist();
    }
    return ok;
  }

  /// 選手個別に声をかけ、士気を高める。効果は性格の結果感応度で変動する
  /// (T10の檄と同じ考え方)。クールダウン中は実施できない。
  Future<bool> talkToPlayer(String playerId) async {
    if (_save == null) return false;
    final idx = userTeam.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = userTeam.players[idx];
    if (player.talkCooldownWeeks > 0) return false;
    final delta =
        (GameState.talkBaseMoraleBoost * player.personality.resultSensitivity).round();
    player.morale = (player.morale + delta).clamp(0, 100);
    player.talkCooldownWeeks = TrainingEngine.talkCooldownWeeks;
    _notify();
    await _persist();
    return true;
  }

  /// スカッド全体で戦術ミーティングを行い、判断力・位置取り・チームワークを
  /// 小幅に伸ばす。クールダウン中は実施できない。
  Future<bool> holdTacticalMeeting() async {
    if (_save == null) return false;
    if (userTeam.tacticalMeetingCooldownWeeks > 0) return false;
    TrainingEngine.applyTacticalMeeting(userTeam.players);
    userTeam.tacticalMeetingCooldownWeeks = GameState.tacticalMeetingCooldownWeeks;
    _notify();
    await _persist();
    return true;
  }

  /// 分割払い(頭金3割 + 残額を4週で均等払い)で移籍市場の選手を獲得する。
  Future<bool> buyPlayerOnInstallments(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final player = transferMarket[idx];
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    if (_save!.budget < downPayment) return false;
    lastSigningBlockReason = null;
    if (!_wageBudgetAllowsSigning(player.wage)) return false;

    _save!.budget -= downPayment;
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
    userTeam.players.add(player);
    transferMarket.removeAt(idx);
    _notify();
    await _persist();
    return true;
  }

  Future<bool> signLoanPlayer(
    String playerId, {
    bool withBuyOption = false,
  }) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final player = transferMarket[idx];
    final fee = (player.marketValue * GameState.loanFeeRatioPercent / 100).round();
    if (_save!.budget < fee) return false;
    lastSigningBlockReason = null;
    if (!_wageBudgetAllowsSigning((player.wage * 0.6).round())) return false;

    _save!.budget -= fee;
    player.isLoan = true;
    player.loanWeeksRemaining = GameState.loanDurationWeeks;
    player.wage = (player.wage * 0.6).round().clamp(1, 999);
    player.loanBuyOptionFee = withBuyOption
        ? (player.marketValue * GameState.loanBuyOptionRatio).round()
        : null;
    // 前クラブで設定されていた解放条項が残っていると、ローン中の選手が
    // 自動移籍オファーの対象になってしまうため解除する。
    player.releaseClause = null;
    userTeam.players.add(player);
    transferMarket.removeAt(idx);
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

    _save!.budget -= fee;
    player.isLoan = false;
    player.loanWeeksRemaining = 0;
    player.loanBuyOptionFee = null;
    // ローン中は週俸を6割に軽減していた(signLoanPlayer)ため、完全移籍化に
    // あたって元の水準に戻す。そのままだと恒久的に割引契約のままになる。
    player.wage = (player.wage / 0.6).round().clamp(1, 999);
    player.contractYearsRemaining = ContractEngine.negotiatedYears(player);
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
      : ScoutingEngine.scoutCostFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        );

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
  int get scoutLevel =>
      _save == null ? 1 : _save!.infrastructure.staffLevel(StaffRole.scout);

  void _refreshScoutCandidates() {
    if (_save == null) {
      scoutCandidates = [];
      return;
    }
    final scoutLevel = _save!.infrastructure.staffLevel(StaffRole.scout);
    final count = ScoutingEngine.scoutCandidateCountFor(scoutLevel);
    scoutCandidates = List.generate(
      count,
      (_) => ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel),
    );
  }

  /// スカウト網を手動で更新する1回あたりの費用(万円)。
  int get scoutRefreshCost => _save == null
      ? 0
      : ScoutingEngine.refreshCostFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        );

  /// 費用を払ってスカウト網を更新し、候補選手の顔ぶれを一新する。
  /// 資金が足りない場合は何もせずfalseを返す。
  Future<bool> refreshScoutCandidates() async {
    if (_save == null) return false;
    final cost = scoutRefreshCost;
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
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
    final cost = ScoutingEngine.scoutCostFor(infra.staffLevel(StaffRole.scout));
    final maxP = ScoutingEngine.maxProspectsFor(
      infra.facilityLevel(FacilityType.youthFacility),
    );
    if (_save!.budget < cost) return false;
    if (_save!.youthProspects.length >= maxP) return false;
    _save!.budget -= cost;
    final signed = scoutCandidates.removeAt(idx);
    _save!.youthProspects.add(signed);
    final scoutLevel = infra.staffLevel(StaffRole.scout);
    scoutCandidates.add(
      ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel),
    );
    _notify();
    await _persist();
    return true;
  }

  Future<bool> promoteYouthProspect(String playerId) async {
    if (_save == null) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final idx = _save!.youthProspects.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.youthProspects.removeAt(idx);
    userTeam.players.add(player);
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
  Future<bool> signFreeAgent(String playerId) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    if (!isTransferWindowOpen) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final idx = _save!.freeAgents.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (!_wageBudgetAllowsSigning(_save!.freeAgents[idx].wage)) return false;
    final player = _save!.freeAgents.removeAt(idx);
    ContractEngine.renewContract(player);
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

  /// 自クラブの選手を期限付きで他クラブへローン放出する。放出中は週俸を放出先が
  /// 負担し、自クラブの試合には出場できない。スタメンだった場合は自動で欠員を埋める。
  /// 出場機会を約束させた貸出でクラブが受け取るレンタル料の割合。
  ///
  /// 0 は「受け取らない」。約束させるぶん、貸出先はこちらに払わない。
  static const int developmentLoanFeePercent = 0;

  /// 通常の貸出で受け取る週次のレンタル料の割合(市場価値に対する百分率)。
  static const int standardLoanFeePercent = 2;

  Future<bool> loanOutPlayer(
    String playerId,
    int weeks, {
    bool guaranteePlayingTime = false,
  }) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final team = userTeam;
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan || player.isLoanedOut) return false;

    final candidates =
        _save!.league.teams.where((t) => t.id != _save!.userTeamId).toList();
    if (candidates.isEmpty) return false;
    final destination = candidates[Random().nextInt(candidates.length)];

    player.loanedOutWeeksRemaining = weeks.clamp(
      GameState.loanOutMinWeeks,
      GameState.loanOutMaxWeeks,
    );
    player.loanedOutToClubName = destination.name;
    // 育成型かどうか。約束させると成長は大きいが、レンタル料は入らない。
    player.loanedWithPlayingTime = guaranteePlayingTime;
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

  /// プレシーズン親善試合(1試合分)を消化する。順位やカップ戦には影響しない。
  Future<MatchResult?> playFriendly(int index) async {
    if (_save == null) return null;
    if (index < 0 || index >= _save!.friendlies.length) return null;
    final f = _save!.friendlies[index];
    if (f.result != null) return null;
    final league = _save!.league;
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
    // MatchEngine.simulate()は内部でapplyPostMatchEffects()を呼び疲労蓄積・
    // 負傷判定を行ってしまうため、プレシーズン親善試合では使わない。前半・後半を
    // simulateMinutesで直接シミュレートし、疲労・負傷への影響を与えないようにする。
    final weather = WeatherEngine.roll();
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
    _save!.budget += offer.amount;
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
    final target = eligible[GameState._offerRng.nextInt(
        eligible.length < 5 ? eligible.length : 5)];

    final rivals = _save!.league.teams
        .where((t) => t.id != _save!.userTeamId)
        .toList();
    if (rivals.isEmpty) return null;
    final buyer = rivals[GameState._offerRng.nextInt(rivals.length)];

    return IncomingOffer(
      id: 'deadline${_incomingOfferSeq++}',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: buyer.name,
      amount: (target.marketValue * deadlineDayPremium).round(),
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
      o.weeksRemaining -= 1;
      if (o.weeksRemaining <= 0) {
        _save!.incomingOffers.remove(o);
      }
    }

    final team = userTeam;

    // 締切の節には、相場より高い駆け込みのオファーが入ることがある。
    // 期限があるだけでは判断が変わらない。締切間際に「今なら高く売れる」
    // 場面が来るから、期限を意識することになる。
    if (isTransferDeadlineMatchday) {
      final deadlineOffer = _rollDeadlineDayOffer(team);
      if (deadlineOffer != null) {
        _save!.incomingOffers.add(deadlineOffer);
        _logNews(
          Tr.pick(
              '締切間際: ${deadlineOffer.buyerClubName}が${deadlineOffer.playerName}に'
                  '${deadlineOffer.amount}万円を提示しました。',
              'Deadline day: ${deadlineOffer.buyerClubName} bid '
                  '${deadlineOffer.amount} for ${deadlineOffer.playerName}.'),
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
      if (biddablePlayerIds.isNotEmpty && GameState._offerRng.nextDouble() < 0.20) {
        final targetId =
            biddablePlayerIds[GameState._offerRng.nextInt(biddablePlayerIds.length)];
        final target = team.players.firstWhere((p) => p.id == targetId);
        final existing = offersByPlayer[targetId]!.first;
        final rivalCandidates = _save!.league.teams
            .where(
              (t) =>
                  t.id != _save!.userTeamId && t.name != existing.buyerClubName,
            )
            .toList();
        if (rivalCandidates.isNotEmpty) {
          final rival =
              rivalCandidates[GameState._offerRng.nextInt(rivalCandidates.length)];
          final outbid =
              (existing.amount * (1.1 + GameState._offerRng.nextDouble() * 0.2)).round();
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
      if (eligible.isNotEmpty && GameState._offerRng.nextDouble() < triggerChance) {
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
        final buyer =
            buyerCandidates[GameState._offerRng.nextInt(buyerCandidates.length)];

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
          _save!.budget += amount;
          autoSold.add(chosen.name);
        } else {
          final amount =
              (chosen.marketValue * (0.9 + GameState._offerRng.nextDouble() * 0.4))
                  .round();
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
