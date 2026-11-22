part of 'game_state.dart';

/// オーナー個人のお金(クラブの資金とは別)。クラブへの出資と貸付。
///
/// 実在のオーナーは、クラブが苦しいときに自分の財布から出資したり、
/// 利息つきで貸したりする。出資は返ってこないが株主に喜ばれ、貸付は
/// 返ってくるがクラブに利息の負担が残る。
extension GameStateOwner on GameState {
  /// 始めたときのオーナーの個人資産は、クラブの初期資金の何倍か。
  static const int startingWealthMultiple = 3;

  /// オーナーの本業から毎月入る額の元(旧5部の物差しの万円)。
  static const int monthlyIncomeTier5 = 1000;

  /// オーナーの本業から毎月入る額(万円)。本業はクラブとは別の商売なので、
  /// クラブのいる部では変わらない。以前は今いる部の倍率を掛けていたため、
  /// 昇格すると本業の収入まで約4倍・14倍に増えていた。始めたときの部
  /// (いちばん下の部)の額に固定する(始めたときの額は以前と同じ)。
  static int get monthlyIncome =>
      scaleMoneyForTier(totalDivisionTiers, monthlyIncomeTier5);

  /// オーナーからの貸付の年利(%)。月ごとにクラブが払う。
  static const int loanRatePercent = 2;

  /// 出資したときの株主の期待の上乗せ(1季に1回まで)。
  static const int injectionGoodwill = 3;

  /// オーナーの個人資産(万円)。旧セーブ・始めたときは、初期資金の3倍。
  int get ownerWealth {
    final s = _save;
    if (s == null) return 0;
    if (s.ownerWealth < 0) {
      s.ownerWealth = GameState.initialBudgetFor(s.currentDivisionTier) *
          startingWealthMultiple;
    }
    return s.ownerWealth;
  }

  /// クラブがオーナーに借りている額(万円)。
  int get ownerLoanBalance => _save?.ownerLoanBalance ?? 0;

  /// 毎月の利息(万円)。
  int get ownerLoanMonthlyInterest =>
      (ownerLoanBalance * loanRatePercent / 100 / 12).round();

  /// 個人の財布からクラブへ出資する(返ってこない)。株主は喜ぶ(1季に1回)。
  Future<bool> injectCapital(int amount) async {
    final s = _save;
    if (s == null || amount <= 0 || amount > ownerWealth) return false;
    s.ownerWealth -= amount;
    _book(LedgerCategory.financing, amount);
    if (s.ownerInjectionSeason != s.league.season) {
      s.ownerInjectionSeason = s.league.season;
      s.shareholderExpectation =
          (s.shareholderExpectation + injectionGoodwill).clamp(0, 100);
    }
    _addTimeline(Tr.pick('オーナーが私財から${formatMoney(amount)}を出資',
        'The owner put in ${formatMoney(amount)} of his own money'));
    _logNews(
        Tr.pick('オーナーが私財から${formatMoney(amount)}をクラブへ出資した。株主は歓迎している。',
            'You put ${formatMoney(amount)} of your own money into the club. The shareholders approve.'),
        context: Tr.pick('オーナー', 'Owner'));
    _notify();
    await _persist();
    return true;
  }

  /// 個人の財布からクラブへ貸す(年利2%、クラブが毎月払う)。
  Future<bool> lendToClub(int amount) async {
    final s = _save;
    if (s == null || amount <= 0 || amount > ownerWealth) return false;
    s.ownerWealth -= amount;
    s.ownerLoanBalance += amount;
    _book(LedgerCategory.financing, amount);
    _logNews(
        Tr.pick('オーナーがクラブに${formatMoney(amount)}を貸した(年利$loanRatePercent%)。',
            'You lent the club ${formatMoney(amount)} at $loanRatePercent% a year.'),
        context: Tr.pick('オーナー', 'Owner'));
    _notify();
    await _persist();
    return true;
  }

  /// クラブからオーナーへ、貸付を返す。
  Future<bool> repayOwnerLoan(int amount) async {
    final s = _save;
    if (s == null || amount <= 0) return false;
    final pay = min(amount, s.ownerLoanBalance);
    if (pay <= 0 || pay > s.budget) return false;
    s.ownerLoanBalance -= pay;
    s.ownerWealth = ownerWealth + pay;
    _book(LedgerCategory.financing, -pay);
    _logNews(
        Tr.pick(
            'クラブがオーナーへ${formatMoney(pay)}を返した(残り${formatMoney(s.ownerLoanBalance)})。',
            'The club repaid you ${formatMoney(pay)} (${formatMoney(s.ownerLoanBalance)} still owed).'),
        context: Tr.pick('オーナー', 'Owner'));
    _notify();
    await _persist();
    return true;
  }

  /// 月が替わったら: オーナーの本業の収入が入り、クラブは貸付の利息を払う。
  void _advanceOwnerMoney(DateTime before, DateTime after) {
    final s = _save;
    if (s == null) return;
    if (before.year == after.year && before.month == after.month) return;
    final months = (after.year - before.year) * 12 + after.month - before.month;
    // 本業の収入は部に関係なく一定(クラブの規模の倍率を掛けない)。
    s.ownerWealth = ownerWealth + monthlyIncome * months;
    final interest = ownerLoanMonthlyInterest * months;
    if (interest > 0) {
      // 利息は損益の支出(2026-11-22 から「その他」ではなく「利息」)。
      _book(LedgerCategory.interest, -interest);
      s.ownerWealth += interest;
    }
  }

  /// クラブを替えるとき: 前のクラブの借りは、新しい持ち主が返す
  /// (オーナーの財布に戻る)。
  void _settleOwnerLoanOnClubChange() {
    final s = _save!;
    if (s.ownerLoanBalance <= 0) return;
    s.ownerWealth = ownerWealth + s.ownerLoanBalance;
    s.ownerLoanBalance = 0;
  }

  // ---- アカデミー ----

  /// アカデミーの等級の点。
  double get academyScore {
    final s = _save;
    if (s == null) return 0;
    return AcademyEngine.score(
      facilityLevel: s.infrastructure.facilityLevel(FacilityType.youthFacility),
      coachLevel: s.infrastructure.staffLevel(StaffRole.youthCoach),
      momentum: s.youthMomentum,
    );
  }

  /// アカデミーのカテゴリー(1〜4。1が最上)。
  int get academyCategory => AcademyEngine.category(academyScore);

  YouthPolicy get youthPolicy =>
      YouthPolicy.values.firstWhere((p) => p.name == _save?.youthPolicy,
          orElse: () => YouthPolicy.balanced);

  /// 育成の方針を変える(次の入団から効く)。
  Future<void> setYouthPolicy(YouthPolicy p) async {
    if (_save == null) return;
    _save!.youthPolicy = p.name;
    _notify();
    await _persist();
  }
}
