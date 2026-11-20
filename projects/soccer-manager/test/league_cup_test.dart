import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2つ目の国内カップ(リーグカップ)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('始めると国内カップとリーグカップの2つがあり、同じ部のクラブで戦う', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    final s = gs.save!;
    expect(s.cups.map((c) => c.type),
        containsAll([CupType.domestic, CupType.leagueCup]));
    final lc = gs.leagueCup!;
    expect(lc.involvesTeam(s.userTeamId), isTrue);
    for (final t in s.league.teams) {
      expect(lc.involvesTeam(t.id), isTrue, reason: t.name);
    }
  });

  test('1回戦ずつまとめて消化し、4節たたないと次の回戦に進まない', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    final lc = gs.leagueCup!;
    final round = lc.nextUnplayedMatch!.round;
    gs.debugPlayLeagueCup();
    expect(lc.rounds.first.every((m) => m.result != null), isTrue,
        reason: '1回戦がまとめて終わる');
    final nextRound = lc.nextUnplayedMatch?.round;
    expect(nextRound, greaterThan(round));
    // すぐにもう一度走らせても、まだ次の回戦は消化しない。
    gs.debugPlayLeagueCup();
    expect(lc.rounds.last.any((m) => m.result == null), isTrue);
  });

  test('季を通すと決勝まで終わる', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    await gs.simulateAheadMatchdays(60);
    gs.debugPlayLeagueCup();
    gs.debugPlayLeagueCup();
    gs.debugPlayLeagueCup();
    expect(gs.leagueCup!.isComplete, isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('杯FC');
    gs.debugPlayLeagueCup();
    final c = SaveGame.fromJson(gs.save!.toJson());
    final lc = c.cups.firstWhere((x) => x.type == CupType.leagueCup);
    expect(lc.rounds.length, gs.leagueCup!.rounds.length);
  });
}
