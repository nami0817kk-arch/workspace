import '../l10n/tr.dart';

/// 対戦相手への対策指示。
///
/// スカウティングレポートは相手の強み・弱み・キーマンを教えてくれるが、
/// 読むだけで手が打てなかった(マンマーク指名だけは例外)。読んだ内容を
/// 手に取れるようにする。
///
/// どれかが常に得ということはない。相手に弱いサイドが無ければ「そこを狙う」
/// は空振りするし、守りを固めれば点は取りにくくなる。相手を見て選ぶ。
enum OppositionPlan {
  /// 特に対策を立てない。
  none,

  /// 相手の司令塔を潰す。相手の攻撃を鈍らせるが、こちらも運動量を割く。
  pressPlaymaker,

  /// 相手の弱いサイドを集中して突く。相手にそこが無ければ効かない。
  targetWeakFlank,

  /// 中央を固めて構える。守備が安定する代わりに攻撃の枚数が減る。
  stayCompact,
}

extension OppositionPlanInfo on OppositionPlan {
  String get label => switch (this) {
        OppositionPlan.none => Tr.pick('特になし', 'No special plan'),
        OppositionPlan.pressPlaymaker =>
          Tr.pick('司令塔を潰す', 'Press their playmaker'),
        OppositionPlan.targetWeakFlank =>
          Tr.pick('弱いサイドを突く', 'Target their weak flank'),
        OppositionPlan.stayCompact => Tr.pick('中央を固める', 'Stay compact'),
      };

  String get description => switch (this) {
        OppositionPlan.none =>
          Tr.pick('相手に合わせた対策は行わない。', 'You set up without regard to the opponent.'),
        OppositionPlan.pressPlaymaker => Tr.pick(
            '相手の組み立てを止めにいく。相手の攻撃が鈍る代わりに、こちらの攻撃にも人数を割けない。',
            'You go after the man who makes them tick. Blunts them, but you commit bodies to it.'),
        OppositionPlan.targetWeakFlank => Tr.pick(
            '相手の手薄なサイドへ人数をかける。効き目は相手のサイドの弱さ次第で、手薄でなければ空振りする。',
            'You overload their weaker side. How much it pays depends on how weak that side really is.'),
        OppositionPlan.stayCompact => Tr.pick(
            '中央を閉じて構える。守備は安定するが、前に出る枚数が減る。',
            'You shut the middle and hold your shape. Solid, but fewer bodies go forward.'),
      };

  /// 自チームの攻撃力に掛かる係数(弱いサイドを突く場合を除く)。
  double get ownAttackFactor => switch (this) {
        OppositionPlan.none => 1.0,
        OppositionPlan.pressPlaymaker => 0.96,
        OppositionPlan.targetWeakFlank => 1.0,
        OppositionPlan.stayCompact => 0.94,
      };

  /// 自チームの守備力に掛かる係数。
  double get ownDefenseFactor => switch (this) {
        OppositionPlan.none => 1.0,
        OppositionPlan.pressPlaymaker => 1.0,
        OppositionPlan.targetWeakFlank => 0.97,
        OppositionPlan.stayCompact => 1.08,
      };

  /// 相手チームの攻撃力に掛かる係数。
  double get opponentAttackFactor => switch (this) {
        OppositionPlan.pressPlaymaker => 0.92,
        _ => 1.0,
      };
}
