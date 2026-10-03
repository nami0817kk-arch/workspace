/// 初回チュートリアルの挿絵の見え方を1枚にまとめて書き出す（確認用）。
///
///     flutter test tool/art/onboarding_preview_test.dart --update-goldens
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/widgets/onboarding_art.dart';

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bundled = {
    'NotoSansJP': ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf'],
    'ShipporiMincho': [
      'ShipporiMincho-Regular.ttf',
      'ShipporiMincho-SemiBold.ttf',
    ],
  };
  for (final entry in bundled.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  final icons =
      File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!icons.existsSync()) {
    fail('アイコンフォントが見つからない: ${icons.path}');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('挿絵の見本を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1000, 340) * 3.0;

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          const SoccerManagerApp().buildTheme(Brightness.light, boldText: false),
      home: Material(
        color: const Color(0xFFF2F2F5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final kind in OnboardingArtKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      OnboardingArt(kind: kind, width: 178),
                      const SizedBox(height: 6),
                      Text(kind.name),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_onboarding.png'));
  });
}
