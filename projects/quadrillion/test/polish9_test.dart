import 'dart:io';

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

/// 9回目の改善: 会議の発言を人ごとに・項目名の折り返し・上の帯の社長の名前・月を進める速さ

/// 本物のフォント（字の幅を本物にする。テストのふつうの字は1字が1文字ぶんの四角で、英語の幅が合わない）
Future<void> _loadFonts() async {
  final jp = FontLoader(fontFamily);
  for (final f in ['assets/fonts/NotoSansJP-Regular.ttf', 'assets/fonts/NotoSansJP-Bold.ttf']) {
    jp.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await jp.load();
}

Future<GameController> _pump(WidgetTester tester, Game g, {required double width, double height = 9000, String lang = 'ja'}) async {
  await _loadFonts();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(77), lang: lang);
  addTearDown(() => L.lang = 'ja');
  ctl.game = g;
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(QuadrillionApp(controller: ctl));
  await tester.pump();
  return ctl;
}

/// 途中の会社（子会社・上場した現地法人・宿敵の持ち分・相棒・投資家までそろえる）
Game _richGame() {
  final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: ['charm', 'gambler']), rng: ParkMiller(2024));
  for (var i = 0; i < 150; i++) {
    botMonth(g);
  }
  resolveEvents(g);
  g.calcAll();
  final b = (g.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).first;
  b.ctry = {g.home, ...g.ctryOf(b), 'us', 'cn'}.toList();
  g.calcAll();
  g.ap = 3;
  g.makeLocal(b, 'us');
  final c = g.locals().single;
  g.subIPO(c);
  final foe = g.cos.firstWhere((x) => x.alive && x.rival != null && x.parent != 'player');
  c.locRiv = foe.id;
  c.locRivPct = 26;
  final p = g.mkPerson(.5)
    ..partner = true
    ..stake = 5;
  g.staff.add(p);
  g.listed = true;
  g.sh = Shares(own: 40, pt: 5, vc: 3, ally: 4, float: 30, riv: {foe.id: 18});
  g.events.clear();
  g.calcAll();
  return g;
}

/// 画面の中の項目名（Kv の左）の文と、その描かれ方（折り返したか・縮めた割合）
List<({String label, bool wrapped, double scale})> _labels(WidgetTester tester) {
  final out = <({String label, bool wrapped, double scale})>[];
  for (final e in find.byType(Kv).evaluate()) {
    final kv = e.widget as Kv;
    final label = tx(kv.k);
    final rp = find
        .descendant(of: find.byWidget(kv), matching: find.byType(RichText))
        .evaluate()
        .map((x) => x.renderObject as RenderParagraph)
        .firstWhere((r) => r.text.toPlainText() == label);
    if (!rp.hasSize) continue;
    final natural = rp.getMaxIntrinsicWidth(double.infinity);
    final wrapped = rp.size.width + .5 < natural;
    // 画面に描かれた幅 ÷ 文の幅（FittedBox で縮めたなら 1 より小さい）
    final shown = rp.localToGlobal(Offset(rp.size.width, 0)).dx - rp.localToGlobal(Offset.zero).dx;
    out.add((label: label, wrapped: wrapped, scale: shown / rp.size.width));
  }
  return out;
}

/// 全部のタブと、項目名の欄がある小窓を開いて、項目名を集める
Future<List<({String where, String label, bool wrapped, double scale})>> _sweep(WidgetTester tester, GameController ctl) async {
  final out = <({String where, String label, bool wrapped, double scale})>[];
  void take(String where) {
    for (final l in _labels(tester)) {
      out.add((where: where, label: l.label, wrapped: l.wrapped, scale: l.scale));
    }
  }

  final g = ctl.game!;
  for (final t in const ['town', 'biz', 'people', 'stock', 'num', 'zukan']) {
    // 一番大きい事業のカードをひらく
    if (t == 'biz') ctl.openBiz = (g.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).first.id;
    ctl.setTab(t);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: t);
    take('タブ $t');
  }
  g.meet = g.mkPerson(.5)..place = 'club';
  openMeet(ctl);
  await tester.pump();
  take('出会い');
  ctl.closeSheet();
  g.meet = null;
  openSettings(ctl);
  await tester.pump();
  take('設定');
  ctl.closeSheet();
  await tester.pump();
  return out;
}

void main() {
  tearDown(() => L.lang = 'ja');

  group('項目名の折り返し', () {
    for (final lang in ['ja', 'en']) {
      for (final w in [320.0, 390.0, 430.0]) {
        testWidgets('項目名は1行に収まる（$lang・幅${w.round()}）', (tester) async {
          final ctl = await _pump(tester, _richGame(), width: w, lang: lang);
          final all = await _sweep(tester, ctl);
          expect(all.map((x) => x.label).toSet(), containsAll(lang == 'ja' ? ['売上（月）', '利益（月）', '宿敵の持ち分', '統率', '版'] : ['Sales/mo', 'Version']));
          if (const bool.fromEnvironment('dummy') || true) {
            // ignore: avoid_print
            print('[scale] $lang ${w.round()} ' + (all.where((x) => x.scale < .999).map((x) => '${x.label}=${x.scale.toStringAsFixed(2)}').toSet().join(' / ')));
          }
          final bad = all.where((x) => x.wrapped).map((x) => '${x.where}: ${x.label}').toSet();
          expect(bad, isEmpty, reason: '折り返している項目名:\n${bad.join('\n')}');
        });
      }
    }
  });
}
