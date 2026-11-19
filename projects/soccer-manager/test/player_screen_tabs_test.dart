import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/player_detail_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// 選手の画面が5つのタブに分かれ、どのタブも開けるかの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  testWidgets('概要・能力・契約・人柄・経歴のタブがあり、どれも開ける', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('タブFC');
    });
    Tr.language = AppLanguage.japanese;
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final p = game.userTeam.players.first;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlayerDetailScreen(playerId: p.id),
      ),
    ));
    await tester.pumpAndSettle();
    for (final t in ['概要', '能力', '契約', '人柄', '経歴']) {
      expect(find.text(t), findsOneWidget, reason: '$tのタブ');
    }
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    expect(find.textContaining('色: 80以上'), findsOneWidget,
        reason: '能力のタブの頭に色分けの一覧');
    for (final t in ['契約', '人柄', '経歴']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tのタブで例外');
    }
    await tester.pump(GameState.persistDebounce);
  });
}
