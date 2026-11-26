/// 課金アイテム「広告を消す」の審査用スクリーンショットを生成する。
///
///     flutter test tool/screenshots/iap_review_test.dart --update-goldens
///
/// App Store Connect の課金アイテムには「審査に関する情報」のスクリーン
/// ショットが要り、買うボタンが写っていなければならない。掲載画像
/// (capture_test.dart)は値段を写さない決まりなので、別に撮る。
///
/// 写すのは設定画面にある実物の [SupporterSection]。値段は日本の価格
/// (370円)を入れて、ボタンの文言が実機と同じ「広告を消す(¥370)」になるように
/// する。寸法は iPhone 中型の横向き(2622x1206)。
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/supporter_section.dart';

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 見出しは明朝(ShipporiMincho)。読まないと「設定」が豆腐(□□)になる(なった)。
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
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await iconLoader.load();
}

void main() {
  setUpAll(_loadFonts);

  for (final (language, code, price) in [
    (AppLanguage.japanese, 'ja', '¥370'),
    (AppLanguage.english, 'en', r'$1.99'),
  ]) {
    testWidgets('課金の審査用スクリーンショット ($code)', (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(() => Tr.language = AppLanguage.system);
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(874, 402) * 3.0;
      SharedPreferences.setMockInitialValues({});

      late final SettingsController settings;
      late final MonetizationController monetization;
      await tester.runAsync(() async {
        settings = SettingsController();
        await settings.init();
        Tr.language = language;
        monetization = MonetizationController(
          adService: NoOpAdService(),
          purchases: _PricedPurchaseService(price),
        );
        await monetization.initialize();
      });

      const app = SoccerManagerApp();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<MonetizationController>.value(
              value: monetization),
        ],
        child: MaterialApp(
          locale: Locale(code),
          theme: app.buildTheme(Brightness.light, boldText: false),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(title: Text(Tr.pick('設定', 'Settings'))),
            body: const SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 120),
              child: SupporterSection(),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // 日本語は「¥」が全角の「￥」に置き換わる(MonetizationController.displayPrice)。
      final button = code == 'ja' ? RegExp(r'^広告を消す（[¥￥]370）$') : RegExp(r'^Remove ads \(\$1\.99\)$');
      expect(find.textContaining(button), findsOneWidget,
          reason: '買うボタンに値段が出ていない');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../marketing/iap_review/remove_ads_$code.png'),
      );
    });
  }
}

class _PricedPurchaseService implements PurchaseService {
  _PricedPurchaseService(this.price);
  final String price;

  @override
  set onDelivered(
      Future<void> Function(String productId, String? purchaseId)? callback) {}
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String?> priceLabel() async => price;
  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.canceled;
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
