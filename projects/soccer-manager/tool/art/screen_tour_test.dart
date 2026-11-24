/// 横画面の iPhone(852x393・切り欠きあり)で、左のメニューの全ページと
/// ページの中のタブを順に開いて PNG に書き出す。画面の質を見直すための見本。
///
/// **CI では回らない。** 実行するとファイルを書く。
///
///     flutter test tool/art/screen_tour_test.dart --dart-define=OUT=<出力先>
///
/// 切り替え(どれも省略できる):
/// - `LOOK=light|dark` 明暗(既定 light。アプリの既定と同じ)
/// - `LANG=ja|en` 言語(既定 ja)
/// - `DEVICE=phone|ipad` 端末(既定 phone)
///
/// 撮るたびに、文字と地の色の差を測り(contrast_audit.dart)、3:1 に
/// 届かない文字を `LOWCONTRAST` の行で出す。明るい見た目を足したとき、
/// 直書きの白い文字が明るい地に乗る箇所をここで拾った(2026-11-24)。
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
import 'package:soccer_manager/widgets/group_page.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';
import 'package:soccer_manager/widgets/notch_side_insets.dart';

import '../../test/support/app_fonts.dart';
import 'contrast_audit.dart';

const _look = String.fromEnvironment('LOOK', defaultValue: 'light');
const _lang = String.fromEnvironment('LANG', defaultValue: 'ja');
const _device = String.fromEnvironment('DEVICE', defaultValue: 'phone');
const _out = String.fromEnvironment('OUT',
    defaultValue: 'build/screen_tour/${_look}_${_lang}_$_device');
const _ipad = _device == 'ipad';
const _en = _lang == 'en';
const _size = _ipad ? Size(1376, 1032) : Size(852, 393);

/// 撮る言語の文言。
String _t(String ja, String en) => _en ? en : ja;

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

  testWidgets('screen tour', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = _size * 2;
    if (!_ipad) {
      tester.view.padding =
          const FakeViewPadding(left: 118, right: 118, bottom: 42);
      tester.view.viewPadding = tester.view.padding;
    }

    SharedPreferences.setMockInitialValues({});
    late final SettingsController settings;
    late final MonetizationController monetization;
    late final GameState game;
    await tester.runAsync(() async {
      settings = SettingsController();
      await settings.init();
      Tr.language = _en ? AppLanguage.english : AppLanguage.japanese;
      monetization = MonetizationController(
          adService: NoOpAdService(), purchases: _NoStore());
      await monetization.initialize();
      game = GameState();
      await game.startNewGame(_t('青嵐FC', 'Blue Storm FC'));
      for (var i = 0; i < 6; i++) {
        await game.playNextMatchday();
        if (game.isHalfTime) await game.playSecondHalf();
      }
      game.save!.firstRunGuideDismissed = true;
    });
    addTearDown(() => Tr.language = AppLanguage.system);

    final key = GlobalKey();
    const app = SoccerManagerApp();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: game),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(_lang),
          theme: app.buildTheme(
              _look == 'dark' ? Brightness.dark : Brightness.light,
              boldText: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => LandscapeScale(
            child: FmThemeScope(
              light: app.buildTheme(Brightness.light, boldText: false),
              dark: app.buildTheme(Brightness.dark, boldText: false),
              child: NotchSideInsets(child: child!),
            ),
          ),
          home: const MainShell(),
        ),
      ),
    ));
    await tester.pump();

    // はみ出しは場所(lib/ の行)を添えて出す。
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      final at = RegExp(r'lib/[\w/]+\.dart:\d+')
          .allMatches(d.toString())
          .map((m) => m.group(0))
          .toSet()
          .join(', ');
      // ignore: avoid_print
      print('PROBLEM ${d.exceptionAsString().split('\n').first} [$at]');
    };
    addTearDown(() => FlutterError.onError = oldOnError);
    var n = 0;
    Future<void> shoot(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      n++;
      final file =
          '${n.toString().padLeft(2, '0')}_${name.replaceAll('/', '_')}';
      await tester.runAsync(() async {
        final image = await b.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_out).createSync(recursive: true);
        File('$_out/$file.png').writeAsBytesSync(data!.buffer.asUint8List());
        for (final issue in await auditContrast(b, image, 1.5)) {
          // ignore: avoid_print
          print('LOWCONTRAST $file $issue');
        }
      });
    }

    // 始めに出るお知らせ(全面の札・ダイアログ)を撮ってから閉じる。
    for (var i = 0;
        i < 6 && find.text(_t('状況', 'Status')).hitTestable().evaluate().isEmpty;
        i++) {
      await shoot('notice');
      final close = find.textContaining(_t('閉じる', 'Close')).hitTestable();
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first, warnIfMissed: false);
      } else {
        await tester.tapAt(Offset(_size.width / 2, 200));
      }
      await tester.pump(const Duration(milliseconds: 600));
    }
    // 環境変数 PAGES で撮るページを絞れる(例: オーナー室)。
    const only = String.fromEnvironment('PAGES');
    for (final p in _en
        ? const [
            'Status',
            'Calendar',
            'Finance',
            'Club',
            'Players',
            'Transfers',
            'League',
            'Office'
          ]
        : const ['状況', 'カレンダー', '経営', 'クラブ', '選手', '移籍', 'リーグ', 'オーナー室']) {
      if (only.isNotEmpty && !only.split(',').contains(p)) continue;
      // 前のページで別の画面(用語集など)が開いたままなら閉じる。
      for (var i = 0; i < 4; i++) {
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        if (!nav.canPop()) break;
        nav.pop();
        await tester.pump(const Duration(milliseconds: 600));
      }
      final side = find.text(p).hitTestable();
      if (side.evaluate().isEmpty) {
        await shoot('missing-$p');
        continue;
      }
      await tester.tap(side.first);
      await tester.pump(const Duration(milliseconds: 300));
      final labels = <String>[
        for (final e in find
            .descendant(
                of: find.byType(GroupPage), matching: find.byType(InkWell))
            .hitTestable()
            .evaluate())
          for (final t in find
              .descendant(
                  of: find.byWidget(e.widget), matching: find.byType(Text))
              .evaluate())
            (t.widget as Text).data ?? '',
        // 「やること」の印が付いたタブは、字を child に持つ。
        for (final e in find.byType(Tab).hitTestable().evaluate())
          (e.widget as Tab).text ??
              find
                  .descendant(
                      of: find.byWidget(e.widget), matching: find.byType(Text))
                  .evaluate()
                  .map((t) => (t.widget as Text).data ?? '')
                  .firstWhere((s) => s.isNotEmpty, orElse: () => ''),
      ]..removeWhere((s) =>
          s.isEmpty ||
          // リーグの順位表などの数字(押すと別の画面が開く)はタブではない。
          RegExp(r'^[\d\-+]').hasMatch(s));
      if (labels.isEmpty) {
        await shoot(p);
        // カレンダーは、次の試合のマスを押したところと「1年の予定」も撮る。
        if (p == _t('カレンダー', 'Calendar')) {
          final opp = find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('cal-opp-'));
          if (opp.evaluate().isNotEmpty) {
            final k = (opp.evaluate().last.widget.key as ValueKey<String>)
                .value
                .substring('cal-opp-'.length);
            await tester.tap(find.byKey(ValueKey('cal-day-$k')));
            await tester.pump(const Duration(milliseconds: 600));
            await shoot('$p-day');
            await tester.tapAt(const Offset(400, 20));
            await tester.pump(const Duration(milliseconds: 600));
          }
          final legend =
              find.byKey(const ValueKey('calendar-legend-button')).hitTestable();
          if (legend.evaluate().isNotEmpty) {
            await tester.tap(legend.first);
            await tester.pump(const Duration(milliseconds: 300));
            await shoot('$p-legend');
            await tester.tap(legend.first);
            await tester.pump(const Duration(milliseconds: 300));
          }
          // 6週ある月(2026年11月)も、送らずに収まるか。
          for (var i = 0; i < 2; i++) {
            await tester.tap(
                find.byTooltip(_t('次の月', 'Next month')).hitTestable().first);
            await tester.pump(const Duration(milliseconds: 300));
          }
          await shoot('$p-6weeks');
          await tester.tap(find.text(_t('今日へ', 'Today')).hitTestable().first);
          await tester.pump(const Duration(milliseconds: 300));
          final year = find.byKey(const ValueKey('chip-1')).hitTestable();
          if (year.evaluate().isNotEmpty) {
            await tester.tap(year.first);
            await tester.pump(const Duration(milliseconds: 400));
            await shoot('$p-year');
            await tester.tap(find.byKey(const ValueKey('chip-0')).first);
            await tester.pump(const Duration(milliseconds: 400));
          }
        }
        // 状況は全部を見たいので、左右の欄を下へ送りながら撮る。
        if (p == _t('状況', 'Status')) {
          for (var i = 1; i <= 8; i++) {
            await tester.dragFrom(
                const Offset(430, 330), const Offset(0, -260));
            await tester.dragFrom(
                const Offset(920, 330), const Offset(0, -260));
            await tester.pump(const Duration(milliseconds: 500));
            await shoot('$p-scroll$i');
          }
          await tester.dragFrom(const Offset(430, 200), const Offset(0, 5000));
          await tester.dragFrom(const Offset(920, 200), const Offset(0, 5000));
          await tester.pump(const Duration(milliseconds: 500));
        }
        continue;
      }
      for (final l in labels) {
        final f = find.text(l).hitTestable();
        if (f.evaluate().isEmpty) continue;
        await tester.tap(f.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
        await shoot('$p-$l');
        // タブの中の札(移籍の「候補」「探す」)も、1つずつ開いて撮る。
        for (var k = 1; k < 4; k++) {
          final chip = find.byKey(ValueKey('chip-$k')).hitTestable();
          if (chip.evaluate().isEmpty) break;
          await tester.tap(chip.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
          await shoot('$p-$l-chip$k');
        }
        // スタッフの候補の表を開いたところも撮る。
        if (p == _t('クラブ', 'Club') && l == _t('スタッフ', 'Staff')) {
          final open =
              find.textContaining(_t('候補を見る', 'candidates')).hitTestable();
          if (open.evaluate().isNotEmpty) {
            await tester.tap(open.first);
            await tester.pump(const Duration(milliseconds: 600));
            await shoot('$p-$l-candidates');
            await tester.tap(open.first);
            await tester.pump(const Duration(milliseconds: 600));
          }
        }
        // 経営・クラブは各タブが長いので、下へ送りながら撮る。
        if ((_en
                ? const ['Finance', 'Club', 'Office', 'League']
                : const ['経営', 'クラブ', 'オーナー室', 'リーグ'])
            .contains(p)) {
          // 座標は論理ピクセル(幅852)。左右2つの欄の両方を送る。
          for (var i = 1; i <= 6; i++) {
            await tester.dragFrom(
                const Offset(300, 330), const Offset(0, -220));
            await tester.dragFrom(
                const Offset(640, 330), const Offset(0, -220));
            await tester.pump(const Duration(milliseconds: 400));
            await shoot('$p-$l-scroll$i');
          }
          await tester.dragFrom(const Offset(300, 200), const Offset(0, 5000));
          await tester.dragFrom(const Offset(640, 200), const Offset(0, 5000));
          await tester.pump(const Duration(milliseconds: 400));
        }
        // 選手のスカッドは、表を下へ送ったところ・カード・選手の詳しい画面も撮る。
        if (p == _t('選手', 'Players') && l == _t('スカッド', 'Squad')) {
          await tester.dragFrom(const Offset(940, 330), const Offset(0, -250));
          await tester.pump(const Duration(milliseconds: 400));
          await shoot('$p-$l-scroll');
          await tester.dragFrom(const Offset(940, 200), const Offset(0, 3000));
          await tester.pump(const Duration(milliseconds: 400));
          final player = find.text(game.userTeam.players.first.name);
          await tester
              .tap(find.byTooltip(_t('カード', 'Cards')).hitTestable().first);
          await tester.pump(const Duration(milliseconds: 400));
          await shoot('$p-$l-card');
          await tester
              .tap(find.byTooltip(_t('表', 'Table')).hitTestable().first);
          await tester.pump(const Duration(milliseconds: 400));
          if (player.hitTestable().evaluate().isNotEmpty) {
            await tester.tap(player.hitTestable().first);
            await tester.pump(const Duration(milliseconds: 600));
            await shoot('$p-detail-open');
            for (final t in _en
                ? const [
                    'Overview',
                    'Attributes',
                    'Contract',
                    'Character & history'
                  ]
                : const ['概要', '能力', '契約', '人柄・経歴']) {
              final tf = find.text(t).hitTestable();
              if (tf.evaluate().isEmpty) continue;
              await tester.tap(tf.first);
              await tester.pump(const Duration(milliseconds: 400));
              await shoot('$p-detail-$t');
            }
            await tester
                .state<NavigatorState>(find.byType(Navigator).first)
                .maybePop();
            await tester.pump(const Duration(milliseconds: 600));
          }
        }
      }
    }
    tester.takeException();
  }, timeout: const Timeout(Duration(minutes: 45)));
}

class _NoStore implements PurchaseService {
  @override
  set onDelivered(
      Future<void> Function(String productId, String? purchaseId)? cb) {}
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
