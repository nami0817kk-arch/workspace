// 世界の画面（1.1.0+28。企画書「世界の画面（決定）」と段5）：横向きの 844×390・667×375・1194×834 の日英で、
// 地図と国の比較（関税・物流の列）、押した国の中身（関税・物流・政治・伸びている業種・自社の出方・仕入れの網・視察）が崩れず、
// 英語に日本語が残らないこと。QUAD_SHOTS にフォルダを渡すと、844×390 と 1194×834 の日英を、下へ送りながら PNG に書き出す
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

String? _json;

/// 2005年の会社：コンビニと家電で韓国（単独）と米国（組んで）に出て、韓国を視察し、家電の仕入れ先を2か国に分け、
/// 中国が止まっていて、中国に出せないお金がある
Game _mid() {
  if (_json == null) {
    final g = Game.newGame(SetupConfig(mode: 'world', year: 2005, traits: const ['charm', 'careful']), rng: ParkMiller(7));
    g.cash = 1e12;
    for (final id in ['konbini', 'kaden']) {
      g.hUsed = 0;
      g.startBiz(id);
    }
    for (final b in g.biz) {
      g.addCtry(b, 'kr', 'solo', b.power * .4);
      g.addCtry(b, 'us', 'jv', b.power * .4);
    }
    for (var m = 0; m < 3; m++) {
      resolveEvents(g);
      g.nextQuarter();
      g.events.clear();
    }
    g.hUsed = 0;
    g.inspect('kr');
    final k = g.biz.firstWhere((b) => b.ind == 'kaden');
    g.hUsed = 0;
    final alt = g.srcList(k).where((s) => !g.supOf(k).contains(s)).first;
    g.addSupplier(k, alt);
    g.trade.stops.add(ActiveStop(c: 'cn', ja: M('洪水'), left: 2, unit: .05, sup: .4));
    g.trade.trapped['cn'] = 3e8;
    g.hUsed = 0;
    g.calcAll();
    _json = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

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
  ctl.setTab('world');
  for (final c in const ['kr', 'us', 'cn', 'jp']) {
    ctl.setWorld(c);
    await tester.pump();
    // 上から下へ送りながら見る
    for (var i = 0; i < (size.height < 500 ? 10 : 5); i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: '$c $i ${size.width}x${size.height} $lang');
      if (lang == 'en') {
        for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
          final s = w.text.toPlainText();
          expect(_cjk.hasMatch(s), isFalse, reason: '$c: 英語の画面に日本語「$s」');
        }
      }
      if (shoot && (c == 'kr' || c == 'us' || i == 0)) {
        await shot(tester, key, 'world_${size.width.round()}x${size.height.round()}_${lang}_${c}_$i', pixelRatio: 1.5);
      }
      // 真ん中の本体を下へ送る（右側の中身がある辺りをつかむ）
      await tester.dragFrom(Offset(size.width * (size.width >= 1000 ? .6 : .45), size.height * .6), Offset(0, -size.height * .6));
      await tester.pump(const Duration(milliseconds: 400));
    }
    // 一番上へ戻す
    for (var i = 0; i < 8; i++) {
      await tester.dragFrom(Offset(size.width * .45, size.height * .4), Offset(0, size.height * 2));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('世界の画面 ${size.width.round()}×${size.height.round()}（$lang）：崩れない${lang == 'en' ? '・日本語が残らない' : ''}', (tester) async {
        await _walk(tester, size, lang, shoot: size.width != 667);
      });
    }
  }

  testWidgets('国を押すと関税・物流・政治・仕入れの網が出て、視察と仕入れ先のボタンが効く', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5));
    ctl.game = _mid();
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    ctl.setTab('world');
    ctl.setWorld('us');
    await tester.pump();
    expect(find.byKey(const ValueKey('world-trade')), findsOneWidget);
    expect(find.byKey(const ValueKey('world-mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('world-supply')), findsOneWidget);
    expect(find.text('関税'), findsWidgets, reason: '国の比較の表に関税の列');
    final g = ctl.game!;
    expect(g.knowsCtry('us'), isFalse);
    g.hUsed = 0;
    tester.widget<Btn>(find.byKey(const ValueKey('world-inspect'))).onTap!();
    await tester.pump();
    expect(g.knowsCtry('us'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
