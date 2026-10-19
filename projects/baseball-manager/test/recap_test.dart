import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/flavor.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('勝ち抜き戦の各試合', () {
    Player p(int v) => Player(
        name: 't',
        role: Role.batter,
        age: 17,
        potential: 50,
        abilities: {for (final a in batterAbilities) a: v});

    test('試合の記録は、勝った数(+負けた1試合)と一致する', () {
      for (var seed = 0; seed < 100; seed++) {
        final t = playTournament(p(60),
            teamLevel: 50,
            opponents: const [40, 46, 52, 58, 64],
            rng: Random(seed));
        final lost = t.champion ? 0 : 1;
        expect(t.games.length, t.roundsWon + lost, reason: 'seed $seed');
        expect(t.games.where((g) => g.won).length, t.roundsWon);
        if (!t.champion) expect(t.games.last.won, isFalse);
        // 各試合の成績を足すと、大会全体の成績になる
        var sum = const Line();
        for (final g in t.games) {
          sum += g.line;
        }
        expect(sum.atBats, t.line.atBats);
        expect(sum.hits, t.line.hits);
      }
    });

    test('勝ち負けの決め方は従来と同じ(乱数の使い方を変えていない)', () {
      // 同じ乱数なら同じ結果になる
      final a = playTournament(p(55),
          teamLevel: 50, opponents: const [40, 50, 60], rng: Random(9));
      final b = playTournament(p(55),
          teamLevel: 50, opponents: const [40, 50, 60], rng: Random(9));
      expect(a.roundsWon, b.roundsWon);
      expect(a.line.hits, b.line.hits);
    });
  });

  group('表記', () {
    test('回戦の呼び名: 最後は決勝、その前は準決勝', () {
      expect(roundLabel(0, 5), '1回戦');
      expect(roundLabel(2, 5), '3回戦');
      expect(roundLabel(3, 5), '準決勝');
      expect(roundLabel(4, 5), '決勝');
      expect(roundLabel(0, 2), '1回戦'); // 2試合なら準決勝は作らない
      expect(roundLabel(1, 2), '決勝');
    });

    test('1試合の中身', () {
      expect(describeGame(const Line(atBats: 4, hits: 2, homeRuns: 1, rbi: 3)),
          '4打数2安打 1本塁打 3打点');
      expect(describeGame(const Line(atBats: 3, hits: 0)), '3打数0安打');
      expect(
          describeGame(
              const Line(faced: 24, outs: 18, hitsAllowed: 3, strikeouts: 9)),
          '6回 被安打3 奪三振9');
      expect(describeGame(const Line()), '');
    });

    test('相手の名前は架空で、同じ条件なら同じ。自分の所属とは別', () {
      for (final st in [
        Stage.youth,
        Stage.juniorHigh,
        Stage.highSchool,
        Stage.pathChoice
      ]) {
        for (var r = 0; r < 6; r++) {
          final a = opponentName(st, 16, r);
          expect(a, opponentName(st, 16, r));
          expect(a, isNotEmpty);
        }
      }
      expect(opponentName(Stage.highSchool, 17, 2), contains('高校'));
      expect(opponentName(Stage.juniorHigh, 14, 0), contains('中学'));
      expect(opponentName(Stage.pathChoice, 20, 1, corporate: true),
          isNot(contains('大学')));
      final own = affiliationOf(Stage.highSchool, 'ユウタ');
      for (var r = 0; r < 12; r++) {
        for (var age = 16; age < 19; age++) {
          expect(
              own.contains(opponentName(Stage.highSchool, age, r, own: own)
                  .replaceAll('高校', '')),
              isFalse);
        }
      }
    });
  });

  group('ゲームの中', () {
    test('大会のあと、ログに試合ごとの結果(○/●・相手・出来)が残る', () {
      var checked = 0;
      for (var seed = 0; seed < 20 && checked < 5; seed++) {
        final g = Game.newGame(
            name: 't', role: Role.batter, rng: Random(seed), potential: 80);
        var n = 0;
        while (g.phase != Phase.retired && n++ < 4000 && checked < 5) {
          g.autoSpend();
          final before = g.log.length;
          switch (g.phase) {
            case Phase.term:
              g.choose(Plan.train, Ability.contact);
            case Phase.event:
              g.resolveEvent(0);
            case Phase.pathChoice:
              g.chooseRoute(Course.university);
            case Phase.retired:
              break;
          }
          final added = g.log.sublist(before);
          final rounds =
              added.where((l) => RegExp(r'^[○●] .* vs ').hasMatch(l));
          if (rounds.isNotEmpty && added.any((l) => l.contains('夏の大会'))) {
            checked++;
            // 最後の試合が負けなら●、優勝なら全部○
            if (added.any((l) => l.contains('で優勝した'))) {
              expect(rounds.every((l) => l.startsWith('○')), isTrue);
            } else {
              expect(rounds.last.startsWith('●'), isTrue, reason: '$added');
              expect(rounds.where((l) => l.startsWith('●')).length, 1);
            }
          }
        }
      }
      expect(checked, greaterThan(0));
    });
  });
}
