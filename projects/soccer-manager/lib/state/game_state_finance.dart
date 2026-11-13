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

  /// 1シーズンに宣言できる勝負の試合の数。
  static const int bigMatchesPerSeason = 4;

  /// 今シーズンに宣言できる勝負の試合の残り。シーズンが変わると満タンに戻る。
  int get bigMatchesLeft {
    final save = _save;
    if (save == null) return 0;
    final used = save.bigMatchSeason == save.league.season ? save.bigMatchesUsed : 0;
    return (GameStateFinance.bigMatchesPerSeason - used)
        .clamp(0, GameStateFinance.bigMatchesPerSeason);
  }

  /// 次の自クラブの試合が、宣言した勝負の試合か。
  bool get isNextMatchBig {
    final save = _save;
    if (save == null) return false;
    final next = save.league.nextUnplayedFixture;
    return next != null &&
        save.bigMatchSeason == save.league.season &&
        save.bigMatchDeclaredMatchday == next.matchday;
  }

  /// 次の試合を勝負の試合と宣言する。回数が尽きている・試合が無い・
  /// すでに宣言済みなら何もしない。宣言した試合だけ、戦術と先発を自分で決める。
  Future<bool> declareBigMatch() async {
    final save = _save;
    if (save == null || isNextMatchBig || bigMatchesLeft <= 0) return false;
    final next = save.league.nextUnplayedFixture;
    if (next == null) return false;
    if (save.bigMatchSeason != save.league.season) {
      save.bigMatchSeason = save.league.season;
      save.bigMatchesUsed = 0;
    }
    save.bigMatchesUsed += 1;
    save.bigMatchDeclaredMatchday = next.matchday;
    _notify();
    await _persist();
    return true;
  }

  /// 宣言を取り消す(回数は戻る)。
  Future<void> cancelBigMatch() async {
    final save = _save;
    if (save == null || !isNextMatchBig) return;
    save.bigMatchesUsed = (save.bigMatchesUsed - 1).clamp(0, 999);
    save.bigMatchDeclaredMatchday = -1;
    _notify();
    await _persist();
  }

  /// 勝負の試合でない節は、監督が先発とメンタリティを決める。穴(負傷・出場停止)
  /// を埋め、相手との力関係から構えを選ぶ。自分で決めた先発と戦術が効くのは、
  /// 宣言した勝負の試合だけ。
  void _managerPreparesMatch(Fixture next) {
    final save = _save;
    if (save == null || isNextMatchBig) return;
    final user = userTeam;
    final oppId = next.homeTeamId == user.id ? next.awayTeamId : next.homeTeamId;
    final opp = _findTeam(save.league.teams, oppId);
    if (opp == null) return;
    LineupUtils.fillVacancies(user);
    user.mentality = CpuTacticsAI.mentalityFor(
      ownRating: user.overallRating,
      opponentRating: opp.overallRating,
    );
  }

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
    save.budget =
        (6000 * save.difficulty.initialBudgetFactor).round();
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
    _refreshStaffCandidates();
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
    if (_save == null) return 0;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == teamId) + 1;
    final teamCount = league.teams.length;
    final rankBonus = ((teamCount - rank) * 20).clamp(0, 999);
    final base = 150 + rankBonus;
    if (teamId != _save!.userTeamId) return base;

    final stadiumLevel = _save!.infrastructure.facilityLevel(
      FacilityType.stadium,
    );
    final commercialMultiplier = ClubInfrastructure.commercialRevenueMultiplier(
      _save!.infrastructure.facilityLevel(FacilityType.commercialFacility),
    );
    var matchdayIncome = ((base + (stadiumLevel - 1) * 80) *
            userAttendanceFactor *
            _save!.ticketPricing.revenueMultiplier *
            commercialMultiplier)
        .round();
    // 2部リーグは1部より観客動員が少ない(userAttendanceFactorに反映済み)。
    final sponsorIncome =
        ((_save!.sponsorDeal?.weeklyIncome ?? 0) * commercialMultiplier)
            .round();
    // グッズ収入(マーチャンダイジング)。試合の有無に関わらず、監督の評価
    // (=クラブの知名度)が高いほど、商業施設が充実しているほど増える。
    // チケット・スポンサーだけに依存しない収入源として資金繰りを下支えする。
    final merchandiseIncome =
        ((40 + managerReputation) * commercialMultiplier).round();
    // 営業の配分を厚くすると収入が増え、削ると減る(初期の配分で1倍)。
    return ((matchdayIncome + sponsorIncome + merchandiseIncome) *
            BudgetEngine.incomeMultiplier(_save!.budgetPlan))
        .round();
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

  int get weeklyWageBill => _save == null
      ? 0
      : ContractEngine.weeklyWageBill(userTeam) +
          _save!.infrastructure.totalStaffWeeklyWage;

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
    return (base * BudgetEngine.wageCapMultiplier(_save!.budgetPlan)).round();
  }

  /// 週給[addedWeeklyWage]万円の選手を加えても週給予算に収まるか。
  /// 収まらない場合は[lastSigningBlockReason]に理由をセットしてfalseを返す。
  bool _wageBudgetAllowsSigning(int addedWeeklyWage) {
    final cap = wageBudgetCap;
    if (weeklyWageBill + addedWeeklyWage <= cap) return true;
    lastSigningBlockReason = Tr.pick(
        '週給予算オーバー: 現在の週給総額$weeklyWageBill万円に新加入の$addedWeeklyWage万円を加えると、理事会の上限$cap万円を超えます。放出や施設スタッフの見直しで枠を空けてください。',
        "Over the wage budget: your current bill of $weeklyWageBill plus $addedWeeklyWage for the new signing would pass the board's cap of $cap. Sell someone or review your staff to make room.");
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
    _save!.budget += amount;
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
    _save!.budget -= amount;
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
