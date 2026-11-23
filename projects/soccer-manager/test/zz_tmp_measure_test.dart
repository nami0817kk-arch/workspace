// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/offscreen_development.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

double avg(Team t) =>
    t.players.map((p) => p.overall).reduce((a, b) => a + b) / t.players.length;

void main() {
  test('1季の伸び 自Lv1 vs CPU', () {
    for (final age in [19, 22, 25, 28]) {
      var u = 0.0, c3 = 0.0, c1 = 0.0;
      const n = 30;
      for (var i = 0; i < n; i++) {
        Team mk(String id) {
          final t = PlayerGenerator.generateSquad(
              id: id, name: id, strengthTier: 72);
          for (final p in t.players) {
            p.age = age;
            p.matchSharpness = 85;
          }
          return t;
        }

        final a = mk('u$i'), b = mk('c$i'), c = mk('d$i');
        final a0 = avg(a), b0 = avg(b), c0 = avg(c);
        for (var w = 0; w < 40; w++) {
          for (final p in a.players) {
            p.fatigue = 20;
            p.matchSharpness = 85;
            p.injuryWeeks = 0;
          }
          TrainingEngine.applyWeeklyTraining(a);
          TrainingEngine.applyPassiveCpuGrowth(b, tier: 3);
          TrainingEngine.applyPassiveCpuGrowth(c, tier: 1);
        }
        u += avg(a) - a0;
        c3 += avg(b) - b0;
        c1 += avg(c) - c0;
      }
      print('age $age user ${(u / n).toStringAsFixed(2)} cpu3 '
          '${(c3 / n).toStringAsFixed(2)} cpu1 ${(c1 / n).toStringAsFixed(2)}');
    }
  });

  test('若手1年 CPU tier3 vs offscreen', () {
    for (final age in [17, 19, 21, 23, 25, 27]) {
      var on = 0.0, off = 0.0;
      const n = 300;
      final rng = Random(1);
      for (var i = 0; i < n; i++) {
        final p = PlayerGenerator.generate(
            position: Position.values[i % Position.values.length],
            strengthTier: 72,
            ageOverride: age);
        p.matchSharpness = 85;
        final q = PlayerGenerator.generate(
            position: Position.values[i % Position.values.length],
            strengthTier: 72,
            ageOverride: age);
        final t = Team(id: 't', name: 'T', players: [p]);
        final b = p.overall;
        for (var w = 0; w < 40; w++) {
          TrainingEngine.applyPassiveCpuGrowth(t, tier: 3);
        }
        on += p.overall - b;
        off += OffscreenDevelopment.yearlyChange(q, rng);
      }
      print('age $age on ${(on / n).toStringAsFixed(2)} '
          'off ${(off / n).toStringAsFixed(2)}');
    }
  });

  test('衰え on/off', () {
    for (final age in [31, 33, 35]) {
      var on = 0.0;
      var off = 0.0;
      const n = 400;
      for (var i = 0; i < n; i++) {
        final p = PlayerGenerator.generate(
            position: Position.mc, strengthTier: 75, ageOverride: age)
          ..growthType = PlayerGrowthType.balanced;
        p.potential = p.overall;
        final t = Team(id: 't', name: 'T', players: [p]);
        final before = p.overall;
        for (var w = 0; w < 52; w++) {
          TrainingEngine.applyPassiveCpuGrowth(t);
        }
        on += p.overall - before;
        final q = PlayerGenerator.generate(
            position: Position.mc, strengthTier: 75, ageOverride: age)
          ..growthType = PlayerGrowthType.balanced;
        off += OffscreenDevelopment.yearlyChange(q, Random(i));
      }
      print('decline age $age on ${(on / n).toStringAsFixed(2)} off ${(off / n).toStringAsFixed(2)}');
    }
  });

  test('drift', () {
    for (final seasons in [8, 24]) {
      const teams = 12;
      double a = 0, b = 0;
      for (int i = 0; i < teams; i++) {
        final team = PlayerGenerator.generateSquad(
            id: 'd$i', name: 'D$i', strengthTier: 50);
        a += avg(team);
        for (int s = 0; s < seasons; s++) {
          for (int w = 0; w < 38; w++) {
            TrainingEngine.applyPassiveCpuGrowth(team);
          }
          for (final p in team.players) {
            p.age += 1;
          }
          RetirementEngine.resolveAndReplaceForCpu(team);
        }
        b += avg(team);
      }
      print('drift $seasons: ${((b - a) / teams).toStringAsFixed(2)}');
    }
  });

  test('ca4', () {
    for (var rep = 0; rep < 6; rep++) {
      Team squad(String id) {
        final t =
            PlayerGenerator.generateSquad(id: id, name: id, strengthTier: 55);
        for (final p in t.players) {
          p.age = 20;
        }
        return t;
      }
      final u = squad('u'), c = squad('c');
      final u0 = avg(u), c0 = avg(c);
      for (var season = 0; season < 5; season++) {
        for (var week = 0; week < 42; week++) {
          for (final p in u.players) {
            p.fatigue = 20;
            p.matchSharpness = 85;
          }
          TrainingEngine.applyWeeklyTraining(u);
          TrainingEngine.applyPassiveCpuGrowth(c);
        }
        for (final p in [...u.players, ...c.players]) {
          p.age += 1;
        }
      }
      final ug = avg(u) - u0, cg = avg(c) - c0;
      print('ca4 user ${ug.toStringAsFixed(2)} cpu ${cg.toStringAsFixed(2)} ratio ${(cg / ug).toStringAsFixed(2)}');
    }
  });
}
