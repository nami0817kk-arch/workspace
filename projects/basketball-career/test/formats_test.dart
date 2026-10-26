import 'dart:convert';
import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(int level) {
  final base = Game.start('x', rng: Random(1), events: false).player;
  return base.copyWith(
    age: 25,
    heightCm: 192,
    abilities: {for (final a in Ability.values) a: level},
    clearPositionLock: true,
  );
}

void main() {
  group('延長戦', () {
    MatchState tied() => const MatchState(
          team: 60,
          opp: 60,
          points: 15,
          rebounds: 5,
          assists: 4,
          teamStrength: 60,
          oppStrength: 60,
          form: 1,
          teamQuarters: [15, 15, 15, 15],
          oppQuarters: [15, 15, 15, 15],
        );

    test('同点なら延長戦になり、必ず勝敗がつく(同点では終わらない)', () {
      var ots = 0, multi = 0;
      for (var seed = 0; seed < 400; seed++) {
        final r = finishMatch(_p(70), tied(), Clutch.defend, Random(seed));
        expect(r.teamScore, isNot(r.oppScore), reason: 'seed $seed');
        expect(r.won, r.teamScore > r.oppScore);
        expect(r.overtimes, lessThanOrEqualTo(3));
        if (r.overtimes > 0) ots++;
        if (r.overtimes > 1) multi++;
        if (r.overtimes > 0) {
          expect(r.teamScore, greaterThan(60), reason: '延長で点が入る');
          expect(r.points, greaterThanOrEqualTo(15), reason: '延長の得点が個人にも入る');
        }
      }
      expect(ots, greaterThan(100), reason: '同点の試合の多くは延長になる');
      expect(multi, greaterThan(0), reason: '延長が続くこともある');
    });

    test('延長が無ければ0。延長の回数は保存で残る', () {
      final s = tied();
      final plain = const MatchState(
        team: 70, opp: 60, points: 15, rebounds: 5, assists: 4,
        teamStrength: 60, oppStrength: 60, form: 1,
        teamQuarters: [18, 18, 17, 17], oppQuarters: [15, 15, 15, 15],
      );
      expect(finishMatch(_p(70), plain, null, Random(1)).overtimes, 0);
      final r = finishMatch(_p(70), s, Clutch.defend, Random(2));
      final back = MatchResult.fromJson(r.toJson());
      expect(back.overtimes, r.overtimes);
      expect(back.teamScore, r.teamScore);
    });

    test('延長のぶんも出場時間に入り、ボックススコアは得点と合う', () {
      for (var seed = 0; seed < 200; seed++) {
        final r = finishMatch(_p(70), tied(), Clutch.defend, Random(seed));
        final b = r.box;
        final twos = b.fgMade - r.threes;
        expect(2 * twos + 3 * r.threes + b.ftMade, r.points, reason: 'seed $seed');
        expect(b.minutes, lessThanOrEqualTo(40 + 5 * r.overtimes + 15));
      }
    });
  });

  group('大会の形式', () {
    test('大学・実業団はリーグ戦6試合のあと決勝トーナメント。負けても6試合は戦う', () {
      for (final lg in [League.university, League.corporate]) {
        expect(lg.rounds, 6);
        expect(lg.elimination, isFalse);
        for (var seed = 0; seed < 80; seed++) {
          final t = playTournament(_p(40), lg, form: 1, rng: Random(seed));
          expect(t.games, greaterThanOrEqualTo(6), reason: '${lg.label} seed $seed');
          if (!t.reachedPlayoffs) {
            expect(t.games, 6);
            expect(t.regularWins, lessThan(lg.qualifyWins));
          } else {
            expect(t.regularWins, greaterThanOrEqualTo(lg.qualifyWins));
          }
        }
      }
    });

    test('日本代表は予選グループ3試合(2勝で進出)のあと、決勝トーナメントの3ラウンド', () {
      var champ = 0;
      for (var seed = 0; seed < 300; seed++) {
        final t = playTournament(_p(99), League.national, form: 1, rng: Random(seed));
        expect(t.games, greaterThanOrEqualTo(2));
        if (t.reachedPlayoffs) {
          expect(t.regularWins, greaterThanOrEqualTo(2));
          expect(t.playoffMatches.length, lessThanOrEqualTo(3));
        }
        if (t.champion) {
          champ++;
          expect(t.playoffMatches.length, 3);
          expect(t.playoffMatches.every((m) => m.won), isTrue);
        }
      }
      expect(champ, greaterThan(0), reason: '強い選手は世界一になりうる');
    });

    test('学生の勝ち抜き(ミニバス・中学・高校)は、負けたら終わりのまま', () {
      for (final lg in [League.minibasket, League.juniorHigh, League.highSchool]) {
        expect(lg.elimination, isTrue);
        expect(lg.playoffRounds, 0);
        for (var seed = 0; seed < 50; seed++) {
          final t = playTournament(_p(50), lg, form: 1, rng: Random(seed));
          final losses = t.matches.where((m) => !m.won).length;
          expect(losses, lessThanOrEqualTo(1));
          if (losses == 1) expect(t.matches.last.won, isFalse);
        }
      }
    });
  });

  group('プレーオフのシリーズ', () {
    test('シリーズは先に過半数を取った方が勝ち抜け。試合の呼び名に何戦目かが付く', () {
      var sawSeries = 0;
      for (var seed = 0; seed < 150; seed++) {
        final t = playTournament(_p(85), League.proDomestic, form: 1, rng: Random(seed));
        if (!t.reachedPlayoffs) continue;
        sawSeries++;
        final po = t.playoffMatches;
        // シリーズごとに分ける: 勝ち数が必要数に達するか、負け数が達したところで区切る。
        var i = 0;
        for (var r = 0; r < League.proDomestic.playoffRounds; r++) {
          if (i >= po.length) break;
          final need = League.proDomestic.seriesNeed(r);
          var w = 0, l = 0, n = 0;
          while (i < po.length && w < need && l < need) {
            po[i].won ? w++ : l++;
            n++;
            expect(po[i].tag, contains('第$n戦'), reason: 'seed $seed ${po[i].tag}');
            i++;
          }
          expect(w == need || l == need, isTrue);
          if (l == need) {
            expect(i, po.length, reason: '負けたシリーズで大会は終わる');
          }
        }
      }
      expect(sawSeries, greaterThan(50));
    });

    test('途中で保存して読み戻しても、シリーズの勝敗と相手が残る', () {
      Game? g;
      for (var seed = 0; seed < 400 && g == null; seed++) {
        final base = Game.start('x', rng: Random(seed), events: false);
        final cand = Game(
          eventsEnabled: false,
          player: base.player.copyWith(
            age: 26,
            heightCm: 194,
            abilities: {for (final a in Ability.values) a: 85},
            clearPositionLock: true,
          ),
          rng: Random(seed),
          track: Track.pro,
          salary: 3000,
          slot: 1,
        );
        cand.choose(Action.rest, Ability.defense, askClutch: true, askHalftime: true);
        var guard = 0;
        while ((cand.phase == Phase.halftime || cand.phase == Phase.clutch) && guard++ < 40) {
          final r = cand.run!;
          if (r.inPlayoffs && (r.seriesWins + r.seriesLosses) > 0) {
            g = cand;
            break;
          }
          if (cand.phase == Phase.halftime) {
            cand.resolveHalftime(Halftime.keep);
          } else {
            cand.resolveClutch(Clutch.drive);
          }
        }
      }
      expect(g, isNotNull, reason: 'シリーズの途中で止まる試合が見つかる');
      final back = Game.fromJson(jsonDecode(jsonEncode(g!.toJson())) as Map<String, dynamic>);
      final a = g.run!, b = back.run!;
      expect(b.seriesWins, a.seriesWins);
      expect(b.seriesLosses, a.seriesLosses);
      expect(b.seriesWon, a.seriesWon);
      expect(b.seriesOpp, a.seriesOpp);
      expect(b.currentLabel, a.currentLabel);
    });

    test('選んで止まるのは、リーチがかかった試合と最終戦だけ(途中の試合は自動で進む)', () {
      var stops = 0;
      for (var seed = 0; seed < 120; seed++) {
        final p = _p(85);
        final run = TournamentRun(League.proAbroad);
        var guard = 0;
        while (!run.finished && guard++ < 60) {
          run.advance(p, form: 1, rng: Random(seed * 31 + guard), askClutch: true);
          if (run.pending != null || run.pendingHalf != null) {
            stops++;
            if (run.inPlayoffs) {
              final need = League.proAbroad.seriesNeed(run.round - League.proAbroad.rounds);
              expect(run.seriesWins == need - 1 || run.seriesLosses == need - 1, isTrue,
                  reason: 'seed $seed: ${run.seriesWins}-${run.seriesLosses} で止まった');
            }
            // 選んで進める。
            final pend = run.pending;
            if (pend != null) {
              run.resolve(p, Clutch.drive, form: 1, rng: Random(seed + guard), askClutch: true);
            } else {
              run.resolveHalftime(p, Halftime.keep, form: 1, rng: Random(seed + guard), askClutch: true);
            }
          }
        }
      }
      expect(stops, greaterThan(0));
    });

    test('古い保存(シリーズの項目なし)でも読める', () {
      final run = TournamentRun(League.proDomestic);
      final j = run.toJson()
        ..remove('seriesWins')
        ..remove('seriesLosses')
        ..remove('seriesWon')
        ..remove('eliminated')
        ..remove('seriesOpp');
      final back = TournamentRun.fromJson(j);
      expect(back.seriesWins, 0);
      expect(back.eliminated, isFalse);
      expect(back.seriesOpp, isNull);
    });
  });

  group('強さの並びと勝ちやすさ', () {
    test('強い選手ほど、どの形式でも勝つ・優勝しやすい(順序が崩れない)', () {
      for (final lg in League.values) {
        double winRate(int level) {
          var w = 0, n = 0;
          for (var seed = 0; seed < 150; seed++) {
            final t = playTournament(_p(level), lg, form: 1, rng: Random(seed));
            w += t.wins;
            n += t.games;
          }
          return w / n;
        }

        expect(winRate(90), greaterThan(winRate(55)), reason: lg.label);
      }
    });
  });

  test('プロの決勝シリーズは、ライバルとの再戦になることがある(決勝以外のプレーオフでは出ない)', () {
    var finals = 0, rivalFinals = 0;
    for (var seed = 0; seed < 150; seed++) {
      final base = Game.start('x', rng: Random(seed), events: false);
      final g = Game(
        eventsEnabled: false,
        player: base.player.copyWith(age: 26, heightCm: 194, clearPositionLock: true,
            abilities: {for (final a in Ability.values) a: 88}),
        rng: Random(seed),
        track: Track.pro,
        salary: 3000,
        slot: 1,
        rival: base.rival,
      );
      g.choose(Action.rest, Ability.defense);
      final t = g.lastReport?.tournament;
      if (t == null) continue;
      final po = t.playoffMatches;
      for (final m in po) {
        if (m.vsRival) expect(m.tag, contains('決勝'), reason: 'seed $seed: ${m.tag}');
        if (m.vsRival) expect(m.tag, isNot(contains('準決勝')));
      }
      if ((t.seriesWon ?? 0) >= 1) {
        finals++;
        if (po.any((m) => m.vsRival)) rivalFinals++;
      }
    }
    expect(finals, greaterThan(20));
    expect(rivalFinals, greaterThan(0), reason: '決勝でライバルと当たることがある');
    expect(rivalFinals, lessThan(finals), reason: 'いつもライバルではない');
  });
}
