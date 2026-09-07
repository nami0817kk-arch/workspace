import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

import 'support/app_fonts.dart';

/// 読みやすさ・操作しやすさを固定するテスト。
///
/// Flutter が持つアクセシビリティ基準で全画面を検査する。導入時点で8件の違反が
/// あった。内訳は、注記に使っていた Colors.grey が明るいテーマでコントラスト
/// 2.55(基準4.5)しか出ていなかったもの、カレンダーの月移動ボタンに読み上げ用の
/// ラベルが無かったもの、ウォッチリストのボタンが40x40で基準の48x48に
/// 足りなかったもの。いずれも見た目では気づきにくい。
///
/// 端末の文字サイズを上げたときの崩れも見る。設定画面に文字サイズの調整が
/// あるので、大きくして使う利用者は実在する。
void main() {
  setUpAll(loadAppFonts);

  late SettingsController settings;
  late MonetizationController monetization;
  late GameState gameState;

  Future<void> boot(WidgetTester tester) async {
    // testWidgets は疑似時間で動くため、SharedPreferences を待つ処理は
    // runAsync の中で行う。
    SharedPreferences.setMockInitialValues({});
    // 設定画面がアプリのバージョンを取りに行く。実機のプラグインは無いので
    // 差し替える。放っておくと描画のあとから MissingPluginException が届き、
    // 無関係のテストを落とす。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'soccer_manager',
        'packageName': 'com.namiki.soccermanager',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      // 実装のままだと課金プラグインへ接続しにいき、テスト完了後に
      // PlatformException が遅れて届く。差し替える。
      monetization = MonetizationController(
          adService: NoOpAdService(), purchases: _StubPurchaseService());
      await monetization.initialize();
      gameState = GameState();
      await gameState.startNewGame('テストFC');
    });
    // SettingsController.init() が Tr.language を上書きするので、指定はこの後。
    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = AppLanguage.system);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
  }

  Widget wrap(Widget child, double textScale) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: gameState),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<MonetizationController>.value(
              value: monetization),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          // アプリ本来のテーマで検査する。既定テーマのままだと Material の
          // 標準色と標準の文字を測ることになり、実際に利用者が見る紺・金の
          // 配色のコントラストは一度も確かめられない。
          theme: const SoccerManagerApp()
              .buildTheme(Brightness.light, boldText: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: c!,
          ),
          home: child,
        ),
      );

  testWidgets('全画面がアクセシビリティ基準を満たす', (WidgetTester tester) async {
    await boot(tester);
    final handle = tester.ensureSemantics();
    final failures = <String>[];

    for (final dest in quickAccessDestinations) {
      await tester.pumpWidget(wrap(Builder(builder: dest.builder), 1.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // 文字コントラストは textContrastGuideline では見ない。あれはノードの
      // 矩形からピクセルの色を推定するため、実フォントを読み込むと文字の縁の
      // アンチエイリアスを拾い、パレットに存在しない色(#6A748E や #D5D5D3)を
      // 「文字色」として報告する。実測で24種類65件の不合格が出たが、テーマの
      // 実色から計算し直すと最低でも 7.28 あり、すべて誤検出だった。
      // 配色そのものは『配色のコントラスト』のテストで決定的に確かめる。
      for (final g in <(String, AccessibilityGuideline)>[
        ('タップ領域48x48', androidTapTargetGuideline),
        ('読み上げラベル', labeledTapTargetGuideline),
      ]) {
        try {
          await expectLater(tester, meetsGuideline(g.$2));
        } catch (e) {
          // 1画面で止めず全部見る。まとめて出た方が傾向を掴みやすい。
          failures.add('${dest.label} / ${g.$1}');
        }
      }
    }
    handle.dispose();

    expect(failures, isEmpty,
        reason: 'アクセシビリティ基準を満たさない画面がある:\n${failures.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('文字サイズを上げても画面が崩れない', (WidgetTester tester) async {
    await boot(tester);
    final broken = <String>[];

    // 2.0 は端末の設定で実際に選べる範囲。ここまでは崩れないようにする。
    for (final scale in const [1.3, 1.6, 2.0]) {
      for (final dest in quickAccessDestinations) {
        await tester.pumpWidget(wrap(Builder(builder: dest.builder), scale));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // はみ出しは throw されず FlutterError.onError に報告されるので、
        // try/catch ではなく takeException で拾う。
        final e = tester.takeException();
        if (e != null) {
          broken.add('${dest.label} (x$scale): '
              '${e.toString().split('\n').first}');
        }
      }
    }

    expect(broken, isEmpty,
        reason: '文字サイズを上げると崩れる画面がある:\n${broken.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 6)));
}

class _StubPurchaseService implements PurchaseService {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<String?> priceLabel() async => null;
  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;
  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
  @override
  void dispose() {}
}
