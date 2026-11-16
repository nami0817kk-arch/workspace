/// 育成予算の効き。配分を変えても、すぐには効かない(2〜3年かけて効く)。
///
/// 「育成の蓄積」は、毎季末に、いまの配分の倍率(初期の配分で 1.0)へ
/// 3分の1ずつ近づく。ユース受け入れの質は、この蓄積に応じて上下する。
/// 厚くして1年目はほとんど変わらず、3年目に大きく効く。削ると、じわじわ
/// 弱くなる。
class YouthInvestmentEngine {
  const YouthInvestmentEngine._();

  /// 蓄積が目標へ近づく割合(1季あたり)。1/3 なら約3年で大半に届く。
  static const double catchUpRate = 1 / 3;

  /// 蓄積(倍率)の下限と上限。
  static const double minMomentum = 0.5;
  static const double maxMomentum = 2.0;

  /// 季末に蓄積を更新する。[ratio] はいまの育成の配分が初期の配分の何倍か。
  static double nextMomentum({required double momentum, required double ratio}) {
    final target = ratio.clamp(minMomentum, maxMomentum);
    final next = momentum + (target - momentum) * catchUpRate;
    return next.clamp(minMomentum, maxMomentum);
  }

  /// ユース受け入れの質(総合力の目安)に足す補正。蓄積 1.0 で0。
  /// 1.0 を0.5上げるごとに +4、下げるごとに -4(-4〜+8)。
  static int qualityBonus(double momentum) =>
      ((momentum - 1.0) * 8).round().clamp(-4, 8);
}
