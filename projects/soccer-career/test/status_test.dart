/// **数字を出す。**
///
/// 参考にした野球のキャリアゲームの状態カードは
/// 「疲労度20 安全圏 / 調子 普通 / 怪我リスク 1%/週」と**数字で**出す。
/// こちらは言葉だけ（「疲れが抜けない」「怪我 ×1.8」）で、
/// **怪我の確率は計算しているのに管理画面（開発用）にしか出ていなかった**。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';

class _Repo implements SaveRepository {
  @override
  Future<CareerState?> load() async => null;
  @override
  Future<void> save(CareerState state) async {}
  @override
  Future<void> clear() async {}
}

Future<CareerController> _started() async {
  final c = CareerController(
    repository: _Repo(),
    careerEngine: CareerEngine(random: Random(5)),
    matchEngine: MatchEngine(random: Random(5)),
    random: Random(5),
  );
  await c.startCareer(
    name: 'T',
    position: Position.cm,
    age: 22,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  testWidgets('今の状態に、疲労・気持ち・怪我の確率が数字で出る', (tester) async {
    final controller = await _started();
    controller.state!.fatigue = const Fatigue(value: 62);
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: HubScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今の状態'), findsOneWidget);
    expect(find.text('62'), findsWidgets);
    expect(find.text('${controller.state!.morale.value}'), findsWidgets);
    // 怪我は倍率ではなく確率。判定と同じ式から出す。
    final percent = '${(controller.injuryChanceNow * 100).toStringAsFixed(1)}%';
    expect(find.text(percent), findsOneWidget);
    expect(find.text('1週あたり'), findsOneWidget);
  });

  testWidgets('選手タブに、代表の線まであといくつかが出る', (tester) async {
    final controller = await _started();
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: HubScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    final state = controller.state!;
    final line = Formulas.callUpLineFor(
      World.byId(state.nationalTeam).prestige,
    );
    // 判定と同じ数字が出る。管理画面（開発用）にしか無かった。
    expect(find.textContaining('総合力$line'), findsOneWidget);
  });

  test('怪我の確率は、判定に使う式そのもの', () async {
    final controller = await _started();
    expect(
      controller.injuryChanceNow,
      MatchEngine.injuryChance(
        controller.state!.player,
        baseChance: CareerController.injuryBaseChanceFor(controller.state!),
      ),
    );
  });
}
