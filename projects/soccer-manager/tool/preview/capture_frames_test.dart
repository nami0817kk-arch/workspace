/// App Store のプレビュー動画用に、アプリの画面を1コマずつ書き出す。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく
/// 生成器だからで、実行するとファイルを書き出す。
///
///     flutter test tool/preview/capture_frames_test.dart
///     python tool/preview/encode.py
///
/// **撮った絵をつなぐのではなく、動いているアプリをそのまま撮る。**
/// 試合画面は時間で動くので、1コマ進めては書き出す、を繰り返すと実際の
/// 映像になる。App Preview は「アプリが動いている様子」であることを
/// 求められるので、静止画の紙芝居では出せない。
///
/// 寸法は 886x1920（iPhone 6.5インチ以上の App Preview の規定値）。
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:typed_data';
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
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/lineup_screen.dart';
import 'package:soccer_manager/screens/live_match_screen.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// 書き出し先の親。encode.py が同じ場所を読む。
const _outRoot = 'build/preview_frames';

/// 撮る言語。ストアの掲載は言語ごとにプレビュー動画を持てる。
typedef _Locale = ({AppLanguage language, String code});

const _locales = <_Locale>[
  (language: AppLanguage.japanese, code: 'ja'),
  (language: AppLanguage.english, code: 'en'),
];

/// 1秒あたりのコマ数。encode.py と合わせること。
const _fps = 30;

/// 論理サイズ。×2 で 886x1920 になる。
const _logical = Size(443, 960);
const _ratio = 2.0;

final _boundaryKey = GlobalKey();

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
  final icons =
      File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!icons.existsSync()) {
    fail('アイコンフォントが見つからない: ${icons.path}\n'
        'FLUTTER_ROOT を設定して実行してください。');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in _locales) {
    testWidgets('プレビュー動画のコマを書き出す (${locale.code})', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => Tr.language = AppLanguage.system);
    tester.view.devicePixelRatio = _ratio;
    tester.view.physicalSize = _logical * _ratio;

    SharedPreferences.setMockInitialValues({});

    final outDir = '$_outRoot/${locale.code}';
    final dir = Directory(outDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState gameState;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      // 言語はシミュレーションより先に決める。記者会見やニュースの文面は
      // 作られた時点の言語で確定し、あとから切り替えても遡って訳されない。
      Tr.language = locale.language;
      monetization = MonetizationController(
        adService: NoOpAdService(),
        purchases: _StubPurchaseService(),
      );
      await monetization.initialize();
      gameState = GameState();
      // **クラブ名も撮る言語に合わせる。** 英語の画面に日本語のクラブ名が
        // 出ていると、英語圏には「訳し切れていないアプリ」に見える。
        // ヘッダーに常時出るので、1枚だけの問題ではない。
        await gameState.startNewGame(
            locale.language == AppLanguage.japanese
                ? '青嵐フットボールクラブ'
                : 'Blue Storm FC');
      for (var i = 0; i < 6; i++) {
        await gameState.playNextMatchday();
        if (gameState.isHalfTime) await gameState.playSecondHalf();
      }
      gameState.save!.firstRunGuideDismissed = true;
    });

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
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(key: _boundaryKey, child: child),
          ),
        );

    var frame = 0;

    /// いま描かれているものを1コマ書き出す。
    Future<void> shot() async {
      var boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // **描き直しが済む前に撮らない。** toImage は未描画の層に対して
      // assert で落ちる(実際に落ちた)。1コマ進めてから撮り直す。
      if (boundary.debugNeedsPaint) {
        await tester.pump();
        boundary = _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
      }
      late Uint8List bytes;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _ratio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = data!.buffer.asUint8List();
        image.dispose();
      });
      File('$outDir/${frame.toString().padLeft(5, '0')}.png')
          .writeAsBytesSync(bytes);
      frame++;
    }

    /// [seconds] 秒ぶん、画面を進めながら書き出す。
    ///
    /// [scrollPerSecond] を渡すと、1秒あたりその分だけ下へ送る。**止まった
    /// 画面を何秒も映さない。** 試合以外の画面は自分では動かないので、
    /// 送ってやらないと静止画を並べたのと変わらなくなる（最初に作った
    /// ものは20秒のうち10秒がハーフタイムの静止画だった）。
    Future<void> record(double seconds, {double scrollPerSecond = 0}) async {
      final count = (seconds * _fps).round();
      const step = Duration(milliseconds: 1000 ~/ _fps);
      // **送り先は毎コマ取り直す。** 1度つかんで使い回すと、画面が作り
      // 替わったときに捨てられたものへ触って落ちる(ハーフタイムに入る
      // ところで実際に落ちた)。
      ///
      /// **縦に動くものを選ぶ。** 画面の最初のスクロールは横並びの絞り込み
      /// であることがある。そのまま送ると、一覧が横にずれて文字が切れた
      /// 絵になる(移籍市場で実際にそうなった)。
      ScrollPosition? positionNow() {
        for (final element in find.byType(Scrollable).evaluate()) {
          final state = (element as StatefulElement).state as ScrollableState;
          if (state.position.axis == Axis.vertical) return state.position;
        }
        return null;
      }

      for (var i = 0; i < count; i++) {
        if (scrollPerSecond != 0) {
          final position = positionNow();
          if (position != null && position.hasPixels) {
            final next = (position.pixels + scrollPerSecond / _fps)
                .clamp(0.0, position.maxScrollExtent);
            // 送ってから進める。逆にすると、送った直後の未描画の状態を
            // 撮りにいって落ちる。
            position.jumpTo(next);
          }
        }
        await tester.pump(step);
        await shot();
      }
    }

    /// 画面を差し替えて、読み込みが終わるまで待つ。
    Future<void> show(Widget screen) async {
      await tester.pumpWidget(wrap(screen));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '読み込み中のまま撮っている');
    }

    // **移籍ウィンドウは試合を始める前に開けておく。** 試合に入ってから
    // 進めようとすると、試合が進行中のあいだ節が進まず、空回りし続ける
    // (実際にここで固まった)。
    await tester.runAsync(() async {
      for (var i = 0; i < 60 && !gameState.isTransferWindowOpen; i++) {
        await gameState.simulateAheadMatchdays(1);
      }
    });
    expect(gameState.isTransferWindowOpen, isTrue,
        reason: '移籍ウィンドウが開かないまま撮ろうとしている');

    // ① スタメン・戦術（3秒）。ピッチに11人が並ぶ絵から始める。
    // 検索結果で最初に目に入るので、ここは動かさず見せる。
    await show(const LineupScreen());
    await record(3);

    // ② 移籍市場（3秒）。
    await show(const TransferScreen());
    await record(3, scrollPerSecond: 150);

    // ③ スカッド（3秒）。
    await show(const SquadScreen());
    await record(3, scrollPerSecond: 150);

    // ④ 試合（6秒）。実況が出て時計が進む、このゲームの中心であり、
    // 唯一それ自体が動く画面。ハーフタイムに入る手前で切る。
    await tester.runAsync(() async {
      await gameState.playNextMatchday();
    });
    await show(const LiveMatchScreen());
    await record(6);

    // ⑤ ハーフタイム（2秒）。交代・檄・戦術変更が並ぶ。何を操作する
    // ゲームなのかがいちばん伝わる画面なので、短く挟む。
    await record(2, scrollPerSecond: 110);

    // ⑥ ホーム（3秒）。経営の数字で締める。
    await show(const HomeScreen());
    await record(3, scrollPerSecond: 120);

    expect(frame, greaterThan(_fps * 15),
        reason: 'App Preview は15秒以上。いま${frame / _fps}秒');
    expect(frame, lessThan(_fps * 30),
        reason: 'App Preview は30秒以内。いま${frame / _fps}秒');
    // ignore: avoid_print
    print('[preview] ${locale.code}: ${frame}コマ / '
        '${(frame / _fps).toStringAsFixed(1)}秒 → $outDir');
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
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
