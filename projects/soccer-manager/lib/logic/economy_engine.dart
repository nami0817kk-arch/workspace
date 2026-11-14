import '../l10n/tr.dart';

/// 景気。シーズンごとに好況・平常・不況のどれかで、収入に効く。
/// 名前(name)はセーブに残すので、変えない。
enum EconomyPhase {
  boom,
  normal,
  slump;

  String get label => switch (this) {
        boom => Tr.pick('好況', 'Boom'),
        normal => Tr.pick('平常', 'Normal'),
        slump => Tr.pick('不況', 'Slump'),
      };

  /// 観客・スポンサー・グッズの収入にかかる倍率。
  double get incomeMultiplier => switch (this) {
        boom => 1.10,
        normal => 1.0,
        slump => 0.88,
      };

  String get summary => switch (this) {
        boom => Tr.pick('収入が10%増えます。', 'Income is up 10%.'),
        normal => Tr.pick('収入に影響はありません。', 'No effect on income.'),
        slump => Tr.pick('収入が12%減ります。人件費は減りません。',
            'Income is down 12%. Wages do not fall.'),
      };
}

class EconomyEngine {
  const EconomyEngine._();

  /// 次のシーズンの景気。[roll]は 0 以上 1 未満の乱数。
  ///
  /// 平常からは好況・不況へ2割ずつ動く。好況・不況は居座りやすいが、
  /// 逆の極端へはほとんど動かず、まず平常に戻る。
  static EconomyPhase next(EconomyPhase current, double roll) {
    // (好況, 平常) の境目。残りは不況。
    final (boomUpTo, normalUpTo) = switch (current) {
      EconomyPhase.normal => (0.20, 0.80),
      EconomyPhase.boom => (0.40, 0.90),
      EconomyPhase.slump => (0.10, 0.60),
    };
    if (roll < boomUpTo) return EconomyPhase.boom;
    if (roll < normalUpTo) return EconomyPhase.normal;
    return EconomyPhase.slump;
  }
}
