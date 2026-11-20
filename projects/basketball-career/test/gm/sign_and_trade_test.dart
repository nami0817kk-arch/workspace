import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade.dart';
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

  test('サイン＆トレード: 契約が切れる選手を再契約してトレードブロックに載せ、トレードに出せる', () {
    final c = atContracts();
    final p = c.me.roster.first
      ..morale = 80
      ..years = 0;
    c.expiring = [p.id];
    expect(c.signAndTradeProblem(p), isNull);
    expect(c.signAndTrade(p.id), isTrue);
    expect(c.expiring, isNot(contains(p.id)));
    expect(p.years, greaterThanOrEqualTo(1));
    expect(c.tradeBlock, contains(p.id));
    // 再契約済みなので、トレードに出せる(契約の話し合い中の選手ではない)
    final partner = (c.mine + 1) % c.teams.length;
    final v = c.judge(TradeOffer(partner: partner, give: [p.id], get: [c.teams[partner].roster.first.id]));
    expect(v.reason, isNot(contains('契約の話し合い中')));
    expect(c.log.any((l) => l.contains('サイン＆トレード')), isTrue);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.tradeBlock, contains(p.id));
  });

  test('契約が切れていない選手や、オフの契約の画面でないときはできない', () {
    final c = atContracts();
    final other = c.me.roster.firstWhere((x) => !c.expiring.contains(x.id));
    expect(c.signAndTradeProblem(other), isNotNull);
    final pre = careerAt(6, 8);
    expect(pre.signAndTradeProblem(pre.me.roster.first), isNotNull);
  }
  );
}
