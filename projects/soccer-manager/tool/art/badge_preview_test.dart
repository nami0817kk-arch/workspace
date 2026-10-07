/// 実績の記章の見え方を1枚にまとめて書き出す（確認用）。
///
///     flutter test tool/art/badge_preview_test.dart --update-goldens
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/achievement_engine.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/widgets/achievement_badge.dart';

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
  // アイコンフォントを読まないと、記章の印がすべて豆腐(□)になる。
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

  testWidgets('記章の見本を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1040, 460) * 3.0;

    final all = AchievementEngine.all;

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          const SoccerManagerApp().buildTheme(Brightness.light, boldText: false),
      home: Material(
        color: const Color(0xFFF2F2F5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 達成済み（実寸 44）。種別ごとに色と印が変わる。
              for (var row = 0; row < 3; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      for (var i = row * 11;
                          i < (row + 1) * 11 && i < all.length;
                          i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: AchievementBadge(
                              achievement: all[i], unlocked: true),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              // 未達成と、拡大。
              Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AchievementBadge(
                          achievement: all[i * 5], unlocked: false),
                    ),
                  const SizedBox(width: 20),
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: AchievementBadge(
                          achievement: all[i * 6], unlocked: true, size: 110),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_badges.png'));
  });
}
