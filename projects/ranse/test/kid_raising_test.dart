import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/kid_raising.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/rng.dart';

import 'people_house_helpers.dart';

/// 子の育て方を決める（2026-11-25）。家にいる五〜十四の子に、年の初めの問いのときだけ方針を選べる。

void _noDigits(Prompt p, String where) {
  for (final c in p.choices) {
    expect(c.hint, isNotNull, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.label), isFalse, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.hint!), isFalse, reason: '$where: ${c.hint}');
  }
}

/// 三十の年に、子が三人（十二・九・六）いる大人の年の初めにする。
Game _parentAt30(int seed, {bool? female}) {
  final g = firstGrown(seed, female: female, to: 1580);
  jumpTo(g, 30);
  g.l.married = true;
  g.meet('伴侶', g.l.female ? '高政' : 'お春', 55);
  g.l.kids = 0;
  final y = g.l.startYear + 30;
  g.l.addKid(y - 12, female: false);
  g.l.addKid(y - 9, female: true);
  g.l.addKid(y - 6, female: false);
  g.choose(0);
  return g;
}

void main() {
  test('育て方は保存を往復でき、古い保存（方針なし）は決めていない子として読む', () {
    final g = _parentAt30(1);
    final k = raisableKids(g).first;
    expect(g.setKidRaising(k, KidRaising.tera), isTrue);
    final back = Life.fromJson(jsonDecode(jsonEncode(g.l.toJson())) as Map<String, dynamic>);
    final bk = back.kidNamed(k.name)!;
    expect(bk.raising, KidRaising.tera);
    expect(bk.raisingSince, g.year);
    final old = Kid.fromJson({'b': 1550, 'f': false, 'n': '太郎', 's': 'home'});
    expect(old.raising, isNull);
    expect(old.raisingYears(1560), 0);
  });

  test('画面から選べるのは年の初めの問いのときだけ。年の途中は選べない。選んだら年の初めの保存を書き直す', () {
    var saves = 0;
    final g = _parentAt30(2);
    final rng = g.rng;
    final g2 = Game(rng: rng, onCheckpoint: (_) => saves++);
    g2.life = g.life;
    g2.fa = g.fa;
    // 年の初めの問いのところ。
    g2.prompt = g.prompt;
    expect(g2.prompt!.title, 'この年の心がけ');
    final ks = raisableKids(g2);
    expect(ks.length, 3);
    expect(g2.canSetKidRaising, isTrue);
    expect(g2.setKidRaising(ks[0], KidRaising.bugei), isTrue);
    expect(saves, 1);
    expect(ks[0].raising, KidRaising.bugei);
    // 同じ方針を選び直しても、始めた年は変わらない。
    expect(g2.setKidRaising(ks[0], KidRaising.bugei), isTrue);
    expect(ks[0].raisingSince, g2.year);
    // 何か選んだあと（年の途中）は選べない。
    g2.choiceLog.add((0, 'x'));
    expect(g2.canSetKidRaising, isFalse);
    expect(g2.setKidRaising(ks[1], KidRaising.tera), isFalse);
    expect(ks[1].raising, isNull);
    g2.choiceLog.clear();
    // 岐路の最中も選べない。
    g2.prompt = Prompt('縁談', '', [Choice('x')], () {});
    expect(g2.canSetKidRaising, isFalse);
    // 五より下・十四より上・家にいない子は選べない。
    g2.prompt = g.prompt;
    final baby = g2.l.addKid(g2.year - 2);
    expect(g2.setKidRaising(baby, KidRaising.ie), isFalse);
    g2.l.kidLeft(ks[2], KidFate.temple, g2.year);
    expect(g2.setKidRaising(ks[2], KidRaising.ie), isFalse);
  });

  test('選んだ方針は、保存から再開しても同じ年の同じ問いのまま残る', () {
    final saved = <String>[];
    final rng = Rng(77);
    final g = Game(
      rng: rng,
      onCheckpoint: (g) => saved.add(jsonEncode({
        'life': g.l.toJson(),
        'world': g.fa.values.map((f) => f.toJson()).toList(),
      })),
    )..reseedAtCheckpoint = true;
    // 子のいる大人の年の初めまで進める。
    final src = _parentAt30(5);
    g.life = src.life;
    g.fa = src.fa;
    g.restore(src.l, src.fa, seed: 1234);
    expect(g.prompt!.title, 'この年の心がけ');
    final labels = g.prompt!.choices.map((c) => c.label).toList();
    final k = raisableKids(g).first;
    expect(g.setKidRaising(k, KidRaising.akinai), isTrue);
    final last = jsonDecode(saved.last) as Map<String, dynamic>;
    final life = Life.fromJson(last['life'] as Map<String, dynamic>);
    expect(life.kidNamed(k.name)!.raising, KidRaising.akinai);
    final g3 = Game(rng: Rng(1));
    g3.restore(life, src.fa, seed: 1234);
    expect(g3.prompt!.title, 'この年の心がけ');
    expect(g3.prompt!.choices.map((c) => c.label).toList(), labels);
  });

  test('方針に沿った岐路が出て、子の歳と方針と年数が合い、匂わせつき・数字なし。行き先も出る', () {
    final seen = <String, int>{};
    var lives = 0;
    for (var s = 0; s < 400; s++) {
      final g = grownUp(s + 40000, to: 1580);
      if (g == null) continue;
      lives++;
      jumpTo(g, 30);
      g.l.married = true;
      g.meet('伴侶', g.l.female ? '高政' : 'お春', 55);
      g.l.kids = 0;
      final y = g.l.startYear + 30;
      for (final a in [13, 10, 7]) {
        g.l.addKid(y - a);
      }
      g.choose(0);
      final pickR = Rng(s + 3);
      playWatch(
        g,
        Rng(s + 5),
        prefix: 'kd_',
        onYear: () {
          for (final k in raisableKids(g)) {
            if (k.raising == null) {
              expect(g.setKidRaising(k, KidRaising.all[pickR.range(0, 3)]), isTrue);
            }
          }
        },
        atScene: (id, p) {
          seen[id] = (seen[id] ?? 0) + 1;
          _noDigits(p, id);
          if (id == 'kd_yukue') {
            expect(
              g.l.kidsInOrder.any(
                (k) => k.home && k.raising != null && k.raisingYears(g.year) >= 4 && (k.ageAt(g.year) ?? 0) >= 15,
              ),
              isTrue,
              reason: id,
            );
            return;
          }
          final r = {
            'kd_tera': KidRaising.tera,
            'kd_bugei': KidRaising.bugei,
            'kd_akinai': KidRaising.akinai,
            'kd_ie': KidRaising.ie,
          }[id]!;
          expect(
            g.l.kidsInOrder.any((k) => k.home && k.raising == r && k.raisingYears(g.year) >= 2),
            isTrue,
            reason: id,
          );
        },
      );
    }
    // ignore: avoid_print
    print('出た岐路: $seen');
    expect(lives, greaterThan(150));
    for (final id in kKidRaisingSceneIds) {
      expect(seen[id] ?? 0, greaterThan(0), reason: '$id が一度も出ない（$seen）');
    }
  });

  test('元服の書き出しと子の志は、育て方で変わる', () {
    expect(raisingLine(Kid(born: 1550, female: false, name: '太郎')), '');
    final k = Kid(born: 1550, female: false, name: '太郎', raising: KidRaising.tera, raisingSince: 1556);
    expect(raisingLine(k), contains('寺で学んだ太郎'));
    expect(raisingLine(k, '長政'), contains('寺で学んだ長政'));
    expect(raisingWish(k), '寺で学ぶ');
    k.raising = KidRaising.bugei;
    expect(raisingWish(k), '足軽に出る');
    k.raising = KidRaising.ie;
    expect(raisingWish(k), isNull);

    // 村の子の志: 武芸を仕込んだ子は足軽に出たいと言う。
    var hit = 0;
    for (var s = 0; s < 400 && hit < 5; s++) {
      final g = grownUp(s + 50000);
      if (g == null) continue;
      g.choose(0);
      g.l.rank = 0;
      g.l.flags.removeAll(['priesthood', 'way_outlaw', 'way_merchant', 'craftsman']);
      if (!const ['farmer', 'fisher', 'beggar'].contains(g.l.cls.id)) continue;
      g.l.t = 40 * 2;
      g.l.kids = 0;
      final son = g.l.addKid(g.year - 15, female: false);
      son.raising = KidRaising.tera;
      son.raisingSince = g.year - 8;
      final sc = g.adultScenes.firstWhere((x) => x.id == 'fa_kokorozashi');
      if (!sc.cond(g)) continue;
      g.prompt = null;
      sc.run(g, () {});
      expect(g.prompt!.text, contains('寺へ戻り'));
      hit++;
    }
    expect(hit, greaterThan(0));
  });
}
