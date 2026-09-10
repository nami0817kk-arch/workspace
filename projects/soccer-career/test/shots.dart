// ignore_for_file: avoid_print
/// 画面を PNG に落として、目で見る道具。
///
/// `flutter test test/shots.dart` で走らせると `shots/` に書き出す。
/// ファイル名が `_test.dart` で終わらないので、CI の一括実行には入らない。
///
/// **見た目を触るときは、必ずこれを回して目で見る。**
/// テストでは気付けないものが多い（髪が鉢巻きに見えた件、
/// 見出しが4節ごとに同じ文になっていた件、`CustomPainter` の中の
/// 文字が同梱フォントに乗らず豆腐になっていた件——全部これで見つかった）。
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/club_identity.dart';
import 'package:soccer_career/ui/screens/create_player_screen.dart';
import 'package:soccer_career/ui/screens/hall_screen.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';

import 'ui_test.dart' as ui_test;

final shotKey = GlobalKey();

class _Repo implements SaveRepository {
  @override
  Future<CareerState?> load() async => null;
  @override
  Future<void> save(CareerState state) async {}
  @override
  Future<void> clear() async {}
}

ThemeData themeFor(dynamic club) => ThemeData(
  fontFamily: 'NotoSansJP',
  colorScheme: ColorScheme.fromSeed(
    seedColor: ClubIdentity.of(club).primary,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
);

Future<void> pump(WidgetTester tester, Widget home, ThemeData theme) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: shotKey,
      child: MaterialApp(theme: theme, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> dump(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('shots')..createSync();
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    print('wrote shots/$name.png');
  });
}

Future<void> loadFont() async {
  final loader = FontLoader('NotoSansJP');
  for (final path in [
    'assets/fonts/NotoSansJP-Regular.ttf',
    'assets/fonts/NotoSansJP-Bold.ttf',
  ]) {
    loader.addFont(
      Future.value(File(path).readAsBytesSync().buffer.asByteData()),
    );
  }
  await loader.load();
}

void main() {
  testWidgets('screens', (tester) async {
    await loadFont();
    final controller = await ui_test.newCareer(
      age: 24,
      hallRepository: ui_test.MemoryHall(),
    );
    for (var i = 0; i < 9; i++) {
      if (controller.pendingEvent != null) {
        await controller.resolveEvent(controller.pendingEvent!.choices.first);
      }
      await controller.simulateMatch();
    }
    // 代表ウィークで止まっていると、次節カードの対戦の絵が出ない。
    while (controller.state!.pendingInternational ||
        controller.state!.pendingCup != null) {
      await controller.simulateMatch();
    }

    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final theme = themeFor(controller.state!.club);
    await pump(tester, HubScreen(controller: controller), theme);
    await dump(tester, '01-hub-match');

    const tabs = ['選手', '育成', 'クラブ', '記録'];
    for (var i = 0; i < tabs.length; i++) {
      await tester.tap(find.widgetWithText(Tab, tabs[i]));
      await tester.pumpAndSettle();
      await dump(tester, '0${i + 2}-${tabs[i]}');
    }

    // 今週の練習のシート。毎週触る画面なので、必ず目で見る。
    await tester.tap(find.widgetWithText(Tab, '試合'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('変える'));
    await tester.pumpAndSettle();
    await dump(tester, '09-week');
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    // 切り札は個人技を覚えてから出る。普通に9節では届かないので、
    // 見た目を確かめるためにここで持たせる（撮るためだけの細工）。
    controller.state!.development = controller.state!.development.copyWith(
      signatures: Signature.values.toList(),
    );
    controller.startNextMatch();
    final started = controller.currentMatch;
    while (started != null && !started.isFinished && started.armable.isEmpty) {
      controller.choose(0);
    }
    await pump(tester, MatchScreen(controller: controller), theme);
    await dump(tester, '06-match');

    // 殿堂。引退させて、記録として残ったところを見る。
    await controller.retire();
    await pump(tester, HallScreen(controller: controller), theme);
    await dump(tester, '08-hall');

    final fresh = CareerController(
      repository: _Repo(),
      careerEngine: CareerEngine(random: Random(2)),
      matchEngine: MatchEngine(random: Random(2)),
      random: Random(2),
    );
    await pump(
      tester,
      CreatePlayerScreen(controller: fresh),
      ThemeData(useMaterial3: true, fontFamily: 'NotoSansJP'),
    );
    await dump(tester, '07-create');
  });
}
