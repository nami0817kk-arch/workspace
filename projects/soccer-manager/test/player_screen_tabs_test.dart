import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/player_detail_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// 選手の画面が4つのタブに分かれ、どのタブも開けるかの検査
/// (2026-11-25: 契約のタブをやめて上の「操作」へ。経歴と人柄を分けた)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  testWidgets('概要・能力・経歴・人柄のタブと「操作」があり、どれも開ける', (tester) async {
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
    for (final t in ['概要', '能力', '経歴', '人柄']) {
      expect(find.text(t), findsOneWidget, reason: '$tのタブ');
    }
    expect(find.text('契約'), findsNothing, reason: '契約のタブは「操作」へ移した');
    expect(find.byKey(const ValueKey('player-actions')), findsOneWidget);
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    expect(find.textContaining('色: 80以上'), findsOneWidget,
        reason: '能力のタブの頭に色分けの一覧');
    expect(find.byKey(const ValueKey('position-map')), findsOneWidget,
        reason: '能力のタブに得意な位置の図');
    for (final t in ['経歴', '人柄']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tのタブで例外');
    }
    // 「操作」で一覧が開き、更新・移籍リスト・比べるが並ぶ。
    await tester.tap(find.byKey(const ValueKey('player-actions')));
    await tester.pumpAndSettle();
    for (final k in ['action-renew', 'action-transfer-list', 'action-compare']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    await tester.pump(GameState.persistDebounce);
  });

  testWidgets('他クラブの選手の詳しい画面も開ける(操作は比べるだけ)', (tester) async {
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
    final other = game.save!.league.teams
        .firstWhere((t) => t.id != game.save!.userTeamId);
    final p = other.players.first;
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
    expect(tester.takeException(), isNull);
    expect(find.text(other.name), findsWidgets, reason: '所属のクラブ名');
    expect(find.textContaining('分からない'), findsWidgets,
        reason: '他クラブの選手の伸びしろは見えない');
    await tester.tap(find.text('経歴'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('career-table')), findsOneWidget);
    expect(find.text(other.name), findsWidgets, reason: '今季の行はいまの所属');
    await tester.tap(find.byKey(const ValueKey('player-actions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('action-compare')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-renew')), findsNothing);
    await tester.pump(GameState.persistDebounce);
  });
}
