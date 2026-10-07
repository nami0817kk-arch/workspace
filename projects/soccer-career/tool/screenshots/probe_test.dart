/// 掲載用の絵を撮る季を探すための、使い捨ての道具。
/// `flutter test tool/screenshots/probe_test.dart`
// ignore_for_file: avoid_print
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/legend.dart';
import 'package:soccer_career/state/career_controller.dart';

class _Repo implements SaveRepository {
  CareerState? _saved;
  @override
  Future<CareerState?> load() async => _saved;
  @override
  Future<void> save(CareerState state) async => _saved = state;
  @override
  Future<void> clear() async => _saved = null;
}

class _Hall implements HallRepository {
  Hall _saved = const Hall();
  @override
  Future<Hall> load() async => _saved;
  @override
  Future<void> save(Hall hall) async => _saved = hall;
}

void main() {
  testWidgets('探す', (tester) async {
    for (final seed in [1, 2, 3, 5, 7, 11, 13, 17]) {
      final controller = CareerController(
        repository: _Repo(),
        hallRepository: _Hall(),
        careerEngine: CareerEngine(random: Random(seed)),
        matchEngine: MatchEngine(random: Random(seed)),
        random: Random(seed),
      );
      await controller.startCareer(
        name: '新堂 陽',
        position: Position.cm,
        age: 18,
        agent: Agent.pool.first,
      );
      final lines = <String>[];
      for (var season = 0; season < 6; season++) {
        while (!controller.state!.seasonFinished) {
          if (controller.pendingEvent != null) {
            await controller.resolveEvent(
              controller.pendingEvent!.choices.first,
            );
          }
          await controller.simulateMatch();
        }
        final s = controller.state!;
        final st = s.seasonStats;
        lines.add(
          '  季$season 年齢${s.player.age} ${s.club.name}(${s.club.tier}部) '
          '${s.leaguePosition}位 総合${s.player.overall} '
          '出${st.appearances} G${st.goals} A${st.assists} '
          '評${st.averageRating.toStringAsFixed(2)}',
        );
        final offers = [
          if (controller.renewalOffer != null) controller.renewalOffer!,
          ...controller.offers,
        ];
        if (offers.isEmpty) {
          lines.add('  （話が来ない）');
          break;
        }
        final ranked = [...offers]
          ..sort((a, b) {
            int score(TransferOffer o) =>
                (o.loan ? -5000 : 0) + o.salary + (4 - o.club.tier) * 800;
            return score(b).compareTo(score(a));
          });
        await controller.advanceSeason(
          accepted: ranked.first,
          offseason: Offseason.sharpen,
        );
      }
      print('seed=$seed');
      lines.forEach(print);
    }
  });
}
