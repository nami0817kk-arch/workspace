import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/names.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

Attributes attrs({int all = 50, int shooting = 50}) => Attributes(
      pace: all,
      shooting: shooting,
      passing: all,
      dribbling: all,
      defending: all,
      physical: all,
    );

Player playerWith({
  Position position = Position.st,
  int age = 20,
  Attributes? attributes,
}) =>
    Player(
      name: 'テスト選手',
      age: age,
      position: position,
      attributes: attributes ?? attrs(),
      potential: 99,
    );

final agent = Agent.pool.first;

void main() {
  group('Attributes', () {
    test('ポジションで総合力の重みが変わる', () {
      final a = Attributes(
        pace: 50,
        shooting: 90,
        passing: 50,
        dribbling: 50,
        defending: 20,
        physical: 50,
      );
      // シュートが高い選手は FW で最も高く評価される。
      expect(a.overallFor(Position.st),
          greaterThan(a.overallFor(Position.cb)));
      expect(a.overallFor(Position.st),
          greaterThan(a.overallFor(Position.cm)));
    });

    test('bumpDetail は上下限で丸める', () {
      final low = attrs(all: Formulas.minAttribute);
      expect(low.bumpDetail(Detail.acceleration, -5).detail(Detail.acceleration),
          Formulas.minAttribute);

      final high = attrs(all: Formulas.maxAttribute);
      expect(high.bumpDetail(Detail.acceleration, 5).detail(Detail.acceleration),
          Formulas.maxAttribute);
    });

    test('bumpDetail は指定した詳細だけ動かし、カテゴリは平均で追従する', () {
      final bumped = attrs(all: 50).bumpDetail(Detail.finishing, 4);
      expect(bumped.detail(Detail.finishing), 54);
      expect(bumped.detail(Detail.shotPower), 50);
      // シュートは4項目の平均: (54+50+50+50)/4 = 51
      expect(bumped.shooting, 51);
      expect(bumped.pace, 50);
    });

    test('bump はカテゴリの中の詳細を1つだけ動かす', () {
      final bumped = attrs(all: 50).bump(AttributeKey.passing, 2, random: Random(1));
      final moved = AttributeKey.passing.details
          .where((d) => bumped.detail(d) != 50)
          .toList();
      expect(moved.length, 1);
      expect(bumped.detail(moved.first), 52);
    });
  });

  group('successChance', () {
    test('能力が難易度と同じでも五分より低い', () {
      expect(MatchInProgress.successChance(60, 60), lessThan(0.5));
    });

    test('能力が高いほど成功率が上がる', () {
      final low = MatchInProgress.successChance(40, 60);
      final high = MatchInProgress.successChance(80, 60);
      expect(high, greaterThan(low));
    });

    test('極端な差でも 0.05〜0.92 に収まる', () {
      expect(MatchInProgress.successChance(1, 99), greaterThanOrEqualTo(0.05));
      expect(MatchInProgress.successChance(99, 1), lessThanOrEqualTo(0.92));
    });
  });

  group('出場の判断', () {
    MatchResult rated(double rating) => MatchResult(
          matchday: 1,
          opponentName: '相手',
          home: true,
          scored: 1,
          conceded: 1,
          appearance: Appearance.start,
          rating: rating,
          goals: 0,
          assists: 0,
        );

    test('実績が無ければ先発から始まる', () {
      expect(MatchEngine.decideAppearance([]), Appearance.start);
    });

    test('評価が高ければ先発を維持する', () {
      final recent = List.generate(5, (_) => rated(7.0));
      expect(MatchEngine.decideAppearance(recent), Appearance.start);
    });

    test('評価が落ちると途中出場になる', () {
      final recent = List.generate(5, (_) => rated(5.9));
      expect(MatchEngine.decideAppearance(recent), Appearance.sub);
    });

    test('さらに落ちるとベンチ外になる', () {
      final recent = List.generate(5, (_) => rated(5.0));
      expect(MatchEngine.decideAppearance(recent), Appearance.benched);
    });

    test('直近5試合だけを見る（古い不調は引きずらない）', () {
      final recent = [
        ...List.generate(5, (_) => rated(4.5)),
        ...List.generate(5, (_) => rated(7.5)),
      ];
      expect(MatchEngine.decideAppearance(recent), Appearance.start);
    });
  });

  group('MatchInProgress', () {
    MatchInProgress build({int seed = 1, Attributes? attributes}) {
      final engine = MatchEngine(random: Random(seed));
      final league = Names.buildLeague(2);
      return engine.start(
        matchday: 1,
        player: playerWith(attributes: attributes),
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.start,
      );
    }

    test('先発は規定数の局面を持つ', () {
      expect(build().scenarios.length, Formulas.scenariosPerStart);
    });

    test('途中出場は局面が少ない', () {
      final engine = MatchEngine(random: Random(1));
      final league = Names.buildLeague(2);
      final match = engine.start(
        matchday: 1,
        player: playerWith(),
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.sub,
      );
      expect(match.scenarios.length, Formulas.scenariosPerSub);
    });

    test('局面を選ぶと進み、全部消化すると終わる', () {
      final match = build();
      expect(match.isFinished, isFalse);
      while (!match.isFinished) {
        match.choose(match.current.options.first);
      }
      expect(match.isFinished, isTrue);
      expect(match.resolutions.length, Formulas.scenariosPerStart);
    });

    test('能力が極端に高ければゴールが記録される', () {
      final match = build(seed: 7, attributes: attrs(all: 99, shooting: 99));
      while (!match.isFinished) {
        // ゴールに繋がる手を優先して選ぶ。
        final goalOption = match.current.options
            .where((o) => o.outcome == Outcome.goal)
            .toList();
        match.choose(
            goalOption.isEmpty ? match.current.options.first : goalOption.first);
      }
      expect(match.goals + match.assists, greaterThan(0));
      expect(match.rating, greaterThan(Formulas.baseRating));
    });

    test('評価点は上下限に収まる', () {
      final match = build(seed: 3, attributes: attrs(all: 1, shooting: 1));
      while (!match.isFinished) {
        match.choose(match.current.options.first);
      }
      expect(match.rating, greaterThanOrEqualTo(Formulas.minRating));
      expect(match.rating, lessThanOrEqualTo(Formulas.maxRating));
    });

    test('ベンチ外の試合は評価点が付かない', () {
      final engine = MatchEngine(random: Random(1));
      final league = Names.buildLeague(2);
      final match = engine.start(
        matchday: 1,
        player: playerWith(),
        club: league.first,
        opponent: league.last,
        home: true,
        appearance: Appearance.benched,
      );
      expect(match.scenarios, isEmpty);
      expect(match.finish().rating, isNull);
    });

    test('自分の得点は必ずチームの得点に含まれる', () {
      final match = build(seed: 11, attributes: attrs(all: 99, shooting: 99));
      while (!match.isFinished) {
        final goalOption = match.current.options
            .where((o) => o.outcome == Outcome.goal)
            .toList();
        match.choose(
            goalOption.isEmpty ? match.current.options.first : goalOption.first);
      }
      final result = match.finish();
      expect(result.scored, greaterThanOrEqualTo(result.goals));
    });
  });

  group('成長', () {
    test('評価が低い試合では伸びない', () {
      final engine = MatchEngine(random: Random(1));
      final player = playerWith();
      final grown = engine.grow(player, 5.0);
      expect(grown.pace, player.attributes.pace);
      expect(grown.shooting, player.attributes.shooting);
    });

    test('出場しなかった試合では伸びない', () {
      final engine = MatchEngine(random: Random(1));
      final player = playerWith();
      expect(engine.grow(player, null).overallFor(Position.st),
          player.overall);
    });

    test('良い評価を重ねれば伸びる', () {
      final engine = MatchEngine(random: Random(5));
      var player = playerWith(age: 20);
      final before = player.overall;
      for (var i = 0; i < 60; i++) {
        player = player.copyWith(attributes: engine.grow(player, 8.5));
      }
      expect(player.overall, greaterThan(before));
    });

    test('ピークを過ぎた選手は衰える', () {
      final engine = MatchEngine(random: Random(9));
      var player = playerWith(age: Formulas.declineAge + 3);
      final before = player.overall;
      for (var i = 0; i < 80; i++) {
        player = player.copyWith(attributes: engine.grow(player, 6.0));
      }
      expect(player.overall, lessThan(before));
    });
  });

  group('CareerEngine', () {
    test('キャリアは2部のクラブから始まる', () {
      final state = CareerEngine(random: Random(1))
          .startCareer(name: 'A', position: Position.cm, age: 17, agent: agent);
      expect(state.club.tier, 2);
      // クラブ数と試合数は国ごとに違う。
      final country = World.byId(state.club.countryId);
      expect(state.league.length, country.clubsInTier(2));
      expect(state.fixtures.length, (country.clubsInTier(2) - 1) * 2);
      expect(state.results, isEmpty);
    });

    test('日程に自分のクラブは入らない', () {
      final state = CareerEngine(random: Random(2))
          .startCareer(name: 'A', position: Position.st, age: 18, agent: agent);
      expect(state.fixtures.contains(state.club.id), isFalse);
    });

    test('結果を反映すると順位表が全クラブ進む', () {
      final engine = CareerEngine(random: Random(3));
      final state =
          engine.startCareer(name: 'A', position: Position.cb, age: 19, agent: agent);
      engine.applyResult(
        state,
        MatchResult(
          matchday: 1,
          opponentName: state.opponentFor(1).name,
          home: true,
          scored: 2,
          conceded: 1,
          appearance: Appearance.start,
          rating: 7.0,
          goals: 1,
          assists: 0,
        ),
      );
      expect(state.results.length, 1);
      for (final row in state.table) {
        expect(row.played, 1, reason: '${row.clubName} が消化していない');
      }
      final mine = state.table.firstWhere((r) => r.clubId == state.club.id);
      expect(mine.points, Formulas.pointsWin);
    });

    test('成績が振るわないと移籍のオファーは来ない', () {
      final engine = CareerEngine(random: Random(4));
      final state =
          engine.startCareer(name: 'A', position: Position.st, age: 20, agent: agent);
      // 出番の無い若手にローンの話が来るのは別（試合に出るための移籍）。
      expect(engine.offersFor(state).where((o) => !o.loan), isEmpty);
    });

    test('シーズンを進めると年齢と年が上がり、記録が残る', () {
      final engine = CareerEngine(random: Random(6));
      final state =
          engine.startCareer(name: 'A', position: Position.cm, age: 18, agent: agent);
      final next = engine.advanceSeason(state, accepted: engine.renewalOffer(state));
      expect(next.year, state.year + 1);
      expect(next.player.age, state.player.age + 1);
      expect(next.history.length, 1);
      expect(next.results, isEmpty);
      expect(next.fixtures.length, Formulas.matchesPerSeason);
    });
  });

  group('保存', () {
    test('JSON を往復しても状態が保たれる', () {
      final engine = CareerEngine(random: Random(8));
      final state =
          engine.startCareer(name: '往復テスト', position: Position.cb, age: 17, agent: agent);
      engine.applyResult(
        state,
        MatchResult(
          matchday: 1,
          opponentName: state.opponentFor(1).name,
          home: false,
          scored: 0,
          conceded: 3,
          appearance: Appearance.sub,
          rating: 5.2,
          goals: 0,
          assists: 0,
        ),
      );

      final restored = CareerState.fromJson(state.toJson());
      expect(restored.player.name, state.player.name);
      expect(restored.player.position, state.player.position);
      expect(restored.club.id, state.club.id);
      expect(restored.year, state.year);
      expect(restored.fixtures, state.fixtures);
      expect(restored.results.length, 1);
      expect(restored.results.first.rating, 5.2);
      expect(restored.table.length, state.table.length);
      expect(restored.leaguePosition, state.leaguePosition);
    });
  });

  group('SeasonStats', () {
    test('出場しなかった試合は平均に含めない', () {
      final results = [
        MatchResult(
          matchday: 1,
          opponentName: 'X',
          home: true,
          scored: 1,
          conceded: 0,
          appearance: Appearance.start,
          rating: 8.0,
          goals: 1,
          assists: 0,
        ),
        MatchResult(
          matchday: 2,
          opponentName: 'Y',
          home: false,
          scored: 0,
          conceded: 2,
          appearance: Appearance.benched,
          rating: null,
          goals: 0,
          assists: 0,
        ),
      ];
      final stats = SeasonStats.from(results);
      expect(stats.appearances, 1);
      expect(stats.averageRating, 8.0);
      expect(stats.goals, 1);
    });

    test('1試合も出ていなければ 0 を返す', () {
      expect(SeasonStats.from(const []).appearances, 0);
      expect(SeasonStats.from(const []).averageRating, 0);
    });
  });

  group('リーグ', () {
    test('1部と2部でクラブ名が重複しない', () {
      final first = Names.buildLeague(1).map((c) => c.name).toSet();
      final second = Names.buildLeague(2).map((c) => c.name).toSet();
      expect(first.intersection(second), isEmpty);
    });

    test('全ての国で、全ての部のクラブ名が重複しない', () {
      for (final country in World.countries) {
        final all = <String>[];
        for (var tier = 1; tier <= country.tiers; tier++) {
          all.addAll(World.buildLeague(country.id, tier).map((c) => c.name));
        }
        expect(all.toSet().length, all.length, reason: country.name);
      }
    });

    test('1部の方が平均的に強い', () {
      double avg(int tier) {
        final clubs = Names.buildLeague(tier);
        return clubs.fold<int>(0, (s, c) => s + c.strength) / clubs.length;
      }

      expect(avg(1), greaterThan(avg(2)));
    });
  });

  group('局面データ', () {
    test('全ポジションに局面がある', () {
      for (final position in Position.values) {
        expect(ScenarioPool.forPosition(position), isNotEmpty);
      }
    });

    test('どの局面も選択肢が3つある', () {
      for (final position in Position.values) {
        for (final scenario in ScenarioPool.forPosition(position)) {
          expect(scenario.options.length, 3, reason: scenario.id);
        }
      }
    });

    test('局面IDが重複していない（ファミリー単位。複数ポジションが同じ局面を共有する）', () {
      final ids = [
        for (final family in ScenarioFamily.values)
          ...ScenarioPool.forFamily(family).map((s) => s.id),
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('得点に直結する手ほど難易度が高い', () {
      for (final position in Position.values) {
        for (final scenario in ScenarioPool.forPosition(position)) {
          final goals =
              scenario.options.where((o) => o.outcome == Outcome.goal);
          final plays =
              scenario.options.where((o) => o.outcome == Outcome.play);
          if (goals.isEmpty || plays.isEmpty) continue;
          final easiestGoal =
              goals.map((o) => o.difficulty).reduce((a, b) => a < b ? a : b);
          final easiestPlay =
              plays.map((o) => o.difficulty).reduce((a, b) => a < b ? a : b);
          expect(easiestGoal, greaterThan(easiestPlay), reason: scenario.id);
        }
      }
    });
  });
}
