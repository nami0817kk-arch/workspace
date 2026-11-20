/// 横画面の iPhone で、よくする操作の流れ(節を進める・選手を見る・獲得の
/// 申し込み)を撮り、英語と大きい文字ではみ出す所を数える。
///
/// **CI では回らない。** 操作のしやすさを点検するための生成器。
///
///     flutter test tool/art/ux_flow_test.dart --dart-define=OUT=<出力先>
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
import 'package:soccer_manager/screens/start_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';

import '../../test/support/app_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/ux_more');
const _size = Size(852, 393);
const _ratio = 2.0;
const _notch = EdgeInsets.only(left: 59, right: 59, bottom: 21);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final root = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  });

  test('節を進める速さ', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
    final gs = GameState();
    final sw = Stopwatch()..start();
    await gs.startNewGame('速さFC');
    final create = sw.elapsedMilliseconds;
    final times = <int>[];
    for (var i = 0; i < 10; i++) {
      sw.reset();
      await gs.playNextMatchdayQuickSim();
      times.add(sw.elapsedMilliseconds);
    }
    sw.reset();
    await gs.advanceToNextDecision();
    final adv = sw.elapsedMilliseconds;
    final json = gs.exportSaveJson()!;
    Directory(_out).createSync(recursive: true);
    File('$_out/speed.txt').writeAsStringSync(
        '新しいゲーム ${create}ms\n1節 ${times.join(', ')} ms\n'
        '決めることまで進む ${adv}ms\nセーブの大きさ ${(json.length / 1024).round()}KB\n');
  });

  testWidgets('ダイアログと始め方を撮る', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = _ratio;
    tester.view.physicalSize = _size * _ratio;
    tester.view.padding = FakeViewPadding(
      left: _notch.left * _ratio,
      right: _notch.right * _ratio,
      bottom: _notch.bottom * _ratio,
    );
    tester.view.viewPadding = tester.view.padding;

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
      await gameState.init();
    });
    addTearDown(() => Tr.language = AppLanguage.system);

    final problems = <String>[];
    final oldHandler = FlutterError.onError;
    var where = 'start';
    FlutterError.onError = (d) {
      problems.add('$where: ${d.exceptionAsString().split('\n').first}');
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    const app = SoccerManagerApp();
    final boundaryKey = GlobalKey();
    Widget wrap(Widget home) => MultiProvider(
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
              locale: const Locale('ja'),
              theme: app.buildTheme(Brightness.light, boldText: false),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => LandscapeScale(
                child: FmThemeScope(
                  dark: app.buildTheme(Brightness.dark, boldText: false),
                  child: NotchSideInsets(child: child!),
                ),
              ),
              home: home,
            ),
          ),
        );
    final out = '$_out/more';
    Directory(out).createSync(recursive: true);
    var shot = 0;
    Future<void> snap(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        shot++;
        File('$out/${shot.toString().padLeft(2, '0')}_$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    Future<void> settle(int n) async {
      for (var k = 0; k < n; k++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    void close() {
      tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    }

    final log = StringBuffer();
    Future<bool> tapText(String text, {bool last = false}) async {
      final f = find.text(text).hitTestable();
      if (f.evaluate().isEmpty) {
        final any = find.textContaining(text).hitTestable();
        if (any.evaluate().isEmpty) {
          log.writeln('見つからない: $text');
          return false;
        }
        await tester.tap(last ? any.last : any.first, warnIfMissed: false);
      } else {
        await tester.tap(last ? f.last : f.first, warnIfMissed: false);
      }
      await settle(6);
      return true;
    }

    // 始め方: スロット → 新規作成の入力
    await tester.pumpWidget(wrap(const StartScreen()));
    await settle(5);
    await snap('start');
    if (await tapText('新規クラブ作成')) {
      await snap('new_club_form');
      // 入力欄の縦の長さ
      for (final e in find.byType(Scrollable).evaluate()) {
        final st = (e as StatefulElement).state as ScrollableState;
        if (st.position.hasContentDimensions &&
            st.position.axis == Axis.vertical) {
          log.writeln('新規作成の縦の長さ ${((st.position.maxScrollExtent + st.position.viewportDimension) / st.position.viewportDimension).toStringAsFixed(1)} 画面');
        }
      }
      close();
      await settle(4);
    }

    // ゲームを作って本体へ
    await tester.runAsync(() async {
      await gameState.startNewGame('青嵐FC');
    });
    await tester.pumpWidget(wrap(const MainShell()));
    await settle(8);
    where = 'shell';
    await snap('first_screen');
    // 初めのガイドなど、最初に出るものを数える
    log.writeln('最初のダイアログ ${find.byType(Dialog).evaluate().length}');
    var guard = 0;
    while (find.byType(Dialog).hitTestable().evaluate().isNotEmpty && guard < 5) {
      await snap('first_dialog$guard');
      close();
      await settle(6);
      guard++;
    }
    gameState.save!.firstRunGuideDismissed = true;
    await settle(2);

    // 買う
    where = 'buy';
    await tapText('移籍');
    if (await tapText('買う')) {
      await snap('buy_dialog');
      close();
      await settle(4);
    }
    // 探す
    where = 'search';
    if (await tapText('探す')) await snap('search');

    // 雇う
    where = 'hire';
    await tapText('クラブ');
    if (await tapText('雇う')) {
      await snap('hire_dialog');
      close();
      await settle(4);
    }

    // 選手 → 契約 → 放出・更新
    where = 'release';
    await tapText('選手');
    final name = gameState.userTeam.players[5].name;
    if (await tapText(name)) {
      await tapText('契約');
      if (await tapText('放出する')) {
        await snap('release_dialog');
        close();
        await settle(4);
      }
      if (await tapText('年俸交渉で更新する')) {
        await snap('renew_dialog');
        close();
        await settle(4);
      }
      close();
      await settle(4);
    }

    // その他 → 設定・用語集・ガイド
    for (final item in ['設定', '用語集', 'ガイド']) {
      where = item;
      final menu = find.byTooltip('設定・用語集・ガイド').hitTestable();
      if (menu.evaluate().isNotEmpty) {
        await tester.tap(menu.first);
        await settle(6);
        if (await tapText(item, last: true)) {
          await snap('other_$item');
          close();
          await settle(4);
        } else {
          close();
          await settle(3);
        }
      }
    }

    // 受信箱 → すべて見る
    where = 'inbox';
    await tapText('状況');
    if (await tapText('すべて見る')) {
      await snap('inbox');
      close();
      await settle(4);
    }

    log.writeln('はみ出し・エラー ${problems.length}');
    for (final p in problems.toSet()) {
      log.writeln('  $p');
    }
    File('$out/log.txt').writeAsStringSync(log.toString());
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
