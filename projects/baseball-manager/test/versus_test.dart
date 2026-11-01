import 'dart:math';

import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/versus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<Ability, int> _bat(int v) =>
    {Ability.contact: v, Ability.power: v, Ability.trajectory: v};
Map<Ability, int> _pit(int v) => {Ability.stuff: v, Ability.control: v};

void main() {
  GameController.adminAllowed = true; // 公開ビルドでは使えない管理者モードを、テストでは使う
  test('対戦テスト: 打者99 vs 投手10 は必ず出塁、投手99 vs 打者10 は必ず打ち取る', () {
    final a = runVersus(
        bat: _bat(99),
        batSkills: {},
        pit: _pit(10),
        pitSkills: {},
        n: 2000,
        rng: Random(1));
    expect(a.onBase, 1.0);
    expect(a.battingAverage, 1.0);
    final b = runVersus(
        bat: _bat(10),
        batSkills: {},
        pit: _pit(99),
        pitSkills: {},
        n: 2000,
        rng: Random(1));
    expect(b.onBase, 0.0);
    expect(b.strikeout, greaterThan(1800));
  });

  test('対戦テスト: 特殊能力の上乗せが反映される(アベレージヒッターは打率が上がる)', () {
    VersusResult run(Set<Skill> t) => runVersus(
        bat: _bat(90),
        batSkills: t,
        pit: _pit(65),
        pitSkills: {},
        n: 20000,
        rng: Random(2));
    expect(run({Skill.averageHitter}).battingAverage,
        greaterThan(run({}).battingAverage + 0.02));
  });

  test('チーム同士: 99と10は必ず勝ち、同じ力なら五分', () {
    expect(teamWinChance(99, 10), 1.0);
    expect(teamWinChance(10, 99), 0.0);
    expect(teamWinChance(50, 50), 0.5);
  });

  testWidgets('設定の管理者モードから対戦テストを開き、結果が出る', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(600, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = GameController(rng: Random(1));
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    expect(
        find.byKey(const Key('versus-open')), findsNothing); // 管理者モードがオフのときは出ない
    await t.tap(find.byKey(const Key('admin-switch')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('versus-open')));
    await t.tap(find.byKey(const Key('versus-open')));
    await t.pumpAndSettle();
    expect(find.text('対戦テスト'), findsWidgets);
    await t.tap(find.byKey(const Key('vs-preset-99-10')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('vs-run')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('vs-result')), findsOneWidget);
    expect(find.text('100.0%'), findsWidgets); // 出塁
    expect(find.text('1.000'), findsOneWidget); // 打率
    await t.ensureVisible(find.byKey(const Key('vs-team-run')));
    await t.tap(find.byKey(const Key('vs-team-run')));
    await t.pumpAndSettle();
    expect(find.textContaining('自チームの勝ち: 100.0%'), findsOneWidget);
  });
}
