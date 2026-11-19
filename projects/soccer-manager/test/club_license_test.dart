import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/club_license.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('条件: 1部はスタジアム3、2部は2、1〜3部は資金がマイナスでない', () {
    expect(ClubLicenseEngine.unmet(4, stadiumLevel: 1, budget: -100), isEmpty);
    expect(ClubLicenseEngine.unmet(3, stadiumLevel: 1, budget: 0), isEmpty);
    expect(ClubLicenseEngine.unmet(3, stadiumLevel: 1, budget: -1).length, 1);
    expect(ClubLicenseEngine.unmet(2, stadiumLevel: 1, budget: 0).length, 1);
    expect(ClubLicenseEngine.unmet(2, stadiumLevel: 2, budget: 0), isEmpty);
    expect(ClubLicenseEngine.unmet(1, stadiumLevel: 2, budget: -1).length, 2);
  });

  /// 自クラブが全勝、ほかは全部引き分けで季を終わらせる(首位で昇格の権利)。
  void winEverything(GameState gs) {
    final userId = gs.userTeam.id;
    for (final f in gs.save!.league.fixtures) {
      final home = f.homeTeamId == userId;
      final away = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: home ? 3 : (away ? 0 : 1),
        awayGoals: away ? 3 : (home ? 0 : 1),
        events: [],
      );
    }
  }

  /// 4部で戦っている形にする(3部へ上がるにはライセンスで資金を見る)。
  void playInTier4(GameState gs) {
    final s = gs.save!;
    final tier4 = s.otherDivisionLeagues[3];
    s.otherDivisionLeagues[3] = null;
    s.otherDivisionLeagues[4] = tier4;
    s.currentDivisionTier = 4;
  }

  test('首位でも、資金がマイナスなら3部へ上がれず、権利は2位に移る', () async {
    final gs = GameState();
    await gs.startNewGame('赤字FC');
    playInTier4(gs);
    winEverything(gs);
    gs.save!.budget = -1000;
    expect(gs.clubLicenseUnmet(3), isNotEmpty);
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 4);
    expect(gs.lastDivisionChangeMessage, isNotNull);
    expect(gs.lastDivisionChangeMessage!.toLowerCase(),
        anyOf(contains('ライセンス'), contains('licence')));
  });

  test('首位で資金が足りていれば、3部へ上がれる', () async {
    final gs = GameState();
    await gs.startNewGame('黒字FC');
    playInTier4(gs);
    winEverything(gs);
    gs.save!.budget = 100000;
    expect(gs.clubLicenseUnmet(3), isEmpty);
    expect(
        gs.save!.infrastructure.facilityLevel(FacilityType.stadium), 1);
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 3);
  });
}
