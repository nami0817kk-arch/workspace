import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/screens/fixtures_screen.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/lineup_screen.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/state/settings_controller.dart';

/// クイックアクセスから開く全画面を実際に描画して、はみ出しと例外を検出する。
///
/// これまで描画されていたのは start / 新クラブのダイアログ / メインタブ4つ /
/// オンボーディングだけで、ここで開く20画面は一度も描画されていなかった。
/// オーバーフローはリリースビルドでは縞模様も例外も出ないため、実機で目視する
/// まで気づけない。デバッグビルドなら RenderFlex のはみ出しが報告されるので、
/// ここで機械的に踏む。
///
/// 検出には tester.takeException() を使う。はみ出しは呼び出し側へ throw される
/// のではなく FlutterError.onError に報告されるため、try/catch では捕まらない。
///
/// 幅は狭いスマートフォン(360)と、さらに狭い小型端末(320)。言語は日本語と英語。
/// 英語はラベルが横に長くなるため、日本語で収まっていても英語だけはみ出す。
/// 検査する画面。クイックアクセスの登録に、ボトムナビの4画面を足したもの。
///
/// メインタブは quickAccessDestinations に入っていないため、以前はこの網の
/// 外にあった。実際、ホーム画面のはみ出しを取りこぼし、別のテストが偶然
/// 拾っている。利用者が最も長く見る4画面なので、ここに含める。
List<({String label, WidgetBuilder builder})> _screensUnderTest() => [
      for (final d in quickAccessDestinations)
        (label: d.label, builder: d.builder),
      (label: 'ホーム', builder: (_) => const HomeScreen()),
      (label: 'スカッド', builder: (_) => const SquadScreen()),
      (label: '戦術', builder: (_) => const LineupScreen()),
      (label: '日程', builder: (_) => const FixturesScreen()),
    ];

void main() {
  const sizes = <String, Size>{
    '360x780': Size(360, 780),
    '320x568': Size(320, 568),
  };

  for (final lang in const [AppLanguage.japanese, AppLanguage.english]) {
    final langLabel = lang == AppLanguage.english ? 'en' : 'ja';

    for (final entry in sizes.entries) {
      testWidgets(
        'every quick-access screen renders cleanly '
        '($langLabel, ${entry.key})',
        (WidgetTester tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = entry.value;

          // testWidgets は疑似時間で動くため、SharedPreferences を待つ処理は
          // そのままでは完了しない。セットアップだけ実時間で走らせる。
          SharedPreferences.setMockInitialValues({});
          late final SettingsController settings;
          late final MonetizationController monetization;
          late final GameState gameState;
          await tester.runAsync(() async {
            settings = SettingsController();
            await settings.init();
            // 実装をそのまま使うと課金プラグインへ接続しにいき、テスト完了後に
            // PlatformException が遅れて届いて無関係のテストを落とす。
            // 広告・課金は差し替える。
            monetization = MonetizationController(
              adService: NoOpAdService(),
              purchases: _StubPurchaseService(),
            );
            await monetization.initialize();
            gameState = GameState();
            await gameState.startNewGame('テストFC');
          });

          // SettingsController.init() が保存値から Tr.language を上書きするため、
          // 言語の指定はその後で行う。先に設定すると消される。
          Tr.language = lang;
          addTearDown(() => Tr.language = AppLanguage.system);

          Widget wrap(Widget child) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<GameState>.value(value: gameState),
                  ChangeNotifierProvider<SettingsController>.value(
                      value: settings),
                  ChangeNotifierProvider<MonetizationController>.value(
                      value: monetization),
                ],
                child: MaterialApp(
                  locale: Locale(langLabel),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: child,
                ),
              );

          // 言語が本当に切り替わっているかを先に確かめる。ここが効いていないと
          // 「両言語で検証した」という前提が崩れ、片方しか見ていないことになる。
          await tester.pumpWidget(
              wrap(Builder(builder: quickAccessDestinations.first.builder)));
          await tester.pump();
          tester.takeException();
          expect(
            find.text(lang == AppLanguage.english ? 'Training' : 'トレーニング'),
            findsWidgets,
            reason: '$langLabel のはずが、その言語の見出しが描画されていない',
          );

          final failures = <String>[];
          for (final dest in _screensUnderTest()) {
            await tester.pumpWidget(wrap(Builder(builder: dest.builder)));
            // はみ出しはレイアウト時に出るので settle は待たない。待つと、
            // 終わらないアニメーションを持つ画面でテストごと止まる。
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));

            // 1画面で止めず全部見る。まとめて出た方が傾向を掴みやすい。
            final err = tester.takeException();
            if (err != null) {
              failures
                  .add('${dest.label}: ${err.toString().split('\n').first}');
            }
          }

          expect(
            failures,
            isEmpty,
            reason: '$langLabel ${entry.key} で描画に問題のある画面がある:\n'
                '${failures.join('\n')}',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}

/// ストアに触らない差し替え。画面の描画にはストアの応答は要らない。
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
