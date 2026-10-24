import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p({int defense = 60, int physical = 60, int a = 60, double h = 190}) => Player(
      name: 'a',
      age: 20,
      potential: 70,
      heightCm: h,
      heightGenes: 0.5,
      abilities: {
        for (final x in Ability.values) x: a,
        Ability.defense: defense,
        Ability.physical: physical,
      },
    );

MatchHalf _half(int fouls, {int team = 40, int opp = 40}) => MatchHalf(
      team: team,
      opp: opp,
      teamQuarters: const [],
      oppQuarters: const [],
      mine: 55,
      oppStrength: 55,
      form: 1,
      share: 0.15,
      rebounds: 0,
      assists: 0,
      steals: 0,
      blocks: 0,
      fouls: fouls,
    );

void main() {
  group('ファウルトラブル', () {
    double avg(Player p, double mul, {int quarters = 2}) {
      var s = 0;
      for (var i = 0; i < 1500; i++) {
        s += foulsOf(p, quarters, mul, Random(i));
      }
      return s / 1500;
    }

    test('ファウルは0〜5つ。守りが強く体が強い選手ほど増える', () {
      for (var i = 0; i < 300; i++) {
        expect(foulsOf(_p(defense: 90, physical: 90), 2, 1.5, Random(i)), inInclusiveRange(0, 5));
      }
      expect(avg(_p(defense: 85, physical: 85), 1.0), greaterThan(avg(_p(defense: 35, physical: 35), 1.0)));
    });

    test('守りを固めると後半のファウルが増える', () {
      final p = _p();
      expect(avg(p, 1.5), greaterThan(avg(p, 1.0)));
      expect(avg(p, 1.0), greaterThan(avg(p, 0.5)));
    });

    test('前半のファウル数が試合に入り、3つ以上でファウルトラブル。保存・復元でも残る', () {
      final p = _p(defense: 85, physical: 85);
      var trouble = 0;
      for (var i = 0; i < 400; i++) {
        final h = playFirstHalf(p, teamStrength: 55, oppStrength: 55, form: 1, rng: Random(i));
        expect(h.fouls, inInclusiveRange(0, 5));
        expect(h.foulTrouble, h.fouls >= 3);
        if (h.foulTrouble) trouble++;
        expect(MatchHalf.fromJson(h.toJson()).fouls, h.fouls);
      }
      expect(trouble, greaterThan(0), reason: '守りの強い選手では、ときどきファウルトラブルになる');
      expect(MatchHalf.fromJson({}).fouls, 0);
    });

    test('5つ目で退場: 退場すると味方の得点と自分の得点が減る', () {
      final p = _p(defense: 40, physical: 40);
      var outs = 0, normals = 0;
      var outPts = 0.0, normalPts = 0.0;
      for (var i = 0; i < 800; i++) {
        final s = playSecondHalf(p, _half(4), Halftime.keep, Random(i));
        expect(s.fouls, inInclusiveRange(4, 5));
        expect(s.fouledOut, s.fouls >= 5);
        if (s.fouledOut) {
          outs++;
          outPts += s.points;
        } else {
          normals++;
          normalPts += s.points;
        }
      }
      expect(outs, greaterThan(0));
      expect(normals, greaterThan(0));
      expect(outPts / outs, lessThan(normalPts / normals));
    });

    test('ファウルが少なければ退場しない(0つなら5つにならない)', () {
      for (var i = 0; i < 400; i++) {
        final s = playSecondHalf(_p(defense: 40, physical: 40), _half(0), Halftime.keep, Random(i));
        expect(s.fouledOut, isFalse);
      }
    });

    test('自動の作戦: ファウルトラブルなら、リードしていても守りを固めない', () {
      final p = _p();
      expect(bestHalftime(p, _half(0, team: 50, opp: 40)), Halftime.defense);
      expect(bestHalftime(p, _half(3, team: 50, opp: 40)), isNot(Halftime.defense));
      expect(bestHalftime(p, _half(3, team: 50, opp: 40)), isNot(Halftime.star));
    });

    test('試合の結果にファウルと退場が残り、保存・復元で変わらない', () {
      const r = MatchResult(
        won: true, teamScore: 70, oppScore: 60, points: 12, rebounds: 4, assists: 3,
        fouls: 5, fouledOut: true,
      );
      final back = MatchResult.fromJson(r.toJson());
      expect(back.fouls, 5);
      expect(back.fouledOut, isTrue);
      expect(MatchResult.fromJson({'won': true}).fouls, 0);
      final s = playSecondHalf(_p(defense: 80, physical: 80), _half(4), Halftime.defense, Random(3));
      final m = finishMatch(_p(), s, null, Random(1));
      expect(m.fouls, s.fouls);
      expect(m.fouledOut, s.fouledOut);
    });
  });

  group('タイムアウト', () {
    test('大会ごとの数: 小さい大会は1回、プロは3回', () {
      expect(League.minibasket.timeouts, 1);
      expect(League.highSchool.timeouts, 2);
      expect(League.proDomestic.timeouts, 3);
      expect(TournamentRun(League.proDomestic).timeouts, 3);
      expect(TournamentRun(League.proDomestic, timeouts: 1).timeouts, 1);
    });

    test('タイムアウトで成功率が+5%(上限内)', () {
      final p = _p(a: 50);
      for (final c in [Clutch.drive, Clutch.threePoint, Clutch.pass, Clutch.defend]) {
        final base = clutchChance(p, c, 60, 1.0);
        expect(clutchChance(p, c, 60, 1.0, timeout: true) - base, closeTo(timeoutBonus, 1e-9), reason: c.name);
      }
      expect(timeoutBonus, 0.05);
    });

    Game inClutch() {
      for (var seed = 0; seed < 600; seed++) {
        final g = Game.start('x', rng: Random(seed), events: false);
        var guard = 0;
        while (g.phase != Phase.retired && g.player.age < 15 && guard++ < 200) {
          if (g.phase == Phase.season) {
            if (g.slot == 1) {
              g.choose(Action.rest, Ability.values.first, askClutch: true);
            } else {
              g.choose(recommendedAction(g), recommendedFocus(g.player));
            }
          } else if (g.phase == Phase.halftime) {
            g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
          } else if (g.phase == Phase.clutch) {
            return g;
          } else if (g.phase == Phase.event) {
            g.resolveEvent(0);
          } else {
            break;
          }
        }
      }
      fail('勝負どころになる乱数が見つからない');
    }

    test('取ると残りが減り、その試合の成功率の表示が上がり、2回目は取れない', () {
      final g = inClutch();
      final left = g.run!.timeouts;
      expect(left, greaterThan(0));
      final before = g.clutchInfo!.chances[Clutch.threePoint]!;
      g.useTimeout();
      expect(g.run!.timeouts, left - 1);
      expect(g.run!.pending!.timeout, isTrue);
      expect(g.clutchInfo!.chances[Clutch.threePoint]!, greaterThan(before));
      expect(() => g.useTimeout(), throwsStateError);
    });

    test('残りが0なら取れない', () {
      final g = inClutch();
      g.run!.timeouts = 0;
      expect(() => g.useTimeout(), throwsStateError);
    });

    test('勝負どころ以外では取れない', () {
      final g = Game.start('x', rng: Random(1), events: false);
      expect(() => g.useTimeout(), throwsStateError);
    });

    test('取ったあとで保存・復元しても、残りと取った印が残る', () {
      final g = inClutch();
      g.useTimeout();
      final back = Game.fromJson(g.toJson());
      expect(back.phase, Phase.clutch);
      expect(back.run!.timeouts, g.run!.timeouts);
      expect(back.run!.pending!.timeout, isTrue);
      expect(TournamentRun.fromJson({'league': 'proDomestic'}).timeouts, 3, reason: '古い保存は既定の数');
    });
  });
}
