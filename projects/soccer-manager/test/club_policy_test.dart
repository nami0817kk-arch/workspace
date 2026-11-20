import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/policy_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

PolicyResult? _score(ClubPolicy p,
        {int rank = 3, int target = 4, int young = 0, int profit = 0}) =>
    PolicyEngine.score(
        policy: p,
        finalRank: rank,
        targetRank: target,
        youngCount: young,
        seasonProfit: profit);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('採点', () {
    test('バランスは何も動かさない', () {
      expect(_score(ClubPolicy.balanced), isNull);
    });

    test('勝利優先: 目標に届けばサポーター+6、届かなければ-6。株主は毎季-3', () {
      final hit = _score(ClubPolicy.win, rank: 4, target: 4)!;
      expect((hit.supporters, hit.shareholders), (6, -3));
      final miss = _score(ClubPolicy.win, rank: 5, target: 4)!;
      expect((miss.supporters, miss.shareholders), (-6, -3));
    });

    test('育成優先: 若手が足りていれば両方上がり、足りなければ両方下がる', () {
      final ok = _score(ClubPolicy.develop,
          young: PolicyEngine.youngCountRequired)!;
      expect((ok.supporters, ok.shareholders), (4, 2));
      final ng = _score(ClubPolicy.develop,
          young: PolicyEngine.youngCountRequired - 1)!;
      expect((ng.supporters, ng.shareholders), (-3, -3));
    });

    test('収益優先: 黒字なら株主+6、赤字なら-6。サポーターは毎季-3', () {
      final ok = _score(ClubPolicy.profit, profit: 1)!;
      expect((ok.supporters, ok.shareholders), (-3, 6));
      final ng = _score(ClubPolicy.profit, profit: 0)!;
      expect((ng.supporters, ng.shareholders), (-3, -6));
    });

    test('どの方針も、どちらかの期待を必ず傷つける余地を持つ(得だけの方針は無い)', () {
      for (final p in [ClubPolicy.win, ClubPolicy.profit]) {
        final r = _score(p, rank: 1, target: 4, profit: 999)!;
        expect(r.supporters < 0 || r.shareholders < 0, isTrue, reason: '$p');
      }
    });
  });

  group('効き目', () {
    test('倍率は、方針ごとに1か所だけ動く', () {
      expect(PolicyEngine.wageCapMultiplier(ClubPolicy.win), 1.10);
      expect(PolicyEngine.facilityCostMultiplier(ClubPolicy.develop), 0.90);
      expect(PolicyEngine.incomeMultiplier(ClubPolicy.profit), 1.05);
      for (final p in ClubPolicy.values) {
        final moved = [
          PolicyEngine.wageCapMultiplier(p),
          PolicyEngine.facilityCostMultiplier(p),
          PolicyEngine.incomeMultiplier(p),
        ].where((m) => m != 1.0).length;
        expect(moved, p == ClubPolicy.balanced ? 0 : 1, reason: '$p');
      }
    });
  });

  group('ゲームの中', () {
    test('開幕前は選べ、1節でも進むと変えられない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(gs.canChangeClubPolicy, isTrue);
      expect(await gs.setClubPolicy(ClubPolicy.profit), isTrue);
      expect(gs.clubPolicy, ClubPolicy.profit);

      await gs.playNextMatchdayQuickSim();
      expect(gs.canChangeClubPolicy, isFalse);
      expect(await gs.setClubPolicy(ClubPolicy.win), isFalse);
      expect(gs.clubPolicy, ClubPolicy.profit);
    });

    test('収益優先は週収入を増やし、勝利優先は週給の上限を広げ、育成優先は増築費を下げる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final id = gs.save!.userTeamId;
      final income = gs.weeklyIncomeFor(id);
      final cap = gs.wageBudgetCap;
      final facility = gs.save!.infrastructure.facilityLevels.keys.first;
      final cost = gs.facilityUpgradeCostFor(facility);

      await gs.setClubPolicy(ClubPolicy.profit);
      expect(gs.weeklyIncomeFor(id), greaterThan(income));
      await gs.setClubPolicy(ClubPolicy.win);
      expect(gs.wageBudgetCap, greaterThan(cap));
      await gs.setClubPolicy(ClubPolicy.develop);
      expect(gs.facilityUpgradeCostFor(facility), lessThan(cost));
    });

    test('採点を回すと、期待が動いてニュースに残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setClubPolicy(ClubPolicy.profit);
      final save = gs.save!;
      save.confidence = 50;
      save.shareholderExpectation = 50;
      final news = save.newsLog.length;
      gs.debugScoreClubPolicy(finalRank: 3);
      expect(save.confidence, 47);
      expect(save.newsLog.length, news + 1);
    });

    test('方針は保存して読み戻せ、無い旧セーブはバランスで読める', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      await gs.setClubPolicy(ClubPolicy.develop);
      final json = gs.save!.toJson();
      expect(SaveGame.fromJson(json).clubPolicy, ClubPolicy.develop);
      json.remove('clubPolicy');
      expect(SaveGame.fromJson(json).clubPolicy, ClubPolicy.balanced);
    });
  });
}
