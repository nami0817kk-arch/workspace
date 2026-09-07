import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/aptitude.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/injury.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

final flat = Attributes(
  pace: 50,
  shooting: 50,
  passing: 50,
  dribbling: 50,
  defending: 50,
  physical: 50,
  goalkeeping: 50,
);

CareerState career({int seed = 3, int age = 20}) =>
    CareerEngine(random: Random(seed)).startCareer(
        name: 'T', position: Position.cm, age: age, agent: Agent.pool.first);

void fillSeason(CareerState state, {double rating = 7.2, int matches = 20}) {
  for (var i = 0; i < matches; i++) {
    state.results.add(MatchResult(
      matchday: i + 1,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: rating,
      goals: 1,
      assists: 0,
    ));
  }
}

void main() {
  group('ポジション適性', () {
    test('本職は100で、近いポジションほど高い', () {
      final a = Aptitude.initial(Position.cm);
      expect(a[Position.cm], Aptitude.max);
      expect(a[Position.dm], greaterThan(a[Position.st]));
      expect(a.penaltyFor(Position.cm), 0);
      expect(a.penaltyFor(Position.st), greaterThan(0));
    });

    test('本職以外で出ると総合力が落ちる', () {
      final p = Player(
        name: 'P',
        age: 24,
        position: Position.cm,
        attributes: flat,
        potential: 90,
        aptitude: Aptitude.initial(Position.cm),
      );
      expect(p.overall, flat.overallFor(Position.cm));
      expect(p.overallAt(Position.st), lessThan(flat.overallFor(Position.st)));
    });

    test('出続ければ適性は上がる', () {
      var a = Aptitude.initial(Position.cm);
      final before = a[Position.dm];
      for (var i = 0; i < 20; i++) {
        a = a.playedAt(Position.dm);
      }
      expect(a[Position.dm], greaterThan(before));
      expect(a[Position.dm], lessThanOrEqualTo(Aptitude.max));
    });

    test('適性が足りないポジションには移れない', () {
      final a = Aptitude.initial(Position.gk);
      expect(a.canConvert(Position.st), isFalse);
      expect(a.canConvert(Position.gk), isTrue);
    });

    test('適性を持たない保存データは、今のポジションを本職として読む', () {
      final a = Aptitude.fromJson(null, Position.wg);
      expect(a[Position.wg], Aptitude.max);

      final p = Player(
        name: 'P',
        age: 24,
        position: Position.wg,
        attributes: flat,
        potential: 90,
        aptitude: Aptitude.initial(Position.wg),
      );
      final json = p.toJson()..remove('aptitude');
      expect(Player.fromJson(json).overall, p.overall);
    });
  });

  group('監督', () {
    test('戦術に合う選手は出場機会で得をする', () {
      final passer = Attributes(
        pace: 40,
        shooting: 40,
        passing: 80,
        dribbling: 75,
        defending: 40,
        physical: 40,
      );
      const possession =
          Manager(name: 'A', tactic: Tactic.possession, demand: 3);
      const press = Manager(name: 'B', tactic: Tactic.press, demand: 3);

      expect(possession.fitFor(passer, Position.cm), greaterThan(0));
      expect(press.fitFor(passer, Position.cm), lessThan(0));
      expect(possession.appearanceBonus(passer, Position.cm),
          greaterThan(press.appearanceBonus(passer, Position.cm)));
    });

    test('バランス型は誰に対しても中庸', () {
      const balanced =
          Manager(name: 'C', tactic: Tactic.balanced, demand: 3);
      expect(balanced.fitFor(flat, Position.cm), 0);
    });

    test('監督が代われば信頼は白紙に戻る', () {
      final engine = CareerEngine(random: Random(5));
      final state = career(age: 24);
      fillSeason(state);
      state.relations = const Relations(manager: 90, teammates: 70);

      // 移籍すれば必ず監督は代わる。
      final target = state.league.first;
      final next = engine.advanceSeason(
        state,
        accepted: TransferOffer(
          club: target,
          reason: 'x',
          salary: state.salary,
          role: '主力',
          years: 3,
        ),
      );
      expect(next.manager!.name, isNot(state.manager!.name));
      expect(next.relations.manager, 50);
      // 信頼の厚かった監督は恩師として残る。
      expect(next.mentorManager, state.manager!.name);
    });

    test('残留して監督が続けば在任年数が伸びる', () {
      var sawTenure = false;
      for (var seed = 0; seed < 30 && !sawTenure; seed++) {
        final engine = CareerEngine(random: Random(seed));
        final state = career(seed: seed, age: 24);
        fillSeason(state);
        final next =
            engine.advanceSeason(state, accepted: engine.renewalOffer(state));
        if (next.manager!.name == state.manager!.name) {
          expect(next.manager!.tenure, state.manager!.tenure + 1);
          sawTenure = true;
        }
      }
      expect(sawTenure, isTrue);
    });
  });

  group('チームメイト', () {
    test('相方は呼吸が合うほど味方を活かす手が通る', () {
      const green = Teammate(
          name: 'A', kind: TeammateKind.partner, overall: 70, age: 24);
      final tuned = green.withSynergy(90);
      expect(tuned.synergyBonus, greaterThan(green.synergyBonus));
      expect(tuned.synergyLabel, isNot(green.synergyLabel));
    });

    test('競争相手と相方は別の役割', () {
      const rival =
          Teammate(name: 'B', kind: TeammateKind.rival, overall: 70, age: 24);
      expect(rival.withSynergy(90).synergyBonus, 0);
    });

    test('メンターは若いうちだけ効く', () {
      const mentor =
          Teammate(name: 'C', kind: TeammateKind.mentor, overall: 78, age: 33);
      expect(mentor.mentorFactor(21), greaterThan(1.0));
      expect(mentor.mentorFactor(28), 1.0);
    });

    test('移籍すると同僚は総入れ替えになり、呼吸も一からになる', () {
      final engine = CareerEngine(random: Random(8));
      final state = career(age: 24);
      fillSeason(state);
      state.partner = state.partner!.withSynergy(80);

      final next = engine.advanceSeason(
        state,
        accepted: TransferOffer(
          club: state.league.first,
          reason: 'x',
          salary: state.salary,
          role: '主力',
          years: 3,
        ),
      );
      expect(next.partner!.synergy, 0);
    });
  });

  group('同期のライバル', () {
    test('別のクラブで勝手に積み上げていく', () {
      final random = Random(2);
      var rival = Rival.roll(random, overall: 62, clubName: 'X');
      final before = rival.goals;
      for (var i = 0; i < 5; i++) {
        rival = rival.advanced(random, clubName: 'X');
      }
      expect(rival.goals, greaterThan(before));
      expect(rival.caps, greaterThan(0));
    });

    test('先を行かれているかが分かる', () {
      const rival =
          Rival(name: 'R', clubName: 'X', overall: 80, goals: 20, caps: 10);
      expect(rival.leads(70), isTrue);
      expect(rival.leads(85), isFalse);
    });
  });

  group('性格への効き', () {
    test('同期に先を行かれると野心が上がり、メンターの下では姿勢が付く', () {
      final state = career(age: 20);
      fillSeason(state);
      state.rival = Rival(
          name: 'R', clubName: 'X', overall: state.player.overall + 10);
      final person = Person(random: Random(1));
      final evolved = person.evolve(state);
      expect(evolved.ambition,
          greaterThan(state.player.personality.ambition));
      expect(evolved.professionalism,
          greaterThan(state.player.personality.professionalism));
    });
  });

  group('クラブの環境', () {
    test('格の高いクラブほど練習環境と医療が良い', () {
      const big = Club(id: 'a', name: 'A', strength: 85, tier: 1);
      const small = Club(id: 'b', name: 'B', strength: 45, tier: 3);
      final rich = Facilities.of(big, prestige: 5);
      final poor = Facilities.of(small, prestige: 1);

      expect(rich.training, greaterThan(poor.training));
      expect(rich.growthFactor, greaterThan(poor.growthFactor));
      expect(rich.recoveryFactor, lessThan(poor.recoveryFactor));
    });
  });

  group('リハビリ方針', () {
    const injury = Injury(
        name: '肉離れ', severity: InjurySeverity.moderate, matchesOut: 10);

    test('強行すれば早く戻るが、再発しやすい', () {
      expect(RehabPlan.rush.lengthFor(injury),
          lessThan(RehabPlan.standard.lengthFor(injury)));
      expect(RehabPlan.cautious.lengthFor(injury),
          greaterThan(RehabPlan.standard.lengthFor(injury)));
      expect(RehabPlan.rush.relapseFactor,
          greaterThan(RehabPlan.cautious.relapseFactor));
      expect(RehabPlan.cautious.conditionOnReturn,
          greaterThan(RehabPlan.rush.conditionOnReturn));
    });

    test('どんなに強行しても1試合は休む', () {
      const light =
          Injury(name: '打撲', severity: InjurySeverity.light, matchesOut: 1);
      expect(RehabPlan.rush.lengthFor(light), greaterThanOrEqualTo(1));
    });
  });

  group('方針', () {
    test('優先したぶん、別のものを諦める', () {
      expect(Directive.playingTime.appearanceBonus, greaterThan(0));
      expect(Directive.develop.appearanceBonus, lessThan(0));
      expect(Directive.develop.growthFactor, greaterThan(1.0));
      expect(Directive.money.negotiationBonus, greaterThan(0));
      expect(Directive.money.teammatesDrift, lessThan(0));
      expect(Directive.winning.managerDrift, greaterThan(0));
      expect(Directive.none.appearanceBonus, 0);
    });
  });

  test('人と方針は保存を往復しても残り、無い保存データも読める', () {
    final state = career();
    state.directive = Directive.playingTime;
    state.rehab = RehabPlan.rush;
    state.rehabWatch = 2;
    state.mentorManager = '恩師';
    state.partner = state.partner!.withSynergy(55);

    final r = CareerState.fromJson(state.toJson());
    expect(r.manager!.name, state.manager!.name);
    expect(r.manager!.tactic, state.manager!.tactic);
    expect(r.directive, Directive.playingTime);
    expect(r.rehab, RehabPlan.rush);
    expect(r.rehabWatch, 2);
    expect(r.mentorManager, '恩師');
    expect(r.partner!.synergy, 55);
    expect(r.rival!.name, state.rival!.name);

    final legacy = CareerState.fromJson(state.toJson()
      ..remove('manager')
      ..remove('directive')
      ..remove('competitor')
      ..remove('partner')
      ..remove('mentor')
      ..remove('rival')
      ..remove('rehab')
      ..remove('rehabWatch')
      ..remove('mentorManager'));
    expect(legacy.manager, isNull);
    expect(legacy.directive, Directive.none);
    expect(legacy.rehab, RehabPlan.standard);
    expect(legacy.partner, isNull);
  });
}
