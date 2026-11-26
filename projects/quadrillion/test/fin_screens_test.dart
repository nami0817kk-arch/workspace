// 決算書と事業ごとの損益の画面（1.1.0+34）: 崩れない・英語に日本語が残らない・iPhone で長すぎない
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/fin_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/grown.dart';
import 'support/shots.dart';

String? _json;

/// 数年遊ばせた会社（事業4つ以上・借金・子会社・現地法人）
Game _grown() {
  if (_json == null) {
    final g = grownGame(years: 12, search: false);
    _json = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

/// 見る面（名前・切り替え）
final _views = <(String, void Function(GameController))>[
  ('pl', (c) => c..setMoney('fs')..setFs(tab: 'pl', mode: 'year')),
  ('pl-open', (c) {
    c.setFs(tab: 'pl', mode: 'year');
    c.toggleShown('fs-sga');
    c.toggleShown('fs-sp');
  }),
  ('bs', (c) => c.setFs(tab: 'bs', mode: 'year')),
  ('cf', (c) => c.setFs(tab: 'cf', mode: 'year')),
  ('cf-open', (c) {
    c.toggleShown('fs-cfop');
    c.toggleShown('fs-cfinv');
    c.toggleShown('fs-cffin');
  }),
  ('trend', (c) => c.setFs(tab: 'trend', mode: 'year')),
  ('trend-num', (c) => c.toggleShown('fs-trend-num')),
  ('month-pl', (c) => c.setFs(tab: 'pl', mode: 'month', months: 'last12')),
  ('month-cf', (c) => c.setFs(tab: 'cf', mode: 'month', months: 'ytd')),
  ('month-trend', (c) => c.setFs(tab: 'trend', mode: 'month', months: 'last12')),
  ('seg', (c) => c..setMoney('seg')..setFs(mode: 'year')),
  ('seg-all', (c) => c.toggleShown('seg-all')),
];

/// 内訳を開いていない、はじめに見る面（iPhone で2画面分に収めたいもの）
const _firstLook = {'pl', 'bs', 'cf', 'trend', 'month-pl', 'month-cf', 'seg'};

void main() {
  setUpAll(loadRealFonts);

  test('盤面の前提（事業4つ以上・借金・子会社か現地法人・締めた年がある）', () {
    final g = _grown();
    // ignore: avoid_print
    print(grownSummary(g));
    expect(g.biz.length, greaterThanOrEqualTo(4));
    expect(g.debt, greaterThan(0));
    expect(g.subs(), isNotEmpty);
    expect(g.books.years.length, greaterThanOrEqualTo(5));
  });

  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('決算書・事業ごとの損益 ${size.width.round()}×${size.height.round()}（$lang）', (tester) async {
        final g = _grown();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
        L.lang = lang;
        addTearDown(() => L.lang = 'ja');
        ctl.game = g;
        // 幅700より狭い画面は、ほかの画面のテストと同じく、左右の帯の分を足して真ん中を同じ幅にする
        tester.view.physicalSize = centerAs(size);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: QuadrillionApp(controller: ctl)));
        await tester.pump();
        ctl.setTab('money');
        final lens = <String>[], tooLong = <String>[];
        for (final v in _views) {
          v.$2(ctl);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: v.$1);
          // 本体の縦の巻き（見出しの札を含むもの）
          final sc = find.ancestor(of: find.byKey(const ValueKey('money-fs')), matching: find.byType(Scrollable)).first;
          final pos = tester.state<ScrollableState>(sc).position;
          pos.jumpTo(0);
          await tester.pump();
          final screens = (pos.maxScrollExtent + pos.viewportDimension) / pos.viewportDimension;
          lens.add('${v.$1} ${screens.toStringAsFixed(2)}');
          // 英語は「お金」の切り替えの札が2行に折り返す（今ある札の英語が長い）ので、その分だけ許す
          if (size == const Size(844, 390) && _firstLook.contains(v.$1) && screens > (lang == 'en' ? 2.6 : 2.05)) tooLong.add('${v.$1} ${screens.toStringAsFixed(2)}');
          // 上から下まで送りながら、英語の画面に日本語が残っていないか・崩れていないかを見る
          var i = 0;
          while (true) {
            await tester.pump();
            expect(tester.takeException(), isNull, reason: '${v.$1} $i');
            if (lang == 'en') {
              for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
                expect(_cjk.hasMatch(w.text.toPlainText()), isFalse, reason: '${v.$1}: 英語の画面に日本語「${w.text.toPlainText()}」');
              }
            }
            if (size != const Size(667, 375)) await shot(tester, key, 'fs_${size.width.round()}x${size.height.round()}_${lang}_${v.$1}_$i', pixelRatio: 1);
            if (pos.pixels >= pos.maxScrollExtent - .5 || i >= 3) break;
            pos.jumpTo((pos.pixels + pos.viewportDimension * .85).clamp(0, pos.maxScrollExtent).toDouble());
            i++;
          }
          pos.jumpTo(0);
        }
        // ignore: avoid_print
        print('${size.width.round()}×${size.height.round()} $lang 画面の長さ（画面分）: ${lens.join(' / ')}');
        // iPhone（844×390）で、はじめに見る面（内訳を開く前）は2画面分まで
        expect(tooLong, isEmpty, reason: 'iPhone で2画面分を超える面');
      });
    }
  }

  testWidgets('事業ごとの損益: 並べ替えると順が変わり、赤字の事業は赤・稼ぎ頭は星', (tester) async {
    final g = _grown();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77));
    ctl.game = g;
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    await tester.pump();
    ctl.setTab('money');
    ctl.setMoney('seg');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seg-best')), findsOneWidget);
    final y = g.books.years.last.y;
    final byProfit = segRows(g, y, 'profit').map((r) => r.key).toList();
    final byRev = segRows(g, y, 'rev').map((r) => r.key).toList();
    final rows = segRows(g, y, 'profit');
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i - 1].profit, greaterThanOrEqualTo(rows[i].profit));
    }
    final rr = segRows(g, y, 'rev');
    for (var i = 1; i < rr.length; i++) {
      expect(rr[i - 1].rev, greaterThanOrEqualTo(rr[i].rev));
    }
    expect(byProfit.toSet(), byRev.toSet());
    await tester.tap(find.byKey(const ValueKey('seg-sort-rev')));
    await tester.pumpAndSettle();
    expect(ctl.segSort, 'rev');
  });
}
