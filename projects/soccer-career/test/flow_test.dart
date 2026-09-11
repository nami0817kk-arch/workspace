/// **局面以外にも、試合を動かすものがあるか。**
///
/// 試合の中でプレイヤーが触るのは 2〜6 の局面だけで、そのあいだ試合は
/// 何も起きていなかった。そして**局面でしか点が入らない**ので、1試合の
/// 最大得点が局面の数で頭打ちになっていた——実測（`test/flow_sim.dart`）で、
/// 中盤の選手は20年で1試合2点を**一度も**取らず、守備の選手は**通算0ゴール**。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

Club _club(String id, {int strength = 60}) =>
    Club(id: id, name: id, strength: strength, tier: 1, countryId: 'yamato');

Player _player({Position position = Position.st, int ability = 70}) => Player(
  name: 'P',
  age: 25,
  position: position,
  attributes: Attributes.fromDetails({
    for (final d in Detail.values) d: ability,
  }),
  potential: 99,
);

MatchInProgress _match({
  Position position = Position.st,
  int opponentStrength = 60,
  int? sentOffThem,
  int? sentOffUs,
  List<int> teammateGoals = const [40, 70],
  List<int> conceded = const [],
  int seed = 3,
}) {
  final engine = MatchEngine(random: Random(seed));
  final base = engine.start(
    matchday: 1,
    player: _player(position: position),
    club: _club('home'),
    opponent: _club('away', strength: opponentStrength),
    home: true,
    appearance: Appearance.start,
  );
  // 退場とスコアは試合開始時に決まっている。ここでは組んだ形で見たいので
  // 同じ局面のまま作り直す。
  return MatchInProgress(
    matchday: 1,
    opponent: base.opponent,
    home: true,
    appearance: Appearance.start,
    scenarios: base.scenarios,
    minutes: base.minutes,
    player: base.player,
    club: base.club,
    teammateGoalMinutes: teammateGoals,
    concededMinutes: conceded,
    sentOffThemMinute: sentOffThem,
    sentOffUsMinute: sentOffUs,
    random: Random(seed),
  );
}

void main() {
  group('試合を動かす展開', () {
    test('退場者が出るまでは効かない', () {
      final match = _match(sentOffThem: 80);
      // 局面は5〜90分に散る。80分より前なら、まだ何も起きていない。
      if (match.currentMinute < 80) {
        expect(match.turns, isEmpty);
      }
    });

    test('相手に退場者が出ると、残りの手が通りやすくなる', () {
      final plain = _match();
      final up = _match(sentOffThem: 1);
      final option = plain.current.options.first;
      expect(up.turns, contains(MatchTurn.numbersUp));
      expect(
        up.chanceFor(option) - plain.chanceFor(option),
        closeTo(Formulas.numbersUpBonus, 0.001),
      );
    });

    test('味方が退場すると、その逆', () {
      final plain = _match();
      final down = _match(sentOffUs: 1);
      final option = plain.current.options.first;
      expect(down.turns, contains(MatchTurn.numbersDown));
      expect(down.chanceFor(option), lessThan(plain.chanceFor(option)));
    });

    test('展開は成功率の内訳に出る', () {
      // **選べないものが効いているときこそ、画面に出す。**
      // 内訳の合計と判定が一致していることは `cohesion_test` が見張る。
      final match = _match(sentOffThem: 1);
      final option = match.current.options.first;
      expect(
        match
            .factorsFor(option)
            .any((f) => f.label == MatchTurn.numbersUp.label),
        isTrue,
      );
    });

    test('展開は時系列に残る', () {
      final match = _match(sentOffThem: 30, sentOffUs: 60);
      final kinds = match.timeline.map((e) => e.kind).toList();
      expect(kinds, contains(MatchEventKind.sentOffThem));
      expect(kinds, contains(MatchEventKind.sentOffUs));
    });

    test('味方の退場は「自分たちの出来事」ではない', () {
      // 色分けが得点と同じになると、失点と並べたときに読めなくなる。
      expect(MatchEventKind.sentOffUs.isOurs, isFalse);
      expect(MatchEventKind.sentOffThem.isOurs, isTrue);
    });

    test('数的優位は、決まる確率にも乗る', () {
      final plain = _match();
      final up = _match(sentOffThem: 1);
      expect(up.goalConversionNow(), greaterThan(plain.goalConversionNow()));
    });
  });

  group('流れの中の1本', () {
    test('ポジションで、絡む度合いが違う', () {
      // 守備の選手が 0 でないのは**セットプレーの的**になるから。
      expect(Formulas.flowGoalShareFor(ScenarioFamily.forward), 1.0);
      expect(
        Formulas.flowGoalShareFor(ScenarioFamily.midfield),
        lessThan(Formulas.flowGoalShareFor(ScenarioFamily.forward)),
      );
      expect(
        Formulas.flowGoalShareFor(ScenarioFamily.defence),
        greaterThan(0),
        reason: '20年で1点も取らないセンターバックは football ではない',
      );
      expect(Formulas.flowGoalShareFor(ScenarioFamily.goalkeeper), 0);
    });

    test('足すのではなく、味方の得点を置き換える', () {
      // **足すと自分のクラブだけ点が増える**（アシストで踏んだのと同じ穴）。
      var found = false;
      for (var seed = 0; seed < 200 && !found; seed++) {
        final match = _match(seed: seed, teammateGoals: const [30, 50, 70, 85]);
        final before = match.teammateGoalMinutes.length;
        while (!match.isFinished) {
          match.choose(match.pickFor(SimStyle.aggressive));
        }
        if (match.flowGoals > 0) {
          found = true;
          expect(
            match.teammateGoalMinutes.length + match.ownGoalMinutes.length,
            greaterThanOrEqualTo(before),
          );
          // 置き換えたぶん、味方の得点は減っている。
          expect(match.teammateGoalMinutes.length, lessThan(before));
        }
      }
      expect(found, isTrue, reason: '200試合で流れの1本が一度も出ない');
    });

    test('予定が無ければ起きない', () {
      // 味方の得点予定が無い試合では、置き換える相手が居ない。
      for (var seed = 0; seed < 40; seed++) {
        final match = _match(seed: seed, teammateGoals: const []);
        while (!match.isFinished) {
          match.choose(match.pickFor(SimStyle.aggressive));
        }
        expect(match.flowGoals, 0);
      }
    });
  });
}
