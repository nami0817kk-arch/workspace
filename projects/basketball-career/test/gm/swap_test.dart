import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('入れ替え権を含む申し込みは保存でき、入れ替え権だけでも「出すもの」と数える', () {
    final o = TradeOffer(partner: 3, giveSwaps: const [1], getSwaps: const [2]);
    expect(o.isEmpty, isFalse);
    final back = TradeOffer.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
    expect(back.giveSwaps, [1]);
    expect(back.getSwaps, [2]);
  });

  test('入れ替え権を渡すトレードが成立すると記録され、保存しても残る', () {
    var found = false;
    for (var seed = 1; seed <= 12 && !found; seed++) {
      final c = careerAt(seed, 8);
      final partner = (c.mine + 1) % c.teams.length;
      for (final p in c.teams[partner].roster.reversed) {
        final x = TradeOffer(partner: partner, get: [p.id], giveSwaps: [c.season, c.season + 1, c.season + 2]);
        if (c.propose(x)) {
          found = true;
          expect(c.swaps, hasLength(3));
          expect(c.swaps.first[1], partner);
          expect(c.swaps.first[2], c.mine);
          final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
          expect(back.swaps, c.swaps);
          break;
        }
      }
    }
    expect(found, isTrue, reason: '入れ替え権3つで、釣り合うトレードが1つは成立する');
  });

  test('ドラフトの順が決まると、相手の1巡目のほうが上位なら入れ替わる。使った権利は消える', () {
    final c = careerAt(6, 1);
    var guard = 0;
    // ドラフトの直前まで進める(ドラフトに入ると順が決まって入れ替え権が使われる)
    while (c.phase != Phase.seasonEnd && guard++ < 300) {
      botStep(c);
    }
    c.fired = false;
    // 自分(強いチーム)が、全体で一番弱いチームの1巡目と入れ替える権利を持つ
    final weakest = [...c.teams]..sort((a, b) => a.wins.compareTo(b.wins));
    final other = weakest.first.index == c.mine ? weakest[1].index : weakest.first.index;
    c.swaps = [
      [c.season, c.mine, other]
    ];
    c.toOffseason();
    guard = 0;
    while (c.phase != Phase.draft && guard++ < 50) {
      botStep(c);
    }
    expect(c.phase, Phase.draft);
    expect(c.swaps.where((x) => x[0] <= c.season), isEmpty, reason: '使った(または使えなかった)権利は消える');
    expect(c.log.any((l) => l.contains('入れ替え権:')), isTrue, reason: '強いチームが、一番弱いチームの1巡目と入れ替える');
  });
}
