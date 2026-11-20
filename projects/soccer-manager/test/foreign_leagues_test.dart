import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('他国の1部にも日程があり、節が進み、季の終わりに締めて次の日程を作る',
      () async {
    final gs = GameState();
    await gs.startNewGame('世界FC');
    final s = gs.save!;
    expect(gs.foreignLeagueTables.length, s.foreignLeagues.length);
    for (final l in s.foreignLeagues.values) {
      expect(l.fixtures, isNotEmpty);
    }
    gs.debugPlayForeignMatchday(1);
    for (final l in s.foreignLeagues.values) {
      expect(l.fixturesForMatchday(1).every((f) => f.result != null), isTrue);
      expect(l.sortedStandings.any((r) => r.played > 0), isTrue);
    }
    final season = s.foreignLeagues.values.first.season;
    final news = s.newsLog.length;
    gs.debugFinishForeignSeasons();
    expect(s.newsLog.length, news + s.foreignLeagues.length,
        reason: 'リーグごとに優勝のニュース');
    for (final l in s.foreignLeagues.values) {
      expect(l.season, season + 1);
      expect(l.fixtures.every((f) => f.result == null), isTrue);
    }

    // 保存して読み戻しても日程は残る。
    final back = SaveGame.fromJson(s.toJson());
    for (final l in back.foreignLeagues.values) {
      expect(l.fixtures, isNotEmpty);
    }
  });
}
