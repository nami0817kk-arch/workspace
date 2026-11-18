import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

/// オフの契約の場面まで進めた経歴と、交渉できる自由契約の選手。
(Career, Player) _atContracts(int seed) {
  final c = careerAt(seed, 15);
  var guard = 0;
  while (!(c.phase == Phase.contracts && c.freeAgents.any((p) => c.askOf(p, c.me).salary > minSalary * 2))) {
    botStep(c);
    if (guard++ > 5000) fail('契約の場面に着かない');
  }
  final p = c.freeAgents.where((p) => c.askOf(p, c.me).salary > minSalary * 2).first;
  return (c, p);
}

void main() {
  test('言い値に近い額ならまとまり、最低線より上なら間を取った額を返してくる', () {
    final (c, p) = _atContracts(3);
    final ask = c.askOf(p, c.me).salary;
    final floor = c.agentFloor(p, 1);
    expect(floor, lessThan(ask));
    expect(c.talkAgent(p.id, 1, ask).mood, AgentMood.agreed);
    final r = c.talkAgent(p.id, 1, floor);
    expect(r.mood == AgentMood.counter || r.mood == AgentMood.agreed || r.mood == AgentMood.last, isTrue);
    if (r.mood != AgentMood.agreed) {
      expect(r.salary, inInclusiveRange(floor, ask));
      expect(c.agentAskOf(p), r.salary);
      // 返してきた言い値で申し出ればまとまる
      expect(c.talkAgent(p.id, 1, r.salary).mood, AgentMood.agreed);
    }
  });

  test('低すぎる額は気を悪くさせ、往復を使い切ると最後の提示になる', () {
    final (c, p) = _atContracts(5);
    final floor = c.agentFloor(p, 1);
    final before = p.morale;
    final low = (floor * 0.7).round();
    final r = c.talkAgent(p.id, 1, low);
    expect(r.mood, AgentMood.insulted);
    expect(p.morale, lessThanOrEqualTo(before));
    for (var k = 1; k < c.haggleLimit; k++) {
      c.talkAgent(p.id, 1, low);
    }
    expect(c.talkAgent(p.id, 1, low).mood, AgentMood.closed);
  });

  test('まとまった額で契約でき、言い値は保存される', () {
    final (c, p) = _atContracts(7);
    final ask = c.askOf(p, c.me).salary;
    final r = c.talkAgent(p.id, 2, c.agentFloor(p, 2));
    final back = Career.fromJson(c.toJson());
    expect(back.agentAsks, c.agentAsks);
    final salary = r.mood == AgentMood.agreed ? r.salary : c.agentAskOf(p);
    final ok = c.offer(p.id, 2, salary / ask, agreed: true);
    if (ok) {
      final signed = c.me.roster.firstWhere((x) => x.id == p.id);
      expect(signed.salary, lessThan(ask));
    }
  });
}
