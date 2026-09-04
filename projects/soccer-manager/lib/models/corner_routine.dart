import 'attributes.dart';
import '../l10n/tr.dart';

/// コーナーキックの狙い。
///
/// どれが強いという順番は無い。狙いごとに「合わせる選手に求められる能力」が
/// 変わるので、手持ちの選手に合うものを選ぶことになる。長身のCFがいるなら
/// ファーで competing、技術の高い選手が揃うならショートが活きる。
enum CornerRoutine {
  /// ファーポストへ放り込む。空中戦の強い選手が合わせる。
  farPost,

  /// ニアに速いボールを入れる。相手より先に触る反応の速さが要る。
  nearPost,

  /// ペナルティエリア手前へ落とす。こぼれ球をミドルで狙う。
  edgeOfBox,

  /// ショートコーナーから崩す。近くの選手と繋いで作り直す。
  shortCorner,
}

extension CornerRoutineInfo on CornerRoutine {
  String get label => switch (this) {
        CornerRoutine.farPost => Tr.pick('ファーで競る', 'Far post'),
        CornerRoutine.nearPost => Tr.pick('ニアで合わせる', 'Near post'),
        CornerRoutine.edgeOfBox => Tr.pick('こぼれ球を狙う', 'Edge of the box'),
        CornerRoutine.shortCorner => Tr.pick('ショートから崩す', 'Short corner'),
      };

  String get description => switch (this) {
        CornerRoutine.farPost => Tr.pick('空中戦に強い選手が合わせる。長身の選手がいるほど活きる。',
            'Aimed at your best header of the ball. Rewards height and heading.'),
        CornerRoutine.nearPost => Tr.pick('相手より先に触る形。反応の速さが要る。',
            'A quick ball in to beat the defender to it. Rewards anticipation.'),
        CornerRoutine.edgeOfBox => Tr.pick('エリア手前へ落とし、ミドルで狙う。',
            'Dropped to the edge for a shot. Rewards long shooting.'),
        CornerRoutine.shortCorner => Tr.pick('繋いで作り直す。技術の高い選手が揃うほど活きる。',
            'Worked short to rebuild the attack. Rewards technique.'),
      };

  /// この狙いで合わせる選手に求められる能力。ここが高い選手が
  /// ターゲットに選ばれ、決定率にも効く。
  String get targetAttribute => switch (this) {
        CornerRoutine.farPost => AttributeKeys.heading,
        CornerRoutine.nearPost => AttributeKeys.anticipation,
        CornerRoutine.edgeOfBox => AttributeKeys.longShots,
        CornerRoutine.shortCorner => AttributeKeys.technique,
      };

  /// 空中戦の質(ヘディングの高さ)が結果に効くかどうか。
  ///
  /// エリア手前とショートは足元の形なので、ヘディングの巧拙は関係しない。
  bool get isAerial =>
      this == CornerRoutine.farPost || this == CornerRoutine.nearPost;
}
