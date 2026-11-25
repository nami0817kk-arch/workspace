// 社長の腕（1.1.0+32）の画面：はじめの画面の振り分けと、人の画面の社長の「腕の伸び方」が、
// 横向きの 844×390・1194×834 の日英で崩れず、英語に日本語が残らないこと。押すと持ち点が動くこと。
// QUAD_SHOTS にフォルダを渡すと PNG に書き出す（画像はコミットしない）
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

void _noJa(WidgetTester tester, String where) {
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    final s = w.text.toPlainText();
    expect(_cjk.hasMatch(s), isFalse, reason: '$where: 英語の画面に日本語「$s」');
  }
}

Future<(GameController, GlobalKey)> _open(WidgetTester tester, Size size, String lang) async {
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
  return (ctl, key);
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(844, 390), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      final tag = '${size.width.round()}x${size.height.round()}_$lang';
      testWidgets('はじめの画面の腕の振り分け $tag', (tester) async {
        final (ctl, key) = await _open(tester, size, lang);
        ctl.setup.traits = ['charm', 'careful'];
        // はじめの画面は縦に長い一覧なので、振り分けの所まで送る
        await tester.scrollUntilVisible(find.byKey(const ValueKey('ab-pick')), 200, scrollable: find.byType(Scrollable).first);
        tester.widget<ChoiceBtn>(find.byKey(const ValueKey('ab-pick'))).onTap!();
        await tester.pump();
        expect(ctl.setup.ab, {for (final k in abKeys) k: 45});
        // 統率を下げて開発に回す
        tester.widget<Btn>(find.byKey(const ValueKey('ab-minus-tou'))).onTap!();
        await tester.pump();
        expect(ctl.setup.abLeft(), 5);
        tester.widget<Btn>(find.byKey(const ValueKey('ab-plus-kai'))).onTap!();
        await tester.pump();
        expect(ctl.setup.ab!['tou'], 40);
        expect(ctl.setup.ab!['kai'], 50);
        expect(ctl.setup.abLeft(), 0);
        // 残りが無いと、もう上げられない
        expect(tester.widget<Btn>(find.byKey(const ValueKey('ab-plus-ei'))).enabled, isFalse);
        await tester.ensureVisible(find.byKey(const ValueKey('ab-panel')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (lang == 'en') _noJa(tester, 'setup');
        await shot(tester, key, 'pres_setup_$tag', pixelRatio: 1.5);
        // 始めると、振り分けた腕で始まる
        ctl.startNew();
        expect(ctl.game!.pres.ab['kai'], 50);
        expect(ctl.game!.pres.ab['tou'], 40);
      });

      testWidgets('人の画面の社長の腕の伸び方 $tag', (tester) async {
        final (ctl, key) = await _open(tester, size, lang);
        final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(7));
        for (var m = 0; m < 36 && g.over == null; m++) {
          botMonth(g, units: true, focus: true);
        }
        resolveEvents(g);
        g.events.clear();
        g.pres.xp['tou'] = presNeedOf(g.pres.ab['tou']!) * .7;
        g.pres.xp['zai'] = presNeedOf(g.pres.ab['zai']!) * .2;
        g.pres.ab['ei'] = 99;
        ctl.game = g;
        ctl.setTab('people');
        ctl.setPeopleSeg('exec');
        ctl.selectPerson(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final panel = find.byKey(const ValueKey('pres-grow'));
        expect(panel, findsOneWidget);
        await tester.ensureVisible(panel);
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final k in abKeys) {
          expect(find.byKey(ValueKey('pres-xp-$k')), findsOneWidget);
        }
        if (lang == 'en') _noJa(tester, 'people');
        await shot(tester, key, 'pres_people_$tag', pixelRatio: 1.5);
      });
    }
  }
}
