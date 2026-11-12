/// 横画面(844x390)でメインの4タブと練習画面がどう見えるかを PNG に書き出す。
///
/// **CI では回らない。** 見た目を目で確かめるための生成器で、実行すると
/// ファイルを書く。
///
///     flutter test tool/art/landscape_preview_test.dart --dart-define=OUT=<出力先>
///
/// 出力先を渡さなければ build/landscape_preview/ に書く。
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:soccer_manager/screens/training_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

import '../../test/support/app_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/landscape_preview');
const _size = Size(844, 390);
const _ratio = 2.0;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    // アイコンフォントを読まないと、全アイコンが豆腐(□)で写る。
    final root = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  });

  testWidgets('横画面の見本を書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = _ratio;
    tester.view.physicalSize = _size * _ratio;

    SharedPreferences.setMockInitialValues({});
    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState gameState;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      Tr.language = AppLanguage.japanese;
      monetization = MonetizationController(
        adService: NoOpAdService(),
        purchases: _StubPurchaseService(),
      );
      await monetization.initialize();
      gameState = GameState();
      await gameState.startNewGame('青嵐フットボールクラブ');
      for (var i = 0; i < 3; i++) {
        await gameState.playNextMatchday();
        if (gameState.isHalfTime) await gameState.playSecondHalf();
      }
      gameState.save!.firstRunGuideDismissed = true;
    });
    addTearDown(() => Tr.language = AppLanguage.system);

    final boundaryKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: gameState),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<MonetizationController>.value(
              value: monetization),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: navKey,
            locale: const Locale('ja'),
            theme: const SoccerManagerApp()
                .buildTheme(Brightness.light, boldText: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MainShell(),
          ),
        ),
      ),
    );
    await tester.pump();

    Future<void> shoot(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out).createSync(recursive: true);
        File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    // 4つのタブを順に撮る。横画面では左のレールで切り替わる。
    expect(find.byType(NavigationRail), findsOneWidget);
    final labels = ['ホーム', 'スカッド', '戦術', '順位表'];
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(find.descendant(
          of: find.byType(NavigationRail), matching: find.text(labels[i])));
      await tester.pump();
      await shoot('tab${i + 1}_${labels[i]}');
    }

    navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const TrainingScreen()));
    await tester.pump();
    await shoot('training');
    tester.takeException();
  });
}

class _StubPurchaseService implements PurchaseService {
  @override
  set onDelivered(
          Future<void> Function(String productId, String? purchaseId)? cb) =>
      _onDelivered = cb;
  // ignore: unused_field
  Future<void> Function(String productId, String? purchaseId)? _onDelivered;

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
