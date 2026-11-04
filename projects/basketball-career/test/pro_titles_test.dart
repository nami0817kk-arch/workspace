// プロの大会で優勝が出ているか。リーグ戦の相手の上げ幅が勝ち抜き戦と同じ(+2.5/試合)だったため、
// おすすめどおりに遊んでも国内プロの優勝が0.5%(1,173回で0回の遊び方もあった)になっていた(2026-11-04)。
// 出来事は入れる(入団先の「強豪」で味方が強くなるのも、実際の遊び方のうち)。
import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('おすすめどおりに遊ぶと、プロでも優勝できる(国内2〜15%・海外1〜10%の大会で)', () {
    final seasons = <League, int>{}, titles = <League, int>{};
    for (var seed = 0; seed < 200; seed++) {
      final g = Game.start('x', rng: Random(seed));
      var guard = 0;
      while (g.phase != Phase.retired && guard++ < 2000) {
        switch (g.phase) {
          case Phase.season:
            g.choose(recommendedAction(g), recommendedFocus(g.player),
                focus2: recommendedFocus2(g.player, recommendedFocus(g.player)));
            if (g.canGoAbroad) g.goAbroad();
          case Phase.plan:
            g.resolvePlan(bestPlanOf(g.planInfo!));
          case Phase.halftime:
            g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
          case Phase.clutch:
            g.resolveClutch(Clutch.drive);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.path:
            final ok = g.chooseRoute(Route.pro);
            if (!ok && !g.retired) g.chooseRoute(Route.university);
          case Phase.retired:
            break;
        }
      }
      for (final r in g.records) {
        seasons[r.league] = (seasons[r.league] ?? 0) + 1;
        if (r.champion) titles[r.league] = (titles[r.league] ?? 0) + 1;
      }
    }
    double rate(League l) => (titles[l] ?? 0) / max(1, seasons[l] ?? 0);
    expect(seasons[League.proDomestic], greaterThan(200));
    expect(rate(League.proDomestic), inInclusiveRange(0.02, 0.15), reason: '国内プロの優勝率 ${rate(League.proDomestic)}');
    expect(rate(League.proAbroad), inInclusiveRange(0.01, 0.10), reason: '海外プロの優勝率 ${rate(League.proAbroad)}');
  });
}
