/// 管理画面の「ゲームへの効き」。
///
/// **判定に使っている関数と同じものを読んでいること**が一番大事な検査。
/// ここがずれると、管理画面だけが嘘をつく。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/dev/admin.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/ranking.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/traits.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/screens/admin_screen.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: Position.cm, age: 24, agent: Agent.pool.first);
  return c;
}

String valueOf(AdminImpact impact, String label) =>
    impact.lines.firstWhere((l) => l.label == label).value;

void main() {
  group('判定と同じ式を読んでいる', () {
    test('総合力の行は Ranking.gradeFor と代表の線から出ている', () async {
      final c = await started();
      final impact = AdminImpact.of(c);
      final player = c.state!.player;
      final line = valueOf(impact, '総合力');
      expect(line, contains('${player.overall}'));
      expect(line, contains(Ranking.gradeFor(player.overall).label));
      expect(line, contains('${Formulas.callUpOverall - player.overall}'));
    });

    test('次の試合の行は SelectionOutlook と同じ見立てと理由', () async {
      final c = await started();
      final impact = AdminImpact.of(c);
      expect(valueOf(impact, '次の試合'), contains(c.outlook!.headline));
      expect(valueOf(impact, '次の試合'), contains(c.outlook!.reason));
    });

    test('怪我の行は rollInjury と同じ確率', () async {
      final c = await started();
      final expected = MatchEngine.injuryChance(
        c.state!.player,
        baseChance: CareerController.injuryBaseChanceFor(c.state!),
      );
      expect(c.injuryChanceNow, expected);
      expect(valueOf(AdminImpact.of(c), '練習した週の怪我'),
          contains((expected * 100).toStringAsFixed(1)));
    });

    test('コンディションの行は conditionModifier と同じ増減', () async {
      final c = await started();
      await AdminActions(c).setCondition(100);
      final expected =
          (MatchInProgress.conditionModifier(100) * 100).round();
      expect(valueOf(AdminImpact.of(c), '局面の成功率'), contains('+$expected%'));
    });

    test('お金の行は budget と同じ数字', () async {
      final c = await started();
      final state = c.state!;
      expect(valueOf(AdminImpact.of(c), '今季のお金'),
          contains('${state.budget.net}'));
    });
  });

  group('変えたら何が動いたか', () {
    test('コンディションを下げると、成功率の行が動く', () async {
      final c = await started();
      final admin = AdminActions(c);
      await admin.setCondition(100);
      final before = AdminImpact.of(c);
      await admin.setCondition(20);
      final changes = AdminImpact.diff(before, AdminImpact.of(c));
      expect(changes, isNotEmpty);
      expect(changes.any((s) => s.startsWith('局面の成功率')), isTrue);
      // 「前 → 後」の形になっている。
      expect(changes.firstWhere((s) => s.startsWith('局面の成功率')),
          contains(' → '));
    });

    test('能力を上げると、総合力と水準の行が動く', () async {
      final c = await started();
      final admin = AdminActions(c);
      final before = AdminImpact.of(c);
      await admin.bumpAll(15);
      final changes = AdminImpact.diff(before, AdminImpact.of(c));
      expect(changes.any((s) => s.startsWith('総合力')), isTrue);
    });

    test('怪我をさせると、怪我の行に離脱が出る', () async {
      final c = await started();
      final admin = AdminActions(c);
      final before = AdminImpact.of(c);
      await admin.setInjury(6);
      final after = AdminImpact.of(c);
      expect(AdminImpact.diff(before, after), isNotEmpty);
      expect(valueOf(after, '練習した週の怪我'), contains('離脱中'));
      expect(valueOf(after, '次の試合'), contains('出られない'));
    });

    test('何も変わらなければ、動いた行は出ない', () async {
      final c = await started();
      final before = AdminImpact.of(c);
      expect(AdminImpact.diff(before, AdminImpact.of(c)), isEmpty);
    });

    test('超越の特性を付けると、伸びしろの行が上限まで伸びると書く', () async {
      final c = await started();
      final admin = AdminActions(c);
      // ポテンシャルに到達させてから付ける。
      await admin.bumpAll(40);
      await admin.setPotential(c.state!.player.overall);
      expect(valueOf(AdminImpact.of(c), '伸びしろ'), contains('もう伸びない'));

      await admin.toggleTrait(Trait.eagleEye);
      final line = valueOf(AdminImpact.of(c), '伸びしろ');
      expect(line, contains('視野'));
      expect(line, contains('${Formulas.absoluteMax}'));
    });
  });

  group('画面', () {
    testWidgets('効きの一覧が管理画面の上に出て、操作すると差分が出る', (tester) async {
      final controller = await started();
      tester.view.physicalSize = const Size(390, 1600);
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
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理'));
      await tester.pumpAndSettle();

      // どのタブに居ても見える。
      expect(find.text('ゲームへの効き'), findsOneWidget);
      for (final label in ['総合力', '次の試合', '練習した週の怪我', '伸びしろ']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      // 触るまでは差分が出ない。
      expect(find.textContaining('直前の操作で'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, '状態'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+5'));
      await tester.pumpAndSettle();
      expect(find.textContaining('直前の操作で '), findsOneWidget);
      expect(find.textContaining(' → '), findsWidgets);
    });

    testWidgets('動かない操作をしたときは、動かなかったと書く', (tester) async {
      // 無言だと「効かない操作をした」のか「押せていない」のか分からない。
      final controller = await started();
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: AdminScreen(controller: controller),
      ));
      await tester.pumpAndSettle();

      // 天才はここに出ている数字を動かさない（効くのは成長のとき）。
      await tester.tap(find.text('天才'));
      await tester.pumpAndSettle();
      expect(find.textContaining('動かなかった'), findsWidgets);
    });
  });
}
