import 'dart:convert';
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/characters.dart';
import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

Cast _cast([int seed = 1]) => Cast.initial(Random(seed), Role.batter, const {});

Game _game(int seed, {int? potential, Role role = Role.batter}) => Game.newGame(
    name: 't', role: role, rng: Random(seed), potential: potential);

/// 恋人が居る高校の最初のターンまで進める。
void _toHighSchool(Game g) {
  var steps = 0;
  while (g.stage != Stage.highSchool || g.phase != Phase.term) {
    if (++steps > 2000) fail('高校に着かない');
    g.autoSpend();
    switch (g.phase) {
      case Phase.term:
        g.choose(g.condition.fatigue >= 60 ? Plan.rest : Plan.train,
            Ability.contact);
      case Phase.event:
        g.resolveEvent(0);
      case Phase.pathChoice || Phase.retired:
        fail('高校の前に終わった');
    }
  }
}

void main() {
  _adminTests();
  test('始まりの顔ぶれ: 家族・ライバル・仲間3人・コーチ。名前は重ならない', () {
    final c = _cast();
    expect(c.family, isNotNull);
    expect(c.rival, isNotNull);
    expect(c.teammates, hasLength(3));
    expect(c.coach, isNotNull);
    expect(c.lover, isNull); // 恋人は高校から
    final names = c.members.map((m) => m.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('仲間は役割の能力を得意にする。二刀流は打者の能力から', () {
    for (final role in Role.values) {
      final c = Cast.initial(Random(3), role, const {});
      for (final m in c.teammates) {
        expect(abilitiesOf(role == Role.twoWay ? Role.batter : role),
            contains(m.specialty));
      }
    }
  });

  test('ライバルは年齢とともに強くなり、素質が高いほど強く、老いると落ちる', () {
    final lo = Character(id: 'r', name: 'a', kind: Kind.rival, talent: 40);
    final hi = Character(id: 'r', name: 'b', kind: Kind.rival, talent: 90);
    expect(rivalLevel(hi, 12), greaterThan(rivalLevel(hi, 8)));
    expect(rivalLevel(hi, 22), greaterThan(rivalLevel(hi, 12)));
    expect(rivalLevel(hi, 20), greaterThan(rivalLevel(lo, 20)));
    expect(rivalLevel(hi, 42), lessThan(rivalLevel(hi, 30)));
    for (var a = 6; a <= 46; a++) {
      expect(rivalLevel(hi, a), inInclusiveRange(0, 100));
    }
  });

  test('段階が変わると仲間とコーチが替わる。恋人は高校で1度だけ現れる', () {
    final c = _cast();
    final coach0 = c.coach!.name;
    c.rotate(Stage.juniorHigh, Random(2), Role.batter, const {});
    expect(c.lover, isNull);
    expect(c.teammates, hasLength(3));
    expect(c.coach!.name, isNot(coach0));
    expect(c.family, isNotNull);
    c.rotate(Stage.highSchool, Random(3), Role.batter, const {});
    expect(c.lover, isNotNull);
    final loverName = c.lover!.name;
    c.rotate(Stage.pro, Random(4), Role.batter, const {});
    expect(c.lover!.name, loverName);
    expect(c.members.where((m) => m.kind == Kind.lover), hasLength(1));
  });

  test('友情タッグは、同じ種類が得意で絆が高い仲間ほど起きやすい', () {
    double rate(int bond) {
      final c = Cast([
        Character(
            id: 'm',
            name: 'm',
            kind: Kind.teammate,
            bond: bond,
            specialty: Ability.power),
      ]);
      var n = 0;
      for (var s = 0; s < 2000; s++) {
        if (c.pickTagMate(Ability.contact, Random(s)) != null) n++; // 同じ打撃の種類
      }
      return n / 2000;
    }

    expect(rate(100), greaterThan(rate(0)));
    final other = Cast([
      Character(
          id: 'm',
          name: 'm',
          kind: Kind.teammate,
          bond: 100,
          specialty: Ability.speed),
    ]);
    for (var s = 0; s < 200; s++) {
      expect(other.pickTagMate(Ability.contact, Random(s)), isNull); // 種類が違う
    }
  });

  test('コーチが教える特性は、いま習得できるものだけ', () {
    for (var s = 0; s < 100; s++) {
      final t =
          teachableTrait(Stage.highSchool, const {Trait.clutch}, Random(s));
      expect(t, isNot(Trait.clutch));
      expect(t, isNotNull);
    }
    final all = {Trait.clutch, Trait.genius, Trait.starPower, Trait.sturdy};
    expect(teachableTrait(Stage.highSchool, all, Random(1)), isNull);
    expect(teachableTrait(Stage.retired, const {}, Random(1)), isNull);
  });

  test('登場人物は保存して読み直せる。欠けた項目は既定値', () {
    final c = _cast(7)..rival!.addBond(30);
    c.rivalWins = 2;
    final q = Cast.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(q.toJson()), jsonEncode(c.toJson()));
    expect(Character.fromJson({}).bond, 0);
    expect(Cast.fromJson({}).members, isEmpty);
  });

  test('絆は0〜100に収まる', () {
    final m = Character(id: 'a', name: 'a', kind: Kind.lover, bond: 95);
    m.addBond(50);
    expect(m.bond, 100);
    m.addBond(-500);
    expect(m.bond, 0);
  });

  test('条件のある出来事は、該当する相手が居るときだけ起きる', () {
    final bare = Cast([]);
    for (var s = 0; s < 3000; s++) {
      final e = drawEvent(Random(s), stage: Stage.youth, cast: bare);
      if (e != null) expect(e.when, isNull, reason: e.id);
    }
    final full = _cast()
      ..rotate(Stage.highSchool, Random(1), Role.batter, const {});
    final seen = <String>{};
    for (var s = 0; s < 3000; s++) {
      final e = drawEvent(Random(s), stage: Stage.highSchool, cast: full);
      if (e != null) seen.add(e.id);
    }
    expect(
        seen,
        containsAll(
            ['date', 'family', 'rival-talk', 'coach-extra', 'mate-invite']));
    // 引数なしの呼び出しでは条件つきは出ない(従来の動き)。
    for (var s = 0; s < 500; s++) {
      final e = drawEvent(Random(s));
      if (e != null) expect(e.when, isNull);
    }
  });

  test('デートに行くと恋人との絆が上がり、断ると下がる', () {
    final e = events.firstWhere((e) => e.id == 'date');
    final c = _cast()
      ..rotate(Stage.highSchool, Random(1), Role.batter, const {});
    final p = Player(name: 't', role: Role.batter, age: 16, potential: 50);
    e.choices[0].onCast!(c, Random(1));
    expect(c.lover!.bond, 22);
    final r =
        e.choices[0].apply(p, const Condition(morale: 50), Ability.contact);
    expect(r.condition.morale, 65);
    e.choices[1].onCast!(c, Random(1));
    expect(c.lover!.bond, 16);
  });

  test('コーチに教わり続けると、コツが貯まって特性を習得する', () {
    final g = _game(5, potential: 60);
    g.cast.coach!.tips = 0;
    final teaches = g.cast.coach!.teaches;
    expect(teaches, isNotNull);
    var turns = 0;
    while (!g.player.traits.contains(teaches)) {
      if (++turns > 40) fail('習得できない');
      if (g.phase == Phase.event) {
        g.resolveEvent(1);
        continue;
      }
      g.choose(Plan.lesson, Ability.contact);
    }
    expect(g.player.traits, contains(teaches));
    expect(g.cast.coach!.tips, lessThan(tipsNeeded));
    expect(g.log.any((l) => l.contains('習得')), isTrue);
  });

  test('教えられる特性が無いコーチからは、代わりに経験点をもらう', () {
    final g = _game(5);
    g.cast.members.removeWhere((m) => m.kind == Kind.coach);
    g.cast.members.add(Character(
        id: 'coach', name: '先生', kind: Kind.coach, tips: tipsNeeded - 1));
    final before = g.exp.total;
    g.choose(Plan.lesson, Ability.contact);
    expect(g.exp.total - before, greaterThanOrEqualTo(120));
    expect(g.cast.coach!.tips, 0);
  });

  test('高校に入ると恋人が現れる', () {
    final g = _game(2);
    expect(g.cast.lover, isNull);
    _toHighSchool(g);
    expect(g.cast.lover, isNotNull);
  });

  test('交流を選ぶと、家族(高校からは恋人)との絆が上がる', () {
    final g = _game(2);
    final before = g.cast.family!.bond;
    g.choose(Plan.social);
    expect(g.cast.family!.bond, before + 10);
    _toHighSchool(g);
    final b2 = g.cast.lover!.bond;
    g.choose(Plan.social);
    expect(g.cast.lover!.bond, b2 + 10);
  });

  test('夏の大会のたびにライバルと勝負し、勝ち負けが記録される', () {
    final g = _game(9);
    var steps = 0;
    while (g.achievements.length < 5) {
      if (++steps > 300) fail('大会が進まない');
      g.autoSpend();
      g.phase == Phase.event
          ? g.resolveEvent(0)
          : g.choose(Plan.train, Ability.contact);
    }
    expect(g.cast.rivalWins + g.cast.rivalLosses, g.achievements.length);
  });

  test('ライバルに勝つと気持ちが上がり、負けると下がる', () {
    // 強すぎる/弱すぎるライバルを置いて確かめる。
    for (final (talent, win) in [(0, true), (200, false)]) {
      final g = _game(4, potential: 50);
      g.cast.members.removeWhere((m) => m.kind == Kind.rival);
      g.cast.members.add(
          Character(id: 'rival', name: 'R', kind: Kind.rival, talent: talent));
      var steps = 0;
      while (g.achievements.isEmpty) {
        if (++steps > 30) fail('大会が進まない');
        if (g.phase == Phase.event) {
          g.resolveEvent(0);
          continue;
        }
        g.choose(Plan.rest);
      }
      expect(win ? g.cast.rivalWins : g.cast.rivalLosses, 1,
          reason: 'talent=$talent');
    }
  });

  test('友情タッグが起きると経験点が増える', () {
    final g = _game(6, potential: 60);
    for (final m in g.cast.teammates) {
      m.addBond(100);
    }
    g.cast.members
      ..removeWhere((m) => m.kind == Kind.teammate)
      ..add(Character(
          id: 'm',
          name: '相棒',
          kind: Kind.teammate,
          bond: 100,
          specialty: Ability.power));
    var tagged = 0;
    for (var i = 0; i < 6; i++) {
      final before = g.log.length;
      g.choose(Plan.train, Ability.contact);
      if (g.log.skip(before).any((l) => l.contains('友情タッグ'))) tagged++;
      if (g.phase == Phase.event) g.resolveEvent(0);
    }
    expect(tagged, greaterThan(0));
  });

  test('絆の深い恋人が居れば、引退時に結婚している', () {
    for (var s = 0; s < 100; s++) {
      final g = _game(s, potential: 100);
      var steps = 0;
      while (!(g.stage == Stage.pro && g.phase == Phase.term)) {
        if (g.phase == Phase.retired) break;
        if (++steps > 3000) fail('終わらない');
        g.autoSpend();
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
      if (g.stage != Stage.pro) continue;
      g.cast.lover!.bond = 90;
      g.retire();
      expect(g.ending!.married, isTrue);
      expect(g.ending!.partnerName, g.cast.lover!.name);
      return;
    }
    fail('プロになった選手がいない');
  });

  test('絆が浅いまま引退すると結婚しない', () {
    final g = _game(3, potential: 0);
    var steps = 0;
    while (g.phase != Phase.pathChoice) {
      if (++steps > 3000) fail('終わらない');
      g.autoSpend();
      g.phase == Phase.event
          ? g.resolveEvent(0)
          : g.choose(Plan.train, Ability.contact);
    }
    g.giveUp();
    expect(g.ending!.married, isFalse);
  });

  test('保存して読み直すと、登場人物も戻る。古いセーブには新しく作る', () {
    final g = _game(8);
    g.cast.rival!.addBond(20);
    final q = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(q.cast.rival!.name, g.cast.rival!.name);
    expect(q.cast.rival!.bond, g.cast.rival!.bond);
    final old = g.toJson()..remove('cast');
    final r = Game.fromJson(old, Random(1));
    expect(r.cast.rival, isNotNull);
  });
}

void _adminTests() {
  test('管理者: 素質・特性・能力を、ルールを無視して書き換えられる', () {
    final g = _game(5, potential: 50);
    g.adminSetPotential(100);
    expect(g.player.potential, 100);
    g.adminSetPotential(999);
    expect(g.player.potential, 100);
    g.adminSetPotential(-5);
    expect(g.player.potential, 0);

    // 5つ・矛盾する組み合わせでも置ける。
    final all = {
      Trait.lateBloomer,
      Trait.earlyBloomer,
      Trait.sturdy,
      Trait.glassBody,
      Trait.clutch
    };
    g.adminSetTraits(all);
    expect(g.player.traits, all);
    expect(g.player.traits.length, greaterThan(maxTraits));
    g.adminSetTraits({});
    expect(g.player.traits, isEmpty);

    g.adminSetAbility(Ability.power, 80);
    expect(g.player.of(Ability.power), 80);
    g.adminSetAbility(Ability.power, 500);
    expect(g.player.of(Ability.power), 99);
    g.adminSetAbility(Ability.stuff, 70); // 打者に投手の能力は無い
    expect(g.player.abilities.containsKey(Ability.stuff), isFalse);
  });

  test('管理者: 素質は伸びに効く(素質を上げると経験点が増える)', () {
    int gained(int potential) {
      final g = _game(5, potential: 50);
      g.adminSetPotential(potential);
      g.choose(Plan.train, Ability.contact);
      return g.lastGain.values.fold(0, (a, b) => a + b);
    }

    expect(gained(100), greaterThan(gained(0)));
  });

  test('管理者: コツを満タンにすると、その場で特性を習得する。上限4つでも入る範囲は通常ルール', () {
    final g = _game(5);
    g.adminSetCoachTeaches(Trait.genius);
    g.adminSetCoachTips(2);
    expect(g.player.traits, isNot(contains(Trait.genius)));
    expect(g.cast.coach!.tips, 2);
    g.adminSetCoachTips(tipsNeeded);
    expect(g.player.traits, contains(Trait.genius));
    expect(g.cast.coach!.tips, 0); // 習得したらコツは0に戻る
    expect(g.cast.coach!.teaches, Trait.genius);
  });

  test('管理者: コーチの教える特性を差し替えると、絆などはそのまま', () {
    final g = _game(5);
    final before = g.cast.coach!;
    g.adminSetCoachTeaches(Trait.sturdy);
    final after = g.cast.coach!;
    expect(after.teaches, Trait.sturdy);
    expect((after.name, after.id, after.bond),
        (before.name, before.id, before.bond));
    g.adminSetCoachTeaches(null);
    expect(g.cast.coach!.teaches, isNull);
  });

  test('管理者: 経験点を足す・0にする。0未満にはならない', () {
    final g = _game(5);
    g.adminAddExp(500);
    for (final c in Category.values) {
      expect(g.exp.of(c), 500);
    }
    g.adminAddExp(-100000);
    expect(g.exp.total, 0);
  });

  test('管理者の書き換えは保存され、読み直しても残る', () {
    final g = _game(5);
    g.adminSetPotential(88);
    g.adminSetTraits({Trait.clutch, Trait.genius});
    final q = Game.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1));
    expect(q.player.potential, 88);
    expect(q.player.traits, {Trait.clutch, Trait.genius});
  });
}
