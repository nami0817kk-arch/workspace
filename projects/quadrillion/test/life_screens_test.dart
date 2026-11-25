// 段6（1.1.0+30）の画面：社長の始め方・図鑑（業種の37の特性と市場の推移・歴史）・人の画面の社長（経歴・私生活・世間の顔）・
// お金の税金（減価償却・保険・IT・特許）・会議と出来事（小窓・小さな知らせは「今月やること」）。
// 横向きの 844×390・1194×834 の日英で崩れず、英語に日本語が残らないこと。
// QUAD_SHOTS にフォルダを渡すと PNG に書き出す（画像はコミットしない）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/life_screens.dart';
import 'package:quadrillion/ui/sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

String? _json;

/// 1980年に会社員を5年してから始め、12年回した会社（特許・ITの段・結婚・業界団体の役職をそろえる）
Game _mid() {
  if (_json == null) {
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1980, traits: const ['charm', 'careful'], start: 'work', workYears: 5, workCat: 'food'), rng: ParkMiller(7));
    for (var m = 0; m < 144 && g.over == null; m++) {
      botMonth(g, units: true, focus: true);
    }
    resolveEvents(g);
    g.events.clear();
    if (g.biz.isNotEmpty) g.life.patents.add(Patent(g.biz.first.ind, g.turn + 200));
    g.life.married = true;
    g.life.assocUntil = g.turn + 10;
    g.life.fame = 23;
    g.ensureFaces();
    g.calcAll();
    _json = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

/// 縦に巻ける欄を順に試し、[f] が見えるところまで巻き上げる（低い画面では下にある欄を書き出すため）
Future<void> _reveal(WidgetTester tester, Finder f) async {
  final n = find.byType(Scrollable).evaluate().length;
  for (var i = 0; i < n; i++) {
    final sc = find.byType(Scrollable).at(i);
    final st = tester.state<ScrollableState>(sc);
    if (st.axisDirection != AxisDirection.down) continue;
    try {
      await tester.scrollUntilVisible(f, 150, scrollable: sc, maxScrolls: 30);
      await tester.pump();
      return;
    } catch (_) {}
  }
}

const _views = ['setup', 'zukan:ind', 'zukan:detail', 'zukan:hist', 'pres', 'tax', 'todo', 'event'];

Future<void> _walk(WidgetTester tester, Size size, String lang, {bool shoot = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5), lang: lang);
  L.lang = lang;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => L.lang = 'ja');
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
  await tester.pump();
  for (final v in _views) {
    ctl.closeSheet();
    switch (v) {
      case 'setup':
        ctl.game = null;
        ctl.setup = SetupConfig(start: 'work', workYears: 5, workCat: 'food', traits: ['charm', 'careful']);
      case 'zukan:ind':
        ctl.game = _mid();
        ctl.setTab('zukan');
        ctl.setZukan('ind');
      case 'zukan:detail':
        final g = ctl.game!;
        openIndDetail(ctl, indm[g.biz.isNotEmpty ? g.biz.first.ind : g.inds.first.id]!);
      case 'zukan:hist':
        ctl.setZukan('hist');
      case 'pres':
        ctl.setTab('people');
        ctl.setPeopleSeg('exec');
        ctl.selectPerson(0);
      case 'tax':
        ctl.setTab('money');
        ctl.setMoney('tax');
      case 'todo':
        ctl.setTab('town');
        final g = ctl.game!;
        g.events.add(GameEvent(title: M('大型の受注'), small: true, text: M('「{0}」に、大口の取引の話が来ました。受ければ一気に伸びますが、現場はかなり無理をします。', [I(g.biz.first.ind)]), choices: [
          Choice(M('受ける'), M('事業の力が1割5分上がる。部下全員の忠誠が下がる'), () => M('受注しました。現場は大忙しです')),
          Choice(M('断る'), M('何も起きない'), () => M('見送りました')),
        ]));
      case 'event':
        final g = ctl.game!;
        openSmallEvent(ctl, g.events.firstWhere((e) => e.small));
    }
    ctl.render();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '$v ${size.width}x${size.height} $lang');
    switch (v) {
      case 'setup':
        await _reveal(tester, find.byKey(const ValueKey('work-cat-food')));
        expect(find.byKey(const ValueKey('work-cat-food')), findsOneWidget);
      case 'zukan:detail':
        expect(find.byKey(const ValueKey('ind-market-chart')), findsOneWidget);
      case 'zukan:hist':
        expect(find.textContaining(lang == 'ja' ? '年表' : 'timeline'), findsOneWidget);
      case 'pres':
        await _reveal(tester, find.byKey(const ValueKey('pres-public')));
        expect(find.byKey(const ValueKey('pres-bio')), findsOneWidget);
      case 'tax':
        // 低い画面では下にある。書き出す前に、ITの欄まで巻き上げる
        await _reveal(tester, find.byKey(const ValueKey('money-it')));
        expect(find.byKey(const ValueKey('money-it')), findsOneWidget);
      case 'todo':
        expect(find.byKey(const ValueKey('small-ev-0')), findsWidgets);
      case 'event':
        expect(find.text(lang == 'ja' ? 'あとで決める' : 'Decide later'), findsOneWidget);
    }
    if (lang == 'en') {
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        final s = w.text.toPlainText();
        expect(_cjk.hasMatch(s), isFalse, reason: '$v: 英語の画面に日本語「$s」');
      }
    }
    if (shoot) await shot(tester, key, 'life_${size.width.round()}x${size.height.round()}_${lang}_${v.replaceAll(':', '-')}', pixelRatio: 1.5);
  }
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(844, 390), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('段6の画面 ${size.width.round()}×${size.height.round()}（$lang）：崩れない${lang == 'en' ? '・日本語が残らない' : ''}', (tester) async {
        await _walk(tester, size, lang, shoot: true);
      });
    }
  }

  test('図鑑の業種の特性は37を全部出す', () {
    for (final i in IND.take(20)) {
      final n = traitRows(i).fold(0, (a, g) => a + g.$2.length);
      expect(n, IndProfile.count, reason: i.id);
    }
  });
}
