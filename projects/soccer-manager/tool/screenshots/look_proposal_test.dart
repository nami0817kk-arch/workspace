/// 見た目の案(明るい・暗い)を比べるための撮影。帯も端末の枠も付けず、
/// 横画面の iPhone(2622x1206)で、画面そのものだけを撮る。
///
///     flutter test tool/screenshots/look_proposal_test.dart --update-goldens \
///       --dart-define=LOOK=light   # light / dark
///
/// 書き出し先は `build/look/<LOOK>/`。掲載画像(capture_test.dart)と同じく、
/// 数節進めて実際に遊んだ状態の [MainShell] を、左のメニューを押して開く。
library;

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
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/funds_pack.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/screens/main_shell.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:soccer_manager/widgets/fm_panel.dart';
import 'package:soccer_manager/widgets/landscape_scale.dart';

const _look = String.fromEnvironment('LOOK', defaultValue: 'dark');
const _logical = Size(874, 402);

const _shots = <(String, String, String?)>[
  ('01_状況', '状況', null),
  ('02_経営', '経営', null),
  ('03_移籍', '移籍', null),
  ('04_施設', 'クラブ', '施設'),
];

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
  final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('見た目の案を撮る ($_look)', (tester) async {
    addTearDown(tester.view.reset);
    // テストの既定では影が「くっきりした板」で描かれる。実機と同じ柔らかい
    // 影で撮る。
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = _logical * 3.0;
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => Tr.language = AppLanguage.system);

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
      for (var attempt = 0; attempt < 30; attempt++) {
        await gameState.startNewGame('青嵐フットボールクラブ');
        await gameState.simulateAheadMatchdays(8);
        var guard = 0;
        while (!gameState.isTransferWindowOpen && guard++ < 40) {
          await gameState.simulateAheadMatchdays(1);
        }
        final standings = gameState.save!.league.sortedStandings;
        final rank =
            standings.indexWhere((r) => r.teamId == gameState.userTeam.id) + 1;
        if (rank <= gameState.save!.boardTargetRank - 4 &&
            gameState.isTransferWindowOpen &&
            !gameState.isTransferDeadlineDay) {
          break;
        }
      }
      gameState.save!.pendingMoments.clear();
      for (final role in StaffRole.values) {
        final candidates = gameState.staffCandidatesFor(role);
        if (candidates.isEmpty) continue;
        final best = candidates
            .reduce((a, b) => a.effectiveLevel >= b.effectiveLevel ? a : b);
        await gameState.hireStaff(best.id);
      }
      gameState.save!.firstRunGuideDismissed = true;
    });

    final app = const SoccerManagerApp();
    final light = _look == 'light';
    final brightness = light ? Brightness.light : Brightness.dark;

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>.value(value: gameState),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<MonetizationController>.value(
            value: monetization),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        theme: app.buildTheme(brightness, boldText: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: _logical,
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: LandscapeScale(
              child: FmThemeScope(
                light: app.buildTheme(Brightness.light, boldText: false),
                dark: app.buildTheme(Brightness.dark, boldText: false),
                child: const MainShell(),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    Future<void> open(String text) async {
      final f = find.text(text).hitTestable();
      expect(f, findsWidgets, reason: '「$text」が押せる所に無い');
      await tester.tap(f.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final (name, menu, tab) in _shots) {
      await open(menu);
      if (tab != null) await open(tab);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: '$name の描画で例外');
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../../build/look/$_look/$name.png'));
    }
    // 終わる前に戻す(戻さないとテストの枠組みが失敗にする)。
    debugDisableShadows = true;
  });
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
