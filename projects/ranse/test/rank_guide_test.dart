import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/ui/rank_guide.dart';
import 'package:ranse/ui/theme.dart';

/// 位の解説（2026-11-24 ユーザー「位がよくわからない時がある」）。
void main() {
  test('位の一言は、男女とも位の数だけある', () {
    expect(kRankNotesM.length, kRanksM.length);
    expect(kRankNotesF.length, kRanksF.length);
    for (final n in [...kRankNotesM, ...kRankNotesF]) {
      expect(n, isNotEmpty);
    }
  });

  Game adult(int seed, {required bool female}) {
    for (var i = 0; i < 400; i++) {
      final rng = Rng(seed + i);
      final g = Game(rng: rng)..start(rollBirth(rng, asFemale: female));
      var n = 0;
      while (!g.finished && g.isChild && n++ < 200) {
        g.choose(0);
      }
      if (!g.finished) return g;
    }
    throw StateError('大人まで生きる人生が見つからない');
  }

  for (final female in [false, true]) {
    testWidgets('位の解説が${female ? '女性' : '男性'}の位をすべて並べ、はみ出さない', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final g = adult(300, female: female);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: RankGuide(g),
            ),
          ),
        ),
      );
      expect(find.text('位の解説'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 下まで送っても崩れず、位の名がすべて出る。
      final names = female ? kRanksF : kRanksM;
      for (final name in names) {
        await tester.scrollUntilVisible(find.text(name).first, 200);
        expect(find.text(name), findsWidgets, reason: name);
      }
      await tester.scrollUntilVisible(find.text('段の外の暮らし'), 300);
      expect(tester.takeException(), isNull);
    });
  }
}
