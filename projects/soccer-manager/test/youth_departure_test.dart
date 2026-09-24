import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/youth_departure_engine.dart';
import 'package:soccer_manager/models/player.dart';

/// 有望株がユースを去る仕組みの検査。
///
/// これが無いと、上げる時期を決めずに置いておくのが常に最善になり、
/// 「いつ一軍へ上げるか」という判断が成立しない。
void main() {
  Player prospect({required int age, int potential = 80, int? overall}) {
    final p = PlayerGenerator.generate(
      position: Position.mc,
      ageOverride: age,
      strengthTier: 50,
    );
    p.potential = potential;
    if (overall != null) {
      // 総合力は属性から決まるので、伸びしろを作りたいときは潜在で調整する。
      p.potential = overall + (potential - overall);
    }
    return p;
  }

  test('若いうちは去らない', () {
    final p = prospect(age: YouthDepartureEngine.restlessAge - 1);
    expect(
      YouthDepartureEngine.weeklyDepartureChance(p,
          facilityLevel: 1, hasMentor: false),
      0,
    );
  });

  test('年齢が上がるほど去りやすい', () {
    final young = prospect(age: YouthDepartureEngine.restlessAge);
    final old = prospect(age: YouthDepartureEngine.departureAge);
    double chance(Player p) => YouthDepartureEngine.weeklyDepartureChance(p,
        facilityLevel: 1, hasMentor: false);
    expect(chance(old), greaterThan(chance(young)));
  });

  test('メンターが付いていると去りにくい', () {
    final p = prospect(age: YouthDepartureEngine.departureAge);
    final withMentor = YouthDepartureEngine.weeklyDepartureChance(p,
        facilityLevel: 1, hasMentor: true);
    final without = YouthDepartureEngine.weeklyDepartureChance(p,
        facilityLevel: 1, hasMentor: false);
    expect(withMentor, lessThan(without));
  });

  test('ユース施設が良いほど引き止められる', () {
    final p = prospect(age: YouthDepartureEngine.departureAge);
    double chance(int level) => YouthDepartureEngine.weeklyDepartureChance(p,
        facilityLevel: level, hasMentor: false);
    expect(chance(5), lessThan(chance(1)));
  });

  test('去った選手は名簿から消え、補償金が付く', () {
    // 確率に左右されないよう、必ず去る年齢で何度も回す。
    final prospects = <Player>[
      for (var i = 0; i < 40; i++) prospect(age: 21, potential: 95),
    ];
    final before = prospects.length;

    var departures = <YouthDeparture>[];
    for (var week = 0; week < 60 && prospects.isNotEmpty; week++) {
      departures.addAll(
        YouthDepartureEngine.resolveWeekly(prospects, facilityLevel: 1),
      );
    }

    expect(departures, isNotEmpty, reason: '60週回しても誰も去らない');
    expect(prospects.length, before - departures.length,
        reason: '去った選手が名簿に残っている');
    for (final d in departures) {
      expect(d.compensation, greaterThan(0), reason: '補償金が0');
    }
  });

  test('伸びしろの大きい選手は引き抜きの形になる', () {
    final prospects = <Player>[
      for (var i = 0; i < 40; i++) prospect(age: 21, potential: 99),
    ];
    // 総合力を低く保ち、伸びしろを確実に作る。
    for (final p in prospects) {
      for (final k in p.attributes.keys.toList()) {
        p.setAttributeValue(k, 30);
      }
    }

    final departures = <YouthDeparture>[];
    for (var week = 0; week < 60 && prospects.isNotEmpty; week++) {
      departures.addAll(
        YouthDepartureEngine.resolveWeekly(prospects, facilityLevel: 1),
      );
    }

    expect(departures, isNotEmpty);
    expect(departures.every((d) => d.poached), isTrue);
  });
}
