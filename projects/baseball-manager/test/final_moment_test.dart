import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/final_moment.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(Role role, {int v = 60}) => Player(
    name: 't',
    role: role,
    age: 17,
    potential: 80,
    abilities: {for (final a in abilitiesOf(role)) a: v});

/// 夏の大会の決勝の決断まで進める(見つかるまで、いくつかの選手で試す)。
Game? _atFinal(int seed, {Role role = Role.batter}) {
  final g =
      Game.newGame(name: 't', role: role, rng: Random(seed), potential: 100);
  var guard = 0;
  while (g.phase != Phase.retired && guard++ < 4000) {
    switch (g.phase) {
      case Phase.term:
        g.autoSpend();
        g.choose(Plan.train, abilitiesOf(role).first);
      case Phase.event:
        if (g.pendingEvent!.id == finalMomentId) return g;
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return null;
}

Game _final({Role role = Role.batter}) {
  for (var s = 0; s < 60; s++) {
    final g = _atFinal(s, role: role);
    if (g != null) return g;
  }
  fail('決勝まで勝ち上がった例が無い');
}

void main() {
  group('決勝の見せ場の計算', () {
    test('作戦は3つ。打者と投手で違い、ラベルに能力の値が付く', () {
      final b = finalMomentEvent(_p(Role.batter, v: 77));
      expect(b.id, finalMomentId);
      expect(b.choices.length, 3);
      expect(b.choices[0].label, contains('パワー 77'));
      expect(b.choices[0].label, contains('賭け'));
      expect(b.choices[1].label, contains('ミート 77'));
      final pitcher = finalMomentEvent(_p(Role.pitcher, v: 40));
      expect(pitcher.choices[0].label, contains('球威 40'));
      expect(pitcher.choices[1].label, contains('制球 40'));
    });

    test('使う能力が高いほど、勝つ確率の上乗せが大きい(安全な作戦は毎回同じ)', () {
      final low = _p(Role.batter, v: 30);
      final high = _p(Role.batter, v: 90);
      for (final i in [1, 2]) {
        expect(finalBonus(i, high, Random(1)),
            greaterThan(finalBonus(i, low, Random(1))));
        expect(finalBonus(i, high, Random(1)), finalBonus(i, high, Random(9)));
      }
      // 賭け(強振)はぶれる
      final xs = {for (var s = 0; s < 20; s++) finalBonus(0, high, Random(s))};
      expect(xs.length, greaterThan(10));
      // 上乗せは範囲に収まる
      for (final p in [low, high]) {
        for (var i = 0; i < 3; i++) {
          for (var s = 0; s < 30; s++) {
            expect(finalBonus(i, p, Random(s)), inInclusiveRange(-0.25, 0.25));
          }
        }
      }
    });

    test('決勝の途中経過は、保存して読み直せる', () {
      final m = FinalMoment(
        games: [
          TournamentGame(
              opponent: 40, won: true, line: const Line(games: 1, hits: 2)),
        ],
        line: const Line(games: 1, hits: 2),
        roundsWon: 1,
        rounds: 2,
        opponent: 55,
        finalLine: const Line(games: 1, hits: 1),
        pWin: 0.42,
      );
      final back = FinalMoment.fromJson(
          jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(back.toJson()), jsonEncode(m.toJson()));
      expect(back.pWin, 0.42);
      expect(back.games.single.line.hits, 2);
    });

    test('決勝を決める: 上乗せが大きいほど優勝しやすい。無失点の登板は負けない', () {
      final m = FinalMoment(
        games: const [],
        line: const Line(),
        roundsWon: 0,
        rounds: 1,
        opponent: 50,
        finalLine: const Line(games: 1, atBats: 4, hits: 1),
        pWin: 0.5,
      );
      int wins(double bonus) {
        var w = 0;
        for (var s = 0; s < 2000; s++) {
          if (finishFinal(m, bonus, Random(s)).champion) w++;
        }
        return w;
      }

      expect(wins(0.2), greaterThan(wins(0.0)));
      expect(wins(0.0), greaterThan(wins(-0.2)));
      final shutout = FinalMoment(
        games: const [],
        line: const Line(),
        roundsWon: 0,
        rounds: 1,
        opponent: 50,
        finalLine: Line(
            games: 1,
            starts: 1,
            faced: 24,
            outs: 18,
            runsRaw: -runBaseline * 24),
        pWin: 0.0,
      );
      for (var s = 0; s < 30; s++) {
        expect(finishFinal(shutout, -0.5, Random(s)).champion, isTrue);
      }
    });
  });

  group('ゲームの中', () {
    test('決勝まで進むと、出来事の形で作戦を選べる。選ぶまで大会の記録は付かない', () {
      final g = _final();
      expect(g.phase, Phase.event);
      expect(g.pendingEvent!.id, finalMomentId);
      expect(g.pendingFinal, isNotNull);
      final recs = g.records.length;
      final slot = g.slot;
      expect(g.pendingEvent!.choices.length, 3);
      g.resolveEvent(1);
      expect(g.pendingFinal, isNull);
      expect(g.records.length, recs + 1);
      expect(g.records.last.roundsWon,
          greaterThanOrEqualTo(g.records.last.rounds - 1));
      expect(g.log.any((l) => l.contains('決勝の最終回')), isTrue);
      expect(g.log.any((l) => l.contains('決勝')), isTrue);
      // 大会のあと、普通に次の季節(か出来事)へ進む
      expect(g.phase == Phase.term || g.phase == Phase.event, isTrue);
      expect(g.slot == slot + 1 || g.phase == Phase.event, isTrue);
    });

    test('決断を待つ途中で保存して読み直しても、同じ選択肢で続きが進む', () {
      final g = _final();
      final back = Game.fromJson(
          jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>,
          Random(5));
      expect(back.phase, Phase.event);
      expect(back.pendingEvent!.id, finalMomentId);
      expect(back.pendingFinal!.opponent, g.pendingFinal!.opponent);
      expect(jsonEncode(back.pendingFinal!.toJson()),
          jsonEncode(g.pendingFinal!.toJson()));
      back.resolveEvent(2);
      expect(back.pendingFinal, isNull);
    });

    test('投手でも決勝の見せ場が出て、最後まで遊べる', () {
      final g = _final(role: Role.pitcher);
      expect(g.pendingEvent!.choices[0].label, contains('球威'));
      var guard = 0;
      while (g.phase != Phase.retired && guard++ < 4000) {
        switch (g.phase) {
          case Phase.term:
            g.autoSpend();
            g.choose(Plan.train, Ability.stuff);
          case Phase.event:
            g.resolveEvent(guard % 3 == 0 ? 0 : 1);
          case Phase.pathChoice:
            g.chooseRoute(Course.university);
          case Phase.retired:
            break;
        }
      }
      expect(g.phase, Phase.retired);
    });
  });
}
