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

  /// [category] の配分が初期の配分の何倍か。1.0 のとき効きは変わらない。
  /// 初期の配分のままなら、既存のプレイの数字は一切動かない。
  static double ratio(BudgetPlan plan, BudgetCategory category) =>
      plan.share(category) / BudgetPlan.balanced().share(category);

  static double _scaled(
    BudgetPlan plan,
    BudgetCategory category,
    double perRatio,
    double min,
    double max,
  ) =>
      (1 + (ratio(plan, category) - 1) * perRatio).clamp(min, max).toDouble();

  /// 営業の配分が、チケット・スポンサー・グッズの週収入に掛かる倍率。
  /// 0.90〜1.15。営業を厚くするほど収入が増え、削ると減る。
  static double incomeMultiplier(BudgetPlan plan) =>
      _scaled(plan, BudgetCategory.marketing, 0.15, 0.90, 1.15);

  /// 補強の配分が、理事会の週給予算(上限)に掛かる倍率。0.85〜1.20。
  static double wageCapMultiplier(BudgetPlan plan) =>
      _scaled(plan, BudgetCategory.signing, 0.15, 0.85, 1.20);

  /// 施設の配分が、施設の増築費用に掛かる倍率。0.80〜1.10。厚いほど安い。
  static double facilityCostMultiplier(BudgetPlan plan) {
    final r = ratio(plan, BudgetCategory.facilities);
    return (1 - (r - 1) * 0.15).clamp(0.80, 1.10).toDouble();
  }

  /// 配当の配分が、シーズン終了時の株主の期待に足す増減。-4〜+4。
  /// 初期の配分(20%)で0。配るほど株主は喜ぶが、他の配り先が削られる。
  static int dividendExpectationDelta(BudgetPlan plan) =>
      ((plan.share(BudgetCategory.dividend) - 20) / 5).round().clamp(-4, 4);

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
