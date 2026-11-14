import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/club_ranking_engine.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('上の部ほど底上げが大きい', () {
    expect(ClubRankingEngine.tierBase(1), greaterThan(ClubRankingEngine.tierBase(5)));
    expect(ClubRankingEngine.estimate(playersValue: 500, tier: 1),
        500 + ClubRankingEngine.tierBase(1));
  });

  test('価値の高い順に並び、自クラブの順位が分かる', () {
    final r = ClubRankingEngine.rank(const [
      RankedClub(name: 'B', value: 100, tier: 2, isUser: false),
      RankedClub(name: 'U', value: 300, tier: 5, isUser: true),
      RankedClub(name: 'A', value: 100, tier: 1, isUser: false),
    ]);
    expect(r.map((c) => c.name), ['U', 'A', 'B']);
    expect(ClubRankingEngine.userRank(r), 1);
  });

  test('ゲームの中では、全部の部のクラブが並び、自クラブが含まれる', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final r = gs.worldClubRanking;
    expect(r.length, greaterThan(20));
    expect(r.where((c) => c.isUser).length, 1);
    expect(ClubRankingEngine.userRank(r), greaterThan(0));
  });
}
