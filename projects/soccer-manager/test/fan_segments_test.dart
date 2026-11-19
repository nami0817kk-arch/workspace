import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/fan_segments.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('層の満足で観客の入りが上下5%まで変わる', () {
    expect(FanSegmentEngine.attendanceModifier(55), 1.0);
    expect(FanSegmentEngine.attendanceModifier(100), 1.05);
    expect(FanSegmentEngine.attendanceModifier(0), 0.95);
    expect(
        FanSegmentEngine.localMood(homegrownStarters: 5, ticketAttendance: 1),
        greaterThan(FanSegmentEngine.localMood(
            homegrownStarters: 0, ticketAttendance: 1)));
  });

  test('自治体: 地元の満足が足りれば補助が下り、次のスタジアムの増築が安くなる',
      () async {
    final gs = GameState();
    await gs.startNewGame('自治体FC');
    final s = gs.save!..budget = 99999999;
    final full = gs.facilityUpgradeCostFor(FacilityType.stadium);
    // 地元・家族の満足を上げる: 先発を全員生え抜きにする。
    for (final p in gs.userTeam.players) {
      p.homegrown = true;
    }
    expect(gs.fanMoods[FanSegment.local]!, greaterThanOrEqualTo(55));
    expect(gs.canAskMunicipality, isTrue);
    expect(await gs.askMunicipality(), isTrue);
    expect(gs.canAskMunicipality, isFalse);
    expect(gs.facilityUpgradeCostFor(FacilityType.stadium),
        (full * 0.6).round());
    expect(await gs.upgradeFacility(FacilityType.stadium), isTrue);
    expect(s.stadiumSubsidyPct, 0, reason: '補助は1回で使い切る');
    expect(SaveGame.fromJson(s.toJson()).municipalityAskSeason,
        s.league.season);
  });
}
