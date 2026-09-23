/// **監督に何を求めるか。**
///
/// 4種のうち、キャリアの結果を動かしているものは1つも無かった
/// （2026-09-23 の実測で全種がピーク 73.3〜74.1、基準 74.1）。
/// しかも「年俸交渉は通りやすく」と書いてある `negotiationBonus` は
/// **どこからも読まれていなかった**。表示と判定を合わせ直す。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/season.dart';

CareerState _career({int seed = 3, Directive directive = Directive.none}) {
  final s = CareerEngine(random: Random(seed)).startCareer(
    name: 'T',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  s.directive = directive;
  s.contractYears = 1;
  for (var i = 0; i < 24; i++) {
    s.results.add(
      MatchResult(
        matchday: i + 1,
        opponentName: 'X',
        home: true,
        scored: 1,
        conceded: 0,
        appearance: Appearance.start,
        rating: 7.4,
        goals: 0,
        assists: 0,
      ),
    );
  }
  return s;
}

void main() {
  group('求めたものは手に入り、別のものを諦める', () {
    test('条件を上げたいと言えば、提示そのものが上がる', () {
      int salary(Directive d) =>
          CareerEngine(random: Random(5))
              .renewalOffer(_career(directive: d))
              .salary;

      expect(salary(Directive.money), greaterThan(salary(Directive.none)));
      // 出場を優先してくれと言った選手は、条件では後回しになる。
      expect(salary(Directive.playingTime), lessThan(salary(Directive.none)));
    });

    test('条件を上げたいと言えば、上乗せ交渉も通りやすい', () {
      int raised(Directive d) {
        var count = 0;
        for (var seed = 0; seed < 200; seed++) {
          final engine = CareerEngine(random: Random(seed));
          final state = _career(directive: d);
          final (result, _) = engine.negotiate(
            state,
            engine.renewalOffer(state),
          );
          if (result == NegotiationResult.raised) count++;
        }
        return count;
      }

      expect(raised(Directive.money), greaterThan(raised(Directive.none)));
    });

    test('出場機会が欲しいと言えば、身の丈より強いクラブからは来ない', () {
      final state = _career(directive: Directive.playingTime);
      final offers = CareerEngine(random: Random(7))
          .offersFor(state)
          .where((o) => !o.loan && !o.isRenewal);
      expect(offers, isNotEmpty);
      for (final o in offers) {
        expect(
          o.club.strength,
          lessThanOrEqualTo(
            state.player.overall + Directive.playingTime.reachCap!,
          ),
        );
      }
    });

    test('勝ちたいと言えば、格下からは来ない', () {
      final state = _career(directive: Directive.winning);
      final offers = CareerEngine(random: Random(7))
          .offersFor(state)
          .where((o) => !o.loan && !o.isRenewal);
      expect(offers, isNotEmpty);
      for (final o in offers) {
        expect(
          o.club.strength,
          greaterThanOrEqualTo(
            state.player.overall + Directive.winning.reachFloor!,
          ),
        );
      }
    });

    test('何も言わなければ、範囲は狭まらない', () {
      expect(Directive.none.reachCap, isNull);
      expect(Directive.none.reachFloor, isNull);
      expect(Directive.none.reachBonus, 0);
      expect(Directive.none.salaryFactor, 1.0);
      expect(Directive.none.synergyFactor, 1.0);
    });

    test('どれも、得るものと失うものが対になっている', () {
      // 出場機会は身の丈まで、勝ちたいは格上まで。両方は取れない。
      expect(Directive.playingTime.reachCap, isNotNull);
      expect(Directive.winning.reachBonus, greaterThan(0));
      expect(Directive.winning.appearanceBonus, lessThan(0));
      // 条件は年俸と引き換えにロッカールーム。
      expect(Directive.money.salaryFactor, greaterThan(1.0));
      expect(Directive.money.teammatesDrift, lessThan(0));
      expect(Directive.money.synergyFactor, lessThan(1.0));
      // 育成は伸びと引き換えに出番。
      expect(Directive.develop.growthFactor, greaterThan(1.0));
      expect(Directive.develop.appearanceBonus, lessThan(0));
    });
  });
}
