// 人の画面（1.1.0+27。企画書「人の画面（決定）」）：横向きの 844×390・667×375・1194×834 の日英で、
// 左の一覧（幹部・責任者・採用の候補・社外）と右の1人の中身が崩れず、英語に日本語が残らないこと。
// QUAD_SHOTS にフォルダを渡すと、844×390 と 1194×834 の日英を PNG に書き出す（画像はコミットしない）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quadrillion/game/game.dart';
import 'package:quadrillion/ui/app.dart';
import 'package:quadrillion/ui/controller.dart';
import 'package:quadrillion/ui/people_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/bot.dart';
import 'support/shots.dart';

final _cjk = RegExp(r'[぀-ヿ㐀-鿿]');

String? _json;

/// 1990年から8年回した会社に、注意の印が出る人・休んでいる人・社外の人をそろえる
Game _mid() {
  if (_json == null) {
    final g = Game.newGame(SetupConfig(mode: 'world', year: 1990, traits: const ['charm', 'careful']), rng: ParkMiller(7));
    for (var m = 0; m < 96 && g.over == null; m++) {
      botMonth(g, units: true, focus: true);
    }
    resolveEvents(g);
    g.cash += 1e10;
    // 部下を4人まで足し、1人を責任者に
    while (g.staff.length < 4 && g.cands.isNotEmpty) {
      g.hUsed = 0;
      g.hire(g.cands.first);
    }
    if (g.biz.isNotEmpty && g.biz.first.mgr == null) g.setManager(g.biz.first, g.staff.first.id);
    // 給料が相場より低い人・疲れている人・休んでいる人
    final s = g.staff;
    s[0].salary = g.mktPay(s[0]) * .7;
    s[0].known.addAll(['hon', 'fam', 'str']);
    if (s.length > 1) s[1].health = 25;
    if (s.length > 2) {
      s[2].away = 3;
      s[2].awayWhy = 'sick';
    }
    // 社外の人
    final out = g.mkPerson(0);
    g.staff.add(out);
    g.fire(out, 'poached');
    g.calcAll();
    _json = jsonEncode(g.toJson());
  }
  return Game.fromJson(jsonDecode(_json!) as Map<String, dynamic>, rng: ParkMiller(3))
    ..events.clear()
    ..calcAll();
}

const _views = ['exec:pres', 'exec', 'mgr', 'cand:grad', 'cand:mid', 'cand:poach', 'out', 'transfer', 'training'];

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
  ctl.setTab('people');
  final g = ctl.game!;
  for (final v in _views) {
    final p = v.split(':');
    ctl.closeSheet();
    if (v == 'transfer' || v == 'training') {
      ctl.setPeopleSeg('exec');
      final who = g.staff.firstWhere((x) => x.away == 0);
      ctl.selectPerson(who.id);
      await tester.pump();
      if (v == 'transfer') openTransfer(ctl, who);
      if (v == 'training') openTraining(ctl, who);
    } else {
      ctl.setPeopleSeg(p[0], src: p[0] == 'cand' && p.length > 1 ? p[1] : 'all');
      if (p.length > 1 && p[1] == 'pres') ctl.selectPerson(0);
      if (p[0] == 'exec' && p.length == 1) {
        final l = peopleOf(g, 'exec');
        if (l.isNotEmpty) ctl.selectPerson(l.first.id);
      }
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '$v ${size.width}x${size.height} $lang');
    if (lang == 'en') {
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        final s = w.text.toPlainText();
        expect(_cjk.hasMatch(s), isFalse, reason: '$v: 英語の画面に日本語「$s」');
      }
    }
    if (shoot) await shot(tester, key, 'people_${size.width.round()}x${size.height.round()}_${lang}_${v.replaceAll(':', '-')}', pixelRatio: 1.5);
  }
  ctl.closeSheet();
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);
  for (final size in const [Size(844, 390), Size(667, 375), Size(1194, 834)]) {
    for (final lang in const ['ja', 'en']) {
      testWidgets('人の画面 ${size.width.round()}×${size.height.round()}（$lang）：崩れない${lang == 'en' ? '・日本語が残らない' : ''}', (tester) async {
        await _walk(tester, size, lang, shoot: size.width != 667);
      });
    }
  }

  testWidgets('左の一覧の注意の印（引き抜かれそう・体を壊しそう）と、右の手（昇給・話を聞く）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ctl = GameController(prefs: prefs, newRandom: () => ParkMiller(5));
    ctl.game = _mid();
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(QuadrillionApp(controller: ctl));
    ctl.setTab('people');
    final g = ctl.game!;
    final low = g.staff.firstWhere((p) => g.payRatio(p) < payLowRatio);
    ctl.setPeopleSeg(g.biz.any((b) => b.mgr == low.id) ? 'mgr' : 'exec');
    ctl.selectPerson(low.id);
    await tester.pump();
    expect(find.byKey(ValueKey('pwarn-${low.id}-${Icons.directions_run.codePoint}')), findsOneWidget);
    expect(find.byKey(ValueKey('payratio-${low.id}')), findsOneWidget);
    g.hUsed = 0;
    await tester.tap(find.byKey(ValueKey('p-raise-${low.id}')));
    await tester.pump();
    expect(g.payRatio(low), greaterThanOrEqualTo(1));
    final k0 = low.known.length;
    await tester.tap(find.byKey(ValueKey('p-talk-${low.id}')));
    await tester.pump();
    expect(low.known.length, greaterThanOrEqualTo(k0));
    // 採用の「中途」を押すと、中途の候補が並ぶ
    await tester.tap(find.byKey(const ValueKey('hire-mid')));
    await tester.pump();
    expect(ctl.peopleSeg, 'cand');
    expect(ctl.candSrc, 'mid');
    expect(tester.takeException(), isNull);
  });
}
