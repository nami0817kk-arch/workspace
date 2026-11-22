import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2つ目の国内カップ(リーグカップ)の検査。
///
/// 2026-11-22: リーグカップは実在ではイングランドだけにあるので、イングランド
/// だけに置き、1〜3部のクラブが出る形にした(それまではどの国にもあり、
/// 同じ部のクラブだけで、4節ごとに1回戦ずつ進んでいた)。回戦は決まった
/// 週にまとめて行い、決勝は2〜3月。他の国の検査は reality2_cups_test.dart。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('始めると国内カップとリーグカップの2つがあり、1〜3部のクラブで戦う', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    final s = gs.save!;
    expect(s.cups.map((c) => c.type),
        containsAll([CupType.domestic, CupType.leagueCup]));
    final lc = gs.leagueCup!;
    expect(lc.involvesTeam(s.userTeamId), isTrue);
    for (final t in s.allTeams) {
      expect(lc.involvesTeam(t.id), isTrue, reason: t.name);
    }
  });

  test('1回戦は決まった週にまとめて消化し、次の回戦の週までは進まない', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    final lc = gs.leagueCup!;
    final due = lc.roundDue!;
    // 1回戦の週の前は消化しない。
    gs.debugPlayLeagueCup();
    expect(lc.rounds.first.every((m) => m.result == null), isTrue);
    await gs.simulateAheadMatchdays(due.first);
    expect(lc.rounds.first.every((m) => m.result != null), isTrue,
        reason: '1回戦がまとめて終わる');
    expect(lc.rounds.length, 2);
    // すぐにもう一度走らせても、まだ次の回戦は消化しない。
    gs.debugPlayLeagueCup();
    expect(lc.rounds.last.any((m) => m.result == null), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('季を通すと決勝まで終わる(決勝は季の6割ほどの節)', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    final lc = gs.leagueCup!;
    final m = (gs.save!.league.teams.length - 1) * 2;
    expect(lc.roundDue!.last, lessThan(m * 0.7));
    await gs.simulateAheadMatchdays(60);
    gs.debugPlayLeagueCup();
    expect(gs.leagueCup!.isComplete, isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    await gs.simulateAheadMatchdays(gs.leagueCup!.roundDue!.first);
    final c = SaveGame.fromJson(gs.save!.toJson());
    final lc = c.cups.firstWhere((x) => x.type == CupType.leagueCup);
    expect(lc.rounds.length, gs.leagueCup!.rounds.length);
    expect(lc.plannedRounds, gs.leagueCup!.plannedRounds);
    expect(lc.entrants.keys, gs.leagueCup!.entrants.keys);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
