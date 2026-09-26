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
import 'package:soccer_manager/monetization/funds_pack.dart';
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

/// 撮る端末の寸法。App Store は iPhone と iPad のそれぞれで
/// スクリーンショットを求める。アプリが iPad でも動く設定になっているため、
/// iPhone だけでは「13インチのiPadディスプレイのスクリーンショットを
/// アップロードする必要があります」で提出できない(実際に止まった)。
typedef _Device = ({String dir, Size logical, double ratio});

/// iPhone 6.7インチ = 1290x2796。
const _phone = (dir: 'screenshots', logical: Size(430, 932), ratio: 3.0);

/// iPad 13インチ = 2064x2752。
const _tablet = (dir: 'screenshots_ipad', logical: Size(1032, 1376), ratio: 2.0);

const _devices = <_Device>[_phone, _tablet];

/// 撮る言語。ストアの掲載は言語ごとに画像を持てる。アプリは選手名・クラブ名
/// まで英語のプールを持っているので、英語圏には英語の画面を出す。日本語の
/// 画面に英語の説明文を添えても、中身が伝わらないどころか不信を招く。
typedef _Locale = ({AppLanguage language, String code, String suffix});

const _ja = (language: AppLanguage.japanese, code: 'ja', suffix: '');
const _en = (language: AppLanguage.english, code: 'en', suffix: '_en');

const _locales = <_Locale>[_ja, _en];

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

  for (final device in _devices) {
    for (final locale in _locales) {
      final outDir = '${device.dir}${locale.suffix}';
      testWidgets('ストア用スクリーンショットを書き出す ($outDir)',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = device.ratio;
      tester.view.physicalSize = device.logical * device.ratio;

      SharedPreferences.setMockInitialValues({});

      addTearDown(() => Tr.language = AppLanguage.system);

      late final SettingsController settings;
      late final MonetizationController monetization;
      late final GameState gameState;
      await tester.runAsync(() async {
        settings = SettingsController();
        await settings.init();
        // **シミュレーションより先に言語を決める。** 記者会見やニュースの文面は
        // 作られた時点の言語で確定し、セーブにそのまま残る。あとから切り替えても
        // 遡って訳されない。ここを撮影直前に置いていたため、日本語の画面に英語の
        // 記者会見が写った画像がストアに載っていた (1.0 の掲載画像が実際にそう)。
        // init() が保存値(既定=端末準拠)を書き戻すので、その後で決めること。
        Tr.language = locale.language;
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

      // 生成された文面が日本語になっているか、撮る前に確かめる。掲載画像は
      // 人が1枚ずつ見返さないので、混ざっていても気づかないまま出てしまう。
      final press = gameState.save!.pendingPressConference;
      expect(press, isNotNull, reason: '記者会見が出ていない状態で撮ろうとしている');
      final hasJapanese = RegExp(r'[ぁ-んァ-ヴ一-龠]').hasMatch(press!.prompt);
      expect(hasJapanese, locale.language == AppLanguage.japanese,
          reason: '記者会見が${locale.code}になっていない: ${press.prompt}');

      // 選手名も撮る言語に合っているか見る。英語の画面に日本人名が並ぶと、
      // 英語圏の人には「翻訳し切れていないアプリ」に見える。名前のプールは
      // Tr.isEnglish で切り替わるので、言語を決める順を間違えると混ざる。
      final aPlayer = gameState.userTeam.players.first.name;
      expect(RegExp(r'[ぁ-んァ-ヴ一-龠]').hasMatch(aPlayer),
          locale.language == AppLanguage.japanese,
          reason: '選手名が${locale.code}になっていない: $aPlayer');

      Widget wrap(Widget child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<GameState>.value(value: gameState),
              ChangeNotifierProvider<SettingsController>.value(value: settings),
              ChangeNotifierProvider<MonetizationController>.value(
                  value: monetization),
            ],
            child: MaterialApp(
              locale: Locale(locale.code),
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
          matchesGoldenFile('../../marketing/$outDir/$name.png'),
        );
      }

      // **番号は撮る順ではなく、ストアに並べる順。** 検索結果には先頭3枚しか
      // 出ないので、そこに何を置くかで見られ方が変わる。起動画面を先頭に
      // していた頃は、いちばん目立つ枠が「何のゲームか伝わらない絵」で
      // 埋まっていた。フォーメーション→試合→ホームの順に変えてある。
      // 撮る順は変えられない(試合はここまで進めないと撮れない)ので、
      // 名前だけで並べ替えている。
      await shoot('08_start', const StartScreen());
      await shoot('02_home', const HomeScreen());
      await shoot('05_squad', const SquadScreen());
      await shoot('00_lineup', const LineupScreen());
      // 移籍ウィンドウが閉じている時期に撮ると、「クローズ中」の帯が出て
      // 「獲得する」が全部灰色の画面になる。何もできない画面をストアの
      // 移籍市場として載せていた(1.1.0 の撮り直しで気づいた)。
      // ウィンドウが開く時期まで進めてから撮る。
      await tester.runAsync(() async {
        while (!gameState.isTransferWindowOpen) {
          await gameState.simulateAheadMatchdays(1);
        }
      });
      expect(gameState.isTransferWindowOpen, isTrue,
          reason: '移籍ウィンドウが閉じたまま移籍市場を撮ろうとしている');
      await shoot('03_transfer', const TransferScreen());
      // 日程・順位表。LeagueRankingScreen は得点王ランキングで、順位表ではない。
      await shoot('04_standings', const FixturesScreen());
      await shoot('07_scorers', const LeagueRankingScreen());

      // 試合はこのアプリの中心なので、実際に進行中の画面を撮る。
      // 後半を消化せずに止めると、ハーフタイムの状態で描画できる。
      await tester.runAsync(() async {
        await gameState.playNextMatchday();
      });
      // 前半を4.5秒ぶん進めると、実況が数件出て時計も進んだ状態になる。
      // ハーフタイムに到達する手前で止める。
      await shoot('01_live_match', const LiveMatchScreen(), warmUpFrames: 45);
      // 同じ画面をさらに進めるとハーフタイムに入る。交代・檄・戦術変更が
      // 並ぶ画面で、このゲームで何を操作するのかがいちばん伝わる。
      // pumpWidget で作り直しても State は残るので、続きから進む。
      await shoot('06_halftime', const LiveMatchScreen(), warmUpFrames: 25);
      });
    }
  }
}

class _StubPurchaseService implements PurchaseService {
  /// 受け取り口。本物は待っているかどうかに関係なく呼ぶ。
  @override
  set onDelivered(Future<void> Function(String productId)? callback) =>
      onDeliveredCallback = callback;

  Future<void> Function(String productId)? onDeliveredCallback;

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
