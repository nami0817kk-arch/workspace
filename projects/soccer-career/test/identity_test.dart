/// クラブの見た目と、試合の時系列。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/ui/club_identity.dart';

Club club(String id, {String? name}) => Club(
      id: id,
      name: name ?? id,
      strength: 60,
      tier: 1,
      countryId: 'yamato',
    );

void main() {
  group('クラブの見た目', () {
    test('同じクラブは毎回同じ見た目になる', () {
      final a = ClubIdentity.of(club('alpha', name: 'アルファ'));
      final b = ClubIdentity.of(club('alpha', name: 'アルファ'));
      expect(a.primary, b.primary);
      expect(a.secondary, b.secondary);
      expect(a.shape, b.shape);
      expect(a.striped, b.striped);
    });

    test('クラブが違えば、そこそこ散らばる', () {
      final league = World.buildLeague('yamato', 1);
      final looks = {
        for (final c in league)
          '${ClubIdentity.of(c).primary.toARGB32()}'
              '-${ClubIdentity.of(c).shape}'
              '-${ClubIdentity.of(c).striped}',
      };
      // 20クラブが全部同じ見た目、のような潰れ方をしていない。
      expect(looks.length, greaterThan(league.length ~/ 2));
    });

    test('エンブレムの文字はクラブ名の頭', () {
      expect(ClubIdentity.initialOf(club('x', name: 'ミナヴィエント')), 'ミ');
      expect(ClubIdentity.initialOf(club('y', name: '')), '?');
    });

    testWidgets('エンブレムが描ける', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final c in World.buildLeague('yamato', 1).take(6))
                ClubCrest(club: c, size: 24),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ClubCrest), findsNWidgets(6));
    });
  });

  group('試合の流れ', () {
    MatchInProgress match({
      List<int> teammateGoals = const [],
      List<int> conceded = const [],
    }) =>
        MatchInProgress(
          matchday: 1,
          opponent: club('rival'),
          home: true,
          appearance: Appearance.start,
          scenarios: ScenarioPool.forPosition(Position.st).take(3).toList(),
          minutes: const [20, 55, 85],
          player: Player(
            name: 'P',
            age: 24,
            position: Position.st,
            attributes: Attributes(
              pace: 70,
              shooting: 90,
              passing: 70,
              dribbling: 70,
              defending: 40,
              physical: 70,
            ),
            potential: 95,
            setPieces: const SetPieceSkills(),
          ),
          club: club('mine'),
          teammateGoalMinutes: teammateGoals,
          concededMinutes: conceded,
          random: Random(3),
        );

    test('得点と失点が時間順に並ぶ', () {
      final m = match(teammateGoals: const [30, 70], conceded: const [10, 50]);
      final events = m.timeline;
      expect(events.length, 4);
      expect(events.map((e) => e.minute).toList(), [10, 30, 50, 70]);
      expect(events.first.kind, MatchEventKind.conceded);
      expect(events.first.kind.isOurs, isFalse);
      expect(events[1].kind, MatchEventKind.teammateGoal);
    });

    test('自分の得点も同じ流れに入る', () {
      for (var seed = 0; seed < 40; seed++) {
        final m = match(conceded: const [10]);
        final goal =
            m.current.options.where((o) => o.outcome == Outcome.goal).toList();
        if (goal.isEmpty) continue;
        m.choose(goal.first);
        if (m.goals == 0) continue;
        final events = m.timeline;
        expect(events.any((e) => e.kind == MatchEventKind.ownGoal), isTrue);
        expect(events.map((e) => e.minute).toList(),
            List.of(events.map((e) => e.minute))..sort());
        return;
      }
    });
  });
}
