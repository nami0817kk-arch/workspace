import 'package:baseball_manager/game/calendar.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/art/avatar.dart';
import 'package:baseball_manager/ui/art/career_chart.dart';
import 'package:baseball_manager/ui/art/confetti.dart';
import 'package:baseball_manager/ui/art/radar.dart';
import 'package:baseball_manager/ui/art/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

Player _p(Role r, [int v = 40]) => Player(
      name: 't',
      role: r,
      age: 20,
      potential: 50,
      abilities: {for (final a in abilitiesOf(r)) a: v},
    );

void main() {
  testWidgets('全ての段階・役割・表情で選手の絵が描ける', (t) async {
    await t.pumpWidget(_wrap(Wrap(children: [
      for (final s in Stage.values)
        for (final r in Role.values)
          for (final m in Mood.values) PlayerAvatar(stage: s, role: r, mood: m, height: 60),
    ])));
    expect(tester(t), isNull);
    expect(find.byType(PlayerAvatar), findsNWidgets(Stage.values.length * Role.values.length * Mood.values.length));
  });

  testWidgets('全ての季節・段階で背景が描ける', (t) async {
    await t.pumpWidget(_wrap(Column(children: [
      for (final se in Season.values)
        for (final st in Stage.values)
          SceneBanner(season: se, stage: st, role: Role.batter, mood: Mood.flat, label: 'x', height: 120),
    ])));
    expect(tester(t), isNull);
  });

  testWidgets('レーダーは打者・投手・二刀流のどれでも描け、能力が変わっても落ちない', (t) async {
    for (final r in Role.values) {
      await t.pumpWidget(_wrap(AbilityRadar(player: _p(r, 20))));
      await t.pumpWidget(_wrap(AbilityRadar(player: _p(r, 90))));
      await t.pumpAndSettle();
      expect(tester(t), isNull);
    }
  });

  test('レーダーの外枠は、最高値より少し上(最低50・最大99)', () {
    expect(radarScale(15), 50);
    expect(radarScale(41), 60);
    expect(radarScale(60), 70);
    expect(radarScale(99), 99);
  });

  testWidgets('人生のグラフは、データが2つあれば描ける。伸びる途中でも落ちない', (t) async {
    await t.pumpWidget(_wrap(const CareerChart(history: [10, 30, 50, 80], proStartAge: 8)));
    await t.pump(const Duration(milliseconds: 300));
    expect(tester(t), isNull);
    await t.pumpAndSettle();
    expect(tester(t), isNull);
  });

  testWidgets('紙吹雪は一度降って終わり、片付く', (t) async {
    await t.pumpWidget(_wrap(const SizedBox(width: 200, height: 200, child: Confetti())));
    await t.pump(const Duration(milliseconds: 1000));
    await t.pumpAndSettle();
    expect(tester(t), isNull);
  });

  test('ユニフォームは段階ごとに違い、表情はやる気で決まる', () {
    final shirts = Stage.values.map((s) => uniformOf(s).cap.toARGB32()).toSet();
    expect(shirts.length, greaterThan(3));
    expect(moodOf(Motivation.great), Mood.happy);
    expect(moodOf(Motivation.normal), Mood.flat);
    expect(moodOf(Motivation.terrible), Mood.sad);
  });
}

/// 描画中に出た例外(あれば)を取り出す。無ければ null。
Object? tester(WidgetTester t) => t.takeException();
