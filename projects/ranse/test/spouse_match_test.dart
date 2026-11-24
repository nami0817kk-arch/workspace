import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/spouse_match.dart';

import 'people_house_helpers.dart';

/// 縁談の相手を選ぶ（2026-11-25）。家柄・気立て・才の違う二、三人の候補から選び、文は前と同じ「◯◯と夫婦になった」。

void _noDigits(Prompt p, String where) {
  for (final c in p.choices) {
    expect(c.hint, isNotNull, reason: '$where: ${c.label} に匂わせがない');
    expect(c.hint!.isNotEmpty, isTrue, reason: where);
    expect(kDigits.hasMatch(c.label), isFalse, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.hint!), isFalse, reason: '$where: ${c.hint}');
  }
}

void main() {
  test('縁談の岐路: 候補は二、三人で型が違い、選ぶと前と同じ文で夫婦になる', () {
    var seen = 0, three = 0;
    final kinds = <String>{};
    for (var s = 0; s < 400 && seen < 120; s++) {
      final g = grownUp(s);
      if (g == null) continue;
      g.choose(0);
      final scene = g.adultScenes.firstWhere((x) => x.id == 'engagement');
      if (!scene.cond(g)) continue;
      g.prompt = null;
      var after = false;
      scene.run(g, () => after = true);
      final p = g.prompt!;
      expect(p.title, '縁談');
      _noDigits(p, 'engagement');
      final cands = p.choices.length - 1;
      // 野に生きる者には家柄の良い家が出ない（一人か二人）。
      final outlaw = g.hasFlag('way_outlaw') && g.l.rank == 0;
      expect(cands, inInclusiveRange(outlaw ? 1 : 2, outlaw ? 2 : 3));
      expect(p.choices.last.label, 'どの縁談も断る');
      if (cands == 3) three++;
      seen++;
      final pick = s % cands;
      final label = p.choices[pick].label;
      g.choose(pick);
      expect(after, isTrue);
      final l = g.l;
      expect(l.married, isTrue, reason: label);
      final sp = l.people['伴侶']!;
      expect(l.path.last, '${g.age}歳　${sp.name}と夫婦になった');
      final k = spouseKind(g);
      expect(k, isNotNull);
      kinds.add(k!);
      expect(l.flags.where((f) => f.startsWith('en_kind:')).length, 1);
      expect(enSince(g), 0);
    }
    expect(seen, greaterThan(60));
    expect(three, greaterThan(0), reason: '才のある人がいる縁談が一度も出ない');
    expect(kinds, containsAll([kSpouseNoble, kSpouseGentle, kSpouseClever]));
  });

  test('野に生きる者には、家柄の良い家の縁談は来ない', () {
    final g = firstGrown(9);
    g.choose(0);
    g.l.rank = 0;
    g.setFlag('way_outlaw');
    for (var i = 0; i < 20; i++) {
      final cs = spouseCandidates(g);
      expect(cs.any((c) => c.kind == kSpouseNoble), isFalse);
      expect(cs, isNotEmpty);
      expect(spouseIntro(g, cs).contains(RegExp('[0-9０-９]')), isFalse);
    }
  });

  test('家柄の良い家は持参と信頼、気立ての良い人は幸福、才のある人はその間', () {
    final g = firstGrown(7);
    g.choose(0);
    final l = g.l;
    final base = (l.gold, l.joy, l.fav, l.net);
    final out = <String, (int, int, int)>{};
    for (final kind in [kSpouseNoble, kSpouseGentle, kSpouseClever]) {
      l.gold = base.$1;
      l.joy = 40;
      l.fav = 30;
      l.rank = 3;
      l.married = false;
      l.people.remove('伴侶');
      marrySpouse(g, SpouseCand(kind, '中村家のお春', 'x', 'y'));
      out[kind] = (l.gold - base.$1, l.joy - 40, l.fav - 30);
      expect(l.people['伴侶']!.name, '中村家のお春');
    }
    expect(out[kSpouseNoble]!.$1, greaterThan(out[kSpouseGentle]!.$1));
    expect(out[kSpouseNoble]!.$3, greaterThan(0));
    expect(out[kSpouseGentle]!.$2, greaterThan(out[kSpouseNoble]!.$2));
    expect(out[kSpouseClever]!.$1, greaterThan(out[kSpouseGentle]!.$1));
  });

  test('連れ合いの型の岐路は、その型の連れ合いと暮らす人にだけ、年を置いて出る', () {
    final seen = <String, int>{};
    for (var s = 0; s < 500; s++) {
      final g = grownUp(s + 3000);
      if (g == null) continue;
      jumpTo(g, 22);
      g.choose(0);
      final r = Rng(s + 77);
      // 最初の年に縁談を通しておく（三つの型を順に）。
      final kind = [kSpouseNoble, kSpouseGentle, kSpouseClever][s % 3];
      marrySpouse(g, SpouseCand(kind, '小川家のお梅', 'x', 'y'));
      playWatch(
        g,
        r,
        prefix: 'en_',
        atScene: (id, p) {
          seen[id] = (seen[id] ?? 0) + 1;
          _noDigits(p, id);
          final want = {
            'en_shuto': kSpouseNoble,
            'en_sasae': kSpouseGentle,
            'en_saikaku': kSpouseClever,
          }[id]!;
          expect(spouseKind(g), want, reason: id);
          expect(enSince(g), greaterThanOrEqualTo(id == 'en_shuto' ? 2 : 1), reason: id);
          expect(g.l.married, isTrue);
        },
      );
    }
    // ignore: avoid_print
    print('出た岐路: $seen');
    for (final id in kSpouseSceneIds) {
      expect(seen[id] ?? 0, greaterThan(0), reason: '$id が一度も出ない');
    }
  });

  test('縁談の岐路の id は登録されている', () {
    final ids = Game(rng: Rng(1)).adultScenes.map((s) => s.id).toList();
    for (final id in kSpouseSceneIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
    }
  });
}
