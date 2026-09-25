import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/screens/lineup_screen.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/state/game_state.dart';

/// ホームやガイドから開いた画面から、戻れることの検査。
///
/// スタメンとスカッドは下タブの一員でもあり、ホーム・「はじめの一歩」・
/// 「次にやること」からも直接開かれる。ドロワーを持つ画面は AppBar が
/// 既定でハンバーガーを出し、戻るボタンを出さない。しかも iOS では
/// 左端スワイプをドロワーが横取りするため、戻る手段が本当に無くなる。
/// 実際、「はじめの一歩」からスタメンを開くとホームに戻れなくなっていた。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  /// 画面を包む。SettingsController と GameState の準備は実時間で行う
  /// 必要があるため、呼び出し側で runAsync してから渡す。
  Widget app(GameState game, SettingsController settings, Widget home) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  /// testWidgets は疑似時間で動くため、SharedPreferences を待つ処理は
  /// そのままでは完了しない(pumpWidget の前で止まる)。準備だけ実時間で走らせる。
  Future<(GameState, SettingsController)> prepare(WidgetTester tester) async {
    late final GameState game;
    late final SettingsController settings;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      game = GameState();
      await game.startNewGame('戻れるFC');
    });
    Tr.language = AppLanguage.japanese;
    return (game, settings);
  }

  for (final entry in {
    'スタメン': const LineupScreen(),
    'スカッド': const SquadScreen(),
  }.entries) {
    testWidgets('${entry.key}を開いたら戻るボタンがある', (tester) async {
      final (game, settings) = await prepare(tester);
      await tester.pumpWidget(app(
        game,
        settings,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => entry.value),
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('開く'));
      // pumpAndSettle は使わない。進捗バーなどが回り続ける画面では
      // 永久に落ち着かず、テストが止まる(実際に止まった)。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BackButton), findsOneWidget,
          reason: '${entry.key}から戻る手段が無い');

      // 実際に戻れること。ボタンがあっても効かなければ意味がない。
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('開く'), findsOneWidget, reason: '押しても戻らない');
    });
  }

  testWidgets('下タブの中では戻るボタンを出さない', (tester) async {
    // タブとして表示されているときに戻るボタンが出ると、どこへ戻るのか
    // 分からないものが増える。
    final (game, settings) = await prepare(tester);
    await tester.pumpWidget(app(game, settings, const MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BackButton), findsNothing);
  });
}
