import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';
import 'package:soccer_career/ui/screens/season_end_screen.dart';

/// 保存しないリポジトリ。端末なしで画面を出すために使う。
class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> newCareer({int seed = 1, int age = 20}) async {
  final controller = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
  );
  await controller.startCareer(
    name: 'テスト',
    position: Position.cm,
    age: age,
    agent: Agent.pool.first,
  );
  return controller;
}

/// スマホの画面で開く。狭いほうで崩れないことを見たい。
Future<void> pumpHub(
  WidgetTester tester,
  CareerController controller, {
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => HubScreen(controller: controller),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('拠点は5つのタブに分かれている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    for (final label in ['試合', '選手', '育成', 'クラブ', '記録']) {
      expect(find.widgetWithText(Tab, label), findsOneWidget,
          reason: '$label タブが無い');
    }
  });

  testWidgets('主要な動作は、スクロールしなくても押せる位置にある', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    // 試合に入る動作は、どのタブに居ても画面に出ている。
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(find.descendant(of: fab, matching: find.text('試合へ')),
        findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('開いてすぐ、次の相手と今の状態が見える', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    expect(find.textContaining('第1節'), findsOneWidget);
    expect(find.text('今の状態'), findsOneWidget);
    // 能力値の一覧は「選手」タブに移した。試合のタブには出さない。
    expect(find.text('詳細能力'), findsNothing);
  });

  testWidgets('練習のタブでは、選んでいるメニューの中身が文字で読める', (tester) async {
    final controller = await newCareer();
    await controller.setMenu(TrainingMenu.athletic);
    // 縦に並ぶものを一度に見たいので、背の高い画面で開く。
    await pumpHub(tester, controller, height: 2000);

    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();

    expect(find.text('今週の練習'), findsOneWidget);
    // ツールチップではなく、本文として出ていること。
    expect(find.text(TrainingMenu.athletic.description), findsOneWidget);
    expect(find.textContaining('消耗 ${TrainingMenu.athletic.conditionCost}'),
        findsOneWidget);
    // 専属スタッフと生活習慣は畳んである。
    expect(find.text('専属スタッフ'), findsOneWidget);
    expect(find.text('世界的 1500万'), findsNothing);
  });

  testWidgets('選手のタブに能力と身体がまとまっている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller, height: 2000);

    await tester.tap(find.widgetWithText(Tab, '選手'));
    await tester.pumpAndSettle();

    expect(find.text('詳細能力'), findsOneWidget);
    expect(find.text('身体'), findsOneWidget);
    expect(find.text('積み上げ'), findsOneWidget);
  });

  testWidgets('クラブのタブに順位表がある', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.widgetWithText(Tab, 'クラブ'));
    await tester.pumpAndSettle();

    expect(find.text('クラブでの立ち位置'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('順位表'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('順位表'), findsOneWidget);
  });

  testWidgets('記録のタブに通算がまとまっている', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();

    expect(find.text('通算'), findsOneWidget);
    expect(find.text('試合'), findsWidgets);
    // 1シーズン目でも空にしない。
    expect(find.textContaining('1シーズン目'), findsOneWidget);
  });

  testWidgets('推移のグラフは、2シーズン目から出る', (tester) async {
    final controller = await newCareer(age: 24);
    // 1シーズン目は出さない（点が1つでは形が分からない）。
    await pumpHub(tester, controller, height: 2000);
    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();
    expect(find.text('推移'), findsNothing);

    // 2シーズン分積むと出る。
    for (var i = 0; i < 2; i++) {
      while (!controller.state!.seasonFinished) {
        await controller.simulateMatch();
      }
      await controller.finishSeason();
      await controller.advanceSeason(accepted: controller.renewalOffer!);
    }
    await pumpHub(tester, controller, height: 2000);
    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();
    expect(find.text('推移'), findsOneWidget);
  });

  testWidgets('引き継ぎコードを出せる', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引き継ぎコードを出す'));
    await tester.pumpAndSettle();

    expect(find.text('引き継ぎコード'), findsOneWidget);
    expect(find.textContaining('SC1:'), findsOneWidget);
  });

  testWidgets('遊び方はいつでも開ける', (tester) async {
    final controller = await newCareer();
    await pumpHub(tester, controller);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('遊び方'), findsOneWidget);
    expect(find.text('1週間の流れ'), findsOneWidget);
  });

  testWidgets('シーズンを終えると、主要な動作が切り替わる', (tester) async {
    final controller = await newCareer();
    final state = controller.state!;
    // 日程を消化した状態にする。
    while (!state.seasonFinished) {
      await controller.simulateMatch();
    }
    await pumpHub(tester, controller);

    expect(
        find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.text('シーズンを終える')),
        findsOneWidget);
  });

  testWidgets('試合の画面は、3つの手を見比べられる', (tester) async {
    final controller = await newCareer();
    controller.startNextMatch();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MatchScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    final match = controller.currentMatch!;
    // 手ごとに成功率が数字と帯で出ている。数字だけだと読み比べになる。
    for (final option in match.current.options) {
      expect(find.text(option.label), findsOneWidget);
    }
    final percent = (match.chanceFor(match.current.options.first) * 100).round();
    expect(find.text('$percent%'), findsWidgets);
    // 相手の戦い方が分かる。
    expect(find.text(match.opponentStyle.label), findsOneWidget);
  });

  testWidgets('シーズン終了の画面が、スマホの幅で崩れない', (tester) async {
    final controller = await newCareer(age: 24);
    while (!controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: SeasonEndScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('シーズン終了'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('オフの過ごし方'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('オフの過ごし方'), findsOneWidget);
    expect(find.text('契約'), findsOneWidget);
  });
}
