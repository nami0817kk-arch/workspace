/// **今節の的。**
///
/// 参考にした野球のキャリアゲームの「今週の目標：7安打」「達成！報酬：20万円」。
/// 38試合を同じ顔で並べないための、近い的。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_target.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/season.dart';

CareerState _career(Position position) => CareerEngine(
  random: Random(31),
).startCareer(name: 'T', position: position, age: 24, agent: Agent.pool.first);

MatchResult _result({
  int goals = 0,
  int assists = 0,
  int conceded = 0,
  double rating = 6.5,
  Appearance appearance = Appearance.start,
}) => MatchResult(
  matchday: 1,
  opponentName: 'X',
  home: true,
  scored: goals,
  conceded: conceded,
  appearance: appearance,
  rating: appearance.played ? rating : null,
  goals: goals,
  assists: assists,
);

void main() {
  test('出ていない試合は達成にしない', () {
    final state = _career(Position.st);
    final target = MatchTarget.of(state);
    expect(
      target.metBy(
        _result(goals: 3, rating: 9, appearance: Appearance.benched),
      ),
      isFalse,
    );
  });

  test('節が変われば的も変わる', () {
    final state = _career(Position.st);
    final labels = <String>{};
    for (var i = 0; i < 3; i++) {
      state.results.add(_result());
      labels.add(MatchTarget.of(state).label);
    }
    expect(labels.length, greaterThan(1));
  });

  test('同じ節なら、何度読んでも同じ的', () {
    // 見てから引き直せると、達成する的を選べてしまう。
    final state = _career(Position.cm);
    expect(MatchTarget.of(state).label, MatchTarget.of(state).label);
  });

  test('守る選手に、点を取る的は出ない', () {
    for (final position in [Position.gk, Position.cb, Position.sb]) {
      final state = _career(position);
      for (var i = 0; i < 3; i++) {
        final label = MatchTarget.of(state).label;
        expect(label, isNot(contains('ゴール')));
        expect(label, isNot(contains('アシスト')));
        state.results.add(_result());
      }
    }
  });

  test('前の選手には、点に絡む的が出る', () {
    final state = _career(Position.st);
    final labels = <String>[];
    for (var i = 0; i < 3; i++) {
      labels.add(MatchTarget.of(state).label);
      state.results.add(_result());
    }
    expect(labels.any((l) => l.contains('ゴール')), isTrue);
  });

  test('報酬は、年俸に対して小さい', () {
    // 「1回で人生が決まる大きさにしない」。38試合の半分でも1シーズン
    // 500万円ほどで、若手には効き、億を超えれば誤差になる。
    expect(Formulas.matchTargetReward * 19, lessThan(1000));
  });
}
