import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/state/career_controller.dart';

/// 端末の保存領域と同じく、JSON に落として持つ。
/// 「アプリが落ちて起動し直した」を、別の CareerController で読み直して再現する。
class _JsonRepository implements SaveRepository {
  Map<String, dynamic>? _saved;

  @override
  Future<CareerState?> load() async =>
      _saved == null ? null : CareerState.fromJson(_saved!);

  @override
  Future<void> save(CareerState state) async => _saved = state.toJson();

  @override
  Future<void> clear() async => _saved = null;
}

class _MemoryHall implements HallRepository {
  Hall _saved = const Hall();

  @override
  Future<Hall> load() async => _saved;

  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

CareerController _controller(
  SaveRepository repository,
  HallRepository hall,
  int seed,
) => CareerController(
  repository: repository,
  hallRepository: hall,
  careerEngine: CareerEngine(random: Random(seed)),
  matchEngine: MatchEngine(random: Random(seed)),
  random: Random(seed),
);

void main() {
  group('季末の処理は1シーズン1回だけ', () {
    test('2回呼んでも、世界大会の結果とキャップは変わらない（エンジン）', () {
      // 種を変えて2回目を呼ぶ。引き直していれば結果が揺れる。
      for (var seed = 0; seed < 20; seed++) {
        final state = CareerEngine(random: Random(seed)).startCareer(
          name: 'T',
          position: Position.cm,
          age: 24,
          agent: Agent.pool.first,
        );
        state.year = 2028; // 世界大会の年
        state.calledUp = true;
        final before = state.caps;

        CareerEngine(random: Random(seed)).resolveSeasonEnd(state);
        expect(state.worldCupStage.participated, isTrue);
        expect(state.seasonEndResolved, isTrue);
        final caps = state.caps;
        final worldCup = state.worldCupStage;
        final cup = state.cupStage;
        final continental = state.continentalStage;
        expect(caps, greaterThan(before));

        for (var again = 0; again < 5; again++) {
          CareerEngine(random: Random(1000 + seed * 7 + again))
              .resolveSeasonEnd(state);
          expect(state.caps, caps, reason: 'seed=$seed: キャップが二重に入った');
          expect(
            state.worldCupStage,
            worldCup,
            reason: 'seed=$seed: 世界大会を引き直した',
          );
          expect(state.cupStage, cup);
          expect(state.continentalStage, continental);
        }
      }
    });

    test('済ませた印は保存に乗り、古い保存データは未処理として読む', () {
      final state = CareerEngine(random: Random(3)).startCareer(
        name: 'T',
        position: Position.cm,
        age: 24,
        agent: Agent.pool.first,
      );
      CareerEngine(random: Random(3)).resolveSeasonEnd(state);
      expect(CareerState.fromJson(state.toJson()).seasonEndResolved, isTrue);

      final old = state.toJson()..remove('seasonEndResolved');
      expect(CareerState.fromJson(old).seasonEndResolved, isFalse);
    });

    test('季末の画面で落ちて起動し直しても、キャップと結果が二重にならない', () async {
      final repository = _JsonRepository();
      final hall = _MemoryHall();
      final first = _controller(repository, hall, 4);
      await first.startCareer(
        name: 'テスト',
        position: Position.cm,
        age: 24,
        agent: Agent.pool.first,
      );
      while (!first.state!.seasonFinished) {
        if (first.pendingEvent != null) {
          await first.resolveEvent(first.pendingEvent!.choices.first);
        }
        await first.simulateMatch();
      }
      // 世界大会の年で、代表に呼ばれていることにする。
      first.state!
        ..year = 2028
        ..calledUp = true;
      final capsBefore = first.state!.caps;

      // 季末の画面を開いた（initState が finishSeason を呼ぶ）。
      await first.finishSeason();
      final caps = first.state!.caps;
      final worldCup = first.state!.worldCupStage;
      final cup = first.state!.cupStage;
      final continental = first.state!.continentalStage;
      final news = first.state!.news.length;
      expect(worldCup.participated, isTrue);
      expect(caps, capsBefore + 3 + worldCup.points);

      // 同じ画面をもう一度開いても何も起きない。
      await first.finishSeason();
      expect(first.state!.caps, caps);
      expect(first.state!.news.length, news, reason: '季末の記事が二度出た');

      // 契約も引退も選ばずにアプリが落ち、起動し直して季末の画面をまた開く。
      // 種を変えてあるので、引き直していれば結果が揺れる。
      for (var seed = 50; seed < 60; seed++) {
        final again = _controller(repository, hall, seed);
        await again.init();
        expect(again.state!.seasonFinished, isTrue);
        await again.finishSeason();
        expect(again.state!.caps, caps, reason: 'キャップが二重に入った');
        expect(again.state!.worldCupStage, worldCup, reason: '世界大会を引き直した');
        expect(again.state!.cupStage, cup);
        expect(again.state!.continentalStage, continental);
        expect(again.state!.news.length, news);
      }
    });

    test('翌季はまた季末の処理が走る', () async {
      final repository = _JsonRepository();
      final c = _controller(repository, _MemoryHall(), 6);
      await c.startCareer(
        name: 'テスト',
        position: Position.cm,
        age: 24,
        agent: Agent.pool.first,
      );
      while (!c.state!.seasonFinished) {
        if (c.pendingEvent != null) {
          await c.resolveEvent(c.pendingEvent!.choices.first);
        }
        await c.simulateMatch();
      }
      await c.finishSeason();
      expect(c.state!.seasonEndResolved, isTrue);
      await c.advanceSeason(accepted: c.renewalOffer ?? c.offers.first);
      expect(c.state!.seasonEndResolved, isFalse);
      expect(c.state!.worldCupStage, WorldCupStage.none);
    });
  });
}
