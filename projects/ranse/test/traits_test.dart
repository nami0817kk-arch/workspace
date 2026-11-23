import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/childhood.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/peace.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/trait_scenes.dart';

import 'bot.dart';

/// 特性100（2026-11-24、1回目〜3回目。場面のある特性は75）。ユーザー「ゲームに効くのを増やしたい。影響が強いほどレア」「100で」。
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

/// 2回目で場面を作った特性。
const _second = {
  'nimble', 'light_sleeper', 'swimmer', 'kind', 'honest', 'gambler', 'singer', 'cook', 'weather', 'handwriting', //
  'iron_gut', 'painless', 'longlived', 'brave', 'builder', 'tactics', 'archer', 'sakai_kin', //
  'surgeon', 'general', 'go', 'deathless', 'dowser', 'kensei', 'ryujin',
};

/// 3回目で場面を作った特性。
const _third = {
  'walker', 'big', 'small', 'stubborn', 'cheerful', 'worrier', 'curious', 'filial', 'patient', 'animals', //
  'keen_ear', 'sea_legs', 'calm', 'generous', 'poet', 'tea', 'temple_kin', 'fallen', //
  'stars', 'smith', 'flute', 'mosugo', 'kamikakushi', 'imiko', 'kitsune',
};

/// [g] を [year] 年の、主家に仕える侍（位は [rank]。既定は位2）に置き直す。
Game _place(Game g, int year, [int rank = 2]) {
  final l = g.l;
  l.t = (year - l.startYear) * 2;
  final lord = g.alive.first.name;
  l
    ..rank = rank
    ..maxRank = rank
    ..lord = rank == 0 ? null : lord
    ..fav = 50
    ..hp = l.maxhp
    ..ronin = false;
  l.flags.removeWhere((f) => f == 'retired' || f == 'priesthood');
  return g;
}

/// [trait] を持たせた男の人生を [year] 年に置く。
Game _withMale(int seed, String trait, int year, [int rank = 2]) {
  for (var s = seed;; s++) {
    final g = _with(s, trait);
    if (g.l.female) continue;
    return _place(g, year, rank);
  }
}

/// [trait] を持たせた男を、[year] 年に働き盛りの歳（一五九〇年より後は、いちばん遅い生まれ）で位 [rank] に置く。
Game _born(int seed, String trait, int year, int rank) {
  for (var s = seed;; s++) {
    final g = _with(s, trait);
    if (g.l.female) continue;
    final age = year - g.l.startYear;
    if (year > 1590 ? g.l.startYear < 1565 : (age < 25 || age > 38)) {
      if (!(year < 1550 && age >= 18 && age <= 38)) continue;
    }
    return _place(g, year, rank);
  }
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

  test('場面の表: 七十五の特性・段が偏らず幻が六つ以上・id はすべて一度ずつ登録され、筋の表の id も実在する', () {
    expect(kTraitScenesDone.length, 75);
    expect(_third.every(kTraitScenesDone.containsKey), isTrue);
    expect(_third.intersection(_second), isEmpty);
    final tiers = [for (final id in kTraitScenesDone.keys) traitOf(id).tier];
    for (final t in TraitTier.values) {
      expect(tiers.where((x) => x == t).length, greaterThanOrEqualTo(t == TraitTier.mythic ? 6 : 15),
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

  test('既存の仕組みに掛ける倍率（2回目）: 痛みに強い・兵法の勘・不死身・剣聖は危うさを下げ、豪胆・弓・将の器は手柄を増やす。長命・鉄の胃袋・堺の親類', () {
    final g = _with(3, 'power');
    g.l.t = 40 * 2;
    for (final t in ['painless', 'tactics', 'deathless', 'kensei']) {
      g.l.traits.add(t);
      expect(traitBattleRisk(g, 'main'), lessThan(1), reason: t);
      g.l.traits.remove(t);
    }
    g.l.traits.add('brave');
    expect(traitBattleGain(g, 'van'), greaterThan(1.1));
    expect(traitBattleGain(g, 'rear'), 1);
    g.l.traits
      ..remove('brave')
      ..add('archer');
    expect(traitBattleGain(g, 'van'), 1);
    expect(traitBattleGain(g, 'rear'), greaterThan(1.1));
    g.l.traits
      ..remove('archer')
      ..add('general');
    g.l.rank = 1;
    expect(traitBattleGain(g, 'main'), 1);
    g.l.rank = 3;
    expect(traitBattleGain(g, 'main'), greaterThan(1));
    g.l.traits.remove('general');
    // 長命の血筋は五十から老いの坂がゆるい。鉄の胃袋は飢えにくい。堺の親類は仕入れが当たりやすい。
    expect(traitOldAge(g), 1);
    expect(traitHunger(g), 1);
    expect(traitTradeEdge(g), 0);
    g.l.traits.addAll(['longlived', 'iron_gut', 'sakai_kin']);
    expect(traitOldAge(g), 1, reason: '四十では効かない');
    g.l.t = 60 * 2;
    expect(traitOldAge(g), lessThan(1));
    expect(traitHunger(g), lessThan(1));
    expect(traitTradeEdge(g), greaterThan(0));
    // 掛け合わせても、危うさが消えることはない。
    g.l.traits.addAll(['swift', 'nighteye', 'rider', 'painless', 'tactics', 'deathless', 'kensei']);
    expect(traitBattleRisk(g, 'van'), greaterThan(.25));
  });

  test('泰平の世（一六〇一年から）では、2回目の場面は陣中の書き出しを出さず、泰平だけの書き出しと手が出る', () {
    // 戦の世の、陣中の書き出しの題。
    const warTitles = {
      '切れた威の糸', '腐れ水', '残った矢尻', '敵方への使い', '陣の崩れ目', //
      '塀の破れ', '夜の同士討ち', '陣中の相撲', '御前の相撲', '所望', '日取り', '一振り',
    };
    Game setUp(String trait, int year) => _withMale(41, trait, year);

    SceneDef scene(Game g, String id) => g.adultScenes.firstWhere((s) => s.id == id);
    String titleOf(String trait, String id, int year) {
      final g = setUp(trait, year);
      // 筋の後段は前の段の旗を立て、年を空けておく。
      for (final f in kTraitPrev[id] ?? const <String>[]) {
        g.setFlag(f);
      }
      final gap = kTraitGap[id];
      if (gap != null) g.setFlag('tr_at:${gap.$1}:${g.year - 5}');
      final sc = scene(g, id);
      expect(sc.cond(g), isTrue, reason: '$id が$year年に出られない');
      sc.run(g, () {});
      final p = g.prompt!;
      for (final c in p.choices) {
        expect(c.hint, isNotNull, reason: '$id: ${c.label}');
        expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
        expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
      }
      return p.title;
    }

    // 戦の世（一五八〇年）の侍には、陣中の書き出しが出る。
    expect(titleOf('nimble', 'tr_nimble', 1580), '切れた威の糸');
    expect(titleOf('tactics', 'tr_tactics', 1580), '陣の崩れ目');
    expect(titleOf('handwriting', 'tr_handwriting', 1580), '代筆');
    // 泰平の世（一六一〇年）の侍には出ない。
    for (final e in kTraitScenesDone.entries) {
      for (final id in e.value) {
        if (kTraitChildSceneIds.contains(id)) continue;
        final g = setUp(e.key, 1610);
        expect(peaceTime(g), isTrue);
        final sc = scene(g, id);
        for (final f in kTraitPrev[id] ?? const <String>[]) {
          g.setFlag(f);
        }
        final gap = kTraitGap[id];
        if (gap != null) g.setFlag('tr_at:${gap.$1}:${g.year - 5}');
        if (g.age < sc.minAge || g.age > sc.maxAge || !sc.cond(g)) continue;
        // 2回目・3回目の場面だけを見る（1回目の場面は陣中の書き出しを残している）。
        if (!_second.contains(e.key) && !_third.contains(e.key)) continue;
        sc.run(g, () {});
        expect(warTitles.contains(g.prompt!.title), isFalse, reason: '$id が泰平の世に「${g.prompt!.title}」');
      }
    }
    // 泰平の世だけの書き出し。
    expect(titleOf('handwriting', 'tr_handwriting', 1610), '手習いの手本');
    expect(titleOf('longlived', 'tr_longlived', 1610), '昔語り');
    expect(titleOf('longlived', 'tr_longlived', 1580), '同い年の葬い');
    // 普請上手は、手伝い普請（江戸の城の石垣）に自分で指図する手が増える。
    for (final has in [true, false]) {
      final g = setUp(has ? 'builder' : 'power', 1610);
      g.l
        ..rank = 6
        ..maxRank = 6;
      final sc = scene(g, 'pc_fushin');
      if (g.l.lord == '松平') g.l.lord = g.alive.firstWhere((f) => f.name != '松平').name;
      expect(sc.cond(g), isTrue);
      sc.run(g, () {});
      expect(g.prompt!.choices.any((c) => c.label.contains('自ら図に引いて指図する')), has);
    }
  });

  test('既存の仕組みに掛ける倍率（3回目）: 心配性・辛抱強い・地獄耳・船に強い・沈着は危うさを下げ、歌詠み・茶の心・没落した名家の出は見込みを上げる', () {
    final g = _with(3, 'power');
    expect(traitHunger(g), 1);
    expect(traitSiege(g), 1);
    expect(traitAssassin(g), 1);
    expect(traitSeaRisk(g), 1);
    expect(traitDisaster(g), 1);
    expect(traitKeepsMen(g), isFalse);
    expect(traitRenga(g), 0);
    expect(traitTea(g), 0);
    expect(traitServeEdge(g), 0);
    expect(traitTempleRefuge(g), isFalse);
    g.l.traits.addAll(['worrier', 'patient', 'keen_ear', 'sea_legs', 'calm', 'generous', 'poet', 'tea', 'fallen', 'temple_kin']);
    expect(traitHunger(g), inExclusiveRange(.3, 1));
    expect(traitSiege(g), inExclusiveRange(.3, 1));
    expect(traitAssassin(g), inExclusiveRange(.3, 1));
    expect(traitSeaRisk(g), inExclusiveRange(.3, 1));
    expect(traitDisaster(g), inExclusiveRange(.3, 1));
    expect(traitKeepsMen(g), isTrue);
    expect(traitRenga(g), greaterThan(0));
    expect(traitTea(g), greaterThan(0));
    expect(traitServeEdge(g), inExclusiveRange(0, .15));
    expect(traitTempleRefuge(g), isTrue);
    // 鉄の胃袋と心配性は掛け合わさる（消えはしない）。
    g.l.traits.add('iron_gut');
    expect(traitHunger(g), inExclusiveRange(.1, .4));
  });

  test('寺に縁者: 主君に腹を切れと命じられたとき、叔父の寺へ駆け込む手が出て、選ぶと仏門に入って生き延びる', () {
    for (final has in [true, false]) {
      final g = _born(61, has ? 'temple_kin' : 'power', 1575, 3);
      g.l.traits.removeWhere((t) => t == 'temple_kin' && !has);
      g.l.fav = 5;
      final sc = g.adultScenes.firstWhere((s) => s.id == 'seppuku_order');
      expect(sc.cond(g), isTrue);
      sc.run(g, () {});
      final p = g.prompt!;
      final i = p.choices.indexWhere((c) => c.label.contains('叔父の寺'));
      expect(i >= 0, has);
      if (!has) continue;
      expect(p.choices[i].hint, isNotNull);
      expect(_digits.hasMatch(p.choices[i].label + p.choices[i].hint!), isFalse);
      g.choose(i);
      expect(g.l.dead, isNull);
      expect(g.hasFlag('priesthood'), isTrue);
      expect(g.l.rank, 0);
      expect(g.l.lord, isNull);
      expect(g.hasFlag('tr_temple_kin_refuge'), isTrue);
    }
  });

  test('3回目の場面は身分で書き分ける: 城主より上の人に村や町の書き出しを出さず、泰平の世だけの書き出しがある', () {
    SceneDef scene(Game g, String id) => g.adultScenes.firstWhere((s) => s.id == id);
    Prompt? open(String trait, String id, int year, int rank) {
      final g = _born(71, trait, year, rank);
      for (final f in kTraitPrev[id] ?? const <String>[]) {
        g.setFlag(f);
      }
      final gap = kTraitGap[id];
      if (gap != null) g.setFlag('tr_at:${gap.$1}:${g.year - 5}');
      final sc = scene(g, id);
      if (g.age < sc.minAge || g.age > sc.maxAge || !sc.cond(g)) return null;
      sc.run(g, () {});
      final p = g.prompt!;
      for (final c in p.choices) {
        expect(c.hint, isNotNull, reason: '$id: ${c.label}');
        expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
        expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
      }
      return p;
    }

    // 村や町の者の書き出しにだけ出る言葉。
    const village = ['名主', '寄り合い', '村の年寄り', '近所の者', '隣近所', '市の隅', '市で、', '旅籠', '便船', '山仕事', '家の戸口', '村の子', '村で、'];
    var seen = 0;
    for (final year in [1580, 1610]) {
      for (final rank in [6, 8]) {
        for (final trait in _third) {
          for (final id in kTraitScenesDone[trait]!) {
            if (kTraitChildSceneIds.contains(id)) continue;
            final p = open(trait, id, year, rank);
            if (p == null) continue;
            seen++;
            for (final w in village) {
              expect(p.text.contains(w), isFalse, reason: '$id が位$rank（$year年）に「$w」: ${p.text}');
            }
          }
        }
      }
    }
    expect(seen, greaterThan(90));
    // 同じ場面でも、身分で題が変わる。
    expect(open('animals', 'tr_animals', 1580, 6)!.title, 'なつかぬ鷹');
    expect(open('animals', 'tr_animals', 1580, 2)!.title, '逃げた鷹');
    expect(open('animals', 'tr_animals', 1580, 0)!.title, '手負いの犬');
    expect(open('big', 'tr_big', 1580, 6)!.title, '陣中の相撲');
    expect(open('big', 'tr_big', 1580, 2)!.title, '御前の相撲');
    expect(open('big', 'tr_big', 1580, 0)!.title, '宮相撲');
    expect(open('small', 'tr_small', 1580, 6)!.title, '小姓と間違えられて');
    expect(open('small', 'tr_small', 1580, 2)!.title, '塀の破れ');
    expect(open('small', 'tr_small', 1580, 0)!.title, '狭い穴');
    // 泰平の世だけの書き出し。
    expect(open('walker', 'tr_walker', 1580, 2)!.title, '雪の峠');
    expect(open('walker', 'tr_walker', 1610, 2)!.title, '継ぎ飛脚');
    expect(open('walker', 'tr_walker', 1610, 6)!.title, '雪の峠');
    expect(open('big', 'tr_big', 1610, 2)!.title, '勧進相撲');
    expect(open('curious', 'tr_curious', 1610, 2)!.title, '煙を呑む草');
    expect(open('curious', 'tr_curious', 1580, 2)!.title, '見慣れぬ品');
    expect(open('poet', 'tr_poet', 1610, 2)!.title, '歌の座');
    expect(open('poet', 'tr_poet', 1625, 2)!.title, '俳諧の座');
    expect(open('tea', 'tr_tea', 1580, 2)!.title, '一服');
    expect(open('tea', 'tr_tea', 1610, 2)!.title, '茶の稽古');
    expect(open('stars', 'tr_stars_day', 1580, 2)!.title, '日取り');
    expect(open('stars', 'tr_stars_day', 1610, 2)!.title, '暦の食い違い');
    expect(open('smith', 'tr_smith_blade', 1580, 2)!.title, '一振り');
    expect(open('smith', 'tr_smith_blade', 1610, 2)!.title, '鍬と刀');
    expect(open('flute', 'tr_flute_call', 1580, 2)!.title, '所望');
    expect(open('flute', 'tr_flute_call', 1610, 2)!.title, '能の笛');
    // 茶の心の場面は、茶の湯の広まる前には出ない。
    final early = _born(71, 'tea', 1548, 2);
    expect(early.year, 1548);
    expect(early.age, greaterThanOrEqualTo(18));
    expect(scene(early, 'tr_tea').cond(early), isFalse);
  });

  test('場面のある七十五の特性を持たせた人生で、その場面（か手）が出て、選択肢に匂わせがあり数字が無い', () {
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
          RegExp('早駆けの使い|敵の物見|流行り病の看病|双子の片割れと並んで|異国の湊|異母兄|不吉な夢|'
                  '子を助けに飛び込み|敵方への使者|しんがりを引き受け|真剣の立ち合い|荒れる沖|'
                  '聞いてはならぬ話|笛を吹きに赴き|消えた子を探して|白い狐のあとを追って')
              .hasMatch(d)) {
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
      // 2回目
      'tr_swimmer_saved', 'tr_kind_took', 'tr_builder_wall', 'tr_surgeon_healer', 'tr_general_trusted', //
      'tr_go_pupil', 'tr_deathless_legend', 'tr_dowser_water', 'tr_kensei_ryu', 'tr_ryujin_shrine_kept',
      'tr_c_ryujin_told',
      // 3回目
      'tr_walker_made', 'tr_worrier_saved', 'tr_keen_ear_used', 'tr_calm_held', 'tr_temple_kin_refuge', //
      'tr_stars_pupil', 'tr_smith_sword', 'tr_flute_master', 'tr_mosugo_heard', 'tr_kami_found', //
      'tr_imiko_spoke', 'tr_kitsune_shrine_kept', 'tr_c_imiko_laughed', 'tr_c_kitsune_fed',
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
    // 2回目: 同じ組（剣聖・竜神）からは一番重い一行だけ。
    final g2 = _with(12, 'kensei');
    g2.l.t = 50 * 2;
    for (final f in ['tr_kensei_won', 'tr_kensei_ryu', 'tr_ryujin_saved', 'tr_ryujin_rain_fell', 'tr_ryujin_shrine_kept']) {
      g2.setFlag(f);
    }
    final lines2 = remembrances(g2);
    expect(lines2.where((s) => s.contains('剣')).length, 1, reason: '$lines2');
    expect(lines2.where((s) => s.contains('竜神') || s.contains('渡し舟')).length, 1, reason: '$lines2');
    expect(lines2.any((s) => s.contains('一流を立て')), isTrue, reason: '$lines2');
    // 3回目: 同じ組（忌み子・狐の子）からは一番重い一行だけ。
    final g3 = _with(13, 'imiko');
    g3.l.t = 60 * 2;
    for (final f in ['tr_imiko_stood', 'tr_imiko_forgave', 'tr_imiko_spoke', 'tr_kitsune_right', 'tr_kitsune_met', 'tr_kitsune_shrine_kept']) {
      g3.setFlag(f);
    }
    final lines3 = remembrances(g3);
    expect(lines3.where((s) => s.contains('忌み子')).length, 1, reason: '$lines3');
    expect(lines3.where((s) => s.contains('狐')).length, 1, reason: '$lines3');
    expect(lines3.any((s) => s.contains('捨てさせなかった')), isTrue, reason: '$lines3');
    for (final s in lines3) {
      expect(_digits.hasMatch(s), isFalse, reason: s);
    }
  });
}
