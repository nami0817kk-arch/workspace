import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 気がかりの直し（2026-11-24）: 死ぬ確率のとても高い手・死因の家の名・女武者の出やすさ・能力で増えた手の釣り合い。
/// （一六〇一〜一五年の最期は `peace_endings_test`、特性の場面の書き分けは `traits_test`。）

/// 命がけだと匂わせに書いてあるはずの手（場面の題／手の名）。亡くなる見込みを二割五分前後までに下げたもの。
const _deadly = {
  '夏の陣／城に残り、野に打って出る',
  '大坂城の評定／豊臣の家臣として、城に籠もる',
  '禁教の触れ／信者であると名乗り出る',
  '絵踏み／踏まない',
  '三方ヶ原／家康の身代わりとなって敵を引きつける',
  '山崎／光秀につく',
  '北ノ庄の落城／お市のそばに残る',
  '本能寺／本能寺へ駆けつける',
  '桶狭間／本陣の守りを固めるよう進言する',
  '籠城／城を出て斬り込む',
  '主君の怒り／命乞いをする',
  '長篠／命に従い突撃する',
  '長島／門徒を助けに長島へ行く',
  '関ヶ原／西軍（石田三成）につく',
  '人取橋／鬼庭左月と共に殿に立つ',
};

/// 命がけと分かる言葉。
final _mortal = RegExp('命|死|生きて|助からない|討たれ|斬られ|果て|首');

void main() {
  test('死ぬ見込みのとても高かった手: 匂わせに命がけと書いてあり、選んでも大半は生き延びる', () {
    final n = <String, int>{}, d = <String, int>{};
    final hints = <String, String>{};
    for (var seed = 0; seed < 2400; seed++) {
      final rng = Rng(seed + 410000);
      final g = Game(rng: rng)..start(rollBirth(rng));
      final r = Rng(seed);
      var k = 0;
      while (!g.finished && k++ < 4000) {
        final p = g.prompt!;
        var i = -1;
        String? key;
        for (var c = 0; c < p.choices.length; c++) {
          final x = '${p.title}／${p.choices[c].label}';
          if (_deadly.contains(x)) {
            i = c;
            key = x;
            hints[x] = p.choices[c].hint ?? '';
            break;
          }
        }
        if (i < 0) {
          i = seed.isEven
              ? r.range(0, p.choices.length - 1)
              : pickAmbitious(g, p, r);
        }
        g.choose(i);
        if (key != null) {
          n[key] = (n[key] ?? 0) + 1;
          // その年のうちの、ほかの訳の死も数に入る（少し多めに出る）。
          if (g.l.dead != null) d[key] = (d[key] ?? 0) + 1;
        }
      }
    }
    for (final e in hints.entries) {
      expect(_mortal.hasMatch(e.value), isTrue, reason: '${e.key} の匂わせ: ${e.value}');
      expect(RegExp('[0-9０-９%％]').hasMatch(e.value), isFalse, reason: e.value);
    }
    var all = 0, dead = 0;
    for (final k in n.keys) {
      all += n[k]!;
      dead += d[k] ?? 0;
      // 数の集まった手は、亡くなるのが四割を下回る（直す前は 五割〜九割）。
      if (n[k]! >= 40) expect((d[k] ?? 0) / n[k]!, lessThan(.4), reason: '$k ${d[k]}/${n[k]}');
    }
    // ignore: avoid_print
    print('【命がけの手】${n.keys.map((k) => '$k ${d[k] ?? 0}/${n[k]}').join('・')}');
    expect(hints.length, greaterThanOrEqualTo(5));
    expect(all, greaterThan(150));
    expect(dead / all, lessThan(.33));
    expect(dead, greaterThan(0));
  });

  test('合戦の死因の家の名は、いまの呼び名で出る（一五六七年からは徳川・一五八六年からは豊臣）', () {
    /// [year] 年に [lord] に仕える男を作り、[enemy] との合戦で討死させる。
    String fall(int year, String lord, String enemy) {
      for (var s = 0; s < 4000; s++) {
        final rng = Rng(s);
        final g = Game(rng: rng)..start(rollBirth(rng));
        if (g.finished || g.l.female) continue;
        final l = g.l;
        final age = year - l.startYear;
        if (age < 18 || age > 40) continue;
        if (!(g.fa[lord]?.alive ?? false) || !(g.fa[enemy]?.alive ?? false)) continue;
        l
          ..t = age * 2
          ..rank = 2
          ..maxRank = 2
          ..lord = lord;
        for (var i = 0; i < 400 && l.dead == null; i++) {
          l.hp = 30;
          g.battle('van', enemy: enemy, risk: 4);
        }
        if (l.dead == null || !l.dead!.contains('との合戦で討死')) continue;
        return l.dead!;
      }
      throw StateError('合戦で討死する人生を作れなかった');
    }

    expect(fall(1560, '武田', '松平'), '松平との合戦で討死');
    expect(fall(1575, '武田', '松平'), '徳川との合戦で討死');
    expect(fall(1575, '武田', '織田'), '織田との合戦で討死');
    expect(fall(1590, '北条', '織田'), '豊臣との合戦で討死');
    // 形は変わらない（最期の条件は「との合戦で討死」で見ている）。
    expect(fall(1590, '北条', '松平'), endsWith('との合戦で討死'));
  });

  test('女武者は、女性のうち三分ほどに付く。ほかの段の出方は変わらない', () {
    var f = 0, onna = 0, m = 0, mUn = 0, fUnOther = 0;
    const n = 40000;
    for (var i = 0; i < n; i++) {
      final b = rollBirth(Rng(i + 900000));
      final un = b.traits.where((t) => t.tier.name == 'uncommon').toList();
      expect(un.length, lessThanOrEqualTo(1));
      if (!b.female) {
        m++;
        if (un.isNotEmpty) mUn++;
        expect(b.traits.any((t) => t.id == 'onna'), isFalse);
        continue;
      }
      f++;
      if (un.any((t) => t.id == 'onna')) {
        onna++;
      } else if (un.isNotEmpty) {
        fUnOther++;
      }
    }
    // ignore: avoid_print
    print('【女武者】女$f のうち $onna（${(onna / f * 100).toStringAsFixed(2)}%）・女性のほかの珍しい特性 ${(fUnOther / f * 100).toStringAsFixed(2)}%・男性の珍しい特性 ${(mUn / m * 100).toStringAsFixed(2)}%');
    expect(onna / f, inInclusiveRange(.022, .038));
    // 女性のほかの「珍しい」特性は、女武者に押しのけられない（男性の出方から、女武者のぶんの一枠を引いたくらい）。
    expect(fUnOther / f, greaterThan(mUn / m * .8));
  });

  test('能力で増えた手を必ず選ぶ自動プレイ: 印のある手だけを選び、出世の届きやすさを大きくは変えない', () {
    // 選び方の確かめ。
    final g0 = Game(rng: Rng(1))..start(rollBirth(Rng(1)));
    final p = Prompt('ためし', '文', [
      Choice.h('ふつうの手', '匂わせ', () => null),
      Choice.h('武の手', '匂わせ', () => null, via: '武'),
      Choice.h('知か魅の手', '匂わせ', () => null, via: '知魅'),
      Choice.h('特性の手', '匂わせ', () => null, via: '薬の心得'),
    ], () {});
    expect(pickVia(g0, p, Rng(2), '武'), 1);
    expect(pickVia(g0, p, Rng(2), '魅'), 2);
    expect(pickVia(g0, p, Rng(2), '武運'), 1);
    expect(pickVia(g0, p, Rng(2), '政'), pickAmbitious(g0, p, Rng(2)));

    /// 十五で武と運を九十に置いた人生の、城主以上に届いた成人の割合。
    (double, double) castle(bool via) {
      var adults = 0, c = 0, picks = 0;
      for (var seed = 0; seed < 900; seed++) {
        final rng = Rng(seed + 91000);
        final g = Game(rng: rng)..start(rollBirth(rng));
        final r = Rng(seed);
        var k = 0, set = false;
        while (!g.finished && k++ < 4000) {
          final q = g.prompt!;
          if (!set && g.age >= 15) {
            g.l
              ..bu = 90
              ..un = 90;
            set = true;
          }
          final i = via ? pickVia(g, q, r, '武運') : pickAmbitious(g, q, r);
          final v = q.choices[i].via;
          if (via && v != null && (v.contains('武') || v.contains('運'))) picks++;
          g.choose(i);
        }
        if (g.age < 15) continue;
        adults++;
        if (g.l.maxRank >= 5) c++;
      }
      return (c / adults, picks / adults);
    }

    final (base, _) = castle(false);
    final (withVia, picks) = castle(true);
    // ignore: avoid_print
    print('【武と運の手】城主以上 いつもの選び方 ${(base * 100).toStringAsFixed(1)}% → 武と運の手を必ず選ぶ ${(withVia * 100).toStringAsFixed(1)}%（成人あたり ${picks.toStringAsFixed(2)} 手）');
    expect(picks, greaterThan(1));
    // 有利になりすぎない（一・三倍を超えない）。
    expect(withVia, lessThan(base * 1.3));
  });
}
