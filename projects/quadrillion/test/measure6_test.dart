// 段6の釣り合いの測り（1.1.0+30）。ふだんの CI では回さない（QUAD_MEASURE にファイルを渡したときだけ回す）。
// 4つの打ち方（借りまくる・少し借りる・借りない・海外に出る。どれも「ふつうの上手な人」の打ち方 support/pro.dart）を同じ種で30年回し、
// 1つの行に「結果・最後の時価・時価の最高・最高の順位」を書き、最後に世界の上位10社（1980・2000・2010）を書き出す。
// QUAD_SEEDS に種を , で並べると、その種で回す（既定は段4と同じ 11,22,33,44,55,66）。QUAD_OLD=1 で段4までの自動プレイ（botMonth）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'real_balance_test.dart' show play;
import 'support/bot.dart';
import 'support/pro.dart';

void main() {
  final f = Platform.environment['QUAD_MEASURE'];
  final seeds = (Platform.environment['QUAD_SEEDS'] ?? '11,22,33,44,55,66').split(',').map(int.parse).toList();
  final hows = (Platform.environment['QUAD_HOWS'] ?? 'max,some,none,abroad').split(',');
  final old = Platform.environment['QUAD_OLD'] == '1';
  test('段6の測り（4つの打ち方・30年）', () {
    final out = StringBuffer();
    for (final seed in seeds) {
      for (final how in hows) {
        out.writeln(play(how == 'abroad' ? 'none' : how, seed, old: old, abroad: how == 'abroad').toString());
        File(f!).writeAsStringSync(out.toString());
      }
    }
    // 世界の上位10社（少し借りる・最初の種）
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: const ['charm', 'careful'], home: 'jp'), rng: ParkMiller(seeds.first));
    void top(int y) {
      final rk = g.rankList();
      final me = rk.indexWhere((x) => x.me) + 1;
      out.writeln('top $y: ${rk.where((r) => !r.me).take(10).map((r) => yen(r.cap)).join(' | ')} | 自社 $me位 ${yen(g.cap + g.wealth)}');
    }

    top(1980);
    for (var m = 0; m < 30 * 12; m++) {
      proMonth(g);
      if (g.won != null) {
        g.mode = 'endless';
        g.won = null;
      }
      if (g.over != null) break;
      if (g.q == 1 && (g.year == 2000 || g.year == 2010)) top(g.year);
    }
    File(f!).writeAsStringSync(out.toString());
  }, skip: f == null ? 'QUAD_MEASURE が無いときは回さない' : null, timeout: const Timeout(Duration(minutes: 120)));
}
