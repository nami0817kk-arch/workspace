import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/training.dart';
import 'package:flutter_test/flutter_test.dart';

Player _kid({int potential = 50, Role role = Role.batter}) =>
    Player(name: 'テスト', role: role, age: 6, potential: potential);

Player _years(Player p, Ability focus, int n, int seed) {
  final rng = Random(seed);
  for (var i = 0; i < n; i++) {
    p = advanceYear(p, focus, rng);
  }
  return p;
}

void main() {
  _twoWayTests();
  test('1年で年齢が1つ進む', () {
    final p = advanceYear(_kid(), Ability.contact, Random(1));
    expect(p.age, 7);
  });

  test('重点にした能力のほうが伸びる(平均)', () {
    var focus = 0, other = 0;
    for (var s = 0; s < 200; s++) {
      final p = _years(_kid(), Ability.power, 6, s);
      focus += p.of(Ability.power);
      other += p.of(Ability.speed);
    }
    expect(focus, greaterThan(other));
  });

  test('素質が高いほど伸びる(平均)', () {
    var lo = 0, hi = 0;
    for (var s = 0; s < 200; s++) {
      lo += _years(_kid(potential: 10), Ability.contact, 12, s).of(Ability.contact);
      hi += _years(_kid(potential: 90), Ability.contact, 12, s).of(Ability.contact);
    }
    expect(hi, greaterThan(lo));
  });

  test('能力は0〜99に収まる', () {
    final p = _years(_kid(potential: 100), Ability.contact, 45, 7);
    for (final a in abilitiesOf(Role.batter)) {
      expect(p.of(a), inInclusiveRange(0, abilityCap));
    }
  });

  test('30代後半は衰える', () {
    final p = Player(
      name: 'ベテラン',
      role: Role.pitcher,
      age: 35,
      potential: 50,
      abilities: {Ability.stuff: 80, Ability.control: 80, Ability.stamina: 80},
    );
    final q = _years(p, Ability.control, 5, 3);
    expect(q.of(Ability.stuff), lessThan(80));
  });

  test('保存して読み直しても同じ。欠けた項目は既定値で読める', () {
    final p = _years(_kid(), Ability.eye, 3, 5);
    final q = Player.fromJson(p.toJson());
    expect(q.age, p.age);
    expect(q.abilities, p.abilities);
    final bare = Player.fromJson({'name': 'x'});
    expect(bare.age, 6);
    expect(bare.potential, 50);
  });
}

void _twoWayTests() {
  Player pro() => Player(
        name: '投手',
        role: Role.pitcher,
        age: 20,
        potential: 60,
        abilities: {Ability.stuff: 70, Ability.control: 60, Ability.stamina: 55},
      );

  test('二刀流にできるのはプロの段階だけ', () {
    expect(() => switchRole(pro(), Role.twoWay, Stage.highSchool), throwsStateError);
    expect(() => switchRole(pro(), Role.twoWay, Stage.pathChoice), throwsStateError);
    final t = switchRole(pro(), Role.twoWay, Stage.pro);
    expect(t.role, Role.twoWay);
  });

  test('二刀流は両方の能力を持ち、元の能力は保たれる', () {
    final t = switchRole(pro(), Role.twoWay, Stage.pro);
    expect(t.abilities.keys.toSet(), abilitiesOf(Role.twoWay).toSet());
    expect(t.of(Ability.stuff), 70);
    expect(t.of(Ability.contact), switchStartLevel);
  });

  test('二刀流は本職より伸びが小さい(平均)', () {
    var one = 0, two = 0;
    for (var s = 0; s < 200; s++) {
      final a = Player(name: 'a', role: Role.batter, age: 18, potential: 60);
      final b = switchRole(a, Role.twoWay, Stage.pro).copyWith(role: Role.twoWay);
      one += _years(a, Ability.contact, 4, s).of(Ability.contact);
      two += _years(b, Ability.contact, 4, s).of(Ability.contact);
    }
    expect(two, lessThan(one));
  });

  test('二刀流は打者にも投手にもなれ、本職に戻せる', () {
    final t = switchRole(pro(), Role.twoWay, Stage.pro);
    expect(t.toBatter().contact, switchStartLevel);
    expect(t.toPitcher().stuff, 70);
    final back = switchRole(t, Role.batter, Stage.pro);
    expect(back.abilities.keys.toSet(), batterAbilities.toSet());
  });

  test('二刀流も保存して読み直せる', () {
    final t = switchRole(pro(), Role.twoWay, Stage.pro);
    final q = Player.fromJson(t.toJson());
    expect(q.role, Role.twoWay);
    expect(q.abilities, t.abilities);
  });
}
