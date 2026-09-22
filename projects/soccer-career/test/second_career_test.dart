/// 引退後の道。6つ全部が起きること。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

final _engine = CareerEngine(random: Random(1));

CareerState _career() => _engine.startCareer(
  name: 'T',
  position: Position.cm,
  age: 30,
  agent: Agent.pool.first,
);

void _play(CareerState state, int matches) {
  for (var i = 0; i < matches; i++) {
    state.results.add(
      MatchResult(
        matchday: i + 1,
        opponentName: 'X',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: 7.0,
        goals: 0,
        assists: 0,
      ),
    );
  }
}

void main() {
  test('腕章とプロ意識なら監督、プロ意識だけならコーチ', () {
    final state = _career();
    state.player = state.player.copyWith(
      personality: const Personality(confidence: 10, ambition: 10, professionalism: 15, temper: 10),
    );
    state.captain = true;
    expect(_engine.secondCareerFor(state), SecondCareer.manager);
    state.captain = false;
    expect(_engine.secondCareerFor(state), SecondCareer.coach);
  });

  test('名前が残っていれば解説者、試合数を積んでいればフロント', () {
    final state = _career();
    state.player = state.player.copyWith(
      personality: const Personality(confidence: 10, ambition: 10, professionalism: 10, temper: 10),
    );
    state.reputation = Reputation(fame: Formulas.punditFame);
    expect(_engine.secondCareerFor(state), SecondCareer.pundit);

    state.reputation = const Reputation(fame: 10);
    _play(state, 520);
    expect(_engine.secondCareerFor(state), SecondCareer.director);
  });

  test('どれにも当てはまらなければ、静かな暮らし', () {
    // ここが必ず何かに当てはまってしまうと、6つのうち1つが死ぬ。
    final state = _career();
    state.player = state.player.copyWith(
      personality: const Personality(confidence: 10, ambition: 10, professionalism: 10, temper: 10),
    );
    state.reputation = const Reputation(fame: 10);
    expect(_engine.secondCareerFor(state), SecondCareer.quiet);
  });

  test('ピッチに戻るのは監督とコーチだけ', () {
    // 解説者も実業家も静かな暮らしも、次のキャリアには現れない。
    for (final path in SecondCareer.values) {
      final returns =
          path == SecondCareer.manager || path == SecondCareer.coach;
      expect(
        path == SecondCareer.manager || path == SecondCareer.coach,
        returns,
      );
    }
  });
}
