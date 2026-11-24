import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/risk_engine.dart';
import 'package:soccer_manager/models/community_activity.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('出来事の計算', () {
    test('確率に入らなければ何も起きない', () {
      expect(
          RiskEngine.roll(
              chanceRoll: 0.9,
              kindRoll: 0,
              sizeRoll: 0,
              tier: 1,
              communityLevel: 0),
          isNull);
    });

    test('不祥事は地域貢献が厚いほど信頼の傷が浅い', () {
      Incident at(int lv) => RiskEngine.roll(
          chanceRoll: 0,
          kindRoll: 0, // scandal
          sizeRoll: 0.5,
          tier: 3,
          communityLevel: lv)!;
      expect(at(0).kind, IncidentKind.scandal);
      expect(at(0).trustLoss, greaterThan(at(5).trustLoss));
    });

    test('損失は保険の半分、基金、クラブの順に払われる', () {
      final c = RiskEngine.cover(loss: 600, insured: true, fund: 100);
      expect(c.byInsurance, 300);
      expect(c.byFund, 100);
      expect(c.byClub, 200);
      expect(c.fundAfter, 0);
      final n = RiskEngine.cover(loss: 600, insured: false, fund: 1000);
      expect(n.byInsurance, 0);
      expect(n.byClub, 0);
      expect(n.fundAfter, 400);
    });
  });

  group('ゲームの中', () {
    test('基金に積むと資金が減り、引き出すと戻る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      final before = save.budget;
      expect(await gs.depositReserveFund(200), isTrue);
      expect(save.reserveFund, 200);
      expect(save.budget, before - 200);
      expect(await gs.depositReserveFund(-200), isTrue);
      expect(save.budget, before);
      expect(await gs.depositReserveFund(-200), isFalse);
    });

    // 地域貢献は 2026-11-25 から、Lv ではなく季ごとに選ぶ活動。
    test('地域活動は選ぶとその季の費用を払い、重ねて選べない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.budget = 100000;
      final cost = gs.communityCostOf(CommunityActivity.cleanup);
      expect(await gs.startCommunityActivity(CommunityActivity.cleanup), isTrue);
      expect(save.budget, 100000 - cost);
      expect(save.communityLevel, CommunityActivity.cleanup.scandalCushion);
      expect(
          await gs.startCommunityActivity(CommunityActivity.cleanup), isFalse);
      expect(await gs.stopCommunityActivity(CommunityActivity.cleanup), isTrue);
      expect(save.communityLevel, 0);
    });

    test('出来事が起きると、基金から払われニュースに残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.reserveFund = 100000;
      final news = save.newsLog.length;
      final budget = save.budget;
      gs.debugResolveSeasonRisks(0.0, 0.5, 0.5);
      expect(save.newsLog.length, news + 1);
      expect(save.budget, budget); // 基金で全額まかなう
      expect(save.reserveFund, lessThan(100000));
    });

    test('保存して読み戻せ、無い旧セーブは備え無し', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!
        ..insured = true
        ..reserveFund = 300
        ..communityActivities = [CommunityActivity.cleanup];
      final json = gs.save!.toJson();
      final back = SaveGame.fromJson(json);
      expect(back.insured, isTrue);
      expect(back.reserveFund, 300);
      expect(back.communityActivities, [CommunityActivity.cleanup]);
      json
        ..remove('insured')
        ..remove('reserveFund')
        ..remove('communityActivities');
      final old = SaveGame.fromJson(json);
      expect(old.insured, isFalse);
      expect(old.reserveFund, 0);
      expect(old.communityLevel, 0);
    });
  });
}
