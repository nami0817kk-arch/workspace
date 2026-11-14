import 'dart:convert';

import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/personality.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('スカウトの段階が高いほど見立ての幅が狭く、本当の値は必ず幅の中', () {
    double width(int level) {
      var w = 0;
      for (var s = 0; s < 40; s++) {
        final rng = Rng(s);
        var id = 1000;
        final pool = makeProspects(rng, () => id++, 10);
        for (final p in pool) {
          scout(p, rng, level: level);
          expect(p.player.ovr, inInclusiveRange(p.ovrLo, p.ovrHi));
          expect(p.player.pot, inInclusiveRange(p.potLo, p.potHi));
          w += (p.ovrHi - p.ovrLo) + (p.potHi - p.potLo);
        }
      }
      return w / 400;
    }

    final w1 = width(1), w2 = width(2), w3 = width(3);
    expect(w1, greaterThan(w2));
    expect(w2, greaterThan(w3));
  });

  test('スカウトした候補は性格が見え、保存しても残る', () {
    final rng = Rng(7);
    var id = 1;
    final p = makeProspects(rng, () => id++, 3).first;
    expect(personalityKnown(p.player), isFalse);
    scout(p, rng);
    expect(personalityKnown(p.player), isTrue);
    final back = Player.fromJson(jsonDecode(jsonEncode(p.player.toJson())) as Map<String, dynamic>);
    expect(personalityKnown(back), isTrue);
  });
}
