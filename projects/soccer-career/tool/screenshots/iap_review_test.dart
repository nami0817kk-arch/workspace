/// 課金アイテムの**審査用**スクリーンショットを生成する。
///
/// **CI では回らない。** `tool/` にあるのは、これがテストではなく生成器だから。
///
///     flutter test tool/screenshots/iap_review_test.dart \n///       --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-0000000000000000/0000000000
///
/// **渡さないと「広告はテスト用のままです」の赤字が写る。**
/// 出すビルドには本番のIDが入るので、その赤字は出ない。
///
/// App Store Connect は、課金アイテム1件ごとに「審査に関する情報」の
/// スクリーンショットを**必須**で求める。求められているのは
/// **値段のボタンが写った画面**で、掲載画像とは別物——
/// あちらには帯を重ねるが、こちらは重ねない（審査員が見るのはアプリの実物）。
///
/// 売るのは「広告を消す」1件だけなので、添付するのもこの1枚。
///
/// 値段はストアから取るものなので、手元では出ない。ここでは差し替えた
/// 課金の窓口（[_PricedStore]）が、実際に登録する予定の額を返す。
/// **`STORE_LISTING.md` の額を変えたら、ここも変えて撮り直す。**
library;

// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_career/monetize/ad_service.dart';
import 'package:soccer_career/monetize/monetization.dart';
import 'package:soccer_career/monetize/purchase_service.dart';
import 'package:soccer_career/ui/screens/support_screen.dart';

import 'capture_test.dart' show bandTheme, loadFonts, phone;

/// 値段を返す課金の窓口。**買えはしない**——撮るのはボタンが出ている画面だけ。
class _PricedStore implements PurchaseService {
  @override
  Future<void> initialize({
    required Future<void> Function(Product product) onDelivered,
    required Future<void> Function(Product product) onRevoked,
  }) async {}

  @override
  Future<bool> isAvailable() async => true;

  /// **`STORE_LISTING.md` の「価格」と同じ額にしておく。**
  ///
  /// **円記号が半角の `¥`（U+00A5）だと、ここでは豆腐（□）になる。**
  /// 同梱している NotoSansJP に U+00A5 が無いためで、実機では
  /// OS のフォントが補う（MaterialIcons がテストだけ□になるのと同じ）。
  /// **審査用の絵が読めないのは困るので、ここだけ全角の `￥` で撮る。**
  /// 実機で□になっていないかは `docs/RELEASE.md` の実機チェックで見る。
  @override
  Future<String?> priceOf(Product product) async =>
      switch (product) { Product.noAds => '￥400' };

  @override
  Future<PurchaseOutcome> buy(Product product) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restore() async => PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}

final _key = GlobalKey();

void main() {
  setUpAll(() async {
    await loadFonts();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  });

  testWidgets('課金アイテムの審査用スクリーンショットを書き出す', (tester) async {
    debugDisableShadows = false;
    try {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = phone.ratio;
      tester.view.physicalSize = phone.logical * phone.ratio;

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final monetization = Monetization(
        ads: NoAdService(),
        purchases: _PricedStore(),
      );
      await monetization.initialize();

      await tester.pumpWidget(
        RepaintBoundary(
          key: _key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: bandTheme,
            home: SupportScreen(monetization: monetization),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // **値段が写っていること。** ここが写っていないと審査で差し戻される
      // （求められているのは「値段のボタンが見える画面」）。
      expect(find.text('広告を消す（￥400）'), findsOneWidget,
          reason: '値段のボタンが出ていない');
      // 読み込み中を撮っていないこと（掲載画像で一度やった）。
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '読み込み中のまま撮られている');
      expect(find.textContaining('テスト用'), findsNothing,
          reason: '広告の警告が写っている。'
              '--dart-define=ADMOB_INTERSTITIAL_ANDROID=... を渡して撮る');
      expect(tester.takeException(), isNull);

      await tester.runAsync(() async {
        final boundary =
            _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: phone.ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('marketing/iap_review')
          ..createSync(recursive: true);
        File('${dir.path}/remove_ads.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        print('wrote marketing/iap_review/remove_ads.png '
            '(${image.width}x${image.height})');
      });
    } finally {
      debugDisableShadows = true;
    }
  });
}
