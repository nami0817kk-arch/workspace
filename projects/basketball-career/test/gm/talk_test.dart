import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/gm_people.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み T-3: 駆け引き(相手が言い返してくる)。
void main() {
  /// 受けてもらえる申し込み(相手に聞いて作る)と、その相手。
  (Career, TradeOffer) dealOf(int seed) {
    for (var s = seed; s < seed + 20; s++) {
      final c = careerAt(s, 12)..startSeason();
      for (var k = 1; k < 30; k++) {
        final t = (c.mine + k) % 30;
        final cheap = [...c.teams[t].roster]..sort((a, b) => a.salary.compareTo(b.salary));
        for (final x in cheap.skip(2).take(4)) {
          final o = c.askPartner(t, get: [x.id]);
          if (o != null && o.give.length >= 2) return (c, o);
        }
      }
    }
    fail('申し込みが作れない');
  }

  test('受けてもらえる案には「受ける」、足りない案には逆の案(どこを直せば通るか)を返す', () {
    final (c, o) = dealOf(3);
    final ok = c.talk(o);
    expect(ok.ok, isTrue);
    expect(ok.line, isNotEmpty);
    // 出すものを1つ減らすと足りない → 逆の案が来て、それなら受ける
    final less = TradeOffer(partner: o.partner, give: o.give.sublist(1), get: o.get, givePicks: o.givePicks, getPicks: o.getPicks);
    final r = c.talk(less);
    expect(r.ok, isFalse);
    if (r.counter != null) {
      expect(c.judge(r.counter!).ok || temperOf(c.gmPerson(o.partner)) == GmTemper.strong, isTrue);
      expect(r.counter!.give.length, greaterThan(less.give.length));
    }
  });

  test('やり取りの回数は GM の話し方で決まり、超えると打ち切られて信用が下がる', () {
    final (c, o) = dealOf(4);
    final less = TradeOffer(partner: o.partner, give: o.give.sublist(1), get: o.get, givePicks: o.givePicks, getPicks: o.getPicks);
    if (c.judge(less).ok) return;
    final rounds = temperOf(c.gmPerson(o.partner)).rounds;
    expect(c.talkRoundsLeft(o.partner), rounds);
    TalkReply? last;
    for (var i = 0; i <= rounds; i++) {
      last = c.talk(less);
    }
    expect(last!.ended, isTrue);
    expect(c.trustOf(o.partner), lessThan(0));
  });

  test('相手の逆の案を受けて成立すると、信用が上がる', () {
    final (c, o) = dealOf(5);
    final less = TradeOffer(partner: o.partner, give: o.give.sublist(1), get: o.get, givePicks: o.givePicks, getPicks: o.getPicks);
    final r = c.talk(less);
    final counter = r.counter;
    if (counter == null || !c.judge(counter).ok) return;
    expect(c.propose(counter), isTrue);
    expect(c.trustOf(o.partner), greaterThan(0));
  });

  test('本気度: 相手の穴のポジションの選手を出す申し込みは、本気になる', () {
    final c = careerAt(6, 12)..startSeason();
    final t = (c.mine + 1) % 30;
    final p = c.me.roster.first;
    // 相手のそのポジションを全員けがにして、穴を作る
    for (final q in c.teams[t].roster.where((q) => q.pos == p.pos)) {
      q.injured = 10;
    }
    final o = TradeOffer(partner: t, give: [p.id], get: [c.teams[t].roster.firstWhere((q) => q.pos != p.pos).id]);
    expect(c.keenFor(o), isTrue);
  });
}
