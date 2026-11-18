part of 'game_state.dart';

/// 評判・理事会・記者会見・ライバル・観客動員・財務(収入/週給予算/融資/定期預金)。
extension GameStateFinance on GameState {
  /// 監督としての世間の評価(0-100)。
  int get managerReputation => _save?.managerReputation ?? 50;

  /// ユーザークラブが現在所属するディビジョン(1が最上位、[totalDivisionTiers]が最下位)。
  int get currentDivisionTier => _save?.currentDivisionTier ?? 1;

  /// 画面表示用のリーグ名(2部以下所属時は「〇〇リーグ2部」のように部を付記する)。
  String get leagueDisplayName => currentDivisionTier == 1
      ? _save?.leagueName ?? Tr.pick('リーグ', 'League')
      : Tr.pick('${_save!.leagueName}$currentDivisionTier部',
          '${_save!.leagueName} tier $currentDivisionTier');

  /// 保存されているリーグ名から国風テーマを逆引きする(テーマ自体は
  /// SaveGameに保持していないため、開幕時に確定した表示名から復元する)。
  LeagueTheme get currentLeagueTheme => LeagueTheme.values.firstWhere(
        (t) => t.label == _save?.leagueName,
        orElse: () => LeagueTheme.england,
      );

  /// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴。新しい順。
  List<SeasonAward> get seasonAwards =>
      (_save?.seasonAwards ?? const <SeasonAward>[]).reversed.toList();

  List<SeasonRecord> get seasonHistory =>
      (_save?.seasonHistory ?? const <SeasonRecord>[]).reversed.toList();

  List<SeasonBestEleven> get bestElevenHistory =>
      (_save?.bestElevenHistory ?? const <SeasonBestEleven>[])
          .reversed
          .toList();

  /// 表示待ちのシーズン中盤理事会レビュー講評。ない場合はnull。
  String? get pendingBoardReviewMessage => _save?.pendingBoardReviewMessage;

  /// シーズン中盤理事会レビューの内容を確認済みにする。
  Future<void> dismissBoardReview() async {
    if (_save == null) return;
    _save!.pendingBoardReviewMessage = null;
    _notify();
    await _persist();
  }

  /// 回答待ちの記者会見の質問。ない場合はnull。
  PressQuestion? get pendingPressConference => _save?.pendingPressConference;

  /// 記者会見の質問に回答する。信頼度・選手全体の士気に選んだ選択肢の効果を反映する。
  Future<void> answerPressConference(int optionIndex) async {
    if (_save == null) return;
    final question = _save!.pendingPressConference;
    if (question == null ||
        optionIndex < 0 ||
        optionIndex >= question.options.length) {
      return;
    }
    final option = question.options[optionIndex];
    _save!.confidence = (_save!.confidence + option.confidenceDelta).clamp(
      0,
      100,
    );
    for (final p in userTeam.players) {
      p.morale = (p.morale + option.moraleDelta).clamp(0, 100);
    }
    _save!.pendingPressConference = null;
    _notify();
    await _persist();
  }

  /// 他クラブから監督就任オファーが届いている場合、そのクラブ。
  ///
  /// **相手が今のリーグに居なければ、オファーを消して null を返す。**
  /// 保留中に相手が昇降格で別のリーグへ移ると、`firstWhere` が投げて
  /// ホーム画面が開くたびに落ち、セーブが詰んでいた。
  Team? get pendingJobOfferTeam {
    final save = _save;
    if (save == null) return null;
    final teamId = save.pendingJobOfferTeamId;
    if (teamId == null) return null;
    final team = _findTeam(save.league.teams, teamId);
    if (team == null) save.pendingJobOfferTeamId = null;
    return team;
  }

  Future<bool> acceptJobOffer() async {
    if (_save == null || _save!.pendingJobOfferTeamId == null) return false;
    final newTeamId = _save!.pendingJobOfferTeamId!;
    final newTeam = _findTeam(_save!.league.teams, newTeamId);
    if (newTeam == null) {
      // 相手が別のリーグへ移った。オファーは成り立たないので消すだけ。
      _save!.pendingJobOfferTeamId = null;
      _notify();
      await _persist();
      return false;
    }
    final newTeamName = newTeam.name;
    _save!.userTeamId = newTeamId;
    _save!.pendingJobOfferTeamId = null;
    _save!.confidence = 60;
    _save!.shareholderExpectation = 60;
    _save!.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(_save!.league, newTeamId),
    );
    _save!.clubHistory.add(newTeamName);
    _notify();
    await _persist();
    return true;
  }

  Future<void> declineJobOffer() async {
    if (_save == null) return;
    _save!.pendingJobOfferTeamId = null;
    _notify();
    await _persist();
  }

  /// クラブを手放すことになった理由。迫られていなければ null。
  /// 両方が尽きたときはサポーターを先に見る(成績の責任が重い)。
  SaleReason? get saleReason {
    final save = _save;
    if (save == null) return null;
    if (save.confidence <= 0) return SaleReason.supporters;
    if (save.shareholderExpectation <= 0) return SaleReason.shareholders;
    return null;
  }

  /// いま追っているオーナーの目標。決めていなければ null。
  OwnerGoal? get ownerGoal => _save?.ownerGoal;

  /// 選べる目標。すでに1部にいるなら「1部へ昇格」は出さない。
  List<OwnerGoal> get selectableOwnerGoals => [
        for (final g in OwnerGoal.values)
          if (!(g == OwnerGoal.reachTopDivision && currentDivisionTier <= 1)) g,
      ];

  /// 達成した目標の記録(新しい順)。
  List<String> get achievedGoals =>
      (_save?.achievedGoals ?? const <String>[]).reversed.toList();

  /// 目標を決める。いまのシーズンから期限を数える。
  Future<void> setOwnerGoal(OwnerGoal goal) async {
    final save = _save;
    if (save == null || !selectableOwnerGoals.contains(goal)) return;
    save.ownerGoal = goal;
    save.ownerGoalStartSeason = save.league.season;
    save.ownerGoalStartValue = clubValue.total;
    _notify();
    await _persist();
  }

  /// 目標の期限までの残りシーズン数(今季を含む)。目標が無ければ 0。
  int get ownerGoalSeasonsLeft {
    final save = _save;
    final goal = save?.ownerGoal;
    if (save == null || goal == null) return 0;
    return (save.ownerGoalStartSeason + goal.deadlineSeasons - save.league.season)
        .clamp(0, goal.deadlineSeasons);
  }

  /// シーズン終了時に、目標の達成と期限切れを見る。達成は殿堂に残り、
  /// 2つの期待を少し持ち上げる。期限切れは目標が消えるだけで、罰は無い。
  void _evaluateOwnerGoal({required int season}) {
    final save = _save;
    final goal = save?.ownerGoal;
    if (save == null || goal == null) return;
    final recs =
        save.seasonHistory.where((r) => r.season >= save.ownerGoalStartSeason);
    final met = OwnerGoalRules.isMet(
      goal,
      wonTopLeague: recs.any((r) => r.wonLeague && r.divisionTier == 1),
      promotedOrTop: recs.any(
          (r) => r.divisionTier == 1 || (r.promoted && r.divisionTier == 2)),
      wonCup: recs.any((r) => r.cupsWon.isNotEmpty),
      budget: save.budget,
      valueRatio: save.ownerGoalStartValue > 0
          ? clubValue.total / save.ownerGoalStartValue
          : 0,
      topFourCount:
          recs.where((r) => r.divisionTier == 1 && r.finalRank <= 4).length,
      unbeaten: recs.any((r) => r.played > 0 && r.lost == 0),
      stadiumLevel: save.infrastructure.facilityLevel(FacilityType.stadium),
      healthScore: ClubHealthEngine.assess(
        supporter: save.confidence,
        shareholder: save.shareholderExpectation,
        wageRatio: save.ledgerFor(season).wageRatio,
        budget: save.budget,
      ).score,
      supporter: save.confidence,
      shareholder: save.shareholderExpectation,
    );
    if (met) {
      save.achievedGoals.add(Tr.pick(
          '${save.clubName}: ${goal.label}(シーズン$season)',
          '${save.clubName}: ${goal.label} (season $season)'));
      save.ownerGoal = null;
      save.confidence = (save.confidence + 10).clamp(0, 100);
      save.shareholderExpectation = (save.shareholderExpectation + 10).clamp(0, 100);
      _logNews(
        Tr.pick('オーナーの目標「${goal.label}」を達成しました。殿堂に残ります。',
            'Owner goal achieved: ${goal.label}. It joins your hall of fame.'),
        context: Tr.pick('オーナー', 'Owner'),
      );
    } else if (OwnerGoalRules.isExpired(goal,
        startSeason: save.ownerGoalStartSeason, season: season)) {
      save.ownerGoal = null;
      _logNews(
        Tr.pick('オーナーの目標「${goal.label}」は期限までに果たせませんでした。新しい目標を決められます。',
            'The owner goal "${goal.label}" was not reached in time. You can set a new one.'),
        context: Tr.pick('オーナー', 'Owner'),
      );
    }
  }

  /// 試合にオーナーは直接関わらない。先発と構えは、毎節かならず監督が決める。
  /// 穴(負傷・出場停止)を埋め、水準が高ければ相手との力関係から構えを、
  /// さらに高ければ最善の先発を選ぶ。
  void _managerPreparesMatch(Fixture next) {
    final save = _save;
    if (save == null) return;
    final user = userTeam;
    final oppId = next.homeTeamId == user.id ? next.awayTeamId : next.homeTeamId;
    final opp = _findTeam(save.league.teams, oppId);
    if (opp == null) return;
    final level = save.infrastructure.staffLevel(StaffRole.manager);
    // 監督の水準が高いほど任せられる。低い監督は穴埋めまで、中くらいは
    // 相手に合わせた構えまで、高い監督は最善の先発まで決める。
    if (level >= 4) {
      LineupUtils.autoFill(user);
    } else {
      LineupUtils.fillVacancies(user);
    }
    if (level >= 3) {
      user.mentality = CpuTacticsAI.mentalityFor(
        ownRating: user.overallRating,
        opponentRating: opp.overallRating,
      );
    }
  }

  /// 判断待ちの事件。無ければ null。
  OwnerEventKind? get pendingOwnerEvent => _save?.pendingOwnerEvent;

  /// 事件が起きる節。1シーズンに3回(12節ごと、6・18・30節)。
  static bool isOwnerEventMatchday(int matchday) =>
      matchday > 0 && matchday % 12 == 6;

  /// その節に事件が起きるなら、判断待ちに積む。すでに待っている事件があれば
  /// 積まない(判断を溜めさせない)。
  void _maybeRaiseOwnerEvent(int matchday) {
    final save = _save;
    if (save == null || save.pendingOwnerEvent != null) return;
    if (!GameStateFinance.isOwnerEventMatchday(matchday)) return;
    final kinds = OwnerEventKind.values;
    save.pendingOwnerEvent =
        kinds[Random(save.league.season * 1000 + matchday).nextInt(kinds.length)];
  }

  /// 事件に答える。選んだ答えの期待と資金の増減を反映する。
  Future<bool> resolveOwnerEvent(int optionIndex) async {
    final save = _save;
    final kind = save?.pendingOwnerEvent;
    if (save == null || kind == null) return false;
    final options = kind.options;
    if (optionIndex < 0 || optionIndex >= options.length) return false;
    final o = options[optionIndex];
    save.confidence = (save.confidence + o.supportersDelta).clamp(0, 100);
    save.shareholderExpectation =
        (save.shareholderExpectation + o.shareholdersDelta).clamp(0, 100);
    _book(LedgerCategory.other, scaledMoney(o.fundsDelta));
    save.pendingOwnerEvent = null;
    _notify();
    await _persist();
    return true;
  }

  /// オーナーの仕事を、いま打てるか。今季すでに打っている・資金が足りない
  /// ときは打てない。
  bool canDoOwnerWork(OwnerWork work) {
    final save = _save;
    if (save == null) return false;
    if (save.ownerWorkDoneSeason[work.id] == save.league.season) return false;
    if (work.onlyInRed && save.budget >= 0) return false;
    // 支出が要らない手は、資金がマイナスでも打てる(危機の手がそう)。
    return work.cost == 0 || save.budget >= scaledMoney(work.cost);
  }

  /// 今季すでに打った仕事か。
  bool ownerWorkDoneThisSeason(OwnerWork work) {
    final save = _save;
    return save != null && save.ownerWorkDoneSeason[work.id] == save.league.season;
  }

  /// オーナーの仕事を打つ。資金と2つの期待に反映し、今季は打ち止めにする。
  Future<bool> doOwnerWork(String id) async {
    final save = _save;
    if (save == null) return false;
    final work = ownerWorks.where((w) => w.id == id).firstOrNull;
    if (work == null || !canDoOwnerWork(work)) return false;
    save.confidence = (save.confidence + work.supporters).clamp(0, 100);
    save.shareholderExpectation =
        (save.shareholderExpectation + work.shareholders).clamp(0, 100);
    _book(LedgerCategory.other, scaledMoney(work.funds));
    save.ownerWorkDoneSeason[work.id] = save.league.season;
    _notify();
    await _persist();
    return true;
  }

  /// 提携クラブ。いなければ null。
  Team? get partnerClub {
    final save = _save;
    final id = save?.partnerClubId;
    if (save == null || id == null) return null;
    return save.league.teams.where((t) => t.id == id).firstOrNull;
  }

  /// 提携できる相手(自クラブ以外)。
  List<Team> get partnerCandidates {
    final save = _save;
    if (save == null) return const [];
    return save.league.teams.where((t) => t.id != save.userTeamId).toList();
  }

  /// 他クラブと提携する。すでに提携していれば結び直す。自クラブや
  /// 存在しないクラブとは結べない。
  Future<bool> setPartnerClub(String teamId) async {
    final save = _save;
    if (save == null) return false;
    if (teamId == save.userTeamId) return false;
    final team = save.league.teams.where((t) => t.id == teamId).firstOrNull;
    if (team == null) return false;
    save.partnerClubId = teamId;
    _logNews(
        Tr.pick('${team.name}と提携した。毎季の提携費は${formatMoney(partnerSeasonCost)}。',
            'Partnered with ${team.name}. The fee is ${formatMoney(partnerSeasonCost)} per season.'),
        context: Tr.pick('提携', 'Partnership'));
    _notify();
    await _persist();
    return true;
  }

  /// 毎季の提携費(今の部の規模)。
  int get partnerSeasonCost => scaledMoney(PartnerClubEngine.seasonCost);

  /// 提携を解消する。
  Future<void> clearPartnerClub() async {
    final save = _save;
    if (save == null || save.partnerClubId == null) return;
    save.partnerClubId = null;
    _notify();
    await _persist();
  }

  /// シーズン終了時の提携の処理。提携費を払い、2つの期待を上げる。
  /// 払えなければ提携は解消される。
  void _settlePartnerClub() {
    final save = _save!;
    final team = partnerClub;
    if (team == null) {
      save.partnerClubId = null;
      return;
    }
    if (save.budget < partnerSeasonCost) {
      save.partnerClubId = null;
      _logNews(
          Tr.pick('資金が足りず、${team.name}との提携は解消された。',
              'The partnership with ${team.name} lapsed for lack of funds.'),
          context: Tr.pick('提携', 'Partnership'));
      return;
    }
    _book(LedgerCategory.other, -partnerSeasonCost);
    save.confidence =
        (save.confidence + PartnerClubEngine.supportersBonus).clamp(0, 100);
    save.shareholderExpectation = (save.shareholderExpectation +
            PartnerClubEngine.shareholdersBonus)
        .clamp(0, 100);
    _logNews(
        Tr.pick('${team.name}との提携で、知名度が上がった。',
            'The partnership with ${team.name} raised our profile.'),
        context: Tr.pick('提携', 'Partnership'));
  }

  /// テスト用: 提携の季末の処理だけを走らせる。
  @visibleForTesting
  void debugSettlePartnerClub() => _settlePartnerClub();

  /// テスト用: 今日を [day] まで進める(あいだの給与日・入金日も処理する)。
  @visibleForTesting
  void debugAdvanceTodayTo(DateTime day) => _advanceTodayTo(day);

  /// 日付で終わるローンを今日の日付で片付ける(テスト用)。
  @visibleForTesting
  void debugSettleLoansByDate() => _settleLoansByDate();

  /// 次の節に打つと決めた試合日のイベント。無ければ null。
  MatchdayPromo? get activeMatchdayPromo {
    final id = _save?.matchdayPromoId;
    if (id == null) return null;
    return matchdayPromos.where((p) => p.id == id).firstOrNull;
  }

  /// 次の節の試合日のイベントを決める。費用を先に払う。すでに決めていれば
  /// 先に取り消さないと決められない。資金が足りなくても決められない。
  Future<bool> setMatchdayPromo(String id) async {
    final save = _save;
    if (save == null || save.matchdayPromoId != null) return false;
    final promo = matchdayPromos.where((p) => p.id == id).firstOrNull;
    if (promo == null) return false;
    final cost = scaledMoney(promo.cost);
    if (cost > 0 && save.budget < cost) return false;
    if (cost > 0) _book(LedgerCategory.other, -cost);
    save.matchdayPromoId = promo.id;
    _notify();
    await _persist();
    return true;
  }

  /// 決めた試合日のイベントを取り消す。節の前なので、費用は戻る。
  Future<bool> cancelMatchdayPromo() async {
    final save = _save;
    final promo = activeMatchdayPromo;
    if (save == null || promo == null) return false;
    final cost = scaledMoney(promo.cost);
    if (cost > 0) _book(LedgerCategory.other, cost);
    save.matchdayPromoId = null;
    _notify();
    await _persist();
    return true;
  }

  /// 節を終えたとき、試合日のイベントの効きを2つの期待に反映して使い切る。
  void _consumeMatchdayPromo() {
    final save = _save!;
    final promo = activeMatchdayPromo;
    if (promo == null) {
      save.matchdayPromoId = null;
      return;
    }
    save.confidence = (save.confidence + promo.supporters).clamp(0, 100);
    save.shareholderExpectation =
        (save.shareholderExpectation + promo.shareholders).clamp(0, 100);
    save.matchdayPromoId = null;
  }

  /// テスト用: 節を終えたときの試合日のイベントの処理だけを走らせる。
  @visibleForTesting
  void debugConsumeMatchdayPromo() => _consumeMatchdayPromo();

  /// テスト用: その節の事件の判定だけを走らせる。
  @visibleForTesting
  void debugRaiseOwnerEvent(int matchday) => _maybeRaiseOwnerEvent(matchday);

  /// テスト用: シーズン終了時の規則の判定だけを走らせる。
  @visibleForTesting
  void debugEnforceLeagueRules() => _enforceLeagueRules();

  /// テスト用: 週給の予算と補強禁止を見る判定だけを走らせる。
  @visibleForTesting
  bool debugAllowsSigning(int wage) => _wageBudgetAllowsSigning(wage);

  /// テスト用: 監督のふだんの試合の準備だけを走らせる。
  @visibleForTesting
  void debugManagerPreparesMatch(Fixture next) => _managerPreparesMatch(next);

  /// テスト用: シーズン終了時の目標の判定だけを走らせる。
  @visibleForTesting
  void debugEvaluateOwnerGoal({required int season}) =>
      _evaluateOwnerGoal(season: season);

  /// サポーターか株主の期待が尽き、クラブを手放さなければならない状態か。
  bool get isSaleForced => saleReason != null;

  /// 手放したあとに買い直せるクラブの候補(最大3つ)。いまのリーグから、
  /// 総合力の下位・中位・上位に1つずつ。強いほど資金の立て直しが楽だが、
  /// 期待も重い。
  List<Team> get buyoutCandidates {
    final save = _save;
    if (save == null) return const [];
    final others = save.league.teams.where((t) => t.id != save.userTeamId).toList()
      ..sort((a, b) => a.overallRating.compareTo(b.overallRating));
    if (others.length <= 3) return others;
    return [others.first, others[others.length ~/ 2], others.last];
  }

  /// 手放すクラブの実績(殿堂に残す1行)。
  OwnerLegacy _legacyOfCurrentClub(SaleReason reason) {
    final save = _save!;
    final mine =
        save.seasonHistory.where((r) => r.clubName == save.clubName).toList();
    final ranks = mine.map((r) => r.finalRank).where((r) => r > 0);
    return OwnerLegacy(
      clubName: save.clubName,
      seasons: mine.length,
      leagueTitles: mine.where((r) => r.wonLeague).length,
      cupTitles: mine.fold<int>(0, (t, r) => t + r.cupsWon.length),
      bestRank: ranks.isEmpty ? 0 : ranks.reduce((a, b) => a < b ? a : b),
      reason: reason,
    );
  }

  /// 売却を迫られたクラブを手放し、[teamId] を買い直す。
  ///
  /// 実績は殿堂に残る。新しいクラブでは2つの期待が60に戻り、資金・施設・
  /// スタッフ・融資・スポンサーは初期の状態から始める(予算の配り方は引き継ぐ)。
  Future<bool> buyClub(String teamId) async {
    final save = _save;
    final reason = saleReason;
    if (save == null || reason == null) return false;
    final team = _findTeam(save.league.teams, teamId);
    if (team == null || team.id == save.userTeamId) return false;

    save.ownerLegacies.add(_legacyOfCurrentClub(reason));
    save.userTeamId = team.id;
    save.clubName = team.name;
    save.pendingJobOfferTeamId = null;
    save.confidence = 60;
    save.shareholderExpectation = 60;
    save.ownerShare = 100;
    save.budget = (scaledMoney(GameState.initialBudgetTier5) *
            save.difficulty.initialBudgetFactor)
        .round();
    save.infrastructure = ClubInfrastructure();
    save.sponsorDeal = null;
    save.bankLoans = [];
    save.youthProspects = [];
    save.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(save.league, team.id),
    );
    save.wageBudget = BoardEngine.wageBudgetFor(
      tier: save.currentDivisionTier,
      currentWeeklyWageBill: weeklyWageBill,
    );
    save.clubHistory.add(team.name);
    // クラブ価値は新しいクラブのものとして数え直す。
    save.clubValueHistory.clear();
    if (save.ownerGoal == OwnerGoal.clubValue) {
      save.ownerGoalStartValue = clubValue.total;
    }
    _refreshStaffCandidates();
    _notify();
    await _persist();
    return true;
  }

  /// 別の国のクラブを新しく立ち上げて、続きを遊ぶ。その国の規則に従い、
  /// 新しい国のピラミッド(5部制)の4部から始まる。実績は殿堂に残る。
  Future<bool> buyClubInCountry(LeagueTheme theme) async {
    final save = _save;
    final reason = saleReason;
    if (save == null || reason == null) return false;
    if (theme == currentLeagueTheme) return false;
    const startTier = 4;
    final rng = Random();
    final names =
        NamePool.themedClubNames(
            theme, theme.teamsByTier.fold<int>(0, (a, n) => a + n));
    var ni = 0;
    String nextName() => names[ni++];
    int strengthForTier(int tier) => rollDivisionStrength(tier, rng);

    save.ownerLegacies.add(_legacyOfCurrentClub(reason));

    final userTeam = PlayerGenerator.generateSquad(
        id: 'user', name: nextName(), strengthTier: 60);
    final others = List<League?>.filled(totalDivisionTiers, null);
    League? mine;
    final cpuInMine = <Team>[];
    for (var tier = 1; tier <= totalDivisionTiers; tier++) {
      final teams = <Team>[
        if (tier == startTier) userTeam,
        for (var i = 0;
            i <
                (tier == startTier
                    ? theme.teamsInTier(tier) - 1
                    : theme.teamsInTier(tier));
            i++)
          PlayerGenerator.generateSquad(
            id: tier == startTier ? 'cpu$i' : 'div${tier}_$i',
            name: nextName(),
            strengthTier: strengthForTier(tier),
          ),
      ];
      for (final t in teams) {
        LineupUtils.autoFill(t);
      }
      final league = League(
        teams: teams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(teams),
        season: save.league.season,
      );
      if (tier == startTier) {
        mine = league;
        cpuInMine.addAll(teams.where((t) => t.id != 'user'));
      } else {
        others[tier - 1] = league;
      }
    }

    save.userTeamId = 'user';
    save.clubName = userTeam.name;
    save.leagueName = theme.label;
    save.ruleSet = RuleSet.forTheme(theme);
    save.league = mine!;
    save.otherDivisionLeagues = others;
    save.currentDivisionTier = startTier;
    _ensureWorldSquads(save);
    save.cups = [
      CupEngine.createKnockout(
        type: CupType.domestic,
        name: theme.domesticCupName,
        teamIds: mine.teams.map((t) => t.id).toList(),
      ),
    ];
    save.continentalCup = null;
    save.continentalTeams = [];
    save.friendlies = _generateFriendlies(mine.teams, 'user');
    // 新しい国のリーグは開幕前から始まる。日付もそのシーズンのオフに戻す。
    save.today = SeasonCalendar.preseasonDate(save.league.season);
    final rival = cpuInMine[rng.nextInt(cpuInMine.length)];
    save.rivalTeamId = rival.id;
    save.rivalTeamName = rival.name;
    save.rivalPast = [0, 0, 0];
    save.pendingJobOfferTeamId = null;
    save.pendingOwnerEvent = null;
    save.pendingPressConference = null;
    save.pendingContractNegotiation = null;
    save.incomingOffers = [];
    save.proposals = [];
    save.declinedProposalIds = [];
    save.confidence = 60;
    save.shareholderExpectation = 60;
    save.ownerShare = 100;
    save.budget = (scaleMoneyForTier(startTier, GameState.initialBudgetTier5) *
            save.difficulty.initialBudgetFactor)
        .round();
    save.infrastructure = ClubInfrastructure();
    save.sponsorDeal = null;
    save.namingDeal = null;
    save.pendingNamingOffers = [];
    save.pendingSponsorOffers = SponsorEngine.generateOffers(
        userTeam.overallRating,
        tier: startTier);
    save.economyVersion = SaveGame.currentEconomyVersion;
    save.tvHolidaySeasons = 0;
    save.bankLoans = [];
    save.youthProspects = [];
    save.projects = {};
    save.advisors = {};
    save.communityLevel = 0;
    save.reserveFund = 0;
    save.insured = false;
    save.retiredLegends.clear();
    save.retiredNumberIds.clear();
    save.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(save.league, 'user'),
    );
    save.boardCupTargetRound = _estimateDomesticCupTarget();
    save.wageBudget = BoardEngine.wageBudgetFor(
      tier: startTier,
      currentWeeklyWageBill: weeklyWageBill,
    );
    save.clubHistory.add(userTeam.name);
    save.clubValueHistory.clear();
    if (save.ownerGoal == OwnerGoal.clubValue) {
      save.ownerGoalStartValue = clubValue.total;
    }
    transferMarket = [];
    _refreshScoutCandidates();
    _refreshStaffCandidates();
    _addTimeline(Tr.pick('${theme.label}(${theme.flavorLabel})で新しいクラブ${userTeam.name}を立ち上げた',
        'Founded ${userTeam.name} in the ${theme.label}'));
    _notify();
    await _persist();
    return true;
  }

  /// ライバルクラブ(開幕時に決定、以後固定)。未設定の場合はnull。
  Team? get rivalTeam {
    final id = _save?.rivalTeamId;
    if (id == null) return null;
    try {
      return _save!.league.teams.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 今シーズンの宿敵との戦績(終わった試合だけ)。
  ({int won, int draw, int lost}) get rivalRecordThisSeason {
    final save = _save;
    if (save == null) return (won: 0, draw: 0, lost: 0);
    var w = 0, d = 0, l = 0;
    for (final f in save.league.fixtures) {
      final r = f.result;
      if (r == null || !isRivalFixture(f)) continue;
      final mine = f.homeTeamId == save.userTeamId ? r.homeGoals : r.awayGoals;
      final theirs = f.homeTeamId == save.userTeamId ? r.awayGoals : r.homeGoals;
      if (mine > theirs) {
        w++;
      } else if (mine == theirs) {
        d++;
      } else {
        l++;
      }
    }
    return (won: w, draw: d, lost: l);
  }

  /// 宿敵との通算の戦績(過去のシーズン+今季)。
  ({int won, int draw, int lost}) get rivalRecord {
    final save = _save;
    if (save == null) return (won: 0, draw: 0, lost: 0);
    final now = rivalRecordThisSeason;
    final past = save.rivalPast;
    return (
      won: past[0] + now.won,
      draw: past[1] + now.draw,
      lost: past[2] + now.lost,
    );
  }

  /// シーズン末に、今季の宿敵との戦績を通算へ足す。
  void _closeRivalSeason() {
    final save = _save!;
    final now = rivalRecordThisSeason;
    if (now.won + now.draw + now.lost == 0) return;
    save.rivalPast[0] += now.won;
    save.rivalPast[1] += now.draw;
    save.rivalPast[2] += now.lost;
    if (now.won >= 2 && now.lost == 0) {
      _addTimeline(Tr.pick('宿敵に今季は負けなし(${now.won}勝${now.draw}分)',
          'Unbeaten against the rivals this season (${now.won}W ${now.draw}D)'));
    }
  }

  /// 指定した対戦カードが自クラブ対ライバルクラブの「ダービー」かどうか。
  bool isRivalFixture(Fixture f) {
    final rivalId = _save?.rivalTeamId;
    if (rivalId == null) return false;
    final userId = _save!.userTeamId;
    return (f.homeTeamId == userId && f.awayTeamId == rivalId) ||
        (f.homeTeamId == rivalId && f.awayTeamId == userId);
  }

  /// 観客動員率(0.0-1.0)。監督への信頼度と現在の順位に連動する(強豪・高信頼ほど満員に近づく)。
  double get userAttendanceFactor {
    if (_save == null) return 0.0;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final teamCount = league.teams.length;
    var factor =
        (0.7 + _save!.confidence / 250 + (teamCount - rank) / teamCount * 0.3)
            .clamp(0.6, 1.4);
    // 下位ディビジョンほど観客動員が少ない(ティアごとに段階的に低下する)。
    factor *= pow(0.8, _save!.currentDivisionTier - 1).toDouble();
    factor *= _save!.ticketPricing.attendanceMultiplier;
    return factor.clamp(0.0, 1.0);
  }

  /// 自クラブのスタジアム収容人数。
  int get stadiumCapacity => _save == null
      ? 0
      : ClubInfrastructure.stadiumCapacity(
          _save!.infrastructure.facilityLevel(FacilityType.stadium),
        );

  /// 通常開催時に見込まれる観客動員数(収容人数 x 動員率)。
  int get expectedAttendance =>
      (stadiumCapacity * userAttendanceFactor).round();

  int weeklyIncomeFor(String teamId) {
    final p = weeklyIncomeParts(teamId);
    return p.gate + p.sponsor + p.merchandise + p.broadcast;
  }

  /// 5部の額 [base] を、今いる部の規模に直す。費用・賞金など「クラブの
  /// 規模で決まる額」は、記帳と画面の表示の両方がここを通る(片方だけ
  /// 直すと、表示と実際に動く額がずれる)。
  int scaledMoney(int base) => scaleMoneyForTier(currentDivisionTier, base);

  /// [tier] 部の規模に直した額。シーズン末の精算のように、部が変わる
  /// 前の部で数えたいときに使う。
  int scaledMoneyFor(int tier, int base) => scaleMoneyForTier(tier, base);

  /// 1シーズンの節の数(国によって部のクラブ数が違うので一定ではない)。
  int get matchdaysPerSeason {
    final save = _save;
    if (save == null) return 38;
    final n = save.league.fixtures
        .fold<int>(0, (m, f) => f.matchday > m ? f.matchday : m);
    return n > 0 ? n : 38;
  }

  /// 毎節入る放映権料(万円)。部で決まり、順位や施設では変わらない。
  int get weeklyBroadcastIncome => weeklyBroadcast(currentDivisionTier,
      matchdays: matchdaysPerSeason);

  /// 選手の給与を毎節いくら払うか。表示の年俸(週俸×52)と1年に払う
  /// 総額が一致するよう、52週ぶんをその年の節の数で割る。
  int get matchdayPlayerWageCost => _save == null
      ? 0
      : perMatchdayFromWeekly(
          ContractEngine.weeklyWageBill(userTeam), matchdaysPerSeason);

  /// スタッフの給与を毎節いくら払うか(選手と同じく年額を節で割る)。
  int get matchdayStaffWageCost => _save == null
      ? 0
      : perMatchdayFromWeekly(
          scaledMoney(_save!.infrastructure.totalStaffWeeklyWage),
          matchdaysPerSeason);

  /// 選手の給与を毎月末にいくら払うか(年俸の12分の1)。
  int get monthlyPlayerWageCost => _save == null
      ? 0
      : MoneyCalendar.monthlyFromWeekly(
          ContractEngine.weeklyWageBill(userTeam));

  /// スタッフの給与を毎月末にいくら払うか。
  int get monthlyStaffWageCost => _save == null
      ? 0
      : MoneyCalendar.monthlyFromWeekly(
          scaledMoney(_save!.infrastructure.totalStaffWeeklyWage));

  /// 今日が [before] から [after] へ進んだあいだのお金の日(給与の月末・
  /// 放映権の入金日)を、日付の順に処理する。
  void _settleMoneyDates(DateTime before, DateTime after) {
    final events = <(DateTime, bool)>[
      for (final d in MoneyCalendar.monthEndsBetween(before, after)) (d, true),
      for (final d in MoneyCalendar.broadcastDatesBetween(before, after))
        (d, false),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (day, isWage) in events) {
      if (isWage) {
        _book(LedgerCategory.staffWages, -monthlyStaffWageCost);
        _book(LedgerCategory.playerWages, -monthlyPlayerWageCost);
      } else {
        _book(LedgerCategory.broadcast, broadcastInstallmentOn(day));
      }
    }
  }

  /// [day] の放映権の入金額(入金日でなければ0)。今いる部の年額の4分の1。
  int broadcastInstallmentOn(DateTime day) {
    final i = MoneyCalendar.broadcastIndexOf(day);
    if (i == null) return 0;
    return MoneyCalendar.broadcastInstallment(
        annualBroadcast(currentDivisionTier), i);
  }

  /// 第[matchday]節が祝日なら、その祝日の名前。
  String? holidayOfMatchday(int matchday) => MoneyCalendar.holidayName(
      dateOfMatchday(matchday), currentLeagueTheme);

  /// 第[matchday]節の試合の日に入る見込みの収入(観客・スポンサー・グッズ。
  /// 祝日なら客が増える。放映権は入金日に別に入る)。
  int expectedMatchdayIncome(int matchday) {
    if (_save == null) return 0;
    final p = weeklyIncomeParts(_save!.userTeamId);
    final income = p.gate + p.sponsor + p.merchandise;
    if (holidayOfMatchday(matchday) == null) return income;
    final base = expectedAttendance;
    return GameState.derbyAdjustedIncome(
      income,
      baseAttendance: base,
      actualAttendance:
          MoneyCalendar.holidayAttendance(base, stadiumCapacity),
    );
  }

  /// 今日より後のお金の予定(給与日・放映権の入金日・リーグ戦の日)を
  /// 日付の順に [count] 件。
  List<({DateTime date, String label, int amount})> upcomingMoneyDates(
      {int count = 8}) {
    final save = _save;
    if (save == null) return const [];
    final from = today;
    final horizon = DateTime(from.year + 1, from.month, from.day);
    final wages = monthlyPlayerWageCost + monthlyStaffWageCost;
    final out = <({DateTime date, String label, int amount})>[
      for (final d in MoneyCalendar.monthEndsBetween(from, horizon))
        (
          date: d,
          label: Tr.pick('給与の支払い(選手・スタッフ)', 'Wages paid (players and staff)'),
          amount: -wages,
        ),
      for (final d in MoneyCalendar.broadcastDatesBetween(from, horizon))
        (
          date: d,
          label: Tr.pick(
              '放映権の入金(${MoneyCalendar.broadcastIndexOf(d)! + 1}/4回目)',
              'Broadcast payment (${MoneyCalendar.broadcastIndexOf(d)! + 1} of 4)'),
          amount: broadcastInstallmentOn(d),
        ),
    ];
    final seen = <int>{};
    for (final f in save.league.fixtures) {
      if (f.result != null) continue;
      if (f.homeTeamId != save.userTeamId && f.awayTeamId != save.userTeamId) {
        continue;
      }
      if (!seen.add(f.matchday)) continue;
      final d = dateOfMatchday(f.matchday);
      if (!d.isAfter(from) && d != from) continue;
      final holiday = holidayOfMatchday(f.matchday);
      out.add((
        date: d,
        label: holiday == null
            ? Tr.pick('第${f.matchday}節の試合の収入', 'Matchday ${f.matchday} income')
            : Tr.pick('第${f.matchday}節の試合の収入($holiday・客が増える)',
                'Matchday ${f.matchday} income ($holiday, bigger crowd)'),
        amount: expectedMatchdayIncome(f.matchday),
      ));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out.take(count).toList();
  }

  /// 資金が動く唯一の入口。資金を増減させ、同じ額をそのシーズンの収支の
  /// 記録に残す。ここを通さずに資金だけ動かすと、損益計算書の合計が実際の
  /// 資金とずれる。収入は正、支出は負で渡す。
  void _book(LedgerCategory category, int delta) {
    final save = _save!;
    save.budget += delta;
    save.ledgerFor(save.league.season).add(category, delta);
  }

  /// 週の収入の内訳(観客・スポンサー・グッズ・放映権)。合計は
  /// [weeklyIncomeFor] と必ず一致する(端数はグッズに寄せる)。他クラブは
  /// 観客収入と放映権だけを持つ。
  ///
  /// 観客とグッズは今いる部の規模([incomeScale])を掛ける。スポンサーと
  /// 命名権は、結んだときの部の規模で契約の額が決まっている(昇格しても
  /// 契約が切れるまでは前の額のまま)ので、ここでは掛けない。
  ({int gate, int sponsor, int merchandise, int broadcast}) weeklyIncomeParts(
      String teamId) {
    if (_save == null) {
      return (gate: 0, sponsor: 0, merchandise: 0, broadcast: 0);
    }
    final scale = incomeScale(currentDivisionTier);
    final broadcast = weeklyBroadcastIncome;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == teamId) + 1;
    final teamCount = league.teams.length;
    final rankBonus = ((teamCount - rank) * 20).clamp(0, 999);
    final base = 150 + rankBonus;
    if (teamId != _save!.userTeamId) {
      return (
        gate: (base * scale).round(),
        sponsor: 0,
        merchandise: 0,
        broadcast: broadcast,
      );
    }

    final stadiumLevel = _save!.infrastructure.facilityLevel(
      FacilityType.stadium,
    );
    final commercialMultiplier = ClubInfrastructure.commercialRevenueMultiplier(
      _save!.infrastructure.facilityLevel(FacilityType.commercialFacility),
    );
    var matchdayIncome = ((base + (stadiumLevel - 1) * 80) *
            userAttendanceFactor *
            _save!.ticketPricing.revenueMultiplier *
            FacilityInvestmentEngine.gateMultiplier(_save!.facilityMomentum) *
            (activeMatchdayPromo?.gateMultiplier ?? 1.0) *
            commercialMultiplier *
            scale)
        .round();
    // 2部リーグは1部より観客動員が少ない(userAttendanceFactorに反映済み)。
    final sponsorIncome = (((_save!.sponsorDeal?.weeklyIncome ?? 0) +
                (_save!.namingDeal?.weeklyIncome ?? 0)) *
            commercialMultiplier)
        .round();
    // グッズ収入(マーチャンダイジング)。試合の有無に関わらず、監督の評価
    // (=クラブの知名度)が高いほど、商業施設が充実しているほど増える。
    // チケット・スポンサーだけに依存しない収入源として資金繰りを下支えする。
    final merchandiseIncome = ((40 +
                managerReputation +
                ProjectEngine.weeklyMerchandiseBonus(
                    _save!.projects, managerReputation)) *
            commercialMultiplier *
            scale)
        .round();
    // 営業の配分を厚くすると収入が増え、削ると減る(初期の配分で1倍)。
    final boost = _save!.marketingBoostWeeks > 0
        ? GameStateSquad.marketingBoostMultiplier
        : 1.0;
    final factor = BudgetEngine.incomeMultiplier(_save!.budgetPlan) *
        PolicyEngine.incomeMultiplier(_save!.clubPolicy) *
        AdvisorEngine.incomeMultiplier(_save!.advisors[Advisor.finance.name] ?? 0) *
        _save!.economyPhase.incomeMultiplier *
        boost;
    final total =
        ((matchdayIncome + sponsorIncome + merchandiseIncome) * factor).round();
    final gate = (matchdayIncome * factor).round();
    final sponsor = (sponsorIncome * factor).round();
    return (
      gate: gate,
      sponsor: sponsor,
      merchandise: total - gate - sponsor,
      broadcast: broadcast,
    );
  }

  /// 年の予算の配分(補強・育成・施設・営業・配当)。
  BudgetPlan get budgetPlan => _save?.budgetPlan ?? BudgetPlan.balanced();

  /// 年の予算の総額(万円)。今の週収入が1シーズン続いた場合の見込み。
  int get annualBudgetPool => _save == null
      ? 0
      : BudgetEngine.annualPool(weeklyIncome: weeklyIncomeFor(_save!.userTeamId));

  /// [category] の配分を [share]% にする。残りの配り先は比率に応じて
  /// 分け直され、合計は100のまま。
  Future<void> setBudgetShare(BudgetCategory category, int share) async {
    if (_save == null) return;
    _save!.budgetPlan = _save!.budgetPlan.withShare(category, share);
    _notify();
    await _persist();
  }

  /// このクラブのいる国の財務規則。
  RuleSet get ruleSet => _save?.ruleSet ?? RuleSet.britain;

  /// 規則の今の状況。今シーズンを終えたらどの罰を受けるかも含む。
  RuleReport get ruleReport => _save == null
      ? const RuleReport(statuses: [])
      : RulesEngine.evaluate(
          ruleSet: ruleSet,
          tier: _save!.currentDivisionTier,
          ledgers: [
            for (final l in _save!.ledgers)
              if (l.season <= _save!.league.season) l,
          ],
          budget: _save!.budget,
        );

  /// 規則違反の罰で補強が禁止されているか。
  bool get isTransferBanned => (_save?.transferBanSeasons ?? 0) > 0;

  /// シーズン終了時に規則を当て、違反なら罰を科す。
  void _enforceLeagueRules() {
    final save = _save!;
    // 前の罰の期間を1季進める。
    if (save.transferBanSeasons > 0) save.transferBanSeasons -= 1;
    final penalty = ruleReport.penalty;
    if (penalty == null) return;
    if (save.league.season <= RulesEngine.graceSeasons) {
      _logNews(
        Tr.pick(
            '${ruleSet.label}の規則に違反する状態です(${penalty.reason})。最初のシーズンは猶予されますが、来季からは罰を受けます。',
            'You are in breach of the ${ruleSet.label} rules (${penalty.reason}). The first season is a grace period; from next season you will be penalised.'),
        context: Tr.pick('リーグの規則', 'League rules'),
      );
      return;
    }
    final fine = (penalty.fine *
            AdvisorEngine.fineMultiplier(
                save.advisors[Advisor.legal.name] ?? 0))
        .round();
    if (fine > 0) _book(LedgerCategory.other, -fine);
    save.confidence = (save.confidence - penalty.trustLoss).clamp(0, 100);
    save.transferBanSeasons = max(save.transferBanSeasons, penalty.banSeasons);
    save.pendingPointsDeduction += penalty.pointsDeduction;
    final parts = <String>[
      if (fine > 0) Tr.pick('罰金${formatMoney(fine)}', 'fine of ${formatMoney(fine)}'),
      if (penalty.pointsDeduction > 0)
        Tr.pick('来季の勝ち点${penalty.pointsDeduction}剥奪',
            '${penalty.pointsDeduction} points docked next season'),
      if (penalty.banSeasons > 0)
        Tr.pick('補強禁止${penalty.banSeasons}季', 'signing ban'),
    ];
    _logNews(
      Tr.pick('${ruleSet.label}の規則違反: ${penalty.reason}。${parts.join('、')}。',
          '${ruleSet.label} breach: ${penalty.reason}. ${parts.join(', ')}.'),
      context: Tr.pick('リーグの規則', 'League rules'),
    );
  }

  /// 年表に1行足す。直近200行だけ残す。
  void _addTimeline(String text) {
    final save = _save!;
    save.timeline.add(TimelineEntry(season: save.league.season, text: text));
    while (save.timeline.length > 200) {
      save.timeline.removeAt(0);
    }
  }

  /// 新規開始のシナリオを、初期の資金・期待・施設に反映する。
  void _applyScenario(StartScenario scenario) {
    final save = _save!;
    switch (scenario) {
      case StartScenario.standard:
        break;
      case StartScenario.debt:
        save.budget = -(GameState.initialBudgetTier5 ~/ 4);
        save.shareholderExpectation = 45;
      case StartScenario.patron:
        save.budget = save.budget * 3;
        save.shareholderExpectation = 70;
        save.boardTargetRank = (save.boardTargetRank - 2).clamp(1, 99);
      case StartScenario.academy:
        save.budget = (save.budget * 0.7).round();
        save.infrastructure.facilityLevels[FacilityType.youthFacility] = 3;
        save.infrastructure.facilityLevels[FacilityType.trainingGround] = 2;
    }
    _addTimeline(Tr.pick('「${scenario.label}」でクラブの経営が始まった',
        'Began running the club: ${scenario.label}'));
  }

  /// 監督の提案を足す(上限まで)。節の進行ごとに呼ぶ。
  void _refreshProposals() {
    final save = _save;
    if (save == null) return;
    // 実際には存在しなくなった選手の提案は消す。
    save.proposals.removeWhere((p) => p.kind == ProposalKind.renew
        ? !userTeam.players.any((x) => x.id == p.playerId)
        : !save.youthProspects.any((x) => x.id == p.playerId));
    final fresh = ProposalEngine.generate(
      squad: userTeam.players,
      prospects: save.youthProspects,
      existing: save.proposals,
      declined: save.declinedProposalIds.toSet(),
      squadFull: userTeam.players.length >= maxSquadSize,
    );
    save.proposals.addAll(fresh);
  }

  /// テスト用: 提案の生成だけを走らせる。
  @visibleForTesting
  void debugRefreshProposals() => _refreshProposals();

  /// 提案を承認して実行する。実行できなかった(資金・枠が足りない)ときは
  /// 提案を取り下げ、false。
  Future<bool> approveProposal(String id) async {
    final save = _save;
    if (save == null) return false;
    final p = save.proposals.where((x) => x.id == id).firstOrNull;
    if (p == null) return false;
    final ok = switch (p.kind) {
      ProposalKind.renew => await renewContract(p.playerId),
      ProposalKind.promote => await promoteYouthProspect(p.playerId),
    };
    save.proposals.removeWhere((x) => x.id == id);
    if (!ok) save.declinedProposalIds.add(id);
    _notify();
    await _persist();
    return ok;
  }

  /// 提案を却下する。今シーズンは同じ提案が出ない。
  Future<void> declineProposal(String id) async {
    final save = _save;
    if (save == null) return;
    save.proposals.removeWhere((x) => x.id == id);
    save.declinedProposalIds.add(id);
    _notify();
    await _persist();
  }

  /// アドバイザーのレベルを変える(0〜3)。
  Future<bool> setAdvisorLevel(Advisor a, int level) async {
    final save = _save;
    if (save == null || level < 0 || level > AdvisorEngine.maxLevel) {
      return false;
    }
    if (level == 0) {
      save.advisors.remove(a.name);
    } else {
      save.advisors[a.name] = level;
    }
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末にアドバイザーへ報酬を払い、広報顧問の効果を与える。
  void _settleAdvisors() {
    final save = _save!;
    final fee = scaledMoney(AdvisorEngine.totalSalary(save.advisors));
    if (fee > 0) _book(LedgerCategory.staffWages, -fee);
    final pr = save.advisors[Advisor.pr.name] ?? 0;
    if (pr > 0) save.confidence = (save.confidence + pr).clamp(0, 100);
  }

  /// 投資案件に着手する。費用は着手時に払う。
  Future<bool> startProject(ClubProject p) async {
    final save = _save;
    if (save == null || ProjectEngine.started(save.projects, p)) return false;
    final cost = scaledMoney(p.cost);
    if (cost > save.budget) return false;
    _book(LedgerCategory.facilities, -cost);
    save.projects[p.name] = p.buildSeasons;
    _logNews(
      Tr.pick('${p.label}に着手しました(${formatMoney(cost)}・完成まで${p.buildSeasons}季)',
          'Started ${p.label} (${formatMoney(cost)}, ${p.buildSeasons} season(s) to build)'),
      context: Tr.pick('投資案件', 'Projects'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末に建設を進め、稼働中の提携クラブの効果を与える。
  void _tickProjects() {
    final save = _save!;
    final wasPartnerActive =
        ProjectEngine.isActive(save.projects, ClubProject.partnerClub);
    final done = ProjectEngine.tick(save.projects);
    for (final p in done) {
      _addTimeline(Tr.pick('${p.label}が完成', '${p.label} completed'));
      _logNews(
        Tr.pick('${p.label}が完成しました', '${p.label} is complete'),
        context: Tr.pick('投資案件', 'Projects'),
      );
    }
    // 完成した季からではなく、稼働している季の末から効く。
    if (wasPartnerActive) {
      save.managerReputation = (save.managerReputation + 2).clamp(0, 100);
      save.confidence = (save.confidence + 1).clamp(0, 100);
    }
  }

  /// 永久欠番にした選手か。
  bool isNumberRetired(String playerId) =>
      _save?.retiredNumberIds.contains(playerId) ?? false;

  /// 殿堂の選手を永久欠番にする。サポーターの期待が上がる。同じ選手は一度だけ。
  Future<bool> retireNumber(String playerId) async {
    final save = _save;
    if (save == null || save.retiredNumberIds.contains(playerId)) return false;
    final p = save.retiredLegends.where((l) => l.id == playerId).firstOrNull;
    if (p == null) return false;
    save.retiredNumberIds.add(playerId);
    _addTimeline(Tr.pick('${p.name}の背番号を永久欠番に', '${p.name}\'s number retired'));
    save.confidence = (save.confidence + 3).clamp(0, 100);
    _logNews(
      Tr.pick('${p.name}の背番号を永久欠番にしました。サポーターが沸いています',
          '${p.name}\'s number is retired for good. Supporters are thrilled'),
      context: Tr.pick('殿堂', 'Hall of fame'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 保険に入る/やめる。
  Future<void> setInsured(bool value) async {
    if (_save == null) return;
    _save!.insured = value;
    _notify();
    await _persist();
  }

  /// 災害基金へ積む(正)/引き出す(負)。資金が足りない・基金が足りないときは false。
  Future<bool> depositReserveFund(int amount) async {
    final save = _save;
    if (save == null || amount == 0) return false;
    if (amount > 0 && amount > save.budget) return false;
    if (amount < 0 && -amount > save.reserveFund) return false;
    save.reserveFund += amount;
    _book(LedgerCategory.financing, -amount);
    _notify();
    await _persist();
    return true;
  }

  /// 地域貢献を1段上げる。
  Future<bool> upgradeCommunity() async {
    final save = _save;
    if (save == null || save.communityLevel >= RiskEngine.maxCommunityLevel) {
      return false;
    }
    final cost = scaledMoney(RiskEngine.communityCost(save.communityLevel + 1));
    if (cost > save.budget) return false;
    _book(LedgerCategory.other, -cost);
    save.communityLevel += 1;
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末: 保険料、地域貢献の効果、突発の出来事。
  void _resolveSeasonRisks({double? chanceRoll, double? kindRoll, double? sizeRoll}) {
    final save = _save!;
    final tier = save.currentDivisionTier;
    if (save.insured) _book(LedgerCategory.other, -RiskEngine.premium(tier));
    if (save.communityLevel > 0) {
      save.confidence =
          (save.confidence + RiskEngine.communityTrustGain(save.communityLevel))
              .clamp(0, 100);
    }
    final rng = Random();
    final incident = RiskEngine.roll(
      chanceRoll: chanceRoll ?? rng.nextDouble(),
      kindRoll: kindRoll ?? rng.nextDouble(),
      sizeRoll: sizeRoll ?? rng.nextDouble(),
      tier: tier,
      communityLevel:
          save.communityLevel + (save.advisors[Advisor.pr.name] ?? 0),
    );
    if (incident == null) return;
    final cover = RiskEngine.cover(
        loss: incident.loss, insured: save.insured, fund: save.reserveFund);
    save.reserveFund = cover.fundAfter;
    if (cover.byClub > 0) _book(LedgerCategory.other, -cover.byClub);
    save.confidence = (save.confidence - incident.trustLoss).clamp(0, 100);
    _logNews(
      Tr.pick(
          '${incident.kind.label}が起きました。損失${formatMoney(incident.loss)}(保険${formatMoney(cover.byInsurance)}・基金${formatMoney(cover.byFund)}・クラブ負担${formatMoney(cover.byClub)})',
          '${incident.kind.label}. Loss ${formatMoney(incident.loss)} (insurance ${formatMoney(cover.byInsurance)}, fund ${formatMoney(cover.byFund)}, club ${formatMoney(cover.byClub)})'),
      context: Tr.pick('突発の出来事', 'Incident'),
    );
  }

  /// テスト用: 突発の出来事の判定を、指定の乱数で進める。
  @visibleForTesting
  void debugResolveSeasonRisks(double chance, double kind, double size) =>
      _resolveSeasonRisks(chanceRoll: chance, kindRoll: kind, sizeRoll: size);

  /// 命名権の候補から1つ結ぶ。
  Future<bool> chooseNamingRights(int index) async {
    final save = _save;
    if (save == null || index < 0 || index >= save.pendingNamingOffers.length) {
      return false;
    }
    save.namingDeal = save.pendingNamingOffers[index];
    _addTimeline(Tr.pick('スタジアムの命名権を${save.namingDeal!.name}と契約',
        'Signed naming rights with ${save.namingDeal!.name}'));
    save.pendingNamingOffers = [];
    _logNews(
      Tr.pick('スタジアムの命名権を結びました: ${save.namingDeal!.name}(1節${formatMoney(save.namingDeal!.weeklyIncome)}・${save.namingDeal!.yearsRemaining}年)',
          'Naming rights signed: ${save.namingDeal!.name} (${formatMoney(save.namingDeal!.weeklyIncome)} a match, ${save.namingDeal!.yearsRemaining} yr)'),
      context: Tr.pick('命名権', 'Naming rights'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 放映権の受け取り方を変える。開幕前だけ。
  Future<bool> setTvDeal(TvDeal deal) async {
    if (_save == null || !canChangeClubPolicy) return false;
    _save!.tvDeal = deal;
    _notify();
    await _persist();
    return true;
  }

  /// 放映権の前払いを受ける。以後の数季は分配金が出ない。
  Future<bool> takeTvAdvance() async {
    final save = _save;
    if (save == null || save.tvHolidaySeasons > 0) return false;
    final amount = MediaDealsEngine.advanceAmount(save.currentDivisionTier);
    _book(LedgerCategory.broadcast, amount);
    save.tvHolidaySeasons = MediaDealsEngine.advanceHolidaySeasons;
    _logNews(
      Tr.pick('放映権の前払い${formatMoney(amount)}を受け取りました。あと${save.tvHolidaySeasons}季は分配金が出ません',
          'Took a TV advance of ${formatMoney(amount)}. No TV money for ${save.tvHolidaySeasons} seasons'),
      context: Tr.pick('放映権', 'TV rights'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末に放映権の分配金を受け取る(前払いの精算中は無い)。
  void _bookTvRights({required int finalRank, required int teamCount}) {
    final save = _save!;
    if (save.tvHolidaySeasons > 0) {
      save.tvHolidaySeasons -= 1;
      return;
    }
    final pay = MediaDealsEngine.tvPayout(
      deal: save.tvDeal,
      tier: save.currentDivisionTier,
      rank: finalRank,
      teamCount: teamCount,
    );
    _book(LedgerCategory.broadcast, pay);
    _logNews(
      Tr.pick('放映権の分配金${formatMoney(pay)}(${save.tvDeal.label})が入りました',
          'TV money of ${formatMoney(pay)} (${save.tvDeal.label}) arrived'),
      context: Tr.pick('放映権', 'TV rights'),
    );
  }

  /// シーズン境界で命名権を1年消化し、無ければ候補を出す。
  void _rollNamingRights() {
    final save = _save!;
    if (save.namingDeal != null) {
      save.namingDeal!.yearsRemaining -= 1;
      if (save.namingDeal!.yearsRemaining <= 0) save.namingDeal = null;
    }
    if (save.namingDeal == null && save.pendingNamingOffers.isEmpty) {
      save.pendingNamingOffers = MediaDealsEngine.namingOffers(
        stadiumLevel: save.infrastructure.facilityLevel(FacilityType.stadium),
        tier: save.currentDivisionTier,
        managerReputation: save.managerReputation,
      );
    }
  }

  /// 世界クラブ価値番付。自クラブは実際の価値、他クラブは見積もり。
  List<RankedClub> get worldClubRanking {
    final save = _save;
    if (save == null) return const [];
    final clubs = <RankedClub>[
      RankedClub(
        name: save.clubName,
        value: clubValue.total,
        tier: save.currentDivisionTier,
        isUser: true,
      ),
    ];
    void addLeague(League league, int tier) {
      for (final t in league.teams) {
        if (t.id == save.userTeamId) continue;
        clubs.add(RankedClub(
          name: t.name,
          value: ClubRankingEngine.estimate(
            playersValue: t.players.fold<int>(0, (s, p) => s + p.marketValue),
            tier: tier,
          ),
          tier: tier,
          isUser: false,
        ));
      }
    }

    addLeague(save.league, save.currentDivisionTier);
    for (var tier = 1; tier <= save.otherDivisionLeagues.length; tier++) {
      final l = save.otherDivisionLeagues[tier - 1];
      if (l != null) addLeague(l, tier);
    }
    return ClubRankingEngine.rank(clubs);
  }

  /// オーナーの持分(%)。
  int get ownerShare => _save?.ownerShare ?? 100;

  /// 持分の10%を外部の株主へ売る(増資)。売れないときは false。
  Future<bool> sellStake() async {
    final save = _save;
    if (save == null) return false;
    final pct = EquityEngine.sellable(save.ownerShare);
    if (pct == 0) return false;
    final price = EquityEngine.salePrice(clubValue.total, pct);
    save.ownerShare -= pct;
    _book(LedgerCategory.financing, price);
    _addTimeline(Tr.pick('持分$pct%を外部の株主に売却(残り${save.ownerShare}%)',
        'Sold a $pct% stake (${save.ownerShare}% left)'));
    _logNews(
      Tr.pick('持分$pct%を外部の株主に売り、${formatMoney(price)}を調達しました(持分${save.ownerShare}%)',
          'Sold a $pct% stake for ${formatMoney(price)} (you now hold ${save.ownerShare}%)'),
      context: Tr.pick('株主', 'Shareholders'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 持分の10%を買い戻す。資金が足りないときは false。
  Future<bool> buyBackStake() async {
    final save = _save;
    if (save == null || save.ownerShare >= 100) return false;
    const pct = EquityEngine.step;
    final take = pct > 100 - save.ownerShare ? 100 - save.ownerShare : pct;
    final cost = EquityEngine.buybackCost(clubValue.total, take);
    if (cost > save.budget) return false;
    save.ownerShare += take;
    _book(LedgerCategory.financing, -cost);
    _logNews(
      Tr.pick('持分$take%を${formatMoney(cost)}で買い戻しました(持分${save.ownerShare}%)',
          'Bought back $take% for ${formatMoney(cost)} (you now hold ${save.ownerShare}%)'),
      context: Tr.pick('株主', 'Shareholders'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末の株主総会。外部の株主へ配当を払い、総会の様子をニュースに残す。
  void _holdShareholdersMeeting() {
    final save = _save!;
    final dividend = EquityEngine.dividend(
        ownerShare: save.ownerShare, seasonProfit: currentLedger.profit);
    if (dividend > 0) _book(LedgerCategory.financing, -dividend);
    final outside = 100 - save.ownerShare;
    _logNews(
      Tr.pick(
          '株主総会: ${EquityEngine.mood(save.shareholderExpectation)}。${outside > 0 ? '外部の株主(持分$outside%)へ配当${formatMoney(dividend)}を払いました。' : '外部の株主はいません。'}',
          'Shareholders\' meeting: ${EquityEngine.mood(save.shareholderExpectation)}. ${outside > 0 ? 'Paid outside holders ($outside%) a dividend of ${formatMoney(dividend)}.' : 'There are no outside shareholders.'}'),
      context: Tr.pick('株主総会', 'Shareholders\' meeting'),
    );
  }

  /// 今シーズンの景気。
  EconomyPhase get economyPhase => _save?.economyPhase ?? EconomyPhase.normal;

  /// 来シーズンの景気(予報)。
  EconomyPhase get economyNext => _save?.economyNext ?? EconomyPhase.normal;

  /// シーズン末に景気を1つ進める。来季の予報が今季になり、次の予報を引く。
  void _advanceEconomy({double? roll}) {
    final save = _save!;
    save.economyPhase = save.economyNext;
    save.economyNext =
        EconomyEngine.next(save.economyPhase, roll ?? Random().nextDouble());
    _logNews(
      Tr.pick(
          '景気: 来季は「${save.economyPhase.label}」です。${save.economyPhase.summary}(再来季の予報: ${save.economyNext.label})',
          'Economy: next season is "${save.economyPhase.label}". ${save.economyPhase.summary} (Forecast after that: ${save.economyNext.label})'),
      context: Tr.pick('景気', 'Economy'),
    );
  }

  /// テスト用: 景気を1つ進める。
  @visibleForTesting
  void debugAdvanceEconomy(double roll) => _advanceEconomy(roll: roll);

  /// オーナーが選んだクラブの方針。
  ClubPolicy get clubPolicy => _save?.clubPolicy ?? ClubPolicy.balanced;

  /// 方針を変えられるか。今シーズンの試合が1つも行われていない間だけ。
  /// 途中で変えられると、シーズン末の採点に合わせて直前に選べてしまう。
  bool get canChangeClubPolicy =>
      _save != null && _save!.league.fixtures.every((f) => f.result == null);

  /// 方針を選ぶ。変えられないときは何もせず false。
  Future<bool> setClubPolicy(ClubPolicy policy) async {
    if (_save == null || !canChangeClubPolicy) return false;
    _save!.clubPolicy = policy;
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末に方針を採点し、2つの期待を動かす。
  void _scoreClubPolicy({required int finalRank}) {
    final save = _save!;
    final result = PolicyEngine.score(
      policy: save.clubPolicy,
      finalRank: finalRank,
      targetRank: save.boardTargetRank,
      youngCount: userTeam.players
          .where((p) => p.age <= PolicyEngine.youngAge)
          .length,
      seasonProfit: currentLedger.profit,
    );
    if (result == null) return;
    save.confidence = (save.confidence + result.supporters).clamp(0, 100);
    save.shareholderExpectation =
        (save.shareholderExpectation + result.shareholders).clamp(0, 100);
    _logNews(result.reason, context: Tr.pick('クラブの方針', 'Club policy'));
  }

  /// テスト用: 方針の採点だけを走らせる。
  @visibleForTesting
  void debugScoreClubPolicy({required int finalRank}) =>
      _scoreClubPolicy(finalRank: finalRank);

  /// いまのクラブ価値と内訳。
  ClubValue get clubValue {
    final save = _save;
    if (save == null) {
      return ClubValueEngine.compute(
        playersValue: 0,
        facilityLevels: const [],
        staffLevels: const [],
        leagueTitles: 0,
        cupTitles: 0,
        managerReputation: 0,
        annualOperatingIncome: 0,
        cash: 0,
        debt: 0,
      );
    }
    final mine = save.seasonHistory.where((r) => r.clubName == save.clubName);
    // 稼ぐ力は、直近に終えたシーズンの営業収入。まだ無ければ今の週収入から見積もる。
    final past = save.ledgers
        .where((l) => l.season < save.league.season && l.operatingIncome > 0)
        .toList();
    final matchdays = save.league.fixtures.fold<int>(
        0, (m, f) => f.matchday > m ? f.matchday : m);
    final annual = past.isNotEmpty
        ? past.last.operatingIncome
        : weeklyIncomeFor(save.userTeamId) * matchdays;
    return ClubValueEngine.compute(
      playersValue:
          userTeam.players.fold<int>(0, (s, p) => s + p.marketValue),
      facilityLevels: [
        for (final f in FacilityType.values)
          save.infrastructure.facilityLevel(f),
      ],
      staffLevels: [
        for (final r in StaffRole.values)
          save.infrastructure.staffFor(r)?.effectiveLevel ?? 0,
      ],
      leagueTitles: mine.where((r) => r.wonLeague).length,
      cupTitles: mine.fold<int>(0, (t, r) => t + r.cupsWon.length),
      managerReputation: save.managerReputation,
      annualOperatingIncome: annual,
      cash: save.budget,
      debt: outstandingLoanDebt,
      scale: moneyScale(save.currentDivisionTier),
    );
  }

  /// 過去のシーズン末のクラブ価値(シーズン順)。
  List<(int, int)> get clubValueHistory => [
        for (final e in (_save?.clubValueHistory.entries.toList() ?? [])
          ..sort((a, b) => a.key.compareTo(b.key)))
          (e.key, e.value),
      ];

  /// 今シーズンの終わりのクラブ価値を記録する。
  void _recordClubValue() {
    final save = _save!;
    save.clubValueHistory[save.league.season] = clubValue.total;
    while (save.clubValueHistory.length > SaveGame.maxLedgerSeasons) {
      save.clubValueHistory.remove(save.clubValueHistory.keys.reduce(min));
    }
  }

  /// テスト用: シーズン末のクラブ価値の記録だけを走らせる。
  @visibleForTesting
  void debugRecordClubValue() => _recordClubValue();

  /// 今シーズンの収支の記録。
  SeasonLedger get currentLedger =>
      _save == null ? SeasonLedger(1) : _save!.ledgerFor(_save!.league.season);

  /// 過去シーズンの収支の記録(シーズン順。今季は含めない)。
  List<SeasonLedger> get pastLedgers => _save == null
      ? const []
      : _save!.ledgers.where((l) => l.season < _save!.league.season).toList();

  /// 1節あたりの収支(収入 − 人件費 − 分割払い − 融資返済)。
  int get weeklyNet {
    if (_save == null) return 0;
    return LedgerEngine.weeklyNet(
      income: weeklyIncomeFor(_save!.userTeamId),
      wageBill: matchdayPlayerWageCost + matchdayStaffWageCost,
      installments:
          _save!.pendingInstallments.fold<int>(0, (s, i) => s + i.weeklyAmount),
      loanRepayment: bankLoans.fold<int>(0, (s, l) => s + l.weeklyRepayment),
    );
  }

  /// 今の収支のまま続けたとき、資金が尽きるまでの節数。尽きなければ null。
  int? get runwayWeeks => _save == null
      ? null
      : LedgerEngine.runwayWeeks(budget: _save!.budget, weeklyNet: weeklyNet);

  /// 選手とスタッフの週俸の合計(万円/週)。理事会の給与の枠はこれで見る。
  /// 年俸で見せるときは52倍する。スタッフは今の部の規模に直した額。
  int get weeklyWageBill => _save == null
      ? 0
      : ContractEngine.weeklyWageBill(userTeam) +
          scaledMoney(_save!.infrastructure.totalStaffWeeklyWage);

  /// 理事会が設定する週給総額の上限(万円/週)。シーズン開始時に確定する。
  /// 未設定の旧セーブでは現在の状況から同じ式で算出する(必ず余裕がある
  /// 値になるため、既存プレイを突然ブロックしない)。
  int get wageBudgetCap {
    if (_save == null) return 0;
    final base = _save!.wageBudget > 0
        ? _save!.wageBudget
        : BoardEngine.wageBudgetFor(
            tier: _save!.currentDivisionTier,
            currentWeeklyWageBill: weeklyWageBill,
            weeklyIncome: weeklyIncomeFor(_save!.userTeamId),
          );
    // 補強の配分を厚くすると上限が広がり、削ると狭まる(初期の配分で1倍)。
    return (base *
            BudgetEngine.wageCapMultiplier(_save!.budgetPlan) *
            PolicyEngine.wageCapMultiplier(_save!.clubPolicy))
        .round();
  }

  /// 週給[addedWeeklyWage]万円の選手を加えても週給予算に収まるか。
  /// 収まらない場合は[lastSigningBlockReason]に理由をセットしてfalseを返す。
  bool _wageBudgetAllowsSigning(int addedWeeklyWage) {
    if (isTransferBanned) {
      lastSigningBlockReason = Tr.pick(
          'リーグの規則違反で、今は補強が禁止されています(あと${_save!.transferBanSeasons}季)。',
          'Signings are banned for a rule breach (${_save!.transferBanSeasons} more seasons).');
      return false;
    }
    final cap = wageBudgetCap;
    if (weeklyWageBill + addedWeeklyWage <= cap) return true;
    lastSigningBlockReason = Tr.pick(
        '給与予算オーバー: 今の年俸の総額${formatMoney(annualFromWeekly(weeklyWageBill))}に新加入の${formatMoney(annualFromWeekly(addedWeeklyWage))}を加えると、理事会の上限(年${formatMoney(annualFromWeekly(cap))})を超えます。放出や施設スタッフの見直しで枠を空けてください。',
        "Over the wage budget: your current annual bill of ${formatMoney(annualFromWeekly(weeklyWageBill))} plus ${formatMoney(annualFromWeekly(addedWeeklyWage))} for the new signing would pass the board's cap of ${formatMoney(annualFromWeekly(cap))} a year. Sell someone or review your staff to make room.");
    return false;
  }

  /// 銀行から借り入れている融資一覧。
  List<BankLoan> get bankLoans => _save?.bankLoans ?? [];

  /// 融資の残り返済総額(元本+利息のうち未払い分)。
  int get outstandingLoanDebt =>
      bankLoans.fold<int>(0, (s, l) => s + l.totalRemaining);

  /// 現在追加で借り入れ可能な上限額。スタジアムの規模と監督としての評価が高いほど拡大する。
  int get maxLoanAmount => _save == null
      ? 0
      : LoanEngine.maxBorrowable(
          stadiumLevel: _save!.infrastructure.facilityLevel(
            FacilityType.stadium,
          ),
          reputation: _save!.managerReputation,
          outstandingDebt: outstandingLoanDebt,
          scale: moneyScale(currentDivisionTier),
        );

  /// 銀行融資を申し込む。頭金なしで即座に資金を得られる代わりに、指定した返済プランで
  /// 毎週の返済が発生する。
  Future<bool> takeLoan(int amount, LoanTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > maxLoanAmount) return false;
    final weekly = LoanEngine.weeklyRepaymentFor(amount, term);
    _save!.bankLoans.add(
      BankLoan(
        id: 'loan${_loanSeq++}',
        principal: amount,
        weeklyRepayment: weekly,
        termWeeks: term.weeks,
        weeksRemaining: term.weeks,
      ),
    );
    _book(LedgerCategory.financing, amount);
    _notify();
    await _persist();
    return true;
  }

  /// 預け入れ中の定期預金一覧。
  List<FixedDeposit> get fixedDeposits => _save?.fixedDeposits ?? [];

  /// 定期預金として運用中の資金の合計(元本ベース)。
  int get totalDepositedFunds =>
      fixedDeposits.fold<int>(0, (s, d) => s + d.principal);

  /// 定期預金を組む。指定額をただちに資金から差し引いて預け入れ、満期まで
  /// 引き出せない代わりに満期時に利息込みでまとめて払い戻される。
  Future<bool> openFixedDeposit(int amount, DepositTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > _save!.budget) return false;
    _book(LedgerCategory.financing, -(amount));
    _save!.fixedDeposits.add(
      FixedDeposit(
        id: 'deposit${_depositSeq++}',
        principal: amount,
        maturityValue: InvestmentEngine.maturityValueFor(amount, term),
        termWeeks: term.weeks,
        weeksRemaining: term.weeks,
      ),
    );
    _notify();
    await _persist();
    return true;
  }
}
