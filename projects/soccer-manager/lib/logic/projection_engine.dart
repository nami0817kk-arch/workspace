import 'dart:math';

import 'agm_engine.dart';

/// 5年の収支の見込みの1年分。
class ProjectionYear {
  /// 何年後か(1〜5)。
  final int yearAhead;
  final int income;
  final int wages;
  final int otherCosts;
  final int tax;

  /// 年度末の資金。
  final int budget;

  const ProjectionYear({
    required this.yearAhead,
    required this.income,
    required this.wages,
    required this.otherCosts,
    required this.tax,
    required this.budget,
  });

  int get profit => income - wages - otherCosts - tax;
}

/// 今の収入と人件費が続いたときの、5年の収支の見込み。
///
/// 目安でしかない(順位・昇降格・移籍は入れない)。オーナーが「このまま
/// だと何年で資金が尽きるか」「人件費の伸びに収入が追いつくか」を見るため。
class ProjectionEngine {
  const ProjectionEngine._();

  /// 収入の年の伸び(%)。
  static const int incomeGrowthPercent = 3;

  /// 人件費の年の伸び(%)。昇給と契約の更新で、収入より少し速く伸びる。
  static const int wageGrowthPercent = 5;

  /// [income] [wages] [otherCosts] は1年分(万円)。[budget]は今の資金。
  /// [lossCarry]は法人税の繰越欠損。
  static List<ProjectionYear> project({
    required int income,
    required int wages,
    required int otherCosts,
    required int budget,
    int lossCarry = 0,
    int years = 5,
  }) {
    final out = <ProjectionYear>[];
    var inc = income.toDouble();
    var wag = wages.toDouble();
    var b = budget;
    var carry = lossCarry;
    for (var y = 1; y <= years; y++) {
      inc *= 1 + incomeGrowthPercent / 100;
      wag *= 1 + wageGrowthPercent / 100;
      final pre = inc.round() - wag.round() - otherCosts;
      final (tax, nextCarry) = AgmEngine.tax(profit: pre, carry: carry);
      carry = nextCarry;
      b += pre - tax;
      out.add(ProjectionYear(
        yearAhead: y,
        income: inc.round(),
        wages: wag.round(),
        otherCosts: otherCosts,
        tax: tax,
        budget: b,
      ));
    }
    return out;
  }

  /// 季の途中の数字を1年分に引き延ばす。[progress]は季の進み(0〜1)。
  /// 進みが小さすぎるときは引き延ばさない(誤差が大きい)。
  static int annualize(int soFar, double progress) =>
      progress < 0.15 ? soFar : (soFar / max(progress, 0.15)).round();
}
