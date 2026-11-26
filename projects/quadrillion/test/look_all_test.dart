// 事業の画面の見本（1.1.0+40）と同じ作りを、ほかの全画面に広げた（1.1.0+41）: 崩れない・英語に日本語が残らない・iPhone で長すぎない。
// QUAD_SHOTS を渡すと、見て確かめるための画像を書き出す（QUAD_SHOT_TAG で名前の頭を替える。既定は after）
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/world_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/grown.dart';
import 'support/shots.dart';

String? _json;

/// 数年遊ばせた会社（事業・宿敵・子会社・上場のある盤面）
Game _grown() {
  if (_json == null) {
    final g = grownGame(seed: 2033, years: 14, search: false);
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
final _only = Platform.environment['QUAD_ONLY'];
final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

/// 画面に出ている顔の絵を読み込ませてから書き出す
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

/// 見る画面（名前・開き方）
final _views = <(String, void Function(GameController))>[
  ('town', (c) => c.setTab('town')),
  ('people', (c) => c.setTab('people')),
  ('stock_own', (c) => c..setTab('stock')..setStockSeg('own')),
  ('stock_ma', (c) => c..setTab('stock')..setStockSeg('ma')),
  ('stock_ipo', (c) => c..setTab('stock')..setStockSeg('ipo')),
  for (final m in const ['cash', 'bank', 'cost', 'tax', 'fs', 'seg', 'book']) ('money_$m', (c) => c..setTab('money')..setMoney(m)),
  ('world', (c) => c.setTab('world')),
  for (final z in const ['syn', 'ind', 'ach', 'hist', 'trait']) ('zukan_$z', (c) => c..setTab('zukan')..setZukan(z)),
  // 業種図鑑の分類を1つ開いて、業種の絵の並びを見る
  ('zukan_indopen', (c) {
    c
      ..setTab('zukan')
      ..setZukan('ind');
    if (!c.shown.contains('zukan-cat-live')) c.toggleShown('zukan-cat-live');
  }),
];

void main() {
  setUpAll(loadRealFonts);

  test('地図の形のデータ（Natural Earth）に24か国のうち23か国の形がある（シンガポールは点）', () {
    final sh = WorldShapes.current!;
    expect(sh.c.keys.toSet(), {for (final c in CTRY) if (c.c != 'sg') c.c});
    expect(sh.o.length, greaterThan(100));
  });

  for (final size in const [Size(844, 390), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('世界の地図：名前の札が重ならず枠に収まり、押すとその国を選ぶ ${size.width.round()}（$lang）', (tester) async {
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
        await tester.pumpWidget(QuadrillionApp(controller: ctl));
        await tester.pump();
        ctl.setTab('world');
        await tester.pump();
        final map = find.byKey(const ValueKey('world-map-tap'));
        expect(map, findsOneWidget);
        final r = tester.getRect(map);
        MapLayout lay() => MapLayout.of(g, r.size, ctl.worldSel ?? g.home);
        final l = lay();
        expect(l.labels.length, CTRY.length);
        for (final a in l.labels) {
          expect((Offset.zero & r.size).contains(a.r.topLeft) && (Offset.zero & r.size).contains(a.r.bottomRight), isTrue, reason: '${a.c} が枠の外');
          if (euInset.contains(a.c)) expect(l.inset.contains(a.r.center), isTrue, reason: '${a.c} は拡大の枠の中');
          for (final b in l.labels) {
            if (a != b) expect(a.r.overlaps(b.r), isFalse, reason: '${a.c} と ${b.c} の札が重なる');
          }
        }
        // 札を押す・拡大の枠の中の国の札を押す・国の形を押す
        for (final c in const ['us', 'fr', 'au', 'jp']) {
          final at = lay().labels.firstWhere((x) => x.c == c).r.center;
          await tester.tapAt(r.topLeft + at);
          await tester.pump();
          expect(ctl.worldSel, c, reason: '$c の札');
        }
        // ブラジルの形のまん中あたり（南緯10度・西経52度。札が別の場所に置かれていても、形を押せば選べる）
        ctl.setWorld('jp');
        await tester.pump();
        final br = lay();
        final hit = br.hit(g, MapLayout.px(Offset(-55, WorldProj.miller(-12)), br.k));
        expect(hit, 'br');
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('全画面 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
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
        final name = '${size.width.round()}x${size.height.round()}_$lang';
        final lens = <String>[];
        for (final v in _views) {
          // QUAD_ONLY（画面の名前の頭）を渡すと、その画面だけを見る（手元で見た目を直すとき）
          final only = _only;
          if (only != null && !only.split(',').any(v.$1.startsWith)) continue;
          v.$2(ctl);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.takeException(), isNull, reason: v.$1);
          final sc = find.byKey(PageStorageKey('tab-${ctl.tab}'));
          final pos = tester.state<ScrollableState>(find.descendant(of: sc, matching: find.byType(Scrollable)).first).position;
          pos.jumpTo(0);
          await tester.pump();
          lens.add('${v.$1} ${((pos.maxScrollExtent + pos.viewportDimension) / pos.viewportDimension).toStringAsFixed(2)}');
          if (lang == 'en') {
            for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
              expect(_cjk.hasMatch(w.text.toPlainText()), isFalse, reason: '${v.$1}: 英語の画面に日本語「${w.text.toPlainText()}」');
            }
          }
          if (size != const Size(667, 375) && shotDir != null) {
            for (var i = 0; i < 3; i++) {
              await _shot(tester, key, '${_tag}_${name}_${v.$1}${i == 0 ? '' : '_$i'}');
              if (pos.pixels >= pos.maxScrollExtent - .5) break;
              pos.jumpTo((pos.pixels + pos.viewportDimension * .85).clamp(0, pos.maxScrollExtent).toDouble());
              await tester.pump();
            }
            pos.jumpTo(0);
            await tester.pump();
          }
        }
        // ignore: avoid_print
        print('$_tag $name 画面の長さ（画面分）: ${lens.join(' / ')}');
      });
    }
  }
}
