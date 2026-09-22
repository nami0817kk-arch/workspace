/// 知名度が張り付かないこと、最上位の国は名前で入ること。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

CareerState _career({String? country}) =>
    CareerEngine(random: Random(3)).startCareer(
      name: 'T',
      position: Position.cm,
      age: 24,
      agent: Agent.pool.first,
      countryId: country,
    );

void main() {
  test('露出が同じなら、知名度は100に張り付かずに落ち着く', () {
    // 以前は毎季 −2 して足すだけで、25歳で 3/4 が 99〜100 だった。
    final person = Person(random: Random(1));
    final state = _career();
    // 毎季同じ露出（1部・格の高い国で出場）を与え続ける。
    state.results.addAll([
      for (var i = 0; i < 20; i++)
        MatchResult(
          matchday: i + 1,
          opponentName: 'X',
          home: true,
          scored: 1,
          conceded: 0,
          appearance: Appearance.start,
          rating: 7.0,
          goals: 1,
          assists: 1,
        ),
    ]);
    for (var i = 0; i < 30; i++) {
      state.reputation = state.reputation.copyWith(fame: person.fameFor(state));
    }
    expect(state.reputation.fame, lessThan(90));
    expect(state.reputation.fame, greaterThan(20));
  });

  test('露出が止まると、有名なほど早く薄れる', () {
    final person = Person(random: Random(1));
    final state = _career();
    state.reputation = state.reputation.copyWith(fame: 90);
    final high = 90 - person.fameFor(state);
    state.reputation = state.reputation.copyWith(fame: 30);
    final low = 30 - person.fameFor(state);
    expect(high, greaterThan(low));
  });

  test('最上位の国は、代表か知名度が届くまで候補に入らない', () {
    final engine = CareerEngine(random: Random(2));
    final top = World.countries.map((c) => c.prestige).reduce(max);
    final below = World.countries.firstWhere((c) => c.prestige == top - 1);
    final state = _career(country: below.id);
    state.player = state.player.copyWith(
      attributes: Attributes.fromDetails({for (final d in Detail.values) d: 90}),
    );
    state.caps = 0;
    state.reputation = const Reputation(fame: 10);
    bool reachesTop() =>
        engine.reachableCountries(state).any((c) => c.prestige == top);
    expect(reachesTop(), isFalse);

    state.caps = Formulas.eliteCaps;
    expect(reachesTop(), isTrue);

    state.caps = 0;
    state.reputation = const Reputation(fame: Formulas.eliteFame);
    expect(reachesTop(), isTrue);
  });
}
