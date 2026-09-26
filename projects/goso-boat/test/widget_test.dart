import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goso_boat/app/progress.dart';
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/main.dart';
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
    final progress = await _progress();
    await tester.pumpWidget(GosoBoatApp(progress: progress));
    await tester.tap(find.text('はじめる'));
    // 待機の揺れが止まらないので pumpAndSettle は使えない
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 舞台1の紹介が出る
    expect(find.text('囚人を向こう岸へ'), findsOneWidget);
    await tester.tap(find.text('わかった'));
    await tester.pump(const Duration(milliseconds: 400));

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
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('警官を全員乗せて出すと、残した囚人が逃げる', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final progress = await _progress({'intro.1': true});
    await tester.pumpWidget(GosoBoatApp(progress: progress));
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
    await tester.tap(find.text('一手戻す').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('脱走された'), findsNothing);
  });

  testWidgets('ステージ選択: 1面目だけ開いている', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final progress = await _progress();
    await tester.pumpWidget(GosoBoatApp(progress: progress));
    await tester.tap(find.text('ステージを選ぶ'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1-1'), findsOneWidget);
    expect(find.bySemanticsLabel('1-2、まだ遊べない'), findsOneWidget);
  });
}
