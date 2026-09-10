/// 世の中の反応。見出し・その試合の意味・得点ランキング。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/newsroom.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/news.dart';
import 'package:soccer_career/models/season.dart';
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

Future<CareerController> started({int seed = 3}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '主人公', position: Position.st, age: 20, agent: Agent.pool.first);
  return c;
}

CareerState career({int seed = 3, Position position = Position.st}) =>
    CareerEngine(random: Random(seed)).startCareer(
        name: '主人公', position: position, age: 20, agent: Agent.pool.first);

MatchResult result({
  int matchday = 5,
  int goals = 0,
  double? rating = 6.5,
  int scored = 1,
  int conceded = 1,
  String opponent = 'X',
  Appearance appearance = Appearance.start,
  bool international = false,
}) =>
    MatchResult(
      matchday: matchday,
      opponentName: opponent,
      home: true,
      scored: scored,
      conceded: conceded,
      appearance: appearance,
      rating: rating,
      goals: goals,
      assists: 0,
      international: international,
    );

void main() {
  group('同じ見出しを並べない', () {
    test('1シーズン回して、見出しが重複しない', () async {
      // 節番号だけで言い回しを選んでいた頃は4節ごとに同じ文が回ってきて、
      // 記録タブに「◯◯に称賛の声」が並んでいた（13本中7本が重複）。
      final c = await started(seed: 21);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      final headlines = c.state!.news.map((n) => n.headline).toList();
      expect(headlines.length, greaterThan(5), reason: '見出しが少なすぎる');
      // 同じ言い回しが並ばないこと。
      // 「◯◯が2ゴール」のような**事実そのもの**の見出しは、
      // 同じ出来事が起きれば同じ文になるのが正しいので、ここでは見ない。
      final stylistic = headlines.where((h) =>
          !h.contains('ゴール') &&
          !h.contains('決勝点') &&
          !h.contains('完封') &&
          !h.contains('デビュー') &&
          !h.contains('キャップ') &&
          !h.contains('試合'));
      expect(stylistic.toSet().length, stylistic.length,
          reason: '同じ言い回しが並んでいる: '
              '${stylistic.where((h) => stylistic.where((x) => x == h).length > 1).toSet()}');
    });

    test('言い回しが尽きたら、節で選んだものに戻る（落ちない）', () async {
      final c = await started(seed: 22);
      // 何季も回して、言い回しの数を超える見出しを出させる。
      for (var season = 0; season < 3; season++) {
        while (!c.state!.seasonFinished) {
          await c.simulateMatch();
        }
        await c.finishSeason();
        final offer = c.renewalOffer;
        if (offer == null) break;
        await c.advanceSeason(accepted: offer);
      }
      expect(c.state!.news, isNotEmpty);
    });

    test('同じ状態からは、同じ見出しが出る（乱数を持たない）', () async {
      Future<List<String>> run() async {
        final c = await started(seed: 23);
        for (var i = 0; i < 12; i++) {
          await c.simulateMatch();
        }
        return c.state!.news.map((n) => n.headline).toList();
      }

      expect(await run(), await run());
    });
  });

  group('見出し', () {
    test('目立ったことだけが記事になる', () {
      final state = career();
      state.results.add(result());
      // ごく普通の試合では、何も書かれない（節目を除く）。
      final quiet = Newsroom.afterMatch(state, result(matchday: 9));
      expect(quiet.where((n) => n.kind == NewsKind.match), isEmpty);

      final hattrick =
          Newsroom.afterMatch(state, result(matchday: 9, goals: 3, scored: 3));
      expect(hattrick.first.headline, contains('ハットトリック'));
    });

    test('デビューと初ゴールは、その節に載る', () {
      final state = career();
      final debut = result(matchday: 1);
      state.results.add(debut);
      final news = Newsroom.afterMatch(state, debut);
      final milestone =
          news.firstWhere((n) => n.kind == NewsKind.milestone);
      expect(milestone.headline, contains('プロデビュー'));
      // 節を跨いで報じない。
      expect(milestone.matchday, 1);

      final scored = result(matchday: 2, goals: 1, scored: 2);
      state.results.add(scored);
      final second = Newsroom.afterMatch(state, scored);
      expect(second.any((n) => n.headline.contains('初ゴール')), isTrue);
    });

    test('同じ言い回しが並ばない', () {
      final state = career();
      state.results.add(result());
      final headlines = {
        for (final day in [3, 4, 5, 6])
          Newsroom.afterMatch(state, result(matchday: day, rating: 4.9))
              .first
              .headline,
      };
      expect(headlines.length, greaterThan(1));
    });

    test('古巣との対戦は特別に書かれる', () {
      final state = career();
      state.history.add(SeasonRecord(
        year: state.year - 1,
        clubName: '古巣クラブ',
        tier: 2,
        leaguePosition: 5,
        stats: const SeasonStats(
            appearances: 30, goals: 10, assists: 5, averageRating: 7.0),
      ));
      state.results.add(result());
      final news = Newsroom.afterMatch(
          state, result(matchday: 8, goals: 1, opponent: '古巣クラブ', scored: 2));
      expect(news.first.headline, contains('古巣'));
    });

    test('保存を往復しても残る', () {
      final state = career();
      state.news = [
        const NewsItem(
          year: 2026,
          matchday: 12,
          kind: NewsKind.milestone,
          headline: '見出し',
          body: '本文',
        ),
      ];
      final restored = CareerState.fromJson(state.toJson());
      expect(restored.news.single.headline, '見出し');
      expect(restored.news.single.kind, NewsKind.milestone);

      final legacy = CareerState.fromJson(state.toJson()..remove('news'));
      expect(legacy.news, isEmpty);
    });
  });

  group('その試合の意味', () {
    test('かつて在籍したクラブとの対戦が分かる', () {
      final state = career();
      final opponent = state.opponentFor(state.matchday);
      state.history.add(SeasonRecord(
        year: state.year - 1,
        clubName: opponent.name,
        tier: 2,
        leaguePosition: 5,
        stats: const SeasonStats(
            appearances: 20, goals: 3, assists: 1, averageRating: 6.8),
      ));
      expect(Newsroom.stakeFor(state), FixtureStake.formerClub);
    });

    test('シーズンが始まったばかりの頃は順位の意味を出さない', () {
      final state = career();
      final stake = Newsroom.stakeFor(state);
      expect(
        stake == FixtureStake.titleRace || stake == FixtureStake.survival,
        isFalse,
      );
    });

    test('普通の試合には何も付かない', () {
      expect(FixtureStake.none.isSpecial, isFalse);
      expect(FixtureStake.derby.isSpecial, isTrue);
      expect(FixtureStake.derby.description, isNotEmpty);
    });
  });

  group('得点ランキング', () {
    test('自分が必ず載り、節が進むと積み上がる', () async {
      final controller = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(6)),
        matchEngine: MatchEngine(random: Random(6)),
        random: Random(6),
      );
      await controller.startCareer(
        name: '得点者',
        position: Position.st,
        age: 22,
        agent: Agent.pool.first,
      );

      final opening = ScorerRace.table(controller.state!);
      expect(opening.any((s) => s.isPlayer), isTrue);
      expect(opening.every((s) => s.goals == 0), isTrue,
          reason: '開幕前から得点がある');

      for (var i = 0; i < 20; i++) {
        await controller.simulateMatch();
      }
      final mid = ScorerRace.table(controller.state!);
      expect(mid.first.goals, greaterThan(0));
      // 上から順に並んでいる。
      for (var i = 1; i < mid.length - 1; i++) {
        expect(mid[i - 1].goals, greaterThanOrEqualTo(mid[i].goals));
      }
      expect(ScorerRace.rankOf(controller.state!), greaterThan(0));
    });

    test('同じ状況なら毎回同じ顔ぶれになる', () {
      final state = career();
      final first = ScorerRace.table(state);
      final second = ScorerRace.table(state);
      expect(first.map((s) => s.name).toList(),
          second.map((s) => s.name).toList());
      expect(first.map((s) => s.goals).toList(),
          second.map((s) => s.goals).toList());
    });
  });

  group('1シーズン通して', () {
    test('見出しが積み上がり、多すぎない', () async {
      final controller = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(4)),
        matchEngine: MatchEngine(random: Random(4)),
        random: Random(4),
      );
      await controller.startCareer(
        name: '影山',
        position: Position.st,
        age: 19,
        agent: Agent.pool.first,
      );
      while (!controller.state!.seasonFinished) {
        await controller.simulateMatch();
      }
      await controller.finishSeason();

      final news = controller.news;
      expect(news.length, greaterThan(3), reason: '1シーズンで何も起きない');
      // 全試合に見出しが付くと、どれも記事に見えなくなる。
      expect(news.length, lessThan(controller.state!.fixtures.length),
          reason: '見出しが多すぎる');
      expect(news.any((n) => n.headline.contains('デビュー')), isTrue);

      // シーズンを跨いでも消えない。
      final before = controller.news.length;
      await controller.advanceSeason(accepted: controller.renewalOffer!);
      expect(controller.news.length, greaterThanOrEqualTo(before));
    });
  });
}
