/// 「今日の1本が何に効くのか」が、試合に入る前と最中に見えているか。
///
/// 監督の求める形・目標の残り・順位・得点王レース・相手の戦い方は、
/// **4つの別々の画面**に散っていた。得点ランキングに至っては
/// `ScorerRace.rankOf` がどこからも呼ばれておらず、自分が何位かも
/// 「あと何点で得点王か」も出ていなかった。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_brief.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/newsroom.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/objective.dart';
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
      name: '検証', position: Position.cm, age: 24, agent: Agent.pool.first);
  return c;
}

/// 節を進めた状態にする（自分の得点だけを作る）。
void playedWith(CareerState state, {required int matchdays, required int goals}) {
  state.results = [
    for (var i = 0; i < matchdays; i++)
      MatchResult(
        matchday: i + 1,
        opponentName: state.opponentFor(i + 1).name,
        home: state.isHome(i + 1),
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: 7.0,
        goals: i < goals ? 1 : 0,
        assists: 0,
      ),
  ];
}

void main() {
  group('得点王レースに自分を乗せる', () {
    test('序盤は煽らない', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: 5, goals: 5);
      expect(ScorerRace.chaseFor(state), isNull, reason: '第6節で得点王を煽っている');
    });

    test('1点も取っていなければ出さない', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: 32, goals: 0);
      expect(ScorerRace.chaseFor(state), isNull);
    });

    test('終盤に届く位置なら、あと何点かを出す', () async {
      final c = await started();
      final state = c.state!;
      // 他人の得点は節数から決まるので、先に節を進めてから測る。
      playedWith(state, matchdays: 32, goals: 0);
      final top = ScorerRace.table(state, take: 999).first.goals;
      // 首位を1点上回れば、必ず射程に入る。
      playedWith(state, matchdays: 32, goals: top + 1);
      final chase = ScorerRace.chaseFor(state);
      expect(chase, isNotNull);
      expect(chase, contains('得点王'));
      expect(ScorerRace.rankOf(state), 1);
    });

    test('届かない差なら煽らない', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: 37, goals: 1);
      // 残り1試合で首位に1点差まで、ということはまず無い。
      final all = ScorerRace.table(state, take: 999);
      final gap = all.first.goals - 1;
      if (gap > 1) expect(ScorerRace.chaseFor(state), isNull);
    });

    test('順位は並び順ではなく本当の順位', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: 20, goals: 0);
      // 6人表示の末尾に付け足された自分は、7位ではない。
      final shown = ScorerRace.table(state);
      expect(shown.last.isPlayer, isTrue);
      expect(ScorerRace.rankOf(state), greaterThan(shown.length));
    });
  });

  group('今日の意味を1枚に', () {
    test('監督・目標・順位・相手が揃う', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.possession, demand: 3);
      state.objective =
          const SeasonObjective(appearances: 20, contributions: 8, rating: 6.8);
      playedWith(state, matchdays: 10, goals: 2);
      final labels = MatchBrief.of(state).map((l) => l.label).toList();
      expect(labels, containsAll(['監督', '目標', '順位', '相手']));
    });

    test('開幕直後は順位を出さない', () async {
      final c = await started();
      final labels = MatchBrief.of(c.state!).map((l) => l.label).toList();
      expect(labels, isNot(contains('順位')), reason: '中身の無い順位表を出している');
      expect(labels, contains('相手'));
    });

    test('監督が求める形を名指しする', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'M', tactic: Tactic.counter, demand: 3);
      final line = MatchBrief.of(state).firstWhere((l) => l.label == '監督');
      expect(line.text, contains(AttributeKey.pace.label));
      expect(line.text, contains(AttributeKey.shooting.label));
    });

    test('何も求めない監督は、そう書く', () async {
      final c = await started();
      final state = c.state!;
      state.manager =
          const Manager(name: 'B', tactic: Tactic.balanced, demand: 3);
      final line = MatchBrief.of(state).firstWhere((l) => l.label == '監督');
      expect(line.text, contains('形は求めていない'));
    });

    test('目標は届いていない項目だけ出す', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: 20, goals: 9);
      state.objective =
          const SeasonObjective(appearances: 10, contributions: 20, rating: 6.5);
      final line = MatchBrief.of(state).firstWhere((l) => l.label == '目標');
      expect(line.text, isNot(contains('出場')), reason: '達成済みの項目が残っている');
      expect(line.text, contains('得点関与 あと11'));
    });

    test('あと一歩なら強調する', () async {
      final c = await started();
      final state = c.state!;
      state.objective =
          const SeasonObjective(appearances: 99, contributions: 1, rating: 0);
      expect(state.objectiveReach, isNotNull);
      final line = MatchBrief.of(state).firstWhere((l) => l.label == '目標');
      expect(line.urgent, isTrue);
    });

    test('代表ウィークではリーグの話をしない', () async {
      final c = await started();
      final state = c.state!;
      state.pendingInternational = true;
      final labels = MatchBrief.of(state).map((l) => l.label).toList();
      expect(labels, isNot(contains('相手')));
      expect(labels, isNot(contains('順位')));
    });

    test('シーズンが終わっていれば何も出さない', () async {
      final c = await started();
      final state = c.state!;
      playedWith(state, matchdays: state.fixtures.length, goals: 0);
      expect(state.seasonFinished, isTrue);
      expect(MatchBrief.of(state), isEmpty);
    });
  });
}
