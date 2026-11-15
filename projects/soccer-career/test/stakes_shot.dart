// ignore_for_file: avoid_print
/// **1.1.0 で手の横に足した札を、目で見る。**
///
/// 「外すと失点30%」「通っても失点8%」「通れば1点防ぐ」「今は重い」は、
/// 局面と状況が揃わないと出ないので、`shots.dart` の通しでは写らないことがある。
/// 局面を指定して試合に入り、書き出す。3つ目の手が画面の外に出ていないかも数える。
/// 手動実行: `flutter test test/stakes_shot.dart`（書き出し先は `shots/`）。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';

import 'shots.dart' as shots;
import 'ui_test.dart' as ui_test;

class _Repo implements SaveRepository {
  @override
  Future<CareerState?> load() async => null;
  @override
  Future<void> save(CareerState state) async {}
  @override
  Future<void> clear() async {}
}

Future<CareerController> _career(Position position) async {
  final controller = CareerController(
    repository: _Repo(),
    hallRepository: ui_test.MemoryHall(),
    careerEngine: CareerEngine(random: Random(4)),
    matchEngine: MatchEngine(random: Random(4)),
    random: Random(4),
  );
  await controller.startCareer(
    name: 'テスト',
    position: position,
    age: 20,
    agent: Agent.pool.first,
  );
  return controller;
}

void main() {
  for (final (position, id) in [
    (Position.cb, 'df-duel'),
    (Position.cb, 'df-cross'),
    (Position.gk, 'gk-hold-wall'),
    (Position.cm, 'mf-build'),
    (Position.st, 'fw-counter'),
  ]) {
    testWidgets('$id', (tester) async {
      await shots.loadFont();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = await _career(position);
      final scenario = ScenarioPool.forPosition(
        position,
      ).firstWhere((s) => s.id == id);
      controller.startNextMatch(forcedScenarios: [scenario]);
      expect(controller.currentMatch!.isFinished, isFalse);

      await shots.pump(
        tester,
        MatchScreen(controller: controller),
        shots.themeFor(controller.state!.club),
      );
      await shots.dump(tester, '11-stakes-$id');

      final view = tester.renderObject<RenderBox>(
        find.byType(SingleChildScrollView).first,
      );
      final fold = view.localToGlobal(Offset.zero).dy + view.size.height;
      final buttons = find.byType(OutlinedButton).evaluate().toList();
      var hidden = 0;
      for (final b in buttons) {
        final box = b.renderObject! as RenderBox;
        final foot = box.localToGlobal(Offset.zero).dy + box.size.height;
        if (foot > fold) hidden++;
        print('  $id 手 高${box.size.height.toStringAsFixed(0)}px');
      }
      print('$id 画面の外に出た手 $hidden / ${buttons.length}');
    });
  }
}
