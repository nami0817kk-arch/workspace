import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/tabs.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 1.0.0+6: 仕掛かりのまとめ・事業カードのたたみ・まとめて進めたときの止まった理由・押しやすさ

Future<GameController> _pump(WidgetTester tester, {Game? game, String lang = 'ja', Size size = const Size(390, 9000)}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
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
  s.calcAll();
  return s;
}

/// 事業を [n] つにそろえる（足りなければ始め、多ければ売る）
Game _withBiz(Game s, int n) {
  s.cash = 1e14;
  for (final i in s.liveInds()) {
    if (s.biz.length >= n) break;
    if (s.biz.any((b) => b.ind == i.id)) continue;
    s.ap = 5;
    s.startBiz(i.id);
  }
  while (s.biz.length > n) {
    s.biz.removeLast();
  }
  s.calcAll();
  return s;
}

Biz _top(Game s) => (s.biz.toList()..sort((a, b) => b.rev.compareTo(a.rev))).first;

/// 事業10・仕掛かり多数の場面
Game _bigGame() {
  final s = _withBiz(_midGame(), 10);
  final b = _top(s);
  b.pipe.clear();
  for (var i = 0; i < 7; i++) {
    b.pipe.add(Pipe(k: 'dev', cost: 5e8 + i * 1e8, left: 1 + i % 5));
  }
  b.pipe.add(Pipe(k: 'build', cost: 3e8, left: 2));
  b.pipe.add(Pipe(k: 'build', cost: 2e8, left: 1));
  b.pipe.add(Pipe(k: 'enter', c: 'us', mode: 'solo', cost: 1e9, left: 4));
  return s;
}

void main() {
  group('仕掛かりのまとめ', () {
    test('種類ごとに件数・合計・一番早いものをまとめる', () {
      final b = Biz(id: 1, ind: 'konbini', early: 0, model: 'direct', power: 1, crew: 1);
      b.pipe.addAll([
        Pipe(k: 'dev', cost: 1e8, left: 3),
        Pipe(k: 'build', cost: 2e8, left: 1),
        Pipe(k: 'dev', cost: 3e8, left: 1),
        Pipe(k: 'dev', cost: 5e7, left: 5),
      ]);
      final g = pipeGroups(b);
      expect(g.map((x) => x.k), ['dev', 'build']);
      expect(g[0].count, 3);
      expect(g[0].total, closeTo(4.5e8, 1));
      expect(g[0].soonest, 1);
      expect(g[0].idx, [2, 0, 3], reason: '早く終わる順');
      expect(g[1].count, 1);
      expect(g[1].total, 2e8);
      L.lang = 'ja';
      expect(pipeGroupText(g[0]), '3件・合計 ${yen(4.5e8)}・早いもので あと1か月');
      L.lang = 'en';
      expect(pipeGroupText(g[0]), '3 items | ${yen(4.5e8)} total | first done in 1 mo');
      L.lang = 'ja';
      expect(pipeGroups(Biz(id: 2, ind: 'konbini', early: 0, model: 'direct', power: 1, crew: 1)), isEmpty);
    });

    testWidgets('2件以上は1行にまとまり、押すと一覧が開いて1件ずつ取り下げられる', (tester) async {
      final s = _bigGame();
      final b = _top(s);
      final ctl = await _pump(tester, game: s);
      ctl.openBiz = b.id;
      ctl.setTab('biz');
      await tester.pump();
      // 開発中7件は1行、建設中2件も1行、進出準備1件は今までどおり
      expect(find.byKey(ValueKey('pipe-${b.id}-dev')), findsOneWidget);
      expect(find.byKey(ValueKey('pipe-${b.id}-build')), findsOneWidget);
      expect(find.byKey(ValueKey('pipe-${b.id}-enter')), findsNothing);
      expect(find.textContaining('7件・合計'), findsOneWidget);
      expect(find.text('取り下げる（半分戻る）'), findsOneWidget, reason: '1件だけの進出準備にはその場のボタン');
      await tester.tap(find.byKey(ValueKey('pipe-${b.id}-dev')));
      await tester.pump();
      expect(ctl.sheet, isNotNull);
      // 後ろの画面の1つ（進出準備）＋一覧の7つ
      expect(find.text('取り下げる（半分戻る）'), findsNWidgets(8));
      expect(find.textContaining('（7件）'), findsOneWidget);
      // 1件取り下げる → お金が半分戻り、一覧に戻ると6件
      final cash = s.cash;
      final first = b.pipe[pipeGroups(b).first.idx.first];
      await tester.tap(find.text('取り下げる（半分戻る）').at(1));
      await tester.pump();
      expect(s.cash, closeTo(cash + first.cost * .5, 1));
      expect(b.pipe.where((x) => x.k == 'dev').length, 6);
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(find.textContaining('（6件）'), findsOneWidget);
      // 5件まで減らし、残り1件になったら一覧ではなくその場の行に戻る
      while (b.pipe.where((x) => x.k == 'dev').length > 1) {
        await tester.tap(find.text('取り下げる（半分戻る）').at(1));
        await tester.pump();
        await tester.tap(find.text('OK'));
        await tester.pump();
      }
      ctl.closeSheet();
      await tester.pump();
      expect(find.byKey(ValueKey('pipe-${b.id}-dev')), findsNothing);
      expect(find.text('取り下げる（半分戻る）'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('事業カードのたたみ', () {
    testWidgets('3つ以上は1行にたたみ、押した1つだけ開く', (tester) async {
      final s = _bigGame();
      final ctl = await _pump(tester, game: s);
      ctl.setTab('biz');
      await tester.pump();
      for (final b in s.biz) {
        expect(find.byKey(ValueKey('biz-row-${b.id}')), findsOneWidget);
      }
      expect(find.text('値付け'), findsNothing, reason: 'たたんでいるので詳しいカードは無い');
      final a = s.biz[3], c = s.biz[5];
      await tester.tap(find.byKey(ValueKey('biz-row-${a.id}')));
      await tester.pump();
      expect(ctl.openBiz, a.id);
      expect(find.text('値付け'), findsOneWidget);
      expect(find.byKey(ValueKey('biz-row-${a.id}')), findsNothing);
      // 別の事業を押すと、前のは閉じる
      await tester.tap(find.byKey(ValueKey('biz-row-${c.id}')));
      await tester.pump();
      expect(ctl.openBiz, c.id);
      expect(find.text('値付け'), findsOneWidget);
      expect(find.byKey(ValueKey('biz-row-${a.id}')), findsOneWidget);
      // 名前の行を押すとたたむ
      await tester.tap(find.byKey(ValueKey('biz-fold-${c.id}')));
      await tester.pump();
      expect(ctl.openBiz, isNull);
      expect(find.text('値付け'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1行に業種名・稼ぎ方・シェア・売上・利益・注意の印が出る', (tester) async {
      final s = _bigGame();
      final b = s.biz[2];
      b.war = 3;
      b.crew = 0;
      final ctl = await _pump(tester, game: s);
      ctl.setTab('biz');
      await tester.pump();
      final row = find.byKey(ValueKey('biz-row-${b.id}'));
      Finder inRow(Finder f) => find.descendant(of: row, matching: f);
      expect(inRow(find.text(indm[b.ind]!.name)), findsOneWidget);
      expect(inRow(find.text(MODELN[b.model]!)), findsOneWidget);
      expect(inRow(find.text('値下げ合戦中')), findsOneWidget);
      if (b.model != 'fc') expect(inRow(find.text('人手不足')), findsOneWidget);
      final line = inRow(find.byType(RichText)).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).join('\n');
      expect(line, contains('シェア ${pct(b.share * 100)}'));
      expect(line, contains('売上 ${yen(b.rev)}'));
      expect(line, contains('利益 ${yen(b.profit)}'));
      // 沈む市場の印
      expect(bizWarnings(s, b), contains('値下げ合戦中'));
      final sinking = s.biz.where((x) => indm[x.ind]!.f != 0 && s.yr() > indm[x.ind]!.f);
      for (final x in sinking) {
        expect(bizWarnings(s, x), contains('沈む市場'));
      }
    });

    testWidgets('2つ以下は今のまま全部開く', (tester) async {
      final s = _withBiz(_midGame(), 2);
      final ctl = await _pump(tester, game: s);
      ctl.setTab('biz');
      await tester.pump();
      expect(find.text('値付け'), findsNWidgets(2));
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('biz-row-')), findsNothing);
    });

    testWidgets('英語でもたたんだ行と開いたカードに日本語が残らない', (tester) async {
      final s = _bigGame();
      final ctl = await _pump(tester, game: s, lang: 'en');
      ctl.openBiz = _top(s).id;
      ctl.setTab('biz');
      await tester.pump();
      final cjk = RegExp('[　-ヿ㐀-鿿＀-￯]');
      final texts = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).where(cjk.hasMatch).toList();
      expect(texts, isEmpty, reason: texts.take(5).join('\n'));
      await tester.tap(find.byKey(ValueKey('pipe-${_top(s).id}-dev')));
      await tester.pump();
      final t2 = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).where(cjk.hasMatch).toList();
      expect(t2, isEmpty, reason: t2.take(5).join('\n'));
    });
  });

  group('まとめて進めたときの止まった理由', () {
    for (final lang in ['ja', 'en']) {
      testWidgets('出来事で途中で止まると、報告の上に理由が出る（$lang）', (tester) async {
        final s = _midGame();
        final ctl = await _pump(tester, game: s, lang: lang);
        final foe = s.cos.firstWhere((c) => c.rival != null && c.alive && c.parent != 'player');
        s.events.add(s.evAlliance(foe));
        doYear(ctl, 12);
        await tester.pump();
        final box = find.byKey(const ValueKey('stop-reason'));
        expect(box, findsOneWidget);
        final text = (find.descendant(of: box, matching: find.byType(Text)).evaluate().first.widget as Text).data!;
        final title = tx(s.events.first.title);
        final when = ym(s.year, s.q);
        expect(text, lang == 'ja' ? '「$title」が起きたので、$whenで止めました' : '"$title" came up, so we stopped at $when.');
        if (lang == 'ja') expect(text, contains('提携の申し出'));
        if (lang == 'en') expect(RegExp('[　-ヿ㐀-鿿]').hasMatch(text), isFalse, reason: text);
      });
    }

    testWidgets('最後の月で起きたときや1か月だけのときは出さない', (tester) async {
      final s = _midGame();
      final ctl = await _pump(tester, game: s);
      final foe = s.cos.firstWhere((c) => c.rival != null && c.alive && c.parent != 'player');
      s.events.add(s.evAlliance(foe));
      doYear(ctl, 1);
      await tester.pump();
      expect(find.byKey(const ValueKey('stop-reason')), findsNothing);
      ctl.closeSheet();
      s.events.clear();
      s.events.add(s.evAlliance(foe));
      doNext(ctl);
      await tester.pump();
      expect(find.byKey(const ValueKey('stop-reason')), findsNothing);
    });

    test('勝ち・終わりの文（日英）', () {
      final s = _midGame();
      L.lang = 'ja';
      s.won = 'x';
      expect(stopReason(s), '目標を達成したので、${ym(s.year, s.q)}で止めました');
      s.over = 'y';
      expect(stopReason(s), 'ゲームが終わったので、${ym(s.year, s.q)}で止めました');
      L.lang = 'en';
      expect(stopReason(s), 'The game ended, so we stopped at ${ym(s.year, s.q)}.');
      s.over = null;
      expect(stopReason(s), 'You reached the goal, so we stopped at ${ym(s.year, s.q)}.');
      L.lang = 'ja';
    });
  });

  group('押しやすさ（44pt 以上）', () {
    /// 画面に出ている押せる部品の大きさを確かめる
    void checkTargets(WidgetTester tester, String where) {
      final bad = <String>[];
      void check(Finder f, String name, {bool width = true}) {
        for (final e in f.evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget).first);
          if (r.height < minTap - .01 || (width && r.width < minTap - .01)) bad.add('$name ${r.size}');
        }
      }

      check(find.byType(Btn), 'Btn');
      check(find.byType(DangerBtn), 'DangerBtn');
      check(find.descendant(of: find.byType(ChoiceBtn), matching: find.byType(InkWell)), 'ChoiceBtn');
      check(find.byType(Pick<String>), 'Pick', width: false);
      check(find.byType(Pick<int>), 'Pick', width: false);
      check(find.byType(IconButton), 'IconButton');
      check(find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey && RegExp(r'^(tab-|biz-|pipe-)').hasMatch('${(w.key as ValueKey).value}')),
          'InkWell');
      check(find.byKey(const ValueKey('settings-tap')), 'settings');
      expect(bad, isEmpty, reason: '$where: ${bad.take(8).join(', ')}');
    }

    for (final lang in ['ja', 'en']) {
      testWidgets('主な画面のボタンと選択の部品（$lang）', (tester) async {
        final s = _bigGame();
        final ctl = await _pump(tester, game: s, lang: lang);
        ctl.openBiz = _top(s).id;
        for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
          ctl.setTab(t);
          await tester.pump();
          checkTargets(tester, 'タブ $t');
          if (t == 'biz') {
            expect(find.byType(Btn), findsWidgets);
            expect(find.byType(Pick<int>), findsOneWidget, reason: '開いた1つの事業の責任者');
            expect(find.byType(Pick<String>), findsOneWidget, reason: '値付け（絞り込みは 1.0.0+13 から札）');
          }
        }
        for (final open in <void Function()>[
          () => openSettings(ctl),
          () => openPipes(ctl, _top(s), 'dev'),
          () => openEnter(ctl, _top(s)),
          () => confirmRestart(ctl),
          () => doYear(ctl, 3),
        ]) {
          open();
          await tester.pump();
          checkTargets(tester, '小窓');
          ctl.closeSheet();
          await tester.pump();
        }
        // はじめの画面
        ctl.game = null;
        ctl.render();
        await tester.pump();
        checkTargets(tester, 'はじめの画面');
        expect(find.byType(ChoiceBtn), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('見た目の外側の余白を押しても、ボタンが動く', (tester) async {
      var n = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: Btn('x', () => n++, small: true)))));
      final r = tester.getRect(find.byType(Btn));
      expect(r.height, greaterThanOrEqualTo(minTap));
      // 見た目（Material）の上端より上を押す
      final m = tester.getRect(find.descendant(of: find.byType(Btn), matching: find.byType(Material)));
      expect(m.height, lessThan(minTap), reason: '見た目の大きさは変えない');
      await tester.tapAt(Offset(r.center.dx, r.top + 2));
      await tester.pump();
      expect(n, 1);
      await tester.tapAt(r.center);
      await tester.pump();
      expect(n, 2);
    });
  });
}
