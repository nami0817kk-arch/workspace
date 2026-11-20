// ignore_for_file: avoid_print
/// **1つの局面の中で、最善の手が入れ替わるか。**
///
/// `choice_sim` はキャリアを回して「答えが9割以上決まっている局面」を数える。
/// 数は出るが、どう直せば入れ替わるのかは見えない。ここでは局面を1つずつ、
/// 能力（60〜90）× 時間（20・50・80分）× 点差（−1・0・+1）の36通りに置き、
/// それぞれで物差し（`expectedDelta`）が一番高い手を数える。
///
/// 局面のデータを直すときに、数秒で確かめるための道具。手動実行。
///   flutter test test/scenario_probe.dart --dart-define=IDS=df-cross,df-offside
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

/// 2026-11-15 に `choice_sim` で答えが9割以上決まっていた GK と CB の局面。
const _fixed =
    'gk-chase-corner,gk-sweeper,gk-backpass,gk-hold-wall,gk-hold-clock,'
    'df-setpiece,df-goalline,df-offside,df-cross,def-hold-box,'
    'def-hold-stop,def-hold-clock,def-hold-duel';

Club _club(String id) =>
    Club(id: id, name: id, strength: 60, tier: 1, countryId: 'yamato');

void main() {
  test('scenario probe', () {
    const ids = String.fromEnvironment('IDS', defaultValue: _fixed);
    final all = {
      for (final f in ScenarioFamily.values)
        for (final s in ScenarioPool.forFamily(f)) s.id: (s, f),
    };
    var stuck = 0;
    for (final id in ids.split(',')) {
      final (scenario, family) = all[id]!;
      final wins = <String, int>{};
      final cells = <String>[];
      for (final level in [60, 70, 80, 90]) {
        final attributes = Attributes.fromDetails({
          for (final d in Detail.values) d: level,
        });
        for (final minute in [20, 50, 80]) {
          for (final margin in [-1, 0, 1]) {
            final m = MatchInProgress(
              matchday: 1,
              opponent: _club('rival'),
              home: true,
              appearance: Appearance.start,
              scenarios: [scenario],
              minutes: [minute],
              player: Player(
                name: 'P',
                age: 26,
                position: family == ScenarioFamily.goalkeeper
                    ? Position.gk
                    : Position.cb,
                attributes: attributes,
                potential: 95,
              ),
              club: _club('mine'),
              teammateGoalMinutes: margin > 0 ? const [5] : const [],
              concededMinutes: margin < 0 ? const [5] : const [],
              expectedConceded: 1.2,
              random: Random(1),
            );
            final best = scenario.options.reduce(
              (a, b) => m.expectedDelta(b) > m.expectedDelta(a) ? b : a,
            );
            wins[best.label] = (wins[best.label] ?? 0) + 1;
            cells.add('$level/$minute/${margin >= 0 ? '+' : ''}$margin');
          }
        }
      }
      final top = wins.values.reduce(max);
      if (top / 36 >= 0.9) stuck++;
      print(
        '${id.padRight(16)} ${top / 36 >= 0.9 ? '決まっている' : '入れ替わる  '} '
        '${[for (final e in wins.entries) '${e.key} ${e.value}'].join(' ／ ')}',
      );
    }
    print('36通りのうち9割以上同じ手が最善の局面: $stuck');
  });
}
