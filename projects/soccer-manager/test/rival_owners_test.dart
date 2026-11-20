import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/transfer_window.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 同じリーグで競う他のオーナーの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('始めると、同じリーグの3クラブにオーナーが付く(強い2クラブを含む)', () async {
    final gs = GameState();
    await gs.startNewGame('競争FC');
    final rivals = gs.rivalOwners;
    expect(rivals, hasLength(3));
    final s = gs.save!;
    final others = [
      for (final t in s.league.teams)
        if (t.id != s.userTeamId) t,
    ]..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    expect(rivals.map((r) => r.clubId),
        containsAll([others[0].id, others[1].id]));
    expect(rivals.every((r) => r.ambition >= 1 && r.ambition <= 3), isTrue);
    expect(rivals.any((r) => r.clubId == s.userTeamId), isFalse);
  });

  test('窓が開くと、他のオーナーは自由契約から自分のクラブへ選手を足す', () async {
    final gs = GameState();
    await gs.startNewGame('競争FC');
    final s = gs.save!;
    final r = gs.rivalOwners.first;
    final club = s.league.teams.firstWhere((t) => t.id == r.clubId);
    // 強い選手を自由契約に置く(必ず足したくなる)。
    final star = s.league.teams
        .expand((t) => t.players)
        .reduce((a, b) => a.overall >= b.overall ? a : b);
    final donor = s.league.teams.firstWhere((t) => t.players.contains(star));
    donor.players.remove(star);
    donor.startingXI.remove(star.id);
    s.freeAgents.add(star);
    while (club.players.length > 20) {
      club.players.removeLast();
    }
    // 窓が閉じた日から、次に開く日の翌日まで進める。
    var d = gs.today;
    while (TransferWindowCalendar.isOpen(d, gs.currentLeagueTheme)) {
      d = d.add(const Duration(days: 1));
    }
    gs.debugAdvanceTodayTo(d);
    while (!TransferWindowCalendar.isOpen(d, gs.currentLeagueTheme)) {
      d = d.add(const Duration(days: 1));
    }
    gs.debugAdvanceTodayTo(d.add(const Duration(days: 1)));
    final signed = gs.rivalOwners.fold<int>(0, (t, x) => t + x.signingsThisSeason);
    expect(signed, greaterThan(0));
    expect(s.freeAgents.contains(star), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('競うオーナーは保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('競争FC');
    final c = SaveGame.fromJson(gs.save!.toJson());
    expect(c.rivalOwners.map((r) => r.clubId),
        gs.rivalOwners.map((r) => r.clubId));
    expect(c.rivalOwners.first.name, gs.rivalOwners.first.name);
  });
}
