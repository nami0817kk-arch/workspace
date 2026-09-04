import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/data/quick_access_destinations.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/season_award.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/screens/fixtures_screen.dart';
import 'package:soccer_manager/screens/home_screen.dart';
import 'package:soccer_manager/screens/lineup_screen.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/state/settings_controller.dart';

import 'support/app_fonts.dart';

/// 「データが溜まってから出る UI」を、実際の文字幅で検査する。
///
/// 既存の screen_render_test には2つの穴があった。
///
/// 1. 新規セーブしか描画しない。受賞歴・疲労ローテーション提案・資金不足の
///    表示などは条件が立たないので一度も描画されない。画面名は対象一覧に
///    載っているため、覆えているように見えるのが厄介なところ。
/// 2. 実フォントを読んでいない。テストの代替フォントは全文字が同じ幅で、
///    英語だけおよそ2倍に太る(support/app_fonts.dart 参照)。実機では
///    起きないはみ出しを検出してしまう。
///
/// ここでは条件を乱数に頼らず直接組み立ててから、実フォントとアプリ本来の
/// テーマで描画する。文字サイズは既定と設定の上限(130%)の両方で見る。
/// 既定で収まっていても、利用者が文字を大きくすると溢れるため。
List<({String label, WidgetBuilder builder})> _screensUnderTest() => [
      for (final d in quickAccessDestinations)
        (label: d.label, builder: d.builder),
      (label: 'ホーム', builder: (_) => const HomeScreen()),
      (label: 'スカッド', builder: (_) => const SquadScreen()),
      (label: '戦術', builder: (_) => const LineupScreen()),
      (label: '日程', builder: (_) => const FixturesScreen()),
    ];

void main() {
  setUpAll(loadAppFonts);

  for (final lang in const [AppLanguage.japanese, AppLanguage.english]) {
    final langLabel = lang == AppLanguage.english ? 'en' : 'ja';
    for (final scale in const [1.0, SettingsController.maxTextScale]) {
      final scaleLabel = '${(scale * 100).round()}%';

      testWidgets(
        'データが溜まった状態でも全画面が収まる ($langLabel, 320x568, 文字$scaleLabel)',
        (WidgetTester tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = const Size(320, 568);

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
            await gameState.startNewGame('テストFC');
            _accumulateState(gameState);
          });

          // SettingsController.init() が保存値から Tr.language を上書きする
          // ため、言語の指定はその後で行う。先に設定すると消される。
          Tr.language = lang;
          addTearDown(() => Tr.language = AppLanguage.system);

          // 条件が本当に立っているかを先に確かめる。立っていなければ
          // 「溜まった状態を見た」と言えない。
          expect(gameState.save!.seasonAwards, isNotEmpty,
              reason: '受賞歴が入っていない');
          expect(gameState.rotationSuggestions, isNotEmpty,
              reason: '疲労ローテーション提案が出ていない');
          expect(gameState.save!.incomingOffers, isNotEmpty,
              reason: '移籍オファーが入っていない');

          final theme = const SoccerManagerApp()
              .buildTheme(Brightness.light, boldText: false);

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
                  theme: theme,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, inner) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: inner!,
                  ),
                  home: child,
                ),
              );

          final failures = <String>[];
          for (final dest in _screensUnderTest()) {
            await tester.pumpWidget(wrap(Builder(builder: dest.builder)));
            // はみ出しはレイアウト時に出るので settle は待たない。待つと、
            // 終わらないアニメーションを持つ画面でテストごと止まる。
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            final err = tester.takeException();
            if (err != null) {
              failures
                  .add('${dest.label}: ${err.toString().split('\n').first}');
            }
          }

          expect(failures, isEmpty,
              reason: '$langLabel 文字$scaleLabel で収まらない画面がある:\n'
                  '${failures.join('\n')}');
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );
    }
  }
}

/// 長く遊んだセーブに現れる条件を、乱数に頼らず直接作る。
///
/// 検証したい条件以外は取り除いておく。生成された選手団の状態に任せると、
/// 引き次第で条件が立ったり立たなかったりしてテストが不安定になる。
void _accumulateState(GameState game) {
  final save = game.save!;
  final team = game.userTeam;

  // 1. 受賞歴。個人タイトル画面はこれが無いと中身が描かれない。
  save.seasonAwards.add(
    SeasonAward(
      season: 1,
      topScorerId: team.players.first.id,
      topScorerName: team.players.first.name,
      topScorerTeamName: team.name,
      topScorerTeamId: team.id,
      topScorerGoals: 24,
      mvpId: team.players.first.id,
      mvpName: team.players.first.name,
      mvpTeamName: team.name,
      mvpTeamId: team.id,
      goldenGloveId: team.players.last.id,
      goldenGloveName: team.players.last.name,
      goldenGloveTeamName: team.name,
      goldenGloveTeamId: team.id,
      goldenGloveCleanSheets: 15,
    ),
  );

  // 2. 疲労ローテーション提案。スタメンを疲労させ、控えを休ませる。
  //    控えは負傷・代表招集・レンタル・出場停止だと候補から外れるので、
  //    それらも取り除いてから1つだけ条件を立てる。
  for (final p in team.players) {
    final starting = team.startingXI.contains(p.id);
    p.fatigue = starting ? 95 : 0;
    if (!starting) {
      p.injuryWeeks = 0;
      p.suspendedMatches = 0;
      p.internationalDutyWeeksRemaining = 0;
      p.loanedOutWeeksRemaining = 0;
    }
  }

  // 3. 資金不足。移籍市場で「獲得できません」の錠アイコンが出る条件。
  save.budget = 0;

  // 4. 受け取り中の移籍オファー。ホームと通知バッジに出る。
  save.incomingOffers.add(
    IncomingOffer(
      id: 'lategame-offer',
      playerId: team.players.first.id,
      playerName: team.players.first.name,
      buyerClubName: 'Wanderers Athletic Club',
      amount: 4800,
    ),
  );
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
