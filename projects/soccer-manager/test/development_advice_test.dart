import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/screens/training_screen.dart';
import 'package:soccer_manager/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/development_advisor.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/state/game_state.dart';

import 'support/app_fonts.dart';

/// 育成アドバイスが「読むだけ」で終わらず、その場で適用できることを固定する。
///
/// 助言は以前からあったが、対応は利用者任せだった。「メンター未設定」と言われて
/// から、適任のベテランを自分で探して設定する必要がある。毎週これを選手ごとに
/// 繰り返すのが育成の手間の中心だった。

/// 助言が出る条件を全員から取り除く。
///
/// advise() は上位6件で打ち切り、しかも noMentor は優先度が最下位。ランダム
/// 生成されたスカッドに疲労などの助言が6件以上あると、検証したい提案が
/// 切り捨てられる。実際これでテストが引き次第で落ちていた。
/// 検証したい条件だけを、この後に作る。
void _clearAdviceTriggers(Team team) {
  for (final p in team.players) {
    p.fatigue = 0;
    p.matchSharpness = 100;
    p.age = 26; // 伸びしろ・メンターの年齢条件から外す
    p.mentorId = null;
    p.drillAttributeKey = null;
    p.developmentTargetRole = null;
    p.potential = p.overall;
  }
}

void main() {
  // 代替フォントは全文字が同じ幅で、英語だけおよそ2倍に太る。
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('メンター未設定の提案は、その場で付けられる', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    _clearAdviceTriggers(team);

    // メンター候補(28歳以上)と、付ける相手(23歳以下)を明示的に作る。
    final veteran = team.players[0]..age = 32;
    final young = team.players[1]
      ..age = 20
      ..mentorId = null;
    expect(veteran.age, greaterThanOrEqualTo(TrainingEngine.minMentorAge));

    final advice = DevelopmentAdvisor.advise(team).firstWhere(
        (a) => a.kind == AdviceKind.noMentor && a.playerId == young.id);
    expect(advice.fix, isA<AssignMentorFix>(), reason: '提案に「誰を付けるか」が入っていない');

    expect(game.applyAdviceFix(advice), isTrue);
    expect(young.mentorId, isNotNull, reason: 'メンターが設定されていない');

    // 付けた相手は条件を満たしていること。
    final mentor = team.players.firstWhere((p) => p.id == young.mentorId);
    expect(mentor.age, greaterThanOrEqualTo(TrainingEngine.minMentorAge));
    expect(mentor.id, isNot(young.id));
  });

  test('疲労の提案は、個別方針を休養にする', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    _clearAdviceTriggers(team);
    final tired = team.players.first;
    tired.fatigue = DevelopmentAdvisor.fatigueThreshold + 5;
    tired.individualFocus = null;

    final advice = DevelopmentAdvisor.advise(team)
        .firstWhere((a) => a.kind == AdviceKind.highFatigue);
    expect(advice.fix, isA<RestFix>());

    expect(game.applyAdviceFix(advice), isTrue);
    expect(
      team.players.firstWhere((p) => p.id == advice.playerId).individualFocus,
      TrainingFocus.rest,
    );
  });

  test('伸びしろの提案は、一番低い属性の特訓を設定する', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    _clearAdviceTriggers(team);
    final young = team.players.first;
    young.age = 19;
    young.potential =
        (young.overall + DevelopmentAdvisor.potentialGapThreshold + 5)
            .clamp(1, 99);
    young.drillAttributeKey = null;
    young.developmentTargetRole = null;

    final advice = DevelopmentAdvisor.advise(team).firstWhere(
        (a) => a.kind == AdviceKind.unusedPotential && a.playerId == young.id);
    final fix = advice.fix;
    expect(fix, isA<SetDrillFix>());

    expect(game.applyAdviceFix(advice), isTrue);
    expect(young.drillAttributeKey, (fix as SetDrillFix).attributeKey);
  });

  test('自動で決められない提案には手を用意しない', () async {
    final game = GameState();
    await game.startNewGame('テストFC');
    final team = game.userTeam;
    _clearAdviceTriggers(team);
    final rusty = team.players.first;
    rusty.injuryWeeks = 0;
    rusty.matchSharpness = DevelopmentAdvisor.sharpnessThreshold - 10;

    final advice = DevelopmentAdvisor.advise(team)
        .firstWhere((a) => a.kind == AdviceKind.lowSharpness);
    // 出場機会を作るかローンに出すかは、こちらでは決められない。
    expect(advice.fix, isNull);
    expect(game.applyAdviceFix(advice), isFalse);
  });

  /// 助言カードは該当選手がいるときだけ出る。新規セーブで必ず出るとは限らず、
  /// 画面網羅のテストでは運任せになる(実際、提案行の溢れをローカルで
  /// 取りこぼし CI で落ちた)。助言が必ず出る状態を作って描画する。
  for (final lang in const [AppLanguage.japanese, AppLanguage.english]) {
    for (final size in const [Size(360, 780), Size(320, 568)]) {
      for (final scale in const [1.0, SettingsController.maxTextScale]) {
      testWidgets(
        '助言が出ている状態のトレーニング画面が崩れない '
        '(${lang == AppLanguage.english ? "en" : "ja"}, '
        '${size.width.toInt()}x${size.height.toInt()}, '
        '文字${(scale * 100).round()}%)',
        (WidgetTester tester) async {
          SharedPreferences.setMockInitialValues({});
          late final SettingsController settings;
          late final MonetizationController monetization;
          late final GameState game;
          await tester.runAsync(() async {
            settings = SettingsController();
            await settings.init();
            monetization = MonetizationController(
                adService: NoOpAdService(), purchases: _StubPurchases());
            await monetization.initialize();
            game = GameState();
            await game.startNewGame('テストFC');
          });
          Tr.language = lang;
          addTearDown(() => Tr.language = AppLanguage.system);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;

          // 4種類すべての助言が出る状態を作る。
          final team = game.userTeam;
          _clearAdviceTriggers(team);
          _clearAdviceTriggers(team);
          team.players[0].age = 32;
          team.players[1]
            ..age = 20
            ..mentorId = null;
          team.players[2].fatigue = DevelopmentAdvisor.fatigueThreshold + 5;
          team.players[3]
            ..injuryWeeks = 0
            ..matchSharpness = DevelopmentAdvisor.sharpnessThreshold - 10;
          team.players[4]
            ..age = 19
            ..potential = 95
            ..drillAttributeKey = null
            ..developmentTargetRole = null;
          expect(DevelopmentAdvisor.advise(team), isNotEmpty);

          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<GameState>.value(value: game),
              ChangeNotifierProvider<SettingsController>.value(value: settings),
              ChangeNotifierProvider<MonetizationController>.value(
                  value: monetization),
            ],
            child: MaterialApp(
              locale: Locale(lang == AppLanguage.english ? 'en' : 'ja'),
              // アプリ本来のテーマで測る。既定テーマのままだと余白も文字種も
              // 本物と違い、実機で起きないはみ出しを拾う。
              theme: const SoccerManagerApp()
                  .buildTheme(Brightness.light, boldText: false),
              // 利用者は文字を 130% まで大きくできる。既定で収まっていても
              // 大きくすると溢れる箇所があるため、上限でも見る。
              builder: (context, inner) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale)),
                child: inner!,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TrainingScreen(),
            ),
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // はみ出しは throw されず FlutterError.onError に報告される。
          expect(tester.takeException(), isNull, reason: '助言カードのある画面が崩れている');
        },
      );
      }
    }
  }
}

class _StubPurchases implements PurchaseService {
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
