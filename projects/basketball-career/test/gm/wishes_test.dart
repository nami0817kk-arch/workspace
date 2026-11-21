import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/wishes.dart';
import 'package:flutter_test/flutter_test.dart';

Player _p(int id, {int age = 25, int ovr = 70}) =>
    Player(id: id, name: '選手$id', pos: Pos.sf, age: age, ovr: ovr, pot: ovr + 5, salary: 300, years: 2, exp: age - 20);

/// 2026-11-21 の作り込み C-2: 選手の望み。
void main() {
  test('望みは年齢と立場で移る(若手は出番、ベテランは優勝かお金、晩年は古巣)', () {
    expect(wishOf(_p(1, age: 21)), Wish.minutes);
    expect(wishOf(_p(2, age: 35)), Wish.home);
    for (var id = 1; id < 60; id++) {
      expect(wishOf(_p(id, age: 31)), anyOf(Wish.ring, Wish.money));
      expect(wishOf(_p(id, age: 26, ovr: 82)), anyOf(Wish.star, Wish.money));
    }
  });

  test('優勝したい選手は、強いチームに関心が上乗せされる', () {
    final c = careerAt(3, 12)..startSeason();
    final ring = [for (var id = 900000; id < 900100; id++) _p(id, age: 31)].firstWhere((p) => wishOf(p) == Wish.ring);
    final strong = [for (var t = 0; t < 30; t++) t]..sort((a, b) => c.strengthRank(a).compareTo(c.strengthRank(b)));
    expect(wishInterest(c, ring, strong.first), greaterThan(wishInterest(c, ring, strong.last)));
  });

  test('望みが満たされない主力は、続くと気持ちが下がり、自分の主力はトレードを申し出る。保存もする', () {
    final c = careerAt(4, 12)..startSeason();
    final p = ([...c.me.roster]..sort((a, b) => b.ovr.compareTo(a.ovr))).first;
    c.wishUnmet[p.id] = 2;
    final morale = p.morale;
    // 望みが満たされていなければ、1区切りで気持ちが下がる
    if (!wishMet(c, p, c.me)) {
      c.playBlock();
      expect(p.morale, lessThan(morale + 20));
      expect(c.inbox.where((m) => m.title.contains('トレードを望んでいる')), isNotEmpty);
      expect(c.wishIsKnown(p), isTrue);
    }
    final y = Career.fromJson(c.toJson());
    expect(y.wishKnown, c.wishKnown);
    expect(y.wishUnmet.length, c.wishUnmet.length);
  });

  test('FA に申し込むと、その選手の望みが分かる', () {
    final c = careerAt(5, 12);
    final p = c.freeAgents.first;
    expect(c.wishIsKnown(p), isFalse);
    c.wishKnown.add(p.id);
    expect(c.wishIsKnown(p), isTrue);
  });
}
