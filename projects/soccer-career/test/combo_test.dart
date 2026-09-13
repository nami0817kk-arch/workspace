/// **布石と仕留め。**
///
/// 実測（`matters_sim`）で、中身の違う3つの遊び方（最善・安全・勝負）が
/// ほぼ同じ結果になっていた。ゲーム自身が期待値を計算して画面に出すので、
/// **人がエンジンに勝つ余地が構造的に無い**のが根っこ。
///
/// 布石はその場の見返りがほぼゼロなので、1手ぶんしか見ない自動進行は
/// 選ばない。**2手先に投資できるのは人だけ**——そこを開ける。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'dart:math';

import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/player.dart';

void main() {
  group('役どころの決まり方', () {
    test('仕留めは、得点に繋がる手のうち一番難しいもの', () {
      for (final family in ScenarioFamily.values) {
        for (final scenario in ScenarioPool.forFamily(family)) {
          final finishes = [
            for (final o in scenario.options)
              if (scenario.roleOf(o) == ComboRole.finish) o,
          ];
          // 得点に繋がる手が無い局面には、仕留めも無い。
          final scoring = scenario.options.where(
            (o) => o.outcome != Outcome.play,
          );
          if (scoring.isEmpty) {
            expect(finishes, isEmpty, reason: scenario.id);
            continue;
          }
          expect(finishes.length, 1, reason: scenario.id);
          for (final o in scoring) {
            expect(
              o.difficulty,
              lessThanOrEqualTo(finishes.first.difficulty),
              reason: scenario.id,
            );
          }
        }
      }
    });

    test('布石は1つまで。仕留めより難しい布石は置かない', () {
      for (final family in ScenarioFamily.values) {
        for (final scenario in ScenarioPool.forFamily(family)) {
          final setups = [
            for (final o in scenario.options)
              if (scenario.roleOf(o) == ComboRole.setup) o,
          ];
          expect(setups.length, lessThanOrEqualTo(1), reason: scenario.id);
          if (setups.isEmpty) continue;
          final finish = scenario.options.firstWhere(
            (o) => scenario.roleOf(o) == ComboRole.finish,
          );
          // **遠回りにしない。** 仕留めより難しい布石はただの損。
          expect(
            setups.first.difficulty,
            lessThan(finish.difficulty),
            reason: scenario.id,
          );
          expect(setups.first.outcome, Outcome.play, reason: scenario.id);
        }
      }
    });

    test('布石も仕留めもある局面が、どのポジションにも4つ以上ある', () {
      // 片方しか無いと、そのポジションではこの仕組みが動かない。
      //
      // 実測: GK 5/18・守備 6/19・中盤 14/19・前線 12/18。
      // **守る側は3割の局面でしか繋げない**（得点に繋がる手が少ないので、
      // 仕留めそのものが立たない）。局面を足すときにここが減ると、
      // GK と CB からこの仕組みが静かに消える。
      for (final family in ScenarioFamily.values) {
        final pairs = ScenarioPool.forFamily(family).where(
          (s) =>
              s.options.any((o) => s.roleOf(o) == ComboRole.setup) &&
              s.options.any((o) => s.roleOf(o) == ComboRole.finish),
        );
        expect(pairs.length, greaterThanOrEqualTo(4), reason: family.name);
      }
    });
  });

  group('効き方', () {
    test('布石は、仕留めより深くない', () {
      // 布石そのものの見返りは、繋がったときの返しより小さく保つ。
      expect(
        Formulas.ratingPerSetup,
        lessThan(Formulas.ratingPerCombo),
      );
    });

    test('繋がると、通りやすくなり、決まりやすくなる', () {
      expect(Formulas.comboBonus, greaterThan(0));
      expect(Formulas.comboConversion, greaterThan(1));
    });
  });

  group('試合の中での繋がり方', () {
    /// 布石と仕留めが揃っている局面を1つ選び、その局面だけで試合を作る。
    (MatchInProgress, ScenarioOption setup, ScenarioOption finish) staged({
      required int ability,
    }) {
      final scenario = ScenarioPool.forFamily(ScenarioFamily.forward).firstWhere(
        (s) =>
            s.options.any((o) => s.roleOf(o) == ComboRole.setup) &&
            s.options.any((o) => s.roleOf(o) == ComboRole.finish),
      );
      final player = Player(
        name: 'テスト',
        position: Position.st,
        age: 26,
        potential: 90,
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: ability,
        }),
      );
      const club = Club(
        id: 'home',
        name: 'home',
        strength: 60,
        tier: 1,
        countryId: 'yamato',
      );
      final engine = MatchEngine(random: Random(9));
      final match = engine.start(
        matchday: 1,
        player: player,
        club: club,
        opponent: club,
        home: true,
        appearance: Appearance.start,
        forcedScenarios: [scenario],
      );
      return (
        match,
        scenario.options.firstWhere((o) => scenario.roleOf(o) == ComboRole.setup),
        scenario.options.firstWhere(
          (o) => scenario.roleOf(o) == ComboRole.finish,
        ),
      );
    }

    test('布石が通ると、仕留めの成功率が上がる', () {
      final (match, setup, finish) = staged(ability: 99);
      final before = match.chanceFor(finish);
      match.setupReady = true;
      final after = match.chanceFor(finish);
      // 上限（0.95）に当たらない範囲で見る。
      expect(after - before, greaterThan(0));
      expect(
        match.factorsFor(finish).any((f) => f.label == '布石が効いている'),
        isTrue,
      );
      // **布石そのものには乗らない。**
      expect(
        match.factorsFor(setup).any((f) => f.label == '布石が効いている'),
        isFalse,
      );
    });

    test('自動進行は、布石の先の価値を見ない', () {
      // 1手ぶんしか見ないので、布石の期待値は布石が乗っていても乗らなくても
      // 変わらない。**ここが、人が2手先を読んで上回れる隙間。**
      final (match, setup, _) = staged(ability: 80);
      final before = match.expectedDelta(setup);
      match.setupReady = true;
      expect(match.expectedDelta(setup), before);
    });

    test('仕留めにいけば、通っても外しても布石は消える', () {
      final (match, _, finish) = staged(ability: 20);
      match.setupReady = true;
      match.choose(finish);
      expect(match.setupReady, isFalse);
    });
  });
}
