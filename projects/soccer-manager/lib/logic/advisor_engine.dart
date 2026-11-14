import '../l10n/tr.dart';

/// 経営アドバイザー。雇うほど効果が大きいが、毎季の報酬が掛かる。
enum Advisor {
  /// 財務: 営業収入が増える。
  finance,

  /// 強化: 施設の増築費が下がる。
  scouting,

  /// 広報: 毎季末にサポーターの期待が上がり、不祥事の傷が浅くなる。
  pr;

  String get label => switch (this) {
        finance => Tr.pick('財務顧問', 'Finance advisor'),
        scouting => Tr.pick('強化顧問', 'Development advisor'),
        pr => Tr.pick('広報顧問', 'PR advisor'),
      };

  String effect(int level) => switch (this) {
        finance => Tr.pick('営業収入 +${level * 2}%', 'Operating income +${level * 2}%'),
        scouting => Tr.pick('施設の増築費 -${level * 4}%', 'Facility cost -${level * 4}%'),
        pr => Tr.pick('毎季末にサポーターの期待+$level、不祥事の傷が軽くなる',
            'Supporters +$level each season end; scandals hurt less'),
      };
}

class AdvisorEngine {
  const AdvisorEngine._();

  static const int maxLevel = 3;

  /// 1人あたりの毎季の報酬(万円)。
  static int salary(int level) => 150 * level;

  /// 営業収入に掛ける倍率。
  static double incomeMultiplier(int financeLevel) => 1 + 0.02 * financeLevel;

  /// 施設の増築費に掛ける倍率。
  static double facilityCostMultiplier(int scoutingLevel) =>
      1 - 0.04 * scoutingLevel;

  /// 3人の報酬の合計(毎季)。
  static int totalSalary(Map<String, int> levels) => Advisor.values
      .fold<int>(0, (s, a) => s + salary(levels[a.name] ?? 0));
}
