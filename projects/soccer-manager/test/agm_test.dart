import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/agm_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 株主総会の議案(株主の要求)と、決算の法人税の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('法人税', () {
    test('黒字に30%。繰越欠損を先に引く', () {
      expect(AgmEngine.tax(profit: 1000, carry: 0), (300, 0));
      expect(AgmEngine.tax(profit: -500, carry: 0), (0, 500));
      expect(AgmEngine.tax(profit: 300, carry: 500), (0, 200));
      expect(AgmEngine.tax(profit: 1000, carry: 400), (180, 0));
    });
  });

  group('要求の選び方', () {
    test('重いものから1つ: 人件費 → 配当 → 監督', () {
      expect(
          AgmEngine.pick(
              wageRatio: 0.9,
              profit: 100,
              outsideShare: 20,
              managerStanding: 10,
              hasManager: true),
          AgmDemand.wageCut);
      expect(
          AgmEngine.pick(
              wageRatio: 0.5,
              profit: 100,
              outsideShare: 20,
              managerStanding: 10,
              hasManager: true),
          AgmDemand.payout);
      expect(
          AgmEngine.pick(
              wageRatio: 0.5,
              profit: 100,
              outsideShare: 0,
              managerStanding: 10,
              hasManager: true),
          AgmDemand.manager);
      expect(
          AgmEngine.pick(
              wageRatio: 0.5,
              profit: -100,
              outsideShare: 20,
              managerStanding: 60,
              hasManager: true),
          isNull);
    });
  });

  group('ゲームの中', () {
    test('配当の上乗せを受けると払い、株主は喜ぶ。断ると期待が下がる', () async {
      final gs = GameState();
      await gs.startNewGame('総会FC');
      final s = gs.save!;
      s.shareholderExpectation = 50;
      s.agmDemand = AgmDemand.payout.name;
      s.agmPayout = 500;
      final budget = s.budget;
      expect(await gs.answerAgmDemand(accept: true), isTrue);
      expect(s.budget, budget - 500);
      expect(s.shareholderExpectation, 50 + AgmDemand.payout.acceptDelta);
      expect(gs.agmDemand, isNull);

      s.agmDemand = AgmDemand.payout.name;
      await gs.answerAgmDemand(accept: false);
      expect(s.shareholderExpectation,
          50 + AgmDemand.payout.acceptDelta + AgmDemand.payout.rejectDelta);
    });

    test('人件費を下げる約束をすると、上限が決まる', () async {
      final gs = GameState();
      await gs.startNewGame('総会FC');
      final s = gs.save!;
      s.agmDemand = AgmDemand.wageCut.name;
      s.agmWageRatio = 0.9;
      await gs.answerAgmDemand(accept: true);
      expect(s.agmWageRatioPledge, closeTo(0.8, 1e-9));
    });

    test('監督の交代を受けると、監督は解任される', () async {
      final gs = GameState();
      await gs.startNewGame('総会FC');
      final s = gs.save!;
      s.wageBudget = 99999999;
      s.budget = 99999999;
      if (gs.currentManager == null) {
        await gs.hireStaff(gs.staffCandidatesFor(StaffRole.manager).first.id);
      }
      s.agmDemand = AgmDemand.manager.name;
      await gs.answerAgmDemand(accept: true);
      expect(gs.currentManager, isNull);
    });

    test('季が終わると決算と総会があり、ニュースに残る', () async {
      final gs = GameState();
      await gs.startNewGame('総会FC');
      await gs.simulateAheadMatchdays(60);
      await gs.startNextSeason();
      final news = gs.save!.newsLog.map((n) => n.context).toSet();
      expect(news.any((c) => c.contains('決算') || c.contains('Accounts')),
          isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('総会の項目は保存して読み戻せる', () async {
      final gs = GameState();
      await gs.startNewGame('総会FC');
      final s = gs.save!
        ..agmDemand = AgmDemand.wageCut.name
        ..agmWageRatio = 0.85
        ..agmWageRatioPledge = 0.7
        ..taxLossCarry = 1234;
      final c = SaveGame.fromJson(s.toJson());
      expect(c.agmDemand, AgmDemand.wageCut.name);
      expect(c.agmWageRatio, closeTo(0.85, 1e-9));
      expect(c.agmWageRatioPledge, closeTo(0.7, 1e-9));
      expect(c.taxLossCarry, 1234);
    });
  });
}
