import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/daimyo_life.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/retainers.dart';
import 'package:ranse/engine/rng.dart';

import 'people_house_helpers.dart';

/// 家臣の顔ぶれ（2026-11-25）。城主より上の人に、名と気質のある家臣。家臣にまつわる一生に一度の岐路と、下剋上に効く口。

void _noDigits(Prompt p, String where) {
  for (final c in p.choices) {
    expect(c.hint, isNotNull, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.label), isFalse, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.hint!), isFalse, reason: '$where: ${c.hint}');
  }
}

/// 岐路が出た瞬間に、出てよい人・前の段を確かめる。
void _check(Game g, String id) {
  expect(krHolder(g), isTrue, reason: '$id が家臣を持つ身でない人に出た（位${g.l.rank}）');
  if (id == 'kr_kaobure') {
    // 顔ぶれの岐路で三人が揃う（場面を出すときに召し抱える）。
    expect(g.l.retainers.length, 3, reason: id);
    expect(g.l.retainers.map((r) => r.temper).toSet().length, 3, reason: id);
    return;
  }
  expect(g.l.retainers, isNotEmpty, reason: '$id が顔ぶれの前に出た');
  if (id == 'kr_sasayaki') expect(g.l.rank, lessThanOrEqualTo(7), reason: id);
  if (id == 'kr_uragiri') expect(dmLord(g), isTrue, reason: id);
}

void main() {
  test('家臣は保存を往復でき、古い保存は空で読む', () {
    final g = firstGrown(11);
    final l = g.l;
    l.retainers
      ..add(Retainer('中村弥吉', RetainerTemper.loyal, bond: 70, head: true, since: 1560))
      ..add(Retainer('小川源太', RetainerTemper.ambitious, bond: 20, state: RetainerState.away));
    final j = jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>;
    final back = Life.fromJson(j);
    expect(jsonEncode(back.retainers.map((r) => r.toJson()).toList()),
        jsonEncode(l.retainers.map((r) => r.toJson()).toList()));
    expect(back.servingRetainers.length, 1);
    j.remove('retainers');
    expect(Life.fromJson(j).retainers, isEmpty);
  });

  test('城主・家老・当主に家臣の岐路が出て、前の段の後に、匂わせつき・数字なしで出る', () {
    final seen = <String, int>{};
    var lives = 0;
    for (var s = 0; s < 700; s++) {
      final g = grownUp(s + 500, female: false, to: 1585);
      if (g == null) continue;
      lives++;
      jumpTo(g, 24);
      serveAt(g, s % 4 == 0 ? 8 : 6);
      g.choose(0);
      playWatch(
        g,
        Rng(s + 9),
        prefix: 'kr_',
        atScene: (id, p) {
          seen[id] = (seen[id] ?? 0) + 1;
          _noDigits(p, id);
          _check(g, id);
        },
      );
      // 家臣の名は重ならない。
      final names = g.l.retainers.map((r) => r.name).toList();
      expect(names.toSet().length, names.length, reason: '$names');
    }
    // ignore: avoid_print
    print('出た岐路: $seen');
    expect(lives, greaterThan(200));
    for (final id in kRetainerSceneIds) {
      expect(seen[id] ?? 0, greaterThan(0), reason: '$id が一度も出ない（$seen）');
    }
    // 顔ぶれは、家臣を持つ身になった人のほとんどに出る。
    expect(seen['kr_kaobure']!, greaterThan(lives ~/ 2));
  });

  test('身分のない人・足軽には家臣の岐路が出ない', () {
    final g = firstGrown(21);
    g.choose(0);
    g.l.rank = 2;
    for (final id in kRetainerSceneIds) {
      final s = g.adultScenes.firstWhere((x) => x.id == id);
      expect(s.cond(g), isFalse, reason: id);
    }
  });

  test('下剋上に効く口: 家臣がいなければ零、野心の家臣と囁きで上がり、告げれば下がる。幅は小さい', () {
    final g = firstGrown(31);
    g.choose(0);
    serveAt(g, 6);
    expect(retainerPlotBonus(g), 0);
    final r = Retainer('松井与作', RetainerTemper.ambitious, bond: 60);
    g.l.retainers.add(r);
    final a = retainerPlotBonus(g);
    expect(a, greaterThan(0));
    g.setFlag('kr_plot');
    expect(retainerPlotBonus(g), greaterThan(a));
    g.l.retainers.addAll([
      for (var i = 0; i < 6; i++) Retainer('家臣$i', RetainerTemper.ambitious, bond: 90),
    ]);
    expect(retainerPlotBonus(g), lessThanOrEqualTo(.12));
    g.l.retainers.clear();
    g.l.retainers.add(Retainer('松井与作', RetainerTemper.loyal, bond: 10));
    g.l.flags.remove('kr_plot');
    g.setFlag('kr_reported');
    expect(retainerPlotBonus(g), lessThan(0));
    expect(retainerPlotBonus(g), greaterThanOrEqualTo(-.05));
  });

  test('家臣の欄: 気質・名・筆頭・去った者は薄く', () {
    final g = firstGrown(41, female: false);
    g.choose(0);
    serveAt(g, 6);
    g.l.retainers
      ..add(Retainer('中村弥吉', RetainerTemper.loyal, bond: 80, head: true))
      ..add(Retainer('小川源太', RetainerTemper.brave, state: RetainerState.dead));
    final rows = retainerRows(g);
    expect(rows.length, 2);
    expect(rows[0].$1, '忠義');
    expect(rows[0].$2, contains('筆頭'));
    expect(rows[0].$3, isFalse);
    expect(rows[1].$2, contains('亡くなった'));
    expect(rows[1].$3, isTrue);
    // 家臣を持つ身でなくなったら、皆薄く。
    g.l.rank = 2;
    expect(retainerRows(g).every((r) => r.$3), isTrue);
  });
}
