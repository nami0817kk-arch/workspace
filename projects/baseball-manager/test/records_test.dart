import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:baseball_manager/game/world.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Role r, int v) => Player(
      name: 't',
      role: r,
      age: 26,
      potential: 50,
      abilities: {for (final a in abilitiesOf(r)) a: v},
    );

LeagueSeason _season(Player p, int seed) => playLeagueSeason(
      p,
      teamLevel: 65,
      opponents: const [55, 60, 66, 72, 78],
      rng: Random(seed),
    );

void main() {
  main2();
  twoWayChecks();
  group('Line', () {
    test('打率・出塁率・長打率・OPS', () {
      const l = Line(atBats: 400, hits: 120, totalBases: 200, walks: 50);
      expect(l.battingAverage, closeTo(0.300, 1e-9));
      expect(l.onBase, closeTo(170 / 450, 1e-9));
      expect(l.slugging, closeTo(0.500, 1e-9));
      expect(l.ops, closeTo(170 / 450 + 0.5, 1e-9));
      expect(const Line().battingAverage, isNull);
      expect(const Line().era, isNull);
    });

    test('防御率・投球回', () {
      const l = Line(faced: 100, outs: 60, runsRaw: -2);
      expect(l.inningsPitched, 20);
      expect(l.inningsText, '20');
      expect(const Line(outs: 61).inningsText, '20 1/3');
      expect(l.runsAllowed, closeTo(8, 1e-9)); // -2 + 0.10*100
      expect(l.era, closeTo(8 * 27 / 60, 1e-9));
      expect(
          const Line(faced: 5, outs: 1, runsRaw: -5).runsAllowed, 0); // 負にはならない
    });

    test('足し算と勝敗の付与、保存して読み直せる', () {
      const a = Line(games: 1, atBats: 4, hits: 2, wins: 0);
      final b = a.withDecision(win: true) + a;
      expect((b.games, b.atBats, b.hits, b.wins, b.losses), (2, 8, 4, 1, 0));
      final q = Line.fromJson(
          jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(q.toJson()), jsonEncode(b.toJson()));
      expect(Line.fromJson({}).games, 0); // 欠けた項目は既定値
    });
  });

  test('数値の見せ方: 打率は「.285」、1以上は「1.031」', () {
    expect(fmtRate(0.2849), '.285');
    expect(fmtRate(1.0312), '1.031');
    expect(fmtRate(null), '-');
    expect(fmtEra(3.126), '3.13');
  });

  test('1試合の成績に矛盾がない(安打≤打数、アウト≥三振、出場1)', () {
    for (var s = 0; s < 200; s++) {
      final g = playGame(_p(Role.twoWay, 60), 50, Random(s));
      expect(g.hits, lessThanOrEqualTo(g.atBats));
      expect(g.homeRuns, lessThanOrEqualTo(g.hits));
      expect(g.totalBases, greaterThanOrEqualTo(g.hits));
      expect(g.outs, greaterThanOrEqualTo(g.strikeouts));
      expect(
          g.outs + g.hitsAllowed + g.walksGiven + g.homeRunsAllowed, g.faced);
      expect(g.games, 1);
      expect(g.starts, 1);
    }
    // 打者は投げない・投手は打たない。
    expect(playGame(_p(Role.batter, 60), 50, Random(1)).faced, 0);
    expect(playGame(_p(Role.pitcher, 60), 50, Random(1)).atBats, 0);
    // 登板しない試合では投げない。
    final rest = playGame(_p(Role.pitcher, 60), 50, Random(1), pitch: false);
    expect((rest.faced, rest.games), (0, 0));
  });

  group('プロの1シーズン', () {
    test('143試合で、勝敗の合計が試合数。打者は全試合に出る', () {
      final s = _season(_p(Role.batter, 60), 1);
      expect(s.games, 143);
      expect(s.wins + s.losses, 143);
      expect(s.line.games, 143);
      expect(s.line.plateAppearances, inInclusiveRange(500, 640));
      expect(s.line.faced, 0);
      expect(s.rank, inInclusiveRange(1, 6));
    });

    test('投手は5試合に1度先発し、勝敗は先発の数まで', () {
      final s = _season(_p(Role.pitcher, 70), 2);
      expect(s.line.starts, (143 / startInterval).ceil());
      expect(s.line.atBats, 0);
      expect(s.line.wins + s.line.losses, lessThanOrEqualTo(s.line.starts));
      expect(s.line.inningsPitched, greaterThan(80));
      expect(s.line.era, inInclusiveRange(1.0, 8.0));
    });

    test('二刀流は打つのも投げるのも成績に残る', () {
      final s = _season(_p(Role.twoWay, 60), 3);
      expect(s.line.hasBatting, isTrue);
      expect(s.line.hasPitching, isTrue);
    });

    test('能力が高いほど、打率・OPSが良く、防御率が良い(平均)', () {
      double avg(Iterable<double> x) => x.reduce((a, b) => a + b) / x.length;
      final bLo = [
        for (var i = 0; i < 40; i++) _season(_p(Role.batter, 35), i).line.ops!
      ];
      final bHi = [
        for (var i = 0; i < 40; i++) _season(_p(Role.batter, 80), i).line.ops!
      ];
      expect(avg(bHi), greaterThan(avg(bLo) + 0.1));
      final pLo = [
        for (var i = 0; i < 40; i++) _season(_p(Role.pitcher, 35), i).line.era!
      ];
      final pHi = [
        for (var i = 0; i < 40; i++) _season(_p(Role.pitcher, 80), i).line.era!
      ];
      expect(avg(pHi), lessThan(avg(pLo) - 1.0));
    });

    test('平均的な選手の成績が、野球として自然な範囲に収まる', () {
      double avg(Iterable<double> x) => x.reduce((a, b) => a + b) / x.length;
      final b = [
        for (var i = 0; i < 60; i++) _season(_p(Role.batter, 60), i).line
      ];
      expect(
          avg(b.map((l) => l.battingAverage!)), inInclusiveRange(0.24, 0.29));
      expect(
          avg(b.map((l) => l.homeRuns.toDouble())), inInclusiveRange(10, 25));
      final p = [
        for (var i = 0; i < 60; i++) _season(_p(Role.pitcher, 60), i).line
      ];
      expect(avg(p.map((l) => l.era!)), inInclusiveRange(3.0, 5.0));
    });

    test('順位は勝率から決まる', () {
      expect(leagueRank(0.65), 1);
      expect(leagueRank(0.55), 2);
      expect(leagueRank(0.52), 3);
      expect(leagueRank(0.49), 4);
      expect(leagueRank(0.45), 5);
      expect(leagueRank(0.30), 6);
    });
  });

  group('タイトル', () {
    test('規定に届いて、基準を超えたら獲得する', () {
      const bat =
          Line(atBats: 520, hits: 190, walks: 60, homeRuns: 42); // 打率.365・PA580
      final t = titlesOf(bat, games: 143, rank: 3);
      expect(t, containsAll(['首位打者', '本塁打王', 'MVP'])); // 2つ以上でMVP
    });

    test('規定打席に足りなければ首位打者にならない', () {
      const bat = Line(atBats: 300, hits: 120, walks: 20); // 打率.400だがPA320
      expect(titlesOf(bat, games: 143, rank: 3), isNot(contains('首位打者')));
    });

    test('投手のタイトル。リーグ優勝のチームなら1つでもMVP', () {
      const pit =
          Line(faced: 900, outs: 600, strikeouts: 260, wins: 22, runsRaw: -80);
      final t = titlesOf(pit, games: 143, rank: 1);
      expect(t, containsAll(['最多勝', '最多奪三振', 'MVP']));
      const one = Line(strikeouts: 260);
      expect(titlesOf(one, games: 143, rank: 5), ['最多奪三振']);
      expect(titlesOf(one, games: 143, rank: 1), ['最多奪三振', 'MVP']);
    });

    test('平凡な成績ではタイトルは無い', () {
      expect(
          titlesOf(const Line(atBats: 500, hits: 130, walks: 40, homeRuns: 15),
              games: 143, rank: 4),
          isEmpty);
    });
  });

  group('成績の記録', () {
    test('年の成績の保存と読み直し・表の「結果」欄', () {
      const r = SeasonRecord(
        age: 17,
        stage: Stage.highSchool,
        line: Line(games: 4, atBats: 15, hits: 6),
        roundsWon: 2,
        rounds: 5,
        rivalWon: true,
      );
      final q = SeasonRecord.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect((q.age, q.stage, q.roundsWon, q.rivalWon),
          (17, Stage.highSchool, 2, true));
      expect(q.resultText, '3回戦敗退');
      expect(
          const SeasonRecord(
                  age: 1,
                  stage: Stage.youth,
                  line: Line(),
                  roundsWon: 4,
                  rounds: 4)
              .resultText,
          '優勝');
      expect(
          const SeasonRecord(age: 1, stage: Stage.pro, line: Line(), rank: 1)
              .resultText,
          'リーグ優勝');
      expect(
          const SeasonRecord(age: 1, stage: Stage.pro, line: Line(), rank: 4)
              .resultText,
          '4位');
      expect(SeasonRecord.fromJson({}).stage, Stage.youth);
    });

    test('通算は年ごとの合計', () {
      final t = totalOf(const [
        SeasonRecord(
            age: 1, stage: Stage.pro, line: Line(atBats: 100, hits: 30)),
        SeasonRecord(
            age: 2, stage: Stage.pro, line: Line(atBats: 200, hits: 70)),
      ]);
      expect((t.atBats, t.hits), (300, 100));
    });

    test('成績の短い説明: 打者・投手・二刀流', () {
      expect(
          describeLine(const Line(
              atBats: 100, hits: 30, totalBases: 50, walks: 10, homeRuns: 3)),
          contains('打率.300'));
      expect(
          describeLine(const Line(
              faced: 100, outs: 60, wins: 3, losses: 1, strikeouts: 40)),
          allOf(contains('3勝1敗'), contains('防御率'), contains('奪三振40')));
      expect(describeLine(const Line()), '');
    });
  });

  group('ゲームの中の成績', () {
    Game play(int seed, {int? potential, bool Function(Game)? stop}) {
      final g = Game.newGame(
          name: 't',
          role: Role.batter,
          rng: Random(seed),
          potential: potential);
      var steps = 0;
      while (g.phase != Phase.retired && !(stop?.call(g) ?? false)) {
        if (++steps > 4000) fail('終わらない');
        g.autoSpend();
        switch (g.phase) {
          case Phase.term:
            if (g.stage == Stage.pro && g.player.age >= 36) {
              g.retire();
            } else {
              g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                  Ability.contact);
            }
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
      }
      return g;
    }

    test('アマチュアは毎年の大会、プロは毎年のシーズンが記録される', () {
      for (var s = 0; s < 40; s++) {
        final g = play(s, potential: 100);
        if (!g.ending!.madePro) continue;
        // 6歳から引退した年まで、1年に1件ずつ。
        expect(
            g.records.map((r) => r.age).toList(),
            [for (var a = 6; a < g.player.age + 1; a++) a]
                .take(g.records.length)
                .toList());
        expect(g.records.where((r) => r.stage == Stage.pro), isNotEmpty);
        for (final r in g.records.where((r) => r.stage == Stage.pro)) {
          expect(r.isLeague, isTrue);
          expect(r.teamWins + r.teamLosses, 143);
        }
        for (final r in g.records.where((r) => r.stage != Stage.pro)) {
          expect(r.isLeague, isFalse);
          expect(r.rounds, greaterThan(0));
        }
        return;
      }
      fail('プロになった選手がいない');
    });

    test('プロのシーズン成績は10月に出る。それ以外の月には出ない', () {
      for (var s = 0; s < 60; s++) {
        final g = play(s,
            potential: 100,
            stop: (g) => g.stage == Stage.pro && g.phase == Phase.term);
        if (g.stage != Stage.pro) continue;
        expect(g.slotName, '4月');
        final before = g.records.length;
        var guard = 0;
        while (g.slotName != '10月') {
          if (++guard > 30) fail('10月に着かない');
          expect(g.records.length, before, reason: g.slotName);
          g.phase == Phase.event
              ? g.resolveEvent(0)
              : g.choose(Plan.rest, Ability.contact);
        }
        g.choose(Plan.rest, Ability.contact);
        expect(g.records.length, before + 1);
        expect(g.records.last.isLeague, isTrue);
        expect(g.log.any((l) => l.startsWith('今季成績')), isTrue);
        return;
      }
      fail('プロになった選手がいない');
    });

    test('成績は保存して読み直せ、エンディングにタイトルが出る', () {
      final g = play(3, potential: 100);
      final q = Game.fromJson(
          jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
          Random(1));
      expect(jsonEncode(q.records.map((r) => r.toJson()).toList()),
          jsonEncode(g.records.map((r) => r.toJson()).toList()));
      expect(g.ending!.titles, [for (final r in g.records) ...r.titles]);
      expect(Game.fromJson({}, Random(1)).records, isEmpty); // 古いセーブ
    });

    test('優勝回数は、大会の優勝とリーグ優勝の合計と一致する', () {
      final g = play(5, potential: 100);
      expect(g.championships, g.records.where((r) => r.champion).length);
    });
  });

  group('年俸', () {
    SeasonRecord rec(Player p,
        {Stage stage = Stage.pro, List<String> t = const []}) {
      final line = _season(p, 3).line;
      return SeasonRecord(
          age: 26, stage: stage, line: line, rank: 2, titles: t);
    }

    test('強い選手ほど高い。タイトルでも上がる。プロ以外は0', () {
      final lo = salaryOf(rec(_p(Role.batter, 40)));
      final hi = salaryOf(rec(_p(Role.batter, 85)));
      expect(hi, greaterThan(lo));
      final p = _p(Role.batter, 70);
      expect(salaryOf(rec(p, t: ['首位打者'])), greaterThan(salaryOf(rec(p))));
      expect(salaryOf(rec(p, stage: Stage.highSchool)), 0);
      expect(lo, inInclusiveRange(400, 80000));
      expect(hi, inInclusiveRange(400, 80000));
    });

    test('表記: 万円と億円', () {
      expect(fmtSalary(0), '-');
      expect(fmtSalary(1750), '1750万円');
      expect(fmtSalary(10000), '1億円');
      expect(fmtSalary(23000), '2億3000万円');
    });
  });

  group('人気', () {
    SeasonRecord rec(int age,
            {List<String> titles = const [],
            int rank = 4,
            Stage stage = Stage.pro,
            bool overseas = false}) =>
        SeasonRecord(
            age: age,
            stage: stage,
            line: const Line(),
            rank: stage == Stage.pro ? rank : null,
            titles: titles,
            overseas: overseas);
    WorldRecord world(int age, bool champion) => WorldRecord(
        age: age,
        eventId: 'pro',
        eventName: '世界大会',
        roundsWon: champion ? 4 : 1,
        rounds: 4,
        line: const Line());

    test('記録が無ければ0。0〜100に収まる', () {
      expect(popularityOf(const [], const []), 0);
      final many = [
        for (var a = 22; a < 40; a++)
          rec(a, titles: ['MVP', '最多勝', '首位打者'], rank: 1)
      ];
      expect(popularityOf(many, [world(30, true)]), 100);
    });

    test('タイトル・優勝・日本代表・海外で上がる', () {
      final base = popularityOf([rec(25)], const []);
      expect(
          popularityOf([
            rec(25, titles: ['最多勝'])
          ], const []),
          greaterThan(base));
      expect(popularityOf([rec(25, rank: 1)], const []), greaterThan(base));
      expect(
          popularityOf([rec(25, overseas: true)], const []), greaterThan(base));
      expect(popularityOf([rec(25)], [world(25, false)]), greaterThan(base));
      expect(popularityOf([rec(25)], [world(25, true)]),
          greaterThan(popularityOf([rec(25)], [world(25, false)])));
    });

    test('昔の活躍は薄れる(8年より前は半分)', () {
      final old = [
        rec(22, titles: ['MVP', '最多勝']),
        rec(40)
      ];
      final fresh = [
        rec(32, titles: ['MVP', '最多勝']),
        rec(40)
      ];
      expect(
          popularityOf(old, const []), lessThan(popularityOf(fresh, const [])));
    });
  });

  test('殊勲の試合は、勝ち+個人の出来が高いときだけ', () {
    const great =
        Line(games: 1, atBats: 4, hits: 4, totalBases: 10, homeRuns: 2, rbi: 5);
    const poor = Line(games: 1, atBats: 4, hits: 0);
    expect(isHeroGame(great, won: true), isTrue);
    expect(isHeroGame(great, won: false), isFalse);
    expect(isHeroGame(poor, won: true), isFalse);
  });
}

void main2() {
  test('ERA+・OPS+は、投球回・打席が少ないと出さず、十分あれば上限999までの値', () {
    const few = Line(faced: 10, outs: 6, runsRaw: -50);
    expect(few.eraPlus, isNull);
    const fewBat = Line(atBats: 1, hits: 1, totalBases: 4);
    expect(fewBat.opsPlus, isNull);
    const pitcher = Line(faced: 120, outs: 90, runsRaw: 0);
    expect(pitcher.eraPlus! <= 999, isTrue);
    const bat = Line(atBats: 40, hits: 40, totalBases: 160);
    expect(bat.opsPlus! <= 999, isTrue);
  });
}

void twoWayChecks() {
  SeasonRecord rec({required bool twoWay}) => SeasonRecord(
      age: 25,
      stage: Stage.pro,
      line: const Line(
          games: 140, atBats: 500, hits: 150, totalBases: 240, walks: 50),
      rank: 3,
      twoWay: twoWay);
  test('二刀流の年は、年俸が1.4倍・人気が+1。保存で残る', () {
    final a = rec(twoWay: false), b = rec(twoWay: true);
    expect(salaryOf(b), greaterThan(salaryOf(a)));
    expect((salaryOf(b) / salaryOf(a) - 1.4).abs(), lessThan(0.02));
    expect(popularityOf([b], const []),
        greaterThanOrEqualTo(popularityOf([a], const [])));
    expect(SeasonRecord.fromJson(b.toJson()).twoWay, isTrue);
    expect(SeasonRecord.fromJson({'age': 20}).twoWay, isFalse);
  });
}
