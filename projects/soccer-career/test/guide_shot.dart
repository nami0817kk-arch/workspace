/// 遊び方ガイドを、畳んだ状態と開いた状態の両方で書き出す。
///
///     flutter test test/guide_shot.dart
///
/// **手動実行の道具。** 書き出し先 `shots/` は gitignore 済み。
library;

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/ui/app_theme.dart';
import 'package:soccer_career/ui/screens/guide_screen.dart';

final _key = GlobalKey();

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('NotoSansJP');
  for (final path in [
    'assets/fonts/NotoSansJP-Regular.ttf',
    'assets/fonts/NotoSansJP-Bold.ttf',
  ]) {
    loader.addFont(
      Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

Future<void> _dump(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('shots').createSync(recursive: true);
    File('shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    print('wrote shots/$name.png (${image.width}x${image.height})');
  });
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  });

  testWidgets('遊び方ガイドを書き出す', (tester) async {
    debugDisableShadows = false;
    try {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2600);

      await tester.pumpWidget(
        RepaintBoundary(
          key: _key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(
              const Color(0xFF1B5E3F),
              Brightness.light,
              fontFamily: 'NotoSansJP',
            ),
            home: const GuideScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _dump(tester, 'guide-list');

      await tester.tap(find.text('試合で選ぶ'));
      await tester.pumpAndSettle();
      await _dump(tester, 'guide-open');

      await tester.tap(find.text('試合で選ぶ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1週間の流れ'));
      await tester.pumpAndSettle();
      await _dump(tester, 'guide-week');

      await tester.tap(find.text('1週間の流れ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('評価点と出場機会'));
      await tester.pumpAndSettle();
      await _dump(tester, 'guide-rating');
    } finally {
      debugDisableShadows = true;
    }
  });
}
