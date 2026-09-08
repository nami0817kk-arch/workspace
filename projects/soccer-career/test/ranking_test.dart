/// 自分の位置が分かるか。リーグの格付け・選手の水準・練習の成果。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/ranking.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

CareerController controller({int seed = 5}) => CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(seed)),
      matchEngine: MatchEngine(random: Random(seed)),
      random: Random(seed),
    );

void main() {
  group('リーグの格付け', () {
    test('世界の全リーグが並ぶ', () {
      final leagues = Ranking.leagues();
      var expected = 0;
      for (final country in World.countries) {
        expected += country.tiers;
      }
      expect(leagues.length, expected);
      expect(leagues.every((l) => l.total == expected), isTrue);
    });

    test('強い順に並び、上の部が下の部より上に来る', () {
      final leagues = Ranking.leagues();
      for (var i = 1; i < leagues.length; i++) {
        expect(leagues[i - 1].average,
            greaterThanOrEqualTo(leagues[i].average));
      }
      final first = Ranking.of('yamato', 1);
      final second = Ranking.of('yamato', 2);
      expect(first.rank, lessThan(second.rank));
      expect(first.average, greaterThan(second.average));
    });

    test('平均が同じリーグは同着になる', () {
      // 順位差を付けると、存在しない差を見せることになる。
      final leagues = Ranking.leagues();
      for (final l in leagues) {
        final stronger = leagues.where((o) => o.average > l.average).length;
        expect(l.rank, stronger + 1);
      }
    });

    test('最高峰は S、最下層は D', () {
      final leagues = Ranking.leagues();
      expect(leagues.first.grade, 'S');
      expect(leagues.last.grade, 'D');
      expect(leagues.first.gradeLabel, isNotEmpty);
      expect(leagues.first.name, contains('1部'));
    });

    test('知らないリーグを聞かれても落ちない', () {
      expect(() => Ranking.of('nowhere', 9), returnsNormally);
    });
  });

  group('選手の水準', () {
    test('総合力が上がるほど上の言葉になる', () {
      final low = Ranking.gradeFor(50);
      final mid = Ranking.gradeFor(70);
      final high = Ranking.gradeFor(90);
      expect(low.label, isNot(mid.label));
      expect(mid.label, isNot(high.label));
      expect(low.percentile, lessThan(mid.percentile));
      expect(mid.percentile, lessThan(high.percentile));
      expect(low.starterClubs, lessThan(high.starterClubs));
    });

    test('代表の目安がそのまま「一流」の線になっている', () {
      // ガイドに書いた数字と、実際の招集条件がずれると嘘になる。
      expect(Ranking.gradeFor(Formulas.callUpOverall).label, '一流');
      expect(Ranking.toCallUp(Formulas.callUpOverall), 0);
      expect(Ranking.toCallUp(Formulas.callUpOverall - 5), 5);
    });

    test('主力を張れる一番上のリーグが出る', () {
      final strong = Ranking.gradeFor(90);
      expect(strong.bestLeague, isNotNull);
      expect(strong.bestLeague!.rank, 1);

      final weak = Ranking.gradeFor(10);
      expect(weak.bestLeague, isNull);
    });

    test('クラブとの差で立ち位置が変わる', () {
      const club = Club(
          id: 'x', name: 'X', strength: 70, tier: 1, countryId: 'yamato');
      expect(Ranking.standingIn(85, club), isNot(Ranking.standingIn(70, club)));
      expect(Ranking.standingIn(40, club), isNot(Ranking.standingIn(70, club)));
    });

    test('能力1あたりの成功率が、判定に使う傾きと同じ', () {
      // 画面に出す数字が判定とずれると、そこから先の説明が全部嘘になる。
      final before = MatchInProgress.successChance(60, 60);
      final after = MatchInProgress.successChance(70, 60);
      expect((after - before) * 100,
          closeTo(Ranking.chanceGainPercent(10), 0.001));
    });
  });

  group('練習の成果', () {
    test('開幕時が控えられ、伸びた分が差として出る', () async {
      final c = controller();
      await c.startCareer(
          name: '育つ選手',
          position: Position.st,
          age: 19,
          agent: Agent.pool.first);
      final state = c.state!;
      expect(state.seasonStart, isNotNull);
      expect(state.seasonGrowth.every((g) => g.growth == 0), isTrue,
          reason: '開幕時点で伸びている');

      state.player = state.player.copyWith(
        attributes: state.player.attributes
            .bumpDetail(Detail.finishing, 4),
      );
      final shooting = state.seasonGrowth
          .firstWhere((g) => g.key == AttributeKey.shooting);
      expect(shooting.growth, greaterThan(0));
      expect(shooting.now, greaterThan(shooting.before));
    });

    test('局面の成否が今季ぶんだけ積み上がる', () async {
      final c = controller(seed: 8);
      await c.startCareer(
          name: '積む選手',
          position: Position.st,
          age: 20,
          agent: Agent.pool.first);
      for (var i = 0; i < 10; i++) {
        await c.simulateMatch();
      }
      final growth = c.state!.seasonGrowth;
      final attempts = growth.fold<int>(0, (a, g) => a + g.attempts);
      expect(attempts, greaterThan(0), reason: '局面が1つも記録されていない');
      for (final g in growth) {
        expect(g.successes, lessThanOrEqualTo(g.attempts));
        if (g.attempts == 0) {
          expect(g.successRate, isNull);
        } else {
          expect(g.successRate, inInclusiveRange(0, 1));
        }
      }
    });

    test('シーズンを跨ぐと、開幕時が新しくなり集計が空になる', () async {
      final c = controller(seed: 9);
      await c.startCareer(
          name: '越える選手',
          position: Position.cm,
          age: 20,
          agent: Agent.pool.first);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      final before = c.state!.player.attributes;
      await c.advanceSeason(accepted: c.renewalOffer!);

      final state = c.state!;
      expect(state.momentAttempts, isEmpty);
      expect(state.momentSuccesses, isEmpty);
      expect(state.seasonGrowth.every((g) => g.growth == 0), isTrue);
      // 前季の能力そのものではなく、オフを挟んだ今の能力が起点になる。
      expect(state.seasonStart!.detail(Detail.stamina),
          state.player.attributes.detail(Detail.stamina));
      expect(before, isNotNull);
    });

    test('保存を往復しても残り、古い保存データでも落ちない', () async {
      final c = controller(seed: 12);
      await c.startCareer(
          name: '保存する選手',
          position: Position.st,
          age: 22,
          agent: Agent.pool.first);
      await c.simulateMatch();

      final json = c.state!.toJson();
      final restored = CareerState.fromJson(json);
      expect(restored.seasonStart, isNotNull);
      expect(restored.momentAttempts, c.state!.momentAttempts);
      expect(restored.momentSuccesses, c.state!.momentSuccesses);

      final legacy = CareerState.fromJson(json
        ..remove('seasonStart')
        ..remove('momentAttempts')
        ..remove('momentSuccesses'));
      expect(legacy.seasonStart, isNull);
      expect(legacy.momentAttempts, isEmpty);
      // 記録が無いときは、差を出さずに今の値をそのまま見せる。
      expect(legacy.seasonGrowth.every((g) => g.growth == 0), isTrue);
    });
  });
}
