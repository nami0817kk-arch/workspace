import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/events.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/legacy.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

Game _pro({int age = 24, int salary = 2000, bool events = true}) {
  final base = Game.start('x', rng: Random(1), events: false);
  return Game(
    eventsEnabled: events,
    player: base.player.copyWith(
      age: age,
      heightCm: 196,
      abilities: {for (final a in Ability.values) a: 75},
    ),
    rng: Random(2),
    track: Track.pro,
    salary: salary,
  );
}

/// 1つの季節を進める(出来事・ハーフタイム・勝負どころは決まった選択で)。
void _step(Game g, {int event = 0}) {
  switch (g.phase) {
    case Phase.season:
      g.choose(recommendedAction(g), recommendedFocus(g.player));
    case Phase.halftime:
      g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
    case Phase.clutch:
      g.resolveClutch(Clutch.drive);
    case Phase.event:
      g.resolveEvent(event);
    case Phase.path:
      if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
    case Phase.retired:
      break;
  }
}

void main() {
  group('フリーエージェント', () {
    test('出来事は選択肢3つで、年俸の増減(salaryPct)が入っている', () {
      final e = eventById('pro_fa')!;
      expect(e.forced, isTrue);
      expect(e.options.length, 3);
      expect(e.options[0].effect.salaryPct, greaterThan(e.options[1].effect.salaryPct));
      expect(e.options[2].effect.salaryPct, 0);
    });

    test('25歳(プロ)の年の終わりに必ず起き、選ぶと年俸が変わる', () {
      final g = _pro(age: 24);
      var saw = false;
      var guard = 0;
      // 24→25歳の年の終わり。
      while (g.player.age < 26 && g.phase != Phase.retired && guard++ < 100) {
        if (g.phase == Phase.event && g.pendingEventId == 'pro_fa') {
          saw = true;
          final before = g.salary;
          final lines = g.resolveEvent(0);
          expect(g.salary, greaterThan(before));
          expect(lines.any((l) => l.startsWith('年俸')), isTrue);
          break;
        }
        if (g.phase == Phase.event) {
          g.resolveEvent(0);
          continue;
        }
        _step(g);
      }
      expect(saw, isTrue, reason: '25歳でフリーエージェントの出来事が起きなかった');
    });

    test('出来事を切っていれば起きない', () {
      final g = _pro(age: 24, events: false);
      var guard = 0;
      while (g.player.age < 27 && g.phase != Phase.retired && guard++ < 100) {
        expect(g.pendingEventId, isNull);
        _step(g);
      }
    });

    test('再契約は年俸が少し上がり、年俸ゼロ(プロ以外)なら変わらない', () {
      final g = _pro(salary: 2000);
      g.pendingEventId = 'pro_fa';
      g.resolveEvent(1);
      expect(g.salary, 2240);
      final h = _pro(salary: 0);
      h.pendingEventId = 'pro_fa';
      h.resolveEvent(0);
      expect(h.salary, 0);
    });
  });

  group('長い怪我からの復帰', () {
    test('復帰の出来事は選択肢3つで、無理をする選択だけ怪我の危険がある', () {
      final e = eventById('comeback')!;
      expect(e.options.length, 3);
      expect(e.options[0].effect.injuryChance, 0);
      expect(e.options[1].effect.injuryChance, greaterThan(0));
    });

    test('3ターン以上の怪我が治った直後に起き、短い怪我では起きない', () {
      Game injured(int terms, int streak) {
        final g = _pro(age: 22);
        g.condition = g.condition.copyWith(injuredTerms: terms, injuryName: '骨折');
        g.injuredStreak = streak;
        return g;
      }

      // 1ターンで治る(あと1ターン)怪我。連続4ターン目→治る→復帰。
      final long = injured(1, 3);
      var comeback = false;
      var guard = 0;
      while (!comeback && guard++ < 6) {
        if (long.phase == Phase.event) {
          comeback = long.pendingEventId == 'comeback';
          break;
        }
        // 休養で確実に治す。
        long.choose(Action.rest, Ability.values.first);
      }
      expect(comeback, isTrue);

      final short = injured(1, 1);
      short.choose(Action.rest, Ability.values.first);
      expect(short.pendingEventId, isNot('comeback'));
    });

    test('怪我の連続ターン数は保存・復元で変わらない', () {
      final g = _pro()..injuredStreak = 4;
      expect(Game.fromJson(g.toJson()).injuredStreak, 4);
      final j = g.toJson()..remove('injuredStreak');
      expect(Game.fromJson(j).injuredStreak, 0);
    });
  });

  group('引退セレモニー', () {
    Game retired({required int years, int titles = 0, String reason = '年齢を重ね、現役を退いた'}) {
      final g = _pro(age: 36);
      for (var i = 0; i < years; i++) {
        g.records.add(YearRecord(
          age: 25 + i, league: League.proDomestic, wins: 4, games: 8, ppg: 12, rpg: 4,
          apg: 3, champion: i < titles, achievement: 60,
        ));
      }
      g.retiredReason = reason;
      return g;
    }

    test('プロで10年戦って優勝があれば、満員のアリーナで見送られる', () {
      final lines = epilogueLines(retired(years: 11, titles: 2));
      expect(lines.any((l) => l.contains('引退セレモニー') && l.contains('スタンディングオベーション')), isTrue);
    });

    test('5年以上なら仲間とファンに見送られ、戦力外なら最後の試合まで立つ', () {
      expect(epilogueLines(retired(years: 6)).any((l) => l.contains('静かにユニフォームを脱いだ')), isTrue);
      expect(epilogueLines(retired(years: 6, reason: '戦力外通告を受けた')).any((l) => l.contains('最後の試合までコートに立った')), isTrue);
    });

    test('短いプロ生活でも一言あり、プロ経験がなければセレモニーはない', () {
      expect(epilogueLines(retired(years: 2)).any((l) => l.contains('温かい拍手')), isTrue);
      final none = retired(years: 0);
      expect(epilogueLines(none).any((l) => l.contains('セレモニー') || l.contains('温かい拍手')), isFalse);
    });

    test('プロの年数を数える関数と、十年選手の実績', () {
      expect(proYears(retired(years: 11)), 11);
      expect(proYears(retired(years: 0)), 0);
      final ids = achievements.where((a) => a.earned(retired(years: 10))).map((a) => a.id);
      expect(ids, contains('pro_decade'));
      expect(achievements.where((a) => a.earned(retired(years: 9))).map((a) => a.id), isNot(contains('pro_decade')));
    });
  });
}
