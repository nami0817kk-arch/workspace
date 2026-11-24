import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/scene_art.dart';
import 'package:ranse/engine/ways.dart';
import 'package:ranse/ui/end_screen.dart';
import 'package:ranse/ui/play_screen.dart';

import 'bot.dart';

/// Gemini で作った絵（assets/images）の置き忘れを止める。
void main() {
  test('10の道すべてに絵があり、ファイルが置いてある', () {
    for (final w in kWays.keys) {
      final art = kWayArt[w];
      expect(art, isNotNull, reason: w);
      expect(File(art!).existsSync(), isTrue, reason: art);
    }
  });

  test('タイトルの絵が置いてある', () {
    expect(File('assets/images/title_castle.jpg').existsSync(), isTrue);
  });

  test('場面の絵がすべて置いてある', () {
    for (final a in kSceneArts) {
      expect(File(sceneArtPath(a)).existsSync(), isTrue, reason: a);
    }
  });

  // 2026-11-25 に足した絵（まとめ役が Gemini で作って置く）。置かれるまでこの二つは落ちる。
  test('住まいの絵がすべて置いてある', () {
    for (final h in kHomeArts) {
      expect(File(homeArtPath(h)).existsSync(), isTrue, reason: homeArtPath(h));
    }
  });

  test('歴史の大事件の絵がすべて置いてある', () {
    for (final e in kEventScenes.keys) {
      final path = sceneArtPath('$kEventArtHead$e');
      expect(path, 'assets/images/event_$e.jpg');
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('岐路には場面の絵が付き、この年の心がけには付かない。絵は場面に合わせて散らばる', () {
    final seen = <String, int>{};
    var scenes = 0, withArt = 0;
    for (var i = 0; i < 300; i++) {
      final rng = Rng(4100 + i);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final pick = Rng(5100 + i);
      var n = 0;
      while (!g.finished && n++ < 1500) {
        final p = g.prompt!;
        if (p.title == 'この年の心がけ') {
          expect(p.art, isNull);
        } else {
          scenes++;
          if (p.art != null) {
            withArt++;
            // 大事件の岐路は event_<名>（無ければ場面の絵に落ちる）。
            final fb = artFallback(p.art!);
            expect(kSceneArts, contains(fb ?? p.art), reason: p.title);
            seen[p.art!] = (seen[p.art!] ?? 0) + 1;
          }
        }
        final k = i.isEven
            ? pick.range(0, p.choices.length - 1)
            : pickAmbitious(g, p, pick);
        g.choose(k);
      }
    }
    // 元服などの場面でない問いもあるので、全部ではない。
    expect(withArt / scenes, greaterThan(.7), reason: '$withArt / $scenes');
    expect(seen.length, greaterThanOrEqualTo(10), reason: '$seen');
    // ignore: avoid_print
    print('【場面の絵】$withArt / $scenes　$seen');
  });
}
