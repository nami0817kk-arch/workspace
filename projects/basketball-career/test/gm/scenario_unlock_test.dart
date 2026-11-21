import 'dart:convert';

import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/profile.dart';
import 'package:basketball_career/gm/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み D-2: 遊ぶうちに出てくるお題。
void main() {
  test('初めの3つは出ていて、ほかは条件を満たすと出る(条件の文は初めから見せる)', () {
    final p = Profile();
    for (final s in Scenario.values) {
      expect(p.scenarioOpen(s), scenarioLock(s) == null, reason: s.label);
    }
    p.titles = 1;
    expect(p.scenarioOpen(Scenario.legacyMess), isTrue);
    p.bestWins = 56;
    expect(p.scenarioOpen(Scenario.expansion), isTrue);
    p.codex['trait:troublemaker'] = 'x';
    expect(p.scenarioOpen(Scenario.troubled), isTrue);
    p.tradeWins[1] = 6;
    p.tradeWins[2] = 4;
    expect(p.scenarioOpen(Scenario.noPicks), isTrue);
    final back = Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
    expect(back.tradeWins, p.tradeWins);
  });

  test('新しいお題の始めの形(指名権ゼロ・拡張チーム・問題児だらけ)', () {
    final a = Career.start(seed: 31);
    final t1 = scenarioTeam(a, Scenario.noPicks);
    final c1 = Career.start(seed: 31, team: t1)..startScenario(Scenario.noPicks);
    expect(c1.picks.where((p) => p.owner == c1.mine && p.season >= c1.season), isEmpty);

    final t2 = scenarioTeam(a, Scenario.expansion);
    final c2 = Career.start(seed: 31, team: t2);
    final best = ([...c2.me.roster]..sort((x, y) => y.ovr.compareTo(x.ovr))).first;
    c2.startScenario(Scenario.expansion);
    expect(c2.me.roster.contains(best), isFalse);
    expect(c2.freeAgents.contains(best), isTrue);

    final t3 = scenarioTeam(a, Scenario.troubled);
    final c3 = Career.start(seed: 31, team: t3)..startScenario(Scenario.troubled);
    expect(c3.me.chem, lessThanOrEqualTo(35));
  });

  test('どのお題でもチームが選べて、始めて1季回せる', () {
    for (final s in Scenario.values) {
      final a = Career.start(seed: 41);
      final t = scenarioTeam(a, s);
      final c = Career.start(seed: 41, team: t)..startScenario(s);
      c.startSeason();
      expect(c.phase, Phase.season, reason: s.label);
      c.playBlock();
    }
  });
}
