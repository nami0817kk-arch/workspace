import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:basketball_career/gm/trade_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み T-4: 相手が覚えている(GM ごとの信用)。
void main() {
  test('信用が高いほど受けやすく、強く警戒すると話に応じない。保存もする', () {
    final c = careerAt(3, 12)..startSeason();
    // 釣り合う形(年俸の決まりを満たす)の申し込みを、相手に聞いて作る
    TradeOffer? o;
    var t = c.mine;
    for (var k = 1; k < 30 && o == null; k++) {
      t = (c.mine + k) % 30;
      final cheap = [...c.teams[t].roster]..sort((a, b) => a.salary.compareTo(b.salary));
      o = c.askPartner(t, get: [cheap[2].id]);
    }
    if (o == null) fail('申し込みが作れない');
    final base = c.judge(o).ratio;
    expect(base, greaterThan(0));
    c.gmTrust[t] = 80;
    expect(c.judge(o).ratio, greaterThan(base));
    expect(c.trustLabel(t), '信頼している');
    c.gmTrust[t] = -70;
    final v = c.judge(o);
    expect(v.ok, isFalse);
    expect(v.reason, contains('警戒'));
    expect(c.trustLabel(t), '警戒している');
    final y = Career.fromJson(c.toJson());
    expect(y.trustOf(t), -70);
  });

  test('一方的なトレードは、翌季の開幕に相手が気づいて警戒し、ほかの GM にも伝わる。信用は季ごとに戻る', () {
    final c = careerAt(4, 12);
    final t = (c.mine + 2) % 30;
    final star = [...c.teams[t].roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final worst = [...c.me.roster]..sort((a, b) => a.ovr.compareTo(b.ovr));
    // 相手の主力を、こちらの控えと交換した記録(こちらの大勝ち)
    c.myTrades = [
      MyTrade(season: c.season - 1, partner: t, give: [(worst.first.id, worst.first.name, worst.first.ovr)], get: [(star.first.id, star.first.name, star.first.ovr)]),
    ];
    expect(tradeValues(c, c.myTrades.first).$1, greaterThan(tradeValues(c, c.myTrades.first).$2));
    final other = (c.mine + 5) % 30;
    c.gmTrust[other] = 50;
    c.startSeason();
    expect(c.trustOf(t), lessThan(-25));
    expect(c.trustOf(other), lessThan(50));
    expect(c.inbox.where((m) => m.title.contains('警戒')), isNotEmpty);
  });
}
