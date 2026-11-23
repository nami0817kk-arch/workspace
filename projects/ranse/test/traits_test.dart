import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/trait_scenes.dart';

import 'bot.dart';

/// 特性100（2026-11-24、1回目）。ユーザー「ゲームに効くのを増やしたい。影響が強いほどレア」「100で」。
final _digits = RegExp('[0-9０-９%％]');

/// 特性の場面 id → その特性。
final _ownerOf = {
  for (final e in kTraitScenesDone.entries)
    for (final id in e.value) id: e.key,
};

class _Run {
  final ids = <String>[];
  final labels = <String>{};
}

/// 人生の終わりまで進め、出た `tr_` の場面を返す。出た瞬間に、持ち主・前の段の旗と間・匂わせと数字を確かめる。
_Run _play(Game g, Rng r, {bool smart = false}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:tr_')).toSet();
  var n = 0;
  while (!g.finished && n++ < 4000) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:tr_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.ids.add(id);
      final owner = _ownerOf[id];
      expect(owner, isNotNull, reason: '$id が表にない');
      expect(g.has(owner!), isTrue, reason: '$id が$ownerを持たない人に出た');
      expect(g.isChild, kTraitChildSceneIds.contains(id), reason: '$id が${g.age}歳に出た');
      final prev = kTraitPrev[id];
      if (prev != null) {
        expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
        // 段を踏んだ年は、出た今の年に置き換わる（前の段からの間は下の「筋の後段」のテストで見る）。
        expect(trSince(g, kTraitGap[id]!.$1), 0, reason: id);
      }
      for (final c in p!.choices) {
        expect(c.hint, isNotNull, reason: '$id: ${c.label}');
        expect(_digits.hasMatch(c.label), isFalse, reason: '$id: ${c.label}');
        expect(_digits.hasMatch(c.hint!), isFalse, reason: '$id: ${c.hint}');
      }
    }
    known = now;
    for (final c in p!.choices) {
      out.labels.add(c.label);
    }
    g.choose(smart ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
  return out;
}

/// [trait] を持たせた人生を始める（[adult] なら元服まで生き延びる生まれを選ぶ）。
Game _with(int seed, String trait) {
  for (var s = seed;; s += 7919) {
    final rng = Rng(s);
    final b = rollBirth(rng);
    final g = Game(rng: rng);
    g.start(b);
    if (g.finished) continue;
    if (!g.l.traits.contains(trait)) g.l.traits.add(trait);
    return g;
  }
}

void main() {
  test('百の特性がそろい、id は重複せず、どれも数字のない説明を持ち、段の数が目安どおり', () {
    expect(kTraits.length, 100);
    expect(kTraits.map((t) => t.id).toSet().length, 100);
    expect(kTraits.map((t) => t.name).toSet().length, 100);
    for (final t in kTraits) {
      expect(t.desc, isNotEmpty, reason: t.id);
      expect(_digits.hasMatch(t.desc), isFalse, reason: t.desc);
      expect(_digits.hasMatch(t.name), isFalse, reason: t.name);
      expect(traitOf(t.id), same(t));
      expect(traitName(t.id), t.name);
    }
    int n(TraitTier tier) => kTraits.where((t) => t.tier == tier).length;
    expect(n(TraitTier.common), 40);
    expect(n(TraitTier.uncommon), 32);
    expect(n(TraitTier.rare), 20);
    expect(n(TraitTier.mythic), 8);
    // 元の13（has('<id>') で見ているコードがある）は id を変えずに残っている。
    for (final id in [
      'power', 'prodigy', 'beauty', 'lucky', 'sickly', 'hardy', 'amb', //
      'loyal', 'gunner', 'rider', 'abacus', 'tongue', 'onna',
    ]) {
      expect(kTraits.any((t) => t.id == id), isTrue, reason: id);
    }
    expect(kTraitOnna.id, 'onna');
    // 段の名は画面に出す。
    expect(TraitTier.values.map((t) => t.label).toList(), ['よくある', '珍しい', '稀', '幻']);
  });

  test('一万の生まれ: 段ごとの出方が目安の範囲・幻は数百人に一人・一人に三つまで・身分と性別で付かない特性は付かない', () {
    const n = 10000;
    final count = {for (final t in TraitTier.values) t: 0};
    var any = 0;
    final seen = <String>{};
    for (var i = 0; i < n; i++) {
      final b = rollBirth(Rng(900000 + i));
      expect(b.traits.length, lessThanOrEqualTo(kMaxTraits));
      expect(b.traits.map((t) => t.id).toSet().length, b.traits.length);
      if (b.traits.isNotEmpty) any++;
      for (final t in b.traits) {
        count[t.tier] = count[t.tier]! + 1;
        seen.add(t.id);
        expect(t.fits(b.cls, b.female), isTrue, reason: '${t.id} ${b.cls.id} ${b.female}');
        if (t.id == 'onna') expect(b.female, isTrue);
        if (t.id == 'rakuin') expect(b.cls.rank, lessThanOrEqualTo(2));
      }
      // 一つの段からは一つだけ。
      final tiers = b.traits.map((t) => t.tier).toList();
      expect(tiers.toSet().length, tiers.length);
    }
    double rate(TraitTier t) => count[t]! / n;
    // ignore: avoid_print
    print('【特性の出方】一万の生まれ: よくある${count[TraitTier.common]}・珍しい${count[TraitTier.uncommon]}・'
        '稀${count[TraitTier.rare]}・幻${count[TraitTier.mythic]}・特性あり$any・出た特性${seen.length}種');
    expect(rate(TraitTier.common), inInclusiveRange(.20, .30)); // 数人に一人
    expect(rate(TraitTier.uncommon), inInclusiveRange(.055, .1)); // 十数人に一人
    expect(rate(TraitTier.rare), inInclusiveRange(.015, .04)); // 数十人に一人
    expect(rate(TraitTier.mythic), inInclusiveRange(.001, .008)); // 数百人に一人
    expect(any / n, inInclusiveRange(.25, .4));
    expect(seen.length, greaterThanOrEqualTo(95));
  });

  test('稀少度は段で大きくなる（同じ身分なら、珍しい段の特性を持つほど「約◯分の1」が大きい）', () {
    final byTier = <int, List<double>>{};
    for (var i = 0; i < 40000; i++) {
      final b = rollBirth(Rng(500000 + i));
      if (b.cls.id != 'farmer' || b.traits.length > 1) continue;
      final k = b.traits.isEmpty ? -1 : b.traits.first.tier.index;
      (byTier[k] ??= []).add(b.rarity);
    }
    double median(List<double> l) => (l..sort())[l.length ~/ 2];
    final m = [for (final k in [-1, 0, 1, 2, 3]) median(byTier[k]!)];
    // ignore: avoid_print
    print('【稀少度】農民の中央 特性なし${m[0].round()}・よくある${m[1].round()}・珍しい${m[2].round()}・稀${m[3].round()}・幻${m[4].round()}');
    for (var i = 1; i < m.length; i++) {
      expect(m[i], greaterThan(m[i - 1] * 2), reason: '$m');
    }
    for (final l in byTier.values) {
      for (final x in l) {
        expect(x, lessThanOrEqualTo(kPopulation));
      }
    }
  });

  test('場面の表: 二十五の特性・段が偏らず幻が二つ以上・id はすべて一度ずつ登録され、筋の表の id も実在する', () {
    expect(kTraitScenesDone.length, 25);
    final tiers = [for (final id in kTraitScenesDone.keys) traitOf(id).tier];
    for (final t in TraitTier.values) {
      expect(tiers.where((x) => x == t).length, greaterThanOrEqualTo(t == TraitTier.mythic ? 2 : 5),
          reason: t.label);
    }
    final g = Game(rng: Rng(1));
    final adult = g.adultScenes.map((s) => s.id).toList();
    final child = g.childScenes.map((s) => s.id).toList();
    for (final e in kTraitScenesDone.entries) {
      final tier = traitOf(e.key).tier;
      // 稀は二つ以上・幻は三つ以上の場面。
      if (tier == TraitTier.rare) expect(e.value.length, greaterThanOrEqualTo(2), reason: e.key);
      if (tier == TraitTier.mythic) expect(e.value.length, greaterThanOrEqualTo(3), reason: e.key);
      for (final id in e.value) {
        final list = kTraitChildSceneIds.contains(id) ? child : adult;
        expect(list.where((x) => x == id).length, 1, reason: id);
        expect(id.startsWith('tr_'), isTrue, reason: id);
      }
    }
    for (final id in [...kTraitPrev.keys, ...kTraitGap.keys]) {
      expect(_ownerOf.containsKey(id), isTrue, reason: id);
    }
    for (final id in kTraitHooks.keys) {
      expect(kTraitScenesDone.containsKey(id), isTrue, reason: id);
    }
    expect(adult.where((x) => x.startsWith('tr_')).length + child.where((x) => x.startsWith('tr_')).length,
        _ownerOf.length);
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る', () {
    final g = _with(5, 'lucky');
    for (final e in kTraitPrev.entries) {
      final id = e.key;
      final (chain, gap) = kTraitGap[id]!;
      g.l.t = 30 * 2;
      g.l.flags.removeWhere((f) => f.startsWith('tr_'));
      expect(trChainReady(g, id), isFalse, reason: id);
      g.setFlag(e.value.first);
      g.setFlag('tr_at:$chain:${g.year}');
      expect(trChainReady(g, id), isFalse, reason: '$id が同じ年に出る');
      g.l.t += gap * 2;
      expect(trChainReady(g, id), isTrue, reason: id);
    }
  });

  test('既存の仕組みに掛ける倍率: 俊足・夜目・馬術は討死の危うさを下げ、馬術・鉄砲は手柄を増やす。弁舌は説く手に効く', () {
    final g = _with(3, 'power');
    expect(traitBattleRisk(g, 'van'), 1);
    expect(traitBattleGain(g, 'van'), 1);
    expect(traitPersuade(g), 0);
    g.l.traits.addAll(['swift', 'nighteye', 'rider', 'gunner', 'tongue']);
    expect(traitBattleRisk(g, 'van'), lessThan(.7));
    expect(traitBattleRisk(g, 'rear'), lessThan(traitBattleRisk(g, 'van') * 1.3));
    expect(traitBattleGain(g, 'van'), greaterThan(1));
    g.l.gun = true;
    expect(traitBattleGain(g, 'rear'), greaterThan(1.1));
    expect(traitPersuade(g), greaterThan(0));
  });

  test('場面のある二十五の特性を持たせた人生で、その場面（か手）が出て、選択肢に匂わせがあり数字が無い', () {
    final missing = <String>[];
    final stages = <String, Set<String>>{};
    // 手だけで効く所（熱病・子の病・連れ合いの病の薬草）。
    const herbalHands = ['裏の野で熱さましの草を摘み、自分で煎じる', '自ら山へ入り、熱さましの草を摘んで煎じる', '胸に効く草を自ら摘み、毎日煎じて飲ませる'];
    var herbalHand = 0;
    var k = 0;
    for (final e in kTraitScenesDone.entries) {
      final trait = e.key;
      k++;
      final tier = traitOf(trait).tier;
      final lives = tier == TraitTier.mythic ? 160 : (tier == TraitTier.rare ? 100 : 60);
      final got = <String>{};
      for (var i = 0; i < lives; i++) {
        final g = _with(7000 + i * 13 + k * 101, trait);
        if (trait == 'rakuin' && g.l.cls.rank > 2) continue;
        final run = _play(g, Rng(i), smart: i.isOdd);
        got.addAll(run.ids.where((id) => _ownerOf[id] == trait));
        if (trait == 'herbal' && run.labels.any(herbalHands.contains)) herbalHand++;
      }
      stages[trait] = got;
      if (got.isEmpty) missing.add(trait);
    }
    // ignore: avoid_print
    print('【特性の場面】${stages.entries.map((e) => '${e.key}:${e.value.length}/${kTraitScenesDone[e.key]!.length}').join(' ')}・薬草の手$herbalHand');
    expect(missing, isEmpty, reason: '場面の出なかった特性 $missing');
    expect(herbalHand, greaterThan(0));
    // 稀は筋の二の段まで、幻は三つ以上の場面まで届く。
    for (final e in stages.entries) {
      final tier = traitOf(e.key).tier;
      if (tier == TraitTier.rare) expect(e.value.length, greaterThanOrEqualTo(2), reason: '${e.key} ${e.value}');
      if (tier == TraitTier.mythic) expect(e.value.length, greaterThanOrEqualTo(3), reason: '${e.key} ${e.value}');
    }
  });

  test('ふつうの人生では、特性を持つ人にだけその場面が出て、持つ人の多くが出会い、新しい場面で亡くなるのは稀', () {
    var lives = 0, holders = 0, met = 0, trDeaths = 0;
    for (var seed = 0; seed < 1500; seed++) {
      final rng = Rng(seed + 61000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final run = _play(g, Rng(seed), smart: seed.isOdd);
      lives++;
      // 場面のある特性を持ち、三十まで生きた人のうち、その特性の場面に出会った人。
      final mine = g.l.traits.where(kTraitScenesDone.containsKey).toList();
      if (mine.isNotEmpty && g.age >= 30) {
        holders++;
        if (run.ids.any((id) => mine.contains(_ownerOf[id]))) met++;
      }
      final d = g.l.dead ?? '';
      if (run.ids.isNotEmpty &&
          RegExp('早駆けの使い|敵の物見|流行り病の看病|双子の片割れと並んで|異国の湊|異母兄|不吉な夢').hasMatch(d)) {
        trDeaths++;
      }
    }
    // ignore: avoid_print
    print('【ふつうの人生】$lives人生: 場面のある特性を持ち三十まで生きた$holders・その場面に出会った$met・新しい場面での死$trDeaths');
    expect(holders, greaterThan(lives * .02));
    expect(met, greaterThan(holders * .6));
    expect(trDeaths, lessThan(lives * .005 + 2));
  });

  test('遺されたもの: 特性の場面の主な旗に行があり、数字が無い', () {
    final ids = kRemembrances.map((r) => r.id).toSet();
    for (final f in [
      'tr_power_stone', 'tr_herbal_village', 'tr_twin_met', 'tr_nanban_sailed', //
      'tr_painter_castle_done', 'tr_rakuin_named', 'tr_rakuin_lord', 'tr_yume_known', 'tr_c_prodigy_praised',
    ]) {
      expect(ids.contains(f), isTrue, reason: f);
    }
    final g = _with(11, 'twin');
    g.l.t = 40 * 2;
    g.setFlag('tr_twin_met');
    g.meet('片割れ', '与作', 60);
    g.setFlag('tr_rakuin_named');
    g.setFlag('tr_rakuin_lord');
    final lines = remembrances(g);
    expect(lines.any((s) => s.contains('与作')), isTrue, reason: '$lines');
    // 同じ組（落胤）からは一番重い一行だけ。
    expect(lines.where((s) => s.contains('落胤')).length, 1, reason: '$lines');
    for (final s in lines) {
      expect(_digits.hasMatch(s), isFalse, reason: s);
    }
  });
}
