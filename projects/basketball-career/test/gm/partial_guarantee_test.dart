import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Career atContracts() {
    final c = careerAt(6, 8);
    var guard = 0;
    while (c.phase != Phase.seasonEnd && guard++ < 200) {
      botStep(c);
    }
    c.toOffseason();
    guard = 0;
    while (c.phase != Phase.contracts && guard++ < 200) {
      botStep(c);
    }
    return c;
  }

  test('一部保証は、2年以上の契約で29歳以上の選手だけ。選ぶと年俸が8%高く、保証は半分になる', () {
    final c = atContracts();
    final p = c.me.roster.first
      ..age = 31
      ..morale = 80;
    expect(c.partialOk(p, 3), isTrue);
    expect(c.partialOk(p, 1), isFalse);
    p.age = 25;
    expect(c.partialOk(p, 3), isFalse);
    p.age = 31;
    c.expiring = [p.id];
    final base = c.askOf(p, c.me).salary;
    c.partialNext = true;
    expect(c.offer(p.id, 3, 1.0), isTrue);
    expect(p.guarantee, 50);
    expect(p.salary, greaterThanOrEqualTo(base));
    expect(c.partialNext, isFalse, reason: '申し出たら元に戻る');
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.me.roster.firstWhere((x) => x.id == p.id).guarantee, 50);
  });

  test('一部保証の選手を放すと、2年目以降の年俸は保証の割合だけ残る', () {
    final c = careerAt(6, 8);
    c.phase = Phase.preseason;
    c.expiring = [];
    c.me.deadCap = 0;
    c.me.deadLater = [];
    final p = c.me.roster.first
      ..salary = 100
      ..years = 3
      ..ovr = 50
      ..morale = 70
      ..guarantee = 50;
    final cost = c.releaseCost(p, ReleaseMode.full);
    expect(cost.now, 100);
    expect(cost.later, [50, 50]);
    p.guarantee = 100;
    expect(c.releaseCost(p, ReleaseMode.full).later, [100, 100]);
    p.guarantee = 50;
    final stretch = c.releaseCost(p, ReleaseMode.stretch);
    expect(stretch.now + stretch.later.fold<int>(0, (a, b) => a + b), greaterThanOrEqualTo(200));
    expect(stretch.now + stretch.later.fold<int>(0, (a, b) => a + b), lessThan(300));
  });
}
