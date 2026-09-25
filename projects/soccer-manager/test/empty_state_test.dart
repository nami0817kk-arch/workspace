import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

import 'support/stub_purchase_service.dart';

/// 始めたばかりの状態で、どの画面にも「何か」が書いてあることの検査。
///
/// 表彰・シーズン成績・殿堂・ニュースなどは、シーズンを1つ終えるまで中身が
/// 無い。そこで真っ白な画面を出すと、壊れているのか、まだ早いのかが区別でき
/// ない。始めた人が最初に開くのは、まさにその状態の画面になる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Tr.language = AppLanguage.system);

  testWidgets('新規開始の状態でも、どの画面にも文字が出ている', (tester) async {
    late final GameState game;
    late final SettingsController settings;
    late final MonetizationController monetization;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      monetization = MonetizationController(
        adService: NoOpAdService(),
        purchases: StubPurchaseService(),
      );
      await monetization.initialize();
      game = GameState();
      await game.startNewGame('空っぽFC');
    });
    Tr.language = AppLanguage.japanese;

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

    final blank = <String>[];
    for (final dest in quickAccessDestinations) {
      navKey.currentState!.push(MaterialPageRoute<void>(builder: dest.builder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.takeException();

      // 見出し(AppBarのタイトル)以外に文字があるか。タイトルしか無い画面は、
      // 開いた人から見れば空白と変わらない。
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .where((t) => t.trim().isNotEmpty && t != dest.label)
          .toList();
      if (texts.isEmpty) blank.add(dest.label);

      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.takeException();
    }

    expect(blank, isEmpty, reason: '始めた直後に中身が空白になる画面: ${blank.join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
