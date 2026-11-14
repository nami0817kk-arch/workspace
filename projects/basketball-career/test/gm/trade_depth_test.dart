import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('トレードの見込み: 強さと勝ち数の変化を数え、名簿は元に戻る', () {
    final c = careerAt(4, 12);
    final partner = (c.mine + 1) % 30;
    final them = c.teams[partner];
    final star = them.order.first;
    final mineIds = [for (final p in c.me.roster) p.id];
    final theirIds = [for (final p in them.roster) p.id];
    final weak = c.me.order.last;
    final o = TradeOffer(partner: partner, give: [weak.id], get: [star.id]);
    final before = c.me.strength;
    final i = c.tradeImpact(o);
    expect(i.myBefore, closeTo(before, 1e-9));
    expect(i.myAfter, greaterThan(i.myBefore), reason: '相手のエースを取れば強くなる');
    expect(i.theirAfter, lessThan(i.theirBefore));
    expect(i.winsAfter, greaterThan(i.winsBefore));
    expect([for (final p in c.me.roster) p.id]..sort(), [...mineIds]..sort());
    expect([for (final p in them.roster) p.id]..sort(), [...theirIds]..sort());
    expect(c.me.strength, closeTo(before, 1e-9));
  });

  test('相手に足りないポジションの選手は高く見られ、その理由が出る', () {
    final c = careerAt(6, 12);
    final partner = (c.mine + 3) % 30;
    final them = c.teams[partner];
    final mine = c.me.order.first;
    // 相手から、こちらの選手と同じポジションの選手を全員もらう申し込み(相手にはそのポジションがいなくなる)
    final same = [for (final p in them.roster) if (p.pos == mine.pos && p.injured == 0) p.id];
    final o = TradeOffer(partner: partner, give: [mine.id], get: same);
    expect(positionCount(them, mine.pos, out: same.toSet()), 0);
    final plain = judgeTrade(c.teams, c.picks, c.mine, o, c.season, rosterLimit: 99);
    final withNeeds = judgeTrade(c.teams, c.picks, c.mine, o, c.season, rosterLimit: 99, needs: true);
    expect(withNeeds.ratio, greaterThan(plain.ratio));
    expect(withNeeds.notes.single, contains(mine.name));
    expect(plain.notes, isEmpty);
  });
}
