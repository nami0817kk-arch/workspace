import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// オーナー個人の財布(出資・貸付・返済・本業の収入・利息)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> start() async {
    final gs = GameState();
    await gs.startNewGame('財布FC');
    return gs;
  }

  test('始めたときの個人資産は、クラブの初期資金の3倍', () async {
    final gs = await start();
    expect(gs.ownerWealth,
        GameState.initialBudgetFor(gs.currentDivisionTier) *
            GameStateOwner.startingWealthMultiple);
  });

  test('出資すると資金が増え、財布は減り、株主は喜ぶ(1季に1回)', () async {
    final gs = await start();
    final s = gs.save!;
    s.shareholderExpectation = 50;
    final wealth = gs.ownerWealth;
    final budget = s.budget;
    expect(await gs.injectCapital(1000), isTrue);
    expect(s.budget, budget + 1000);
    expect(gs.ownerWealth, wealth - 1000);
    expect(s.shareholderExpectation, 50 + GameStateOwner.injectionGoodwill);
    await gs.injectCapital(1000);
    expect(s.shareholderExpectation, 50 + GameStateOwner.injectionGoodwill);
    expect(await gs.injectCapital(gs.ownerWealth + 1), isFalse,
        reason: '財布より多くは出せない');
  });

  test('貸すと借りが残り、返してもらうと財布に戻る', () async {
    final gs = await start();
    final s = gs.save!;
    final wealth = gs.ownerWealth;
    expect(await gs.lendToClub(5000), isTrue);
    expect(gs.ownerLoanBalance, 5000);
    expect(gs.ownerWealth, wealth - 5000);
    expect(await gs.repayOwnerLoan(2000), isTrue);
    expect(gs.ownerLoanBalance, 3000);
    expect(gs.ownerWealth, wealth - 3000);
    s.budget = 0;
    expect(await gs.repayOwnerLoan(100), isFalse, reason: '資金が無ければ返せない');
  });

  test('月が替わると本業の収入が入り、クラブは利息を払う', () async {
    final gs = await start();
    expect(await gs.lendToClub(30000), isTrue);
    final interest = gs.ownerLoanMonthlyInterest;
    expect(interest, (30000 * 2 / 100 / 12).round());
    final wealth = gs.ownerWealth;
    final other = gs.currentLedger.of(LedgerCategory.other);
    final d = gs.today;
    gs.debugAdvanceTodayTo(DateTime(d.year, d.month + 1, 2));
    expect(gs.ownerWealth,
        wealth + gs.scaledMoney(GameStateOwner.monthlyIncomeTier5) + interest);
    expect(gs.currentLedger.of(LedgerCategory.other), other - interest);
  });

  test('財布と貸付は保存して読み戻せる', () async {
    final gs = await start();
    await gs.lendToClub(3000);
    final copy = SaveGame.fromJson(gs.save!.toJson());
    expect(copy.ownerWealth, gs.ownerWealth);
    expect(copy.ownerLoanBalance, 3000);
  });
}
