import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/app/progress.dart';
import 'package:goso_boat/app/settings.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/main.dart';
import 'package:goso_boat/monetization/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Level> _levels() {
  final data = jsonDecode(File('assets/levels.json').readAsStringSync()) as Map<String, Object?>;
  return (data['levels']! as List).map((e) => Level.fromJson(e as Map<String, Object?>)).toList();
}

Future<Progress> _progress([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  return Progress.open(_levels());
}

void main() {
  testWidgets('はじめる → 紹介 → 乗せて渡す → 1面をクリア', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // 広告SDKはテストに無いので、ヒントは「広告を消した」状態で使う
    final progress = await _progress({'adFree': true});
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true), locale: const Locale('ja')));
    await tester.tap(find.text('はじめる'));
    // 待機の揺れが止まらないので pumpAndSettle は使えない
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 舞台1の紹介が出る
    expect(find.text('囚人を向こう岸へ'), findsOneWidget);
    await tester.tap(find.text('わかった'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('最短3回で★3'), findsOneWidget, reason: '面の始まりの札');
    await tester.pump(const Duration(seconds: 2));

    // 1-1 は 警官3・囚人1・定員3、最短3回。ヒントに従って渡しきる
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('ヒント'));
      await tester.pump(const Duration(milliseconds: 400));
      final up = find.text('向こう岸へ');
      await tester.tap(up.evaluate().isNotEmpty ? up : find.text('手前の岸へ'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('全員護送'), findsOneWidget);
    expect(progress.stars(progress.levels.first), 2, reason: 'ヒントを使ったので星2');
    expect(find.text('自己ベスト 3回'), findsOneWidget);
    expect(find.text('1回目の挑戦でクリア！'), findsOneWidget);
    expect(find.text('一手も戻さずにクリア'), findsOneWidget);
    expect(find.textContaining('タイム '), findsOneWidget);
    // お手本の再生はしない（2026-09-27 ユーザー判断: 答えを見せると繰り返し遊ぶ理由が減る）
    expect(find.text('お手本を見る'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('警官を全員乗せて出すと、残した囚人が逃げる', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final progress = await _progress({'intro.1': true});
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true), locale: const Locale('ja')));
    await tester.tap(find.text('はじめる'));
    // 待機の揺れが止まらないので pumpAndSettle は使えない
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    for (final label in ['警官、手前の岸', '警官、手前の岸', '警官、手前の岸']) {
      await tester.tap(find.bySemanticsLabel(label).first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('向こう岸へ'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('脱走された'), findsOneWidget);
    expect(find.textContaining('囚人だけが残った'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Text && ['あばよ！', 'お先に〜', 'へへっ', '自由だー！'].contains(w.data)), findsOneWidget, reason: '捨てぜりふ');
    expect(progress.tries(progress.levels.first), 1);
    // 逃げられたら「最初から」だけ（一手戻すは出さない。2026-09-27 ユーザー決定）
    expect(find.text('一手戻す'), findsOneWidget, reason: '上の段のボタン（押せない）だけで、札には出さない');
    await tester.tap(find.text('最初から').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('脱走された'), findsNothing);
    expect(find.text('0回'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('ステージ選択: 1面目だけ開いている', (tester) async {
    final semantics = tester.ensureSemantics();
    final progress = await _progress();
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true), locale: const Locale('ja')));
    await tester.tap(find.text('ステージを選ぶ'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1-1'), findsOneWidget);
    expect(find.bySemanticsLabel('1-2、まだ遊べない'), findsOneWidget);
    semantics.dispose();
  });

  test('評価のお願い: 舞台の最後の面を星2以上で解いたときだけ、舞台ごとに1回', () async {
    final progress = await _progress();
    final w1 = progress.levels.where((l) => l.world == 1).toList();
    expect(progress.shouldAskReview(w1.first, 3), isFalse, reason: '舞台の途中');
    expect(progress.shouldAskReview(w1.last, 1), isFalse, reason: '星1');
    expect(progress.shouldAskReview(w1.last, 2), isTrue);
    await progress.markReviewAsked(1);
    expect(progress.shouldAskReview(w1.last, 3), isFalse, reason: '同じ舞台では1回だけ');
    final w4 = progress.levels.where((l) => l.world == 4).toList();
    expect(progress.shouldAskReview(w4.last, 3), isFalse, reason: '舞台4以降は出さない');
  });

  testWidgets('英語: 端末が日本語以外なら英語で出る（逃げたときの文も英語）', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final progress = await _progress();
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true), locale: const Locale('en')));
    expect(find.text('Prison Ferry'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Get them across'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 400));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Officer, near bank').first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('To far bank'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('They escaped!'), findsOneWidget);
    expect(find.text('Prisoners were left alone on the near bank.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('端末の言語で選ぶ: 日本語以外はすべて英語', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final progress = await _progress();
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true)));
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('設定: 効果音と振動の切り替え、進み具合を消しても広告なしは残る', (tester) async {
    final progress = await _progress({'stars.1-1': 3, 'intro.1': true, 'adFree': true});
    final settings = GameSettings(progress.prefsForTest, silent: true);
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: settings, locale: const Locale('ja')));
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.text('効果音'), findsOneWidget);
    await tester.tap(find.text('効果音'));
    await tester.pumpAndSettle();
    expect(settings.sound, isFalse);
    await tester.tap(find.text('進み具合を消す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('消す'));
    await tester.pumpAndSettle();
    expect(progress.stars(progress.levels.first), 0);
    expect(progress.seenIntro(1), isFalse);
    expect(Monetization(progress.prefsForTest).adFree, isTrue, reason: '購入は消さない');
  });

  testWidgets('中断した盤面から続けられる／長押しで役の説明', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    // 1-1（警官3・囚人1）で、警官1と囚人1を向こう岸に渡した途中
    final progress = await _progress({
      'intro.1': true,
      'resume.1-1': '{"places":[1,0,0,1],"boat":1,"trips":1,"hint":false}',
    });
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true), locale: const Locale('ja')));
    await tester.tap(find.text('はじめる'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1回'), findsOneWidget);
    expect(find.text('続きから・1回'), findsOneWidget);
    expect(find.bySemanticsLabel('警官、向こう岸'), findsOneWidget);

    await tester.longPress(find.bySemanticsLabel('警官、手前の岸').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('警官：見張り1人分。舟を漕げる'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    semantics.dispose();
  });

  testWidgets('ホームに階級と次の階級までの星', (tester) async {
    final progress = await _progress();
    await tester.pumpWidget(GosoBoatApp(progress: progress, money: Monetization(progress.prefsForTest), settings: GameSettings(progress.prefsForTest, silent: true), locale: const Locale('ja')));
    expect(find.text('見習い・次の階級まで ★10'), findsOneWidget);
  });
}
