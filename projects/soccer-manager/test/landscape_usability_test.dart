// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
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

import 'support/app_fonts.dart';

/// 横画面の iPhone(852x393・左右に切り欠き)で、操作のしやすさが戻らないこと。
///
/// 2026-11-20 の見直しで直したもの(押す所が33〜38pt・オーナーの仕事が縦35画面
/// 分・タブ8つ・英語や大きい文字ではみ出し)を、ここで止める。
/// - 左のメニュー・ページのタブ・タブの段は 44pt 以上
/// - どのページ・タブも、はみ出さない(日本語・英語・文字1.3倍)
/// - どのページも縦8画面分を超えない
const _size = Size(852, 393);
const _notch = EdgeInsets.only(left: 59, right: 59, bottom: 21);
const _minTap = 44.0;
const _maxScreens = 8.0;

void main() {
  setUpAll(loadAppFonts);

  for (final (mode, en, scale) in [
    ('ja', false, 1.0),
    ('en', true, 1.0),
    ('ja_big', false, 1.3),
  ]) {
    testWidgets('landscape usability $mode', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = _size * 2;
      tester.view.padding = FakeViewPadding(
          left: _notch.left * 2,
          right: _notch.right * 2,
          bottom: _notch.bottom * 2);
      tester.view.viewPadding = tester.view.padding;

      SharedPreferences.setMockInitialValues({});
      late final SettingsController settings;
      late final MonetizationController monetization;
      late final GameState game;
      await tester.runAsync(() async {
        settings = SettingsController();
        await settings.init();
        Tr.language = en ? AppLanguage.english : AppLanguage.japanese;
        monetization = MonetizationController(
            adService: NoOpAdService(), purchases: _NoStore());
        await monetization.initialize();
        game = GameState();
        await game.startNewGame('Seiran FC');
        game.save!.firstRunGuideDismissed = true;
      });
      addTearDown(() => Tr.language = AppLanguage.system);

      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        // はみ出した部品の場所(lib/ の行)も添える。CI と手元で字幅が違い、
        // 手元では再現しないことがあるため。
        final at = RegExp(r'lib/[\w/]+\.dart:\d+')
            .allMatches(d.toString())
            .map((m) => m.group(0))
            .toSet()
            .take(3)
            .join(', ');
        problems.add(
            '$where: ${d.exceptionAsString().split('\n').first} [$at]');
      };

      const app = SoccerManagerApp();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: game),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<MonetizationController>.value(
              value: monetization),
        ],
        child: MaterialApp(
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
      ));
      await tester.pump();

      double heightPt(Element e) {
        final ro = e.renderObject! as RenderBox;
        final a = ro.localToGlobal(Offset.zero);
        final b = ro.localToGlobal(ro.size.bottomRight(Offset.zero));
        return b.dy - a.dy;
      }

      void checkTaps(String page) {
        // ページのタブ(グループの帯)と、タブの段。
        for (final e in find
            .descendant(of: find.byType(GroupPage), matching: find.byType(InkWell))
            .hitTestable()
            .evaluate()) {
          final h = heightPt(e);
          if (h < _minTap) problems.add('$page: page tab ${h.round()}pt');
          break;
        }
        for (final e in find.byType(Tab).hitTestable().evaluate()) {
          final h = heightPt(e);
          if (h < _minTap) problems.add('$page: tab ${h.round()}pt');
          break;
        }
      }

      void checkLength(String page) {
        for (final e in find.byType(Scrollable).hitTestable().evaluate()) {
          final pos = ((e as StatefulElement).state as ScrollableState).position;
          if (pos.axis != Axis.vertical || !pos.hasContentDimensions) continue;
          final screens = (pos.maxScrollExtent + pos.viewportDimension) /
              pos.viewportDimension;
          // 文字を大きくすると、その分だけ長くなってよい。
          if (screens > _maxScreens * scale) {
            problems.add('$page: ${screens.toStringAsFixed(1)} screens long');
          }
        }
      }

      final pages = en
          ? ['Status', 'Finance', 'Club', 'Players', 'Transfers', 'League', 'Office']
          : ['状況', '経営', 'クラブ', '選手', '移籍', 'リーグ', 'オーナー室'];
      for (final p in pages) {
        where = p;
        final f = find.text(p).hitTestable();
        expect(f, findsWidgets, reason: 'sidebar item $p is not reachable');
        // 左のメニューの高さ。
        final item = find.ancestor(of: f.first, matching: find.byType(InkWell));
        final h = heightPt(item.evaluate().first);
        if (h < _minTap) problems.add('sidebar $p ${h.round()}pt');
        await tester.tap(f.first);
        await tester.pump(const Duration(milliseconds: 300));
        checkTaps(p);
        checkLength(p);
        // ページの中のタブを順に開く。
        final labels = <String>[
          for (final e in find
              .descendant(
                  of: find.byType(GroupPage), matching: find.byType(InkWell))
              .hitTestable()
              .evaluate())
            ...[
              for (final t in find
                  .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
                  .evaluate())
                (t.widget as Text).data ?? '',
            ],
          for (final e in find.byType(Tab).hitTestable().evaluate())
            (e.widget as Tab).text ?? '',
        ]..removeWhere((s) => s.isEmpty);
        for (final l in labels) {
          where = '$p/$l';
          final tf = find.text(l).hitTestable();
          if (tf.evaluate().isEmpty) continue;
          await tester.tap(tf.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
          checkLength(where);
        }
      }

      FlutterError.onError = old;
      expect(problems, isEmpty, reason: problems.toSet().join('\n'));
    });
  }
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
