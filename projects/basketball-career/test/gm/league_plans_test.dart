import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/league_plans.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み C-1: AI の GM の数年の計画。
void main() {
  test('どのチームも計画を持ち、計画から考え方が決まる(どのチームを選んでも同じリーグ。自分の計画はうわさにしない)', () {
    final c = careerAt(3, 12)..startSeason();
    expect(c.teamPlans.containsKey(c.mine), isTrue);
    expect(c.inbox.where((m) => m.title == 'うわさ: ${c.me.def.short}の計画'), isEmpty);
    for (final t in c.teams) {
      final p = c.teamPlans[t.index];
      expect(p, isNotNull);
      switch (p!.$1) {
        case TeamPlan.allIn:
          expect(t.mode, TeamMode.contend);
        case TeamPlan.slim:
          expect(t.mode, anyOf(TeamMode.cutCost, TeamMode.balanced));
        case TeamPlan.rebuild3:
          expect(t.mode, anyOf(TeamMode.rebuild, TeamMode.contend));
        case TeamPlan.core:
          expect(t.mode, anyOf(TeamMode.contend, TeamMode.balanced));
      }
    }
    // 計画は何種類かに散らばる
    expect({for (final p in c.teamPlans.values) p.$1}.length, greaterThanOrEqualTo(3));
    final y = Career.fromJson(c.toJson());
    expect(y.teamPlans.length, c.teamPlans.length);
  });

  test('季をまたぐと計画が進み、うわさが届く。数年で計画が入れ替わるチームがある', () {
    final c = careerAt(4, 12)..startSeason();
    expect(c.inbox.where((m) => m.title.contains('の計画')), isNotEmpty);
    final first = {for (final e in c.teamPlans.entries) e.key: e.value};
    var guard = 0;
    while (c.season < 4 && guard++ < 4000) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    final changed = c.teamPlans.entries.where((e) => first[e.key] != e.value).length;
    expect(changed, greaterThan(0));
  });
}
