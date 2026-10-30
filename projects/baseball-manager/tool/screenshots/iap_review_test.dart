/// 課金アイテムの審査用スクリーンショット(購入欄と値段が写った1枚)を生成する。
///
/// **CI では回らない**(`test/` の外にある生成器。実行するとファイルを書き換える)。
///
///     flutter test tool/screenshots/iap_review_test.dart
///
/// 出力: `marketing/screenshots/iap_review.png`(1206x2622。広告を消す・継承ブーストの両方に使う)。
/// 本物のストアに繋がらない環境でも値段の行が出るよう、仮のストア(￥370 / ￥250)を差し込む。
/// 値段は全角の「￥」で出す(テストの環境のフォントには半角の ¥ が無く、□になる)。
/// 撮ったら必ず目で見る(`ios-app-release` スキルの E)。
library;

// このファイルは test/ の外にあるため、解析器から見ると「テストではないコード」になる。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/monetization/ad_service.dart';
import 'package:baseball_manager/monetization/monetization.dart';
import 'package:baseball_manager/monetization/purchase_service.dart';
import 'package:baseball_manager/ui/app.dart';
import 'package:baseball_manager/ui/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _logical = Size(402, 874);
const _ratio = 3.0;

/// 値段だけを返す仮のストア(買う処理はしない)。
class _PriceOnlyStore extends NoOpPurchaseService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> priceLabel(String productId) async =>
      productId == PurchaseService.removeAdsId ? '￥370' : '￥250';
}

Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final noto = FontLoader('NotoSansJP');
  for (final f in ['NotoSansJP-Regular.ttf', 'NotoSansJP-Bold.ttf']) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    noto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await noto.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
      );
      await loader.load();
    }
  }
}

final _key = GlobalKey();

void main() {
  testWidgets('課金の審査用スクリーンショット', (t) async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    addTearDown(t.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final money = Monetization(prefs, store: _PriceOnlyStore());
    final c = GameController(rng: Random(1), money: money);
    c.newGame('ハルト', Role.batter);
    c.pending.clear();

    t.view.physicalSize = _logical * _ratio;
    t.view.devicePixelRatio = _ratio;
    await t.pumpWidget(
      RepaintBoundary(key: _key, child: BaseballManagerApp(controller: c)),
    );
    await t.pump(const Duration(milliseconds: 600));
    while (find.byKey(const Key('milestone-ok')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const Key('milestone-ok')));
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const Key('settings-open')));
    await t.pumpAndSettle();
    // 値段を取りに行く非同期処理を待つ。
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)));
    await t.pump(const Duration(milliseconds: 300));

    // 購入欄(広告を消す・継承ブースト)が画面の中ほどに来るまでスクロールする。
    final ads = find.byKey(const Key('remove-ads'));
    final boost = find.byKey(
      const Key('buy-${PurchaseService.legacyBoostId}'),
    );
    expect(ads, findsOneWidget, reason: '広告を消すの行が無い');
    expect(boost, findsOneWidget, reason: '継承ブーストの行が無い');
    await t.ensureVisible(ads);
    await t.pumpAndSettle();
    // 2行とも画面の中に入っていること(片方が切れたまま撮らない)。
    final top = t.getTopLeft(ads).dy, bottom = t.getBottomLeft(boost).dy;
    expect(top, greaterThanOrEqualTo(56), reason: '広告を消すの行が上に切れている');
    expect(bottom, lessThan(_logical.height), reason: '継承ブーストの行が下に切れている');
    expect(find.text('￥370'), findsOneWidget);
    expect(find.text('￥250'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await t.runAsync(() async {
      final b =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: _ratio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('marketing/screenshots').createSync(recursive: true);
      File('marketing/screenshots/iap_review.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
