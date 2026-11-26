// 横向きの画面（1.1.0+25）：iPhone の横（844×390・667×375）と iPad の横（1194×834）で、どの画面も崩れず、
// 英語の画面に日本語が残らないこと。QUAD_SHOTS にフォルダを渡すと、844×390 と 1194×834 の日英を PNG に書き出す
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

String? _midJson;

/// 1990年から6年回した会社（借金あり・海外あり）。作るのは1回だけ
/// 1.1.0+26 から、借りて回すと6年で倒れることがある（店などの数で伸びが遅くなった）。倒れない種を選び、
/// 事業の画面で型の違いが見えるように、店舗型のほかに型の違う事業を足す
Game _mid() {
  if (_midJson == null) {
    late Game g;
    for (var seed = 7; seed < 40; seed++) {
      g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
      for (var m = 0; m < 72 && g.over == null; m++) {
        botMonth(g, units: true, focus: true);
      }
      if (g.over == null && g.biz.any((b) => g.kindB(b) == 'shop')) break;
    }
    resolveEvents(g);
    // 人で稼ぐ型（コンサル）・工場型（冷凍食品）・許認可型（質屋）
    for (final ind in const ['consult', 'frozen', 'pawn']) {
      if (g.biz.any((b) => b.ind == ind) || g.biz.length >= 4) continue;
      g.cash += g.capexOf(indm[ind]!);
      g.hUsed = 0;
      g.startBiz(ind);
    }
    if (g.loans.isEmpty) {
      // 借りたお金は手元に入る（会社の大きさに見合う額にする。1.1.0+26 から会社が小さいことがあり、5億円だと時価総額が1円になった）
      final a = g.rev * 6 + 1e7;
      g.loanFromEvent(a);
      g.cash += a;
    }
    resolveEvents(g);
    g.calcAll();
    _midJson = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_midJson!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

/// 画面に出ている字を全部（Text と RichText）
List<String> _texts(WidgetTester t) => [
      for (final w in t.widgetList<RichText>(find.byType(RichText))) w.text.toPlainText(),
    ];

// biz:2 は2つ目の事業、biz:shop は店舗型の事業を選んだ画面、biz:new は右に新しい事業を出した画面、town:1 は2つ目の都市圏（1.1.0+26）
const _views = ['town', 'town:1', 'biz', 'biz:2', 'biz:shop', 'biz:new', 'people', 'stock', 'money', 'money:bank', 'money:cost', 'money:tax', 'money:book', 'world', 'zukan'];

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
  for (final v in _views) {
    final p = v.split(':');
    ctl.setTab(p[0]);
    if (p[0] == 'money') ctl.setMoney(p.length > 1 ? p[1] : 'cash');
    if (p[0] == 'world') ctl.setWorld('us');
    if (p[0] == 'town') ctl.setTownCity(p.length > 1 ? int.parse(p[1]) : 0);
    if (p[0] == 'biz') {
      final g = ctl.game!;
      if (p.length > 1 && p[1] == 'new') {
        ctl.showNewBiz();
      } else if (p.length > 1 && p[1] == 'shop') {
        // 店舗型の事業（立地ごとの店の数・日販・1店の利益の表）
        ctl.selectBiz(g.biz.firstWhere((b) => g.kindB(b) == 'shop', orElse: () => g.biz.first).id);
      } else {
        final l = g.biz.toList()..sort((a, b) => b.rev.compareTo(a.rev));
        ctl.selectBiz(l[p.length > 1 ? (int.parse(p[1]) - 1).clamp(0, l.length - 1) : 0].id);
      }
    }
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '$v ${size.width}x${size.height} $lang');
    if (shoot) await shot(tester, key, '${size.width.round()}x${size.height.round()}_${lang}_${v.replaceAll(':', '-')}', pixelRatio: 1.5);
    if (p[0] == 'town') {
      // 1.1.0+42 から街の絵は無い。都市ごとの違いは「自社の拠点」の欄（都市の切り替えと、その都市の店などの数）で見せる
      expect(find.byKey(const ValueKey('town-picture')), findsNothing, reason: v);
      // 画面の下にあるときは、まだ作られていないので、そこまで送る（書き出しのあとで送る）
      await tester.scrollUntilVisible(find.byKey(const ValueKey('town-sites')), 120,
          scrollable: find.descendant(of: find.byKey(const PageStorageKey('tab-town')), matching: find.byType(Scrollable)).first);
      expect(find.byKey(const ValueKey('town-sites')), findsOneWidget, reason: v);
      expect(find.byKey(const ValueKey('town-city-1')), findsOneWidget, reason: '$v: 都市の切り替えは残す');
      final g = ctl.game!, city = p.length > 1 ? int.parse(p[1]) : 0;
      for (final b in g.biz) {
        final n = g.unitsAt(b, '${g.home}/$city/0') + g.unitsAt(b, '${g.home}/$city/1');
        if (KIND_ZONED.contains(g.kindB(b)) && n > 0) expect(find.byKey(ValueKey('town-site-${b.id}')), findsOneWidget, reason: '$v: ${b.ind} の数');
      }
    }
    if (lang == 'en') {
      for (final s in _texts(tester)) {
        expect(_cjk.hasMatch(s), isFalse, reason: '$v: 英語の画面に日本語「$s」');
      }
    }
  }
  // 幅の狭い画面は、右の帯を小窓で開く
  if (size.width < 760) {
    await tester.tap(find.byKey(const ValueKey('side-open')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (shoot) await shot(tester, key, '${size.width.round()}x${size.height.round()}_${lang}_side', pixelRatio: 1.5);
    ctl.closeSheet();
    await tester.pump();
  }
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('横向き ${size.width.round()}×${size.height.round()}（$lang）：どの画面も崩れない${lang == 'en' ? '・日本語が残らない' : ''}', (tester) async {
        await _walk(tester, size, lang, shoot: size.width != 667);
      });
    }
  }

  testWidgets('前の版のセーブを読もうとしても落ちず、「新しい版では続きから遊べません」と出て、新しく始められる', (tester) async {
    final old = Game.newGame(SetupConfig(traits: const ['charm', 'careful']), rng: ParkMiller(1)).toJson()..['v'] = 1;
    SharedPreferences.setMockInitialValues({slotKey(1): jsonEncode(old), slotMetaKey(1): jsonEncode({'year': 1980, 'q': 1, 'name': 'x', 'cap': 1, 'rank': 1})});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5));
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    expect(ctl.load(1), isFalse);
    await tester.pump();
    expect(find.textContaining('新しい版では続きから遊べません'), findsOneWidget);
    expect(ctl.hasSave(1), isFalse, reason: '枠は空く');
    ctl.closeSheet();
    ctl.setup = SetupConfig(traits: const ['charm', 'careful']);
    ctl.startNew();
    await tester.pump();
    expect(ctl.game, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
