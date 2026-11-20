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
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';

import '../../test/support/app_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/ux_flow');
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

  for (final mode in ['ja', 'en', 'ja_big']) {
    testWidgets('流れを撮る $mode', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = _ratio;
      tester.view.physicalSize = _size * _ratio;
      tester.view.padding = FakeViewPadding(
        left: _notch.left * _ratio,
        right: _notch.right * _ratio,
        bottom: _notch.bottom * _ratio,
      );
      tester.view.viewPadding = tester.view.padding;
      final en = mode == 'en';
      final scale = mode == 'ja_big' ? 1.3 : 1.0;

      SharedPreferences.setMockInitialValues({});
      late final SettingsController settings;
      late final MonetizationController monetization;
      late final GameState gameState;
      await tester.runAsync(() async {
        settings = SettingsController();
        await settings.init();
        Tr.language = en ? AppLanguage.english : AppLanguage.japanese;
        monetization = MonetizationController(
          adService: NoOpAdService(),
          purchases: _StubPurchaseService(),
        );
        await monetization.initialize();
        gameState = GameState();
        await gameState.startNewGame('Seiran FC');
        gameState.save!.firstRunGuideDismissed = true;
      });
      addTearDown(() => Tr.language = AppLanguage.system);

      final overflows = <String>[];
      final oldHandler = FlutterError.onError;
      var where = '';
      FlutterError.onError = (d) {
        final s = d.exceptionAsString().split('\n').first;
        overflows.add('$where: $s');
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      const app = SoccerManagerApp();
      final boundaryKey = GlobalKey();
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
              locale: Locale(en ? 'en' : 'ja'),
              theme: app.buildTheme(Brightness.light, boldText: false),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: LandscapeScale(
                  child: FmThemeScope(
                    dark: app.buildTheme(Brightness.dark, boldText: false),
                    child: NotchSideInsets(child: child!),
                  ),
                ),
              ),
              home: const MainShell(),
            ),
          ),
        ),
      );
      await tester.pump();
      final out = '$_out/$mode';
      Directory(out).createSync(recursive: true);
      var shot = 0;
      Future<void> snap(String name) async {
        await tester.pump(const Duration(milliseconds: 400));
        final boundary = tester
            .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
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

      final log = StringBuffer();
      String t(String ja, String e) => en ? e : ja;

      // 1) 全ページと中のタブを開いて、はみ出しを集める。
      final pages = en
          ? ['Status', 'Finance', 'Club', 'Players', 'Transfers', 'League', 'Office']
          : ['状況', '経営', 'クラブ', '選手', '移籍', 'リーグ', 'オーナー室'];
      for (final p in pages) {
        where = p;
        final f = find.text(p);
        if (f.evaluate().isEmpty) continue;
        await tester.tap(f.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        if (mode != 'ja') await snap('page_$p');
        final tabs = [
          for (final e in find.byType(Tab).hitTestable().evaluate())
            if ((e.widget as Tab).text != null) (e.widget as Tab).text!,
        ];
        for (final tab in tabs) {
          where = '$p/$tab';
          final tf = find.widgetWithText(Tab, tab).hitTestable();
          if (tf.evaluate().isEmpty) continue;
          await tester.tap(tf.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
        }
      }

      // 2) 選手の画面(選手の一覧の先頭を押す)。
      where = 'player';
      await tester.tap(find.text(t('選手', 'Players')).first,
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      final firstName = gameState.userTeam.players.first.name;
      final pf = find.text(firstName).hitTestable();
      if (pf.evaluate().isNotEmpty) {
        await tester.tap(pf.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 600));
        await snap('player');
        for (final tab in [
          t('能力', 'Attributes'),
          t('契約', 'Contract'),
          t('人柄', 'Character'),
          t('経歴', 'History'),
        ]) {
          where = 'player/$tab';
          final tf = find.widgetWithText(Tab, tab).hitTestable();
          if (tf.evaluate().isEmpty) continue;
          await tester.tap(tf.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
          await snap('player_$tab');
        }
        tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
        await tester.pump(const Duration(milliseconds: 600));
      } else {
        log.writeln('player: 名前が押せない');
      }

      // 3) 獲得の申し込み(移籍 → 監督の案 → 買う)。
      where = 'buy';
      await tester.tap(find.text(t('移籍', 'Transfers')).first,
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      final buy = find.text(t('買う', 'Buy')).hitTestable();
      if (buy.evaluate().isNotEmpty) {
        await tester.tap(buy.first);
        await tester.pump(const Duration(milliseconds: 600));
        await snap('buy_dialog');
        tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
        await tester.pump(const Duration(milliseconds: 600));
      }

      // 4) 次の節へを数回押して、出てくる画面を数える。
      if (mode == 'ja') {
        for (var i = 0; i < 6; i++) {
          where = 'next$i';
          final next = find.text('次の節へ').hitTestable();
          if (next.evaluate().isEmpty) {
            log.writeln('next$i: 次の節へが押せない');
            await snap('next${i}_blocked');
            break;
          }
          await tester.tap(next.first);
          await settle(30);
          var taps = 0;
          while (taps < 8) {
            final dialog = find.byType(Dialog).hitTestable();
            if (dialog.evaluate().isEmpty) break;
            await snap('next${i}_dialog$taps');
            final buttons = find
                .descendant(
                    of: find.byType(Dialog),
                    matching: find.byWidgetPredicate((w) =>
                        w is ButtonStyleButton && w.onPressed != null))
                .hitTestable();
            if (buttons.evaluate().isEmpty) {
              tester
                  .state<NavigatorState>(find.byType(Navigator).last)
                  .maybePop();
            } else {
              await tester.tap(buttons.last);
            }
            taps++;
            await settle(10);
          }
          final snack = find.byType(SnackBar).evaluate().length;
          log.writeln('next$i: ダイアログ $taps 回・通知の帯 $snack');
          await snap('next${i}_after');
        }
      }

      log.writeln('はみ出し・エラー ${overflows.length}');
      for (final o in overflows.toSet()) {
        log.writeln('  $o');
      }
      File('$out/log.txt').writeAsStringSync(log.toString());
      tester.takeException();
    });
  }
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
