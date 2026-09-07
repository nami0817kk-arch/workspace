import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/names.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

/// 指定した順位になるように順位表を作った状態を返す。
CareerState stateAt({required int tier, required int position}) {
  final league = Names.buildLeague(tier);
  final club = league[5];
  final table = <TableRow>[];
  var slot = 0;
  for (final c in league) {
    final row = TableRow(clubId: c.id, clubName: c.name);
    // 自分は position 番目、他は上から詰める。
    final rank = c.id == club.id ? position : (++slot >= position ? slot + 1 : slot);
    row.won = 40 - rank; // 順位が上ほど勝点が多い
    table.add(row);
  }
  return CareerState(
    player: Player(
      name: 'T',
      age: 25,
      position: Position.cm,
      attributes: const Attributes(
          pace: 60, shooting: 60, passing: 60, dribbling: 60, defending: 60, physical: 60),
      potential: 99,
    ),
    club: club,
    league: league,
    year: 2030,
    fixtures: [for (var i = 0; i < 38; i++) league[(i % 19) + (i % 19 >= 5 ? 1 : 0)].id],
    results: [],
    table: table,
    history: [],
    agent: Agent.pool.first,
    salary: 300,
    contractYears: 1,
  );
}

MatchResult played(double rating, {int goals = 0}) => MatchResult(
      matchday: 1,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: rating,
      goals: goals,
      assists: 0,
    );

void main() {
  group('昇格・降格', () {
    final engine = CareerEngine(random: Random(1));

    test('2部で上位なら昇格', () {
      final s = stateAt(tier: 2, position: Formulas.promotionPlaces);
      expect(s.leaguePosition, Formulas.promotionPlaces);
      expect(engine.fateOf(s), ClubFate.promoted);
    });

    test('2部で3位なら残留', () {
      final s = stateAt(tier: 2, position: Formulas.promotionPlaces + 1);
      expect(engine.fateOf(s), ClubFate.stay);
    });

    test('1部で下位なら降格', () {
      final s = stateAt(tier: 1, position: Formulas.relegationFrom);
      expect(engine.fateOf(s), ClubFate.relegated);
    });

    test('1部で中位なら残留', () {
      final s = stateAt(tier: 1, position: 10);
      expect(engine.fateOf(s), ClubFate.stay);
    });

    test('昇格すると1部リーグに自分のクラブが入り、20クラブが保たれる', () {
      final s = stateAt(tier: 2, position: 1);
      final next = engine.advanceSeason(s, accepted: engine.renewalOffer(s));
      expect(next.club.tier, 1);
      expect(next.club.name, s.club.name);
      expect(next.league.length, Formulas.clubsPerLeague);
      expect(next.league.where((c) => c.name == s.club.name).length, 1);
      expect(next.league.every((c) => c.tier == 1), isTrue);
      expect(next.fixtures.contains(next.club.id), isFalse);
    });

    test('降格すると2部リーグへ移る', () {
      final s = stateAt(tier: 1, position: 20);
      final next = engine.advanceSeason(s, accepted: engine.renewalOffer(s));
      expect(next.club.tier, 2);
      expect(next.league.every((c) => c.tier == 2), isTrue);
      expect(next.league.where((c) => c.name == s.club.name).length, 1);
    });

    test('移籍を選べば昇降格より移籍先が優先される', () {
      final s = stateAt(tier: 2, position: 1);
      final target = Names.buildLeague(2).last;
      final next = engine.advanceSeason(
        s,
        accepted: TransferOffer(
          club: target, reason: '', salary: 500, role: '主力', years: 3),
      );
      expect(next.club.name, target.name);
      expect(next.club.tier, 2);
    });
  });

  group('引退', () {
    final engine = CareerEngine(random: Random(2));

    test('若いうちは引退を選べない', () {
      final s = stateAt(tier: 2, position: 10);
      expect(engine.canRetire(s), isFalse);
      expect(engine.mustRetire(s), isFalse);
    });

    test('一定年齢で引退を選べ、上限で強制になる', () {
      final s = stateAt(tier: 2, position: 10);
      s.player = s.player.copyWith(age: Formulas.retirementOptionalAge);
      expect(engine.canRetire(s), isTrue);
      expect(engine.mustRetire(s), isFalse);

      s.player = s.player.copyWith(age: Formulas.retirementForcedAge);
      expect(engine.mustRetire(s), isTrue);
    });

    test('引退すると記録が残り、試合ができなくなる', () {
      final s = stateAt(tier: 2, position: 10);
      s.results.add(played(7.0, goals: 2));
      final retired = engine.retire(s);
      expect(retired.retired, isTrue);
      expect(retired.history.length, 1);
      expect(retired.history.first.stats.goals, 2);
      expect(retired.results, isEmpty);
    });

    test('引退フラグは保存を往復しても残る', () {
      final s = stateAt(tier: 2, position: 10);
      final retired = engine.retire(s);
      final restored = CareerState.fromJson(retired.toJson());
      expect(restored.retired, isTrue);
    });

    test('古い保存データ（フラグ無し）は現役として読む', () {
      final s = stateAt(tier: 2, position: 10);
      final json = s.toJson()..remove('retired');
      expect(CareerState.fromJson(json).retired, isFalse);
    });
  });

  group('通算成績', () {
    test('過去シーズンと今シーズンを合算し、平均は出場数で重み付けする', () {
      final s = stateAt(tier: 2, position: 10);
      s.history.add(SeasonRecord(
        year: 2029,
        clubName: 'A',
        tier: 2,
        leaguePosition: 5,
        stats: const SeasonStats(
            appearances: 10, goals: 4, assists: 1, averageRating: 7.0),
      ));
      s.results.addAll([played(6.0, goals: 1), played(6.0)]);

      final totals = s.careerTotals;
      expect(totals.appearances, 12);
      expect(totals.goals, 5);
      expect(totals.assists, 1);
      // (7.0*10 + 6.0*2) / 12
      expect(totals.averageRating, closeTo(6.833, 0.001));
    });

    test('1試合も無ければ 0', () {
      final s = stateAt(tier: 2, position: 10);
      expect(s.careerTotals.appearances, 0);
      expect(s.careerTotals.averageRating, 0);
    });
  });

  group('成長の偏り', () {
    test('成功した手の能力が、他より伸びやすい', () {
      final engine = MatchEngine(random: Random(3));
      var player = Player(
        name: 'G',
        age: 20,
        position: Position.cm,
        attributes: const Attributes(
            pace: 50, shooting: 50, passing: 50, dribbling: 50, defending: 50, physical: 50),
        potential: 99,
      );
      for (var i = 0; i < 300; i++) {
        player = player.copyWith(
          attributes: engine.grow(player, 8.0, used: const [AttributeKey.passing]),
        );
      }
      final a = player.attributes;
      final others = [a.pace, a.shooting, a.dribbling, a.defending, a.physical];
      final maxOther = others.reduce(max);
      expect(a.passing, greaterThan(maxOther));
    });

    test('使った能力が無ければ無作為に伸びる（何も伸びないわけではない）', () {
      final engine = MatchEngine(random: Random(4));
      var player = Player(
        name: 'G',
        age: 20,
        position: Position.cm,
        attributes: const Attributes(
            pace: 50, shooting: 50, passing: 50, dribbling: 50, defending: 50, physical: 50),
        potential: 99,
      );
      final before = player.overall;
      for (var i = 0; i < 100; i++) {
        player = player.copyWith(attributes: engine.grow(player, 8.0));
      }
      expect(player.overall, greaterThan(before));
    });
  });

  group('試合の時間', () {
    final league = Names.buildLeague(2);
    final player = Player(
      name: 'M',
      age: 20,
      position: Position.st,
      attributes: const Attributes(
          pace: 50, shooting: 50, passing: 50, dribbling: 50, defending: 50, physical: 50),
      potential: 99,
    );

    test('局面と同じ数の時間が、昇順で 1〜90 分に収まる', () {
      final match = MatchEngine(random: Random(5)).start(
        matchday: 1,
        player: player,
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.start,
      );
      expect(match.minutes.length, match.scenarios.length);
      for (var i = 1; i < match.minutes.length; i++) {
        expect(match.minutes[i], greaterThan(match.minutes[i - 1]));
      }
      expect(match.minutes.first, greaterThanOrEqualTo(1));
      expect(match.minutes.last, lessThanOrEqualTo(90));
    });

    test('途中出場の局面は後半にしか無い', () {
      final match = MatchEngine(random: Random(6)).start(
        matchday: 1,
        player: player,
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.sub,
      );
      expect(match.minutes.every((m) => m > 45), isTrue);
    });

    test('表示は前半・後半で分ける', () {
      expect(MatchInProgress.minuteLabel(12), '前半 12分');
      expect(MatchInProgress.minuteLabel(45), '前半 45分');
      expect(MatchInProgress.minuteLabel(46), '後半 1分');
      expect(MatchInProgress.minuteLabel(90), '後半 45分');
    });

    test('成功した手の能力だけが successfulKeys に入る', () {
      final match = MatchEngine(random: Random(7)).start(
        matchday: 1,
        player: player,
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.start,
      );
      while (!match.isFinished) {
        match.choose(match.current.options.first);
      }
      final successes = match.resolutions.where((r) => r.success).length;
      expect(match.successfulKeys.length, successes);
    });
  });

  group('局面プールの量', () {
    test('各ポジションに 7 局面以上あり、1試合で同じ局面が重複しない', () {
      for (final position in Position.values) {
        final pool = ScenarioPool.forPosition(position);
        expect(pool.length, greaterThanOrEqualTo(7), reason: position.label);
      }
      final match = MatchEngine(random: Random(8)).start(
        matchday: 1,
        player: Player(
          name: 'P',
          age: 20,
          position: Position.cb,
          attributes: const Attributes(
              pace: 50, shooting: 50, passing: 50, dribbling: 50, defending: 50, physical: 50),
          potential: 99,
        ),
        club: Names.buildLeague(2).first,
        opponent: Names.buildLeague(2).last,
        home: true,
        appearance: Appearance.start,
      );
      final ids = match.scenarios.map((s) => s.id).toSet();
      expect(ids.length, match.scenarios.length);
    });
  });

  group('移籍オファー', () {
    test('同名のクラブ（今の所属）はオファー元にならない', () {
      final engine = CareerEngine(random: Random(9));
      final s = stateAt(tier: 2, position: 1);
      for (var i = 0; i < 12; i++) {
        s.results.add(played(8.0, goals: 1));
      }
      final offers = engine.offersFor(s);
      expect(offers.every((o) => o.club.name != s.club.name), isTrue);
    });
  });
}
