import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('オフに入ると、リーグ全体の伸び・落ちの大きい選手が残り、保存しても残る。来季の強さ予想は強さの順', () {
    final c = careerAt(7, 14)..startSeason();
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 60) {
      botStep(c);
    }
    c.fired = false;
    c.toOffseason();
    expect(c.leagueGrowth, isNotEmpty);
    expect(c.leagueGrowth.length, lessThanOrEqualTo(48));
    final up = c.leagueRisers(), down = c.leagueFallers();
    expect(up, isNotEmpty);
    expect(up.every((g) => g.after > g.before && g.team >= 0), isTrue);
    expect(down.every((g) => g.after < g.before), isTrue);
    for (var i = 1; i < up.length; i++) {
      expect(up[i - 1].after - up[i - 1].before, greaterThanOrEqualTo(up[i].after - up[i].before));
    }
    // ほかのチームの選手も入る
    expect(c.leagueGrowth.any((g) => g.team != c.mine), isTrue);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.leagueGrowth.length, c.leagueGrowth.length);
    expect(back.leagueGrowth.first.team, c.leagueGrowth.first.team);
    final pr = c.powerRanking();
    expect(pr, hasLength(c.teams.length));
    for (var i = 1; i < pr.length; i++) {
      expect(c.teams[pr[i - 1]].strength, greaterThanOrEqualTo(c.teams[pr[i]].strength));
    }
  });
}
