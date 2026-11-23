import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';

/// 目で見て確かめるための画面の書き出し。本物のフォントで幅390の縦画面を PNG にする。
/// QUAD_SHOTS に書き出し先のフォルダを渡したときだけ動く（画像はコミットしない）。
///   QUAD_SHOTS=C:/somewhere flutter test test/screens_test.dart
final _out = Platform.environment['QUAD_SHOTS'];

Future<void> _loadFonts() async {
  final jp = FontLoader(fontFamily);
  for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
    final b = File(f).readAsBytesSync();
    jp.addFont(Future.value(ByteData.sublistView(b)));
  }
  await jp.load();
  // アイコン（×・＞）も本物で描く
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final im = await ro.toImage(pixelRatio: 2);
    final bd = await im.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('画面の書き出し（幅390）', (tester) async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77))
      ..setup = SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']);
    ctl.startNew();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
    await tester.pump();
    await _shot(tester, key, '1_town_guide');

    // 最初の事業を始めると、案内が次の段に進む
    final s = ctl.game!;
    final ind = s.liveInds().where((i) => s.capexOf(i) <= s.cash).first;
    ctl.act(() => s.startBiz(ind.id));
    await tester.pump();
    await _shot(tester, key, '2_town_guide_next');

    // 月を進めた直後（数字が光っている途中）
    doNext(ctl);
    ctl.closeSheet();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await _shot(tester, key, '3_flash');
    await tester.pumpAndSettle();

    // 途中のゲームで宿敵の色が出る画面（事業・株）
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
    for (var i = 0; i < 150; i++) {
      botMonth(g);
    }
    resolveEvents(g);
    g.calcAll();
    ctl.game = g;
    ctl.setTab('biz');
    await tester.pump();
    await _shot(tester, key, '4_biz_rivals');
    ctl.setTab('town');
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pump();
    await _shot(tester, key, '5_town_rivals');

    // 数字タブの下の社史
    for (var i = 0; i < 120; i++) {
      botMonth(g);
    }
    resolveEvents(g);
    g.calcAll();
    ctl.setTab('num');
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pump();
    await _shot(tester, key, '6a_num_graphs');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pump();
    await _shot(tester, key, '6_num_history');
    ctl.setTab('town');
    await tester.pump();
    await _shot(tester, key, '6b_town_advice');

    // 設定と、取り返しのつかない操作の確認
    openSettings(ctl);
    await tester.pump();
    await _shot(tester, key, '7_settings');
    final b = g.biz.first;
    actConfirmed(ctl, '「${indm[b.ind]!.name}」を売る', '「${indm[b.ind]!.name}」を約${yen(g.sellValue(b))}で手放します。育てた力は戻りません。', '売る', () => null);
    await tester.pump();
    await _shot(tester, key, '8_confirm');
    ctl.closeSheet();

    // 終わったときのまとめ（勝ち・負け）
    g.won = '${g.year}年、世界の企業ランキングで1位になりました';
    g.chron('rank', '世界の企業ランキングで1位になった');
    ctl.render();
    await tester.pump();
    await _shot(tester, key, '9_end_win');
    g.won = null;
    g.over = '宿敵に株の過半数を握られ、社長の座を追われました';
    ctl.render();
    await tester.pump();
    await _shot(tester, key, '10_end_over');

    // はじめの画面（続きからの一覧・難しさ・保存する枠）
    ctl.save();
    ctl.game = null;
    ctl.sheet = null;
    ctl.render();
    await tester.pump();
    await _shot(tester, key, '11_setup_slots');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pump();
    await _shot(tester, key, '12_setup_diff');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pump();
    await _shot(tester, key, '13_setup_bottom');
    expect(tester.takeException(), isNull);
  }, skip: _out == null);

  // 「事業」タブの新しい事業の一覧（200業種）と図鑑の数（日英）
  for (final lang in ['ja', 'en']) {
    testWidgets('新しい事業の一覧と図鑑の書き出し（$lang・幅390）', (tester) async {
      await _loadFonts();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
      addTearDown(() => L.lang = 'ja');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final g = Game.newGame(SetupConfig(mode: 'world', year: 2000, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 120; i++) {
        botMonth(g);
      }
      resolveEvents(g);
      g.calcAll();
      ctl.game = g;
      ctl.bizFilter = 'all';
      ctl.setTab('biz');
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
      await tester.pump();
      await tester.scrollUntilVisible(find.text(tr('新しい事業')), 300, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
      await tester.pump();
      await _shot(tester, key, 'n1_newbiz_$lang');
      for (var k = 2; k <= 4; k++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pump();
        await _shot(tester, key, 'n${k}_newbiz_$lang');
      }
      ctl.setTab('zukan');
      await tester.pump();
      expect(find.textContaining('${g.found.length} / ${SYN.length}'), findsOneWidget);
      await _shot(tester, key, 'n5_zukan_$lang');
      expect(tester.takeException(), isNull);
    }, skip: _out == null);
  }

  // 宿敵の物語と取締役会の場面（日英）
  for (final lang in ['ja', 'en']) {
    testWidgets('物語と取締役会の場面の書き出し（$lang・幅390）', (tester) async {
      await _loadFonts();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
      addTearDown(() => L.lang = 'ja');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 150; i++) {
        botMonth(g);
      }
      resolveEvents(g);
      g.calcAll();
      ctl.game = g;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
      await tester.pump();
      final rv = g.cos.where((c) => c.alive && c.rival != null && c.parent != 'player').toList();
      // 出会い
      final a = rv.firstWhere((c) => c.rival!.kind == 'peer', orElse: () => rv.first);
      a.rival!
        ..st = 0
        ..ties.clear();
      a.biz.add(CoBiz(ind: g.biz.first.ind, power: 1e6));
      g.events.clear();
      g.storyMonthly((m, [t = '']) {});
      g.events.removeWhere((e) => e.who != a);
      nextEvent(ctl);
      await tester.pump();
      await _shot(tester, key, 's1_meet_$lang');
      // 因縁が深まる → 決着（組んだ）
      for (final k in ['g', 'h', 'g']) {
        g.tieRec(a, k, k == 'g' ? M('「{0}」で値下げ合戦を仕掛けた', [I(g.biz.first.ind)]) : M('部下の{0}を引き抜かれかけた', [Nm(g.staff.isNotEmpty ? g.staff.first.name : '佐藤 健一')]));
      }
      g.events.clear();
      g.storyMonthly((m, [t = '']) {});
      g.events.removeWhere((e) => e.who != a);
      nextEvent(ctl);
      await tester.pump();
      await _shot(tester, key, 's2_clash_$lang');
      final b = rv.firstWhere((c) => c != a);
      b.rival!.st = 1;
      g.events.clear();
      g.storyEnd(b, 'ally');
      nextEvent(ctl);
      await tester.pump();
      await _shot(tester, key, 's3_end_ally_$lang');
      // 取締役会の解任動議
      g.sh = Shares(own: 32, pt: 6, float: 50, riv: {b.id: 12});
      g.listed = true;
      g.yPrev = {'rev': g.rev * 12 * 1.1, 'pre': g.pre.abs() * 12 * 2, 'cap': g.cap * 1.2, 'rank': g.rank + 3.0};
      g.yAcc = {'rev': g.rev * 11, 'pre': g.pre.abs() * 11, 'n': 11};
      g.events.clear();
      g.holdBoard();
      final motion = g.events.first;
      nextEvent(ctl);
      await tester.pump();
      await _shot(tester, key, 's4_board_motion_$lang');
      // 約束したあとの街（約束と、宿敵の欄の因縁）
      motion.choices[0].f();
      g.events.clear();
      ctl.closeSheet();
      ctl.setTab('town');
      await tester.pump();
      await _shot(tester, key, 's5_town_vow_$lang');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pump();
      await _shot(tester, key, 's6_town_ties_$lang');
      expect(tester.takeException(), isNull);
    }, skip: _out == null);
  }

  // 現地法人と臨時の会議の場面（日英）
  for (final lang in ['ja', 'en']) {
    testWidgets('現地法人と臨時の会議の場面の書き出し（$lang・幅390）', (tester) async {
      await _loadFonts();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
      addTearDown(() => L.lang = 'ja');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
      for (var i = 0; i < 150; i++) {
        botMonth(g);
      }
      resolveEvents(g);
      g.calcAll();
      ctl.game = g;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
      await tester.pump();
      final b = (g.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).first;
      b.ctry = {g.home, ...g.ctryOf(b), 'us', 'cn'}.toList();
      g.calcAll();
      g.ap = 3;
      // 分社・独立のシート（現地法人に分ける）
      openShape(ctl, b);
      await tester.pump();
      await _shot(tester, key, 'l1_shape_$lang');
      openLocal(ctl, b, 'us');
      await tester.pump();
      await _shot(tester, key, 'l2_local_pres_$lang');
      ctl.closeSheet();
      g.makeLocal(b, 'us');
      final c = g.locals().single;
      g.subIPO(c);
      final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
      c.locRiv = foe.id;
      c.locRivPct = 26;
      g.calcAll();
      // 株の画面の現地法人のカード
      ctl.setTab('stock');
      await tester.pump();
      await tester.scrollUntilVisible(find.textContaining(tr('現地法人（{0}）', [cm['us']!.n])), 300, scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pump();
      await _shot(tester, key, 'l3_local_card_$lang');
      // 宿敵に狙われる
      g.events
        ..clear()
        ..add(g.evLocalHostile(c, foe, 25));
      nextEvent(ctl);
      await tester.pump();
      await _shot(tester, key, 'l4_local_hostile_$lang');
      ctl.closeSheet();
      // 臨時の会議（乗っ取り・不祥事・資金）
      if (!g.staff.any((p) => p.partner)) {
        final p = g.mkPerson(.5)
          ..partner = true
          ..stake = 5;
        g.staff.add(p);
      }
      g.listed = true;
      g.sh = Shares(own: 40, pt: 5, float: 37, riv: {foe.id: 18});
      var k = 5;
      g.pre = -g.cash / 2.5;
      for (final kind in ['takeover', 'scandal', 'cash']) {
        g.events
          ..clear()
          ..add(g.crisisMeeting(kind, foe: foe, near: 20)!);
        nextEvent(ctl);
        await tester.pump();
        await _shot(tester, key, 'l${k++}_crisis_${kind}_$lang');
        ctl.closeSheet();
      }
      // 遊び方の2項目
      showHelp(ctl);
      await tester.pump();
      await tester.scrollUntilVisible(find.text(tr('現地法人')), 300, scrollable: find.byType(Scrollable).last);
      await tester.pump();
      await _shot(tester, key, 'l8_help_$lang');
      expect(tester.takeException(), isNull);
    }, skip: _out == null);
  }
}
