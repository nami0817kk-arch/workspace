import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('オーナーの性格は始めるときに決まり、保存しても残る。育成好きは毎年若手の目標を出す', () {
    final seen = <OwnerType>{};
    for (var seed = 1; seed <= 8; seed++) {
      seen.add(Career.start(seed: seed, team: 3).ownerType);
    }
    expect(seen.length, OwnerType.values.length);
    final c = Career.start(seed: 1, team: 3)..ownerType = OwnerType.youth;
    c.phase = Phase.preseason;
    c.startSeason();
    expect(c.goals.map((g) => g.kind), contains(GoalKind.youth));
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.ownerType, OwnerType.youth);
  });

  test('面談で予算を決められるのはシーズン前に1回。守ると信頼が上がり、超える補強は止まる', () {
    final c = careerAt(6, 12);
    expect(c.phase, Phase.preseason);
    expect(c.meetingOpen, isTrue);
    expect(c.budgetProblem(secondApron + 1), isNull, reason: '既定は縛らない');
    c.ownerMeeting(1);
    expect(c.budgetLevel, 1);
    expect(c.meetingOpen, isFalse);
    c.ownerMeeting(0);
    expect(c.budgetLevel, 1, reason: '面談は1回だけ');
    expect(c.budgetProblem(taxLine + 10), isNotNull);
    expect(c.budgetProblem(taxLine - 10), isNull);
    // 年俸の合計が減るときは止めない
    c.me.deadCap = taxLine * 2 - c.me.payroll + c.me.deadCap;
    expect(c.budgetProblem(c.me.payroll - 5), isNull);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.budgetLevel, 1);
    expect(back.meetingSeason, c.season);
  });

  test('予算を超える自由契約の補強はできない', () {
    final c = careerAt(6, 12);
    c.ownerMeeting(0);
    c.me.deadCap = 0;
    c.me.deadCap = salaryCap - 5 - c.me.payroll;
    final p = c.freeAgents.firstWhere((x) => c.askOf(x, c.me).salary > minSalary, orElse: () => c.freeAgents.first);
    final ask = c.askOf(p, c.me).salary;
    if (ask > minSalary) expect(c.signProblem(p), isNotNull);
  });
}
