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
  Team? get pendingJobOfferTeam {
    final teamId = _save?.pendingJobOfferTeamId;
    if (teamId == null) return null;
    return _save!.league.teams.firstWhere((t) => t.id == teamId);
  }

  Future<bool> acceptJobOffer() async {
    if (_save == null || _save!.pendingJobOfferTeamId == null) return false;
    final newTeamId = _save!.pendingJobOfferTeamId!;
    final newTeamName =
        _save!.league.teams.firstWhere((t) => t.id == newTeamId).name;
    _save!.userTeamId = newTeamId;
    _save!.pendingJobOfferTeamId = null;
    _save!.confidence = 60;
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
    return matchdayIncome + sponsorIncome + merchandiseIncome;
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
    if (_save!.wageBudget > 0) return _save!.wageBudget;
    return BoardEngine.wageBudgetFor(
      tier: _save!.currentDivisionTier,
      currentWeeklyWageBill: weeklyWageBill,
      weeklyIncome: weeklyIncomeFor(_save!.userTeamId),
    );
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
