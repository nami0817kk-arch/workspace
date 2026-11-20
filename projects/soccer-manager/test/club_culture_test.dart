import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/club_culture.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// クラブの文化の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MatchResult r(int gf, int ga) => MatchResult(
      matchday: 1,
      homeTeamId: 'u',
      awayTeamId: 'o',
      homeGoals: gf,
      awayGoals: ga,
      events: const []);

  test('文化に沿った試合だけ+1', () {
    int b(ClubCulture c, MatchResult m) => ClubCultureEngine.matchBonus(
        culture: c, r: m, userId: 'u', starters: const []);
    expect(b(ClubCulture.attacking, r(2, 1)), 1);
    expect(b(ClubCulture.attacking, r(1, 0)), 0);
    expect(b(ClubCulture.defensive, r(1, 0)), 1);
    expect(b(ClubCulture.defensive, r(3, 1)), 0);
    expect(b(ClubCulture.none, r(5, 0)), 0);
  });

  test('1季に1回だけ変えられ、決めたものから変えると期待が下がる', () async {
    final gs = GameState();
    await gs.startNewGame('文化FC');
    final s = gs.save!..confidence = 50;
    expect(await gs.setClubCulture(ClubCulture.attacking), isTrue);
    expect(s.confidence, 50, reason: '最初に決めるのは罰なし');
    expect(await gs.setClubCulture(ClubCulture.youth), isFalse,
        reason: '同じ季にもう一度は変えられない');
    s.clubCultureChangedSeason = 0;
    expect(await gs.setClubCulture(ClubCulture.youth), isTrue);
    expect(s.confidence, 50 - ClubCultureEngine.changePenalty);
    expect(SaveGame.fromJson(s.toJson()).clubCulture, 'youth');
  });
}
