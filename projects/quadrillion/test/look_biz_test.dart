// 事業の画面の見た目の作り直し（1.1.0+40 の見本）: 崩れない・英語に日本語が残らない・iPhone で長すぎない。
// QUAD_SHOTS を渡すと、見て確かめるための画像を書き出す（QUAD_SHOT_TAG で名前の頭を替える。既定は after）
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/look.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/grown.dart';
import 'support/shots.dart';

String? _json;

/// 数年遊ばせた会社（事業4つ以上・店舗型と工場型）
Game _grown() {
  if (_json == null) {
    // 種 2033 の14年目は事業12（店・人・当たり外れ・ネット）。組み立て役の会社には工場型が育たないので、
    final g = grownGame(seed: 2033, years: 14, search: false);
    //工場型を1つ始めて（元手は足す）、さらに1年ふつうに進める（会社の形を変える手は打たない）
    final f = g.liveInds().where((i) => kindOf(i) == 'factory' && !g.biz.any((b) => b.ind == i.id) && g.newIndBlock(i.id) == null).toList()
      ..sort((a, b) => g.capexOf(a).compareTo(g.capexOf(b)));
    if (f.isNotEmpty) {
      g.cash = (g.cash < 0 ? 0 : g.cash) + g.capexOf(f.first) * 1.5;
      g.hUsed = 0;
      // ignore: avoid_print
      print('工場型を始める: ${txIn(g.startBiz(f.first.id), 'ja')}');
    }
    for (var m = 0; m < 13 && g.over == null; m++) {
      resolveEvents(g);
      g.nextQuarter();
    }
    resolveEvents(g);
    g.undelegAll();
    g.calcAll();
    _json = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

final _tag = Platform.environment['QUAD_SHOT_TAG'] ?? 'after';
final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

/// 画面に出ている顔の絵を読み込ませてから書き出す（テストでは絵の読み込みが本物の時間を要る）
Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  if (shotDir == null) return;
  final els = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    for (final e in els) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
  await shot(tester, key, name, pixelRatio: 1);
}

Biz? _ofKind(Game g, String k) => g.biz.where((b) => g.kindB(b) == k).firstOrNull;

void main() {
  setUpAll(loadRealFonts);

  test('盤面の前提（事業4つ以上・店舗型と工場型がある）', () {
    final g = _grown();
    // ignore: avoid_print
    print('${grownSummary(g)} 型: ${g.biz.map(g.kindB).join(',')}');
    expect(g.biz.length, greaterThanOrEqualTo(4));
    expect(_ofKind(g, 'shop'), isNotNull);
    expect(_ofKind(g, 'factory'), isNotNull);
  });

  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('事業の画面 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
        final g = _grown();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
        L.lang = lang;
        addTearDown(() => L.lang = 'ja');
        ctl.game = g;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
        await tester.pump();
        ctl.setTab('biz');
        final name = '${size.width.round()}x${size.height.round()}_$lang';
        final lens = <String>[];
        for (final k in const ['shop', 'factory', 'net', 'people']) {
          final b = _ofKind(g, k);
          if (b == null) continue;
          ctl.selectBiz(b.id);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.takeException(), isNull, reason: k);
          final sc = find.byKey(const PageStorageKey('tab-biz'));
          final pos = tester.state<ScrollableState>(find.descendant(of: sc, matching: find.byType(Scrollable)).first).position;
          pos.jumpTo(0);
          await tester.pump();
          lens.add('$k ${((pos.maxScrollExtent + pos.viewportDimension) / pos.viewportDimension).toStringAsFixed(2)}');
          if (lang == 'en') {
            for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
              expect(_cjk.hasMatch(w.text.toPlainText()), isFalse, reason: '$k: 英語の画面に日本語「${w.text.toPlainText()}」');
            }
          }
          if (size != const Size(667, 375)) {
            // 上から下まで、画面の85%ずつ送りながら書き出す
            for (var i = 0; i < 6; i++) {
              await _shot(tester, key, '${_tag}_${name}_$k${i == 0 ? '' : '_$i'}');
              if (pos.pixels >= pos.maxScrollExtent - .5) break;
              pos.jumpTo((pos.pixels + pos.viewportDimension * .85).clamp(0, pos.maxScrollExtent).toDouble());
              await tester.pump();
            }
            pos.jumpTo(0);
            await tester.pump();
          }
        }
        // ignore: avoid_print
        print('$_tag $name 事業の画面の長さ（画面分）: ${lens.join(' / ')}');
        if (_tag == 'before') return;
        // 推移のグラフを押すと、その月の値の札が出る
        final shop = _ofKind(g, 'shop')!;
        ctl.selectBiz(shop.id);
        await tester.pump();
        final chart = find.byKey(ValueKey('biz-chart-${shop.id}'));
        expect(chart, findsOneWidget);
        await tester.ensureVisible(chart);
        await tester.pump();
        final r = tester.getRect(chart);
        await tester.tapAt(Offset(r.left + r.width * .55, r.center.dy));
        await tester.pump();
        expect(find.byKey(const ValueKey('trend-tip')), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size != const Size(667, 375)) await _shot(tester, key, '${_tag}_${name}_chart');
        // 右の帯をたたむと、件数だけの細い帯になり、たたんだ形は端末に残る
        if (size.width >= 760) {
          final sc = find.descendant(of: find.byKey(const PageStorageKey('tab-biz')), matching: find.byType(Scrollable)).first;
          tester.state<ScrollableState>(sc).position.jumpTo(0);
          await tester.tap(find.byKey(const ValueKey('side-fold')));
          await tester.pump();
          expect(find.byKey(const ValueKey('side-unfold')), findsOneWidget);
          expect(prefs.getBool(GameController.sideFoldKey), isTrue);
          expect(tester.takeException(), isNull);
          await _shot(tester, key, '${_tag}_${name}_folded');
          await tester.tap(find.byKey(const ValueKey('side-unfold')));
          await tester.pump();
          expect(find.byKey(const ValueKey('side')), findsOneWidget);
          expect(prefs.getBool(GameController.sideFoldKey), isFalse);
        }
      });
    }
  }

  testWidgets('右の帯の「今月やること」は、文を「…」で切らない', (tester) async {
    final g = _grown();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77))..game = g;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    final tips = find.descendant(of: find.byKey(const ValueKey('side')), matching: find.byKey(const ValueKey('todo-tip')));
    expect(tips, findsWidgets);
    for (final e in tester.widgetList<Text>(tips)) {
      expect(e.maxLines, isNull);
      expect(e.overflow, isNot(TextOverflow.ellipsis));
    }
  });

  testWidgets('たたんだ右の帯は、次に開いたときもたたんだまま', (tester) async {
    SharedPreferences.setMockInitialValues({GameController.sideFoldKey: true});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77))..game = _grown();
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    expect(find.byKey(const ValueKey('side-unfold')), findsOneWidget);
    expect(find.byKey(const ValueKey('side')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('今月やること')), findsWidgets);
  });

  testWidgets('月を進めると、要点のカードの数字が前の値から動いて変わる（選び替えでは動かない）', (tester) async {
    Motion.num = Motion.numDefault;
    addTearDown(() => Motion.num = Duration.zero);
    final g = _grown();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77))..game = g;
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    ctl.setTab('biz');
    final b = _ofKind(g, 'shop')!;
    ctl.selectBiz(b.id);
    await tester.pump();
    bool moving() => tester.stateList<KpiCardState>(find.byType(KpiCard)).any((s) => s.moving);
    expect(moving(), isFalse);
    // 別の事業を選んでも動かない
    ctl.selectBiz(_ofKind(g, 'factory')!.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(moving(), isFalse);
    ctl.selectBiz(b.id);
    await tester.pump();
    final before = b.rev;
    resolveEvents(g);
    g.nextQuarter();
    resolveEvents(g);
    ctl.render();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    if (g.biz.contains(b) && b.rev != before) expect(moving(), isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(moving(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
