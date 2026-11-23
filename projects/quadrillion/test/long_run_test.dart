import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';

import 'support/bot.dart';

/// 試作の自動プレイ（sim.js）と同じ考え方で、50年回して落ちないこと・数字が壊れないことを見る
void main() {
  const cases = [
    ('world', 1980, ['charm', 'gambler'], 'jp', 1),
    ('quad', 2000, ['tech', 'noble'], 'us', 2),
    ('endless', 2025, ['oneman', 'careful'], 'in', 3),
    ('endless', 1980, ['liar', 'frugal'], 'cn', 4),
    ('world', 2000, ['stamina', 'genius'], 'ru', 5),
  ];
  for (final c in cases) {
    test('50年回しても落ちない（${c.$1}・${c.$2}年・${c.$3.join('/')}・${c.$4}）', () {
      final s = Game.newGame(SetupConfig(mode: c.$1, year: c.$2, traits: c.$3, home: c.$4), rng: ParkMiller(c.$5 * 1009));
      var months = 0;
      for (var t = 0; t < 12 * 50 && s.over == null; t++) {
        botMonth(s);
        months++;
        if (s.won != null) {
          // 勝っても続ける（画面の「このまま続ける」と同じ）
          s.mode = 'endless';
          s.won = null;
        }
        expect(s.cash.isFinite, isTrue, reason: '$months か月目の現金');
        expect(s.cap.isFinite && s.cap >= 1, isTrue, reason: '$months か月目の時価総額');
        expect(s.biz.every((b) => b.power.isFinite && b.rev.isFinite), isTrue, reason: '$months か月目の事業');
        expect(s.sh.own, inInclusiveRange(0, 100.0001));
        expect(s.ap, greaterThanOrEqualTo(0));
      }
      expect(months > 24 || s.over != null, isTrue);
      expect(s.log.length, lessThanOrEqualTo(300));
      expect(s.hist.length, lessThanOrEqualTo(1200));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
