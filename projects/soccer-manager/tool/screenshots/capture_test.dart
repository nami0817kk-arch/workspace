/// ストア掲載用のスクリーンショットを生成する。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく
/// 生成器だからで、実行するとファイルを書き換える。
///
///     flutter test tool/screenshots/capture_test.dart --update-goldens
///
/// 手で撮らずにここで作る理由:
///
/// - ストアが求める解像度(iPhone 6.7インチ = 1290x2796)を確実に満たせる。
///   実機やエミュレータのスクリーンショットは端末ごとに寸法が違う。
/// - 同じ内容で撮り直せる。文言を直すたびに端末を出してくる必要がない。
///
/// 以前 `marketing/screenshots/` に置かれていた画像は、天気アイコンが
/// 豆腐(□)のまま写っていた。ウィジェットテストの既定ではアイコンフォントが
/// 読み込まれないためで、このファイルでは実物を読み込んでいる。
library;

// このファイルは test/ の外にあるため、解析器から見ると「テストではない
// コード」になり、@visibleForTesting の項目を使うと警告になる。実体は
// flutter test で走らせる生成器で、テストと同じ立場でアプリを組み立てる。
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
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/screens/fixtures_screen.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/league_ranking_screen.dart';
import 'package:soccer_manager/screens/lineup_screen.dart';
import 'package:soccer_manager/screens/live_match_screen.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/start_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// iPhone 6.7インチ。App Store がこの寸法を求め、Google Play もこのまま通る。
const _logical = Size(430, 932);
const _pixelRatio = 3.0;

/// 同梱フォントと、Flutter SDK が持つアイコンフォントを読み込む。
///
/// アイコンフォントを読まないと、天気やナビゲーションのアイコンが
/// すべて豆腐(□)になる。実際に前のスクリーンショットがそうなっていた。
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

  final icons = File(_materialIconsPath());
  if (!icons.existsSync()) {
    fail('アイコンフォントが見つからない: ${icons.path}\n'
        'FLUTTER_ROOT を設定して実行してください。'
        'このまま撮ると、全アイコンが豆腐(□)で写ります。');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
}

String _materialIconsPath() {
  // flutter test は FLUTTER_ROOT を渡してくる。渡ってこない実行のために、
  // 実行中の Dart の位置からも辿れるようにしておく。
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  return '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('ストア用スクリーンショットを書き出す', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = _pixelRatio;
    tester.view.physicalSize = _logical * _pixelRatio;

    SharedPreferences.setMockInitialValues({});
    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState gameState;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      monetization = MonetizationController(
        adService: NoOpAdService(),
        purchases: _StubPurchaseService(),
      );
      await monetization.initialize();
      gameState = GameState();
      await gameState.startNewGame('青嵐フットボールクラブ');
      // 空の順位表や無得点の名簿を写しても、何ができるゲームか伝わらない。
      // 数節進めて、実際に遊んだ状態にしてから撮る。
      for (var i = 0; i < 6; i++) {
        await gameState.playNextMatchday();
        if (gameState.isHalfTime) await gameState.playSecondHalf();
      }
      // 初回ガイドは画面の上4分の1を占める。何ができるゲームかを見せる
      // 場所なので、遊び始めた人の画面として閉じた状態で撮る。
      gameState.save!.firstRunGuideDismissed = true;
    });

    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = AppLanguage.system);

    Widget wrap(Widget child) => MultiProvider(
          providers: [
            ChangeNotifierProvider<GameState>.value(value: gameState),
            ChangeNotifierProvider<SettingsController>.value(value: settings),
            ChangeNotifierProvider<MonetizationController>.value(
                value: monetization),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            theme: const SoccerManagerApp()
                .buildTheme(Brightness.light, boldText: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // これを外さないと、右上にデバッグ用の赤い帯が写り込む。
            // 実際に1度撮り込んでいる。
            debugShowCheckedModeBanner: false,
            home: child,
          ),
        );

    /// [warmUpFrames] は、時間で動く画面のために進める分。試合画面は
    /// 開いた直後だと 0-0 の1分で、画面の下半分が空のまま写る。
    Future<void> shoot(String name, Widget screen,
        {int warmUpFrames = 0}) async {
      await tester.pumpWidget(wrap(screen));
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0; i < warmUpFrames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // はみ出しや例外を抱えたまま掲載画像を作らない。
      expect(tester.takeException(), isNull, reason: '$name の描画で例外が出ている');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../marketing/screenshots/$name.png'),
      );
    }

    await shoot('00_start', const StartScreen());
    await shoot('01_home', const HomeScreen());
    await shoot('02_squad', const SquadScreen());
    await shoot('03_lineup', const LineupScreen());
    await shoot('04_transfer', const TransferScreen());
    // 日程・順位表。LeagueRankingScreen は得点王ランキングで、順位表ではない。
    await shoot('05_standings', const FixturesScreen());
    await shoot('06_scorers', const LeagueRankingScreen());

    // 試合はこのアプリの中心なので、実際に進行中の画面を撮る。
    // 後半を消化せずに止めると、ハーフタイムの状態で描画できる。
    await tester.runAsync(() async {
      await gameState.playNextMatchday();
    });
    // 前半を4.5秒ぶん進めると、実況が数件出て時計も進んだ状態になる。
    // ハーフタイムに到達する手前で止める。
    await shoot('07_live_match', const LiveMatchScreen(), warmUpFrames: 45);
    // 同じ画面をさらに進めるとハーフタイムに入る。交代・檄・戦術変更が
    // 並ぶ画面で、このゲームで何を操作するのかがいちばん伝わる。
    // pumpWidget で作り直しても State は残るので、続きから進む。
    await shoot('08_halftime', const LiveMatchScreen(), warmUpFrames: 25);
  });
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
