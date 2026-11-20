import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

/// **試合の状況で、手の値打ちが変わる**（2026-11-15）。
///
/// 評価点の物差しが状況を見ていなかったので、負けている終盤も
/// 勝っている終盤も、同じ局面はいつも同じ答えだった。
final _flat = Attributes(
  pace: 70,
  shooting: 70,
  passing: 70,
  dribbling: 70,
  defending: 70,
  physical: 70,
  goalkeeping: 70,
);

Club _club(String id) =>
    Club(id: id, name: id, strength: 60, tier: 1, countryId: 'yamato');

MatchInProgress _match(
  Scenario scenario, {
  required int minute,
  List<int> scored = const [],
  List<int> conceded = const [],
  int seed = 1,
  Position position = Position.cm,
}) => MatchInProgress(
  matchday: 1,
  opponent: _club('rival'),
  home: true,
  appearance: Appearance.start,
  scenarios: [scenario],
  minutes: [minute],
  player: Player(
    name: 'P',
    age: 24,
    position: position,
    attributes: _flat,
    potential: 90,
  ),
  club: _club('mine'),
  teammateGoalMinutes: scored,
  concededMinutes: conceded,
  random: Random(seed),
);

ScenarioOption _best(MatchInProgress m, {MatchStakes? asIf}) =>
    m.current.options.reduce(
      (a, b) => m.expectedDelta(b, asIf: asIf) > m.expectedDelta(a, asIf: asIf)
          ? b
          : a,
    );

void main() {
  final pool = ScenarioPool.neutralFor(Position.cm.family);
  final build = pool.firstWhere(
    (s) => s.options.any((o) => o.outcome == Outcome.play),
  );

  group('状況の読み方', () {
    test('局面の差し替えと同じ線で、状況が決まる', () {
      expect(_match(build, minute: 30).stakes, MatchStakes.none);
      expect(
        _match(build, minute: 80, conceded: [5]).stakes,
        MatchStakes.chasing,
      );
      expect(_match(build, minute: 80).stakes, MatchStakes.leveling);
      expect(
        _match(build, minute: 72, scored: [5]).stakes,
        MatchStakes.protecting,
      );
      // 同点でも、終盤より前は何も変えない。
      expect(_match(build, minute: 72).stakes, MatchStakes.none);
    });

    test('状況が変えていないときは、札も手の印も出さない', () {
      final m = _match(build, minute: 30);
      expect(m.stakesLabel, isNull);
      for (final o in m.current.options) {
        expect(m.stakesNoteFor(o), isNull);
      }
    });

    test('札と手の印は、判定の倍率から作る', () {
      final m = _match(build, minute: 80, conceded: [5]);
      for (final o in m.current.options) {
        expect(m.stakesNoteFor(o), o.outcome == Outcome.play ? '今は軽い' : '今は重い');
      }
      final hold = _match(build, minute: 80, scored: [5]);
      for (final o in hold.current.options) {
        expect(
          hold.stakesNoteFor(o),
          o.outcome == Outcome.play ? '今は重い' : '外すと痛い',
        );
      }
    });
  });

  group('判定と物差しが同じ重みを読む', () {
    // つなぐ手は試合の展開（相手の前がかり等）の補正を受けないので、
    // 終盤の同じ分なら成功率が同じ。違うのは状況の重みだけ。
    final play = build.options.firstWhere((o) => o.outcome == Outcome.play);

    test('追う展開では、つなぐ手が通っても評価は軽い', () {
      for (var seed = 0; seed < 40; seed++) {
        final chase = _match(build, minute: 80, conceded: [5], seed: seed);
        final level = _match(build, minute: 80, seed: seed);
        expect(chase.chanceFor(play), closeTo(level.chanceFor(play), 1e-9));
        final a = chase.choose(play);
        final b = level.choose(play);
        if (!a.success) continue;
        expect(b.success, isTrue);
        // 布石が通ったぶん（`ratingPerSetup`）は状況に関係なく付くので引いて比べる。
        final setup = build.roleOf(play) == ComboRole.setup
            ? Formulas.ratingPerSetup
            : 0.0;
        expect(
          (a.ratingDelta - setup) / (b.ratingDelta - setup),
          closeTo(Formulas.stakesChasePlay / Formulas.stakesLevelPlay, 1e-9),
        );
        return;
      }
      fail('通る種が見つからなかった');
    });

    test('守り切る展開では、外したときの減点が重い', () {
      for (var seed = 0; seed < 40; seed++) {
        final hold = _match(build, minute: 80, scored: [5], seed: seed);
        final level = _match(build, minute: 80, seed: seed);
        final a = hold.choose(play);
        final b = level.choose(play);
        if (a.success) continue;
        expect(b.success, isFalse);
        expect(
          a.ratingDelta / b.ratingDelta,
          closeTo(Formulas.stakesHoldFailure, 1e-9),
        );
        return;
      }
      fail('外れる種が見つからなかった');
    });

    test('物差しも、状況で値打ちを動かす', () {
      final m = _match(build, minute: 80, conceded: [5]);
      final attack = build.options.firstWhere((o) => o.outcome != Outcome.play);
      expect(
        m.expectedDelta(play),
        lessThan(m.expectedDelta(play, asIf: MatchStakes.none)),
      );
      expect(
        m.expectedDelta(attack),
        greaterThan(m.expectedDelta(attack, asIf: MatchStakes.none)),
      );
    });
  });

  test('**同じ局面でも、状況で最善の手が入れ替わる**', () {
    // ここが仕組みの目的そのもの。入れ替わる局面が無ければ、
    // 倍率を足しても選択は増えていない。
    var flips = 0;
    var checked = 0;
    for (final position in [Position.st, Position.cm, Position.cb]) {
      for (final s in ScenarioPool.neutralFor(position.family)) {
        final chase = _match(s, minute: 80, conceded: [5], position: position);
        final hold = _match(s, minute: 80, scored: [5], position: position);
        final calm = _best(chase, asIf: MatchStakes.none);
        checked++;
        if (!identical(_best(chase), calm) || !identical(_best(hold), calm)) {
          flips++;
        }
      }
    }
    expect(checked, greaterThan(30));
    expect(
      flips,
      greaterThanOrEqualTo(checked ~/ 4),
      reason: '状況で答えが変わる局面 $flips / $checked',
    );
  });
}
