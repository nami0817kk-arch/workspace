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

  // 3部制(2026-11-22)。新しいゲームは最下部の3部から始まり、2部へ上がる
  // にはライセンス(スタジアム2・資金がマイナスでない)を見る。

  test('首位でも、資金がマイナスなら2部へ上がれず、権利は2位に移る', () async {
    final gs = GameState();
    await gs.startNewGame('赤字FC');
    expect(gs.currentDivisionTier, 3);
    gs.save!.infrastructure.facilityLevels[FacilityType.stadium] = 2;
    winEverything(gs);
    // 季末の賞金などで判定の前にプラスへ戻らないよう、大きく赤字にする。
    gs.save!.budget = -10000000;
    expect(gs.clubLicenseUnmet(2), isNotEmpty);
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 3);
    expect(gs.lastDivisionChangeMessage, isNotNull);
    expect(gs.lastDivisionChangeMessage!.toLowerCase(),
        anyOf(contains('ライセンス'), contains('licence')));
  });

  test('首位で資金とスタジアムが足りていれば、2部へ上がれる', () async {
    final gs = GameState();
    await gs.startNewGame('黒字FC');
    gs.save!.infrastructure.facilityLevels[FacilityType.stadium] = 2;
    winEverything(gs);
    gs.save!.budget = 1000000;
    expect(gs.clubLicenseUnmet(2), isEmpty);
    await gs.startNextSeason();
    expect(gs.currentDivisionTier, 2);
  });
}
