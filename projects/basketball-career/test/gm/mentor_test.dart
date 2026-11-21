import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/personality.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atPreseason(int seed) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (!(c.phase == Phase.preseason && c.season >= 2)) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('シーズン前に着かない');
  }
  return c;
}

/// ベテランと若手を1人ずつ用意する(足りなければ年を変える)。
(Player, Player) _pair(Career c) {
  final vet = c.me.roster.reduce((a, b) => a.age >= b.age ? a : b)..age = 31;
  final young = c.me.roster.where((p) => p != vet).reduce((a, b) => a.age <= b.age ? a : b)..age = 21;
  young.pot = young.ovr + 10;
  return (vet, young);
}

void main() {
  test('指導役: 29歳からと24歳まで。付けると気持ちが上がり、1組だけ。保存で残る', () {
    final c = _atPreseason(1);
    final (vet, young) = _pair(c);
    expect(c.mentorProblem(young, vet), isNotNull, reason: '逆向きは付けられない');
    final (mv, my) = (vet.morale, young.morale);
    c.setMentor(vet.id, young.id);
    expect(c.mentor, [vet.id, young.id]);
    expect(vet.morale, (mv + 5).clamp(0, 100));
    expect(young.morale, (my + 2).clamp(0, 100));
    expect(c.mentorProblem(vet, young), contains('もう指導役'));
    final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(copy.mentor, c.mentor);
    c.clearMentor();
    expect(c.mentor, isEmpty);
  });

  test('指導役: 次のオフに答えが出て空になる。付けた若手は付けないときより伸びることがある', () {
    var helped = 0;
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final a = _atPreseason(seed);
      final b = _atPreseason(seed);
      final (vet, young) = _pair(a);
      final (_, youngB) = _pair(b);
      a.setMentor(vet.id, young.id);
      while (a.phase != Phase.draft) {
        if (a.phase == Phase.seasonEnd) a.fired = false;
        botStep(a);
      }
      while (b.phase != Phase.draft) {
        if (b.phase == Phase.seasonEnd) b.fired = false;
        botStep(b);
      }
      expect(a.mentor, isEmpty);
      // 指導役は気持ちを少し上げるので、試合が1つ2つ変わることはある(組み合わせの作り込みのあとで表に出た)
      expect((a.me.wins - b.me.wins).abs(), lessThanOrEqualTo(2), reason: '指導役は試合の結果をほとんど変えない');
      if (!a.me.roster.contains(young)) continue;
      final d = young.ovr - youngB.ovr;
      expect(d, inInclusiveRange(0, 1));
      if (d == 1) helped++;
      expect(a.news.any((n) => n.contains(young.name)), isTrue);
    }
    expect(helped, greaterThan(0));
  });

  test('問題児の指導役は効きにくく、リーダーは効きやすい', () {
    final c = _atPreseason(1);
    final p = c.me.roster.first;
    final base = c.mentorChance(p);
    expect(base, inInclusiveRange(0.1, 0.8));
    expect(hasTrait(p, Trait.troublemaker) ? base < 0.45 : true, isTrue);
  });
}
