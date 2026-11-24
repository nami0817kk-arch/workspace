import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/endings_catalog.dart';
import 'package:ranse/engine/endings_peace.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/peace.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/ways.dart';

import 'bot.dart';

/// 泰平の世（一六〇一年から）に亡くなった人の最期（`endings_peace.dart`）と、
/// 「泰平の世で亡くなった人には、戦の世の言葉の最期より泰平の最期を先に出す」決まり（`ending.dart`）のテスト。

/// 差し込みの記号（これのほかの波括弧は残してはいけない）。
final _slots = RegExp(r'\{(名|歳|年|元号|国|友|子)\}');
final _digits = RegExp('[0-9０-９%％]');

/// 今回足した最期（id に `_hei_` が入る）。
bool _isNew(EndingDef e) => e.id.contains('_hei_');

final _plFocus = RegExp('詰める|城の番を勤める|役方|道場|手習い所|新田を拓く|廻船|謡と仕舞|俳諧の座|講の仲間|家訓|縁組と');

/// 命を落としにくい選び方（泰平の世まで生きる人生を増やす）。
int _pickCareful(Game g, Prompt p, Rng r) {
  final cs = p.choices;
  if (p.title == 'この年の心がけ') {
    // 泰平の世の暮らしの重点（勤め・道場・手習い所・新田・廻船・俳諧・講・家訓・縁組）を、三割ほどの年に選ぶ。
    final life = [
      for (var i = 0; i < cs.length; i++)
        if (_plFocus.hasMatch(cs[i].label)) i,
    ];
    if (life.isNotEmpty && r.chance(.3)) return life[r.range(0, life.length - 1)];
    for (final w in ['体を休める', '主君に尽くす', '奥向きに尽くす', '学問に励む']) {
      final i = cs.indexWhere((c) => c.label.contains(w));
      if (i >= 0 && r.chance(.4)) return i;
    }
    final safe = [
      for (var i = 0; i < cs.length; i++)
        if (!RegExp('戦に備える|版図|獲物|流れる').hasMatch(cs[i].label)) i,
    ];
    return safe.isEmpty ? 0 : safe[r.range(0, safe.length - 1)];
  }
  final safe = [
    for (var i = 0; i < cs.length; i++)
      if (!RegExp('命|討死|死|危う|ただでは|咎め|磔|助から|生きて帰').hasMatch(cs[i].hint ?? '')) i,
  ];
  return safe.isEmpty
      ? r.range(0, cs.length - 1)
      : safe[r.range(0, safe.length - 1)];
}

/// 元服のあと、いろいろな暮らしへ置き直す（泰平の世の道をひととおり通すため）。
void _shape(Game g, int k) {
  final l = g.l;
  void clear() {
    l.rank = 0;
    l.lord = null;
    l.troops = 0;
    l.ronin = false;
  }

  String home() =>
      (g.fa[l.home]?.alive ?? false) ? l.home : g.alive.first.name;
  switch (k % 8) {
    case 0: // 主家に仕える侍（女性は奥で仕える）
      l.rank = 3;
      l.maxRank = 3;
      l.lord = home();
      l.fav = 70;
      g.setFlag('first_battle');
    case 1: // 牢人
      clear();
      l.ronin = !l.female;
      if (!l.female) l.maxRank = 2;
      g.setFlag('first_battle');
    case 2: // 商いの道
      clear();
      g.setFlag('way_merchant');
      l.gold += 120;
    case 3: // 仏門
      clear();
      g.setFlag('priesthood');
    case 4: // 野の道
      clear();
      g.setFlag('way_outlaw');
    case 5: // キリシタン
      g.setFlag('kirishitan');
    case 6: // 城主（女性は城主の妻）
      l.rank = 5;
      l.maxRank = 5;
      l.lord = home();
      l.fav = 60;
      l.troops = 30;
      if (l.female) l.married = true;
      g.setFlag('first_battle');
    default: // 生まれのまま
      break;
  }
}

/// 一つの人生を終わりまで進める。[mode] 0＝ランダム／1＝考えて選ぶ／2＝暮らしを置き直して用心深く／
/// 3＝暮らしを置き直し、重点は用心深く・岐路はランダム。
Game? _life(int seed, int mode) {
  final rng = Rng(seed * 11 + 7 + mode);
  final g = Game(rng: rng);
  var b = rollBirth(rng);
  // 置き直す人生は、一六〇一年に大人として生きていられる生まれ（一五四五年から）にする。
  for (var k = 0; mode >= 2 && b.startYear < 1545 && k < 200; k++) {
    b = rollBirth(rng);
  }
  g.start(b);
  final r = Rng(seed + 41);
  var n = 0;
  if (mode >= 2) {
    while (!g.finished && g.isChild && n++ < 200) {
      g.choose(r.range(0, g.prompt!.choices.length - 1));
    }
    if (g.finished) return null;
    _shape(g, seed);
  }
  n = 0;
  while (!g.finished && n++ < 6000) {
    final p = g.prompt!;
    g.choose(switch (mode) {
      0 => r.range(0, p.choices.length - 1),
      // 重点は用心深く、岐路はランダム（危うい手も選ぶので、泰平の岐路の死に方が出る）。
      3 =>
        p.title == 'この年の心がけ'
            ? _pickCareful(g, p, r)
            : r.range(0, p.choices.length - 1),
      1 => pickAmbitious(g, p, r),
      _ => _pickCareful(g, p, r),
    });
  }
  expect(g.finished, isTrue);
  return g;
}

/// 足す前の決まり（今回足した最期が無く、泰平の最期へ譲る決まりも無い）で選ばれる最期。
EndingDef? _before(Game g, String kind) => findHandEnding(
  g,
  lifeWay(g.l),
  kind,
  [
    for (final e in kHandEndings)
      if (!_isNew(e)) e,
  ],
  eraFits: (e) => eraEndingFits(g, e),
);

void main() {
  final byId = {for (final e in kHandEndings) e.id: e};
  final fresh = [
    for (final e in kPeaceEndings)
      if (_isNew(e)) e,
  ];

  test('泰平の最期の表: id が重ならず、称号と希少度があり、差し込みのほかに記号も数字も無い', () {
    expect(byId.length, kHandEndings.length); // id は重複しない
    expect(kPeaceEndings.length, inInclusiveRange(95, 125));
    expect(fresh.length, greaterThanOrEqualTo(75));
    for (final e in kPeaceEndings) {
      expect(isPeaceEnding(e), isTrue);
      expect(e.title, isNotEmpty, reason: e.id);
      expect(e.title.length, lessThanOrEqualTo(24), reason: e.id);
      expect(e.way, isNot('young'), reason: e.id);
      expect(kWays.containsKey(e.way), isTrue, reason: e.id);
      expect(e.kinds, isNotNull, reason: e.id);
      final bare = e.text.replaceAll(_slots, '');
      expect(bare, isNot(contains('{')), reason: e.id);
      expect(bare, isNot(contains('}')), reason: e.id);
      expect(_digits.hasMatch(bare), isFalse, reason: e.id);
      expect(_digits.hasMatch(e.title), isFalse, reason: e.id);
      // 三〜五文・百五十字前後
      expect(e.text.length, inInclusiveRange(90, 230), reason: e.id);
      final sentences = '。'.allMatches(e.text).length;
      expect(sentences, inInclusiveRange(3, 8), reason: e.id);
      // 常体（です・ますで終わる文がない）
      expect(RegExp('(です|ます|でした|ました)。').hasMatch(e.text), isFalse, reason: e.id);
    }
    // 足した最期は、九つの道すべてにあり、死に方は八つと天下統一にまたがる。
    expect({for (final e in fresh) e.way}, kWays.keys.where((w) => w != 'young').toSet());
    expect(
      {for (final e in fresh) ...e.kinds!},
      containsAll(['tenju', 'byo', 'sai', 'ue', 'yukue', 'seppuku', 'ansatsu', 'senshi', 'victory']),
    );
    // 希少度は四つとも使う。幻は長生きした人と、世を覆した人だけ。
    expect({for (final e in fresh) e.tier}, Tier.values.toSet());
    expect(fresh.where((e) => e.tier == Tier.phantom).length, inInclusiveRange(3, 6));
    // 徳川の世の言葉（江戸・幕府・徳川・大坂）を本文に持つ足した最期は、史実の世の岐路の旗か死因で出る。
    // 受け皿（細かさ3以下）には入れない（歴史が変わった世でも出るため）。
    for (final e in fresh.where((e) => e.spec <= 3)) {
      expect(RegExp('江戸|幕府|徳川|将軍').hasMatch(e.text), isFalse, reason: e.id);
    }
  });

  test('戦の世の言い回しの表は、泰平の暮らしの言葉には当たらず、戦の言葉には当たる', () {
    for (final s in ['陣から戻るたびに', '敵の槍が', '乱世の真ん中', '討死した', '籠城の末に', '鉄砲の撃ち合い', '雑兵']) {
      expect(kWarWords.hasMatch(s), isTrue, reason: s);
    }
    for (final s in ['首を横に振った', '孫に看取られた', '帳場で算盤をはじいた', '念仏の中で逝った', '田の畦に腰を下ろした']) {
      expect(kWarWords.hasMatch(s), isFalse, reason: s);
    }
    // 既存の最期のうち、戦に触れないもの（押しのけないもの）が半分より多く残る。
    final old = [
      for (final e in kHandEndings)
        if (!isPeaceEnding(e) && e.way != 'young' && !(e.kinds?.contains('victory') ?? false)) e,
    ];
    final quiet = old.where((e) => !hasWarWords(e)).length;
    // ignore: avoid_print
    print('【戦の言い回し】既存の最期 ${old.length}本のうち、戦に触れないもの $quiet本');
    expect(quiet, greaterThan(old.length ~/ 2));
  });

  test('泰平の世で亡くなった三千人生: 戦の世の言い回しの最期が出ず、泰平の最期が増え、足した最期が四十種より多く出る', () {
    var late = 0, after1616 = 0;
    var sideBefore = 0, sideAfter = 0, side16Before = 0, side16After = 0;
    var warBefore = 0, warAfter = 0, yielded = 0;
    final got = <String>{}, gotWays = <String>{}, gotKinds = <String>{};
    final bands = <String, List<int>>{};
    final rareTales = <String>[];
    final early = <(Game, EndingDef, String)>[];
    for (var i = 0; i < 3000; i++) {
      final g = _life(i, const [0, 1, 2, 2, 3][i % 5]);
      if (g == null || g.l.victory || g.year < 1601) continue;
      late++;
      final e = buildEnding(g);
      expect(e.handId, isNotNull, reason: '${e.way}/${e.kind} ${g.year}年');
      final def = byId[e.handId]!;
      final kind = e.kind;
      // 差し込みの記号が残らない。
      expect(e.text, isNot(contains('{')), reason: def.id);
      expect(e.text, isNot(contains('}')), reason: def.id);
      expect(e.text, isNot(contains('null')), reason: def.id);
      expect(e.title, isNotEmpty, reason: def.id);
      if (isPeaceEnding(def)) {
        // 泰平の最期は、戦の絶えた世（一六〇一年から。今川の世には無い）か、その世の天下統一にだけ。
        expect(g.year, greaterThanOrEqualTo(kPeaceFrom), reason: def.id);
        expect(def.kinds!.contains(kind), isTrue, reason: def.id);
        if (_isNew(def)) {
          got.add(def.id);
          gotWays.add(def.way);
          gotKinds.add(kind);
        }
      }
      final before = _before(g, kind);
      final sb = before != null && isPeaceSideEnding(before, kind);
      final sa = isPeaceSideEnding(def, kind);
      if (sb) sideBefore++;
      if (sa) sideAfter++;
      final band = g.year <= 1615 ? '一六〇一〜一五' : (g.year <= 1635 ? '一六一六〜三五' : '一六三六〜');
      final b = bands.putIfAbsent(band, () => [0, 0, 0]);
      b[0]++;
      if (sb) b[1]++;
      if (sa) b[2]++;
      if (g.year < kPeaceYieldFrom && peaceTime(g)) early.add((g, def, kind));
      if (g.year < kPeaceYieldFrom || !peaceTime(g)) continue;
      after1616++;
      if (sb) side16Before++;
      if (sa) side16After++;
      if (before != null && !sb && hasWarWords(before)) warBefore++;
      if (before != null && before.id != def.id && !_isNew(def)) yielded++;
      // 一六一六年からの世に亡くなった人の最期に、戦の世の言い回しは出ない。
      // 残してよいのは、幻の最期と、自ら起こした戦で討死した人の戦死の最期と、
      // 稀な最期の昔語り（北ノ庄の落城を思い返す女 など。「現在の戦」の文は残さない）だけ。
      if (!sa && hasWarWords(def)) {
        final ownBattle = kind == 'senshi' && !RegExp('大坂|島原').hasMatch(g.l.dead!);
        final rareTale = def.tier == Tier.rare && isWarTale(def);
        if (rareTale) {
          rareTales.add(def.id);
        } else {
          warAfter++;
        }
        expect(
          def.tier == Tier.phantom || ownBattle || rareTale,
          isTrue,
          reason: '${def.id} ${g.year}年 $kind ${g.l.dead}',
        );
        if (!ownBattle) expect(isWarNow(def), isFalse, reason: def.id);
      }
    }
    // 一六〇一〜一五年に亡くなった人には、戦の昔語りは出てよいが、「現在の戦」の文は出ない（自ら起こした戦の討死は除く）。
    for (final (g, def, kind) in early) {
      if (kind == 'senshi' && !RegExp('大坂|島原').hasMatch(g.l.dead!)) continue;
      expect(isWarNow(def), isFalse, reason: '${def.id} ${g.year}年 $kind ${g.l.dead}');
    }
    String pct(int a, int b) => b == 0 ? '-' : '${(a * 100 / b).toStringAsFixed(1)}%';
    // ignore: avoid_print
    print(
      '【泰平の世の最期】一六〇一年からの世で亡くなった $late人生: 泰平の側の最期 ${pct(sideBefore, late)} → ${pct(sideAfter, late)}'
      '（${bands.entries.map((e) => '${e.key} ${e.value[0]}人 ${pct(e.value[1], e.value[0])} → ${pct(e.value[2], e.value[0])}').join('／')}）\n'
      '  一六一六年からの $after1616人生: 泰平の側 ${pct(side16Before, after1616)} → ${pct(side16After, after1616)}'
      '・戦の言い回しの最期 $warBefore → $warAfter・足した最期 ${got.length}種（道 ${gotWays.length}・死に方 ${gotKinds.length}）'
      '\n  ${(got.toList()..sort()).join(' ')}',
    );
    // ignore: avoid_print
    print('  一六一六年からの世に残った稀な昔語り ${rareTales.length}（${rareTales.toSet().join(' ')}）・一六〇一〜一五年 ${early.length}人生');
    expect(late, greaterThan(500));
    expect(after1616, greaterThan(200));
    // 泰平の側の最期が付く割合が上がる（足す前と比べる）。
    expect(sideAfter / late, greaterThan(sideBefore / late + .15));
    expect(side16After / after1616, greaterThan(side16Before / after1616 + .25));
    expect(side16After / after1616, greaterThan(.6));
    expect(warBefore, greaterThan(warAfter * 4));
    // 足した最期が四十種より多く出る。
    expect(got.length, greaterThanOrEqualTo(40));
    expect(gotWays.length, greaterThanOrEqualTo(6));
    expect(gotKinds.length, greaterThanOrEqualTo(4));
    expect(yielded, greaterThanOrEqualTo(0));
  });

  test('決まりの確かめ: 一六一六年からは戦の言葉の最期を泰平の最期に譲り、戦に触れない最期・幻の最期・一六一五年までは譲らない', () {
    // 泰平の世まで生きる侍を一人つくり、亡くなる年と旗を置き直して確かめる。
    Game make(int year, {bool female = false}) {
      for (var s = 0; s < 4000; s++) {
        final rng = Rng(s);
        final b = rollBirth(rng);
        if (b.startYear < 1560) continue;
        final g = Game(rng: rng);
        g.start(b);
        if (g.finished || g.l.female != female) continue;
        final l = g.l;
        l.t = (year - l.startYear) * 2;
        l.rank = 3;
        l.maxRank = 3;
        g.setFlag('first_battle');
        return g;
      }
      throw StateError('人生を作れなかった');
    }

    final war = EndingDef(
      id: 'x_war',
      way: 'samurai',
      tier: Tier.common,
      title: '陣中で逝った侍',
      text: '陣から戻るたびに、敵の話をした。',
      kinds: const {'tenju'},
      cond: (g) => true,
      spec: 5,
    );
    final quiet = EndingDef(
      id: 'x_quiet',
      way: 'samurai',
      tier: Tier.common,
      title: '孫に看取られた侍',
      text: '孫に看取られて逝った。',
      kinds: const {'tenju'},
      cond: (g) => true,
      spec: 5,
    );
    final phantom = EndingDef(
      id: 'x_phantom',
      way: 'samurai',
      tier: Tier.phantom,
      title: '乱世を変えた侍',
      text: '乱世は、ここで終わった。',
      kinds: const {'tenju'},
      cond: (g) => true,
      spec: 5,
    );

    final g = make(1630);
    g.die('天寿をまっとうした', 'tenju');
    expect(g.year, 1630);
    expect(peaceTime(g), isTrue);
    expect(yieldsToPeace(g, war, 'tenju'), isTrue);
    expect(yieldsToPeace(g, quiet, 'tenju'), isFalse);
    expect(yieldsToPeace(g, phantom, 'tenju'), isFalse);
    expect(yieldsToPeace(g, byId['b_taihei']!, 'tenju'), isFalse);
    // 実際に出る最期は、泰平の側のもの（戦の言い回しの既存の最期ではない）。
    final e = buildEnding(g);
    final def = byId[e.handId]!;
    expect(
      isPeaceSideEnding(def, 'tenju') || def.tier == Tier.phantom || !hasWarWords(def),
      isTrue,
      reason: def.id,
    );

    // 自ら起こした戦での討死は譲らない。島原の死は譲る。
    final s = make(1638);
    s.die('島津との合戦で討死', 'senshi');
    expect(yieldsToPeace(s, war, 'senshi'), isFalse);
    final h = make(1638);
    h.die('島原の一揆攻めで討死した', 'senshi');
    expect(yieldsToPeace(h, war, 'senshi'), isTrue);
    expect(buildEnding(h).handId, 'b_hei_shimabara');

    // 一六一五年までに亡くなった人は、これまでどおり（戦を知る者の世）。
    final early = make(1612);
    early.die('天寿をまっとうした', 'tenju');
    expect(yieldsToPeace(early, war, 'tenju'), isFalse);

    // 今川の世は乱世が続くので、譲らない。
    final ima = make(1630);
    ima.setFlag('history_okehazama');
    ima.die('天寿をまっとうした', 'tenju');
    expect(peaceTime(ima), isFalse);
    expect(yieldsToPeace(ima, war, 'tenju'), isFalse);

    // 長く生きた人だけの幻の最期。
    final old = make(1646);
    old.die('天寿をまっとうした', 'tenju');
    expect(old.age, greaterThanOrEqualTo(78));
    final oe = buildEnding(old);
    expect(byId[oe.handId]!.spec, greaterThanOrEqualTo(9), reason: oe.handId);
    expect(oe.text, isNot(contains('{')));

    // ---- 「現在の戦」と「昔語り」の分け方（2026-11-24 気がかりの直し）
    // 表: 現在の戦は、陣中や囲まれた城で息を引き取る・戦の世がまだ続いている前提の文だけ。
    for (final id in ['p_byo_abbot', 'd_tenju_born', 'b_byo_chosen', 'j_byo_numajiri', 'd_byo_longcamp']) {
      expect(isWarNow(byId[id]!), isTrue, reason: id);
      expect(isWarTale(byId[id]!), isFalse, reason: id);
    }
    for (final id in [
      'f_kitanosho_survivor', 'f_tenju_onnajo', 'p_tenju_late_samurai', 'p_tenju_ishiyama', //
      'b_byo_spouse', 'b_tenju_retired', 'j_tenju_joy', 'b_era_letters', 'f_tenju_content',
    ]) {
      expect(isWarTale(byId[id]!), isTrue, reason: id);
      expect(isWarNow(byId[id]!), isFalse, reason: id);
    }
    // 泰平の最期と、戦に触れない最期は、どちらでもない。
    expect(isWarNow(byId['b_taihei']!) || isWarNow(quiet), isFalse);
    expect(kHandEndings.where(isWarNow).length, inInclusiveRange(8, 20));

    final now = EndingDef(
      id: 'x_now',
      way: 'samurai',
      tier: Tier.common,
      title: '陣小屋で逝った侍',
      text: '長い対陣の陣中で病に倒れた。',
      kinds: const {'tenju'},
      cond: (g) => true,
      spec: 5,
    );
    final rareTale = EndingDef(
      id: 'x_rare_tale',
      way: 'samurai',
      tier: Tier.rare,
      title: '落城の日を語った侍',
      text: 'かつての落城の日のことを、また思い返していた。',
      kinds: const {'tenju'},
      cond: (g) => true,
      spec: 5,
    );
    final rareNow = EndingDef(
      id: 'x_rare_now',
      way: 'samurai',
      tier: Tier.rare,
      title: '陣中に果てた侍',
      text: '遠い国の陣中で病に倒れた。',
      kinds: const {'tenju'},
      cond: (g) => true,
      spec: 5,
    );
    expect(isWarNow(now), isTrue);
    expect(isWarTale(war), isTrue);
    // 一六〇一〜一五年: 現在の戦の文だけが譲り、昔語りは残る。譲った先には、昔語りの既存の最期も泰平の側の最期も入る。
    expect(yieldsToPeace(early, now, 'tenju'), isTrue);
    expect(yieldsToPeace(early, rareNow, 'tenju'), isTrue);
    expect(yieldsToPeace(early, war, 'tenju'), isFalse);
    expect(yieldsToPeace(early, rareTale, 'tenju'), isFalse);
    expect(yieldsToPeace(early, quiet, 'tenju'), isFalse);
    final poolEarly = yieldPool(early, 'tenju');
    expect(poolEarly.any(isWarNow), isFalse);
    expect(poolEarly.any((e) => e.id == 'b_byo_spouse'), isTrue);
    expect(poolEarly.any((e) => e.id == 'b_taihei'), isTrue);
    final ee = byId[buildEnding(early).handId]!;
    expect(isWarNow(ee), isFalse, reason: ee.id);
    // 一六〇一年より前（戦の世）は、現在の戦の文もそのまま。
    final sengoku = make(1595);
    sengoku.die('病に倒れた');
    expect(yieldsToPeace(sengoku, now, 'byo'), isFalse);
    // 一六一六年から: 稀な最期の昔語りは残り、稀でも現在の戦の文は譲る。ふつうの昔語りは、これまでどおり譲る。
    expect(yieldsToPeace(g, rareTale, 'tenju'), isFalse);
    expect(yieldsToPeace(g, rareNow, 'tenju'), isTrue);
    expect(yieldsToPeace(g, now, 'tenju'), isTrue);
    expect(yieldsToPeace(g, byId['f_kitanosho_survivor']!, 'tenju'), isFalse);
    expect(yieldsToPeace(g, byId['p_tenju_late_samurai']!, 'tenju'), isFalse);
    expect(yieldsToPeace(g, byId['b_byo_spouse']!, 'byo'), isTrue);
    expect(yieldPool(g, 'tenju').every((e) => isPeaceSideEnding(e, 'tenju')), isTrue);
    // 寺を預かる僧が一六一〇年に病で亡くなっても、「戦の世でも、この寺は焼かせるな」は出ない。
    final abbot = make(1610);
    abbot.l
      ..rank = 0
      ..lord = null;
    abbot.setFlag('priesthood');
    abbot.setFlag('abbot');
    abbot.die('病に倒れた');
    final ae = byId[buildEnding(abbot).handId]!;
    expect(ae.id, isNot('p_byo_abbot'));
    expect(isWarNow(ae), isFalse, reason: ae.id);

    // 泰平の岐路の死因で出る最期。
    final oi = make(1625);
    oi.die('亡き主君の後を追い、追腹を切った', 'seppuku');
    expect(buildEnding(oi).handId, 'b_hei_oibara');
    final ka = make(1620);
    ka.die('辻でかぶき者の喧嘩に巻き込まれ、斬られた', 'ansatsu');
    expect(buildEnding(ka).handId, 'b_hei_kabuki');
  });
}
