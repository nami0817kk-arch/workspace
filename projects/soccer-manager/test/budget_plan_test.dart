import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/budget_engine.dart';
import 'package:soccer_manager/models/budget_plan.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

int _total(BudgetPlan plan) =>
    BudgetCategory.values.fold<int>(0, (t, c) => t + plan.share(c));

/// オーナーが年の予算を5つへ配る比率。合計が100から外れると、配った金額が
/// 総額を超えたり余ったりするので、どの操作のあとでも100を保つことを固定する。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('BudgetPlan', () {
    test('初期の配分は合計100で、どれも0より大きい', () {
      final plan = BudgetPlan.balanced();
      expect(_total(plan), 100);
      for (final c in BudgetCategory.values) {
        expect(plan.share(c), greaterThan(0));
      }
    });

    test('1つの配り先を変えても、合計は100のまま', () {
      var plan = BudgetPlan.balanced();
      for (final c in BudgetCategory.values) {
        for (final v in [0, 1, 7, 33, 50, 99, 100]) {
          plan = plan.withShare(c, v);
          expect(_total(plan), 100, reason: '$c を $v にした');
          expect(plan.share(c), v);
        }
      }
    });

    test('範囲外の値は0〜100に収める', () {
      expect(BudgetPlan.balanced().withShare(BudgetCategory.youth, 150).share(
          BudgetCategory.youth), 100);
      expect(BudgetPlan.balanced().withShare(BudgetCategory.youth, -5).share(
          BudgetCategory.youth), 0);
    });

    test('1つを増やすと、残りは比率に応じて減る', () {
      final before = BudgetPlan.balanced();
      final after = before.withShare(BudgetCategory.signing, 60);
      // 補強の30を60にすると、他の4つは小さくなる。大きかったものは大きいまま。
      expect(after.share(BudgetCategory.youth),
          lessThan(before.share(BudgetCategory.youth)));
      expect(after.share(BudgetCategory.youth),
          greaterThanOrEqualTo(after.share(BudgetCategory.facilities)));
    });

    test('他が全部0でも、残りは均等に分けて合計100を保つ', () {
      var plan = BudgetPlan.balanced();
      for (final c in BudgetCategory.values) {
        if (c != BudgetCategory.signing) plan = plan.withShare(c, 0);
      }
      plan = plan.withShare(BudgetCategory.signing, 100);
      final next = plan.withShare(BudgetCategory.signing, 60);
      expect(_total(next), 100);
      expect(next.share(BudgetCategory.youth), 10);
    });

    test('保存して読み戻せる', () {
      final plan = BudgetPlan.balanced().withShare(BudgetCategory.youth, 45);
      final restored = BudgetPlan.fromJson(plan.toJson());
      for (final c in BudgetCategory.values) {
        expect(restored.share(c), plan.share(c));
      }
    });

    test('無い・壊れている・合計が100でない保存値は、初期の配分にする', () {
      final balanced = BudgetPlan.balanced();
      void expectBalanced(Map<String, dynamic>? json) {
        final plan = BudgetPlan.fromJson(json);
        for (final c in BudgetCategory.values) {
          expect(plan.share(c), balanced.share(c));
        }
      }

      expectBalanced(null);
      expectBalanced({'signing': 50});
      expectBalanced({
        'signing': 50,
        'youth': 50,
        'facilities': 50,
        'marketing': 0,
        'dividend': 0,
      });
      expectBalanced({
        'signing': 'x',
        'youth': 25,
        'facilities': 25,
        'marketing': 25,
        'dividend': 25,
      });
    });
  });

  group('BudgetEngine', () {
    test('総額は週収入×38週。収入が無ければ0', () {
      expect(BudgetEngine.annualPool(weeklyIncome: 500), 500 * 38);
      expect(BudgetEngine.annualPool(weeklyIncome: 0), 0);
      expect(BudgetEngine.annualPool(weeklyIncome: -10), 0);
    });

    test('金額の合計は、端数が出ても総額にぴったり合う', () {
      for (final pool in [0, 1, 99, 1234, 19000]) {
        for (final share in [0, 13, 37, 100]) {
          final plan =
              BudgetPlan.balanced().withShare(BudgetCategory.facilities, share);
          final amounts = BudgetEngine.allocate(pool, plan);
          final sum = amounts.values.fold<int>(0, (t, v) => t + v);
          expect(sum, pool, reason: '総額$pool 施設$share%');
        }
      }
    });
  });

  group('セーブとGameState', () {
    test('配分は保存して読み戻せ、無い旧セーブは初期の配分になる', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      await gameState.setBudgetShare(BudgetCategory.youth, 40);

      final restored = SaveGame.fromJson(gameState.save!.toJson());
      expect(restored.budgetPlan.share(BudgetCategory.youth), 40);

      final old = gameState.save!.toJson()..remove('budgetPlan');
      final fromOld = SaveGame.fromJson(old);
      expect(fromOld.budgetPlan.share(BudgetCategory.youth),
          BudgetPlan.balanced().share(BudgetCategory.youth));
    });

    test('setBudgetShare は合計100を保ち、年の予算は正の値になる', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      await gameState.setBudgetShare(BudgetCategory.signing, 55);

      expect(_total(gameState.budgetPlan), 100);
      expect(gameState.budgetPlan.share(BudgetCategory.signing), 55);
      expect(gameState.annualBudgetPool, greaterThan(0));
    });
  });
}
