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
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/state/career_controller.dart';
import 'package:soccer_career/ui/club_identity.dart';
import 'package:soccer_career/ui/screens/create_player_screen.dart';
import 'package:soccer_career/ui/screens/guide_screen.dart';
import 'package:soccer_career/ui/screens/hall_screen.dart';
import 'package:soccer_career/ui/screens/hub_screen.dart';
import 'package:soccer_career/ui/screens/match_screen.dart';
import 'package:soccer_career/ui/screens/season_end_screen.dart';

import 'ui_test.dart' as ui_test;

final shotKey = GlobalKey();

/// 書き出した名前。**撮れていないことは、撮った絵を見るまで分からない**——
/// 06-match が真っ白のまま書き出され、06b-result は黙って飛ばされていた。
final written = <String>{};

class _Repo implements SaveRepository {
  @override
  Future<CareerState?> load() async => null;
  @override
  Future<void> save(CareerState state) async {}
  @override
  Future<void> clear() async {}
}

ThemeData themeFor(dynamic club, {Brightness brightness = Brightness.light}) =>
    ThemeData(
      fontFamily: 'NotoSansJP',
      colorScheme: ColorScheme.fromSeed(
        seedColor: ClubIdentity.of(club).primary,
        brightness: brightness,
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
    written.add(name);
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

/// 局面が立つ週まで進めてから、試合を組む。
///
/// **出られない週に `startNextMatch` を呼ぶと、局面ゼロの「終わった試合」が返る。**
/// 離脱・出場停止・登録外・構想外のどれでもそうなる。撮影はそれに気付かず
/// 真っ白な主画面を書き出していた——このゲームで一番大事な画面が、
/// 何週間も撮れていなかった。
Future<void> startPlayableMatch(CareerController controller) async {
  for (var i = 0; i < 80; i++) {
    while (controller.state!.pendingInternational ||
        controller.state!.pendingCup != null) {
      await controller.simulateMatch();
    }
    if (controller.state!.seasonFinished || controller.state!.retired) break;
    controller.startNextMatch();
    final match = controller.currentMatch;
    if (match != null && !match.isFinished) return;
    await controller.simulateMatch();
  }
  throw StateError('局面の立つ試合に辿り着けなかった');
}

/// 撮り漏らしを落とす。**撮れていないものは、絵を見るまで分からない。**
void requireShots(Iterable<String> names) {
  final missing = names.where((n) => !written.contains(n)).toList();
  if (missing.isNotEmpty) {
    throw StateError('撮れていない画面: ${missing.join(", ")}');
  }
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

    // 育てる方向は既定で空なので、そのままだと育成タブの
    // 「積み上げ」「上限」が一行も撮れない。3つ選んでおく。
    for (final detail in [
      Detail.finishing,
      Detail.shortPassing,
      Detail.tackling,
    ]) {
      await controller.toggleFocus(detail);
    }

    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final theme = themeFor(controller.state!.club);
    await pump(tester, HubScreen(controller: controller), theme);
    await dump(tester, '01-hub-match');

    // 節に割ってあるタブは、札ごとに撮る。
    // 片方だけ撮っていると、もう片方の崩れは一生見えない。
    const tabs = {
      '選手': ['能力', '人となり'],
      '育成': ['今週決める', '長い目で狙う'],
      'クラブ': ['立ち位置', 'この国と、世界'],
      '記録': ['今季', 'これまで'],
    };
    var n = 2;
    for (final entry in tabs.entries) {
      await tester.tap(find.widgetWithText(Tab, entry.key));
      await tester.pumpAndSettle();
      for (final section in entry.value) {
        await tester.tap(find.text(section));
        await tester.pumpAndSettle();
        await dump(tester, '0$n-${entry.key}-$section');
      }
      n++;
    }

    // 個人技を狙うカード。育成タブの下のほうにあるので、標準の高さでは
    // 一度も撮れていなかった。候補を開いた状態で撮る。
    await tester.tap(find.widgetWithText(Tab, '育成'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('狙う技を選ぶ'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('狙う技を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('狙う技を選ぶ'));
    await tester.pumpAndSettle();
    await dump(tester, '10-aim');

    // 今週の練習のシート。毎週触る画面なので、必ず目で見る。
    await tester.tap(find.widgetWithText(Tab, '今週'));
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
    await startPlayableMatch(controller);
    await pump(tester, MatchScreen(controller: controller), theme);
    await dump(tester, '06-match');

    // 手を選んだ直後。結果のカード（ミニピッチにボールの行方）を見る。
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    await dump(tester, '06b-result');

    // 切り札を構えられる局面。**残り1つになったら止める**——
    // 以前は局面が尽きるまで進めていたので、armable が出ない試合では
    // 「終わった試合」を主画面として書き出していた。
    final match = controller.currentMatch!;
    while (!match.isFinished &&
        match.armable.isEmpty &&
        match.currentIndex < match.scenarios.length - 1) {
      controller.choose(0);
    }
    if (!match.isFinished && match.armable.isNotEmpty) {
      await pump(tester, MatchScreen(controller: controller), theme);
      await dump(tester, '06c-armed');
    }

    // **記録タブは、ダークモードで一度も撮っていなかった。**
    // 暗いほうで崩れていても、明るいほうの絵を見ている限り分からない。
    final dark = themeFor(controller.state!.club, brightness: Brightness.dark);
    await pump(tester, HubScreen(controller: controller), dark);
    await tester.tap(find.widgetWithText(Tab, '記録'));
    await tester.pumpAndSettle();
    await dump(tester, '12-dark-記録');

    // 殿堂。引退させて、記録として残ったところを見る。
    await controller.retire();
    await pump(tester, HallScreen(controller: controller), theme);
    await dump(tester, '08-hall');
    await pump(tester, HallScreen(controller: controller), dark);
    await dump(tester, '12-dark-殿堂');

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
    await pump(
      tester,
      CreatePlayerScreen(controller: fresh),
      ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSansJP',
        brightness: Brightness.dark,
      ),
    );
    await dump(tester, '12-dark-create');

    requireShots([
      '01-hub-match',
      '02-選手-能力',
      '02-選手-人となり',
      '03-育成-今週決める',
      '03-育成-長い目で狙う',
      '04-クラブ-立ち位置',
      '04-クラブ-この国と、世界',
      '05-記録-今季',
      '05-記録-これまで',
      '06-match',
      '06b-result',
      '07-create',
      '08-hall',
      '09-week',
      '10-aim',
      '12-dark-記録',
      '12-dark-殿堂',
      '12-dark-create',
    ]);
  });

  /// 初めて開いた人の目で通す。作った直後・出来事・シーズン終了・
  /// ガイド・ダークモード。標準の高さ（844）で撮るのは、
  /// 「開いてすぐ何が見えるか」をそのまま見るため。
  testWidgets('first run', (tester) async {
    await loadFont();
    final controller = await ui_test.newCareer(
      age: 17,
      hallRepository: ui_test.MemoryHall(),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final theme = themeFor(controller.state!.club);
    await pump(tester, HubScreen(controller: controller), theme);
    await dump(tester, '11-first-hub');

    // ダークモード。撮ったことが一度も無かった。
    await pump(
      tester,
      HubScreen(controller: controller),
      themeFor(controller.state!.club, brightness: Brightness.dark),
    );
    await dump(tester, '12-dark-hub');
    for (final tab in ['選手', '育成', 'クラブ']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      await dump(tester, '12-dark-$tab');
    }

    // 出来事が来るまで進める。
    while (controller.pendingEvent == null &&
        !controller.state!.seasonFinished) {
      await controller.simulateMatch();
    }
    await pump(tester, HubScreen(controller: controller), theme);
    // タブは前の撮影の位置が残るので、試合タブへ戻す。
    await tester.tap(find.widgetWithText(Tab, '今週'));
    await tester.pumpAndSettle();
    await dump(tester, '13-event');

    await startPlayableMatch(controller);
    await pump(
      tester,
      MatchScreen(controller: controller),
      themeFor(controller.state!.club, brightness: Brightness.dark),
    );
    await dump(tester, '14-dark-match');
    await controller.simulateMatch();

    // シーズン終了まで。
    while (!controller.state!.seasonFinished) {
      if (controller.pendingEvent != null) {
        await controller.resolveEvent(controller.pendingEvent!.choices.first);
      }
      await controller.simulateMatch();
    }
    tester.view.physicalSize = const Size(390, 2400);
    await pump(tester, SeasonEndScreen(controller: controller), theme);
    await dump(tester, '15-season-end');
    await pump(
      tester,
      SeasonEndScreen(controller: controller),
      themeFor(controller.state!.club, brightness: Brightness.dark),
    );
    await dump(tester, '12-dark-season-end');

    await pump(tester, const GuideScreen(), theme);
    await dump(tester, '16-guide');

    requireShots([
      '11-first-hub',
      '12-dark-hub',
      '13-event',
      '14-dark-match',
      '15-season-end',
      '12-dark-season-end',
      '16-guide',
    ]);
  });
}
