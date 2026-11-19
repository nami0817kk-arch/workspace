import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('手放したクラブの、季の終わりの部と順位を記録して知らせる', () async {
    final gs = GameState();
    await gs.startNewGame('旧FC');
    final s = gs.save!;
    final other = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
    s.formerClubs[other.id] = other.name;
    expect(gs.formerClubsAfter.single.$2, isNull);
    final news = s.newsLog.length;
    gs.debugRecordFormerClubs(s.currentDivisionTier);
    final st = s.formerClubStatus[other.id]!;
    expect(st[1], s.currentDivisionTier);
    expect(st[2], inInclusiveRange(1, s.league.teams.length));
    expect(s.newsLog.length, news + 1);
    expect(SaveGame.fromJson(s.toJson()).formerClubStatus[other.id], st);
  });
}
