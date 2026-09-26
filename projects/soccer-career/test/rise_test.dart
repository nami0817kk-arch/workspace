/// **昇格と降格は、残った選手にしか起きない。**
///
/// 実測（20キャリアずつ）で、移籍を選び続けるキャリアが昇格を経験するのは
/// **5%**、1クラブに留まると **75%**。上がる/落ちるクラブに残る意味は
/// 契約更改の文でしか伝わらないので、そこに書く。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/ui/screens/season_end_screen.dart';

CareerState _career({int tier = 2, int position = 1}) {
  final s = CareerEngine(random: Random(11)).startCareer(
    name: 'T',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  s.club = Club(
    id: s.club.id,
    name: s.club.name,
    strength: s.club.strength,
    tier: tier,
    countryId: s.club.countryId,
  );
  s.contractYears = 1;
  // 順位は順位表から出るので、勝ち点で作る。
  for (final row in s.table) {
    row.won = row.clubId == s.club.id ? (position == 1 ? 30 : 0) : 10;
  }
  for (var i = 0; i < s.fixtures.length; i++) {
    s.results.add(
      MatchResult(
        matchday: i + 1,
        opponentName: 'X',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: 7.2,
        goals: 0,
        assists: 0,
      ),
    );
  }
  return s;
}

void main() {
  test('上がるクラブの更改には、来季の部が書いてある', () {
    final engine = CareerEngine(random: Random(11));
    final state = _career(tier: 2, position: 1);
    expect(engine.fateOf(state), ClubFate.promoted);
    final offer = engine.renewalOffer(state);
    expect(offer.reason, contains('来季は1部'));
    expect(offer.club.tier, 1);
  });

  test('3部から上がるなら、2部と書く', () {
    final engine = CareerEngine(random: Random(11));
    final state = _career(tier: 3, position: 1);
    final offer = engine.renewalOffer(state);
    expect(offer.reason, contains('来季は2部'));
  });

  test('落ちるクラブの更改にも、行き先が書いてある', () {
    final engine = CareerEngine(random: Random(11));
    final state = _career(tier: 1, position: 20);
    expect(engine.fateOf(state), ClubFate.relegated);
    final offer = engine.renewalOffer(state);
    expect(offer.reason, contains('2部に落ちる'));
  });

  testWidgets('札は、実際の部を書く', (tester) async {
    // 「1部昇格」と決め打ちで書いていたので、3部から2部へ上がった
    // クラブにも「1部昇格」と出ていた。
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FateChip(fate: ClubFate.promoted, tier: 3)),
      ),
    );
    expect(find.text('2部昇格'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FateChip(fate: ClubFate.relegated, tier: 1)),
      ),
    );
    expect(find.text('2部降格'), findsOneWidget);
  });
}
