import 'package:baseball_manager/game/calendar.dart';
import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p([int v = 30, Role role = Role.batter]) => Player(
      name: 't',
      role: role,
      age: 16,
      potential: 50,
      abilities: {for (final a in abilitiesOf(role)) a: v},
    );

void main() {
  _seasonTests();
  _roleFactorTests();
  test('全ての能力がどれかの種類に属し、役割の能力だけで種類が決まる', () {
    for (final a in Ability.values) {
      expect(Category.values, contains(categoryOf(a)));
    }
    expect(categoryOf(Ability.contact), Category.batting);
    expect(categoryOf(Ability.speed), Category.running);
    expect(categoryOf(Ability.stuff), Category.pitching);
  });

  test('高い能力ほど上げるのに経験点が要る', () {
    expect(expCost(80), greaterThan(expCost(20)));
    expect(expCost(0), greaterThan(0));
  });

  test('買うと能力が1上がり、その種類の経験点が減る', () {
    final r = buy(_p(), const ExpPool({Category.batting: 100}), Ability.power)!;
    expect(r.player.of(Ability.power), 31);
    expect(r.pool.of(Category.batting), 100 - expCost(30));
    expect(r.pool.of(Category.running), 0);
  });

  test('足りない・種類が違う・役割に無い・上限のときは買えない', () {
    expect(buy(_p(), const ExpPool({Category.batting: 1}), Ability.power), isNull);
    expect(buy(_p(), const ExpPool({Category.pitching: 999}), Ability.power), isNull);
    expect(buy(_p(), const ExpPool({Category.pitching: 999}), Ability.stuff), isNull);
    expect(buy(_p(99), const ExpPool({Category.batting: 999}), Ability.power), isNull);
  });

  test('買えるだけ買う。余りは次に持ち越せる', () {
    final r = buyAll(_p(), const ExpPool({Category.batting: 100}), Ability.power);
    expect(r.bought, greaterThan(1));
    expect(r.pool.of(Category.batting), lessThan(expCost(30 + r.bought)));
    expect(r.pool.of(Category.batting), greaterThanOrEqualTo(0));
  });

  test('おまかせは各種類の低い能力から順に振り、経験点を使い切る', () {
    final p = Player(
      name: 't',
      role: Role.batter,
      age: 16,
      potential: 50,
      abilities: {
        Ability.contact: 60,
        Ability.power: 20,
        Ability.eye: 60,
        Ability.speed: 40,
        Ability.fielding: 40,
      },
    );
    final r = autoSpendExp(p, const ExpPool({Category.batting: 80}));
    expect(r.player.of(Ability.power), greaterThan(20));
    expect(r.player.of(Ability.contact), 60); // 低いほうを先に上げる
    expect(r.pool.of(Category.batting), lessThan(expCost(r.player.of(Ability.power))));
  });

  test('やる気は気持ちで5段階に分かれ、高いほど倍率が大きい', () {
    expect(motivationOf(100), Motivation.great);
    expect(motivationOf(60), Motivation.good);
    expect(motivationOf(40), Motivation.normal);
    expect(motivationOf(20), Motivation.bad);
    expect(motivationOf(0), Motivation.terrible);
    final m = Motivation.values.map((e) => e.expMultiplier).toList();
    for (var i = 1; i < m.length; i++) {
      expect(m[i], greaterThan(m[i - 1]));
    }
  });

  test('経験点は保存して読み直せる。欠けていれば0', () {
    const pool = ExpPool({Category.batting: 12, Category.pitching: 3});
    final q = ExpPool.fromJson(pool.toJson());
    expect((q.of(Category.batting), q.of(Category.pitching)), (12, 3));
    expect(ExpPool.fromJson({}).total, 0);
  });

  test('高校とプロは月単位、それ以外は季節', () {
    expect(slotsPerYear(Stage.highSchool), 12);
    expect(slotsPerYear(Stage.pro), 12);
    expect(slotsPerYear(Stage.youth), 4);
    expect(slotsPerYear(Stage.juniorHigh), 4);
    expect(slotsPerYear(Stage.pathChoice), 4);
    expect(slotShare(Stage.pro), closeTo(1 / 3, 1e-9));
    expect(slotShare(Stage.youth), 1.0);
  });

  test('ターンの名前と大会のターン', () {
    expect(slotLabel(Stage.highSchool, 0), '4月');
    expect(slotLabel(Stage.highSchool, 11), '3月');
    expect(slotLabel(Stage.youth, 1), '夏');
    expect(isTournamentSlot(Stage.highSchool, 3), isTrue);
    expect(slotLabel(Stage.highSchool, 3), '7月');
    expect(isTournamentSlot(Stage.youth, 1), isTrue);
    for (final s in [Stage.highSchool, Stage.youth]) {
      final n = [for (var i = 0; i < slotsPerYear(s); i++) isTournamentSlot(s, i)];
      expect(n.where((x) => x).length, 1, reason: '$s');
    }
  });
}

void _roleFactorTests() {
  test('役割が違っても、1能力あたりの経験点の貯まり方が揃う', () {
    // 重点1つ(1.0)とそれ以外(0.25)の合計を、能力の数で割った平均が打者と同じになる。
    double perAbility(Role r) {
      final n = abilitiesOf(r).length;
      return (1 + 0.25 * (n - 1)) / n * roleExpFactor(r);
    }

    expect(roleExpFactor(Role.batter), closeTo(1.0, 1e-9));
    expect(perAbility(Role.pitcher), closeTo(perAbility(Role.batter), 1e-9));
    expect(perAbility(Role.twoWay), closeTo(perAbility(Role.batter), 1e-9));
    expect(roleExpFactor(Role.pitcher), lessThan(1.0));
  });
}

void _seasonTests() {
  test('季節: 月単位は4月始まり、季節ターンはそのまま', () {
    final m = [for (var i = 0; i < 12; i++) seasonOf(Stage.highSchool, i)];
    expect(m, [
      Season.spring, Season.spring, // 4・5月
      Season.summer, Season.summer, Season.summer, // 6〜8月
      Season.autumn, Season.autumn, Season.autumn, // 9〜11月
      Season.winter, Season.winter, Season.winter, // 12〜2月
      Season.spring, // 3月
    ]);
    expect([for (var i = 0; i < 4; i++) seasonOf(Stage.youth, i)], Season.values);
  });
}
