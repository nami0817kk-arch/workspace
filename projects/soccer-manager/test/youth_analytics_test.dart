import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/analytics_engine.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('U21 の試合で、控えの若手の試合勘が上がり、伸びることがある', () async {
    final gs = GameState();
    await gs.startNewGame('若手FC');
    final p = gs.userTeam.players
        .firstWhere((p) => !gs.userTeam.startingXI.contains(p.id) && !p.isLoan)
      ..age = 19
      ..matchSharpness = 30;
    p.potential = p.overall + 20;
    final before = p.overall;
    expect(gs.u21Squad, contains(p));
    final rng = Random(1);
    for (var i = 0; i < 80; i++) {
      gs.debugPlayU21Matchday(rng);
    }
    expect(p.matchSharpness, 100);
    expect(p.overall, greaterThan(before));
  });

  test('分析部門: 置くと年会費を払い、xG と隠れた逸材が出る', () async {
    final gs = GameState();
    await gs.startNewGame('分析FC');
    final s = gs.save!..budget = 99999999;
    final r = MatchResult(
      matchday: 1,
      homeTeamId: gs.userTeam.id,
      awayTeamId: 'x',
      homeGoals: 1,
      awayGoals: 0,
      events: const [],
      homeShots: 10,
      awayShots: 5,
      homeShotsOnTarget: 4,
      awayShotsOnTarget: 1,
    );
    expect(gs.xgOf(r), isNull);
    expect(gs.hiddenGems, isEmpty);
    final money = s.budget;
    expect(await gs.setAnalytics(true), isTrue);
    expect(s.budget, lessThan(money));
    final xg = gs.xgOf(r)!;
    expect(xg.$1, closeTo(AnalyticsEngine.xg(shots: 10, onTarget: 4), 1e-9));
    expect(xg.$1, greaterThan(xg.$2));
    for (final g in gs.hiddenGems) {
      expect(g.player.age, lessThanOrEqualTo(21));
      expect(g.potential - g.player.overall, greaterThanOrEqualTo(12));
    }
    expect(SaveGame.fromJson(s.toJson()).hasAnalytics, isTrue);
  });
}
