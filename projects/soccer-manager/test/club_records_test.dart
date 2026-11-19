import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('出場・得点・最大の勝ち試合を数え、出ていった選手も残る', () async {
    final gs = GameState();
    await gs.startNewGame('記録FC');
    final s = gs.save!;
    final f = s.league.fixtures.firstWhere((x) =>
        x.homeTeamId == gs.userTeam.id || x.awayTeamId == gs.userTeam.id);
    final home = f.homeTeamId == gs.userTeam.id;
    final a = gs.userTeam.players[0];
    final b = gs.userTeam.players[1];
    MatchResult result(int ours, int theirs) => MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: home ? ours : theirs,
          awayGoals: home ? theirs : ours,
          events: [
            for (var i = 0; i < ours; i++)
              MatchEvent(
                minute: 10 + i,
                type: MatchEventType.goal,
                teamId: gs.userTeam.id,
                scorerName: a.name,
                scorerId: a.id,
              ),
          ],
          playerRatings: {a.id: 7.0, b.id: 6.5},
        );
    gs.debugRecordClubMatch(result(2, 0), f);
    gs.debugRecordClubMatch(result(5, 1), f);
    gs.debugRecordClubMatch(result(1, 0), f);

    expect(gs.clubAppsLeaders().first.value, 3);
    final g = gs.clubGoalsLeaders();
    expect(g.first.id, a.id);
    expect(g.first.value, 8);
    expect(s.biggestWinMargin, 4);
    expect(s.biggestWin, contains('5-1'));

    // 小さな記録(10得点未満)では演出を出さない。
    expect(s.pendingMoments.where((m) => m[0] == 'clubRecord'), isEmpty);
    // 10得点を超えて歴代1位を塗り替えたら、演出が1つ出る。
    gs.debugRecordClubMatch(result(3, 0), f);
    expect(s.pendingMoments.where((m) => m[0] == 'clubRecord').length, 1);

    // 選手が出ていっても、名前と記録は残る。保存して読み戻せる。
    gs.userTeam.players.remove(a);
    expect(gs.clubGoalsLeaders().first.name, a.name);
    final back = SaveGame.fromJson(s.toJson());
    expect(back.clubGoals[a.id], 11);
    expect(back.biggestWinMargin, 4);
  });
}
