import '../l10n/tr.dart';

/// 経営アドバイザー。雇うほど効果が大きいが、毎季の報酬が掛かる。
enum Advisor {
  /// 財務: 営業収入が増える。
  finance,

  /// 強化: 施設の増築費が下がる。
  scouting,

  /// 広報: 毎季末にサポーターの期待が上がり、不祥事の傷が浅くなる。
  pr,

  /// 法務: 財務規則の違反で科される罰金が軽くなる。
  legal;

  String get label => switch (this) {
        finance => Tr.pick('財務顧問', 'Finance advisor'),
        scouting => Tr.pick('強化顧問', 'Development advisor'),
        pr => Tr.pick('広報顧問', 'PR advisor'),
        legal => Tr.pick('法務顧問', 'Legal advisor'),
      };

  /// 何をする顧問か(1行)。
  String get description => switch (this) {
        finance => Tr.pick('観客・スポンサー・グッズの収入を増やす',
            'Raises gate, sponsor and merchandise income'),
        scouting =>
          Tr.pick('施設の増築費を下げる', 'Cuts what facility upgrades cost'),
        pr => Tr.pick('毎季末にサポーターの期待を上げ、不祥事の傷を浅くする',
            'Lifts supporters each season end and softens scandals'),
        legal => Tr.pick('財務規則の違反の罰金を軽くする',
            'Cuts fines for breaking the financial rules'),
      };

  /// 表の1マスに入る短い効き目(「+2%」「期待+1」)。
  String shortEffect(int level) => switch (this) {
        finance => Tr.pick('収入 +${level * 2}%', 'Income +${level * 2}%'),
        scouting => Tr.pick('増築費 -${level * 4}%', 'Upgrades -${level * 4}%'),
        pr => Tr.pick('期待 +$level/季', 'Fans +$level/season'),
        legal => Tr.pick('罰金 -${level * 15}%', 'Fines -${level * 15}%'),
      };

  String effect(int level) => switch (this) {
        finance => Tr.pick('営業収入 +${level * 2}%', 'Operating income +${level * 2}%'),
        scouting => Tr.pick('施設の増築費 -${level * 4}%', 'Facility cost -${level * 4}%'),
        pr => Tr.pick('毎季末にサポーターの期待+$level、不祥事の傷が軽くなる',
            'Supporters +$level each season end; scandals hurt less'),
        legal => Tr.pick('規則違反の罰金 -${level * 15}%',
            'Rule-breach fines -${level * 15}%'),
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

  /// 規則違反の罰金に掛ける倍率。法務顧問のレベルが高いほど軽くなる。
  static double fineMultiplier(int legalLevel) =>
      (1 - 0.15 * legalLevel).clamp(0.0, 1.0);

  /// 全顧問の報酬の合計(毎季)。
  static int totalSalary(Map<String, int> levels) => Advisor.values
      .fold<int>(0, (s, a) => s + salary(levels[a.name] ?? 0));
}
