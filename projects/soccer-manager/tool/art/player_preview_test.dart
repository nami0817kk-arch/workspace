/// 選手詳細の見え方を書き出す（確認用）。
///
/// この画面は掲載画像に入らないので、ここで見ないと誰も見ないまま出る。
///
///     flutter test tool/art/player_preview_test.dart --update-goldens
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
import 'package:soccer_manager/screens/player_detail_screen.dart';
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

  testWidgets('選手詳細を書き出す', (tester) async {
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
      await gameState.startNewGame('青嵐フットボールクラブ');
      // 何節か進めておく。真っさらだと評点も成長も空で、
      // 画面の半分が「—」になる。
      for (var i = 0; i < 6; i++) {
        await gameState.playNextMatchday();
        if (gameState.isHalfTime) await gameState.playSecondHalf();
      }
    });

    final player = gameState.userTeam.players
        .reduce((a, b) => a.overall >= b.overall ? a : b);

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
        home: PlayerDetailScreen(playerId: player.id),
      ),
    ));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: '読み込み中のまま撮っている');
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('../../_player.png'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
