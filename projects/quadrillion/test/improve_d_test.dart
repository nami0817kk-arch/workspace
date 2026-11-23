import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';

import 'support/bot.dart';
import 'support/pilot.dart';
import 'support/shots.dart';

/// 1.0.0+16：字の大きさの設定・読み上げ（VoiceOver）・iPad と幅の広い画面。
/// 画面は「押して遊ぶ役」（test/support/pilot.dart）のひと回りで通す

String? _midJson;

/// 途中のゲーム（150か月。事業・部下・宿敵・子会社がそろっている）。作るのは1回だけで、テストごとに写しを渡す
Game _mid() {
  if (_midJson == null) {
    final s = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 150; i++) {
      botMonth(s);
    }
    resolveEvents(s);
    s.deals.add(Deal(co: s.cos.firstWhere((c) => c.alive && c.parent != 'player').id, type: 'sales', since: s.year));
    s.biz.first.pipe.add(Pipe(k: 'enter', c: 'us', mode: 'solo', cost: 1e9, left: 3));
    s.calcAll();
    _midJson = jsonEncode(s.toJson());
  }
  return Game.fromJson(jsonDecode(_midJson!) as Map<String, dynamic>, rng: ParkMiller(5))..calcAll();
}

void main() {
  group('字の大きさの設定', () {
    for (final c in const [(1.3, 390.0, 'ja'), (1.6, 390.0, 'en'), (1.6, 320.0, 'ja'), (1.3, 320.0, 'en')]) {
      testWidgets('文字を${c.$1}倍にしても、全部のタブと小窓がはみ出さない（幅${c.$2.toInt()}・${c.$3}）', (tester) async {
        final p = await Pilot.launch(tester, lang: c.$3, size: Size(c.$2, 780), textScale: c.$1, game: _mid());
        // 大きすぎる設定は上限（1.4倍）で抑える
        final scaler = MediaQuery.textScalerOf(tester.element(find.byType(MainScreen)));
        expect(scaler.scale(10), closeTo(10 * (c.$1 > Ui.maxTextScale ? Ui.maxTextScale : c.$1), 1e-6));
        await p.tour();
        for (var i = 0; i < 3; i++) {
          await p.next();
        }
        expect(p.found, isEmpty, reason: p.found.join('\n'));
        expect(p.seen['ひと回り'], 1);
      });
    }

    testWidgets('文字を1.6倍にしても、はじめの画面から最初の事業まで進められる（幅320）', (tester) async {
      final p = await Pilot.launch(tester, size: const Size(320, 640), textScale: 1.6);
      await p.start(year: 1980);
      for (var i = 0; i < 4; i++) {
        await p.month();
        await p.next();
      }
      expect(p.found, isEmpty, reason: p.found.join('\n'));
      expect(p.ctl.game!.turn, 4);
    });

    testWidgets('字が大きい設定では、決まった幅の欄（表の列・年月）がそのぶん広がる', (tester) async {
      final p = await Pilot.launch(tester, textScale: 1.3, game: _mid());
      expect(Ui.textScale, closeTo(1.3, 1e-9));
      expect(Ui.sw(84), closeTo(84 * 1.3, 1e-9));
      // 上の帯の年月・現金は1行のまま（折り返して2行にならない）
      await p.tab('num');
      await p.reveal(find.byKey(const ValueKey('rank-1')));
      final rank = tester.getSize(find.byKey(const ValueKey('rank-1')));
      expect(rank.height, lessThan(13 * 1.3 * 2 + 10), reason: 'ランキングの1行が2行に折れている');
      expect(tester.takeException(), isNull);
    });
  });

  group('iPad と幅の広い画面', () {
    for (final c in const [(768.0, 1024.0, 'ja'), (1024.0, 768.0, 'en')]) {
      testWidgets('幅${c.$1.toInt()}×${c.$2.toInt()}：中身は最大720の幅で中央、小窓は最大620（${c.$3}）', (tester) async {
        final p = await Pilot.launch(tester, lang: c.$3, size: Size(c.$1, c.$2), game: _mid());
        final w = c.$1;
        final left = (w - Ui.maxBody) / 2;
        // カード：幅は 720 から左右の余白 12 ずつを引いた 696、中心は画面の真ん中
        final card = tester.getRect(find.byKey(const ValueKey('town-picture')));
        expect(card.width, closeTo(Ui.maxBody - 24, .01));
        expect(card.center.dx, closeTo(w / 2, .01));
        // 上の帯・下のボタン・タブも同じ幅の中に収まる
        expect(tester.getRect(find.byKey(const ValueKey('pres-name'))).left, closeTo(left + 12, .01));
        expect(tester.getRect(find.byKey(const ValueKey('settings'))).right, lessThanOrEqualTo(w - left - 12 + .01));
        expect(tester.getRect(find.byKey(const ValueKey('advance-menu'))).left, greaterThanOrEqualTo(left + 12 - .01));
        expect(tester.getRect(find.byKey(const ValueKey('tab-town'))).left, greaterThanOrEqualTo(left - .01));
        expect(tester.getRect(find.byKey(const ValueKey('tab-zukan'))).right, lessThanOrEqualTo(w - left + .01));
        // 一覧は左右の余白の上でも動かせる（端から端まで一覧のまま）
        expect(tester.getSize(find.byKey(const PageStorageKey('tab-town'))).width, w);
        // 小窓
        showHelp(p.ctl);
        await tester.pump();
        final sheet = tester.getRect(find.byKey(const ValueKey('sheet-card')));
        expect(sheet.width, closeTo(Ui.maxSheet, .01));
        expect(sheet.center.dx, closeTo(w / 2, .01));
        await p.drain();
        await p.tour();
        for (var i = 0; i < 3; i++) {
          await p.next();
        }
        expect(p.found, isEmpty, reason: p.found.join('\n'));
      });
    }

    testWidgets('幅の広い画面のはじめの画面と終わりの画面も、最大720の幅で中央', (tester) async {
      final p = await Pilot.launch(tester, size: const Size(1024, 768));
      final title = tester.getRect(find.text('QUADRILLION'));
      expect(title.left, closeTo((1024 - Ui.maxBody) / 2 + 12, .01));
      await p.start(year: 2000);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
      final s = p.ctl.game!;
      s.over = M('資金が尽きました');
      p.ctl.render();
      await tester.pump();
      final end = tester.getRect(find.text(tr('ゲームオーバー')).last);
      expect(end.left, closeTo((1024 - Ui.maxBody) / 2 + 16, .01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('幅の狭い画面（iPhone）は今までどおり端から端まで', (tester) async {
      await Pilot.launch(tester, game: _mid());
      final card = tester.getRect(find.byKey(const ValueKey('town-company')));
      expect(card.left, 12);
      expect(card.width, 390 - 24);
      expect(Ui.sideGap(390), 0);
      expect(Ui.sideGap(700), 0);
      expect(Ui.sideGap(1024), (1024 - 720) / 2);
    });
  });

  group('読み上げ（VoiceOver）', () {
    for (final lang in const ['ja', 'en']) {
      testWidgets('アイコンだけのボタン・手の四角・棒・グラフに名前があり、読み上げから押せる（$lang）', (tester) async {
        final h = tester.ensureSemantics();
        final p = await Pilot.launch(tester, lang: lang, size: const Size(390, 3000), game: _mid());
        final ctl = p.ctl;
        final s = ctl.game!;
        SemanticsNode node(Finder f) => tester.getSemantics(f);
        // 読み上げ（VoiceOver）から押す
        void semTap(Pattern label) => tester.semantics.tap(find.semantics.byLabel(label).first);

        // ？（遊び方）と歯車（設定）：名前があり、ボタンで、読み上げから押すと開く
        final help = find.bySemanticsLabel(tr('遊び方'));
        expect(help, findsOneWidget);
        expect(node(help), isSemantics(isButton: true, hasTapAction: true));
        semTap(tr('遊び方'));
        await tester.pump();
        expect(ctl.sheet, isNotNull, reason: '読み上げから「遊び方」が開かない');
        await p.drain();
        final gear = find.bySemanticsLabel(tr('設定'));
        expect(node(gear), isSemantics(isButton: true, hasTapAction: true));
        semTap(tr('設定'));
        await tester.pump();
        expect(ctl.sheet, isNotNull);
        await p.drain();

        // 手の四角：残りの数を言葉で
        expect(find.bySemanticsLabel(tr('手 残り{0}／{1}', [s.ap, s.apMax])), findsOneWidget);

        // 用語の「i」：名前があり、読み上げから押せる（前は押す動きが読み上げに渡っていなかった）
        final infoLabel = RegExp('^${RegExp.escape(tr('用語の説明：{0}', ['']))}');
        final info = find.bySemanticsLabel(infoLabel);
        expect(info, findsWidgets);
        expect(node(info.first), isSemantics(isButton: true, hasTapAction: true));
        semTap(infoLabel);
        await tester.pump();
        expect(ctl.sheet, isNotNull, reason: '読み上げから用語の説明が開かない');
        await p.drain();

        // 飾りの丸（名前の1文字目）は読み上げない
        final rv = s.cos.firstWhere((c) => c.rival != null && c.alive);
        final initial = nmL(rv.presName).replaceAll(RegExp(r'\s'), '').characters.first;
        expect(find.bySemanticsLabel(initial), findsNothing);
        expect(find.text(initial), findsWidgets);

        // たたんだ行と開いたカードの名前の行：ボタンとして読む
        final row = find.byKey(ValueKey('rival-row-${rv.id}'));
        expect(node(row), isSemantics(isButton: true, hasTapAction: true));

        // 選ぶ札（並べ替え）：読み上げから押せる
        ctl.setTab('biz');
        await tester.pump();
        final chip = find.bySemanticsLabel(tr('市場の大きい順'));
        expect(node(chip), isSemantics(isButton: true, hasTapAction: true, isSelected: false));
        semTap(tr('市場の大きい順'));
        await tester.pump();
        expect(ctl.bizSort, 'market');
        // シェアの棒：割合を言葉で
        final b = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
        ctl.toggleBiz(b.id);
        await tester.pump();
        // （カードの中の字は1つにまとめて読まれるので、その中に入っていることを見る）
        expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(tr('シェア {0}', [pct(b.share * 100)]))}\$', multiLine: true)), findsWidgets);
        // ふつうのボタンは「ボタン」と読み、手が足りないときも押せる（押すと理由を出す）
        final grow = find.descendant(of: find.byKey(ValueKey('grp-grow-${b.id}')), matching: find.byType(InkWell)).first;
        expect(node(grow), isSemantics(isButton: true, hasTapAction: true));

        // 株主の棒：誰が何%かを言葉で
        ctl.setTab('stock');
        await tester.pump();
        final owners = node(find.byKey(const ValueKey('sem-owners'))).label;
        expect(owners, contains('${tr('あなた')} ${pct(s.sh.own)}'));
        // 棒に重ねた節目の小さな字（33.4%・50%・66.7%）は、棒の読み上げには入れない
        expect(owners.split('\n'), isNot(contains('66.7%')), reason: '節目の小さな字まで読んでいる');

        // グラフ：見出しと、はじめと今の値
        ctl.setTab('num');
        await tester.pump();
        final cap = node(find.byKey(const ValueKey('sem-cap-graph'))).label;
        expect(cap, contains(tr('時価総額の推移')));
        expect(cap, contains(yen(s.hist.last.cap)));
        final rev = node(find.byKey(const ValueKey('sem-rev-graph'))).label;
        expect(rev, contains(yen(s.hist.last.rev)));
        if (lang == 'en') {
          for (final l in [cap, rev, owners]) {
            expect(RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uff00-\uffef、。]').hasMatch(l), isFalse, reason: l);
          }
        }

        // 図鑑の切り替えと下のタブ：選んでいるものが分かる
        ctl.setTab('zukan');
        await tester.pump();
        expect(node(find.byKey(const ValueKey('zukan-syn'))), isSemantics(isButton: true, isSelected: true));
        expect(node(find.byKey(const ValueKey('tab-zukan'))), isSemantics(isButton: true, isSelected: true, hasTapAction: true));
        expect(tester.takeException(), isNull);
        h.dispose();
      });
    }

    testWidgets('選ぶボタンは、選んでいるか・押せないかが読み上げに伝わる', (tester) async {
      final h = tester.ensureSemantics();
      await Pilot.launch(tester, size: const Size(390, 3000));
      SemanticsNode node(Finder f) => tester.getSemantics(f);
      // はじめの画面：選んでいるモードは「選択中」
      final on = find.ancestor(of: find.text(tr('世界一位')), matching: find.byType(InkWell)).first;
      expect(node(on), isSemantics(isButton: true, isSelected: true, hasTapAction: true));
      final off = find.ancestor(of: find.text(tr('終わりなし')), matching: find.byType(InkWell)).first;
      expect(node(off), isSemantics(isButton: true, isSelected: false, hasTapAction: true));
      // 特性を2つ選ぶまで「会社を立ち上げる」は使えない
      final go = find.ancestor(of: find.text(tr('会社を立ち上げる')), matching: find.byType(InkWell)).first;
      expect(node(go), isSemantics(isButton: true, isEnabled: false, hasEnabledState: true));
      h.dispose();
    });
  });

  group('通しの点検で見つけて直したもの', () {
    testWidgets('割合の棒は、合計が100%を超えてもはみ出さない（株主の割合は100からずれることがある）', (tester) async {
      await tester.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 200, child: Bar([(45, Pal.gold), (40, Pal.teal), (35, Pal.down)], height: 14)))));
      expect(tester.takeException(), isNull);
      final parts = tester.widgetList<Container>(find.descendant(of: find.byType(Row), matching: find.byType(Container))).toList();
      expect(parts, hasLength(3));
      final widths = [for (final e in find.descendant(of: find.byType(Row), matching: find.byType(Container)).evaluate()) e.size!.width];
      expect(widths.reduce((a, b) => a + b), closeTo(200, .01));
      // 比はそのまま（45:40:35）
      expect(widths[0] / widths[2], closeTo(45 / 35, .001));
    });

    testWidgets('割合の棒は、合計が100%以下ならそのままの長さ', (tester) async {
      await tester.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr, child: Center(child: SizedBox(width: 200, child: Bar([(25, Pal.gold), (50, Pal.teal)], height: 14)))));
      final widths = [for (final e in find.descendant(of: find.byType(Row), matching: find.byType(Container)).evaluate()) e.size!.width];
      expect(widths, [50, 100]);
    });

    testWidgets('説明とボタンの行は、幅が足りないとボタンを下の行に回す（説明が1字ずつ縦に折れない）', (tester) async {
      Future<(Rect, Rect)> at(double w) async {
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: w,
                        child: TextBtnRow(
                            text: Text('Major development (¥199M), 9 mo left', key: const ValueKey('t'), style: ts(size: 12.5)),
                            btn: Btn('Cancel (50% back)', () {}, key: const ValueKey('b'), small: true)))))));
        expect(tester.takeException(), isNull);
        return (tester.getRect(find.byKey(const ValueKey('t'))), tester.getRect(find.byKey(const ValueKey('b'))));
      }

      final wide = await at(700);
      expect(wide.$2.left, greaterThanOrEqualTo(wide.$1.right - .01), reason: '広いときは横に並ぶ');
      final narrow = await at(264);
      expect(narrow.$2.top, greaterThanOrEqualTo(narrow.$1.bottom - .01), reason: '狭いときはボタンが下');
      expect(narrow.$1.width, greaterThan(200), reason: '説明が細く押しつぶされている');
    });

    testWidgets('街の会社のカード：英語の長い事務所の札でも、段階と拠点の文が押しつぶされない（幅320）', (tester) async {
      final g = Game.newGame(SetupConfig(mode: 'world', year: 2000, traits: ['genius', 'gambler'], home: 'us'), rng: ParkMiller(23));
      g.startBiz(g.liveInds().where((i) => g.capexOf(i) <= g.cash).first.id);
      // 雑居ビルの1フロア（英語では長い札になる）
      g.rev = 2e7;
      final p = await Pilot.launch(tester, lang: 'en', size: const Size(320, 3000), game: g);
      expect(tester.takeException(), isNull);
      final stage = tester.getRect(find.byKey(const ValueKey('town-stage')));
      final office = tester.getRect(find.byKey(const ValueKey('town-office')));
      expect(find.text(tx(g.officeName())), findsOneWidget);
      // 文は欄の幅をほぼ使えていて、札は文の下の行にある
      expect(stage.width, greaterThan(200));
      expect(office.top, greaterThanOrEqualTo(stage.bottom - .01));
      expect(office.right, lessThanOrEqualTo(320 - 12 - Ui.pad + .01));
      // 1か国のときに「1 countries」と書かない
      expect(p.texts().where((x) => x.contains('1 countries')), isEmpty);
      expect(p.texts().where((x) => x.contains('Countries: 1')), hasLength(1));
    });

    testWidgets('社長の行動の見出し：幅320・英語・字1.3倍でも「i」が押せる所にある', (tester) async {
      final p = await Pilot.launch(tester, lang: 'en', size: const Size(320, 3000), textScale: 1.3, game: _mid());
      expect(tester.takeException(), isNull);
      final info = find.descendant(of: find.byKey(const ValueKey('town-pres')), matching: find.byKey(const ValueKey('info-ap')));
      expect(tester.getRect(info).right, lessThanOrEqualTo(320 - 12 + .01));
      await p.press(info, '用語（手）');
      expect(p.ctl.sheet, isNotNull);
      expect(p.found, isEmpty, reason: p.found.join('\n'));
    });

    testWidgets('「次の月へ」は、幅が足りないときは残りの手の数を省く（字を豆粒にしない）', (tester) async {
      String label() => (tester.widget(find.byKey(const ValueKey('next'))) as Btn).label;
      final g = _mid();
      await Pilot.launch(tester, game: g);
      expect(label(), tr('次の月へ（手が{0}残っています）', [g.ap]));
      await Pilot.launch(tester, game: g, textScale: 1.6);
      expect(label(), tr('次の月へ'));
      await Pilot.launch(tester, game: g, size: const Size(320, 640), textScale: 1.3);
      expect(label(), tr('次の月へ'));
      // 幅の広い画面は、字が大きくても入る
      await Pilot.launch(tester, game: g, size: const Size(768, 1024), textScale: 1.6);
      expect(label(), tr('次の月へ（手が{0}残っています）', [g.ap]));
    });

    test('英語の文：まとめて進めた報告と、新商品の知らせ', () {
      L.lang = 'en';
      addTearDown(() => L.lang = 'ja');
      // 前は「Advanced from Since Jul 1992」になっていた
      expect(tr('{0}まとめて進めました', [tr('{0}から', [ym(1992, 7, sp: true)])]), 'Skipped ahead from Jul 1992');
      // 前は「Clinics's new product flopped」になっていた（業種名は複数形が多い）
      expect(tx(M('「{0}」の新商品は不発に終わりました', [I('clinic')])), isNot(contains("s's")));
      expect(tx(M('大当たり！「{0}」の新商品が爆発的に売れています', [I('clinic')])), isNot(contains("s's")));
      // 1か月のときに「1 months」と書かない（月は「mo」で書く）
      final g = Game.newGame(SetupConfig(year: 1980, traits: ['charm', 'careful']), rng: ParkMiller(3));
      g.startBiz(g.liveInds().where((i) => g.capexOf(i) <= g.cash).first.id);
      g.cash = 1e12;
      final texts = <String>[];
      for (var i = 0; i < 12; i++) {
        g.ap = g.apMax;
        texts.add(tx(g.buildN(g.biz.first, 1)));
        g.ap = g.apMax;
        texts.add(tx(g.developN(g.biz.first, 0)));
      }
      expect(texts.where((x) => RegExp(r'\b1 months\b').hasMatch(x)), isEmpty);
      expect(texts.where((x) => x.contains(' mo')), isNotEmpty);
    });
  });

  // 目で見る確認（QUAD_SHOTS にフォルダを渡したときだけ。画像はコミットしない）
  //   QUAD_SHOTS=C:/somewhere flutter test test/improve_d_test.dart --plain-name 書き出し
  testWidgets('画面の書き出し（字の大きさ・iPad）', (tester) async {
    await loadRealFonts();
    Future<void> run(String name, {required Size size, double scale = 1, String lang = 'ja'}) async {
      final key = GlobalKey();
      final p = await Pilot.launch(tester, lang: lang, size: size, textScale: scale, game: _mid(), boundary: key);
      final ctl = p.ctl;
      final s = ctl.game!;
      for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
        ctl.setTab(t);
        await tester.pump();
        await shot(tester, key, '${name}_$t', pixelRatio: 1.5);
      }
      ctl.setTab('biz');
      final b = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
      ctl.openBiz = b.id;
      await tester.pump();
      await shot(tester, key, '${name}_biz_open', pixelRatio: 1.5);
      ctl.setTab('num');
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pump();
      await shot(tester, key, '${name}_num_rank', pixelRatio: 1.5);
      ctl.setTab('town');
      doYear(ctl, 3);
      await tester.pump();
      await shot(tester, key, '${name}_report', pixelRatio: 1.5);
      ctl.closeSheet();
      s.events.clear();
      openBuild(ctl, b);
      await tester.pump();
      await shot(tester, key, '${name}_build', pixelRatio: 1.5);
      ctl.closeSheet();
      await tester.pump();
      // 次の書き出しのために片付ける
      await tester.pumpWidget(const SizedBox());
    }

    await run('s13_ja', size: const Size(390, 844), scale: 1.3);
    await run('s16_ja', size: const Size(390, 844), scale: 1.6);
    await run('s16_en', size: const Size(390, 844), scale: 1.6, lang: 'en');
    await run('s16_w320_ja', size: const Size(320, 640), scale: 1.6);
    await run('ipad_p_ja', size: const Size(768, 1024));
    await run('ipad_l_en', size: const Size(1024, 768), lang: 'en');
    await run('ipad_l_s16_ja', size: const Size(1024, 768), scale: 1.6);
    expect(tester.takeException(), isNull);
  }, skip: shotDir == null);
}
