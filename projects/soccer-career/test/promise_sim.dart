// ignore_for_file: avoid_print
/// 約束が「賭け」になっているかを測る。
///
/// `flutter test test/promise_sim.dart` で明示的に走らせる。
/// ファイル名が `_test.dart` で終わらないので、CI の一括実行には入らない。
///
/// 見たいのは達成率。100% なら罰の無いただのボーナスで、0% ならただの罰。
/// 3つの出方が「控えめ・順当・大きく出る」の順に並んでいるかも見る。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/promises.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/promise.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/state/career_controller.dart';

import 'support/career_sim.dart';

class _Tally {
  int offered = 0;
  int achieved = 0;
  double get rate => offered == 0 ? 0 : achieved / offered;
}

void main() {
  test('約束の達成率', () async {
    final byWeight = {for (final w in PromiseWeight.values) w: _Tally()};
    final byKind = {for (final k in PromiseKind.values) k: _Tally()};
    var seasons = 0;

    for (final position in [
      Position.st,
      Position.wg,
      Position.am,
      Position.cm,
      Position.cb,
      Position.gk,
    ]) {
      for (var seed = 0; seed < 24; seed++) {
        final controller = CareerController(
          repository: MemoryRepository(),
          careerEngine: CareerEngine(random: Random(seed)),
          matchEngine: MatchEngine(random: Random(seed * 7919 + 13)),
          random: Random(seed * 104729 + 7),
        );
        final random = Random(seed * 31 + 5);
        await controller.startCareer(
          name: '選手$seed',
          position: position,
          age: 19,
          agent: Agent.pool.first,
        );
        await controller.setSimStyle(SimStyle.balanced);

        var guard = 0;
        while (!controller.state!.retired && guard++ < 25) {
          final state = controller.state!;
          // 約束できる場面で、3つの出方をそのまま覚えておく。
          // 実際には1つしか選べないが、達成率を測るには全部見たい。
          final offers =
              PromiseOffers.canPromise(state) ? PromiseOffers.forState(state) : null;

          var matches = 0;
          while (!controller.state!.seasonFinished && matches++ < 60) {
            if (controller.pendingEvent != null) {
              final choices = controller.pendingEvent!.choices;
              await controller
                  .resolveEvent(choices[random.nextInt(choices.length)]);
            }
            await controller.simulateMatch();
          }
          await controller.finishSeason();

          if (offers != null) {
            seasons++;
            final stats = controller.state!.seasonStats;
            for (final offer in offers) {
              final kept = offer.achievedBy(stats);
              byWeight[offer.weight]!.offered++;
              byKind[offer.kind]!.offered++;
              if (kept) {
                byWeight[offer.weight]!.achieved++;
                byKind[offer.kind]!.achieved++;
              }
            }
          }

          if (controller.canRetire && controller.state!.player.age >= 34) {
            await controller.retire();
            break;
          }
          final offer = controller.renewalOffer;
          if (offer == null) break;
          await controller.advanceSeason(accepted: offer);
        }
      }
    }

    print('約束できたシーズン: $seasons');
    print('--- 出方ごと ---');
    for (final w in PromiseWeight.values) {
      final t = byWeight[w]!;
      print('${w.label.padRight(8)} ${(t.rate * 100).toStringAsFixed(1)}% '
          '(${t.achieved}/${t.offered})');
    }
    print('--- 中身ごと ---');
    for (final k in PromiseKind.values) {
      final t = byKind[k]!;
      if (t.offered == 0) continue;
      print('${k.label.padRight(6)} ${(t.rate * 100).toStringAsFixed(1)}% '
          '(${t.achieved}/${t.offered})');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
