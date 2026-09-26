/// **出来高払い契約。**
///
/// 参考にしたのは野球のキャリアゲームの契約更改画面
/// （年俸-15%、条件達成で減額分の2倍）。こちらは的を
/// **監督の目標**（既にある仕組み）に置く。
///
/// 実測（753季）で目標の達成は 0/3 が14% / 1/3 が21% /
/// **2/3 が36% / 3/3 が29%**。2つで全額・3つで2.5倍にすると
/// 期待値は +1.3% で、下振れ −15%・上振れ +22.5%。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/objective.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

CareerState _career({double rating = 7.5, int goals = 2}) {
  final s = CareerEngine(random: Random(12)).startCareer(
    name: 'T',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  s.contractYears = 1;
  s.finances = const Finances(savings: 10000);
  for (var i = 0; i < s.fixtures.length; i++) {
    s.results.add(
      MatchResult(
        matchday: i + 1,
        opponentName: 'X',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: rating,
        goals: i < goals ? 1 : 0,
        assists: 0,
      ),
    );
  }
  return s;
}

void main() {
  group('値付け', () {
    test('2つ達成で減額分が戻り、3つで2.5倍になる', () {
      const cut = 200;
      expect(Formulas.incentivePay(cut, 0), 0);
      expect(Formulas.incentivePay(cut, 1), 0);
      expect(Formulas.incentivePay(cut, 2), cut);
      expect(Formulas.incentivePay(cut, 3), (cut * 2.5).round());
    });

    test('期待値はほぼ五分', () {
      // 実測の分布（2/3 が36%、3/3 が29%）で、賭けた1に対する戻り。
      const cut = 1000;
      final ev =
          Formulas.incentivePay(cut, 2) * 0.36 +
          Formulas.incentivePay(cut, 3) * 0.29;
      // 賭けた額（cut）に対して ±15% に収まる＝どちらかが常に正解にならない。
      expect(ev, greaterThan(cut * 0.85));
      expect(ev, lessThan(cut * 1.15));
    });
  });

  group('契約', () {
    test('出来高払いにすると、来季の年俸が削られる', () {
      final engine = CareerEngine(random: Random(12));
      final state = _career();
      final offer = engine.renewalOffer(state);
      final next = engine.advanceSeason(
        state,
        accepted: offer,
        incentive: true,
      );
      final cut = Formulas.incentiveCutOf(offer.salary);
      expect(next.salary, offer.salary - cut);
      expect(next.incentiveCut, cut);
    });

    test('普通にサインすれば、削られない', () {
      final engine = CareerEngine(random: Random(12));
      final state = _career();
      final offer = engine.renewalOffer(state);
      final next = engine.advanceSeason(state, accepted: offer);
      expect(next.salary, offer.salary);
      expect(next.incentiveCut, 0);
    });

    /// 同じ成績で、賭けた場合と賭けなかった場合の貯蓄を比べる。
    /// シーズンの収支そのものが動くので、差だけを見る。
    int savingsWith(
      int cut,
      SeasonObjective objective, {
      double rating = 7.5,
      int goals = 2,
    }) {
      final engine = CareerEngine(random: Random(12));
      final state = _career(rating: rating, goals: goals)
        ..incentiveCut = cut
        ..objective = objective;
      return engine
          .advanceSeason(state, accepted: engine.renewalOffer(state))
          .finances
          .savings;
    }

    test('3つ達成すれば、賭けたぶんの2.5倍が乗る', () {
      const easy = SeasonObjective(
        appearances: 1,
        contributions: 1,
        rating: 6.0,
      );
      expect(
        savingsWith(500, easy) - savingsWith(0, easy),
        Formulas.incentivePay(500, 3),
      );
    });

    test('届かなければ、何も戻らない', () {
      const hard = SeasonObjective(
        appearances: 99,
        contributions: 99,
        rating: 9.0,
      );
      expect(
        savingsWith(500, hard, rating: 5.8, goals: 0) -
            savingsWith(0, hard, rating: 5.8, goals: 0),
        0,
      );
    });
  });

  test('出来高の状態は保存を往復しても残り、無い保存データは0', () {
    final state = _career()..incentiveCut = 300;
    expect(CareerState.fromJson(state.toJson()).incentiveCut, 300);
    expect(
      CareerState.fromJson(state.toJson()..remove('incentiveCut')).incentiveCut,
      0,
    );
  });
}
