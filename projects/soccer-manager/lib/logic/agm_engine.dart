import '../l10n/tr.dart';

/// 株主総会で株主が出してくる要求。
enum AgmDemand {
  /// 人件費を下げてほしい(人件費率が高い)。
  wageCut,

  /// 配当を増やしてほしい(黒字で、外部の株主がいる)。
  payout,

  /// 監督を替えてほしい(監督の立場が危うい)。
  manager,
}

extension AgmDemandInfo on AgmDemand {
  String get title => switch (this) {
        AgmDemand.wageCut => Tr.pick('株主から「人件費を下げてほしい」', 'Shareholders want the wage bill cut'),
        AgmDemand.payout => Tr.pick('株主から「配当を増やしてほしい」', 'Shareholders want a bigger dividend'),
        AgmDemand.manager => Tr.pick('株主から「監督を替えてほしい」', 'Shareholders want a new manager'),
      };

  String get acceptLabel => switch (this) {
        AgmDemand.wageCut => Tr.pick('来季、人件費率を1割下げると約束する', 'Promise to cut the wage ratio by 10 points'),
        AgmDemand.payout => Tr.pick('上乗せの配当を払う', 'Pay the extra dividend'),
        AgmDemand.manager => Tr.pick('監督を解任する', 'Sack the manager'),
      };

  String get rejectLabel => Tr.pick('断る(株主の期待が下がる)', 'Refuse (shareholder expectation falls)');

  /// 受けたときの株主の期待の増減。
  int get acceptDelta => switch (this) {
        AgmDemand.wageCut => 4,
        AgmDemand.payout => 5,
        AgmDemand.manager => 3,
      };

  /// 断ったときの株主の期待の増減。
  int get rejectDelta => switch (this) {
        AgmDemand.wageCut => -6,
        AgmDemand.payout => -5,
        AgmDemand.manager => -6,
      };
}

/// 株主総会の決まり(要求の選び方・法人税)。
class AgmEngine {
  const AgmEngine._();

  /// 法人税の率(%)。
  static const int taxRatePercent = 30;

  /// 人件費を下げる約束で下げる幅(人件費率の割合)。
  static const double wageCutPoints = 0.10;

  /// 上乗せの配当: 黒字の4分の1を、外部の持分の割合で。
  static int extraPayout({required int profit, required int outsideShare}) =>
      profit <= 0 ? 0 : (profit * 0.25 * outsideShare / 100).round();

  /// 今年の要求を選ぶ(無ければ null)。重いものから1つだけ。
  static AgmDemand? pick({
    required double wageRatio,
    required int profit,
    required int outsideShare,
    required int managerStanding,
    required bool hasManager,
  }) {
    if (wageRatio > 0.8) return AgmDemand.wageCut;
    if (outsideShare > 0 && profit > 0) return AgmDemand.payout;
    if (hasManager && managerStanding < 30) return AgmDemand.manager;
    return null;
  }

  /// 法人税。繰越欠損([carry])を先に差し引く。返すのは (税額, 新しい繰越欠損)。
  static (int, int) tax({required int profit, required int carry}) {
    if (profit <= 0) return (0, carry - profit);
    final taxable = profit - carry;
    if (taxable <= 0) return (0, carry - profit);
    return ((taxable * taxRatePercent / 100).round(), 0);
  }
}
