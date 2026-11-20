import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('けがをすると部位と回数が付き、重さと残りが説明に出る。保存して読み直しても残る', () {
    final c = careerAt(6, 12)..startSeason();
    var guard = 0;
    Player? hurt;
    while (hurt == null && guard++ < 40) {
      c.playBlock();
      for (final t in c.teams) {
        for (final p in t.roster) {
          if (p.injured > 0) hurt = p;
        }
      }
      if (c.phase != Phase.season) break;
    }
    expect(hurt, isNotNull, reason: '数区切りのうちに誰かがけがをする');
    expect(hurt!.injPart, inInclusiveRange(0, injuryParts.length - 1));
    expect(hurt.injCount, greaterThan(0));
    expect(hurt.injuryText, contains('あと${hurt.injured}試合'));
    expect(['軽い', '中くらい', '重い'], contains(hurt.injurySeverity));
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    final q = [for (final t in back.teams) ...t.roster].firstWhere((x) => x.id == hurt!.id);
    expect(q.injPart, hurt.injPart);
    expect(q.injCount, hurt.injCount);
    botStep(c);
  });
}
