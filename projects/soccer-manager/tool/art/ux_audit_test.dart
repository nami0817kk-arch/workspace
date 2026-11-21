/// 横画面の iPhone(852x393・左右に切り欠き 59)で、各ページを撮り、
/// 押せる所の大きさを測って書き出す。
///
/// **CI では回らない。** 操作のしやすさを点検するための生成器。
///
///     flutter test tool/art/ux_audit_test.dart --dart-define=OUT=<出力先>
///
/// 押せる所の大きさは画面上の実寸(pt)。Apple の目安は 44pt 以上。
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

const _out = String.fromEnvironment('OUT', defaultValue: 'build/ux_audit');
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

  testWidgets('操作のしやすさを点検する', (tester) async {
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
      await gameState.startNewGame('青嵐フットボールクラブ');
      gameState.save!.firstRunGuideDismissed = true;
    });
    addTearDown(() => Tr.language = AppLanguage.system);

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
            home: const MainShell(),
          ),
        ),
      ),
    );
    await tester.pump();

    final report = StringBuffer();
    Directory(_out).createSync(recursive: true);

    String labelOf(Element e) {
      final texts = <String>[];
      void walk(Element x) {
        final w = x.widget;
        if (w is Text && w.data != null) texts.add(w.data!);
        if (w is Icon && w.icon != null && texts.isEmpty) {
          texts.add('icon:${w.icon!.codePoint.toRadixString(16)}');
        }
        if (w is Tooltip && w.message != null) texts.add(w.message!);
        x.visitChildren(walk);
      }

      walk(e);
      final s = texts.join(' ').replaceAll('\n', ' ');
      return s.length > 30 ? s.substring(0, 30) : s;
    }

    Future<void> audit(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
      final screen = Offset.zero & _size;
      final rows = <(double, String)>[];
      var total = 0;
      for (final e in find
          .byWidgetPredicate((w) =>
              (w is InkWell && (w.onTap != null || w.onLongPress != null)) ||
              (w is InkResponse && w.onTap != null) ||
              (w is GestureDetector && w.onTap != null))
          .hitTestable(at: Alignment.center)
          .evaluate()) {
        final ro = e.renderObject;
        if (ro is! RenderBox || !ro.hasSize) continue;
        final r = ro.localToGlobal(Offset.zero) & ro.size;
        // 見えている所だけ(スクロールの外は数えない)。
        if (!screen.overlaps(r)) continue;
        // 実寸に直す(LandscapeScale で縮めて描いている)。
        final br = ro.localToGlobal(ro.size.bottomRight(Offset.zero));
        final h = br.dy - r.top;
        final w = br.dx - r.left;
        total++;
        final small = h < 44 || w < 44;
        if (small) rows.add((h < w ? h : w, '${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)} ${labelOf(e)}'));
      }
      rows.sort((a, b) => a.$1.compareTo(b.$1));
      report.writeln('## $name  押せる所 $total / 44pt 未満 ${rows.length}');
      for (final r in rows.take(25)) {
        report.writeln('  ${r.$2}');
      }
      // 文字の小ささ(実寸)
      final sizes = <double, int>{};
      for (final e in find.byType(RichText).evaluate()) {
        final ro = e.renderObject;
        if (ro is! RenderParagraph || !ro.hasSize) continue;
        final r = ro.localToGlobal(Offset.zero) & ro.size;
        if (!screen.overlaps(r)) continue;
        final sx = (ro.localToGlobal(const Offset(100, 0)).dx -
                ro.localToGlobal(Offset.zero).dx) /
            100;
        final fs = ((ro.text.style?.fontSize ?? 14) * sx).roundToDouble();
        sizes[fs] = (sizes[fs] ?? 0) + 1;
      }
      final keys = sizes.keys.toList()..sort();
      report.writeln('  文字(pt:個数) ${[for (final k in keys) '$k:${sizes[k]}'].join(' ')}');
    }

    // 縦に何画面ぶんあるか・札(Card)がいくつあるか(見えている縦の列ごと)。
    void measureLength(String name) {
      final parts = <String>[];
      for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
        final st = (e as StatefulElement).state as ScrollableState;
        final pos = st.position;
        if (pos.axis != Axis.vertical || !pos.hasContentDimensions) continue;
        final screens = (pos.maxScrollExtent + pos.viewportDimension) /
            pos.viewportDimension;
        parts.add(screens.toStringAsFixed(1));
      }
      final cards = find.byType(Card).evaluate().length;
      report.writeln('  [$name] 縦の長さ(画面) ${parts.join(' / ')}  札 $cards');
    }

    final pages = ['状況', '経営', 'クラブ', '選手', '移籍', 'リーグ', 'オーナー室'];
    for (final p in pages) {
      final f = find.text(p);
      if (f.evaluate().isEmpty) {
        report.writeln('## $p  見つからない');
        continue;
      }
      await tester.tap(f.first, warnIfMissed: false);
      await tester.pump();
      await audit(p);
      measureLength(p);
      // ページの中のタブを順に開いて、長さを測る(1段目のタブだけ)。
      final tabs = find.byType(Tab).hitTestable().evaluate().toList();
      final tabLabels = <String>[
        for (final t in tabs)
          if ((t.widget as Tab).text != null) (t.widget as Tab).text!,
      ];
      report.writeln('  タブ ${tabLabels.length}: ${tabLabels.join(' / ')}');
      for (var i = 0; i < tabLabels.length && i < 12; i++) {
        final tf = find.widgetWithText(Tab, tabLabels[i]).hitTestable();
        if (tf.evaluate().isEmpty) continue;
        await tester.tap(tf.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
        measureLength('$p/${tabLabels[i]}');
        if (i > 0) {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.0);
            final data =
                await image.toByteData(format: ui.ImageByteFormat.png);
            File('$_out/${p}_${tabLabels[i].replaceAll('/', '_')}.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          });
        }
        tester.takeException();
      }
      tester.takeException();
    }
    // 見出しの帯に文字で並ぶタブ(Tab ではない作り)も開いて測る。
    const headerTabs = {
      'クラブ': ['スタッフ', '施設', 'ファンと街', 'ユース・スカウト'],
      '選手': ['スカッド', '登録と契約'],
      'リーグ': ['順位・日程', 'カップ戦', 'ランキング', '個人タイトル'],
      'オーナー室': [
        'オーナーの仕事', 'オーナーと世界', 'カレンダー', 'ニュース',
        'シーズン分析', '記録',
      ],
    };
    for (final e in headerTabs.entries) {
      final page = find.text(e.key);
      if (page.evaluate().isEmpty) {
        report.writeln('  [${e.key}] 見つからない');
        continue;
      }
      await tester.tap(page.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      for (final t in e.value) {
        final f = find.text(t).hitTestable();
        if (f.evaluate().isEmpty) {
          report.writeln('  [${e.key}/$t] 見つからない');
          continue;
        }
        await tester.tap(f.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
        measureLength('${e.key}/$t');
        {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.0);
            final data =
                await image.toByteData(format: ui.ImageByteFormat.png);
            File('$_out/${e.key}_$t.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          });
        }
        // 長いページは見出し(札の題)を並べる。
        final heads = <String>[];
        for (final h in find.byType(Text).evaluate()) {
          final w = h.widget as Text;
          final st = w.style;
          final ro = h.renderObject;
          if (ro is! RenderBox || !ro.hasSize) continue;
          if ((st?.fontWeight == FontWeight.bold ||
                  st?.fontWeight == FontWeight.w700) &&
              (w.data?.length ?? 0) >= 3 &&
              (w.data?.length ?? 0) <= 16) {
            heads.add(w.data!);
          }
        }
        if (heads.length > 12) {
          report.writeln('    見出し ${heads.length}: ${heads.take(60).join(' | ')}');
        }
        tester.takeException();
      }
    }
    File('$_out/report.txt').writeAsStringSync(report.toString());
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
