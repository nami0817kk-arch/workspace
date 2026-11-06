import 'dart:math';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:basketball_career/ui/app.dart';
import 'package:basketball_career/ui/gm_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GmController> _controller([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  return GmController(prefs: await SharedPreferences.getInstance(), seedSource: Random(3));
}

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _closeDialogs(WidgetTester tester) async {
  while (find.text('OK').evaluate().isNotEmpty) {
    await tester.tap(find.text('OK').first);
    await tester.pumpAndSettle();
  }
}

/// 縦に流れる一覧(トレードの画面には、相手を選ぶ横の一覧もある)。
final _vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;

void main() {
  testWidgets('はじめの画面から就任し、開幕して20試合を進める', (tester) async {
    _size(tester, 430, 932);
    final c = await _controller();
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('バスケ編成室'), findsOneWidget);

    await tester.tap(find.text('GMに就任する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中位から上へ'));
    await tester.pumpAndSettle();
    // はじめてなら、先に遊び方
    expect(find.text('遊び方'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('はじめる'), 300);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.text('1年目のシーズン前'), findsOneWidget);

    await tester.tap(find.text('開幕する'));
    await tester.pumpAndSettle();
    expect(c.career!.phase, Phase.season);
    await tester.tap(find.text('次の20試合を進める'));
    await tester.pumpAndSettle();
    await _closeDialogs(tester);
    expect(c.career!.block, 1);
    expect(find.textContaining('この20試合'), findsOneWidget);
  });

  testWidgets('トレードの画面で選ぶと相手の反応が出て、釣り合えば成立する', (tester) async {
    _size(tester, 430, 932);
    final c = await _controller({'gmHowtoSeen': true});
    c.newCareer(Scenario.middle);
    final car = c.career!;
    await tester.pumpWidget(BasketballCareerApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('トレード'));
    await tester.pumpAndSettle();
    expect(find.textContaining('相手の反応が分かる'), findsOneWidget);
    // 相手のいちばん下の選手を、こちらのいちばんの選手で取りに行く(相手はきっと受ける)
    final them = car.teams[1];
    final theirs = them.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
    final ours = car.me.roster.reduce((a, b) => a.ovr >= b.ovr ? a : b);
    await tester.scrollUntilVisible(find.text(theirs.name), 200, scrollable: _vertical);
    await tester.tap(find.text(theirs.name).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(ours.name), 300, scrollable: _vertical);
    await tester.tap(find.text(ours.name).last);
    await tester.pumpAndSettle();
    final v = car.judge(TradeOffer(partner: 1, give: [ours.id], get: [theirs.id]));
    final ok = v.ok;
    expect(find.text(ok ? '受けてくれそう' : v.reason), findsOneWidget);
    if (ok) {
      await tester.tap(find.text('申し込む'));
      await tester.pumpAndSettle();
      expect(car.me.roster.any((p) => p.id == theirs.id), isTrue);
      expect(find.textContaining('トレードが成立した'), findsOneWidget);
    }
  });

  testWidgets('続きは保存され、起動するとはじめの画面から「続きから」で戻れる', (tester) async {
    _size(tester, 390, 844);
    final c = await _controller();
    c.newCareer(Scenario.rebuild);
    c.startSeason();
    await tester.pumpWidget(const SizedBox());
    final prefs = await SharedPreferences.getInstance();
    final c2 = GmController(prefs: prefs, seedSource: Random(4));
    await tester.pumpWidget(BasketballCareerApp(controller: c2));
    await tester.pumpAndSettle();
    expect(find.textContaining('続きから'), findsOneWidget);
    await tester.tap(find.textContaining('続きから'));
    await tester.pumpAndSettle();
    expect(find.text('次の20試合を進める'), findsOneWidget);
    expect(c2.career!.me.roster.length, c.career!.me.roster.length);
  });

  group('どの画面も、小さいスマホ・大きいスマホ・iPad ではみ出さない', () {
    const sizes = [Size(360, 640), Size(390, 844), Size(430, 932), Size(1032, 1376)];

    Future<void> show(WidgetTester tester, GmController c, Size s, {String? tab}) async {
      _size(tester, s.width, s.height);
      await tester.pumpWidget(BasketballCareerApp(controller: c));
      await tester.pumpAndSettle();
      await _closeDialogs(tester);
      if (tab != null) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '$s $tab ${c.career?.phase}');
      await tester.pumpWidget(const SizedBox());
    }

    for (final s in sizes) {
      testWidgets('$s', (tester) async {
        final c = await _controller({'gmHowtoSeen': true});
        await show(tester, c, s); // はじめの画面
        c.newCareer(Scenario.lastWindow);
        final car = c.career!;
        for (final tab in [null, 'チーム', 'トレード', '補強', 'リーグ']) {
          await show(tester, c, s, tab: tab);
        }
        c.startSeason();
        car.playBlock();
        await show(tester, c, s);
        await show(tester, c, s, tab: 'リーグ');
        while (car.phase == Phase.season) {
          car.playBlock();
        }
        await show(tester, c, s); // プレーオフ前
        car.playPlayoffs();
        await show(tester, c, s); // シーズン終了
        car.fired = false;
        car.toOffseason();
        await show(tester, c, s); // ドラフト
        while (car.phase == Phase.draft) {
          botStep(car);
        }
        await show(tester, c, s); // 契約
        await show(tester, c, s, tab: '補強');
        car.phase = Phase.over;
        await show(tester, c, s);
      });
    }
  });
}
