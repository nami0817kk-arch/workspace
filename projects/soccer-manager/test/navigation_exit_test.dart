import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/screens/fixtures_screen.dart';
import 'package:soccer_manager/screens/lineup_screen.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/youth_intake_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

import 'support/stub_purchase_service.dart';

/// 開いた画面から必ず戻れることを、全画面について確かめる。
///
/// 「はじめの一歩」からスタメンを開くとホームに戻れなくなっていた。
/// ドロワーを持つ画面は AppBar が既定でハンバーガーを出し、戻るボタンを
/// 出さない。iOS では左端スワイプもドロワーが横取りするため、戻る手段が
/// 本当に無くなる。1画面直しただけでは、次に同じ作りの画面が増えたときに
/// また起きるので、押せる遷移先を全部まとめて見る。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  testWidgets('押して開ける画面には、すべて戻る手段がある', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    late final MonetizationController monetization;
    // testWidgets は疑似時間で動くため、保存を待つ準備は実時間で走らせる。
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      monetization = MonetizationController(
        adService: NoOpAdService(),
        purchases: StubPurchaseService(),
      );
      await monetization.initialize();
      game = GameState();
      await game.startNewGame('遷移FC');
    });
    Tr.language = AppLanguage.japanese;

    // ドロワーの遷移先に加えて、ホームやガイドのカードから直接開かれる画面。
    final targets = <String, WidgetBuilder>{
      for (final d in quickAccessDestinations) d.label: d.builder,
      'スタメン': (_) => const LineupScreen(),
      'スカッド': (_) => const SquadScreen(),
      'ユースインテーク': (_) => const YouthIntakeScreen(),
      // いまは下タブ専用。将来どこかから開かれたときに備えて一緒に見る。
      '日程・順位表': (_) => const FixturesScreen(),
    };

    // 画面は tap ではなく Navigator から直接開く。ボタンを押す形にすると、
    // pumpWidget を呼び直しても同じ形のツリーでは Navigator の状態が残り、
    // 前の画面が次の tap を遮る(最初そう書いて2画面目で落ちた)。
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: game),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<MonetizationController>.value(
              value: monetization),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: Text('土台'))),
        ),
      ),
    );
    await tester.pump();

    final stuck = <String>[];
    for (final entry in targets.entries) {
      navKey.currentState!.push(MaterialPageRoute<void>(builder: entry.value));
      // settle は待たない。終わらないアニメーションを持つ画面で止まる。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.takeException();

      final hasBack = find.byType(BackButton).evaluate().isNotEmpty ||
          find.byIcon(Icons.arrow_back).evaluate().isNotEmpty ||
          find.byIcon(Icons.arrow_back_ios).evaluate().isNotEmpty ||
          find.byIcon(Icons.close).evaluate().isNotEmpty;
      if (!hasBack) stuck.add(entry.key);

      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.takeException();
    }

    // 1画面で止めず全部見る。まとめて出た方が直す順番を決めやすい。
    expect(stuck, isEmpty, reason: '戻る手段が無い画面: ${stuck.join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
