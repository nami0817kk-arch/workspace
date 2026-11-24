import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 終わりの画面には、いつ・何歳で・なぜ亡くなったかが必ず出る（2026-11-24 ユーザー「死んだ理由がないことがある」）。
void main() {
  test('どの人生の終わりにも、年と歳と死因の一行がある', () {
    final seen = <String>{};
    for (var i = 0; i < 600; i++) {
      final rng = Rng(12000 + i);
      final g = Game(rng: rng)..start(rollBirth(rng));
      final pick = Rng(13000 + i);
      var n = 0;
      while (!g.finished && n++ < 2000) {
        final p = g.prompt!;
        g.choose(
          i.isEven
              ? pick.range(0, p.choices.length - 1)
              : pickAmbitious(g, p, pick),
        );
      }
      expect(g.finished, isTrue);
      final line = deathLine(g);
      expect(line, startsWith('${g.year}年（'), reason: line);
      expect(line, contains('${g.age}歳。'), reason: line);
      expect(line.endsWith('。'), isTrue, reason: line);
      expect(line.contains('。。'), isFalse, reason: line);
      expect(line.contains('null'), isFalse, reason: line);
      // 歳のあとに、死因（または天下統一）の文が続く。
      final rest = line.substring(line.indexOf('歳。') + 2);
      expect(rest.length, greaterThan(2), reason: line);
      if (g.l.dead != null) expect(line, contains(g.l.dead!), reason: line);
      seen.add(rest);
    }
    // 死因は一通りではない。
    expect(seen.length, greaterThan(20));
    // ignore: avoid_print
    print('【死因の一行】${seen.length}種　例: ${seen.take(12).join(' ／ ')}');
  });
}
