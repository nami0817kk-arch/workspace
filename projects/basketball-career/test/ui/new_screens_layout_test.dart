// あとから足した画面(型を選ぶ・特殊能力・ゾーン・重点の2段・特性のくじ)が、小さい幅と大きい文字でもはみ出さないこと。
import 'dart:math';

import 'package:basketball_career/game/build.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/special.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:flutter/material.dart' hide Action, Route;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NullStore extends SaveStore {
  @override
  Future<void> save(Map<String, dynamic> json) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
}

void phone(WidgetTester t, {double width = 360, double height = 5200}) {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> show(WidgetTester t, GameController c, double textScale) async {
  await t.pumpWidget(MediaQuery(
    data: MediaQueryData(
        size: t.view.physicalSize, textScaler: TextScaler.linear(textScale)),
    child: BasketballCareerApp(controller: c),
  ));
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

/// 特殊能力をたくさん習得し、長い名前の型を選んだ育成中の選手。
GameController _busy() {
  final c = GameController(store: _NullStore(), rng: Random(1), events: false);
  final g = Game.start('ミナトヨシタカ', rng: Random(2), events: false, style: Build.lockdown);
  g.sp = 200;
  for (final s in learnPriority.take(12)) {
    if (canLearn(g.player.specials, g.sp, s)) g.learnSpecial(s);
  }
  c.game = g;
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in [1.0, 1.6, 2.0]) {
    group('文字の大きさ x$scale (幅360)', () {
      testWidgets('育成画面: 型・特殊能力・重点の2段・今回の伸び', (t) async {
        phone(t);
        final c = _busy();
        c.game!.choose(Action.practice, Ability.threePoint, focus2: Ability.pass);
        await show(t, c, scale);
        expect(find.textContaining('① 大きく伸ばす能力'), findsOneWidget);
        expect(find.textContaining('② 少し伸ばす能力'), findsOneWidget);
      });

      testWidgets('型を選ぶダイアログ', (t) async {
        phone(t);
        await show(t, _busy(), scale);
        await t.ensureVisible(find.text('型を選ぶ'));
        await t.tap(find.text('型を選ぶ'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('どんな選手を目指す?'), findsOneWidget);
        await t.tap(find.text('ストレッチビッグ'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });

      testWidgets('特殊能力の習得画面(習得できるものがある・ない)', (t) async {
        phone(t, height: 2400);
        final c = _busy();
        await show(t, c, scale);
        await t.ensureVisible(find.textContaining('特殊能力'));
        await t.tap(find.text('習得できる!'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.textContaining('特殊能力 '), findsWidgets);
        // いちばん下まで送っても例外が出ない。
        await t.drag(find.byType(ListView).last, const Offset(0, -6000));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });

      testWidgets('勝負どころ: ゾーンのボタン', (t) async {
        phone(t);
        GameController? found;
        for (var seed = 0; seed < 600 && found == null; seed++) {
          final base = Game.start('x', rng: Random(seed), events: false);
          final c = GameController(store: _NullStore(), rng: Random(seed), events: false);
          c.game = Game(
            eventsEnabled: false,
            player: base.player.copyWith(
              age: 24,
              heightCm: 192,
              abilities: {for (final a in Ability.values) a: 70},
              specials: {Special.calm, Special.zone},
            ),
            rng: Random(seed),
            track: Track.pro,
            salary: 2000,
            slot: 1,
          );
          c.act(Action.rest);
          while (c.game!.phase == Phase.halftime) {
            c.game!.resolveHalftime(Halftime.keep);
          }
          if (c.game!.phase == Phase.clutch) found = c;
        }
        expect(found, isNotNull);
        await show(t, found!, scale);
        expect(find.textContaining('ゾーンに入る'), findsOneWidget);
        await t.tap(find.textContaining('ゾーンに入る'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('ゾーン中: +12%'), findsOneWidget);
      });

      testWidgets('はじめの画面: 特性のくじと型・夢の選択', (t) async {
        phone(t);
        await show(t, GameController(store: _NullStore(), rng: Random(1)), scale);
        for (var i = 0; i < 6; i++) {
          await t.ensureVisible(find.text('振り直す'));
          await t.tap(find.text('振り直す'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await t.ensureVisible(find.text('リムプロテクター'));
        await t.tap(find.text('リムプロテクター'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    });
  }

}
