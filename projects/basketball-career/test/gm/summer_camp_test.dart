import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts(int seed) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (c.phase != Phase.contracts) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('契約の場面に着かない');
  }
  return c;
}

void main() {
  test('個人練習: 枠は練習施設＋1。契約切れの選手は選べない。オフを終えると能力が上がり、空になる', () {
    for (final seed in [1, 2, 3]) {
      final c = _atContracts(seed);
      expect(c.campSlots, c.facilityLevel(Facility.training) + 1);
      final picks = [for (final p in c.me.roster) if (!c.expiring.contains(p.id)) p].take(c.campSlots + 1).toList();
      for (final p in picks) {
        c.setCamp(p.id, Attr.defense);
      }
      expect(c.camp.length, c.campSlots, reason: '枠を超えて選べない');
      final extra = picks.last;
      expect(c.camp.containsKey(extra.id), isFalse);
      expect(c.campProblem(extra), contains('枠がいっぱい'));
      if (c.expiring.isNotEmpty) {
        final gone = c.me.roster.firstWhere((p) => p.id == c.expiring.first);
        expect(c.campProblem(gone), isNotNull);
      }
      // 外すと空く
      c.setCamp(picks.first.id, null);
      expect(c.camp.length, c.campSlots - 1);
      c.setCamp(picks.first.id, Attr.outside);
      // 保存して読み戻しても残る
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.camp, c.camp);
      final chosen = {for (final e in c.camp.entries) e.key: e.value};
      final before = {for (final p in picks) p.id: (p.ovr, [...p.attrs])};
      c.finishContracts();
      expect(c.camp, isEmpty);
      expect(c.phase, Phase.preseason);
      for (final e in chosen.entries) {
        final p = [...c.me.roster, ...c.me.twoWay].where((x) => x.id == e.key).firstOrNull;
        if (p == null) continue;
        final (ovr, attrs) = before[p.id]!;
        // 選んだ能力は上がる(ずれの上限15に届いていれば、そのまま)
        expect(p.attrs[e.value.index], attrs[e.value.index] >= 15 ? 15 : greaterThan(attrs[e.value.index]));
        expect(p.ovr - ovr, inInclusiveRange(0, 1));
      }
      expect(c.inbox.any((m) => m.title == '夏の個人練習の結果'), isTrue);
    }
  });

  test('個人練習を選ばなければ、オフの終わりは今までと同じ', () {
    final a = _atContracts(7);
    final b = _atContracts(7);
    final p = a.me.roster.firstWhere((p) => !a.expiring.contains(p.id));
    a.setCamp(p.id, Attr.passing);
    a.finishContracts();
    b.finishContracts();
    // 個人練習はリーグの乱数を使わない
    expect(a.rng.next(), b.rng.next());
    expect(a.campProblem(p), isNotNull, reason: 'シーズン前は選べない');
  });
}
