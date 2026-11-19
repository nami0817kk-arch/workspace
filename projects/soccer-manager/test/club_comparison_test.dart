import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/club_comparison.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('順位はクラブの数の中に収まり、一番大きいクラブが1位', () async {
    final gs = GameState();
    await gs.startNewGame('比較FC');
    final teams = gs.save!.league.teams;
    final userId = gs.userTeam.id;
    for (final r in [
      ClubComparisonEngine.squadValue(teams, userId),
      ClubComparisonEngine.wageBill(teams, userId),
      ClubComparisonEngine.strength(teams, userId),
    ]) {
      expect(r.clubs, teams.length);
      expect(r.rank, inInclusiveRange(1, teams.length));
      expect(r.median, greaterThan(0));
    }
    // 一番強いクラブの目線では1位になる。
    final top = [...teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    expect(ClubComparisonEngine.strength(teams, top.first.id).rank, 1);
  });
}
