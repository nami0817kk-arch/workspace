import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';
import 'support/deleg.dart';

/// 「責任者に任せる」（1.0.0+20）の釣り合いを測って書き出す。時間がかかるので、手元で回すときだけ（QUAD_H_BALANCE を渡す）:
///   QUAD_H_BALANCE=1 flutter test test/h_balance_test.dart
///
/// 1.0.0+20 で測った値:
///
/// ■ 同じお金で、人が最善手を打ったときとの比べ（1985年から10年育てた5つの盤面 × 6本 × 60か月。責任者のいる事業を全部任せる）
///   物差しは「打った手の、事業の力の伸びの見込み」（商品の大当たり・不発をならした値）を、使ったお金で割ったもの。
///   実際の売上・力の伸びは、商品の大当たり1つで何倍も変わり、30本を足しても比が定まらなかったので、物差しにしていない
///   ・月の枠 元手の1倍:  0.84（使ったお金は最善手の 52%）
///   ・月の枠 元手の3倍:  0.79（同 44%）
///   ・月の枠 元手の10倍: 0.76（同 45%）
///   → 同じお金なら、任せた事業の伸びは人の最善手の 7〜9割。責任者は1件ずつ仕上げるので、使うお金も人の半分ほど
///
/// ■ 同じ種で30年の自動プレイ（1985年から・9つの種。空いている部下は、どの遊び方でも責任者に置く）
///   時価総額の中央値／世界の順位の中央値
///   ・全部自分で:           6.12兆円／182位
///   ・半分任せる（枠1倍）:  13.0兆円／102位
///   ・全部任せる（枠1倍）:  6.95兆円／157位
///   ・半分任せる（枠3倍）:  13.2兆円／100位
///   ・全部任せる（枠3倍）:  10.2兆円／117位
///   ・全部任せる（枠10倍）: 13.2兆円／107位
///   → 任せると、社長の手（月5つ）で届かない事業にも手が入るぶん伸びる。いちばん伸びたのは「半分任せて、残りは自分で」。
///     種ごとのばらつきは大きい（全部任せる・枠1倍で 9,746億円〜130兆円）
void main() {
  final on = Platform.environment['QUAD_H_BALANCE'] != null;
  const seeds = [11, 23, 35, 77, 2024];

  test('任せたときの伸び ÷ 人が同じお金で最善手を打ったときの伸び', () {
    for (final budget in const [1, 2, 3]) {
      var spA = 0.0, spB = 0.0, gA = 0.0, gB = 0.0;
      final each = <double>[];
      for (final seed in seeds) {
        final g = Game.newGame(SetupConfig(mode: 'endless', year: 1985, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
        for (var m = 0; m < 120 && g.over == null; m++) {
          delegMonth(g, 'none');
        }
        resolveEvents(g);
        for (final s2 in const [5, 6, 7, 8, 9, 10]) {
          final r = delegVsBest(g, budget: budget, seed: s2);
          spA += r.spentA;
          spB += r.spentB;
          gA += r.gainA;
          gB += r.gainB;
          each.add((r.gainA / r.spentA) / (r.gainB / r.spentB));
        }
      }
      // ignore: avoid_print
      print('H-BAL 枠${delegMults[budget]}倍（${each.length}本・60か月）: 同じお金あたりの力の伸びの見込みの比 ${((gA / spA) / (gB / spB)).toStringAsFixed(3)}'
          '（1本ごと 最小 ${each.reduce(math.min).toStringAsFixed(2)}・中央 ${median(each).toStringAsFixed(2)}・最大 ${each.reduce(math.max).toStringAsFixed(2)}）・'
          '使ったお金の比 ${(spA / spB).toStringAsFixed(3)}（任せた ${yenJa(spA)} / 最善手 ${yenJa(spB)}）');
    }
  }, skip: !on, timeout: const Timeout(Duration(minutes: 20)));

  test('同じ種で30年：全部自分で・半分任せる・全部任せる', () {
    const seeds30 = [11, 23, 35, 41, 59, 77, 101, 500, 2024];
    for (final v in const [('none', 1), ('half', 1), ('all', 1), ('half', 2), ('all', 2), ('all', 3)]) {
      final rs = [for (final s in seeds30) delegRun(s, v.$1, budget: v.$2)];
      // ignore: avoid_print
      print('H-BAL30 ${v.$1} 枠${delegMults[v.$2]}倍: 時価総額 中央 ${yenJa(median([for (final r in rs) r.cap]))}・月の売上 中央 ${yenJa(median([for (final r in rs) r.rev]))}・'
          '事業の力 中央 ${yenJa(median([for (final r in rs) r.power]))}・順位 中央 ${median([for (final r in rs) r.rank.toDouble()]).round()}・'
          '種ごとの時価総額 ${rs.map((r) => yenJa(r.cap)).join(' ')}・順位 ${rs.map((r) => r.rank).join(' ')}・倒産 ${rs.where((r) => r.over != null).length}');
    }
  }, skip: !on, timeout: const Timeout(Duration(minutes: 30)));
}
