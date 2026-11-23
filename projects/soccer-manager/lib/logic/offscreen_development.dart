import 'dart:math';

import '../models/player.dart';
import '../models/player_stub.dart';
import 'training_engine.dart';

/// 自クラブの部の外(他の部・他国)の選手の、年に1度の伸びと衰え。
///
/// 自クラブの部の選手は毎節の練習で育つが、外の選手は練習を回していない。
/// 何もしないと、外の選手は年をとるだけで能力が変わらず、若手が育たず、
/// ベテランも衰えない。年齢と潜在能力から、1年分の変化をまとめて足す。
class OffscreenDevelopment {
  /// 1年分の総合力の変化(年齢を1つ足した後に呼ぶ)。
  ///
  /// 衰えは画面に出る選手([TrainingEngine]の毎週の衰え)と同じ決まりで
  /// 見る: 成長の型とポジションで決まる年齢([TrainingEngine.declineStartAge])
  /// から落ち始め、その翌年から速まる([TrainingEngine.declineSeverity])。
  /// 以前は成長の型を見ず、29歳から一律に落ち、32歳からも年1〜3で
  /// 頭打ちだったので、同じ選手でも画面に出るかで落ち方が違った(2026-11-22)。
  ///
  /// 23歳以下の伸びは、画面に出る CPU のクラブの1年の練習
  /// ([TrainingEngine.applyPassiveCpuGrowth])を回した平均に合わせてある
  /// (17歳 約5.0・19歳 4.6・21歳 3.7・23歳 2.8。部の倍率
  /// [TrainingEngine.cpuStandardGrowthMultiplier]も同じに掛ける)。以前は
  /// 年齢を見ずに +2〜5(平均3.5)だった(2026-11-23)。
  static int yearlyChange(Player p, Random rng, {int? tier}) {
    final room = p.potential - p.overall;
    // ポジションでピークがずれる(GK は長く保ち、サイドの選手は早く落ちる)。
    final shift = TrainingEngine.positionPeakShift(p.position);
    if (p.age >= TrainingEngine.declineStartAge(p)) {
      final mean = TrainingEngine.yearlyDeclineEstimate(p);
      // 目安の前後に少し散らす(0.5〜1.5倍)。
      final drop = (mean * (0.5 + rng.nextDouble())).round();
      return -drop;
    }
    if (p.age <= 23) {
      if (room <= 0) return 0;
      final mean = youngYearlyGain(p.age) *
          TrainingEngine.cpuStandardGrowthMultiplier(tier);
      return min(room, (mean * (0.5 + rng.nextDouble())).round());
    }
    if (p.age <= 28 + shift) {
      if (room <= 0) return rng.nextInt(3) - 1;
      return min(room, rng.nextInt(3));
    }
    // ピークを過ぎて衰えが始まるまでは、ほぼ横ばい。
    return room > 0 ? rng.nextInt(2) : -rng.nextInt(2);
  }

  /// 23歳以下の1年の伸びの目安(部の倍率 1.0、伸びしろが十分あるとき)。
  static double youngYearlyGain(int age) =>
      5.0 - 0.37 * (age.clamp(17, 23) - 17);

  static void apply(Player p, Random rng, {int? tier}) {
    final change = yearlyChange(p, rng, tier: tier);
    if (change == 0) return;
    PlayerStub.matchOverall(p, (p.overall + change).clamp(20, 99));
  }
}
