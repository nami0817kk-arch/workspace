// 株の画面（1.1.0+29。企画書「株の画面（決定）」）：横向きの 844×390・667×375・1194×834 の日英で、
// 自社の株・他社の株と買収・上場の3面が崩れず、英語に日本語が残らないこと。
// QUAD_SHOTS にフォルダを渡すと、844×390 と 1194×834 の日英を PNG に書き出す（画像はコミットしない）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

String? _json;
int _dealCo = 0, _subCo = 0;

/// 1990年から8年回した会社に、株価の記録・買う話・統合中の子会社・大口の客・宿敵の持ち分をそろえる
Game _mid() {
  if (_json == null) {
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(7));
    for (var m = 0; m < 96 && g.over == null; m++) {
      botMonth(g, units: true, focus: true);
    }
    resolveEvents(g);
    g.events.clear();
    g.listed = true;
    final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
    g.sh = Shares(own: 52, float: 40, riv: {foe.id: 8});
    final others = g.cos.where((c) => c.alive && c.parent != 'player' && c.rival == null && c.loc == null).toList()..ssort((a, b) => a.cap.compareTo(b.cap));
    final d = others[3];
    g.rollHidden(d);
    d.fin!.offDebt = .1;
    g.corp.deals.add(MaDeal(co: d.id, stage: 'review', left: 4, block: .3));
    _dealCo = d.id;
    final sub = others[5];
    sub.parent = 'player';
    sub.stakePlayer = 60;
    sub.fin!
      ..dd = 1
      ..integ = 9
      ..integAll = 18
      ..attr = .04
      ..gw = 3e9
      ..plan = 1e9;
    _subCo = sub.id;
    if (g.biz.isNotEmpty) g.corp.clients[g.biz.first.id] = Client(co: foe.id, share: .45, since: 1994);
    g.ensureFaces();
    g.calcAll();
    _json = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

const _views = ['own', 'ma:deal', 'ma:sub', 'ma:buy', 'ipo:none', 'ipo:prep', 'ipo:listed'];

Future<void> _walk(WidgetTester tester, Size size, String lang, {bool shoot = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5), lang: lang);
  L.lang = lang;
  ctl.game = _mid();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => L.lang = 'ja');
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
  await tester.pump();
  ctl.setTab('stock');
  final g = ctl.game!;
  for (final v in _views) {
    final p = v.split(':');
    ctl.closeSheet();
    switch (v) {
      case 'own':
        ctl.setStockSeg('own');
      case 'ma:deal':
        ctl.selectCo(_dealCo);
      case 'ma:sub':
        ctl.selectCo(_subCo);
      case 'ma:buy':
        ctl.selectCo(g.cos.firstWhere((c) => c.alive && c.parent != 'player' && g.pctOf(c) == 0 && g.dealOf(c) == null && c.rival != null).id);
      case 'ipo:none':
        g.listed = false;
        g.corp.ipo = null;
        ctl.setStockSeg('ipo');
      case 'ipo:prep':
        g.listed = false;
        g.corp.ipo = IpoPrep(start: 0, total: 30, done: 12, audit: 12, ctrl: .4, spent: 5e7);
        ctl.setStockSeg('ipo');
      case 'ipo:listed':
        g.listed = true;
        g.corp.ipo = null;
        ctl.setStockSeg('ipo');
    }
    ctl.render();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '$v ${size.width}x${size.height} $lang');
    if (p[0] == 'ma') expect(find.byKey(ValueKey('co-row-${ctl.openCo}')), findsOneWidget, reason: v);
    if (lang == 'en') {
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        final s = w.text.toPlainText();
        expect(_cjk.hasMatch(s), isFalse, reason: '$v: 英語の画面に日本語「$s」');
      }
    }
    if (shoot) await shot(tester, key, 'stock_${size.width.round()}x${size.height.round()}_${lang}_${v.replaceAll(':', '-')}', pixelRatio: 1.5);
  }
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('株の画面 ${size.width.round()}×${size.height.round()}（$lang）：崩れない${lang == 'en' ? '・日本語が残らない' : ''}', (tester) async {
        await _walk(tester, size, lang, shoot: size.width != 667);
      });
    }
  }

  testWidgets('他社の会社を押すと右に中身が出て、「調べる」で買う話が始まる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5), lang: 'ja');
    ctl.game = _mid();
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    ctl.setTab('stock');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stock-ma')));
    await tester.pump();
    final g = ctl.game!;
    g.cash = 1e15;
    g.hUsed = 0;
    final c = g.cos.firstWhere((c) => c.alive && c.parent != 'player' && g.pctOf(c) == 0 && g.dealOf(c) == null && c.rival != null);
    ctl.selectCo(c.id);
    await tester.pump();
    expect(find.byKey(ValueKey('deal-${c.id}')), findsOneWidget);
    final btn = find.descendant(of: find.byKey(ValueKey('deal-${c.id}')), matching: find.textContaining('調べる（'));
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pump();
    expect(g.dealOf(c)?.stage, 'dd');
    expect(find.byKey(ValueKey('deal-stage-${c.id}')), findsOneWidget);
  });
}
