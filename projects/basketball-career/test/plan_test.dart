import 'dart:convert';
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Game _strong({required int seed, Track track = Track.school, int age = 15, int ability = 92}) => Game(
      eventsEnabled: false,
      player: Player(name: 'x', age: age, potential: 90, heightCm: 192, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: ability}),
      rng: Random(seed),
      track: track,
      slot: 1,
    );

/// 大会を、作戦以外は決まった選択で最後まで進める。止まった作戦の場面の数を返す。
int _playThrough(Game g, BigGamePlan plan) {
  var plans = 0, guard = 0;
  while (g.phase != Phase.season && g.phase != Phase.retired && guard++ < 200) {
    switch (g.phase) {
      case Phase.plan:
        plans++;
        g.resolvePlan(plan);
      case Phase.halftime:
        g.resolveHalftime(Halftime.keep);
      case Phase.clutch:
        g.resolveClutch(Clutch.drive);
      default:
        return plans;
    }
  }
  return plans;
}

void main() {
  test('効き目: 守りが強いと「止める」、総合が高いと「攻める」、チームワークとパスで「回す」', () {
    final g = _strong(seed: 1, ability: 60);
    g.player = g.player.copyWith(abilities: {...g.player.abilities, Ability.defense: 95});
    g.teamwork = 30;
    expect(bestPlanOf(g.planEffects), BigGamePlan.stopAce);
    final h = _strong(seed: 1, ability: 95)..teamwork = 30;
    expect(bestPlanOf(h.planEffects), BigGamePlan.attack);
    final t = _strong(seed: 1, ability: 55)..teamwork = 100;
    t.player = t.player.copyWith(abilities: {...t.player.abilities, Ability.pass: 99});
    expect(bestPlanOf(t.planEffects), BigGamePlan.team);
    // 総合が低いと「攻める」は逆効果。
    expect(planValue(_strong(seed: 1, ability: 40).planEffects[BigGamePlan.attack]!), lessThan(0));
  });

  test('勝ち抜き戦は決勝の前に1度だけ止まる(自分で選ぶ大会のとき)。選んだ作戦が残る', () {
    for (var seed = 0; seed < 50; seed++) {
      final g = _strong(seed: seed);
      g.choose(Action.rest, Ability.pass, askClutch: true, askHalftime: true);
      final plans = _playThrough(g, BigGamePlan.team);
      final reachedFinal = g.records.isNotEmpty && g.records.last.games == g.records.last.league.rounds;
      if (reachedFinal) {
        expect(plans, 1, reason: 'seed $seed');
        return;
      }
    }
    fail('決勝まで勝ち進む乱数が見つからない');
  });

  test('プロはプレーオフ決勝のシリーズの前に1度だけ止まる', () {
    for (var seed = 0; seed < 80; seed++) {
      final g = _strong(seed: seed, track: Track.pro, age: 27);
      g.choose(Action.rest, Ability.pass, askClutch: true, askHalftime: true);
      final plans = _playThrough(g, BigGamePlan.attack);
      final finalGames = g.records.last.games - League.proDomestic.rounds;
      if (plans > 0) {
        expect(plans, 1);
        expect(finalGames, greaterThanOrEqualTo(League.proDomestic.playoffSeries.first ~/ 2 + 1 + 3),
            reason: '準決勝を勝ち抜いて決勝の第1戦以降まで戦っている');
        return;
      }
    }
    fail('プレーオフ決勝まで進む乱数が見つからない');
  });

  test('自分で選ばない大会では止まらず、いちばん効く作戦で戦う', () {
    for (var seed = 0; seed < 30; seed++) {
      final g = _strong(seed: seed);
      g.choose(Action.rest, Ability.pass);
      expect(g.phase, isNot(Phase.plan));
    }
  });

  test('作戦の場面で保存して読み戻しても、同じ結果になる', () {
    for (var seed = 0; seed < 50; seed++) {
      final a = _strong(seed: seed);
      a.choose(Action.rest, Ability.pass, askClutch: true, askHalftime: true);
      var guard = 0;
      while (a.phase != Phase.plan && a.phase != Phase.season && guard++ < 50) {
        if (a.phase == Phase.halftime) a.resolveHalftime(Halftime.keep);
        if (a.phase == Phase.clutch) a.resolveClutch(Clutch.drive);
      }
      if (a.phase != Phase.plan) continue;
      final rngState = Random(seed * 31);
      final b = Game.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>, rng: rngState);
      final a2 = Game.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>, rng: Random(seed * 31));
      expect(b.phase, Phase.plan);
      expect(b.planInfo!.keys, BigGamePlan.values);
      _playThrough(b, BigGamePlan.stopAce);
      _playThrough(a2, BigGamePlan.stopAce);
      expect(jsonEncode(b.toJson()), jsonEncode(a2.toJson()));
      expect(b.run, isNull);
      return;
    }
    fail('作戦の場面で止まる乱数が見つからない');
  });

  test('壊れた作戦の保存でも落ちない', () {
    final r = TournamentRun.fromJson({
      'league': 'highSchool',
      'planEffects': {'stopAce': [1, 2], 'attack': 'x', 'nope': [1, 1], 'team': [1]},
      'plan': 'こわれた',
    });
    expect(r.planEffects.keys, [BigGamePlan.stopAce]);
    expect(r.plan, isNull);
  });
}
