// 月を進める仕組みと保存の速さを、本番に近い形（AOT）で測る。画面は測らない（test/bench_test.dart で測る）。
//   dart compile exe tool/bench_logic.dart -o build/bench_logic.exe && build/bench_logic.exe
// 1980年から自動で回した会社で、2000年と2060年の局面から100か月ぶんを測る。
// 最後に出す数字（時価総額・現金・売上）は、速くする前と後で同じでなければならない（数字を変えていない確かめ）。
import 'dart:convert';

import 'package:quadrillion/game/game.dart';

import '../test/support/bot.dart';

void main() {
  for (final c in const [('2000年', 240), ('2060年', 960)]) {
    final g = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < c.$2 && g.over == null; i++) {
      botMonth(g);
    }
    resolveEvents(g);
    g.calcAll();
    final alive = g.cos.where((x) => x.alive).length;
    final next = Stopwatch(), save = Stopwatch();
    for (var i = 0; i < 110; i++) {
      final on = i >= 10;
      resolveEvents(g);
      if (on) next.start();
      g.nextQuarter();
      next.stop();
      if (on) save.start();
      jsonEncode(g.toJson());
      save.stop();
    }
    String ms(Stopwatch w) => (w.elapsedMicroseconds / 100 / 1000).toStringAsFixed(2);
    // ignore: avoid_print
    print('${c.$1}の局面（会社$alive社・事業${g.biz.length}）: 仕組み ${ms(next)}ms・保存 ${ms(save)}ms／月'
        '　確かめ: 時価総額 ${g.cap} 現金 ${g.cash} 売上 ${g.rev}');
  }
}
