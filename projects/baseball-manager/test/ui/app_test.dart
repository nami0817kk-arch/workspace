import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 縦長の画面にして、ListView の下のほうまで描画させる。
void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(900, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<GameController> _start(WidgetTester t, {int seed = 1}) async {
  SharedPreferences.setMockInitialValues({});
  _tall(t);
  final c = GameController(rng: Random(seed));
  await t.pumpWidget(BaseballManagerApp(controller: c));
  await t.pumpAndSettle();
  return c;
}

/// 決まった方針で、指定の状態になるまでロジックだけ進める。
Game _until(bool Function(Game) stop, {int seed = 1, int? potential}) {
  final g = Game.newGame(name: 'テスト', role: Role.batter, rng: Random(seed), potential: potential);
  var steps = 0;
  while (g.phase != Phase.retired && !stop(g)) {
    if (++steps > 4000) fail('届かない');
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train, Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return g;
}

void main() {
  testWidgets('はじめの画面から選手を作ると、6歳の春から始まる', (t) async {
    await _start(t);
    expect(find.text('はじめる'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ひなた');
    await t.tap(find.text('投手'));
    await t.pump();
    await t.tap(find.text('はじめる'));
    await t.pumpAndSettle();
    expect(find.textContaining('ひなた'), findsWidgets);
    expect(find.textContaining('6歳'), findsOneWidget);
    expect(find.textContaining('春'), findsWidgets);
    expect(find.text('球威'), findsWidgets); // 投手の能力
    expect(find.text('ミート'), findsNothing);
  });

  testWidgets('練習すると季節が進み、経験点が貯まり、能力に振り分けられる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    final before = c.game!.player.of(Ability.contact);
    await t.tap(find.byKey(const Key('act-train')));
    await t.pumpAndSettle();
    expect(find.textContaining('夏'), findsWidgets);
    expect(c.game!.exp.total, greaterThan(0));
    // 出来事が起きていたら選んで進める。
    if (c.game!.phase == Phase.event) {
      await t.tap(find.byKey(const Key('event-0')));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('おまかせ振り分け'));
    await t.pumpAndSettle();
    final sum = abilitiesOf(Role.batter).map(c.game!.player.of).reduce((a, b) => a + b);
    expect(sum, greaterThan(15 * 5));
    expect(c.game!.player.of(Ability.contact) >= before, isTrue);
  });

  testWidgets('経験点が足りない能力の+1は押せない', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    final btn = t.widget<OutlinedButton>(find.byKey(const Key('buy-contact')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('重点の能力を選んでから練習できる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('focus-power')));
    await t.pump();
    expect(c.focus, Ability.power);
    await t.tap(find.byKey(const Key('act-special')));
    await t.pumpAndSettle();
    expect(c.game!.exp.total, greaterThan(0));
  });

  testWidgets('出来事が起きると選択肢が出て、選ぶと進む', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.event));
    await t.pumpAndSettle();
    expect(find.text('出来事'), findsOneWidget);
    expect(find.byKey(const Key('event-0')), findsOneWidget);
    expect(find.byKey(const Key('act-train')), findsNothing); // 選ぶまで練習はできない
    await t.tap(find.byKey(const Key('event-0')));
    await t.pumpAndSettle();
    expect(find.text('出来事'), findsNothing);
  });

  testWidgets('ドラフトに外れると進路の選択が出る', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('route-corporate')), findsOneWidget); // 進路の選択が出ている
    await t.tap(find.byKey(const Key('route-corporate')));
    await t.pumpAndSettle();
    expect(c.game!.route, Course.corporate);
    expect(find.byKey(const Key('route-corporate')), findsNothing);
  });

  testWidgets('諦めるとエンディングが出て、もう一度で最初に戻る', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    expect(find.text('プロにはなれなかった'), findsOneWidget);
    await t.tap(find.byKey(const Key('again')));
    await t.pumpAndSettle();
    expect(find.text('はじめる'), findsOneWidget);
  });

  testWidgets('プロになったら二刀流に挑戦でき、確認のうえ引退できる', (t) async {
    final c = await _start(t);
    Game? g;
    for (var s = 0; s < 80 && g == null; s++) {
      final x = _until((g) => g.stage == Stage.pro && g.phase == Phase.term,
          seed: s, potential: 100);
      if (x.stage == Stage.pro) g = x;
    }
    c.adopt(g!);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('role-twoway')), findsOneWidget);
    await t.tap(find.byKey(const Key('role-twoway')));
    await t.pumpAndSettle();
    expect(c.game!.player.role, Role.twoWay);
    expect(find.text('球威'), findsWidgets); // 投手の能力も並ぶ
    expect(find.text('ミート'), findsWidgets);
    await t.tap(find.byKey(const Key('retire')));
    await t.pumpAndSettle();
    expect(find.text('引退しますか?'), findsOneWidget);
    await t.tap(find.byKey(const Key('retire-confirm')));
    await t.pumpAndSettle();
    expect(find.textContaining('の一生'), findsOneWidget);
    expect(find.text('二刀流'), findsOneWidget);
  });

  testWidgets('操作のたびに保存され、アプリを開き直すと続きから始まる', (t) async {
    final c = await _start(t, seed: 2);
    c.newGame('つづき', Role.batter);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act-rest')));
    await t.pumpAndSettle();
    final slot = c.game!.slot;
    final age = c.game!.player.age;

    // 別のコントローラで開き直す(保存済みの中身は同じ SharedPreferences)。
    final c2 = GameController(rng: Random(5));
    await t.pumpWidget(BaseballManagerApp(key: UniqueKey(), controller: c2));
    await t.pumpAndSettle();
    expect(find.text('はじめる'), findsNothing);
    expect(c2.game!.player.name, 'つづき');
    expect(c2.game!.player.age, age);
    expect(c2.game!.slot, slot);
    expect(find.textContaining('つづき'), findsWidgets);
  });

  testWidgets('壊れたセーブがあっても、最初の画面から始められる', (t) async {
    SharedPreferences.setMockInitialValues({saveKey: '{こわれた'});
    _tall(t);
    await t.pumpWidget(BaseballManagerApp(controller: GameController(rng: Random(1))));
    await t.pumpAndSettle();
    expect(find.text('はじめる'), findsOneWidget);
  });

  testWidgets('高校では月の名前が出る', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.stage == Stage.highSchool && g.phase == Phase.term));
    await t.pumpAndSettle();
    expect(find.textContaining('4月'), findsWidgets);
    expect(find.textContaining('高校'), findsWidgets);
  });
}
