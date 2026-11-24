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

/// 特性100（2026-11-24、1回目〜4回目。百の特性すべてに場面がある）。ユーザー「ゲームに効くのを増やしたい。影響が強いほどレア」「100で」。
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

/// 4回目で場面を作った特性（これで百すべて）。
const _fourth = {
  'lustful', 'lazy', 'vain', 'shy', 'birthmark', 'big_family', 'sickly', 'hardy', 'amb', 'loyal', 'abacus', //
  'lefty', 'cunning', 'jealous', 'vengeful', 'dialects', 'sword', 'stealth', 'onna', //
  'mimic', 'seer', 'nito', 'kaizoku', 'tenka_so', 'keikoku',
};

/// [trait] を持たせた女の人生を [year] 年に置く。
Game _withFemale(int seed, String trait, int year, [int rank = 2]) {
  for (var s = seed;; s++) {
    final g = _with(s, trait);
    if (!g.l.female) continue;
    final age = year - g.l.startYear;
    if (age < 20 || age > 45) continue;
    return _place(g, year, rank);
  }
}

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

  test('場面の表: 百の特性すべてに場面があり（段ごとに四十・三十二・二十・八）、id はすべて一度ずつ登録され、筋の表の id も実在する', () {
    expect(kTraitScenesDone.length, 100);
    expect(kTraitScenesDone.keys.toSet(), kTraits.map((t) => t.id).toSet());
    expect(_third.every(kTraitScenesDone.containsKey), isTrue);
    expect(_fourth.every(kTraitScenesDone.containsKey), isTrue);
    expect(_fourth.length, 25);
    expect(_third.intersection(_second), isEmpty);
    expect(_fourth.intersection({..._second, ..._third}), isEmpty);
    final tiers = [for (final id in kTraitScenesDone.keys) traitOf(id).tier];
    const want = {TraitTier.common: 40, TraitTier.uncommon: 32, TraitTier.rare: 20, TraitTier.mythic: 8};
    for (final t in TraitTier.values) {
      expect(tiers.where((x) => x == t).length, want[t], reason: t.label);
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
      // 4回目
      '左の太刀', '敵の国言葉', '女の槍', '二刀を見たい', '潮の瀬戸', '海の関', '祟りの家', '晴れの日', '空いた席', '目録',
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
        // 2回目からの場面だけを見る（1回目の場面は陣中の書き出しを残している）。
        if (!_second.contains(e.key) && !_third.contains(e.key) && !_fourth.contains(e.key)) continue;
        sc.run(g, () {});
        expect(warTitles.contains(g.prompt!.title), isFalse, reason: '$id が泰平の世に「${g.prompt!.title}」');
      }
    }
    // 泰平の世だけの書き出し。
    expect(titleOf('handwriting', 'tr_handwriting', 1610), '手習いの手本');
    expect(titleOf('longlived', 'tr_longlived', 1610), '昔語り');
    expect(titleOf('longlived', 'tr_longlived', 1580), '同い年の葬い');
    // 4回目: 泰平の世だけの題。
    for (final (trait, id, war, peace) in [
      ('vain', 'tr_vain', '晴れの日', '伊達な拵え'),
      ('amb', 'tr_amb', '空いた席', '空いた役'),
      ('abacus', 'tr_abacus', '勘定の穴', '勘定方'),
      ('lefty', 'tr_lefty', '左の太刀', '左の構え'),
      ('dialects', 'tr_dialects', '敵の国言葉', '諸国の言葉'),
      ('sword', 'tr_sword', '目録', '道場の看板'),
      ('seer', 'tr_seer_house', '祟りの家', '古戦場'),
      ('nito', 'tr_nito_duel', '二刀を見たい', '二刀の型'),
      ('kaizoku', 'tr_kaizoku_toll', '海の関', '陸に上がった者'),
      ('kaizoku', 'tr_kaizoku_sea', '潮の瀬戸', '潮の道'),
    ]) {
      expect(titleOf(trait, id, 1580), war, reason: id);
      expect(titleOf(trait, id, 1610), peace, reason: id);
    }
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
        for (final trait in {..._third, ..._fourth}) {
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
    expect(seen, greaterThan(190));
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

  test('既存の仕組みに掛ける倍率と手（4回目）: 左利き・嫉妬深い・悪知恵・執念深い・国言葉・忍び足', () {
    final g = _with(3, 'power');
    expect(traitBattleGain(g, 'van'), 1);
    expect(traitTradeEdge(g), 0);
    expect(traitServeEdge(g), 0);
    expect(traitTrap(g), 0);
    expect(traitNightRaid(g), isFalse);
    g.l.traits.add('lefty');
    expect(traitBattleGain(g, 'van'), inExclusiveRange(1, 1.1));
    expect(traitBattleGain(g, 'rear'), 1, reason: '左利きは先陣の打ち合いにだけ効く');
    g.l.traits
      ..remove('lefty')
      ..add('jealous');
    g.l.people.remove('好敵手');
    expect(traitBattleGain(g, 'main'), 1, reason: '好敵手がいなければ効かない');
    g.meet('好敵手', '源太', 30);
    expect(traitBattleGain(g, 'main'), inExclusiveRange(1, 1.1));
    g.l.traits.addAll(['cunning', 'vengeful', 'dialects', 'stealth']);
    expect(traitTradeEdge(g), inExclusiveRange(0, .1));
    expect(traitServeEdge(g), inExclusiveRange(0, .08));
    expect(traitTrap(g), inExclusiveRange(0, .2));
    expect(traitNightRaid(g), isTrue);
    // 掛け合わせても、仕官と仕入れの見込みは小さい。
    g.l.traits.addAll(['fallen', 'sakai_kin']);
    expect(traitServeEdge(g), lessThan(.15));
    expect(traitTradeEdge(g), lessThan(.2));
    // 覚え書きの表は、4回目の珍しい八つをすべて載せている。
    for (final id in ['lefty', 'cunning', 'jealous', 'vengeful', 'dialects', 'sword', 'stealth', 'onna']) {
      expect(kTraitHooks.containsKey(id), isTrue, reason: id);
    }
  });

  test('国言葉に通じる: 泰平の世の関所に、土地の者の顔で通る手が出て、選んでも命を落とさない', () {
    for (final has in [true, false]) {
      final g = _born(81, has ? 'dialects' : 'power', 1620, 0);
      g.l.traits.removeWhere((t) => t == 'dialects' && !has);
      g.setFlag('way_outlaw');
      final sc = g.adultScenes.firstWhere((s) => s.id == 'pc_sekisho');
      expect(sc.cond(g), isTrue);
      sc.run(g, () {});
      final p = g.prompt!;
      final i = p.choices.indexWhere((c) => c.label.contains('土地の言葉'));
      expect(i >= 0, has);
      if (!has) continue;
      expect(p.choices[i].hint, isNotNull);
      expect(_digits.hasMatch(p.choices[i].label + p.choices[i].hint!), isFalse);
      g.choose(i);
      expect(g.l.dead, isNull);
      expect(g.hasFlag('pc_seki_kotoba'), isTrue);
    }
  });

  test('4回目の場面は、僧・忍び・野の者にも合う書き出しを持ち、女性と男性で書き分ける', () {
    SceneDef scene(Game g, String id) => g.adultScenes.firstWhere((s) => s.id == id);
    Prompt open(Game g, String id) {
      for (final f in kTraitPrev[id] ?? const <String>[]) {
        g.setFlag(f);
      }
      final gap = kTraitGap[id];
      if (gap != null) g.setFlag('tr_at:${gap.$1}:${g.year - 5}');
      final sc = scene(g, id);
      expect(g.age >= sc.minAge && g.age <= sc.maxAge && sc.cond(g), isTrue, reason: id);
      sc.run(g, () {});
      final p = g.prompt!;
      for (final c in p.choices) {
        expect(c.hint, isNotNull, reason: '$id: ${c.label}');
        expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
        expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
      }
      return p;
    }

    // 村や町の者・僧・野の者・忍びで、書き出しが違う。
    for (final (trait, id) in [
      ('lazy', 'tr_lazy'), ('shy', 'tr_shy'), ('loyal', 'tr_loyal'), ('hardy', 'tr_hardy'), ('abacus', 'tr_abacus'), //
      ('cunning', 'tr_cunning'), ('jealous', 'tr_jealous'), ('vengeful', 'tr_vengeful'), ('stealth', 'tr_stealth'), //
      ('mimic', 'tr_mimic_voice'), ('seer', 'tr_seer_shadow'), ('nito', 'tr_nito_both'), //
      ('tenka_so', 'tr_tenka_face'), ('keikoku', 'tr_keikoku_blade'),
    ]) {
      final common = open(_born(91, trait, 1580, 0), id).text;
      final monk = open(_born(91, trait, 1580, 0)..setFlag('priesthood'), id).text;
      final wild = open(_born(91, trait, 1580, 0)..setFlag('way_outlaw'), id).text;
      final nin = open(
        _born(91, trait, 1580, 0)
          ..setFlag('way_outlaw')
          ..setFlag('nukenin'),
        id,
      ).text;
      final high = open(_born(91, trait, 1580, 8), id).text;
      expect({common, monk, wild, nin, high}.length, 5, reason: '$id の書き出しが身分で分かれていない');
      expect(monk.contains('寺') || monk.contains('僧') || monk.contains('出家') || monk.contains('戒め') || monk.contains('庫裏') || monk.contains('本堂'),
          isTrue, reason: '$id: $monk');
      for (final w in ['名主', '寄り合い', '近所', '村の', '家の戸口']) {
        expect(monk.contains(w), isFalse, reason: '$id の僧の書き出しに「$w」: $monk');
        expect(wild.contains(w), isFalse, reason: '$id の野の者の書き出しに「$w」: $wild');
        expect(nin.contains(w), isFalse, reason: '$id の忍びの書き出しに「$w」: $nin');
      }
    }
    // 大柄の女性にも場面がある（相撲は男だけ）。
    final big = _withFemale(101, 'big', 1580, 0);
    expect(scene(big, 'tr_big').cond(big), isFalse);
    expect(open(big, 'tr_big_f').title, '背負う');
    final bigM = _born(101, 'big', 1580, 0);
    expect(scene(bigM, 'tr_big_f').cond(bigM), isFalse);
    // 女武者は、戦の世と泰平の世で題が変わる。
    expect(open(_withFemale(111, 'onna', 1580), 'tr_onna').title, '女の槍');
    for (var s = 111;; s++) {
      final g = _with(s, 'onna');
      if (!g.l.female || g.l.startYear < 1565) continue;
      expect(open(_place(g, 1610), 'tr_onna').title, '別式');
      break;
    }
    final man = _born(111, 'onna', 1580, 2);
    expect(scene(man, 'tr_onna').cond(man), isFalse);
    // 傾国の美貌は、男女で書き出しが違う。
    for (final id in ['tr_keikoku_blade', 'tr_keikoku_wish']) {
      final f = open(_withFemale(121, 'keikoku', 1580, 0), id).text;
      final m = open(_born(121, 'keikoku', 1580, 0), id).text;
      expect(f == m, isFalse, reason: id);
    }
    expect(open(_withFemale(121, 'keikoku', 1580, 0), 'tr_keikoku_blade').text.contains('嫁に望む'), isTrue);
    expect(open(_born(121, 'keikoku', 1580, 0), 'tr_keikoku_blade').text.contains('許婚'), isTrue);
    // 天下の相は、位も兵も大きくは動かさない（集まる者を受け入れても、兵は少し増えるだけ）。
    final t = _born(131, 'tenka_so', 1580, 6);
    final before = t.l.troops;
    open(t, 'tr_tenka_rumor');
    t.choose(0);
    expect(t.l.rank, 6);
    expect(t.l.troops - before, inInclusiveRange(1, 40));
    expect(t.hasFlag('tr_tenka_gathered'), isTrue);
  });

  test('1回目・2回目の場面は、城主より上の人には書き出しだけを差し替える（題・選択肢は元のまま）', () {
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
      return g.prompt;
    }

    var swapped = 0;
    for (final e in kTraitHighOpen.entries) {
      final id = e.key;
      final trait = _ownerOf[id];
      expect(trait, isNotNull, reason: id);
      expect(_second.contains(trait) || (!_third.contains(trait) && !_fourth.contains(trait)), isTrue, reason: id);
      expect(_digits.hasMatch(e.value.$2), isFalse, reason: id);
      // 身分のない人には、元の書き出し（差し替えの目印の言葉を含む）。
      final low = open(trait!, id, 1580, 0);
      if (low != null && low.text.contains(e.value.$1)) {
        expect(low.text == e.value.$2, isFalse, reason: id);
      }
      // 大名には、差し替えた書き出し。題と選択肢の数は変わらない。
      final high = open(trait, id, 1580, 8);
      if (high == null) continue;
      expect(high.text.contains(e.value.$1), isFalse, reason: '$id が大名に「${e.value.$1}」: ${high.text}');
      if (high.text == e.value.$2) {
        swapped++;
        expect(high.choices.length, greaterThanOrEqualTo(2));
        for (final c in high.choices) {
          expect(c.hint, isNotNull, reason: id);
        }
      }
    }
    expect(swapped, greaterThanOrEqualTo(kTraitHighOpen.length - 6), reason: '差し替えの効いた場面 $swapped／${kTraitHighOpen.length}');
    // 主家に仕える城主（位6）で、陣中・家中の書き出しが出たときは差し替えない。
    final sv = open('rider', 'tr_rider', 1580, 6)!;
    expect(sv.text.contains('厩'), isTrue);
    // 1回目・2回目の場面を大名に出して、村の者の書き出しの言葉が残っていない。
    const village = ['村の辻', '寄り合い', '隣村', '近所の者', '村はずれ', '村の水車', '村の土手', '隣の村', '納屋'];
    for (final e in kTraitScenesDone.entries) {
      if (_third.contains(e.key) || _fourth.contains(e.key)) continue;
      for (final id in e.value) {
        if (kTraitChildSceneIds.contains(id)) continue;
        final p = open(e.key, id, 1580, 8);
        if (p == null) continue;
        for (final w in village) {
          expect(p.text.contains(w), isFalse, reason: '$id が大名に「$w」: ${p.text}');
        }
      }
    }
  });

  test('百の特性のどれを持たせた人生でも、その場面（か手）が出て、選択肢に匂わせがあり数字が無い', () {
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
                  '聞いてはならぬ話|笛を吹きに赴き|消えた子を探して|白い狐のあとを追って|'
                  '二刀を見たいと望んだ|舟戦で舳先に立ち|天下を取る相を危ぶまれ|顔を望まれて断った')
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
      // 4回目
      'tr_lazy_made', 'tr_sickly_read', 'tr_hardy_stood', 'tr_loyal_repaid', 'tr_abacus_found', 'tr_big_f_carried', //
      'tr_lefty_won', 'tr_vengeful_told', 'tr_onna_taught', 'tr_mimic_son', 'tr_seer_talked', 'tr_nito_kata', //
      'tr_kaizoku_pilot', 'tr_tenka_own', 'tr_keikoku_painted',
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
    // 4回目: 同じ組（天下の相・傾国の美貌）からは一番重い一行だけ。
    final g4 = _with(14, 'tenka_so');
    g4.l.t = 60 * 2;
    for (final f in ['tr_tenka_asked', 'tr_tenka_gathered', 'tr_tenka_faced', 'tr_tenka_own', 'tr_keikoku_stopped', 'tr_keikoku_refused', 'tr_keikoku_painted']) {
      g4.setFlag(f);
    }
    final lines4 = remembrances(g4);
    expect(lines4.where((s) => s.contains('天下を取る相')).length, 1, reason: '$lines4');
    expect(lines4.where((s) => s.contains('美貌')).length, 1, reason: '$lines4');
    expect(lines4.any((s) => s.contains('自分の天下だった')), isTrue, reason: '$lines4');
    expect(lines4.any((s) => s.contains('絵師に描かせた')), isTrue, reason: '$lines4');
    for (final s in lines4) {
      expect(_digits.hasMatch(s), isFalse, reason: s);
    }
  });

  test('1回目〜3回目の場面も、僧・忍び・野の者に村の書き出しが出ず、城主より上の手に村の言葉が出ない', () {
    // 1回目〜3回目の大人の場面（4回目は上のテストで見ている）。
    final ids = [
      for (final e in kTraitScenesDone.entries)
        if (!_fourth.contains(e.key))
          for (final id in e.value)
            if (!id.startsWith('tr_c_')) id,
    ];
    expect(ids.length, greaterThan(100));

    /// [id] の場面が出る身分 [status] の人を [year] 年に作る（条件が合わなければ null）。
    Game? build(String id, String status, int year) {
      for (var s = 1000; s < 2200; s++) {
        final rng = Rng(s * 7 + year);
        final g = Game(rng: rng)..start(rollBirth(rng));
        if (g.finished) continue;
        final sc = g.adultScenes.firstWhere((x) => x.id == id);
        final l = g.l;
        final age = year - l.startYear;
        if (age < sc.minAge || age > sc.maxAge || age < 16) continue;
        if (status == 'high' && l.female) continue;
        final trait = _ownerOf[id]!;
        if (!l.traits.contains(trait)) l.traits.add(trait);
        l
          ..t = age * 2
          ..hp = l.maxhp
          ..ronin = false
          ..fav = 50
          ..rank = status == 'high' ? 8 : 0
          ..maxRank = status == 'high' ? 8 : 0
          ..lord = status == 'high' ? g.alive.first.name : null;
        l.flags.removeWhere((f) => f == 'retired' || f == 'priesthood');
        if (status == 'monk') g.setFlag('priesthood');
        if (status == 'wild' || status == 'nin') g.setFlag('way_outlaw');
        if (status == 'nin') g.setFlag('nukenin');
        for (final f in kTraitPrev[id] ?? const <String>[]) {
          g.setFlag(f);
        }
        final gap = kTraitGap[id];
        if (gap != null) g.setFlag('tr_at:${gap.$1}:${g.year - 6}');
        if (!sc.cond(g)) continue;
        sc.run(g, () {});
        return g.prompt == null ? null : g;
      }
      return null;
    }

    var opened = 0, highOpened = 0;
    final scenes = <String>{};
    for (final id in ids) {
      for (final year in [1580, 1610]) {
        for (final st in ['monk', 'wild', 'nin']) {
          final g = build(id, st, year);
          if (g == null) continue;
          opened++;
          scenes.add(id);
          final p = g.prompt!;
          for (final w in ['名主', '庄屋', '寄り合い', '近所', '村の', '隣村', '家の戸口']) {
            expect(p.text.contains(w), isFalse, reason: '$id（$st・$year年）の書き出しに「$w」: ${p.text}');
          }
          for (final c in p.choices) {
            expect(c.hint, isNotNull, reason: '$id: ${c.label}');
            expect(_digits.hasMatch('${c.label}${c.hint}'), isFalse, reason: '$id: ${c.label}');
            // 忍び・野の者の手に、村の役の言葉は出ない。
            if (st != 'monk') {
              for (final w in ['庄屋', '名主', '寄り合い', '上の者へ知らせる']) {
                expect('${c.label}${c.hint}'.contains(w), isFalse, reason: '$id（$st）の手に「$w」: ${c.label}／${c.hint}');
              }
            }
          }
        }
        // 城主より上（大名）の手に、村の者として語る言葉は出ない。
        final h = build(id, 'high', year);
        if (h == null) continue;
        highOpened++;
        for (final c in h.prompt!.choices) {
          for (final w in ['村の者たちに', '上の者へ知らせる', '庄屋', '名主', '寄り合い']) {
            expect('${c.label}${c.hint}'.contains(w), isFalse, reason: '$id（大名・$year年）の手に「$w」: ${c.label}／${c.hint}');
          }
        }
      }
    }
    // ignore: avoid_print
    print('【特性の場面の書き分け】僧・忍び・野の者に開いた書き出し $opened（場面 ${scenes.length}／${ids.length}）・大名に開いた場面 $highOpened');
    expect(scenes.length, greaterThan(ids.length * .7));
    expect(highOpened, greaterThan(60));
  });
}
