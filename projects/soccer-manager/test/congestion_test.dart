import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 過密日程は試合の日付の間隔で判定する(2026-11-22)。以前は「前の週に
/// 戦った試合の数」を節ごとに数えていたため、節と節のあいだが3日でも
/// 1週扱いになり、イングランドの年末の連戦が過密と判定されなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('前の試合から3日以内の試合は過密。間が空けば過密ではない', () async {
    final gs = GameState();
    await gs.startNewGame('過密FC');
    final s = gs.save!;
    final y = SeasonCalendar.startYear(s.league.season);
    gs.debugAdvanceTodayTo(DateTime(y, 10, 3));
    gs.debugNoteUserMatchDay();
    expect(s.lastWeekCongested, isFalse, reason: '前の試合が無い');

    final starter = gs.userTeam.players
        .firstWhere((p) => gs.userTeam.startingXI.contains(p.id));
    // 3日後の試合: 過密。先発に疲れが足される。
    gs.debugAdvanceTodayTo(DateTime(y, 10, 6));
    starter.fatigue = 10;
    gs.debugNoteUserMatchDay();
    expect(s.lastWeekCongested, isTrue);
    expect(starter.fatigue, 10 + GameStateCongestion.congestionFatigue);

    // 同じ日に二度呼んでも二重には足さない。
    gs.debugNoteUserMatchDay();
    expect(starter.fatigue, 10 + GameStateCongestion.congestionFatigue);

    // 4日空けば過密ではない。
    gs.debugAdvanceTodayTo(DateTime(y, 10, 10));
    starter.fatigue = 10;
    gs.debugNoteUserMatchDay();
    expect(s.lastWeekCongested, isFalse);
    expect(starter.fatigue, 10);
  });
}
