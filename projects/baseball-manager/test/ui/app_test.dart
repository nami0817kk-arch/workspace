import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/difficulty.dart';
import 'package:baseball_manager/game/goals.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/tactics.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/history.dart';
import 'package:baseball_manager/ui/game_screen.dart' show endingShareText;
import 'package:baseball_manager/ui/labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final g = Game.newGame(
      name: 'テスト', role: Role.batter, rng: Random(seed), potential: potential);
  var steps = 0;
  while (g.phase != Phase.retired && !stop(g)) {
    if (++steps > 4000) fail('届かない');
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
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

/// 引退直後は実績などの祝いダイアログが出るので、閉じてから先へ進む。
Future<void> _dismissMilestones(WidgetTester t) async {
  while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
    await t.tap(find.byKey(const Key('milestone-ok')));
    await t.pumpAndSettle();
  }
}

void main() {
  _rankTests();
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
    final sum =
        abilitiesOf(Role.batter).map(c.game!.player.of).reduce((a, b) => a + b);
    expect(sum, greaterThan(15 * 5));
    expect(c.game!.player.of(Ability.contact) >= before, isTrue);
  });

  testWidgets('練習のあと、「いまの結果」に貯まった経験点が出る。能力のランクが並ぶ', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recent')), findsNothing);
    expect(find.text('G'), findsNWidgets(5)); // 15は全部Gランク
    await t.tap(find.byKey(const Key('act-train')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recent')), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp(r'^素振りとティー打撃(\(.+\))?: 打撃経験点 \+').hasMatch(w.data ?? '')),
        findsOneWidget);
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
    expect(
        find.byKey(const Key('route-corporate')), findsOneWidget); // 進路の選択が出ている
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
    await t.tap(find.byKey(const Key('give-up-confirm')));
    await t.pumpAndSettle();
    expect(find.text('プロにはなれなかった'), findsOneWidget);
    await _dismissMilestones(t);
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
    await t.pumpWidget(
        BaseballManagerApp(controller: GameController(rng: Random(1))));
    await t.pumpAndSettle();
    expect(find.text('はじめる'), findsOneWidget);
  });

  testWidgets('高校では月の名前が出る', (t) async {
    final c = await _start(t);
    c.adopt(
        _until((g) => g.stage == Stage.highSchool && g.phase == Phase.term));
    await t.pumpAndSettle();
    expect(find.textContaining('4月'), findsWidgets);
    expect(find.textContaining('高校'), findsWidgets);
  });
}

void _rankTests() {
  test('ランクは10ごとに上がり、色が違う', () {
    expect(rankOf(0), 'G');
    expect(rankOf(29), 'G');
    expect(rankOf(30), 'F');
    expect(rankOf(49), 'E');
    expect(rankOf(50), 'D');
    expect(rankOf(60), 'C');
    expect(rankOf(70), 'B');
    expect(rankOf(80), 'A');
    expect(rankOf(90), 'S');
    expect(rankOf(99), 'S');
    expect(
        ['G', 'F', 'E', 'D', 'C', 'B', 'A', 'S'].map(rankColor).toSet().length,
        8);
  });

  testWidgets('進学すると、ダイアログで知らせる', (t) async {
    final c = await _start(t);
    // 12歳の冬(最後のターン)まで進めておき、1手で13歳(中学)になるようにする。
    c.adopt(_until(
        (g) => g.player.age == 12 && g.slot == 3 && g.phase == Phase.term));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('act-rest')));
    await t.pumpAndSettle();
    if (c.game!.phase == Phase.event) {
      await t.tap(find.byKey(const Key('event-0')));
      await t.pumpAndSettle();
    }
    expect(find.text('中学へ'), findsOneWidget);
    await t.tap(find.byKey(const Key('milestone-ok')));
    await t.pumpAndSettle();
    expect(find.text('中学へ'), findsNothing);
    expect(c.pending, isEmpty);
  });

  testWidgets('ドラフトで指名されると、ダイアログで祝う', (t) async {
    final c = await _start(t);
    for (var s = 0; s < 60; s++) {
      final g = _until(
          (g) => g.player.age == 18 && g.slot == 11 && g.phase == Phase.term,
          seed: s,
          potential: 100);
      if (g.player.age != 18) continue;
      c.adopt(g);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('act-rest')));
      await t.pumpAndSettle();
      if (c.game!.phase == Phase.event) {
        await t.tap(find.byKey(const Key('event-0')));
        await t.pumpAndSettle();
      }
      if (!c.game!.turnedPro) {
        // 外れた年: 優勝などの節目が出ていれば閉じて、次の乱数へ。
        while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const Key('milestone-ok')));
          await t.pumpAndSettle();
        }
        continue;
      }
      expect(find.text('ドラフト指名!'), findsOneWidget);
      return;
    }
    fail('60人試して指名された選手がいない');
  });

  testWidgets('優勝すると、ダイアログで祝う', (t) async {
    final c = await _start(t);
    for (var s = 0; s < 80; s++) {
      final g = _until(
          (g) => g.player.age >= 12 && g.slot == 0 && g.phase == Phase.term,
          seed: s,
          potential: 100);
      c.adopt(g);
      await t.pumpAndSettle();
      // 夏(slot 1)まで進める。
      await t.tap(find.byKey(const Key('act-rest')));
      await t.pumpAndSettle();
      if (c.game!.phase == Phase.event) {
        await t.tap(find.byKey(const Key('event-0')));
        await t.pumpAndSettle();
      }
      await t.tap(find.byKey(const Key('act-train')));
      await t.pumpAndSettle();
      if (find.text('優勝!').evaluate().isNotEmpty) return;
      while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
        await t.tap(find.byKey(const Key('milestone-ok')));
        await t.pumpAndSettle();
      }
    }
    fail('80人試して優勝した選手がいない');
  });

  testWidgets('引退すると殿堂に残り、もう一度の画面に並ぶ。二重には残らない', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up-confirm')));
    await t.pumpAndSettle();
    expect(c.history, hasLength(1));
    expect(c.history.first.title, 'プロにはなれなかった');
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('again')));
    await t.pumpAndSettle();
    expect(find.text('殿堂(これまでの選手)'), findsOneWidget);
    expect(find.textContaining('プロ入りならず'), findsOneWidget);
    // 同じ引退を読み直しても増えない。
    c.adopt(c.game ??
        _until((g) => g.phase == Phase.retired, seed: 3, potential: 0));
    expect(c.history, hasLength(1));
  });

  testWidgets('殿堂は開き直しても残る', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up-confirm')));
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('again')));
    await t.pumpAndSettle();

    final c2 = GameController(rng: Random(5));
    await t.pumpWidget(BaseballManagerApp(key: UniqueKey(), controller: c2));
    await t.pumpAndSettle();
    expect(c2.history, hasLength(1));
    expect(find.text('殿堂(これまでの選手)'), findsOneWidget);
  });

  testWidgets('あそびかたを開ける', (t) async {
    await _start(t);
    await t.tap(find.byKey(const Key('help')));
    await t.pumpAndSettle();
    expect(find.text('あそびかた'), findsWidgets);
    expect(find.textContaining('経験点'), findsWidgets);
    await t.tap(find.text('閉じる'));
    await t.pumpAndSettle();
    expect(find.text('閉じる'), findsNothing);
  });

  testWidgets('タイトルを7回タップすると管理者モードが入り、素質・特性・コツを書き換えられる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('admin-open')), findsNothing);
    for (var i = 0; i < 6; i++) {
      await t.tap(find.byKey(const Key('title')));
    }
    await t.pump();
    expect(c.adminMode, isFalse); // 6回ではまだ
    await t.tap(find.byKey(const Key('title')));
    await t.pumpAndSettle();
    expect(c.adminMode, isTrue);
    expect(find.text('管理者モード: オン'), findsOneWidget);

    await t.tap(find.byKey(const Key('admin-open')));
    await t.pumpAndSettle();
    expect(find.text('管理者機能'), findsOneWidget);

    // 素質をスライダーで最大に。
    await t.drag(
        find.byKey(const Key('admin-potential')), const Offset(2000, 0));
    await t.pumpAndSettle();
    expect(c.game!.player.potential, 100);

    // 特性: 矛盾する2つを同時に付けられる。
    await t.ensureVisible(find.byKey(const Key('admin-trait-lateBloomer')));
    await t.tap(find.byKey(const Key('admin-trait-lateBloomer')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('admin-trait-earlyBloomer')));
    await t.tap(find.byKey(const Key('admin-trait-earlyBloomer')));
    await t.pumpAndSettle();
    expect(
        c.game!.player.traits
            .containsAll({Trait.lateBloomer, Trait.earlyBloomer}),
        isTrue);

    // コーチ: 教える特性を決めて、コツを満タンにすると習得する。
    await t.ensureVisible(find.byKey(const Key('admin-teach-clutch')));
    await t.tap(find.byKey(const Key('admin-teach-clutch')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('admin-tips')));
    await t.drag(find.byKey(const Key('admin-tips')), const Offset(2000, 0));
    await t.pumpAndSettle();
    expect(c.game!.player.traits, contains(Trait.clutch));
  });

  testWidgets('管理者モードは覚えていて、7回タップでもう一度切れる', (t) async {
    final c = await _start(t);
    for (var i = 0; i < 7; i++) {
      await t.tap(find.byKey(const Key('title')));
    }
    await t.pumpAndSettle();
    expect(c.adminMode, isTrue);

    final c2 = GameController(rng: Random(3));
    await t.pumpWidget(BaseballManagerApp(key: UniqueKey(), controller: c2));
    await t.pumpAndSettle();
    expect(c2.adminMode, isTrue); // 開き直しても残る
    for (var i = 0; i < 7; i++) {
      await t.tap(find.byKey(const Key('title')));
    }
    await t.pumpAndSettle();
    expect(c2.adminMode, isFalse);
  });

  testWidgets('管理者モードでなければ、管理者ボタンは出ない', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('admin-open')), findsNothing);
  });

  testWidgets('成績: 記録が無いうちは案内が出て、大会のあとは成績表が見られる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('records-open-card')), findsNothing);
    await t.tap(find.byKey(const Key('records-open')));
    await t.pumpAndSettle();
    expect(find.textContaining('まだ成績がありません'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();

    // 大会を終えた選手に差し替える。
    c.adopt(_until((g) => g.records.isNotEmpty && g.phase == Phase.term));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('records-open-card')), findsOneWidget);
    expect(find.textContaining('歳の成績'), findsOneWidget);
    await t.tap(find.byKey(const Key('records-open-card')));
    await t.pumpAndSettle();
    expect(find.text('テスト の成績'), findsOneWidget);
    expect(find.text('年度別成績'), findsOneWidget);
    expect(find.text('打率'), findsWidgets);
    expect(find.textContaining('通算'), findsWidgets);
  });

  testWidgets('成績: 投手は勝敗・防御率・奪三振の欄が出る。打者の欄は出ない', (t) async {
    final c = await _start(t);
    final g = Game.newGame(
        name: '投手', role: Role.pitcher, rng: Random(2), potential: 70);
    var steps = 0;
    while (g.records.isEmpty) {
      if (++steps > 100) fail('大会が進まない');
      g.autoSpend();
      g.phase == Phase.event
          ? g.resolveEvent(0)
          : g.choose(Plan.train, Ability.stuff);
    }
    c.adopt(g);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('records-open')));
    await t.pumpAndSettle();
    expect(find.text('防御率'), findsWidgets);
    expect(find.text('奪三振'), findsWidgets);
    expect(find.text('打率'), findsNothing);
  });

  testWidgets('成績: プロのシーズンは順位とプロ通算が出る', (t) async {
    final c = await _start(t);
    Game? g;
    for (var s = 0; s < 80 && g == null; s++) {
      final x = _until(
          (g) => g.stage == Stage.pro && g.records.any((r) => r.isLeague),
          seed: s,
          potential: 100);
      if (x.records.any((r) => r.isLeague)) g = x;
    }
    c.adopt(g!);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('records-open')));
    await t.pumpAndSettle();
    expect(find.textContaining('プロ通算 ('), findsOneWidget);
    // 順位(「3位」)か、優勝(「リーグ優勝」)のどちらかが表に出る。
    expect(
        find.byWidgetPredicate((w) =>
            w is Text && RegExp(r'^(\d位|リーグ優勝)$').hasMatch(w.data ?? '')),
        findsWidgets);
  });

  testWidgets('成績: エンディングにも成績表が出て、殿堂に通算成績が残る', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up-confirm')));
    await t.pumpAndSettle();
    expect(find.text('年度別成績'), findsOneWidget);
    expect(find.text('獲得したタイトル'), findsNothing); // 無ければ出さない
    expect(c.history.first.summary, startsWith('大会通算'));
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('again')));
    await t.pumpAndSettle();
    expect(find.textContaining('大会通算'), findsOneWidget);
  });

  testWidgets('おすすめ: 疲れていれば休養、気持ちが沈んでいれば交流、普段は練習', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recommended-train')), findsOneWidget);
    c.admin((g) => g.condition = const Condition(fatigue: 80, morale: 50));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recommended-rest')), findsOneWidget);
    expect(find.byKey(const Key('recommended-train')), findsNothing);
    c.admin((g) => g.condition = const Condition(fatigue: 10, morale: 20));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recommended-social')), findsOneWidget);
  });

  testWidgets('経験点が貯まったら、振り分けの案内が出る。使い切ると消える', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('spend-hint')), findsNothing);
    c.admin((g) => g.adminAddExp(5000));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('spend-hint')), findsOneWidget);
    c.admin((g) => g.adminAddExp(-100000));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('spend-hint')), findsNothing);
  });

  testWidgets('はじめの数ターンだけ案内が出て、1年たつと消える', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('first-hint')), findsOneWidget);
    c.adopt(_until((g) => g.player.age == 8 && g.phase == Phase.term));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('first-hint')), findsNothing);
  });

  testWidgets('経験点が貯まったら、育成画面の上のほうで「おまかせ」ですぐ振り分けられる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('quick-spend')), findsNothing);
    c.admin((g) => g.adminAddExp(3000));
    await t.pumpAndSettle();
    final before = c.game!.player.abilities.values.reduce((a, b) => a + b);
    await t.tap(find.byKey(const Key('quick-spend')));
    await t.pumpAndSettle();
    expect(c.game!.player.abilities.values.reduce((a, b) => a + b),
        greaterThan(before));
    expect(find.byKey(const Key('quick-spend')), findsNothing); // 使い切ったら消える
  });

  testWidgets('操作のカードは、能力カードより上にある(スクロールせずに選べる)', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    final actY = t.getTopLeft(find.byKey(const Key('act-train'))).dy;
    final abilityY = t.getTopLeft(find.byKey(const Key('buy-contact'))).dy;
    expect(actY, lessThan(abilityY));
  });

  testWidgets('「プロは諦める」は確認が出て、やめるを選べば続けられる', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    expect(find.text('プロは諦めますか?'), findsOneWidget);
    await t.tap(find.text('やめる'));
    await t.pumpAndSettle();
    expect(c.game!.phase, Phase.pathChoice); // まだ選べる
    expect(find.byKey(const Key('route-university')), findsOneWidget);
  });

  testWidgets('選手情報: アイコンでもバナーでも開け、プロフィール・成績・経歴の3つを見られる', (t) async {
    final c = await _start(t);
    c.newGame('ひなた', Role.pitcher);
    await t.pumpAndSettle();
    c.admin((g) => g.adminSetTraits({Trait.clutch, Trait.sturdy}));
    c.admin((g) => g.adminSetPotential(80));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('player-open')));
    await t.pumpAndSettle();
    expect(find.text('プロフィール'), findsOneWidget);
    expect(find.text('成績'), findsWidgets);
    expect(find.text('経歴'), findsOneWidget);
    expect(find.text('ひなた'), findsWidgets);
    expect(find.textContaining('総合評価'), findsOneWidget);
    expect(find.text('素質 ★★★★☆'), findsOneWidget);
    expect(find.byKey(const Key('trait-clutch')), findsOneWidget);
    expect(find.byKey(const Key('trait-sturdy')), findsOneWidget);
    expect(find.textContaining('大会での体調が'), findsOneWidget); // 特性の説明が読める
    expect(find.text('球威'), findsWidgets);
    expect(find.text('いまの状態'), findsOneWidget); // 育成中だけ出る

    await t.tap(find.byKey(const Key('tab-records')));
    await t.pumpAndSettle();
    expect(find.textContaining('まだ成績がありません'), findsOneWidget);

    await t.tap(find.byKey(const Key('tab-career')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('timeline')), findsOneWidget);
    expect(find.textContaining('少年野球を始めた'), findsOneWidget);

    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('banner')));
    await t.pumpAndSettle();
    expect(find.text('プロフィール'), findsOneWidget);
  });

  testWidgets('選手情報: 成績が溜まると成績タブに表が出て、経歴に優勝やドラフトが並ぶ', (t) async {
    final c = await _start(t);
    Game? g;
    for (var s = 0; s < 80 && g == null; s++) {
      final x = _until(
          (g) => g.stage == Stage.pro && g.records.any((r) => r.isLeague),
          seed: s,
          potential: 100);
      if (x.records.any((r) => r.isLeague)) g = x;
    }
    c.adopt(g!);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('player-open')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('tab-records')));
    await t.pumpAndSettle();
    expect(find.text('年度別成績'), findsOneWidget);
    await t.tap(find.byKey(const Key('tab-career')));
    await t.pumpAndSettle();
    expect(find.textContaining('位指名を受けて、プロ入り'), findsOneWidget);
    expect(find.textContaining('中学に進んだ'), findsOneWidget);
  });

  testWidgets('殿堂の選手をタップすると、その選手の情報(特性・成績・経歴)が見られる', (t) async {
    final c = await _start(t);
    final g = _until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0);
    g.adminSetTraits({Trait.genius});
    c.adopt(g);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up-confirm')));
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('again')));
    await t.pumpAndSettle();

    await t.tap(find.textContaining('テスト  ―  プロにはなれなかった'));
    await t.pumpAndSettle();
    expect(find.text('称号: プロにはなれなかった'), findsOneWidget);
    expect(find.byKey(const Key('trait-genius')), findsOneWidget);
    expect(find.text('いまの状態'), findsNothing); // 過去の選手には出ない
    await t.tap(find.byKey(const Key('tab-career')));
    await t.pumpAndSettle();
    expect(find.textContaining('プロを諦めた'), findsOneWidget);
    await t.tap(find.byKey(const Key('tab-records')));
    await t.pumpAndSettle();
    expect(find.text('年度別成績'), findsOneWidget);
  });

  testWidgets('設定: ホームからも育成中からも開け、管理者モードをスイッチで切り替えられる', (t) async {
    final c = await _start(t);
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    expect(find.text('管理者モード'), findsOneWidget);
    expect(c.adminMode, isFalse);
    await t.tap(find.byKey(const Key('admin-switch')));
    await t.pumpAndSettle();
    expect(c.adminMode, isTrue);
    // 選手がいなければ、管理者機能は開けない。
    expect(find.text('育成中の選手がいるときに開けます'), findsOneWidget);
    await t.tap(find.byKey(const Key('admin-switch')));
    await t.pumpAndSettle();
    expect(c.adminMode, isFalse);
  });

  testWidgets('設定: 育成中に、スイッチ→管理者機能まで3タップで着く', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('admin-switch')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('admin-open-settings')));
    await t.pumpAndSettle();
    expect(find.text('管理者機能'), findsOneWidget);
    await t.drag(
        find.byKey(const Key('admin-potential')), const Offset(2000, 0));
    await t.pumpAndSettle();
    expect(c.game!.player.potential, 100);
  });

  testWidgets('設定: すべてのデータを消す(確認つき)。殿堂も育成中の選手も消える', (t) async {
    final c = await _start(t);
    c.adopt(_until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('give-up-confirm')));
    await t.pumpAndSettle();
    expect(c.history, hasLength(1));
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('erase-all')));
    await t.pumpAndSettle();
    await t.tap(find.text('やめる')); // やめれば消えない
    await t.pumpAndSettle();
    expect(c.history, hasLength(1));
    await t.tap(find.byKey(const Key('erase-all')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('erase-confirm')));
    await t.pumpAndSettle();
    expect(c.history, isEmpty);
    expect(c.game, isNull);
    expect(find.text('はじめる'), findsOneWidget);
    expect(find.text('殿堂(これまでの選手)'), findsNothing);
  });

  testWidgets('作戦: 大会の前の季節と大会の季節にだけ選択肢が出て、選ぶと反映され、大会後に消える', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tactic-picker')), findsOneWidget); // 春(大会の前)
    await t.tap(find.byKey(const Key('tactic-aggressive')));
    await t.pumpAndSettle();
    expect(c.game!.tactic, Tactic.aggressive);
    expect(find.textContaining('長打・球威を重視'), findsOneWidget);
    await t.tap(find.byKey(const Key('act-rest')));
    await t.pumpAndSettle();
    if (c.game!.phase == Phase.event) {
      await t.tap(find.byKey(const Key('event-0')));
      await t.pumpAndSettle();
    }
    expect(find.byKey(const Key('tactic-picker')), findsOneWidget); // 夏(大会)
    await t.tap(find.byKey(const Key('act-rest')));
    await t.pumpAndSettle();
    if (c.game!.phase == Phase.event) {
      await t.tap(find.byKey(const Key('event-0')));
      await t.pumpAndSettle();
    }
    // 大会が終わった。ダイアログが出ていれば閉じる。
    while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('milestone-ok')));
      await t.pumpAndSettle();
    }
    expect(find.byKey(const Key('tactic-picker')), findsNothing); // 秋
    expect(c.game!.tactic, Tactic.steady);
  });

  testWidgets('今年の目標: 画面に出て、達成すると「達成!」になる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('goal-row')), findsOneWidget);
    expect(find.textContaining('今年の目標:'), findsOneWidget);
    expect(find.text('挑戦中'), findsOneWidget);
    expect(find.textContaining('達成すると 経験点+'), findsOneWidget);
    c.admin((g) => g.goal = Goal(GoalKind.rounds, 0));
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byKey(const Key('act-rest')));
      await t.pumpAndSettle();
      if (c.game!.phase == Phase.event) {
        await t.tap(find.byKey(const Key('event-0')));
        await t.pumpAndSettle();
      }
    }
    while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('milestone-ok')));
      await t.pumpAndSettle();
    }
    expect(find.text('達成!'), findsOneWidget);
    expect(find.text('ごほうびをもらった'), findsOneWidget);
  });

  testWidgets('難しさ: はじめの画面で選べ、選んだものでその選手が始まる。説明が出る', (t) async {
    final c = await _start(t);
    expect(find.text('難しさ'), findsOneWidget);
    expect(find.textContaining('ほどよい難しさ'), findsOneWidget);
    await t.tap(find.text('むずかしい'));
    await t.pumpAndSettle();
    expect(find.textContaining('経験点が0.9倍'), findsOneWidget);
    await t.tap(find.text('はじめる'));
    await t.pumpAndSettle();
    expect(c.game!.difficulty, Difficulty.hard);
    await t.tap(find.byKey(const Key('player-open')));
    await t.pumpAndSettle();
    expect(find.text('むずかしい'), findsOneWidget); // 選手情報に出る
  });

  testWidgets('実績: 一生が終わると解除され、ダイアログとエンディングで知らせる。保存されて、ホームと一覧に出る', (t) async {
    final c = await _start(t);
    Game? g;
    for (var s = 0; s < 80 && g == null; s++) {
      final x = _until((g) => g.stage == Stage.pro && g.phase == Phase.term,
          seed: s, potential: 100);
      if (x.stage == Stage.pro) g = x;
    }
    c.adopt(g!);
    await t.pumpAndSettle();
    expect(c.unlocked, isEmpty);
    await t.tap(find.byKey(const Key('retire')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('retire-confirm')));
    await t.pumpAndSettle();
    // 実績解除のダイアログ(プロ入りは必ず含まれる)。
    expect(find.text('実績解除!'), findsWidgets);
    expect(find.textContaining('プロの舞台へ'), findsWidgets);
    while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('milestone-ok')));
      await t.pumpAndSettle();
    }
    expect(c.unlocked, contains('first-pro'));
    expect(find.byKey(const Key('new-achievements')), findsOneWidget);
    expect(c.newlyUnlocked.map((a) => a.id), contains('first-pro'));

    // 次の一生では、解除済みのものはもう「新しい」に出ない。
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('again')));
    await t.pumpAndSettle();
    expect(find.textContaining('解除'), findsWidgets); // 「n / 19 解除」
    // 開き直しても残っている。
    final c2 = GameController(rng: Random(5));
    await t.pumpWidget(BaseballManagerApp(key: UniqueKey(), controller: c2));
    await t.pumpAndSettle();
    expect(c2.unlocked, contains('first-pro'));
    await t.tap(find.byKey(const Key('achievements-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('achievements-count')), findsOneWidget);
    expect(find.textContaining('解除した実績 '), findsOneWidget);
    expect(find.byKey(const Key('ach-first-pro')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('実績: 設定からも開け、「すべてのデータを消す」で実績も消える', (t) async {
    final c = await _start(t);
    c.unlocked = {'first-pro'};
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-achievements')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ach-first-pro')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('erase-all')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('erase-confirm')));
    await t.pumpAndSettle();
    expect(c.unlocked, isEmpty);
  });

  testWidgets('おすすめで年末まで進める: 年が変わるか、出来事・節目で止まる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    final age = c.game!.player.age;
    await t.tap(find.byKey(const Key('auto-year')));
    await t.pumpAndSettle();
    final g = c.game!;
    expect(
        g.player.age > age ||
            g.phase != Phase.term ||
            c.pending.isNotEmpty ||
            g.slot > 0,
        isTrue);
    // 何回進めたかが「いまの結果」に出る(1回しか進まなかったときは出ない)
    if (g.slot > 1 || g.player.age > age) {
      expect(c.recent.first, matches(RegExp(r'^おすすめの過ごし方で\d+回進めた。$')));
    }
    // 何度押しても壊れず、出来事は自分で選ぶまで止まっている
    for (var i = 0; i < 30 && c.game!.phase != Phase.retired; i++) {
      await _dismissMilestones(t);
      if (c.game!.phase == Phase.event) {
        c.chooseEvent(0);
      } else if (c.game!.phase == Phase.pathChoice) {
        c.chooseRoute(Course.university);
      } else {
        c.autoYear();
      }
      c.autoSpend();
      await t.pumpAndSettle();
    }
    expect(c.game!.player.age, greaterThan(age + 2));
  });

  testWidgets('せまい画面(幅320)・大きい文字(1.6倍)でも、どの画面も溢れない', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await SaveStore().saveHistory([
      HistoryEntry.of(_until((g) => false, seed: 5, potential: 90)),
    ]);
    final c = GameController(rng: Random(5));
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'ホーム(殿堂つき)');
    // ホーム → 実績 → 戻る
    await t.scrollUntilVisible(find.byKey(const Key('achievements-open')), 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('achievements-open')));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    final lives = <Game>[
      Game.newGame(name: 'テスト', role: Role.pitcher, rng: Random(5)),
      _until((g) => g.stage == Stage.juniorHigh, seed: 5),
      _until((g) => g.stage == Stage.highSchool, seed: 5),
      _until((g) => g.stage == Stage.pro, seed: 5, potential: 90),
      _until((g) => false, seed: 5, potential: 90), // 引退まで
      for (var sd = 1; sd <= 5; sd++)
        _until((g) => false, seed: sd, potential: 70),
    ];
    for (final g in lives) {
      c.adopt(g);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '${g.stage}');
      for (final k in ['player-open', 'records-open', 'settings-open']) {
        final f = find.byKey(Key(k));
        if (f.evaluate().isEmpty) {
          continue;
        }
        await t.tap(f.first);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${g.stage} $k');
        await t.pageBack();
        await t.pumpAndSettle();
      }
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('エンディングの「結果をコピーする」で文章が作られ、通知が出る', (t) async {
    final c = await _start(t);
    final g = _until((g) => false, seed: 5, potential: 90);
    expect(g.phase, Phase.retired);
    final text = endingShareText(g);
    expect(text, contains('テスト'));
    expect(text, contains('最高の総合評価'));
    String? copied;
    t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    c.adopt(g);
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    await t.tap(find.byKey(const Key('copy-result')));
    await t.pumpAndSettle();
    expect(copied, text);
    expect(find.text('コピーしました。友だちに見せよう'), findsOneWidget);
  });

  group('バックアップ', () {
    test('書き出して別のコントローラに読み込むと、選手・殿堂・実績が戻る', () async {
      SharedPreferences.setMockInitialValues({});
      final a = GameController(rng: Random(1));
      a.adopt(_until((g) => g.stage == Stage.highSchool, seed: 5));
      a.history = [HistoryEntry.of(_until((g) => false, seed: 6))];
      a.unlocked = {'first-pro', 'title'};
      final text = a.exportBackup();

      SharedPreferences.setMockInitialValues({});
      final b = GameController(rng: Random(2));
      expect(await b.importBackup(text), isTrue);
      expect(b.game!.player.name, a.game!.player.name);
      expect(b.game!.player.age, a.game!.player.age);
      expect(b.history, hasLength(1));
      expect(b.unlocked, {'first-pro', 'title'});
      // 読み込んだ内容は保存もされる
      final c = GameController(rng: Random(3));
      expect(await c.loadSaved(), isTrue);
      expect(c.game!.player.age, a.game!.player.age);
      expect(c.unlocked, {'first-pro', 'title'});
    });

    test('読めない文字列・別のアプリのデータは、何も変えず false', () async {
      SharedPreferences.setMockInitialValues({});
      final c = GameController(rng: Random(1));
      c.adopt(_until((g) => g.stage == Stage.highSchool, seed: 5));
      final age = c.game!.player.age;
      expect(await c.importBackup('これは違う'), isFalse);
      expect(await c.importBackup('{"app":"other"}'), isFalse);
      expect(await c.importBackup('{"app":"baseball-manager","game":{"x":'),
          isFalse);
      expect(c.game!.player.age, age);
    });

    testWidgets('設定から開いて、読めない文字列だとお知らせが出る', (t) async {
      final c = await _start(t);
      await t.tap(find.byKey(const Key('settings-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('backup-open')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('backup-text')), 'でたらめ');
      await t.tap(find.byKey(const Key('backup-import')));
      await t.pumpAndSettle();
      expect(find.textContaining('読み込めませんでした'), findsOneWidget);
      expect(c.game, isNull);
    });
  });

  group('出来事の結果', () {
    test('変わったところだけ言葉にする。何も変わらなければ空', () {
      final p0 = Player(
          name: 't',
          role: Role.pitcher,
          age: 15,
          potential: 50,
          abilities: {for (final a in pitcherAbilities) a: 30});
      const c0 = Condition(fatigue: 10, morale: 50);
      final p1 = p0.copyWith(abilities: {...p0.abilities, Ability.stuff: 33});
      final c1 = c0.copyWith(morale: 58, fatigue: 6);
      expect(eventResultText(p0, c0, p1, c1), '球威 +3 / 気持ち +8 / 疲れ -4');
      expect(eventResultText(p0, c0, p0, c0), '');
      // 役割に無い能力(投手のミート)は出さない
      expect(
          eventResultText(p0, c0, p0.copyWith(abilities: {...p0.abilities}),
              c0.copyWith(injuredTerms: 2)),
          '怪我');
    });

    testWidgets('出来事を選ぶと「選んだ結果」が画面に出る', (t) async {
      final c = await _start(t);
      var shownOnce = false;
      for (var seed = 1; seed < 40 && !shownOnce; seed++) {
        final g = _until((g) => g.phase == Phase.event, seed: seed);
        if (g.phase != Phase.event) {
          continue;
        }
        final p0 = g.player;
        final c0 = g.condition;
        c.adopt(g);
        await t.pumpAndSettle();
        await _dismissMilestones(t);
        await t.tap(find.byKey(const Key('event-0')));
        await t.pumpAndSettle();
        final expected = eventResultText(p0, c0, g.player, g.condition);
        if (expected.isNotEmpty) {
          expect(c.recent.first, '選んだ結果: $expected');
          expect(find.textContaining('選んだ結果:'), findsOneWidget);
          shownOnce = true;
        } else {
          expect(c.recent.any((l) => l.startsWith('選んだ結果:')), isFalse);
        }
      }
      expect(shownOnce, isTrue);
    });
  });

  group('育成の手ごたえ', () {
    testWidgets('選手カードに所属・背番号(少年野球は無し)・投打・守備位置が出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('player-card')), findsOneWidget);
      expect(find.textContaining('ジュニアーズ'), findsOneWidget);
      expect(find.textContaining('背番号'), findsNothing); // 少年野球
      c.adopt(_until((g) => g.stage == Stage.highSchool, seed: 5));
      await t.pumpAndSettle();
      expect(find.textContaining('高校 野球部'), findsOneWidget);
      expect(find.textContaining('背番号'), findsOneWidget);
    });

    testWidgets('選手情報にも所属と背番号・投打・守備位置が出る', (t) async {
      final c = await _start(t);
      c.adopt(_until((g) => g.stage == Stage.highSchool, seed: 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('profile-affiliation')), findsOneWidget);
      final line = t.widget<Text>(find.byKey(const Key('profile-card'))).data!;
      expect(line, contains('背番号'));
      expect(line, contains('投'));
    });

    testWidgets('練習の名前は重点の能力で変わる(素振り→ノック)', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.text('素振りとティー打撃'), findsOneWidget);
      await t.tap(find.byKey(const Key('focus-fielding')));
      await t.pumpAndSettle();
      expect(find.text('ノック(守備練習)'), findsOneWidget);
      expect(find.text('特訓: ノック(守備練習)'), findsOneWidget);
    });

    testWidgets('経験点で能力を上げると、今回の上昇とランクアップが出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      c.act(Plan.rest);
      c.game!.adminAddExp(400);
      await t.pumpAndSettle();
      var guard = 0;
      while (!c.recent.any((l) => l.contains('ランクに上がった')) && guard++ < 60) {
        c.spend(Ability.contact);
      }
      await t.pumpAndSettle();
      expect(c.recent.any((l) => l.contains('ミートが Fランクに上がった!')), isTrue,
          reason: '${c.recent}');
      expect(c.abilityGains[Ability.contact], greaterThan(0));
      final gainText =
          t.widget<Text>(find.byKey(const Key('gain-contact'))).textSpan!;
      expect(gainText.toPlainText(), contains('+'));
      // 次の行動で「今回の上昇」は消える
      c.act(Plan.rest);
      await t.pumpAndSettle();
      expect(c.abilityGains, isEmpty);
    });
  });

  group('世界大会の画面', () {
    Game withWorld() {
      for (var seed = 0; seed < 60; seed++) {
        final g = _until((g) => false, seed: seed, potential: 100);
        if (g.worldRecords.isNotEmpty) return g;
      }
      fail('世界大会に出た選手がいない');
    }

    testWidgets('エンディングの成績に世界大会の一覧が出て、結果コピーにも入る', (t) async {
      final c = await _start(t);
      final g = withWorld();
      c.adopt(g);
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      expect(find.byKey(const Key('world-records')), findsOneWidget);
      expect(find.textContaining(g.worldRecords.first.eventName), findsWidgets);
      expect(endingShareText(g),
          contains('日本代表: 世界大会${g.worldRecords.length}回出場'));
    });

    test('代表に選ばれた・世界一になったとき、節目のダイアログが積まれる', () async {
      SharedPreferences.setMockInitialValues({});
      var sawNational = false;
      for (var seed = 0; seed < 40 && !sawNational; seed++) {
        final c = GameController(rng: Random(seed));
        c.newGame('テスト', Role.batter);
        var n = 0;
        while (c.game!.phase != Phase.retired && n++ < 4000) {
          c.autoSpend();
          switch (c.game!.phase) {
            case Phase.term:
              c.act(c.game!.condition.fatigue >= 60 ? Plan.rest : Plan.train);
            case Phase.event:
              c.chooseEvent(0);
            case Phase.pathChoice:
              c.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
          if (c.pending.any((m) => m.kind == MilestoneKind.national)) {
            sawNational = true;
            final m =
                c.pending.firstWhere((m) => m.kind == MilestoneKind.national);
            expect(m.title, '日本代表に選出!');
            expect(m.body, contains('世界大会'));
            break;
          }
        }
      }
      expect(sawNational, isTrue);
    });
  });

  group('指標の画面', () {
    testWidgets('成績画面に指標のカードが出て、項目をタップすると意味が出る', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 80 && g == null; sd++) {
        final x = _until(
            (g) => g.stage == Stage.pro && g.records.any((r) => r.isLeague),
            seed: sd,
            potential: 100);
        if (x.records.any((r) => r.isLeague)) g = x;
      }
      c.adopt(g!);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('records-open')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('metrics')), findsOneWidget);
      expect(find.text('出塁率'), findsOneWidget);
      expect(find.text('OPS+'), findsWidgets); // 指標カードと表の見出し
      expect(find.text('打点'), findsWidgets);
      await t.tap(find.text('出塁率'));
      await t.pumpAndSettle();
      expect(find.textContaining('塁に出た割合'), findsOneWidget);
    });
  });
}
