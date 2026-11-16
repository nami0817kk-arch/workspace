/// 「話が来ている」と画面に出した打診は、次の試合のあとに必ず答えさせる。
///
/// 2026-11-16 に利用者から「スポンサーの話が来ていると出るのに、選ぶ場所が無い」と
/// 問い合わせが来た。答える場は出来事の抽選（1試合 24% × 候補 数十件のうちの1件）で
/// しか来ず、1シーズン待っても来ないことが多かった。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/life_events.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/life_event.dart';
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

Future<CareerController> started(int seed) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
    name: '検証',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  return c;
}

/// 出来事が出るまで試合を進める。出た出来事を返す。
Future<LifeEvent?> playUntilEvent(CareerController c, {int matches = 3}) async {
  for (var i = 0; i < matches; i++) {
    if (c.pendingEvent != null) return c.pendingEvent;
    c.startNextMatch();
    await c.simulateMatch();
  }
  return c.pendingEvent;
}

LifeContext context({bool sponsor = false, bool captain = false}) =>
    LifeContext(
      age: 25,
      fame: 50,
      savings: 0,
      abroad: false,
      afterInjury: false,
      sponsorOffered: sponsor,
      captaincyOffered: captain,
      lowMorale: false,
    );

void main() {
  group('返事を待っている打診', () {
    test('スポンサーの打診があれば、それを出す', () {
      expect(LifeEvents().offerWaiting(context(sponsor: true))?.id, 'sponsor');
    });

    test('腕章の打診があれば、それを出す', () {
      expect(LifeEvents().offerWaiting(context(captain: true))?.id, 'captain');
    });

    test('打診が無ければ、何も出さない', () {
      expect(LifeEvents().offerWaiting(context()), isNull);
    });

    test('腕章の出来事は一度きりではない（断った後の打診にも答えられる）', () {
      final captain = LifeEvents.catalogue.firstWhere((e) => e.id == 'captain');
      expect(captain.once, isFalse);
    });

    test('スポンサーの出来事も一度きりではない', () {
      final sponsor = LifeEvents.catalogue.firstWhere((e) => e.id == 'sponsor');
      expect(sponsor.once, isFalse);
    });
  });

  group('試合のあとに答える場が来る', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      test('スポンサーの話が来ていれば、次の試合のあとに出る（種 $seed）', () async {
        final c = await started(seed);
        final state = c.state!;
        state.sponsor = null;
        state.sponsorOffer = const Sponsor(name: 'アストレア', annual: 800);
        final event = await playUntilEvent(c, matches: 1);
        expect(event, isNotNull, reason: '1試合のあとに答える場が来ていない');
        expect(event!.id, 'sponsor');
        // 額のしるしが埋まっている。
        expect(event.body, contains('800'));

        await c.resolveEvent(event.choices.first);
        expect(state.sponsorOffer, isNull);
        expect(state.sponsor?.name, 'アストレア');
      });
    }

    test('断れば、打診は消えて二度は出ない', () async {
      final c = await started(7);
      final state = c.state!;
      state.sponsor = null;
      state.sponsorOffer = const Sponsor(name: 'ノルディカ', annual: 500);
      final event = await playUntilEvent(c, matches: 1);
      expect(event?.id, 'sponsor');
      await c.resolveEvent(event!.choices.last);
      expect(state.sponsorOffer, isNull);
      expect(state.sponsor, isNull);

      // この後の試合でスポンサーの話は出ない。
      for (var i = 0; i < 5; i++) {
        final next = await playUntilEvent(c, matches: 1);
        expect(next?.id, isNot('sponsor'));
        if (next != null) await c.resolveEvent(next.choices.first);
      }
    });

    test('腕章の打診も、次の試合のあとに出る', () async {
      final c = await started(9);
      final state = c.state!;
      state.captain = false;
      state.captaincyOffered = true;
      final event = await playUntilEvent(c, matches: 1);
      expect(event?.id, 'captain');
      await c.resolveEvent(event!.choices.first);
      expect(state.captain, isTrue);
      expect(state.captaincyOffered, isFalse);
    });
  });
}
