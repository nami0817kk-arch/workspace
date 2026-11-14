import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/media_deals_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  group('放映権の計算', () {
    test('固定は順位に関わらず同じ、成績連動は上位ほど多い', () {
      int pay(TvDeal d, int rank) => MediaDealsEngine.tvPayout(
          deal: d, tier: 1, rank: rank, teamCount: 20);
      expect(pay(TvDeal.fixed, 1), pay(TvDeal.fixed, 20));
      expect(pay(TvDeal.performance, 1), greaterThan(pay(TvDeal.fixed, 1)));
      expect(pay(TvDeal.performance, 20), lessThan(pay(TvDeal.fixed, 20)));
      expect(pay(TvDeal.performance, 1), greaterThan(pay(TvDeal.performance, 10)));
    });

    test('上の部ほど基準額が大きい', () {
      expect(MediaDealsEngine.tvBase(1), greaterThan(MediaDealsEngine.tvBase(5)));
    });

    test('命名権の候補は3件で、年数が長いほど週額が低い', () {
      final o = MediaDealsEngine.namingOffers(
          stadiumLevel: 3, tier: 3, managerReputation: 50);
      expect(o.length, 3);
      expect(o[0].yearsRemaining, greaterThan(o[2].yearsRemaining));
      expect(o[0].weeklyIncome, lessThan(o[2].weeklyIncome));
    });
  });

  group('ゲームの中', () {
    test('命名権を結ぶと週収入が増える', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.pendingNamingOffers = MediaDealsEngine.namingOffers(
          stadiumLevel: 1, tier: 5, managerReputation: 50);
      final before = gs.weeklyIncomeFor(save.userTeamId);
      expect(await gs.chooseNamingRights(0), isTrue);
      expect(gs.weeklyIncomeFor(save.userTeamId), greaterThan(before));
      expect(save.pendingNamingOffers, isEmpty);
      final p = gs.weeklyIncomeParts(save.userTeamId);
      expect(p.gate + p.sponsor + p.merchandise,
          gs.weeklyIncomeFor(save.userTeamId));
    });

    test('前払いは資金を増やし、以後の季は分配金が出ない。重ねて受けられない', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      final before = save.budget;
      expect(await gs.takeTvAdvance(), isTrue);
      expect(save.budget, greaterThan(before));
      expect(save.tvHolidaySeasons, MediaDealsEngine.advanceHolidaySeasons);
      expect(await gs.takeTvAdvance(), isFalse);
    });

    test('受け取り方は開幕前に変えられる', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      expect(await gs.setTvDeal(TvDeal.performance), isTrue);
      expect(gs.save!.tvDeal, TvDeal.performance);
    });

    test('保存して読み戻せ、無い旧セーブは固定・契約なし', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.tvDeal = TvDeal.performance;
      gs.save!.tvHolidaySeasons = 1;
      final json = gs.save!.toJson();
      final back = SaveGame.fromJson(json);
      expect(back.tvDeal, TvDeal.performance);
      expect(back.tvHolidaySeasons, 1);
      json
        ..remove('tvDeal')
        ..remove('namingDeal')
        ..remove('pendingNamingOffers');
      final old = SaveGame.fromJson(json);
      expect(old.tvDeal, TvDeal.fixed);
      expect(old.namingDeal, isNull);
      expect(old.pendingNamingOffers, isEmpty);
    });
  });
}
