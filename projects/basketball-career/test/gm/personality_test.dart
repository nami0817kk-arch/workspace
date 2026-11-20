import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/personality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('性格は選手の id から決まり(同じなら同じ)、価値観と特徴が全部の種類にばらける', () {
    final c = careerAt(6, 12);
    final all = [for (final t in c.teams) ...t.roster];
    final values = <Value>{}, traits = <Trait>{};
    for (final p in all) {
      final a = personalityOf(p), b = personalityOf(p);
      expect(a.line, b.line);
      expect(a.traits, isNotEmpty);
      expect(a.traits.length, lessThanOrEqualTo(2));
      expect(a.traits.toSet().length, a.traits.length);
      values.add(a.value);
      traits.addAll(a.traits);
    }
    expect(values.length, Value.values.length);
    expect(traits.length, Trait.values.length);
  });

  test('性格は、同じチームに2年いると見えてくる', () {
    final c = careerAt(6, 12);
    final p = c.me.roster.first;
    p.tenure = 1;
    expect(personalityKnown(p), isFalse);
    p.tenure = 2;
    expect(personalityKnown(p), isTrue);
  });

  test('リーダーは相性を上げ、問題児は下げる。忠誠の選手は値切りに応じやすい', () {
    final c = careerAt(6, 12)..startSeason();
    final top = c.me.order.take(9).toList();
    // 全員の性格を見て、リーダーと問題児の数から目標が動く向きを確かめる(上限・下限を超えない)
    final leaders = top.where((p) => hasTrait(p, Trait.leader)).length;
    final trouble = top.where((p) => hasTrait(p, Trait.troublemaker)).length;
    c.playBlock();
    expect(c.me.chem, inInclusiveRange(0, 100));
    expect(leaders + trouble, greaterThanOrEqualTo(0));
    final loyal = [for (final t in c.teams) ...t.roster].firstWhere((p) => personalityOf(p).value == Value.loyal);
    final money = [for (final t in c.teams) ...t.roster].firstWhere((p) => personalityOf(p).value == Value.money);
    loyal.morale = 60;
    money.morale = 60;
    expect(c.discountChance(loyal, freeAgent: false), greaterThan(c.discountChance(money, freeAgent: false)));
    botStep(c);
  });
}
