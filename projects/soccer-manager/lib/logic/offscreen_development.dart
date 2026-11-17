import 'dart:math';

import '../models/player.dart';
import '../models/player_stub.dart';

/// 自クラブの部の外(他の部・他国)の選手の、年に1度の伸びと衰え。
///
/// 自クラブの部の選手は毎節の練習で育つが、外の選手は練習を回していない。
/// 何もしないと、外の選手は年をとるだけで能力が変わらず、若手が育たず、
/// ベテランも衰えない。年齢と潜在能力から、1年分の変化をまとめて足す。
class OffscreenDevelopment {
  /// 1年分の総合力の変化(年齢を1つ足した後に呼ぶ)。
  static int yearlyChange(Player p, Random rng) {
    final room = p.potential - p.overall;
    if (p.age <= 23) {
      if (room <= 0) return 0;
      return min(room, 2 + rng.nextInt(4));
    }
    if (p.age <= 28) {
      if (room <= 0) return rng.nextInt(3) - 1;
      return min(room, rng.nextInt(3));
    }
    if (p.age <= 31) return -rng.nextInt(2);
    return -(1 + rng.nextInt(3));
  }

  static void apply(Player p, Random rng) {
    final change = yearlyChange(p, rng);
    if (change == 0) return;
    PlayerStub.matchOverall(p, (p.overall + change).clamp(20, 99));
  }
}
