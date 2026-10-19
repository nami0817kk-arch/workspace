import 'dart:math';

import 'package:baseball_manager/game/achievements.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/invest.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/records.dart';
import 'package:baseball_manager/game/snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Game _pro(int seed) {
  final g = Game.newGame(
      name: 't', role: Role.batter, rng: Random(seed), potential: 100);
  var n = 0;
  while (g.phase != Phase.retired && n++ < 4000) {
    g.autoSpend();
    if (g.stage == Stage.pro && g.phase == Phase.term) break;
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice:
        g.chooseRoute(Course.university);
      case Phase.retired:
        break;
    }
  }
  return g;
}

Game _proGame() {
  for (var s = 0; s < 60; s++) {
    final g = _pro(s);
    if (g.stage == Stage.pro) return g;
  }
  fail('プロになれない');
}

void main() {
  group('投資の式', () {
    test('費用は上がるほど高く、最大レベルは null', () {
      expect(investCost(0), 2000);
      expect(investCost(1), 6000);
      expect(investCost(2), 15000);
      expect(investCost(3), isNull);
    });

    test('効果は レベルとともに大きくなる', () {
      expect(trainerMultiplier(0), 1.0);
      expect(trainerMultiplier(3), closeTo(1.18, 1e-9));
      expect(dietitianMultiplier(3), closeTo(1.6, 1e-9));
      expect(medicalFactor(0), 1.0);
      expect(medicalFactor(1), closeTo(0.8, 1e-9));
      expect(medicalFactor(3), closeTo(0.512, 1e-9));
    });

    test('資産の表記', () {
      expect(fmtMoney(0), '0円');
      expect(fmtMoney(3500), '3500万円');
      expect(fmtMoney(12000), '1億2000万円');
      expect(fmtMoney(30000), '3億円');
    });
  });

  group('練習への効き方', () {
    Player bat() => Player(
        name: 't',
        role: Role.batter,
        age: 22,
        potential: 70,
        abilities: {for (final a in batterAbilities) a: 50});

    test('専属トレーナーで、貯まる経験点が増える', () {
      int exp(double bonus) {
        var t = 0;
        for (var s = 0; s < 30; s++) {
          final r = playTerm(
              bat(), const Condition(), Plan.train, Ability.contact, Random(s),
              trainBonus: bonus);
          t += r.exp.values.fold(0, (a, b) => a + b);
        }
        return t;
      }

      expect(exp(1.18), greaterThan(exp(1.0)));
    });

    test('栄養士で、休養の疲れの抜けが大きくなる', () {
      const tired = Condition(fatigue: 80);
      final base =
          playTerm(bat(), tired, Plan.rest, Ability.contact, Random(1));
      final more = playTerm(bat(), tired, Plan.rest, Ability.contact, Random(1),
          recoveryBonus: 1.6);
      expect(more.condition.fatigue, lessThan(base.condition.fatigue));
    });

    test('医療チームで、怪我が減る', () {
      int hurt(double f) {
        var n = 0;
        for (var s = 0; s < 3000; s++) {
          final r = playTerm(bat(), const Condition(fatigue: 70), Plan.special,
              Ability.contact, Random(s),
              injuryFactor: f);
          if (r.gotInjured) n++;
        }
        return n;
      }

      expect(hurt(0.512), lessThan(hurt(1.0)));
    });
  });

  group('ゲームの中', () {
    test('プロの年俸が資産になる(年ごとの年俸の合計)', () {
      final g = _proGame();
      expect(g.money, 0);
      var k = 0;
      while (g.phase != Phase.retired && k++ < 3000) {
        g.autoSpend();
        g.phase == Phase.event
            ? g.resolveEvent(0)
            : g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
                Ability.contact);
      }
      final pro = g.records.where((r) => r.stage == Stage.pro).toList();
      // 年俸の合計に、人気しだいでCM出演料が加わる。
      expect(g.money, greaterThanOrEqualTo(careerEarnings(pro)));
      expect(g.money, greaterThan(0));
    });

    test('投資すると資産が減ってレベルが上がる。足りなければ買えず、最大でも買えない', () {
      final g = _proGame();
      expect(g.buyInvest(Invest.trainer), isFalse); // 資産が無い
      g.money = 100000;
      expect(g.buyInvest(Invest.trainer), isTrue);
      expect(g.money, 100000 - 2000);
      expect(g.investLevel(Invest.trainer), 1);
      expect(g.buyInvest(Invest.trainer), isTrue);
      expect(g.buyInvest(Invest.trainer), isTrue);
      expect(g.investLevel(Invest.trainer), 3);
      expect(g.buyInvest(Invest.trainer), isFalse); // 最大
      expect(g.money, 100000 - 2000 - 6000 - 15000);
      expect(g.log.any((l) => l.contains('専属トレーナーに投資した(Lv1)')), isTrue);
    });

    test('プロでない間は投資できない', () {
      final g = Game.newGame(
          name: 't', role: Role.batter, rng: Random(1), potential: 80);
      expect(g.canInvest, isFalse);
      expect(() => g.buyInvest(Invest.medical), throwsStateError);
    });

    test('保存して読み直しても資産と投資が残る。古いセーブは0', () {
      final g = _proGame();
      g.money = 50000;
      g.buyInvest(Invest.dietitian);
      g.buyInvest(Invest.dietitian);
      final back = Game.fromJson(g.toJson(), Random(1));
      expect(back.money, g.money);
      expect(back.investLevel(Invest.dietitian), 2);
      final old = g.toJson()
        ..remove('money')
        ..remove('invests');
      final o = Game.fromJson(old, Random(1));
      expect(o.money, 0);
      expect(o.investLevel(Invest.dietitian), 0);
      // 壊れたレベルは範囲に収める
      final bad = g.toJson()..['invests'] = {'trainer': 99, 'unknown': 5};
      expect(Game.fromJson(bad, Random(1)).investLevel(Invest.trainer),
          maxInvestLevel);
    });

    test('投資しなければ、これまでと同じ(バランスを変えない)', () {
      expect(trainerMultiplier(0), 1.0);
      expect(dietitianMultiplier(0), 1.0);
      expect(medicalFactor(0), 1.0);
    });
  });

  group('実績', () {
    PlayerSnapshot snap(int money, int total) => PlayerSnapshot(
          name: 't',
          role: Role.batter,
          age: 40,
          stage: Stage.retired,
          potential: 50,
          abilities: const {Ability.contact: 50},
          traits: const {},
          records: const [],
          events: const [],
          overallHistory: const [10, 20],
          money: money,
          investTotal: total,
        );

    test('資産家・万全の体制', () {
      expect(earnedBy(snap(99999, 8)), isNot(contains('rich')));
      expect(earnedBy(snap(100000, 8)), contains('rich'));
      expect(earnedBy(snap(0, 8)), isNot(contains('full-support')));
      expect(earnedBy(snap(0, 9)), contains('full-support'));
      final back = PlayerSnapshot.fromJson(snap(123, 4).toJson());
      expect(back.money, 123);
      expect(back.investTotal, 4);
      expect(PlayerSnapshot.fromJson({}).money, 0);
    });
  });
}
