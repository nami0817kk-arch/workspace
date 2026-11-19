/// タイトル画面と、節目の演出の見え方を書き出す（確認用）。
///
///     flutter test tool/art/moment_preview_test.dart --update-goldens
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/screens/start_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

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

  testWidgets('タイトル画面を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => Tr.language = AppLanguage.system);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(430, 932) * 3.0;
    SharedPreferences.setMockInitialValues({});

    late final SettingsController settings;
    late final GameState gameState;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      Tr.language = AppLanguage.japanese;
      gameState = GameState();
      await gameState.init();
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: gameState),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        theme: const SoccerManagerApp()
            .buildTheme(Brightness.light, boldText: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home: const StartScreen(),
      ),
    ));
    // 保存枠の読み込みと、背景の画像の読み込みを実時間で終わらせる。
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: '読み込み中のまま撮っている');
    expect(find.byType(Image), findsAtLeastNWidgets(1),
        reason: '背景の絵が入っていない');
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_title.png'));
  });

  testWidgets('節目の演出を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(880, 700) * 3.0;

    // home_screen の `_showSeasonStartReport` と同じ作りで並べる。
    Widget card(String title, String asset, List<String> lines) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.asset(asset, fit: BoxFit.cover),
                    ),
                  ),
                ),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.celebration,
                            size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            // home_screen と同じく、節目のときだけ評価への道を添える。
            TextButton(onPressed: () {}, child: const Text('このアプリを評価する')),
            TextButton(onPressed: () {}, child: const Text('閉じる')),
          ],
        );

    await tester.pumpWidget(MaterialApp(
      theme:
          const SoccerManagerApp().buildTheme(Brightness.light, boldText: false),
      debugShowCheckedModeBanner: false,
      home: Material(
        color: const Color(0xFFF2F2F5),
        child: Row(
          children: [
            Expanded(
              child: card('昇格！', 'assets/art/promotion.jpg', [
                '昇格達成！来シーズンは4部リーグに昇格します。理事会から補強予算3000万円が支給されました。',
              ]),
            ),
            Expanded(
              child: card('優勝！', 'assets/art/championship.jpg', [
                '5部リーグを制しました。来シーズンは4部リーグで戦います。',
                '年間最優秀監督賞を受賞しました！',
              ]),
            ),
          ],
        ),
      ),
    ));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_moments.png'));
  });
}
