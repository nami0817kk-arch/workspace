import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

Career _inSeason([int seed = 6]) {
  final c = careerAt(seed, 8);
  var guard = 0;
  while (c.phase != Phase.season && guard++ < 50) {
    botStep(c);
  }
  return c;
}

Player _cheapFa(Career c) => c.freeAgents.firstWhere((p) => c.askOf(p, c.me).salary <= minSalary);

void main() {
  test('10日契約: 5試合で切れて自由契約に戻る。同じ選手とは2回まで', () {
    final c = _inSeason();
    while (c.me.roster.length >= 15) {
      c.me.roster.removeLast();
    }
    final p = _cheapFa(c);
    expect(c.tenDayProblem(p), isNull);
    c.signTenDay(p.id);
    expect(c.me.roster, contains(p));
    expect(p.salary, tenDaySalary);
    expect(p.tenDay, tenDayRounds);
    c.playWeek();
    c.playWeek();
    expect(c.me.roster.contains(p), isFalse);
    expect(c.freeAgents, contains(p));
    c.signTenDay(p.id);
    c.playWeek();
    c.playWeek();
    expect(c.tenDayProblem(p), contains('2回'));
  });

  test('10日契約は、保存して読み直しても残る', () {
    final c = _inSeason();
    while (c.me.roster.length >= 15) {
      c.me.roster.removeLast();
    }
    final p = _cheapFa(c);
    c.signTenDay(p.id);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    final q = back.me.roster.firstWhere((x) => x.id == p.id);
    expect(q.tenDay, tenDayRounds);
    expect(q.tenDayCount, 1);
  });

  test('ウェーバー: 安くて力のある選手は拾われ、年俸の負担が残らない。高い選手は拾われない', () {
    final c = _inSeason();
    final p = c.me.roster.first
      ..ovr = 75
      ..salary = 20
      ..years = 2;
    expect(c.waiverChance(p), greaterThan(0.5));
    p.salary = 150;
    expect(c.waiverChance(p), 0);
    var claimed = 0;
    for (var i = 0; i < 40; i++) {
      final d = _inSeason(100 + i);
      final q = d.me.roster.first
        ..ovr = 75
        ..salary = 20
        ..years = 2;
      d.me.deadCap = 0;
      if (d.release(q.id)) {
        claimed++;
        expect(d.me.deadCap, 0);
        expect(d.me.roster.contains(q), isFalse);
      } else {
        expect(d.me.deadCap, 20);
      }
    }
    expect(claimed, inInclusiveRange(1, 39));
  });
}
