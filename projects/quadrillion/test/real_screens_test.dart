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
Game _mid() {
  if (_midJson == null) {
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(7));
    for (var m = 0; m < 72; m++) {
      botMonth(g, units: true, borrow: 'some');
    }
    if (g.loans.isEmpty) g.loanFromEvent(5e8);
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

const _views = ['town', 'biz', 'people', 'stock', 'money', 'money:bank', 'money:cost', 'money:tax', 'money:book', 'world', 'zukan'];

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
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '$v ${size.width}x${size.height} $lang');
    if (lang == 'en') {
      for (final s in _texts(tester)) {
        expect(_cjk.hasMatch(s), isFalse, reason: '$v: 英語の画面に日本語「$s」');
      }
    }
    if (shoot) await shot(tester, key, '${size.width.round()}x${size.height.round()}_${lang}_${v.replaceAll(':', '-')}', pixelRatio: 1.5);
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
