import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/difficulty.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/rng.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

Career _start(Difficulty d, {int seed = 5, int rank = 12}) =>
    Career.start(seed: seed, team: teamAtRank(seed, rank), difficulty: d);

void main() {
  group('難しさ', () {
    test('保存に残り、読み直しても変わらない。前の版の保存(印が無い)はふつう', () {
      for (final d in Difficulty.values) {
        final c = _start(d);
        final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
        expect(copy.difficulty, d);
      }
      final old = _start(Difficulty.hard).toJson()..remove('df');
      expect(Career.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>).difficulty, Difficulty.normal);
      expect(Difficulty.fromIndex(99), Difficulty.normal);
      expect(Difficulty.fromIndex(null), Difficulty.normal);
    });

    test('難しさで変わるのは遊び方の決まりだけ。始めのリーグ(選手・年俸)は同じ', () {
      String league(Career c) => jsonEncode([for (final t in c.teams) t.toJson()..remove('co')]);
      final a = league(_start(Difficulty.easy));
      expect(league(_start(Difficulty.normal)), a);
      expect(league(_start(Difficulty.hard)), a);
    });

    test('同じ申し込みでも、やさしいほど相手が受けやすい(釣り合いの届き方が上がる)', () {
      final c = _start(Difficulty.normal, seed: 9, rank: 15);
      final them = c.teams.where((t) => t.index != c.mine).reduce((a, b) => a.capRoom >= b.capRoom ? a : b);
      final theirScrub = them.roster.reduce((a, b) => a.ovr <= b.ovr ? a : b);
      final mine = c.me.roster.where((p) => p.salary <= them.capRoom + theirScrub.salary).reduce((a, b) => a.ovr >= b.ovr ? a : b);
      final o = TradeOffer(partner: them.index, give: [mine.id], get: [theirScrub.id]);
      double ratio(Difficulty d) {
        c.difficulty = d;
        return c.judge(o).ratio;
      }

      final easy = ratio(Difficulty.easy), normal = ratio(Difficulty.normal), hard = ratio(Difficulty.hard);
      expect(easy, greaterThan(normal));
      expect(normal, greaterThan(hard));
      expect(easy / hard, closeTo(Difficulty.hard.tradeHardness / Difficulty.easy.tradeHardness, 0.001));
    });

    test('けがはきびしいほど多い(同じ乱数なので、起きる抽選の線だけが違う)', () {
      final t = _start(Difficulty.normal).me;
      int injuries(Difficulty d) {
        var n = 0;
        for (var i = 0; i < 1500; i++) {
          for (final p in t.roster) {
            p.injured = 0;
          }
          boxScore(t, 105, Rng(i), injuryScale: d.injury);
          n += t.roster.where((p) => p.injured > 0).length;
        }
        return n;
      }

      final easy = injuries(Difficulty.easy), normal = injuries(Difficulty.normal), hard = injuries(Difficulty.hard);
      expect(easy, lessThan(normal), reason: 'easy=$easy normal=$normal hard=$hard');
      expect(normal, lessThan(hard), reason: 'easy=$easy normal=$normal hard=$hard');
    });

    test('オーナーの信頼は、減るときだけ難しさの倍率がかかる(増えるときは同じ)', () {
      // 同じシーズンをプレーオフの直前まで進め、そこで3つに複製して難しさだけ替える(続きは同じ乱数)
      var dropped = 0, rose = 0;
      for (final seed in [1, 2, 4, 5, 6, 10]) {
        for (final rank in [2, 15, 28]) {
          final base = _start(Difficulty.normal, seed: seed, rank: rank)..ownerType = OwnerType.winNow; // 上乗せが付きにくい性格(減る局面を確かめるため)
          base.startSeason();
          while (base.phase == Phase.season) {
            base.playBlock();
          }
          int delta(Difficulty d) {
            final c = Career.fromJson(jsonDecode(jsonEncode(base.toJson())) as Map<String, dynamic>)..difficulty = d;
            final before = c.trust;
            c.playPlayoffs();
            return c.trust - before;
          }

          final easy = delta(Difficulty.easy), normal = delta(Difficulty.normal), hard = delta(Difficulty.hard);
          if (normal < 0) {
            dropped++;
            expect(hard, lessThanOrEqualTo(normal), reason: 'seed $seed rank $rank');
            expect(easy, greaterThanOrEqualTo(normal), reason: 'seed $seed rank $rank');
          } else if (normal > 0) {
            rose++;
            expect([easy, hard], everyElement(normal), reason: 'seed $seed rank $rank');
          }
        }
      }
      expect(dropped, greaterThan(0), reason: '減る局面を1つは確かめる');
      expect(rose, greaterThan(0), reason: '増える局面を1つは確かめる');
    });
  });
}
