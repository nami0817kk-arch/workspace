import '../l10n/tr.dart';

/// 契約の中身の型。基本の週給を下げる代わりに、出来高か段階昇給を付ける。
enum ContractStyle {
  /// 固定(今まで通り)。
  fixed,

  /// 出来高: 週給 -10%、リーグ戦の1点ごとに週給の半分。
  goalBonus,

  /// 段階昇給: 週給 -8%、季が変わるたびに +5%。
  stepped,
}

extension ContractStyleInfo on ContractStyle {
  String get label => switch (this) {
        ContractStyle.fixed => Tr.pick('固定', 'Fixed'),
        ContractStyle.goalBonus => Tr.pick('出来高', 'Goal bonus'),
        ContractStyle.stepped => Tr.pick('段階昇給', 'Stepped rises'),
      };

  String get summary => switch (this) {
        ContractStyle.fixed => Tr.pick('年俸は一定。', 'The salary stays the same.'),
        ContractStyle.goalBonus => Tr.pick(
            '年俸を1割下げ、リーグ戦で1点取るごとに出来高(年俸の約1%)を払う。点を取る選手ほど高くつく。',
            'Salary down 10%; a bonus of about 1% of it for every league goal. Costs more for scorers.'),
        ContractStyle.stepped => Tr.pick('年俸を8%下げ、季が変わるたびに5%上げる。長い契約ほど後で高くつく。',
            'Salary down 8%, then up 5% every season. Long deals cost more later.'),
      };

  /// 今の週給からの、新しい週給・出来高・昇給率。
  (int wage, int goalBonus, int raisePct) apply(int wage) => switch (this) {
        ContractStyle.fixed => (wage, 0, 0),
        ContractStyle.goalBonus => (
            (wage * 0.9).round(),
            (wage * 0.5).round().clamp(1, 1 << 30),
            0
          ),
        ContractStyle.stepped => ((wage * 0.92).round(), 0, 5),
      };
}
