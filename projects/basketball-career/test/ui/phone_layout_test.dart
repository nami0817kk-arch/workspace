// スマホの幅(390)で各画面を描いて、はみ出し・例外が出ないことを確かめる。
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/rival.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:basketball_career/ui/history_screen.dart';
import 'package:basketball_career/ui/howto_screen.dart';
import 'package:basketball_career/ui/settings_screen.dart';
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

void phone(WidgetTester t, {double width = 390, double height = 3200}) {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Player star() => Player(
      name: 'ミナトヨシタカ', // 長い名前
      age: 17,
      potential: 80,
      heightCm: 196,
      heightGenes: 0.7,
      abilities: {for (final a in Ability.values) a: 75},
    );

Future<void> show(WidgetTester t, GameController c) async {
  await t.pumpWidget(BasketballCareerApp(controller: c));
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [360.0, 390.0, 430.0]) {
    group('幅 $width', () {
      testWidgets('はじめの画面', (t) async {
        phone(t, width: width);
        await show(t, GameController(store: _NullStore(), rng: Random(1)));
      });

      testWidgets('遊び方', (t) async {
        phone(t, width: width);
        await t.pumpWidget(MaterialApp(home: HowToScreen(onStart: () {})));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });

      testWidgets('育成の画面(体調が悪い・怪我・目標あり)', (t) async {
        phone(t, width: width);
        final c = GameController(store: _NullStore(), rng: Random(1), events: false);
        c.game = Game.start('ミナトヨシタカ', rng: Random(2), events: false)
          ..condition = const Condition(fatigue: 85, morale: 20, injuredTerms: 2);
        c.game!.adoptGoal(1);
        await show(t, c);
      });

      testWidgets('出来事の画面', (t) async {
        phone(t, width: width);
        final c = GameController(store: _NullStore(), rng: Random(1), events: false);
        c.game = Game(
          eventsEnabled: false,
          player: star(),
          rng: Random(1),
          rival: Rival(name: '一ノ瀬ツバサ', potential: 80),
          pendingEventId: 'rival_talk',
        );
        await show(t, c);
      });

      testWidgets('勝負どころの画面', (t) async {
        phone(t, width: width);
        GameController? found;
        for (var seed = 0; seed < 400 && found == null; seed++) {
          final c = GameController(
              store: _NullStore(), rng: Random(seed), events: false);
          c.game = Game(
            eventsEnabled: false,
            player: star().copyWith(age: 15),
            rng: Random(seed),
            slot: 1,
          );
          c.act(Action.rest);
          if (c.game!.phase == Phase.clutch) found = c;
        }
        await show(t, found!);
      });

      testWidgets('進路・エンディング・殿堂・設定', (t) async {
        phone(t, width: width);
        final path = GameController(store: _NullStore(), rng: Random(1), events: false);
        path.game = Game(
          eventsEnabled: false,
          player: star().copyWith(age: 19),
          rng: Random(1),
          pathPending: true,
        );
        await show(t, path);

        final end = GameController(store: _NullStore(), rng: Random(1), events: false);
        final g = Game(
          eventsEnabled: false,
          player: star().copyWith(age: 25),
          rng: Random(1),
          track: Track.pro,
          abroad: true,
          rival: Rival(name: '一ノ瀬ツバサ', potential: 80, wins: 5, losses: 3),
        );
        for (var i = 0; i < 12; i++) {
          g.choose(Action.rest, Ability.pass);
        }
        g.retire();
        end.game = g;
        await show(t, end);

        await t.pumpWidget(MaterialApp(home: HistoryScreen(controller: end)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const MaterialApp(home: SettingsScreen(money: null)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    });
  }
}
