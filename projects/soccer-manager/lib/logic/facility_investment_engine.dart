/// 施設予算の効き。スタジアムへの投資は、3〜5年かけて観客収入に返る。
///
/// 「施設の蓄積」は、毎季末にいまの配分の倍率(初期の配分で 1.0)へ4分の1ずつ
/// 近づく(育成の3分の1より遅い)。観客収入は、この蓄積に応じて上下する。
/// 初期の配分のままなら 1.0 のままで、既存のプレイの収入は動かない。
class FacilityInvestmentEngine {
  const FacilityInvestmentEngine._();

  /// 蓄積が目標へ近づく割合(1季あたり)。
  static const double catchUpRate = 1 / 4;

  static const double minMomentum = 0.6;
  static const double maxMomentum = 1.8;

  /// 季末に蓄積を更新する。[ratio] は施設の配分が初期の配分の何倍か。
  static double nextMomentum({required double momentum, required double ratio}) {
    final target = ratio.clamp(minMomentum, maxMomentum);
    return (momentum + (target - momentum) * catchUpRate)
        .clamp(minMomentum, maxMomentum);
  }

  /// 観客収入に掛ける倍率。蓄積 1.0 で 1.0。0.94〜1.12。
  static double gateMultiplier(double momentum) =>
      (1 + (momentum - 1.0) * 0.15).clamp(0.94, 1.12);
}
