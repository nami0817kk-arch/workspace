import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

Future<GameController> _pump(WidgetTester tester, {Size size = const Size(390, 844), Game? game}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77));
  ctl.game = game;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(QuadrillionApp(controller: ctl));
  await tester.pump();
  return ctl;
}

Game _midGame() {
  final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
  for (var i = 0; i < 150; i++) {
    botMonth(s);
  }
  resolveEvents(s);
  // 画面に出る項目を増やす
  s.deals.add(Deal(co: s.cos.firstWhere((c) => c.alive && c.parent != 'player').id, type: 'sales', since: s.year));
  s.kids.add(s.mkPerson(0)
    ..age = 25
    ..kid = true);
  s.biz.first.pipe.add(Pipe(k: 'enter', c: 'us', mode: 'solo', cost: 1e9, left: 3));
  s.biz.first.war = 3;
  s.biz.first.ad = 3;
  s.seen['fusion'] = 1;
  s.calcAll();
  return s;
}

void main() {
  testWidgets('はじめの画面から会社を立ち上げ、最初の事業を始めて月を進める', (tester) async {
    final ctl = await _pump(tester);
    expect(find.text('QUADRILLION'), findsOneWidget);
    // 特性が2つそろうまで始められない
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('会社を立ち上げる'), 300, scrollable: list);
    await tester.tap(find.text('会社を立ち上げる'));
    await tester.pump();
    expect(ctl.game, isNull);
    await tester.scrollUntilVisible(find.text('天才肌'), -300, scrollable: list);
    await tester.ensureVisible(find.text('天才肌'));
    await tester.pump();
    await tester.tap(find.text('天才肌'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('慎重'), 100, scrollable: list);
    await tester.ensureVisible(find.text('慎重'));
    await tester.pump();
    await tester.tap(find.text('慎重'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('会社を立ち上げる'), 300, scrollable: list);
    await tester.ensureVisible(find.text('会社を立ち上げる'));
    await tester.pump();
    expect(ctl.setup.traits, hasLength(2));
    await tester.tap(find.text('会社を立ち上げる'));
    await tester.pump();
    expect(ctl.game, isNotNull);
    expect(find.text('相棒を探しに行く'), findsOneWidget);
    await tester.tap(find.text('先に最初の事業を決める'));
    await tester.pump();
    expect(find.textContaining('創業'), findsWidgets);
    await tester.tap(find.textContaining('屋台（元手').first);
    await tester.pump();
    // 稼ぎ方を選ぶ小窓が出ることもある
    if (find.text('直営').evaluate().isNotEmpty) {
      await tester.tap(find.text('直営'));
      await tester.pump();
    }
    expect(ctl.game!.biz.length, 1);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(ctl.sheet, isNull);
    // 月を進める
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.textContaining('次の月へ'));
      await tester.pump();
      while (ctl.sheet != null) {
        final cont = find.text('続ける');
        final ok = find.text('OK');
        if (cont.evaluate().isNotEmpty) {
          await tester.tap(cont);
        } else if (ok.evaluate().isNotEmpty) {
          await tester.tap(ok);
        } else {
          // 出来事は最後の選択肢を選ぶ
          ctl.game!.events.clear();
          nextEvent(ctl);
        }
        await tester.pump();
      }
    }
    expect(ctl.game!.turn, 4);
    expect(tester.takeException(), isNull);
    // 保存されていて、読み込める
    expect(ctl.hasSave(), isTrue);
    final back = GameController(prefs: ctl.prefs);
    expect(back.load(), isTrue);
    expect(back.game!.turn, 4);
  });

  for (final w in [320.0, 390.0]) {
    testWidgets('6つのタブが幅${w.toInt()}で崩れない（途中のゲーム）', (tester) async {
      final ctl = await _pump(tester, size: Size(w, 9000), game: _midGame());
      for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
        ctl.setTab(t);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: t);
      }
      // 下のタブを押して切り替えられる
      // 1.1.0+41 から図鑑の見出しの帯にも「図鑑」が出るので、左の切り替えの中の字を押す
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('tab-zukan')), matching: find.text('図鑑')));
      await tester.pump();
      expect(ctl.tab, 'zukan');
      expect(find.textContaining('シナジー図鑑'), findsOneWidget);
    });
  }

  testWidgets('小窓（報告・出来事・遊び方・海外・稼ぎ方・業態・裏の手・売る・組む・分社・相棒・腕磨き）が崩れない', (tester) async {
    final ctl = await _pump(tester, size: const Size(360, 800), game: _midGame());
    final s = ctl.game!;
    final b = s.biz.first;
    final foe = s.cos.firstWhere((c) => c.rival != null && c.alive && c.parent != 'player');
    final sheets = <String, void Function()>{
      '遊び方': () => showHelp(ctl),
      '海外': () => openEnter(ctl, b),
      '稼ぎ方': () => openModel(ctl, 'konbini', b),
      '業態': () => openPivot(ctl, b),
      '裏の手': () => openDirty(ctl, foe),
      '売る': () => openSell(ctl),
      '組む': () => openDeal(ctl, foe),
      '分社': () => openShape(ctl, b),
      '創業': () => openStart(ctl),
      '相棒探し': () {
        s.ap = 3;
        openSeek(ctl);
      },
      'はじめ': () => openIntro(ctl),
    };
    for (final e in sheets.entries) {
      e.value();
      await tester.pump();
      expect(ctl.sheet, isNotNull, reason: e.key);
      expect(tester.takeException(), isNull, reason: e.key);
      ctl.closeSheet();
      await tester.pump();
    }
    // 出会い
    s.ap = 3;
    s.presAct('seek', 'meet');
    openMeet(ctl);
    await tester.pump();
    expect(find.textContaining('で出会った'), findsOneWidget);
    await tester.tap(find.text('今回は見送る'));
    await tester.pump();
    expect(s.meet, isNull);
    // 報告と出来事
    s.events.add(s.evPoach(foe, s.staff.isNotEmpty ? s.staff.first : (s.mkPerson(0)..name = '山田 太郎')));
    doYear(ctl, 3);
    await tester.pump();
    expect(find.text('続ける'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('続ける'));
    await tester.pump();
    await tester.tap(find.text('続ける'));
    await tester.pump();
    var guard = 0;
    while (ctl.sheet != null && guard++ < 20) {
      final ok = find.text('OK');
      final target = ok.evaluate().isNotEmpty ? ok : find.byType(ChoiceBtn).last;
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(ctl.sheet, isNull);
  });

  testWidgets('勝ち・負けの札と「はじめから」', (tester) async {
    final g = _midGame();
    g.won = 'テストで勝ちました';
    final ctl = await _pump(tester, game: g);
    // 全画面のまとめが上に出る
    Finder onEnd(String t) => find.descendant(of: find.byType(EndScreen), matching: find.text(t));
    expect(onEnd('達成！'), findsOneWidget);
    await tester.tap(onEnd('このまま続ける'));
    await tester.pump();
    expect(g.won, isNull);
    expect(g.mode, 'endless');
    expect(find.byType(EndScreen), findsNothing);
    g.over = 'テストで負けました';
    ctl.render();
    await tester.pump();
    expect(onEnd('ゲームオーバー'), findsOneWidget);
    expect(find.textContaining('次の月へ'), findsNothing);
    // まとめを閉じても、盤面の札から「はじめから」に戻れる
    await tester.tap(onEnd('盤面を見る'));
    await tester.pump();
    expect(find.byType(EndScreen), findsNothing);
    expect(find.text('ゲームオーバー'), findsOneWidget);
    await tester.tap(find.text('はじめから'));
    await tester.pump();
    expect(ctl.game, isNull);
    expect(find.text('QUADRILLION'), findsOneWidget);
  });
}
