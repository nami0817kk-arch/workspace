// 月を進める仕組みと保存の速さを、本番に近い形（AOT）で測る。画面は測らない（test/bench_test.dart で測る）。
//   dart compile exe tool/bench_logic.dart -o build/bench_logic.exe && build/bench_logic.exe
// 1980年から自動で回した会社で、2000年と2060年の局面から100か月ぶんを測る。
// 最後に出す数字（時価総額・現金・売上）は、速くする前と後で同じでなければならない（数字を変えていない確かめ）。
import 'dart:convert';
import 'dart:isolate';

import 'package:quadrillion/game/game.dart';

import '../test/support/bot.dart';

Future<void> main() async {
  for (final c in const [('2000年', 240), ('2060年', 960)]) {
    final g = Game.newGame(SetupConfig(mode: 'endless', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < c.$2 && g.over == null; i++) {
      botMonth(g);
    }
    resolveEvents(g);
    g.calcAll();
    final alive = g.cos.where((x) => x.alive).length;
    final next = Stopwatch(), save = Stopwatch(), tj = Stopwatch(), enc = Stopwatch(), parts = Stopwatch(), wall = Stopwatch();
    var bytes = 0, cnt = 0;
    String ms(Stopwatch w) => (w.elapsedMicroseconds / 100 / 1000).toStringAsFixed(2);
    for (var i = 0; i < 110; i++) {
      final on = i >= 10;
      resolveEvents(g);
      if (on) next.start();
      g.nextQuarter();
      next.stop();
      if (on) save.start();
      jsonEncode(g.toJson());
      save.stop();
      // 保存の内訳（木にする・文字にする・別 Isolate へ渡すための写し）
      if (on) {
        tj.start();
        final m = g.toJson();
        tj.stop();
        enc.start();
        final t = jsonEncode(m);
        enc.stop();
        bytes = t.length;
        // 別 Isolate で文字にする。呼んだ側が止まるのは、木を写して渡すあいだだけ
        parts.start();
        final f = Isolate.run(() => jsonEncode(m));
        parts.stop();
        wall.start();
        cnt = (await f).length;
        wall.stop();
      }
    }
    // ignore: avoid_print
    print('  保存の内訳: 木にする ${ms(tj)}ms・文字にする ${ms(enc)}ms（${bytes ~/ 1024}KB）・別 Isolate へ渡す ${ms(parts)}ms（そのあと裏で ${ms(wall)}ms、同じ長さ ${cnt == bytes}）');
    // ignore: avoid_print
    print('${c.$1}の局面（会社$alive社・事業${g.biz.length}）: 仕組み ${ms(next)}ms・保存 ${ms(save)}ms／月'
        '　確かめ: 時価総額 ${g.cap} 現金 ${g.cash} 売上 ${g.rev}');
  }
}
