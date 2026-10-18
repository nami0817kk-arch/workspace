import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _bat(int v) => Player(
    name: 't',
    role: Role.batter,
    age: 27,
    potential: 50,
    abilities: {for (final a in batterAbilities) a: v});

const _opp = [55, 60, 66, 72, 78];

Game proGameForTest() => _proGame();

Game _proGame() {
  for (var s = 0; s < 60; s++) {
    final g = Game.newGame(
        name: 't', role: Role.batter, rng: Random(s), potential: 100);
    var n = 0;
    while (g.phase != Phase.retired && n++ < 4000) {
      g.autoSpend();
      if (g.stage == Stage.pro && g.phase == Phase.term && g.slot == 0) {
        return g;
      }
      switch (g.phase) {
        case Phase.term:
          g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
              Ability.contact);
        case Phase.event:
          g.resolveEvent(0);
        case Phase.pathChoice:
          g.chooseRoute(Course.university);
        case Phase.retired:
          break;
      }
    }
  }
  fail('プロの最初の月まで進めない');
}

void main() {
  group('月ごとの進行(チャンク)', () {
    test('小分けにしても、全試合ぶんの記録になる(試合数・勝敗の合計)', () {
      var prog = const LeagueProgress();
      final rng = Random(1);
      for (final n in [20, 20, 20, 20, 20, 20, 23]) {
        prog = playLeagueChunk(_bat(65), prog,
            teamLevel: 65, opponents: _opp, rng: rng, count: n);
      }
      expect(prog.games, leagueGames);
      expect(prog.wins + prog.losses, leagueGames);
      final season = prog.toSeason();
      expect(season.games, leagueGames);
      expect(season.line.games, leagueGames); // 打者は全試合に出る
      expect(season.missed, 0);
    });

    test('1度にまとめて進めても、小分けでも、平均の成績はほぼ同じ', () {
      double avgHits(bool chunked) {
        var hits = 0;
        const n = 60;
        for (var s = 0; s < n; s++) {
          final rng = Random(s);
          if (chunked) {
            var prog = const LeagueProgress();
            for (final c in [20, 20, 20, 20, 20, 20, 23]) {
              prog = playLeagueChunk(_bat(65), prog,
                  teamLevel: 65, opponents: _opp, rng: rng, count: c);
            }
            hits += prog.line.hits;
          } else {
            hits += playLeagueSeason(_bat(65),
                    teamLevel: 65, opponents: _opp, rng: rng)
                .line
                .hits;
          }
        }
        return hits / n;
      }

      expect((avgHits(true) - avgHits(false)).abs(), lessThan(8));
    });

    test('怪我で出られない月は、自分の成績が増えず、欠場として数える', () {
      var prog = playLeagueChunk(_bat(65), const LeagueProgress(),
          teamLevel: 65, opponents: _opp, rng: Random(1), count: 20);
      final before = prog.line.atBats;
      prog = playLeagueChunk(_bat(65), prog,
          teamLevel: 65,
          opponents: _opp,
          rng: Random(2),
          count: 20,
          available: false);
      expect(prog.line.atBats, before);
      expect(prog.missed, 20);
      expect(prog.games, 40);
      expect(prog.wins + prog.losses, 40);
    });

    test('途中経過は保存して読み直せる。古いセーブ(なし)は空', () {
      final prog = playLeagueChunk(_bat(65), const LeagueProgress(),
          teamLevel: 65, opponents: _opp, rng: Random(3), count: 20);
      final back = LeagueProgress.fromJson(prog.toJson());
      expect(back.games, 20);
      expect(back.wins, prog.wins);
      expect(back.line.hits, prog.line.hits);
      expect(LeagueProgress.fromJson({}).games, 0);
    });
  });

  group('ゲームの中', () {
    test('プロの月ごとに途中経過が進み、10月に1年の結果になる', () {
      final g = _proGame();
      expect(g.seasonProgress, isNull);
      var lastGames = 0;
      final seen = <int>[];
      var k = 0;
      final n0 = g.records.length;
      while (g.records.length == n0 && g.phase != Phase.retired && k++ < 60) {
        if (g.phase == Phase.event) {
          g.resolveEvent(0);
          continue;
        }
        g.choose(Plan.rest, Ability.contact);
        final p = g.seasonProgress;
        if (p != null) {
          expect(p.games, greaterThanOrEqualTo(lastGames));
          lastGames = p.games;
          seen.add(p.games);
        }
      }
      // 4〜9月の6か月ぶん、20試合ずつ増える
      expect(seen.toSet().toList()..sort(), [20, 40, 60, 80, 100, 120]);
      expect(g.records.length, n0 + 1);
      final r = g.records.last;
      expect(r.line.games, greaterThan(0));
      expect(r.teamWins + r.teamLosses, leagueGames);
      expect(g.seasonProgress, isNull); // 年が終わると空に戻る
    });

    test('保存して読み直しても、シーズンの途中から続けられる', () {
      final g = _proGame();
      g.choose(Plan.rest, Ability.contact);
      var k = 0;
      while (g.phase == Phase.event && k++ < 3) {
        g.resolveEvent(0);
      }
      final games = g.seasonProgress?.games;
      expect(games, 20);
      final back = Game.fromJson(g.toJson(), Random(5));
      expect(back.seasonProgress?.games, 20);
      expect(back.seasonProgress?.wins, g.seasonProgress?.wins);
      // 続きを進められる
      var n = 0;
      while (back.records.length == g.records.length &&
          back.phase != Phase.retired &&
          n++ < 60) {
        back.phase == Phase.event
            ? back.resolveEvent(0)
            : back.choose(Plan.rest, Ability.contact);
      }
      expect(back.records.length, g.records.length + 1);
    });

    test('古いセーブ(途中経過なし)でも読める', () {
      final g = _proGame();
      final old = g.toJson()..remove('seasonProgress');
      expect(Game.fromJson(old, Random(1)).seasonProgress, isNull);
    });

    test('怪我で欠場したシーズンは、ログに欠場の試合数が出る', () {
      var found = false;
      for (var s = 0; s < 40 && !found; s++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(s), potential: 100);
        var n = 0;
        while (g.phase != Phase.retired && n++ < 4000 && !found) {
          g.autoSpend();
          switch (g.phase) {
            case Phase.term:
              // 特訓で怪我しやすくする
              g.choose(g.stage == Stage.pro ? Plan.special : Plan.train,
                  Ability.contact);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
          if (g.log.any((l) => RegExp(r'^怪我で\d+試合を欠場した。$').hasMatch(l))) {
            found = true;
          }
        }
      }
      expect(found, isTrue);
    });

    test('プロの月ごとに、成績とチームの勝敗がログに出る', () {
      final g = _proGame();
      final re = RegExp(r'チームは\d+勝\d+敗。$');
      for (var i = 0; i < 6; i++) {
        final before = g.log.length;
        g.choose(Plan.rest, Ability.contact);
        while (g.phase == Phase.event) {
          g.resolveEvent(0);
        }
        expect(g.log.skip(before).any(re.hasMatch), isTrue, reason: 'slot $i');
        if (g.phase != Phase.term) break;
      }
    });
  });
}
