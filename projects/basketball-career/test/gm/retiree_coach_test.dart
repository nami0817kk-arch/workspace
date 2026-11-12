import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('引退した力のある選手が、契約の画面のコーチ候補に「元選手」として加わる。保存しても残る', () {
    var found = false;
    for (var seed = 1; seed <= 6 && !found; seed++) {
      final c = careerAt(seed, 12);
      for (var year = 0; year < 10 && !found; year++) {
        var guard = 0;
        while (c.phase != Phase.seasonEnd && guard++ < 300) {
          botStep(c);
        }
        c.fired = false;
        c.toOffseason();
        final pending = [...c.retirees];
        if (pending.isEmpty) {
          guard = 0;
          while (c.phase != Phase.preseason && guard++ < 300) {
            botStep(c);
          }
          continue;
        }
        found = true;
        final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
        expect(back.retirees, c.retirees);
        guard = 0;
        while (c.phase != Phase.contracts && guard++ < 300) {
          botStep(c);
        }
        final names = c.coachPool.map((k) => k.name).toList();
        for (final r in pending) {
          expect(names, contains('${r[0]}(元選手)'));
        }
        expect(c.retirees, isEmpty);
      }
    }
    expect(found, isTrue, reason: '数年のうちに力のある選手が引退する');
  });
}
