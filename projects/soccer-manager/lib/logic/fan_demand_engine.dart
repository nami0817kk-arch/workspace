import 'dart:math';

/// スタジアムに来たいファンの数(需要)。
///
/// 以前の観客数は「収容人数×動員率」で、席を増やせばそのまま入った。
/// 実際は、来たい人より多くは入らない(2部のクラブが6万人のスタジアムを
/// 建てても、6万人は来ない)。観客数は「需要×動員率」と収容人数の小さい
/// ほうにする(2026-11-23)。
///
/// 需要は部(露出・相手の格)と評判(クラブの歴史・知名度の代わり)から
/// 作り、成績と昇格でゆっくり伸び、降格で減る。
class FanDemandEngine {
  const FanDemandEngine._();

  /// 需要の下限と上限(人)。
  static const int minDemand = 3000;
  static const int maxDemand = 90000;

  /// 部ごとの、評判が真ん中(50)のクラブの需要の目安(人)。実際の平均の
  /// 観客数に近い(プレミア 約4万・チャンピオンシップ 約2.2万・
  /// リーグ1 約1万)。
  static int baseForTier(int tier) => switch (tier.clamp(1, 3)) {
        1 => 40000,
        2 => 22000,
        _ => 11000,
      };

  /// 評判(0〜100)による倍率。0.8〜1.2。
  static double reputationFactor(int reputation) =>
      (0.8 + reputation.clamp(0, 100) / 250).clamp(0.8, 1.2);

  /// 部と評判から見た需要の目安(人)。
  static int target(int tier, int reputation) =>
      (baseForTier(tier) * reputationFactor(reputation)).round();

  /// 需要を持たないセーブ(古いセーブ・新しいクラブ)の需要。部と評判の
  /// 目安と、いまのスタジアムの規模(収容人数の85%)の大きいほう。
  /// 古いセーブで増築していたクラブの入りが、読み込んだ途端に大きく
  /// 減らないようにする。
  static int initial({
    required int tier,
    required int reputation,
    required int capacity,
  }) =>
      max(target(tier, reputation), (capacity * 0.85).round())
          .clamp(minDemand, maxDemand);

  /// 順位による動員率の上下(1位 +10%・最下位 -10%)。年間シートが多いので
  /// 順位で大きくは動かない。
  static double rankSwing(int rank, int teamCount) {
    if (teamCount <= 1 || rank <= 0) return 0;
    final r = rank.clamp(1, teamCount);
    return 0.1 * (1 - 2 * (r - 1) / (teamCount - 1));
  }

  /// 季が終わったあとの需要。
  ///
  /// - 成績: 1位 +4%・最下位 -4%(毎季、少しずつ)
  /// - 昇格: 1つ上がるごとに +12%。降格: 1つ下がるごとに -15%
  /// - そのうえで、新しい部と評判の目安へ2割だけ寄る(上の部にいれば
  ///   年を追って伸び、下の部にいれば減っていく)
  static int nextSeason({
    required int demand,
    required int playedTier,
    required int newTier,
    required int finalRank,
    required int teamCount,
    required int reputation,
  }) {
    var d = demand.toDouble();
    d *= 1 + 0.4 * rankSwing(finalRank, teamCount);
    if (newTier < playedTier) {
      d *= pow(1.12, playedTier - newTier);
    } else if (newTier > playedTier) {
      d *= pow(0.85, newTier - playedTier);
    }
    d += (target(newTier, reputation) - d) * 0.2;
    return d.round().clamp(minDemand, maxDemand);
  }
}
