import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts() {
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

Player _young(Career c) => c.freeAgents.firstWhere((p) => p.exp <= twoWayMaxExp, orElse: () => c.freeAgents.first..exp = 1);

void main() {
  group('2ウェイ契約', () {
    test('取ると登録にも年俸の合計にも数えず、3人まで', () {
      final c = _atContracts();
      final roster = c.me.roster.length;
      final pay = c.me.payroll;
      final ids = <int>[];
      for (final p in c.freeAgents.toList()) {
        p.exp = 1;
        if (ids.length < twoWayMax) {
          c.signTwoWay(p.id);
          if (c.me.twoWay.contains(p)) ids.add(p.id);
        }
      }
      expect(c.me.twoWay.length, twoWayMax);
      expect(c.me.roster.length, roster);
      expect(c.me.payroll, pay);
      final extra = c.freeAgents.first..exp = 1;
      expect(c.twoWayProblem(extra), isNotNull);
      c.signTwoWay(extra.id);
      expect(c.me.twoWay.length, twoWayMax);
      for (final p in c.me.twoWay) {
        expect(p.salary, twoWaySalary);
      }
    });

    test('年数の長い選手は取れない', () {
      final c = _atContracts();
      final p = c.freeAgents.first..exp = twoWayMaxExp + 1;
      expect(c.twoWayProblem(p), isNotNull);
      c.signTwoWay(p.id);
      expect(c.me.twoWay, isEmpty);
    });

    test('登録に上げる(最低年俸2年)・登録がいっぱいなら上げられない・放すと自由契約', () {
      final c = _atContracts();
      final p = _young(c);
      c.signTwoWay(p.id);
      expect(c.me.twoWay, contains(p));
      while (c.me.roster.length - c.expiring.length > maxRoster - 1) {
        c.me.roster.removeLast();
      }
      c.promoteTwoWay(p.id);
      expect(c.me.twoWay, isEmpty);
      expect(c.me.roster, contains(p));
      expect(p.salary, minSalary);
      expect(p.years, 2);

      final q = c.freeAgents.firstWhere((x) => x.id != p.id)..exp = 1;
      c.signTwoWay(q.id);
      while (c.me.roster.length - c.expiring.length < maxRoster) {
        c.me.roster.add(c.freeAgents.firstWhere((x) => x.id != q.id));
        c.freeAgents.removeWhere((x) => c.me.roster.contains(x));
      }
      expect(c.promoteProblem(q), isNotNull);
      final dead = c.me.deadCap;
      c.waiveTwoWay(q.id);
      expect(c.me.twoWay, isEmpty);
      expect(c.freeAgents, contains(q));
      expect(c.me.deadCap, dead);
    });

    test('登録の若手を2ウェイに下げると登録に空きができる', () {
      final c = _atContracts();
      final p = c.me.roster.firstWhere((x) => x.years > 0 && !c.expiring.contains(x.id))..exp = 1;
      final n = c.me.roster.length;
      expect(c.toTwoWayProblem(p), isNull);
      c.toTwoWay(p.id);
      expect(c.me.roster.length, n - 1);
      expect(c.me.twoWay, contains(p));
      expect(p.salary, twoWaySalary);
    });

    test('保存して読み直しても同じ。次のオフに年を取り、契約が切れたら自由契約へ', () {
      final c = _atContracts();
      final p = _young(c);
      c.signTwoWay(p.id);
      final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.me.twoWay.map((x) => x.id), [p.id]);
      expect(back.me.twoWay.first.salary, twoWaySalary);

      final age = p.age;
      p.years = 1;
      var guard = 0;
      while (c.phase != Phase.seasonEnd && guard++ < 400) {
        botStep(c);
      }
      c.fired = false;
      c.toOffseason();
      expect(c.me.twoWay, isNot(contains(p)));
      if (!c.freeAgents.contains(p)) {
        // 引退した
        expect(p.age, age + 1);
      } else {
        expect(p.age, age + 1);
      }
    });
  });
}
