import 'attributes.dart';
import '../l10n/tr.dart';

/// 選手ごとの個別指示。ロール(PlayerRole)の上に重ねる細かい注文。
///
/// 一律の強化にはしていない。「持ち上がれ」と「守備に残れ」は攻守の
/// 引き換えで、「シュートを狙え」と「内側へ切れ込め」は、その選手に
/// 向いているかどうかで得にも損にもなる。指示を全員に付ければ強くなる、
/// という作りだと選ぶ意味が無い。
enum PlayerInstruction {
  /// 深くまで持ち上がれ。攻撃に厚みが出るが、守備の枚数が減る。
  getForward,

  /// 守備に残れ。守備が安定するが、攻撃に絡まなくなる。
  stayBack,

  /// 積極的にシュートを狙え。ミドルの上手い選手なら得点源になる。
  shootOnSight,

  /// 内側へ切れ込め。ドリブルで中へ入る選手向け。クロスが持ち味の
  /// 選手にやらせると持ち味を殺す。
  cutInside,
}

extension PlayerInstructionInfo on PlayerInstruction {
  String get label => switch (this) {
        PlayerInstruction.getForward => Tr.pick('持ち上がれ', 'Get forward'),
        PlayerInstruction.stayBack => Tr.pick('守備に残れ', 'Stay back'),
        PlayerInstruction.shootOnSight =>
          Tr.pick('シュートを狙え', 'Shoot on sight'),
        PlayerInstruction.cutInside => Tr.pick('内側へ切れ込め', 'Cut inside'),
      };

  String get description => switch (this) {
        PlayerInstruction.getForward => Tr.pick('攻撃に厚みが出るが、守備の枚数が減る。',
            'Adds weight to the attack at the cost of defensive numbers.'),
        PlayerInstruction.stayBack => Tr.pick('守備が安定するが、攻撃に絡まなくなる。',
            'Steadies the defence but takes him out of the attack.'),
        PlayerInstruction.shootOnSight => Tr.pick('ミドルが上手い選手なら得点源になる。下手なら枠を外し続ける。',
            'A weapon if he can shoot from range. A waste if he cannot.'),
        PlayerInstruction.cutInside => Tr.pick('ドリブルで中へ入る選手向け。クロスが持ち味なら殺してしまう。',
            'For a dribbler who comes inside. It smothers a natural crosser.'),
      };

  /// 攻撃力へ掛かる係数。[attributeValue]は選手の能力を引く関数。
  ///
  /// 引き換えのある指示は固定値、向き不向きのある指示は能力差で決まる。
  double attackFactor(int Function(String) attributeValue) =>
      switch (this) {
        PlayerInstruction.getForward => 1.15,
        PlayerInstruction.stayBack => 0.85,
        // ミドルの上手さがそのまま出る。50が分かれ目。
        PlayerInstruction.shootOnSight =>
          1 + (attributeValue(AttributeKeys.longShots) - 50) / 250,
        // ドリブルで中に入る形。クロスの方が持ち味なら下がる。
        PlayerInstruction.cutInside => 1 +
            (attributeValue(AttributeKeys.dribbling) -
                    attributeValue(AttributeKeys.crossing)) /
                250,
      };

  /// 守備力へ掛かる係数。
  double get defenseFactor => switch (this) {
        PlayerInstruction.getForward => 0.85,
        PlayerInstruction.stayBack => 1.15,
        PlayerInstruction.shootOnSight => 1.0,
        PlayerInstruction.cutInside => 1.0,
      };
}
