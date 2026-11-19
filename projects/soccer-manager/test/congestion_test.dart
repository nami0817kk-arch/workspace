import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('1週に2試合戦うと、先発に疲れが残る', () async {
    final gs = GameState();
    await gs.startNewGame('過密FC');
    final s = gs.save!;
    gs.debugApplyCongestion();
    expect(s.lastWeekCongested, isFalse);
    // 自クラブのリーグ戦を2試合、結果だけ入れる。
    final mine = s.league.fixtures
        .where((f) =>
            f.homeTeamId == s.userTeamId || f.awayTeamId == s.userTeamId)
        .take(2)
        .toList();
    for (final f in mine) {
      f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 1,
          awayGoals: 1,
          events: const []);
    }
    final starter = gs.userTeam.players
        .firstWhere((p) => gs.userTeam.startingXI.contains(p.id))
      ..fatigue = 10;
    gs.debugApplyCongestion();
    expect(s.lastWeekCongested, isTrue);
    expect(starter.fatigue, 10 + GameStateCongestion.congestionFatigue);
    // 次の週に試合が無ければ、過密ではない。
    gs.debugApplyCongestion();
    expect(s.lastWeekCongested, isFalse);
  });
}
