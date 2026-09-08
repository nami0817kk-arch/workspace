import '../models/attributes.dart';
import 'formulas.dart';

/// 能力の依存関係。
///
/// 「筋力20のまま最高速だけ99」のような選手を作れないようにする。
/// 各能力には土台になる能力があり、そこから離れすぎると伸びなくなる。
/// 伸ばせなかった週は、代わりに土台のほうが伸びる。遠回りに見えて、
/// 結局そこを鍛えないと先に進めない、という現実の練習に近づける。
class Dependencies {
  const Dependencies._();

  /// 土台になる能力。空なら土台そのもの。
  static const Map<Detail, List<Detail>> supports = {
    Detail.sprintSpeed: [Detail.strength, Detail.stamina],
    Detail.acceleration: [Detail.strength, Detail.agility],

    Detail.finishing: [Detail.ballControl, Detail.shotPower],
    Detail.shotPower: [Detail.strength],
    Detail.longShots: [Detail.shotPower, Detail.vision],
    Detail.heading: [Detail.jumping, Detail.strength],

    Detail.longPassing: [Detail.shortPassing, Detail.vision],
    Detail.crossing: [Detail.longPassing, Detail.ballControl],
    Detail.vision: [Detail.shortPassing],

    Detail.dribbling: [Detail.ballControl, Detail.agility],

    Detail.tackling: [Detail.strength, Detail.agility],
    Detail.interceptions: [Detail.marking, Detail.vision],

    Detail.jumping: [Detail.strength],

    Detail.handling: [Detail.reflexes, Detail.strength],
    Detail.gkPositioning: [Detail.reflexes, Detail.vision],
  };

  /// 土台からどれだけ先行できるか。
  static const int headroom = 18;

  /// その能力の当面の上限。土台の平均 + [headroom]。
  ///
  /// [ceiling] はその能力そのものの上限（普通は 99、超越の特性なら 109）で、
  /// 土台を持たない能力にだけ効く。土台を持つ能力は、土台の平均 + headroom が
  /// 99 を超えていても**ここでは丸めない**。丸めると 99 に達した能力の成長が
  /// 土台へ流れて全体が膨らむ（実測で代表経験 57%→63%）。99 で止まるのは
  /// [Attributes.bumpDetail] の側。
  static int capFor(Detail detail, Attributes attributes,
      {int ceiling = Formulas.maxAttribute}) {
    final base = supports[detail];
    if (base == null || base.isEmpty) return ceiling;
    final sum = base.fold(0, (s, d) => s + attributes.detail(d));
    return (sum / base.length).round() + headroom;
  }

  /// 今それ以上伸ばせないか。
  static bool blocked(Detail detail, Attributes attributes,
          {int ceiling = Formulas.maxAttribute}) =>
      attributes.detail(detail) >= capFor(detail, attributes, ceiling: ceiling);

  /// 頭打ちのとき、代わりに伸ばすべき土台。一番低いところから鍛える。
  static Detail? weakestSupport(Detail detail, Attributes attributes) {
    final base = supports[detail];
    if (base == null || base.isEmpty) return null;
    return base.reduce(
        (a, b) => attributes.detail(a) <= attributes.detail(b) ? a : b);
  }

  /// 伸ばす先を決める。頭打ちなら土台に回す。
  ///
  /// 返すのは実際に伸ばす詳細能力。土台も頭打ちなら、そこからさらに
  /// 下の土台へ回す（最大3段）。
  static Detail resolve(Detail wanted, Attributes attributes,
      {int Function(Detail)? ceilingOf}) {
    var target = wanted;
    for (var i = 0; i < 3; i++) {
      final ceiling = ceilingOf?.call(target) ?? Formulas.maxAttribute;
      if (!blocked(target, attributes, ceiling: ceiling)) return target;
      final next = weakestSupport(target, attributes);
      if (next == null) return target;
      target = next;
    }
    return target;
  }
}
