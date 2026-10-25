import 'dart:math';

import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/game/after_career.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/childhood.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/invest.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/difficulty.dart';
import 'package:baseball_manager/game/goals.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:baseball_manager/game/tryout.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:baseball_manager/ui/history.dart';
import 'package:baseball_manager/ui/game_screen.dart' show endingShareText;
import 'package:baseball_manager/ui/labels.dart';
import 'package:baseball_manager/ui/trait_book_screen.dart';
import 'package:baseball_manager/ui/widgets.dart' show CastCard;
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

/// 下のタブを切り替える(train=育成 / ability=能力 / career=キャリア)。
Future<void> _tab(WidgetTester t, String name) async {
  await t.tap(find.byKey(Key('tab-$name')));
  await t.pumpAndSettle();
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
    await _tab(t, 'ability');
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
    c.recent = []; // 生まれ(引き直しの見本)によっては、生まれ持った才能の知らせが出るので消す
    c.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recent')), findsNothing);
    await _tab(t, 'ability');
    expect(find.text('G'), findsNWidgets(6)); // 15は全部Gランク(5能力+総合)
    await _tab(t, 'train');
    await t.tap(find.byKey(const Key('act-train')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recent')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('recent')),
            matching: find.byWidgetPredicate((w) =>
                w is Text &&
                RegExp(r'^素振りとティー打撃(\(.+\))?: 打撃経験点 \+')
                    .hasMatch(w.data ?? ''))),
        findsOneWidget);
    // 画面の下に、結果が一瞬出る(どこまでスクロールしていても見える)
    expect(find.byKey(const Key('result-toast')), findsOneWidget);
  });

  testWidgets('育成タブに、おすすめの印つきの行動が並び、疲れると休養がおすすめになる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    c.recent = []; // 生まれ持った才能の知らせは消しておく
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recommended-train')), findsOneWidget);
    expect(c.recent, isEmpty);
    await t.tap(find.byKey(const Key('act-train')));
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(c.recent, isNotEmpty);
    if (c.game!.phase == Phase.event) c.game!.resolveEvent(0);
    c.game!.condition = c.game!.condition.copyWith(fatigue: 90);
    c.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recommended-rest')), findsOneWidget);
    expect(find.byKey(const Key('recommended-train')), findsNothing);
  });

  testWidgets('経験点が足りない能力の+1は押せない', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    await _tab(t, 'ability');
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
    // 幼少期などの「分かれ道」(見出しが別)ではなく、ふつうの出来事で止める。
    c.adopt(_until((g) =>
        g.phase == Phase.event &&
        !childhoodSteps.any((s) => s.event == g.pendingEvent)));
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
    await _tab(t, 'career');
    expect(find.byKey(const Key('role-twoway')), findsOneWidget);
    await t.tap(find.byKey(const Key('role-twoway')));
    await t.pumpAndSettle();
    expect(c.game!.player.role, Role.twoWay);
    await _tab(t, 'ability');
    expect(find.text('球威'), findsWidgets); // 投手の能力も並ぶ
    expect(find.text('ミート'), findsWidgets);
    await _tab(t, 'career');
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
      // 決勝まで来たら、見せ場の作戦を選ぶ。
      if (c.game!.phase == Phase.event &&
          c.game!.pendingEvent!.id == 'final-moment') {
        await t.tap(find.byKey(const Key('event-1')));
        await t.pumpAndSettle();
      }
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

    // コーチ: 教える特殊能力を決めて、コツを満タンにすると習得する。
    await t.ensureVisible(find.byKey(const Key('admin-teach-chance')));
    await t.tap(find.byKey(const Key('admin-teach-chance')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('admin-tips')));
    await t.drag(find.byKey(const Key('admin-tips')), const Offset(2000, 0));
    await t.pumpAndSettle();
    expect(c.game!.skillTips[Skill.chance], maxSkillTips);

    // 天賦: スライダーで書き換えられ、レア特性も付けられる。覚醒済みの印も切り替えられる。
    await t.ensureVisible(find.byKey(const Key('admin-gift-contact')));
    await t.drag(
        find.byKey(const Key('admin-gift-contact')), const Offset(2000, 0));
    await t.pumpAndSettle();
    expect(c.game!.player.gift(Ability.contact), 2);
    await t.ensureVisible(find.byKey(const Key('admin-trait-monster')));
    await t.tap(find.byKey(const Key('admin-trait-monster')));
    await t.pumpAndSettle();
    expect(c.game!.player.traits, contains(Trait.monster));
    expect(c.game!.awakened, isFalse);
    await t.ensureVisible(find.byKey(const Key('admin-awakened')));
    await t.tap(find.byKey(const Key('admin-awakened')));
    await t.pumpAndSettle();
    expect(c.game!.awakened, isTrue);

    // 特殊能力: 付け外しと、コツの満タン。
    await t.ensureVisible(find.byKey(const Key('admin-skill-stealer')));
    await t.tap(find.byKey(const Key('admin-skill-stealer')));
    await t.pumpAndSettle();
    expect(c.game!.player.skills, contains(Skill.stealer));
    await t.ensureVisible(find.byKey(const Key('admin-tips-max')));
    await t.tap(find.byKey(const Key('admin-tips-max')));
    await t.pumpAndSettle();
    expect(c.game!.skillTips[Skill.powerHitter], maxSkillTips);
    expect(c.game!.skillTips.containsKey(Skill.stealer), isFalse);
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
    await _tab(t, 'career');
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
    await _tab(t, 'ability');
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

  testWidgets('操作は育成タブにあり、能力は別タブ。育成タブは1画面に収まる(スクロール不要)', (t) async {
    final c = await _start(t);
    t.view.physicalSize = const Size(390, 844);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('act-train')), findsOneWidget);
    expect(find.byKey(const Key('buy-contact')), findsNothing);
    // 行動は4列のタイルで並ぶ(縦に長くしない)
    final xs = {
      for (final plan in Plan.values)
        t.getTopLeft(find.byKey(Key('act-${plan.name}'))).dx
    };
    expect(xs.length, 4);
    await _tab(t, 'ability');
    expect(find.byKey(const Key('buy-contact')), findsOneWidget);
    expect(find.byKey(const Key('act-train')), findsNothing);
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

  testWidgets('幼少期の分かれ道: 見出しが出て、選ぶと選手情報の「育ち」に載る', (t) async {
    final c = await _start(t);
    final g = _until((g) => g.pendingEvent?.id == 'kid-first-play', seed: 4);
    c.adopt(g);
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(find.text('幼少期の分かれ道'), findsOneWidget);
    await t.tap(find.byKey(const Key('event-1')));
    await t.pumpAndSettle();
    expect(c.game!.childhood['kid-first-play'], 1);
    await t.tap(find.byKey(const Key('player-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('upbringing')), findsOneWidget);
    expect(find.textContaining('6歳: 走り回るのが好きな子だった'), findsOneWidget);
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
    expect(find.text('才能 ★★★★★'), findsOneWidget);
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

  testWidgets('今年の目標: 画面に出て、達成すると「達成!」になる', (t) async {
    final c = await _start(t);
    c.newGame('テスト', Role.batter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('goal-row')), findsOneWidget);
    expect(find.textContaining('今年の目標:'), findsOneWidget);
    expect(find.text('挑戦中'), findsOneWidget);
    expect(find.textContaining('達成で 経験点+'), findsOneWidget);
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

  testWidgets('難しさは選ばない(2026-10-24 ユーザー「難しさのコントロールはいらない」)。いつも「ふつう」で始まる', (t) async {
    final c = await _start(t);
    expect(find.text('難しさ'), findsNothing);
    expect(find.byKey(const Key('difficulty')), findsNothing);
    await t.tap(find.text('はじめる'));
    await t.pumpAndSettle();
    expect(c.game!.difficulty, Difficulty.normal);
    await t.tap(find.byKey(const Key('player-open')));
    await t.pumpAndSettle();
    expect(find.text('難しさ'), findsNothing); // 選手情報にも出さない
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
    await _tab(t, 'career');
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
    // 継承ポイントがあるときの新規開始画面も、狭い画面・大きい文字で溢れない
    c.legacyPoints = 12;
    c.seenTraits = {
      Trait.genius.name,
      Trait.hardWorker.name,
      Trait.leader.name
    };
    c.notifyListeners();
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('carry-genius')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('carry-genius')), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'ホーム(継承)');
    // ホーム → 実績 → 戻る
    await t.scrollUntilVisible(find.byKey(const Key('achievements-open')), 200,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.byKey(const Key('achievements-open')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('achievements-open')));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    // ホーム → 特性図鑑 → 戻る(狭い画面・大きい文字で溢れない)
    await t.scrollUntilVisible(find.byKey(const Key('trait-book-open')), 200,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.byKey(const Key('trait-book-open')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('trait-book-open')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trait-book-count')), findsOneWidget);
    expect(t.takeException(), isNull, reason: '特性図鑑');
    await t.pageBack();
    await t.pumpAndSettle();
    // 分かれ道(全部)の出来事カードも、狭い画面・大きい文字で溢れない
    for (final st in childhoodSteps) {
      final k = Game.newGame(name: 'テスト', role: Role.batter, rng: Random(2))
        ..pendingEvent = st.event
        ..phase = Phase.event;
      c.adopt(k);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: st.id);
    }
    final lives = <Game>[
      Game.newGame(name: 'テスト', role: Role.pitcher, rng: Random(5)),
      _until((g) => g.stage == Stage.juniorHigh, seed: 5),
      _until((g) => g.stage == Stage.highSchool, seed: 5),
      _until((g) => g.stage == Stage.pro, seed: 5, potential: 90),
      _until((g) => false, seed: 5, potential: 90), // 引退まで
      _until((g) => g.canUseFa, seed: 5, potential: 100), // FA権つきのプロ
      for (var sd = 1; sd <= 5; sd++)
        _until((g) => false, seed: sd, potential: 70),
    ];
    for (final g in lives) {
      c.adopt(g);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '${g.stage}');
      // 3つのタブ(育成・能力・キャリア)も溢れない
      for (final tab in ['ability', 'career', 'relations', 'train']) {
        if (find.byKey(Key('tab-$tab')).evaluate().isEmpty) continue;
        await _tab(t, tab);
        expect(t.takeException(), isNull, reason: '${g.stage} tab-$tab');
      }
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
    await t.scrollUntilVisible(find.byKey(const Key('copy-result')), 300,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.byKey(const Key('copy-result')));
    await t.pumpAndSettle();
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
      expect(eventResultText(p0, c0, p1, c1), '球威 +3 / やる気 +8 / 疲れ -4');
      expect(eventResultText(p0, c0, p0, c0), '');
      expect(
          eventResultText(p0, c0, p0.copyWith(traits: {Trait.hardWorker}), c0,
              tips0: 1, tips1: 2),
          '特性「努力家」 / コーチのコツ +1');
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
      // 行動のタイルは短い名前。長押しの説明(ツールチップ)に具体的な練習名が出る
      Finder tip(String text) => find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith(text));
      expect(tip('素振りとティー打撃'), findsOneWidget);
      await t.tap(find.byKey(const Key('focus-fielding')));
      await t.pumpAndSettle();
      expect(tip('ノック(守備練習)'), findsOneWidget);
      expect(tip('特訓: ノック(守備練習)'), findsOneWidget);
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
      await _tab(t, 'ability');
      final gainText =
          t.widget<Text>(find.byKey(const Key('gain-contact'))).textSpan!;
      expect(gainText.toPlainText(), contains('+'));
      // 次の行動で「今回の上昇」は消える(出来事が起きていたら先に選ぶ)
      if (c.game!.phase == Phase.event) c.chooseEvent(0);
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

  group('ポジション', () {
    testWidgets('中学・高校の最初の年にだけ「ポジションを決めよう」が出て、選べる', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('position-card')), findsNothing); // 少年野球
      c.adopt(_until((g) => g.stage == Stage.highSchool, seed: 5));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('position-card')), findsOneWidget);
      expect(find.textContaining('(おすすめ)'), findsOneWidget);
      // 捕手を選ぶと、選手カードの守備位置も変わる
      await t.tap(find.byKey(const Key('pos-catcher')));
      await t.pumpAndSettle();
      expect(c.game!.position, Pos.catcher);
      expect(find.textContaining('捕手'), findsWidgets);
      // 年の途中では出ない
      c.act(Plan.rest);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('position-card')), findsNothing);
    });

    testWidgets('選手情報にポジション適性が並ぶ', (t) async {
      final c = await _start(t);
      c.adopt(_until((g) => g.stage == Stage.highSchool, seed: 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('aptitude-card')), findsOneWidget);
      final p = c.game!.player;
      for (final pos in positionsFor(p.role)) {
        expect(find.text(pos.label), findsWidgets, reason: pos.label);
      }
    });
  });

  group('目標のむずかしさの画面', () {
    testWidgets('年の最初に3つから選べて、選ぶと目標が変わり、行動すると選べなくなる', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      // 画面を占領しないよう、ふだんは閉じていて、ボタンで開く
      expect(find.byKey(const Key('goal-picker')), findsNothing);
      await t.tap(find.byKey(const Key('goal-change')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('goal-picker')), findsOneWidget);
      expect(find.byKey(const Key('goal-level-0')), findsOneWidget);
      expect(find.byKey(const Key('goal-level-2')), findsOneWidget);
      final normal = c.game!.goal!.target;
      await t.tap(find.byKey(const Key('goal-level-2')));
      await t.pumpAndSettle();
      expect(c.game!.goal!.level, 2);
      expect(c.game!.goal!.baseTarget, normal);
      expect(find.textContaining('達成で 経験点+${goalExpFor(Stage.youth, 2)}'),
          findsOneWidget);
      await t.tap(find.text('閉じる'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('act-rest')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('goal-change')), findsNothing);
    });
  });

  group('操作性', () {
    testWidgets('「ひとつ前に戻す」ボタンは無い(行動は取り消せない)', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('act-special')));
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      expect(find.byKey(const Key('undo')), findsNothing);
      expect(find.byTooltip('ひとつ前に戻す'), findsNothing);
    });

    testWidgets('キーボード: Enterでおすすめ、Rで休養', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(c.recent, isNotEmpty);
      if (c.game!.phase == Phase.event) c.game!.resolveEvent(0);
      c.notifyListeners();
      await t.pumpAndSettle();
      final n = c.game!.log.length;
      await t.sendKeyEvent(LogicalKeyboardKey.keyR);
      await t.pumpAndSettle();
      expect(c.game!.log.length, greaterThan(n));
    });

    testWidgets('選手情報の「くわしいプロフィール」は、タップで開く', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('profile-card')), findsOneWidget);
      expect(find.byKey(const Key('profile-hometown')), findsNothing);
      await t.tap(find.byKey(const Key('profile-details')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('profile-hometown')), findsOneWidget);
      expect(find.byKey(const Key('profile-strengths')), findsOneWidget);
    });

    testWidgets('名前はおまかせで入れられ、Enterではじめられる', (t) async {
      final c = await _start(t);
      await t.tap(find.byKey(const Key('random-name')));
      await t.pumpAndSettle();
      final name = t
          .widget<TextField>(find.byKey(const Key('name-field')))
          .controller!
          .text;
      expect(name, isNotEmpty);
      await t.tap(find.byKey(const Key('name-field')));
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(c.game, isNotNull);
      expect(c.game!.player.name, name);
    });
  });

  group('下のタブ', () {
    testWidgets('育成・能力・キャリア・関係の4つ。関係タブに仲間が出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      for (final k in ['train', 'ability', 'career', 'relations']) {
        expect(find.byKey(Key('tab-$k')), findsOneWidget, reason: k);
      }
      expect(find.text('関係'), findsOneWidget);
      expect(find.byType(CastCard), findsNothing);
      await _tab(t, 'relations');
      expect(find.byType(CastCard), findsOneWidget);
      await _tab(t, 'career');
      expect(find.byType(CastCard), findsNothing);
    });

    testWidgets('手をつけられることがあるタブには、赤い点の印が付く', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mark-ability')), findsNothing);
      c.admin((g) => g.adminAddExp(5000));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mark-ability')), findsOneWidget);
      await _tab(t, 'ability');
      c.admin((g) => g.adminAddExp(-100000));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mark-ability')), findsNothing);
      // プロ8年目のFA権・海外移籍は、キャリアに印
      Game? g;
      for (var sd = 0; sd < 60 && g == null; sd++) {
        final x = _until((g) => g.canUseFa, seed: sd, potential: 100);
        if (x.canUseFa) g = x;
      }
      c.adopt(g!);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mark-career')), findsOneWidget);
    });
  });

  group('操作の手ごたえ(第3弾)', () {
    testWidgets('結果のトーストに「戻す」は付かない', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('act-special')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 1000));
      expect(find.byKey(const Key('toast-undo')), findsNothing);
      expect(find.text('戻す'), findsNothing);
    });

    testWidgets('経験点のチップをタップすると能力タブへ。最も低い能力に「伸ばしどころ」', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('exp-batting')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('buy-contact')), findsOneWidget);
      expect(find.textContaining('伸ばしどころ', findRichText: true), findsOneWidget);
      expect(find.textContaining('あと+', findRichText: true), findsWidgets);
    });

    testWidgets('疲れが高いと特訓・練習試合に危険の印。数字キーで行動できる', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('danger-special')), findsNothing);
      c.game!.condition = c.game!.condition.copyWith(fatigue: 80);
      c.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('danger-special')), findsOneWidget);
      expect(find.byKey(const Key('danger-match')), findsOneWidget);
      expect(find.byKey(const Key('danger-train')), findsNothing);
      c.game!.condition = c.game!.condition.copyWith(fatigue: 0);
      c.recent = []; // 生まれ持った才能の知らせは消しておく
      c.notifyListeners();
      await t.pumpAndSettle();
      expect(c.recent, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.digit3); // 休養
      await t.pumpAndSettle();
      expect(c.recent.first, contains('休養'));
    });
  });

  group('記録・殿堂まわり(第3弾)', () {
    testWidgets('成績表の行をタップすると、その年の詳しい成績が開く', (t) async {
      final c = await _start(t);
      c.adopt(_until((g) => g.records.length >= 3 && g.phase == Phase.term,
          seed: 5, potential: 90));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('records-open')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const Key('records-table')), 300,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('少年').first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('season-detail')), findsOneWidget);
      expect(find.textContaining('歳のシーズン'), findsOneWidget);
    });

    testWidgets('殿堂は評価順に並べ替えでき、長押しで消せる。ヒントは更新できる', (t) async {
      final c = await _start(t);
      final a = HistoryEntry.of(_until((g) => false, seed: 5, potential: 90));
      final b = HistoryEntry.of(_until((g) => false, seed: 6, potential: 40));
      c.history = [b, a];
      c.notifyListeners();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const Key('history-sort')), 300,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('評価順'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('history-sort')), findsOneWidget);
      await t.longPress(find.textContaining('―').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('history-delete-confirm')));
      await t.pumpAndSettle();
      expect(c.history.length, 1);
    });

    testWidgets('結婚して引退したら、そのまま二世で続けられる', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 400 && g == null; sd++) {
        final x = _until((g) => false, seed: sd, potential: 90);
        if (x.ending?.married ?? false) g = x;
      }
      expect(g, isNotNull);
      c.adopt(g!);
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      await t.scrollUntilVisible(find.byKey(const Key('continue-heir')), 300,
          scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const Key('continue-heir')));
      await t.pumpAndSettle();
      expect(c.game!.phase, isNot(Phase.retired));
      expect(c.game!.parentName, g.player.name);
    });

    testWidgets('育成中: キャリアに資産、関係にライバル。選手情報から選手カードをコピーできる', (t) async {
      final c = await _start(t);
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
      c.adopt(_until((g) => g.stage == Stage.pro && g.phase == Phase.term,
          seed: 5, potential: 100));
      await t.pumpAndSettle();
      await _tab(t, 'career');
      expect(find.byKey(const Key('money-card')), findsOneWidget);
      await _tab(t, 'relations');
      if (c.game!.cast.rival != null) {
        expect(find.byKey(const Key('rival-line')), findsOneWidget);
      }
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('copy-profile')));
      await t.pumpAndSettle();
      expect(copied, contains('総合評価'));
    });

    testWidgets('設定に「このアプリについて」。実績に進み具合のバーが出る', (t) async {
      final c = await _start(t);
      expect(c.game, isNull);
      expect(find.byKey(const Key('achievements-progress')), findsOneWidget);
      await t.tap(find.byKey(const Key('settings-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('about-open')));
      await t.pumpAndSettle();
      expect(find.text(appVersion), findsWidgets);
    });
  });

  group('状況の知らせ(第3弾)', () {
    testWidgets('高校の終わりごろはドラフトの見込み、疲れの警告、能力タブに総合評価', (t) async {
      final c = await _start(t);
      c.adopt(_until(
          (g) =>
              g.stage == Stage.highSchool &&
              g.player.age == 17 &&
              g.phase == Phase.term,
          seed: 5,
          potential: 90));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('draft-outlook')), findsOneWidget);
      expect(find.byKey(const Key('tired-note')), findsNothing);
      // 怪我中は別の表示になるので、怪我のない状態で疲れだけ上げる。
      c.game!.condition =
          c.game!.condition.copyWith(fatigue: 85, injuredTerms: 0);
      c.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('tired-note')), findsOneWidget);
      await _tab(t, 'ability');
      expect(find.byKey(const Key('overall-header')), findsOneWidget);
      expect(find.textContaining('総合評価'), findsWidgets);
    });

    testWidgets('怪我のあいだは復帰までの回数が出る。出来事には体力ややる気の目安が出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      c.game!.condition = c.game!.condition.copyWith(injuredTerms: 2);
      c.notifyListeners();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('injury-left')), findsOneWidget);
      expect(find.textContaining('あと2回で復帰'), findsOneWidget);
    });
  });

  group('設定の追加と広い画面(第3弾)', () {
    testWidgets('触覚・結果の知らせ・動きを減らすを切り替えられ、端末に覚えられる', (t) async {
      final c = await _start(t);
      await t.tap(find.byKey(const Key('settings-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('toasts-switch')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('haptics-switch')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('reduce-motion')));
      await t.pumpAndSettle();
      expect(c.toasts, isFalse);
      expect(c.haptics, isFalse);
      expect(c.reduceMotion, isTrue);
      final f = await SaveStore().loadFlags();
      expect((f.toasts, f.haptics, f.reduceMotion), (false, false, true));
      await t.tap(find.byKey(const Key('keys-open')));
      await t.pumpAndSettle();
      expect(find.textContaining('Enter'), findsOneWidget);
    });

    testWidgets('結果の知らせを切ると、トーストは出ない', (t) async {
      final c = await _start(t);
      c.setFlags(toasts: false);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('act-rest')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('result-toast')), findsNothing);
    });

    testWidgets('広い画面(幅1200)では、育成と能力が横に並ぶ', (t) async {
      final c = await _start(t);
      t.view.physicalSize = const Size(1200, 900);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('act-train')), findsOneWidget);
      expect(find.byKey(const Key('buy-contact')), findsOneWidget);
      await _tab(t, 'career');
      expect(find.byKey(const Key('act-train')), findsNothing);
    });
  });

  group('仕上げ(第3弾)', () {
    testWidgets('コーチのコツが貯まりきっていなければ、3回に1回は「教わる」がおすすめ', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      final g = c.game!;
      expect(g.cast.coach, isNotNull);
      g.slot = 2;
      expect(recommendedPlan(g), Plan.lesson);
      expect(recommendReason(g), contains('コツ'));
      g.slot = 0;
      expect(recommendedPlan(g), Plan.train);
      g.slot = 2;
      g.condition = g.condition.copyWith(fatigue: 90);
      expect(recommendedPlan(g), Plan.rest); // 疲れていれば休養が先
    });

    testWidgets('おすすめで年末まで進めると、経験点の合計が知らせに出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      for (var i = 0;
          i < 12 && !(c.recent.isNotEmpty && c.recent.first.contains('回進めた'));
          i++) {
        if (c.game!.phase == Phase.event) c.chooseEvent(0);
        c.autoYear();
      }
      await t.pumpAndSettle();
      expect(c.recent.first, contains('回進めた'));
      expect(c.recent.first, contains('経験点'));
    });

    testWidgets('能力タブの印に、振り分けられる能力の数が出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      c.admin((g) => g.adminAddExp(5000));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const Key('mark-ability')),
              matching: find.text('5')),
          findsOneWidget);
    });

    testWidgets('引退後の画面にベストシーズン。実績は解除済み・未解除で絞れる', (t) async {
      final c = await _start(t);
      c.adopt(_until((g) => false, seed: 5, potential: 90));
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      expect(find.byKey(const Key('best-season')), findsOneWidget);
    });

    testWidgets('育成中は設定から「はじめから」にできる。殿堂は残る', (t) async {
      final c = await _start(t);
      c.history = [
        HistoryEntry.of(_until((g) => false, seed: 5, potential: 90))
      ];
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('settings-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('restart-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('restart-confirm')));
      await t.pumpAndSettle();
      expect(c.game, isNull);
      expect(c.history.length, 1);
      expect(find.byKey(const Key('start')), findsOneWidget);
    });

    testWidgets('キャリアタブのログは「ぜんぶ見る」で一生ぶんを読める', (t) async {
      final c = await _start(t);
      c.adopt(
          _until((g) => g.player.age >= 10 && g.phase == Phase.term, seed: 5));
      await t.pumpAndSettle();
      await _tab(t, 'career');
      expect(find.byKey(const Key('log-card')), findsOneWidget);
      await t.tap(find.byKey(const Key('log-all')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('log-dialog')), findsOneWidget);
      expect(find.text('── 7歳 ──'), findsOneWidget);
    });

    testWidgets('投手の役割は、選手カードとくわしいプロフィールで同じ(先発/中継ぎ/抑え)', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.pitcher);
      await t.pumpAndSettle();
      final pos = positionOf(c.game!.player, c.game!.position);
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const Key('profile-card'))).data,
          contains(pos));
      expect(
          find.descendant(
              of: find.byKey(const Key('profile-details')),
              matching: find.textContaining(pos)),
          findsOneWidget);
    });

    testWidgets('進路を選ぶ画面では、今年の目標を出さない(まだ年が始まっていない)', (t) async {
      final c = await _start(t);
      c.adopt(
          _until((g) => g.phase == Phase.pathChoice, seed: 3, potential: 0));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('route-university')), findsOneWidget);
      expect(find.byKey(const Key('goal-row')), findsNothing);
    });

    testWidgets('年のはじめのお知らせは、キャリアでしか決められないものだけ(カードと重複しない)', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 60 && g == null; sd++) {
        final x = _until((g) => g.canUseFa, seed: sd, potential: 100);
        if (x.canUseFa) g = x;
      }
      c.adopt(g!);
      await t.pumpAndSettle();
      // プロの任意の決めごとは、たたまれて1枚。開くとカードが出る
      expect(find.byKey(const Key('pro-decisions')), findsOneWidget);
      expect(find.byKey(const Key('offseason-card')), findsNothing);
      await t.tap(find.byKey(const Key('pro-decisions')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('offseason-card')), findsOneWidget);
      expect(find.text('オフの過ごし方を選べる'), findsNothing); // カードが出ているので不要
      expect(find.textContaining('FA権あり'), findsOneWidget);
    });

    testWidgets('実績の絞りこみ', (t) async {
      final c = await _start(t);
      c.unlocked = {'first-pro'};
      await t.tap(find.byKey(const Key('achievements-open')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ach-first-pro')), findsOneWidget);
      await t.tap(find.text('未解除'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ach-first-pro')), findsNothing);
      await t.tap(find.text('解除済み'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ach-first-pro')), findsOneWidget);
    });

    testWidgets('経歴は種類で絞れ、成績の詳細は前後の年へ移れる', (t) async {
      final c = await _start(t);
      c.adopt(_until(
          (g) =>
              g.records.where((r) => r.stage == Stage.pro).length >= 2 &&
              g.phase == Phase.term,
          seed: 5,
          potential: 100));
      await t.pumpAndSettle();
      final pro = c.game!.records.where((r) => r.stage == Stage.pro).toList();
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tab-career')).last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('timeline-injury')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('timeline')), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('records-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('grade-${pro.last.age}')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('season-detail')), findsOneWidget);
      await t.tap(find.byKey(const Key('season-prev')));
      await t.pumpAndSettle();
      expect(
          find.text('${c.game!.records[c.game!.records.length - 2].age}歳のシーズン'),
          findsOneWidget);
    });
  });

  group('表示の設定とホームのカード', () {
    testWidgets('文字の大きさと画面の色を選べて、端末に覚えられる', (t) async {
      final c = await _start(t);
      expect(c.textScale, 1.0);
      await t.tap(find.byKey(const Key('settings-open')));
      await t.pumpAndSettle();
      await t.tap(find.descendant(
          of: find.byKey(const Key('text-scale')), matching: find.text('大')));
      await t.pumpAndSettle();
      expect(c.textScale, 1.2);
      await t.tap(find.descendant(
          of: find.byKey(const Key('theme-mode')), matching: find.text('暗い')));
      await t.pumpAndSettle();
      expect(c.themeMode, ThemeMode.dark);
      final saved = await SaveStore().loadDisplay();
      expect(saved.scale, 1.2);
      expect(saved.theme, ThemeMode.dark);
    });

    testWidgets('ホームに今日のヒントが出る。殿堂があれば通算と称号図鑑も出る', (t) async {
      final c = await _start(t);
      expect(find.byKey(const Key('daily-tip')), findsOneWidget);
      expect(find.byKey(const Key('life-stats')), findsNothing);
      c.history = [
        HistoryEntry.of(_until((g) => false, seed: 5, potential: 90)),
      ];
      c.notifyListeners();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const Key('title-book')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('life-stats')), findsOneWidget);
      expect(find.byKey(const Key('title-book')), findsOneWidget);
    });

    testWidgets('育成中は「今年の予定」が開ける。決められることはチップで出る', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter, Difficulty.normal, null);
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      await t.tap(find.byKey(const Key('year-plan')));
      await t.pumpAndSettle();
      expect(find.text('今年の予定'), findsWidgets);
      expect(find.textContaining('少年野球の大会'), findsOneWidget);
    });
  });

  group('FAの画面', () {
    testWidgets('プロ8年目以降は「FA権を使う」から移籍を決められる', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 60 && g == null; sd++) {
        final x = _until((g) => g.canUseFa, seed: sd, potential: 100);
        if (x.canUseFa) g = x;
      }
      expect(g, isNotNull);
      c.adopt(g!);
      await t.pumpAndSettle();
      await _tab(t, 'career');
      expect(find.byKey(const Key('fa-open')), findsOneWidget);
      await t.tap(find.byKey(const Key('fa-open')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fa-contender')));
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      expect(c.game!.faUsed, isTrue);
      expect(c.game!.teamBoost, 3);
      expect(find.byKey(const Key('fa-open')), findsNothing);
    });
  });

  group('海外移籍の画面', () {
    testWidgets('強いプロ選手は、年の最初にアメリカへ移籍でき、日本にも戻れる', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 60 && g == null; sd++) {
        final x = _until(
            (g) => g.stage == Stage.pro && g.player.age >= 24 && g.slot == 0,
            seed: sd,
            potential: 100);
        if (x.stage == Stage.pro && x.phase == Phase.term && x.slot == 0) g = x;
      }
      for (final a in g!.player.abilities.keys) {
        g.adminSetAbility(a, 80);
      }
      c.adopt(g);
      await t.pumpAndSettle();
      await _tab(t, 'career');
      expect(find.byKey(const Key('move-overseas')), findsOneWidget);
      await t.tap(find.byKey(const Key('move-overseas')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('overseas-confirm')));
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      expect(c.game!.overseas, isTrue);
      expect(find.textContaining(c.game!.overseasTeam!), findsWidgets);
      expect(find.byKey(const Key('move-overseas')), findsNothing);
      expect(find.byKey(const Key('return-home')), findsOneWidget);
      await t.tap(find.byKey(const Key('return-home')));
      await t.pumpAndSettle();
      expect(c.game!.overseas, isFalse);
    });
  });

  group('二世の画面', () {
    Game marriedLife() {
      for (var sd = 0; sd < 400; sd++) {
        final g = _until((g) => false, seed: sd, potential: 90);
        if (g.ending?.married ?? false) return g;
      }
      fail('結婚して引退した選手がいない');
    }

    testWidgets('殿堂に結婚した選手が居ると、二世として始められる', (t) async {
      SharedPreferences.setMockInitialValues({});
      final parent = marriedLife();
      await SaveStore().saveHistory([HistoryEntry.of(parent)]);
      final c = GameController(rng: Random(3));
      _tall(t);
      await t.pumpWidget(BaseballManagerApp(controller: c));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('heir-select')), findsOneWidget);
      await t.tap(find.byKey(const Key('heir-select')));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('の子').last);
      await t.pumpAndSettle();
      await t.tap(find.text('はじめる'));
      await t.pumpAndSettle();
      expect(c.game!.parentName, parent.player.name);
      // 選手情報に「○○の子(二世)」が出る
      await t.tap(find.byKey(const Key('player-open')).first);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('profile-parent')), findsOneWidget);
    });

    testWidgets('結婚した選手が居なければ、二世の選択は出ない', (t) async {
      final c = await _start(t);
      expect(c.history, isEmpty);
      expect(find.byKey(const Key('heir-select')), findsNothing);
    });
  });

  group('投資の画面', () {
    testWidgets('プロで資産があれば投資でき、買うと資産が減ってレベルが上がる', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 60 && g == null; sd++) {
        final x = _until((g) => g.stage == Stage.pro, seed: sd, potential: 100);
        if (x.stage == Stage.pro && x.phase == Phase.term) g = x;
      }
      g!.money = 10000;
      c.adopt(g);
      await t.pumpAndSettle();
      await _tab(t, 'career');
      await t.tap(find.byKey(const Key('invest-open')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('money')), findsOneWidget);
      await t.tap(find.byKey(const Key('invest-trainer')));
      await t.pumpAndSettle();
      expect(g.investLevel(Invest.trainer), 1);
      expect(g.money, 8000);
      expect(find.textContaining('Lv1/3'), findsOneWidget);
      // 資産が足りない投資は押せない(最大・足りない)
      g.money = 100;
      c.adopt(g);
      await t.pumpAndSettle();
      final btn =
          t.widget<FilledButton>(find.byKey(const Key('invest-medical')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('アマチュアには投資のボタンが出ない', (t) async {
      final c = await _start(t);
      c.newGame('テスト', Role.batter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('invest-open')), findsNothing);
    });
  });

  group('ペナントの画面', () {
    testWidgets('プロでは、月が進むごとに途中経過(勝敗・順位・今季の成績)が出る', (t) async {
      final c = await _start(t);
      Game? g;
      for (var sd = 0; sd < 60 && g == null; sd++) {
        final x = _until((g) => g.stage == Stage.pro && g.slot == 0,
            seed: sd, potential: 100);
        if (x.stage == Stage.pro && x.phase == Phase.term && x.slot == 0) g = x;
      }
      c.adopt(g!);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('pennant')), findsNothing); // 開幕前
      c.act(Plan.rest);
      await t.pumpAndSettle();
      await _dismissMilestones(t);
      if (c.game!.phase == Phase.event) {
        c.chooseEvent(0);
        await t.pumpAndSettle();
      }
      expect(find.byKey(const Key('pennant')), findsOneWidget);
      expect(find.textContaining('(20/143試合)'), findsOneWidget);
      expect(find.textContaining('暫定'), findsOneWidget);
    });
  });

  testWidgets('同梱の絵: ホームのタイトル絵と、プロを引退したときの絵が出る(読めなくても落ちない)', (t) async {
    final c = await _start(t);
    expect(find.byKey(const Key('home-hero')), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(t.takeException(), isNull, reason: '画像の読み込み');
    // プロを引退したエンディングに絵が出る
    final done = _until((g) => false, seed: 3, potential: 95);
    expect(done.ending!.madePro, isTrue);
    c.adopt(done);
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(find.byKey(const Key('retire-image')), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'エンディング');
  });

  test('結果のコピーに、特性(レアは★・覚醒の印)が入る', () {
    final g = _until((g) => false, seed: 3, potential: 95)
      ..adminSetTraits({Trait.hardWorker, Trait.monster})
      ..adminSetAwakened(true);
    final text = endingShareText(g);
    expect(text, contains('特性: '));
    expect(text, contains('★怪物'));
    expect(text, contains('努力家'));
    expect(text, contains('(覚醒)'));
    g.adminSetTraits({});
    expect(endingShareText(g), isNot(contains('特性: ')));
  });

  testWidgets('殿堂の一覧に、レア特性を持っていた選手の★が出る', (t) async {
    SharedPreferences.setMockInitialValues({});
    _tall(t);
    final rare = _until((g) => false, seed: 3, potential: 95)
      ..adminSetTraits({Trait.monster})
      ..adminSetSkills({Skill.averageHitter, Skill.geniusBat});
    final plain = _until((g) => false, seed: 4, potential: 95)
      ..adminSetTraits({Trait.hardWorker});
    await SaveStore()
        .saveHistory([HistoryEntry.of(rare), HistoryEntry.of(plain)]);
    final c = GameController(rng: Random(1));
    await t.pumpWidget(BaseballManagerApp(controller: c));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('★怪物'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('★怪物'), findsOneWidget);
    expect(find.textContaining('★努力家'), findsNothing);
    expect(find.textContaining('金特1'), findsOneWidget);
  });

  testWidgets('戦力外のトライアウト: 「受ける」「引退する」の選択が出て、引退を選ぶと終わる', (t) async {
    final c = await _start(t);
    final g = _until((g) => g.stage == Stage.pro, seed: 3, potential: 95)
      ..pendingEvent = tryoutEvent
      ..phase = Phase.event;
    c.adopt(g);
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(find.textContaining('戦力外通告を受けた'), findsWidgets);
    expect(find.text('トライアウトを受ける'), findsOneWidget);
    expect(find.text('現役を引退する'), findsOneWidget);
    await t.tap(find.byKey(const Key('event-1')));
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(c.game!.phase, Phase.retired);
    expect(t.takeException(), isNull);
  });

  testWidgets('決勝の見せ場: 見出しと3つの作戦が出て、選ぶと大会の結果が出る', (t) async {
    final c = await _start(t);
    Game? g;
    for (var sd = 0; sd < 60 && g == null; sd++) {
      final x = _until(
          (g) => g.phase == Phase.event && g.pendingEvent?.id == 'final-moment',
          seed: sd,
          potential: 100);
      if (x.phase == Phase.event) g = x;
    }
    expect(g, isNotNull);
    c.adopt(g!);
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(find.text('決勝の見せ場'), findsOneWidget);
    expect(find.textContaining('決勝、最終回'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('event-$i')), findsOneWidget);
    }
    expect(find.textContaining('パワー'), findsWidgets);
    final recs = g.records.length;
    await t.tap(find.byKey(const Key('event-1')));
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(c.game!.records.length, recs + 1);
    expect(c.game!.pendingFinal, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('引退後の道: プロを引退すると5つの道が出て、選ぶと物語が出る(殿堂にも残る)', (t) async {
    final c = await _start(t);
    Game? g;
    for (var sd = 0; sd < 40 && g == null; sd++) {
      final x = _until((g) => false, seed: sd, potential: 100);
      if (x.ending!.madePro) g = x;
    }
    expect(g, isNotNull);
    c.adopt(g!);
    c.autoSpend(); // 引退を殿堂に書き込む
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    await t.scrollUntilVisible(find.byKey(const Key('after-path')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('after-path')), findsOneWidget);
    for (final p in AfterPath.values) {
      expect(find.byKey(Key('after-${p.name}')), findsOneWidget);
    }
    expect(find.byKey(const Key('after-tier')), findsNothing);
    await t.ensureVisible(find.byKey(const Key('after-commentator')));
    await t.tap(find.byKey(const Key('after-commentator')));
    await t.pumpAndSettle();
    await _dismissMilestones(t);
    expect(c.game!.afterPath, AfterPath.commentator);
    expect(find.byKey(const Key('after-tier')), findsOneWidget);
    expect(find.byKey(const Key('after-line')), findsWidgets);
    // 殿堂の最新の記録にも、選んだ道が入る
    expect(c.history.first.snapshot!.afterPath, 'commentator');
    expect(c.unlocked, contains('second-career'));
    expect(t.takeException(), isNull);
  });

  testWidgets('継承ポイント: 引退で貯まり、図鑑にある特性を次の選手に持たせられる', (t) async {
    final c = await _start(t);
    expect(c.legacyPoints, 0);
    // 引退した一生(殿堂に書き込まれるとき)にポイントが入り、二重には入らない
    final done = _until((g) => false, seed: 3, potential: 95);
    expect(done.phase, Phase.retired);
    c.adopt(done);
    c.autoSpend();
    await t.pumpAndSettle();
    expect(c.lastLegacyGain, greaterThan(0));
    final pts = c.legacyPoints;
    expect(pts, c.lastLegacyGain);
    c.autoSpend();
    expect(c.legacyPoints, pts);
    // 保存され、新しいコントローラーでも残る
    final c2 = GameController(rng: Random(1));
    await c2.loadSaved();
    expect(c2.legacyPoints, pts);
    // 図鑑に無い特性は持たせられない
    c.legacyPoints = 10;
    c.seenTraits = {Trait.genius.name};
    expect(c.carryCandidates(Role.batter), [Trait.genius]);
    c.newGame('あ', Role.batter, Difficulty.normal, null, Trait.hardWorker);
    expect(c.game!.player.traits, isNot(contains(Trait.hardWorker)));
    expect(c.legacyPoints, 10);
    // 持たせられる特性は付き、ポイントを使う
    c.newGame('い', Role.batter, Difficulty.normal, null, Trait.genius);
    expect(c.game!.player.traits, contains(Trait.genius));
    expect(c.legacyPoints, 7);
    // ポイントが足りなければ持たせられない
    c.legacyPoints = 2;
    c.newGame('う', Role.batter, Difficulty.normal, null, Trait.genius);
    expect(c.legacyPoints, 2);
  });

  testWidgets('特性図鑑: 持った特性が載り、データを消すと空に戻る', (t) async {
    final c = await _start(t);
    expect(c.seenTraits, isEmpty);
    final g = Game.newGame(name: 'テスト', role: Role.batter, rng: Random(2))
      ..adminSetTraits({Trait.monster, Trait.hardWorker});
    c.adopt(g);
    c.autoSpend(); // 操作のあとで、持っている特性が図鑑に載る
    await t.pumpAndSettle();
    expect(c.seenTraits, {Trait.monster.name, Trait.hardWorker.name});
    // 図鑑の画面: 持った特性は名前が出て、持っていないものは「???」
    await t.pumpWidget(MaterialApp(home: TraitBookScreen(controller: c)));
    await t.pumpAndSettle();
    expect(find.text('発見した特性 2 / ${Trait.values.length}'), findsOneWidget);
    expect(find.text('怪物'), findsOneWidget);
    expect(find.text('???'), findsWidgets);
    // 未発見のレア特性には、手に入れ方のヒントが出る
    expect(find.textContaining('覚醒で手に入る'), findsWidgets);
    // 保存され、新しいコントローラーでも残る
    final c2 = GameController(rng: Random(1));
    await c2.loadSaved();
    expect(c2.seenTraits, {Trait.monster.name, Trait.hardWorker.name});
    // すべてのデータを消す
    await c.eraseAll();
    expect(c.seenTraits, isEmpty);
    final c3 = GameController(rng: Random(1));
    await c3.loadSaved();
    expect(c3.seenTraits, isEmpty);
  });
}
