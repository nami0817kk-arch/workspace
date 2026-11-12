import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts(int seed) {
  final c = careerAt(seed, 8);
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

void main() {
  test('自分で指名した新人の契約が終わって手放すと、制限付きの自由契約になる', () {
    final c = _atContracts(6);
    final p = c.me.roster.first
      ..exp = 3
      ..years = 0;
    c.draftedIds.add(p.id);
    c.expiring = [p.id];
    c.letGo(p.id);
    expect(c.rfa, contains(p.id));
    // 指名した選手でなければならない
    final q = c.me.roster.first
      ..exp = 9
      ..years = 0;
    c.expiring = [q.id];
    c.letGo(q.id);
    expect(c.rfa, isNot(contains(q.id)));
  });

  test('ほかのチームのオファーシートに同じ条件で残せる。答えずに日が進めば見送り', () {
    final c = _atContracts(6);
    final p = c.freeAgents.firstWhere((x) => c.isBigFa(x));
    c.rfa = [p.id];
    // その選手に、ほかのチームの申し込みだけを置いて、決める日を進める
    final other = (c.mine + 1) % c.teams.length;
    c.teams[other].roster.removeWhere((x) => c.teams[other].roster.length > 12);
    c.bids = {
      p.id: [FaBid(other, 200, 3)]
    };
    var guard = 0;
    while (c.sheet == null && c.faDay < faDays && guard++ < 20) {
      c.bids.putIfAbsent(p.id, () => [FaBid(other, 200, 3)]);
      c.nextFaDay();
    }
    expect(c.sheet, isNotNull, reason: "決める日までにオファーシートが届く");
    expect(c.sheet, [p.id, other, 200, 3]);
    expect(c.sheetPlayer, p);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.sheet, [p.id, other, 200, 3]);
    c.me.roster.removeWhere((x) => c.me.roster.length > 10 && !c.expiring.contains(x.id));
    expect(c.matchSheet(), isTrue);
    expect(c.me.roster, contains(p));
    expect(p.salary, 200);
    expect(p.years, 3);
    expect(c.sheet, isNull);
  });

  test('見送ると、その選手はオファーを出したチームに行く', () {
    final c = _atContracts(6);
    final p = c.freeAgents.firstWhere((x) => c.isBigFa(x));
    final other = (c.mine + 1) % c.teams.length;
    c.sheet = [p.id, other, 180, 2];
    c.declineSheet();
    expect(c.sheet, isNull);
    expect(c.teams[other].roster, contains(p));
    expect(p.salary, 180);
  });
}
