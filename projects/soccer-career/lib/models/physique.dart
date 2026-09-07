import 'dart:math';

import 'attributes.dart';

/// 利き足。
enum Foot {
  right('右足'),
  left('左足'),
  both('両利き');

  const Foot(this.label);

  final String label;
}

/// オフの肉体改造の方針。
enum BodyPlan {
  bulk('増量', '筋力は増すが、キレは落ちる'),
  cut('減量', '動きは軽くなるが、当たりに弱くなる'),
  maintain('維持', '無理をしない。疲れを残さずシーズンに入る');

  const BodyPlan(this.label, this.description);

  final String label;
  final String description;
}

/// 身体データ。
///
/// 能力値と違って練習では動かない。ここが「同じ総合力でも別の選手」を作る。
/// 高さはヘディングを、体重は当たりの強さと機動力を、利き足は逆足の扱いを決める。
class Physique {
  const Physique({
    required this.heightCm,
    required this.weightKg,
    this.foot = Foot.right,
    this.weakFoot = 2,
  });

  final int heightCm;
  final int weightKg;
  final Foot foot;

  /// 逆足の精度 1〜5。低いと逆足の局面で大きく落ちる。
  final int weakFoot;

  /// 標準体型。ここからのずれが補正になる。
  static const int baseHeight = 178;
  static const int baseWeight = 74;

  /// 補正の上限。身体だけで能力が決まってしまわないようにする。
  static const int maxBonus = 6;

  /// ポジションに合わせて引く。GK と CB は高く、WG は小さく速い。
  factory Physique.roll(Random random, Position position) {
    final center = switch (position) {
      Position.gk => 189,
      Position.cb => 187,
      Position.st => 182,
      Position.dm => 180,
      Position.cm => 177,
      Position.sb => 176,
      Position.am => 174,
      Position.wg => 173,
    };
    final height = center + random.nextInt(7) + random.nextInt(7) - 6;
    // 身長なりの体重に、体型のばらつきを足す。
    final weight = ((height - 100) * 0.86).round() + random.nextInt(9) - 4;
    // 左利きは2割強。両利きは稀。
    final roll = random.nextDouble();
    final foot = roll < 0.22
        ? Foot.left
        : roll < 0.25
            ? Foot.both
            : Foot.right;
    return Physique(
      heightCm: height,
      weightKg: weight,
      foot: foot,
      weakFoot: foot == Foot.both ? 5 : 1 + random.nextInt(3),
    );
  }

  double get _h => (heightCm - baseHeight) / 1.0;
  double get _w => (weightKg - baseWeight) / 1.0;

  /// 体格の見出し。体重と身長の比から決める。
  String get buildLabel {
    final expected = (heightCm - 100) * 0.86;
    final diff = weightKg - expected;
    if (diff >= 5) return 'がっしり';
    if (diff <= -5) return '細身';
    return '標準';
  }

  /// 身体が詳細能力に与える増減。試合の判定に使う。
  ///
  /// 能力値そのものは書き換えない。練習で積み上げた数字と、生まれ持った
  /// 身体を別々に持っておかないと、増量した瞬間に「伸びた」ように見える。
  int bonusFor(Detail detail) {
    final value = switch (detail) {
      Detail.heading => _h * 0.35 + _w * 0.12,
      Detail.jumping => _h * 0.20 - _w * 0.10,
      Detail.strength => _h * 0.10 + _w * 0.35,
      Detail.stamina => -_w * 0.20,
      Detail.acceleration => -_w * 0.22 - _h * 0.08,
      Detail.sprintSpeed => -_w * 0.14 + _h * 0.06,
      Detail.agility => -_h * 0.18 - _w * 0.14,
      Detail.dribbling => -_h * 0.10,
      Detail.ballControl => -_h * 0.06,
      Detail.shotPower => _w * 0.12 + _h * 0.06,
      Detail.tackling => _h * 0.08 + _w * 0.10,
      Detail.reflexes => _h * 0.10,
      Detail.handling => _h * 0.08,
      Detail.gkPositioning => _h * 0.12,
      _ => 0.0,
    };
    return value.round().clamp(-maxBonus, maxBonus);
  }

  /// 画面に出す用。効いているものだけを並べる。
  List<String> get effects => [
        for (final d in Detail.values)
          if (bonusFor(d) != 0)
            '${d.label} ${bonusFor(d) > 0 ? '+' : ''}${bonusFor(d)}',
      ];

  /// オフの肉体改造。体重だけが動く。
  Physique afterOffseason(BodyPlan plan) => switch (plan) {
        BodyPlan.bulk => copyWith(weightKg: weightKg + 3),
        BodyPlan.cut => copyWith(weightKg: max(55, weightKg - 3)),
        BodyPlan.maintain => this,
      };

  Physique copyWith({int? weightKg, int? weakFoot}) => Physique(
        heightCm: heightCm,
        weightKg: weightKg ?? this.weightKg,
        foot: foot,
        weakFoot: (weakFoot ?? this.weakFoot).clamp(1, 5),
      );

  String get label => '$heightCm cm  ·  $weightKg kg  ·  ${foot.label}';

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'foot': foot.name,
        'weakFoot': weakFoot,
      };

  /// 身体データを持たせる前の保存データは、標準体型として読む。
  factory Physique.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Physique(heightCm: baseHeight, weightKg: baseWeight);
    return Physique(
      heightCm: json['heightCm'] as int? ?? baseHeight,
      weightKg: json['weightKg'] as int? ?? baseWeight,
      foot: Foot.values.any((f) => f.name == json['foot'])
          ? Foot.values.byName(json['foot'] as String)
          : Foot.right,
      weakFoot: json['weakFoot'] as int? ?? 2,
    );
  }
}
