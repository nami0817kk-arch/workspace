/// 「今年の予算の配り方」のカードを、置かれている画面(経営 → 概要)ごと撮る。
///
///     flutter test tool/screenshots/budget_card_test.dart --update-goldens \
///       --dart-define=LOOK=light --dart-define=LANG=ja --dart-define=DEVICE=phone
///
/// - `LOOK=light|dark`(既定 dark)
/// - `LANG=ja|en`(既定 ja)
/// - `DEVICE=phone|pad`(既定 phone。phone は 844x390、pad は 1194x834)
///
/// 書き出し先は `build/budget_card/<DEVICE>_<LOOK>_<LANG>/`。開いた直後・
/// 配り直している途中(残りあり)・型を押した直後を、カードの上と下で撮る。
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
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/budget_plan_card.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';

const _look = String.fromEnvironment('LOOK', defaultValue: 'dark');
const _lang = String.fromEnvironment('LANG', defaultValue: 'ja');
const _device = String.fromEnvironment('DEVICE', defaultValue: 'phone');
const _en = _lang == 'en';
const _logical = _device == 'pad' ? Size(1194, 834) : Size(844, 390);
const _ratio = _device == 'pad' ? 2.0 : 3.0;

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
  final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('予算のカードを撮る ($_device $_look $_lang)', (tester) async {
    addTearDown(tester.view.reset);
    debugDisableShadows = false;
    tester.view.devicePixelRatio = _ratio;
    tester.view.physicalSize = _logical * _ratio;
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => Tr.language = AppLanguage.system);

    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState gameState;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      Tr.language = _en ? AppLanguage.english : AppLanguage.japanese;
      monetization = MonetizationController(
        adService: NoOpAdService(),
        purchases: _StubPurchaseService(),
      );
      await monetization.initialize();
      gameState = GameState();
      await gameState.startNewGame(_en ? 'Seiran FC' : '青嵐フットボールクラブ');
      await gameState.simulateAheadMatchdays(3);
      gameState.save!.pendingMoments.clear();
      gameState.save!.firstRunGuideDismissed = true;
    });

    final app = const SoccerManagerApp();
    final brightness = _look == 'light' ? Brightness.light : Brightness.dark;

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: gameState),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
      ],
      child: MaterialApp(
        locale: const Locale(_lang),
        theme: app.buildTheme(brightness, boldText: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: _logical,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: LandscapeScale(
              child: FmThemeScope(
                light: app.buildTheme(Brightness.light, boldText: false),
                dark: app.buildTheme(Brightness.dark, boldText: false),
                child: const MainShell(),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final menu = find.text(_en ? 'Finance' : '経営').hitTestable();
    expect(menu, findsWidgets, reason: '左のメニューに経営が無い');
    await tester.tap(menu.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 350));

    final card = find.byType(BudgetPlanCard);
    expect(card, findsOneWidget);
    Finder key(String k) => find.byKey(ValueKey(k));

    Future<void> shot(String name, {required bool bottom}) async {
      await Scrollable.ensureVisible(
        tester.element(card),
        alignment: bottom ? 1.0 : 0.0,
        alignmentPolicy: bottom
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.explicit,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: '$name の描画で例外');
      await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
              '../../build/budget_card/${_device}_${_look}_$_lang/$name.png'));
    }

    Future<void> press(String k) async {
      await tester.ensureVisible(key(k));
      await tester.pump();
      await tester.tap(key(k));
      await tester.pump(const Duration(milliseconds: 350));
    }

    await shot('1_saved_top', bottom: false);
    await shot('1_saved_bottom', bottom: true);

    await press('budget-minus-dividend');
    await press('budget-minus-dividend');
    await press('budget-plus-signing');
    await shot('2_editing_top', bottom: false);
    await shot('2_editing_bottom', bottom: true);

    await press('budget-preset-youth');
    await shot('3_preset_top', bottom: false);
    await shot('3_preset_bottom', bottom: true);

    debugDisableShadows = true;
  });
}

class _StubPurchaseService implements PurchaseService {
  @override
  set onDelivered(
          Future<void> Function(String productId, String? purchaseId)?
              callback) =>
      onDeliveredCallback = callback;

  Future<void> Function(String productId, String? purchaseId)?
      onDeliveredCallback;

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<String?> priceLabel() async => null;
  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;
  @override
  Future<String?> priceLabelFor(FundsPack pack) async => null;
  @override
  Future<PurchaseOutcome> buyFundsPack(FundsPack pack) async =>
      PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}
