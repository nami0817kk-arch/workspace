import '../models/budget_plan.dart';

/// 年の予算を、5つの配り先へ金額で割り振る。
///
/// いまは金額の計算だけ。各配り先が戦力・収入・人気へどう返るかの結び付きは、
/// 次の段階で入れる(補強は週給の上限、施設・営業は商業施設とスポンサー、
/// 育成はユースコーチの効き)。数値は自動で何年も回すシミュレーションで測る。
class BudgetEngine {
  const BudgetEngine._();

  /// 1シーズンの週数。年の予算の元になる週収入に掛ける。
  static const int seasonWeeks = 38;

  /// 年の予算の総額(万円)。今の週収入が1シーズン続いた場合の見込み。
  static int annualPool({required int weeklyIncome}) =>
      weeklyIncome <= 0 ? 0 : weeklyIncome * seasonWeeks;

  /// [category] に配る金額(万円)。端数は切り捨てるので、5つの合計が
  /// 総額より少し少なくなることがある。
  static int amountFor(int pool, BudgetPlan plan, BudgetCategory category) =>
      pool * plan.share(category) ~/ 100;

  /// 5つの配り先の金額。端数の切り捨て分は、補強に回して合計を総額に揃える。
  static Map<BudgetCategory, int> allocate(int pool, BudgetPlan plan) {
    final amounts = {
      for (final c in BudgetCategory.values) c: amountFor(pool, plan, c),
    };
    final rest = pool - amounts.values.fold<int>(0, (t, v) => t + v);
    amounts[BudgetCategory.signing] = amounts[BudgetCategory.signing]! + rest;
    return amounts;
  }
}
