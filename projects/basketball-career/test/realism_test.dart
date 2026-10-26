import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p({int level = 60, double h = 190}) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
    age: 24,
    heightCm: h,
    abilities: {for (final a in Ability.values) a: level},
    clearPositionLock: true,
  );
}

/// そのリーグの規模で、同じ強さの相手と n 試合して、(自チームの平均得点, 勝率, 結果の一覧)を返す。
(double, double, List<MatchResult>) _play(League lg, int n, {double diff = 0}) {
  final p = _p();
  var sum = 0, wins = 0;
  final out = <MatchResult>[];
  for (var i = 0; i < n; i++) {
    final rng = Random(i);
    final h = playFirstHalf(p,
        teamStrength: 55 + diff,
        oppStrength: 55,
        form: 1.0,
        rng: rng,
        scale: lg.scoreScale,
        gameMinutes: lg.quarterMinutes * 4);
    final s = playSecondHalf(p, h, Halftime.keep, rng);
    final r = finishMatch(p, s, null, rng);
    sum += r.teamScore;
    if (r.won) wins++;
    out.add(r);
  }
  return (sum / n, wins / n, out);
}

void main() {
  group('点数の規模(段階ごとに実際のバスケに近い)', () {
    test('1試合の平均得点: ミニバス約40台・中学約60・高校約70・国内プロ約80台・海外の最高峰約110', () {
      final expected = {
        League.minibasket: (35.0, 52.0),
        League.juniorHigh: (52.0, 70.0),
        League.highSchool: (64.0, 82.0),
        League.university: (68.0, 86.0),
        League.proDomestic: (76.0, 98.0),
        League.national: (74.0, 96.0),
        League.proAbroad: (98.0, 128.0),
      };
      for (final e in expected.entries) {
        final (avg, _, _) = _play(e.key, 300);
        expect(avg, inInclusiveRange(e.value.$1, e.value.$2), reason: '${e.key.label}: $avg点');
      }
    });

    test('規模が違っても、強さが同じなら勝率は同じくらい(勝ちやすさは変わらない)', () {
      final rates = [
        for (final lg in League.values) _play(lg, 600, diff: 6).$2,
      ];
      final spread = rates.reduce(max) - rates.reduce(min);
      expect(spread, lessThan(0.10), reason: '勝率のばらつき $rates');
    });

    test('勝負どころに入る点差は、規模に合わせて広がる(ミニバス2・高校3・海外の最高峰5)', () {
      expect(clutchWindowOf(League.minibasket.scoreScale), 2);
      expect(clutchWindowOf(League.highSchool.scoreScale), 3);
      expect(clutchWindowOf(League.proAbroad.scoreScale), 5);
    });

    test('勝負どころに入る割合は、規模が違ってもあまり変わらない', () {
      double rate(League lg) {
        final (_, _, rs) = _play(lg, 800);
        return rs.where((r) => r.clutch != null).length / rs.length;
      }

      final rates = [for (final lg in League.values) rate(lg)];
      expect(rates.reduce(max) - rates.reduce(min), lessThan(0.18), reason: '$rates');
    });

    test('試合時間: ミニバス24分・中学32分・高校〜国内プロ40分・海外の最高峰48分', () {
      expect(League.minibasket.quarterMinutes * 4, 24);
      expect(League.juniorHigh.quarterMinutes * 4, 32);
      expect(League.highSchool.quarterMinutes * 4, 40);
      expect(League.proDomestic.quarterMinutes * 4, 40);
      expect(League.proAbroad.quarterMinutes * 4, 48);
    });
  });

  group('ボックススコア', () {
    test('得点と3Pの本数に合っている(2点×2＋3点×3＋フリースロー＝得点)。試投は成功以上', () {
      for (final lg in [League.highSchool, League.proDomestic, League.proAbroad]) {
        final (_, _, rs) = _play(lg, 300);
        for (final r in rs) {
          final b = r.box;
          expect(b.isEmpty, isFalse);
          final twos = b.fgMade - r.threes;
          expect(twos, greaterThanOrEqualTo(0), reason: '${lg.label}: $r');
          expect(2 * twos + 3 * r.threes + b.ftMade, r.points,
              reason: '${lg.label}: ${r.points}点 FG${b.fgMade} 3P${r.threes} FT${b.ftMade}');
          expect(b.fgAttempts, greaterThanOrEqualTo(b.fgMade));
          expect(b.threeAttempts, greaterThanOrEqualTo(r.threes));
          expect(b.threeAttempts, lessThanOrEqualTo(b.fgAttempts));
          expect(b.ftAttempts, greaterThanOrEqualTo(b.ftMade));
          expect(b.turnovers, inInclusiveRange(0, 9));
          expect(b.minutes, inInclusiveRange(1, lg.quarterMinutes * 4));
        }
      }
    });

    test('成功率が現実的(2点は38〜62%・全体のFGは約35〜60%の範囲に収まる)', () {
      final (_, _, rs) = _play(League.proDomestic, 400);
      var made = 0, att = 0;
      for (final r in rs) {
        made += r.box.fgMade;
        att += r.box.fgAttempts;
      }
      expect(made / att, inInclusiveRange(0.35, 0.60));
    });

    test('保存で残る。古い保存(ボックススコアなし)は空で読める', () {
      final (_, _, rs) = _play(League.proAbroad, 5);
      final r = MatchResult.fromJson(rs.first.toJson());
      expect(r.box.fgMade, rs.first.box.fgMade);
      expect(r.box.minutes, rs.first.box.minutes);
      final j = rs.first.toJson()..remove('box');
      expect(MatchResult.fromJson(j).box.isEmpty, isTrue);
    });

    test('途中の試合(MatchHalf・MatchState)の規模と試合時間も保存で残る', () {
      final p = _p();
      final h = playFirstHalf(p,
          teamStrength: 55,
          oppStrength: 55,
          form: 1.0,
          rng: Random(3),
          scale: 1.55,
          gameMinutes: 48);
      final hb = MatchHalf.fromJson(h.toJson());
      expect(hb.scale, 1.55);
      expect(hb.gameMinutes, 48);
      final s = playSecondHalf(p, h, Halftime.keep, Random(3));
      final sb = MatchState.fromJson(s.toJson());
      expect(sb.scale, 1.55);
      expect(sb.gameMinutes, 48);
      // 古い保存は高校の規模(1.0・40分)として読む。
      final old = (s.toJson()..remove('scale')..remove('gameMinutes'));
      expect(MatchState.fromJson(old).scale, 1.0);
      expect(MatchState.fromJson(old).gameMinutes, 40);
    });
  });

  group('シュート成功率(大会・年・通算)', () {
    test('成功率の表示: 試投が無ければ「-」、あれば小数1桁の%', () {
      expect(pctLabel(0, 0), '-');
      expect(pctLabel(9, 20), '45.0%');
      expect(pctLabel(1, 3, digits: 0), '33%');
      const b = BoxScore(fgMade: 10, fgAttempts: 20, threeAttempts: 8, ftMade: 4, ftAttempts: 5);
      expect(shootingLine(b, 3), 'FG 50.0%・3P 37.5%・FT 80.0%');
    });

    test('ボックススコアは足し合わせられ、年の記録・通算に入り、保存で残る', () {
      final g = Game.start('x', rng: Random(4), events: false);
      var guard = 0;
      while (g.records.isEmpty && guard++ < 20) {
        g.choose(Action.practice, Ability.threePoint);
      }
      expect(g.records, isNotEmpty);
      final r = g.records.first;
      expect(r.box.isEmpty, isFalse);
      expect(g.careerBox.fgAttempts, greaterThanOrEqualTo(r.box.fgAttempts));
      final back = Game.fromJson(g.toJson());
      expect(back.records.first.box.fgMade, r.box.fgMade);
      expect(back.careerBox.ftAttempts, g.careerBox.ftAttempts);
      // 古い記録(ボックススコアなし)は空で読める。
      final j = r.toJson()..remove('box');
      expect(YearRecord.fromJson(j).box.isEmpty, isTrue);
    });
  });

  group('控え(ベンチスタート)', () {
    test('プロで総合が控えの線より低いと控え。出場時間と個人の数字が小さい。学生の大会では全員先発', () {
      final weak = _p(level: 30), strong = _p(level: 80);
      expect(weak.overall, lessThan(League.proDomestic.benchLine!));
      expect(strong.overall, greaterThanOrEqualTo(League.proDomestic.benchLine!));
      var benchMin = 0, starMin = 0, benchShare = 0.0, starShare = 0.0;
      for (var i = 0; i < 200; i++) {
        MatchResult play(Player p) {
          final rng = Random(i);
          final h = playFirstHalf(p,
              teamStrength: 62, oppStrength: 62, form: 1, rng: rng,
              scale: 1.17, gameMinutes: 40, benchBelow: League.proDomestic.benchLine);
          return finishMatch(p, playSecondHalf(p, h, Halftime.keep, rng), null, rng);
        }
        final b = play(weak), s = play(strong);
        expect(b.starter, isFalse);
        expect(s.starter, isTrue);
        benchMin += b.box.minutes;
        starMin += s.box.minutes;
        benchShare += b.points / b.teamScore;
        starShare += s.points / s.teamScore;
      }
      expect(benchMin / 200, lessThan(starMin / 200 * 0.75));
      expect(benchShare, lessThan(starShare));
      expect(League.highSchool.benchLine, isNull);
      expect(League.university.benchLine, isNull);
    });

    test('先発かどうかは保存で残り、古いセーブは先発', () {
      final h = playFirstHalf(_p(level: 30),
          teamStrength: 62, oppStrength: 62, form: 1, rng: Random(1), benchBelow: 56);
      expect(MatchHalf.fromJson(h.toJson()).starter, isFalse);
      final s = playSecondHalf(_p(level: 30), h, Halftime.keep, Random(1));
      expect(MatchState.fromJson(s.toJson()).starter, isFalse);
      final r = finishMatch(_p(level: 30), s, null, Random(1));
      expect(MatchResult.fromJson(r.toJson()).starter, isFalse);
      expect(MatchResult.fromJson(r.toJson()..remove('starter')).starter, isTrue);
    });
  });
}
