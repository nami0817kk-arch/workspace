import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/career_engine_extras.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/names.dart';
import 'package:soccer_career/game/national.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/injury.dart';
import 'package:soccer_career/models/objective.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

final flat = Attributes(
  pace: 50,
  shooting: 50,
  passing: 50,
  dribbling: 50,
  defending: 50,
  physical: 50,
  goalkeeping: 50,
);

Player player({
  int age = 22,
  int condition = 100,
  int potential = 99,
  Position position = Position.cm,
  Attributes? attributes,
}) =>
    Player(
      name: 'P',
      age: age,
      position: position,
      attributes: attributes ?? flat,
      potential: potential,
      condition: condition,
    );

MatchResult league(double rating, {int goals = 0, int matchday = 1}) =>
    MatchResult(
      matchday: matchday,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: rating,
      goals: goals,
      assists: 0,
    );

CareerState freshCareer({int seed = 1, Position position = Position.st}) =>
    CareerEngine(random: Random(seed)).startCareer(
      name: 'T',
      position: position,
      age: 20,
      agent: Agent.pool.first,
    );

void main() {
  group('負傷', () {
    test('コンディションが低いほど起きやすい', () {
      int count(int condition) {
        var injured = 0;
        for (var seed = 0; seed < 400; seed++) {
          final engine = MatchEngine(random: Random(seed));
          if (engine.rollInjury(player(condition: condition),
                  baseChance: Formulas.injuryBaseChance) !=
              null) {
            injured++;
          }
        }
        return injured;
      }

      expect(count(10), greaterThan(count(100)));
    });

    test('歳を取るほど起きやすい', () {
      int count(int age) {
        var injured = 0;
        for (var seed = 0; seed < 400; seed++) {
          final engine = MatchEngine(random: Random(seed));
          if (engine.rollInjury(player(age: age),
                  baseChance: Formulas.injuryBaseChance) !=
              null) {
            injured++;
          }
        }
        return injured;
      }

      expect(count(35), greaterThan(count(20)));
    });

    test('離脱試合数は種類の範囲に収まる', () {
      for (var seed = 0; seed < 300; seed++) {
        final engine = MatchEngine(random: Random(seed));
        final injury = engine.rollInjury(player(condition: 10),
            baseChance: Formulas.injuryBaseChance);
        if (injury == null) continue;
        final kind = InjuryKind.all.firstWhere((k) => k.name == injury.name);
        expect(injury.matchesOut, inInclusiveRange(kind.minMatches, kind.maxMatches));
        expect(injury.severity, kind.severity);
      }
    });

    test('tick で減り、0 で治る', () {
      const injury = Injury(
          name: '打撲', severity: InjurySeverity.light, matchesOut: 2);
      final once = injury.tick();
      expect(once.matchesOut, 1);
      expect(once.healed, isFalse);
      expect(once.tick().healed, isTrue);
    });

    test('重傷は能力とポテンシャルを削る。軽傷は削らない', () {
      final engine = MatchEngine(random: Random(1));
      final p = player(potential: 90);

      const severe = Injury(
          name: '膝の靭帯損傷',
          severity: InjurySeverity.severe,
          matchesOut: 15);
      final (attrs, potential) = engine.applySevereInjury(p, severe);
      expect(potential, 90 - Formulas.severeInjuryPotentialLoss);
      // スピードの詳細のどれかが削られている。
      final lost = AttributeKey.pace.details
          .map((d) => 50 - attrs.detail(d))
          .reduce(max);
      expect(lost, Formulas.severeInjuryAttributeLoss);

      const light = Injury(
          name: '打撲', severity: InjurySeverity.light, matchesOut: 1);
      final (sameAttrs, samePotential) = engine.applySevereInjury(p, light);
      expect(samePotential, 90);
      expect(sameAttrs.physical, flat.physical);
    });

    test('休養の週には練習中の負傷が起きない', () {
      final engine = MatchEngine(random: Random(2));
      for (var i = 0; i < 200; i++) {
        final week = engine.applyWeek(player(condition: 5),
            training: null, played: true);
        expect(week.injury, isNull);
      }
    });

    test('保存を往復しても負傷が残る', () {
      final s = freshCareer();
      s.injury = const Injury(
          name: '疲労骨折', severity: InjurySeverity.moderate, matchesOut: 7);
      final restored = CareerState.fromJson(s.toJson());
      expect(restored.injured, isTrue);
      expect(restored.injury!.name, '疲労骨折');
      expect(restored.injury!.matchesOut, 7);
      expect(restored.injury!.severity, InjurySeverity.moderate);
    });

    test('離脱中の試合は局面が無く、評価点も付かない', () {
      final league = Names.buildLeague(2);
      final match = MatchEngine(random: Random(3)).start(
        matchday: 1,
        player: player(),
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.injured,
      );
      expect(match.scenarios, isEmpty);
      final result = match.finish();
      expect(result.appearance, Appearance.injured);
      expect(result.rating, isNull);
    });

    test('負傷離脱の試合は平均評価に含まれない', () {
      final stats = SeasonStats.from([
        league(8.0),
        MatchResult(
          matchday: 2,
          opponentName: 'Y',
          home: false,
          scored: 0,
          conceded: 1,
          appearance: Appearance.injured,
          rating: null,
          goals: 0,
          assists: 0,
        ),
      ]);
      expect(stats.appearances, 1);
      expect(stats.averageRating, 8.0);
    });
  });

  group('代表', () {
    final extras = CareerExtras(random: Random(4));

    test('実力が足りないと招集されない', () {
      final s = freshCareer();
      for (var i = 0; i < 10; i++) {
        s.results.add(league(9.0, matchday: i + 1));
      }
      // 初期能力では総合力が足りない。
      expect(s.player.overall, lessThan(Formulas.callUpOverall));
      expect(extras.shouldCallUp(s), isFalse);
    });

    test('実力があっても出場実績が無ければ招集されない', () {
      final s = freshCareer();
      s.player = Player.rebuild(
        s.player,
        attributes: Attributes(
            pace: 85, shooting: 85, passing: 85, dribbling: 85,
            defending: 85, physical: 85),
        potential: 99,
      );
      expect(extras.shouldCallUp(s), isFalse);
    });

    test('実力と直近の出来がそろえば招集される', () {
      final s = freshCareer();
      s.player = Player.rebuild(
        s.player,
        attributes: Attributes(
            pace: 85, shooting: 85, passing: 85, dribbling: 85,
            defending: 85, physical: 85),
        potential: 99,
      );
      for (var i = 0; i < 8; i++) {
        s.results.add(league(7.5, matchday: i + 1));
      }
      expect(extras.shouldCallUp(s), isTrue);
    });

    test('代表ウィークは決まった節のあとに来る', () {
      for (final matchday in National.breakAfterMatchday) {
        expect(extras.isBreakAfter(matchday), isTrue);
      }
      expect(extras.isBreakAfter(1), isFalse);
    });

    test('代表戦はリーグの節に数えず、キャップとゴールだけ増える', () {
      final engine = CareerEngine(random: Random(5));
      final s = freshCareer();
      final beforeMatchday = s.matchday;

      engine.applyResult(
        s,
        MatchResult(
          matchday: 1,
          opponentName: 'アルヴェニア代表',
          home: true,
          scored: 2,
          conceded: 1,
          appearance: Appearance.start,
          rating: 7.5,
          goals: 1,
          assists: 0,
          international: true,
        ),
      );

      expect(s.matchday, beforeMatchday, reason: '節は進まない');
      expect(s.caps, 1);
      expect(s.internationalGoals, 1);
      expect(s.seasonCaps, 1);
      // 順位表は動かない。
      expect(s.table.every((r) => r.played == 0), isTrue);
      // 監督の目標はリーグ戦だけで見る。
      expect(s.seasonStats.appearances, 0);
    });

    test('キャップは保存を往復しても残る', () {
      final s = freshCareer();
      s.caps = 12;
      s.internationalGoals = 4;
      s.calledUp = true;
      s.pendingInternational = true;
      final r = CareerState.fromJson(s.toJson());
      expect(r.caps, 12);
      expect(r.internationalGoals, 4);
      expect(r.calledUp, isTrue);
      expect(r.pendingInternational, isTrue);
    });
  });

  group('監督の目標', () {
    final extras = CareerExtras(random: Random(6));

    test('3つのうち2つ達成で達成扱い', () {
      const objective =
          SeasonObjective(appearances: 20, contributions: 10, rating: 6.5);
      const met = SeasonStats(
          appearances: 25, goals: 8, assists: 4, averageRating: 6.2);
      expect(objective.achievedCount(met), 2);
      expect(objective.achieved(met), isTrue);

      const missed = SeasonStats(
          appearances: 10, goals: 2, assists: 1, averageRating: 6.6);
      expect(objective.achievedCount(missed), 1);
      expect(objective.achieved(missed), isFalse);
    });

    test('格上のクラブでは出場目標が下がる', () {
      final weak = extras.objectiveFor(
        player: player(attributes: flat),
        club: const Club(id: 'a', name: 'A', strength: 40, tier: 2),
      );
      final strong = extras.objectiveFor(
        player: player(attributes: flat),
        club: const Club(id: 'b', name: 'B', strength: 80, tier: 1),
      );
      expect(strong.appearances, lessThan(weak.appearances));
    });

    test('攻撃のポジションほど得点関与を求められる', () {
      const club = Club(id: 'a', name: 'A', strength: 55, tier: 2);
      final striker =
          extras.objectiveFor(player: player(position: Position.st), club: club);
      final back =
          extras.objectiveFor(player: player(position: Position.cb), club: club);
      expect(striker.contributions, greaterThan(back.contributions));
    });

    test('達成すると契約更改の年俸が上がる', () {
      int salaryAfter({required bool achieve}) {
        final engine = CareerEngine(random: Random(7));
        final s = engine.startCareer(
            name: 'S', position: Position.st, age: 24, agent: Agent.pool.first);
        s.objective =
            const SeasonObjective(appearances: 5, contributions: 2, rating: 6.0);
        for (var i = 0; i < 20; i++) {
          s.results.add(league(achieve ? 7.2 : 7.2,
              goals: achieve ? 1 : 0, matchday: i + 1));
        }
        if (!achieve) {
          s.objective = const SeasonObjective(
              appearances: 99, contributions: 99, rating: 9.9);
        }
        return engine.renewalOffer(s).salary;
      }

      expect(salaryAfter(achieve: true), greaterThan(salaryAfter(achieve: false)));
    });

    test('目標は保存を往復しても残り、シーズンを進めると作り直される', () {
      final engine = CareerEngine(random: Random(8));
      final s = freshCareer(seed: 8);
      expect(s.objective, isNotNull);
      final r = CareerState.fromJson(s.toJson());
      expect(r.objective!.appearances, s.objective!.appearances);

      final next = engine.advanceSeason(s, accepted: engine.renewalOffer(s));
      expect(next.objective, isNotNull);
    });
  });

  group('契約年数', () {
    test('開始時の契約は規定の範囲に収まる', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = freshCareer(seed: seed);
        expect(s.contractYears,
            inInclusiveRange(Formulas.contractYearsMin, Formulas.contractYearsMax));
      }
    });

    test('契約が残っているとオファーは来ない', () {
      final engine = CareerEngine(random: Random(9));
      final s = freshCareer(seed: 9);
      s.contractYears = 3;
      for (var i = 0; i < 20; i++) {
        s.results.add(league(8.5, goals: 1, matchday: i + 1));
      }
      expect(engine.offersFor(s), isEmpty);

      s.contractYears = 1;
      expect(engine.offersFor(s), isNotEmpty);
    });

    test('契約更改を受けると年数が戻る', () {
      final engine = CareerEngine(random: Random(10));
      final s = freshCareer(seed: 10);
      s.contractYears = 1;
      final renewal = engine.renewalOffer(s);
      final next = engine.advanceSeason(s, accepted: renewal);
      expect(next.contractYears, renewal.years);
      expect(next.contractYears, greaterThan(1));
    });

    test('オファーには契約年数が付く', () {
      final engine = CareerEngine(random: Random(11));
      final s = freshCareer(seed: 11);
      expect(engine.renewalOffer(s).years,
          inInclusiveRange(Formulas.contractYearsMin, Formulas.contractYearsMax));
    });

    test('契約年数は保存を往復しても残る', () {
      final s = freshCareer(seed: 12);
      s.contractYears = 4;
      expect(CareerState.fromJson(s.toJson()).contractYears, 4);
    });
  });

  group('シーズン記録', () {
    test('代表数と目標達成が記録に残る', () {
      final engine = CareerEngine(random: Random(13));
      final s = freshCareer(seed: 13);
      s.objective =
          const SeasonObjective(appearances: 1, contributions: 0, rating: 0);
      s.results.add(league(7.0));
      s.results.add(MatchResult(
        matchday: 1,
        opponentName: '代表相手',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: 7.0,
        goals: 0,
        assists: 0,
        international: true,
      ));

      final next = engine.advanceSeason(s, accepted: engine.renewalOffer(s));
      expect(next.history.last.caps, 1);
      expect(next.history.last.objectiveMet, isTrue);
    });
  });
}
