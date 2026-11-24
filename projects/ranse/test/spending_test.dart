import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/adult.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/spending.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 三十歳の [cls] の家に生まれた人（身分・道は消してある）。
Game _person(String cls, {bool female = false, int seed = 0}) {
  for (var s = seed;; s++) {
    final rng = Rng(s + 900);
    final x = Game(rng: rng);
    final b = rollBirth(rng);
    if (b.female != female || b.startYear > 1550 || b.cls.id != cls) continue;
    x.start(b);
    if (x.finished) continue;
    x.prompt = null;
    x.l.t = 30 * 2;
    x.l
      ..rank = 0
      ..maxRank = 0
      ..lord = null
      ..married = false
      ..gold = 0
      ..merit = 0
      ..troops = 0;
    for (final f in ['priesthood', 'retired', 'way_merchant', 'way_outlaw']) {
      x.l.flags.remove(f);
    }
    x.l.flags.removeWhere((f) => f.startsWith('sp_'));
    return x;
  }
}

String _home(Game g) =>
    (g.fa[g.l.home]?.alive ?? false) ? g.l.home : g.alive.first.name;

/// 主家に [rank] で仕える人にする。
Game _retainer(int rank, {bool female = false}) {
  final g = _person(female ? 'samurai' : 'lowsamurai', female: female);
  g.l
    ..rank = rank
    ..maxRank = rank
    ..lord = _home(g)
    ..fav = 40;
  return g;
}

List<String> _focusLabels(Game g) =>
    adultFocusOptions(g).map((o) => o.label).toList();

/// 銭・功の使い道の入り口を見つけたら選び、使い道の岐路では見送り以外から選ぶ。ほかはランダムか考えて選ぶ。
int _spender(Game g, Prompt p, Rng r, bool ambitious) {
  final cs = p.choices;
  if (p.title == 'この年の心がけ') {
    final i = cs.indexWhere((c) => c.label == '蓄えを使う' || c.label.contains('恩賞を願い出る') || c.label == '功を願い出る');
    if (i >= 0 && r.chance(.8)) return i;
  }
  if (p.title == '蓄えの使い道' || p.title == '恩賞の願い') {
    return r.range(0, cs.length - 2);
  }
  return ambitious ? pickAmbitious(g, p, r) : r.range(0, cs.length - 1);
}

/// 持ち物の旗と、その使い道の id（持っている間は並ばない）。
const _owned = <String, String>{
  'sp_horse': 'sp_horse',
  'sp_armor': 'sp_armor',
  'sp_sword': 'sp_sword',
  'sp_chaki': 'sp_chaki',
  'sp_nanban': 'sp_nanban',
  'sp_house': 'sp_house',
  'sp_roto': 'sp_roto',
  'sp_genin': 'sp_genin',
  'sp_tutor': 'sp_tutor',
  'sp_dowry': 'sp_dowry',
  'sp_kuyo': 'sp_kuyo',
  'sp_kani': 'sp_kani',
  'sp_bribe': 'sp_bribe',
  'sp_robe': 'sp_robe',
};

void main() {
  test('表: 銭の使い道は二十前後・功は十前後で、岐路はどれも一度ずつ登録されている', () {
    expect(kSpendGoldIds.length, inInclusiveRange(18, 24));
    expect(kSpendMeritIds.length, inInclusiveRange(8, 13));
    final all = [...kSpendGoldIds, ...kSpendMeritIds];
    expect(all.toSet().length, all.length);
    for (final id in all) {
      expect(id.startsWith('sp_'), isTrue, reason: id);
    }
    final g = Game(rng: Rng(1));
    final adult = g.adultScenes.map((s) => s.id).toList();
    for (final id in ['sp_spend', 'sp_boon', ...kSpendEchoIds]) {
      expect(adult.where((x) => x == id).length, 1, reason: id);
    }
    for (final s in g.adultScenes.where((s) => s.id == 'sp_spend' || s.id == 'sp_boon')) {
      expect(s.onlyForced, isTrue);
      expect(s.repeat, isTrue);
    }
    for (final s in g.adultScenes.where((s) => kSpendEchoIds.contains(s.id))) {
      expect(s.onlyForced, isFalse);
      expect(s.repeat, isFalse);
    }
    expect(kSpendEchoGap.keys.toSet(), kSpendEchoIds.toSet());
  });

  test('銭や功が足りないと入り口が出ず、たまると出る。使った年から間をあける', () {
    final g = _retainer(3);
    g.l.gold = kSpendGoldMin[spTier(g)] - 1;
    expect(spendGoldReady(g), isFalse);
    expect(_focusLabels(g), isNot(contains('蓄えを使う')));
    g.l.gold = 2000;
    expect(spendGoldReady(g), isTrue);
    expect(_focusLabels(g), contains('蓄えを使う'));
    g.setFlag('sp_gold@${g.year}');
    expect(spendGoldReady(g), isFalse, reason: '使った年');
    g.l.flags.remove('sp_gold@${g.year}');
    g.setFlag('sp_gold@${g.year - kSpendGap}');
    expect(spendGoldReady(g), isTrue, reason: '年が空いた');

    // 功: 次の昇進に要る功を、目安より多く越えたときだけ。
    final need = kPromo[4]!.merit;
    g.l.merit = need + kMeritSpare - 1;
    expect(spendMeritReady(g), isFalse);
    expect(_focusLabels(g), isNot(contains('功を願い出る')));
    g.l.merit = need + 60;
    expect(spendMeritReady(g), isTrue);
    expect(_focusLabels(g), contains('功を願い出る'));
    // 並ぶ使い道は、どれも次の昇進に要る功を割り込まない。
    expect(spendMeritIds(g), isNotEmpty);

    // 仕えていない人・隠居・大名には功の入り口が出ない。
    final f = _person('farmer');
    f.l.merit = 999;
    expect(spendMeritReady(f), isFalse);
    g.setFlag('retired');
    expect(spendMeritReady(g), isFalse);
    g.l.flags.remove('retired');
    g.l.rank = 8;
    expect(spendMeritReady(g), isFalse);

    // 切り替えを切ると、どちらも出ない（比べるテスト用）。
    g.l.rank = 3;
    spendingEnabled = false;
    expect(spendingFocusOptions(g), isEmpty);
    spendingEnabled = true;
    expect(spendingFocusOptions(g), isNotEmpty);
  });

  test('身分・暮らしごとに、合う使い道が並ぶ', () {
    // 百姓: 田・下人・家。武具や官位・献上は並ばない。
    final f = _person('farmer');
    f.l.gold = 5000;
    final fi = spendGoldIds(f);
    expect(fi, containsAll(['sp_field', 'sp_genin', 'sp_house', 'sp_alms']));
    for (final x in ['sp_horse', 'sp_sword', 'sp_kani', 'sp_gift', 'sp_roto', 'sp_shop', 'sp_robe']) {
      expect(fi, isNot(contains(x)), reason: '百姓に $x');
    }
    // 城主: 名馬・具足・郎党・官位・献上。田と下人は並ばない。
    final c = _retainer(5);
    c.l.gold = 5000;
    final ci = spendGoldIds(c);
    expect(ci, containsAll(['sp_horse', 'sp_armor', 'sp_sword', 'sp_roto', 'sp_kani', 'sp_gift', 'sp_chaki']));
    for (final x in ['sp_field', 'sp_genin', 'sp_shop', 'sp_robe']) {
      expect(ci, isNot(contains(x)), reason: '城主に $x');
    }
    // 足軽には官位も名馬もない。
    final a = _retainer(1);
    a.l.gold = 5000;
    expect(spendGoldIds(a), isNot(contains('sp_kani')));
    expect(spendGoldIds(a), isNot(contains('sp_horse')));
    // 商人: 店・荷駄の馬・田。献上・郎党は並ばない。
    final m = _person('merchant');
    m.setFlag('way_merchant');
    m.l.gold = 5000;
    final mi = spendGoldIds(m);
    expect(mi, containsAll(['sp_shop', 'sp_horse', 'sp_field', 'sp_chaki']));
    expect(mi, isNot(contains('sp_gift')));
    expect(mi, isNot(contains('sp_roto')));
    expect(spendLabel(m, 'sp_horse'), '荷駄の馬を買う');
    // 僧: 寺の堂を繕う。家や武具は並ばない。
    final p = _person('priest');
    p.setFlag('priesthood');
    p.l.gold = 5000;
    final pi = spendGoldIds(p);
    expect(pi, contains('sp_temple'));
    expect(spendLabel(p, 'sp_temple'), '寺の堂を繕う');
    for (final x in ['sp_house', 'sp_armor', 'sp_horse', 'sp_tutor', 'sp_robe']) {
      expect(pi, isNot(contains(x)), reason: '僧に $x');
    }
    // 奥で仕える未婚の女性: 晴れ着。家・武具・郎党は並ばない。
    final w = _retainer(3, female: true);
    w.l.gold = 5000;
    final wi = spendGoldIds(w);
    expect(wi, contains('sp_robe'));
    for (final x in ['sp_house', 'sp_armor', 'sp_horse', 'sp_roto', 'sp_sword', 'sp_gun']) {
      expect(wi, isNot(contains(x)), reason: '奥の女性に $x');
    }
    // 状況: 薬は体の弱ったときだけ、鉄砲は伝来のあとだけ。
    expect(ci, isNot(contains('sp_medicine')));
    c.l.hp = 10;
    expect(spendGoldIds(c), contains('sp_medicine'));
    // 功: 女性には感状・偏諱・刀がなく、小袖がある。
    w.l.merit = 999;
    final wm = spendMeritIds(w);
    expect(wm, contains('sp_m_robe'));
    for (final x in ['sp_m_kanjo', 'sp_m_henki', 'sp_m_sword', 'sp_m_horse']) {
      expect(wm, isNot(contains(x)), reason: '奥の女性に $x');
    }
    c.l.merit = 999;
    expect(spendMeritIds(c), containsAll(['sp_m_chigyo', 'sp_m_suikyo', 'sp_m_henki', 'sp_m_sword', 'sp_m_tea']));
  });

  test('持っている物は二度並ばない', () {
    final c = _retainer(5);
    c.l
      ..t = (1585 - c.l.startYear) * 2
      ..gold = 9999
      ..hp = 10;
    c.l.addKid(c.year - 16);
    c.l.addKid(c.year - 8);
    final m = _person('merchant');
    m.setFlag('way_merchant');
    m.l.gold = 9999;
    final w = _retainer(3, female: true);
    w.l.gold = 9999;
    final f = _person('farmer');
    f.l.gold = 9999;
    for (final e in _owned.entries) {
      final g = [c, m, w, f].firstWhere((x) => spendGoldIds(x).contains(e.value), orElse: () => c);
      expect(spendGoldIds(g), contains(e.value), reason: '${e.key} を持つ前');
      g.setFlag(e.key);
      expect(spendGoldIds(g), isNot(contains(e.value)), reason: '${e.key} を持ったあと');
    }
    // 段のある物（田・店）は段が尽きると並ばない。
    for (final fl in ['sp_field_1', 'sp_field_2', 'sp_field_3']) {
      f.setFlag(fl);
    }
    expect(spendGoldIds(f), isNot(contains('sp_field')));
    for (final fl in ['sp_shop_1', 'sp_shop_2']) {
      m.setFlag(fl);
    }
    expect(spendGoldIds(m), isNot(contains('sp_shop')));
    // 鉄砲は l.gun で見る。
    final a = _retainer(3);
    a.l.gold = 9999;
    a.l.t = (1560 - a.l.startYear) * 2;
    expect(spendGoldIds(a), contains('sp_gun'));
    a.l.gun = true;
    expect(spendGoldIds(a), isNot(contains('sp_gun')));
    // 名物の茶碗を持つ人には茶入が並ばない。
    final t = _retainer(4);
    t.l.gold = 9999;
    expect(spendGoldIds(t), contains('sp_chaki'));
    t.setFlag('ps_meibutsu');
    expect(spendGoldIds(t), isNot(contains('sp_chaki')));
  });

  test('買った物が効く: 具足で討死しにくく、馬で手柄が増え、田と知行は毎年の実入りになる', () {
    // 同じ人に先陣で何度も戦わせ、具足の有無で討死の数を比べる。
    (int, int) fight(bool armor, bool horse) {
      final g = _retainer(3);
      g.l
        ..bu = 40
        ..un = 40
        ..troops = 0;
      if (armor) g.setFlag('sp_armor');
      if (horse) g.setFlag('sp_horse');
      final power = {for (final f in g.fa.values) f.name: f.power};
      var dead = 0, merit = 0;
      for (var i = 0; i < 20000; i++) {
        for (final f in g.fa.values) {
          f.power = power[f.name]!;
        }
        g.l
          ..fav = 40
          ..dead = null
          ..deathKind = null
          ..hp = g.l.maxhp
          ..merit = 0;
        g.battle('van');
        if (g.l.dead != null) {
          dead++;
        } else {
          merit += g.l.merit;
        }
      }
      return (dead, merit);
    }

    final (bare, bareMerit) = fight(false, false);
    final (armored, _) = fight(true, false);
    final (_, horseMerit) = fight(false, true);
    // ignore: avoid_print
    print('【使い道】先陣二万回の討死 素肌$bare・具足$armored／手柄 素$bareMerit・馬$horseMerit');
    expect(armored, lessThan(bare * .85));
    expect(horseMerit, greaterThan(bareMerit * 1.04));

    // 田・知行・店は、年の終わりに銭を足す。
    final f = _person('farmer');
    f.l.gold = 0;
    spendingYear(f);
    expect(f.l.gold, 0);
    f.setFlag('sp_field_1');
    spendingYear(f);
    expect(f.l.gold, greaterThan(0));
    final c = _retainer(4);
    c.l.gold = 0;
    c.setFlag('sp_chigyo_1');
    spendingYear(c);
    expect(c.l.gold, greaterThan(0));

    // 多くの人生でも: 戦に出続ける侍に、十五で具足を持たせた人生と持たせない人生の戦死を比べる。
    var withArmor = 0, without = 0, livesA = 0, livesB = 0;
    for (var seed = 0; seed < 1600; seed++) {
      final armor = seed.isEven;
      final rng = Rng(seed ~/ 2 + 5100);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed ~/ 2 + 7100);
      var n = 0;
      while (!g.finished && g.isChild && n++ < 400) {
        g.choose(r.range(0, g.prompt!.choices.length - 1));
      }
      if (g.finished || g.l.female) continue;
      if (g.l.rank < 1) {
        g.l
          ..rank = 1
          ..maxRank = 1
          ..lord = _home(g)
          ..fav = 25;
      }
      if (armor) g.setFlag('sp_armor');
      while (!g.finished && n++ < 4000) {
        g.choose(pickAmbitious(g, g.prompt!, r));
      }
      final senshi = g.l.deathKind == 'senshi';
      if (armor) {
        livesA++;
        if (senshi) withArmor++;
      } else {
        livesB++;
        if (senshi) without++;
      }
    }
    // ignore: avoid_print
    print('【使い道】侍の人生の戦死 具足あり $withArmor/$livesA・なし $without/$livesB');
    expect(withArmor / livesA, lessThan(without / livesB));
  });

  test('ふつうの人生を流しても例外がなく、入り口が出て使われ、選択肢に匂わせがあり数字が無い', () {
    var adults = 0, goldShown = 0, meritShown = 0, spent = 0, boons = 0;
    final kinds = <String, int>{};
    final echoes = <String, int>{};
    final seen = <String, List<Choice>>{};
    for (var seed = 0; seed < 900; seed++) {
      final rng = Rng(seed + 81000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 91000);
      final mode = seed % 3; // 0 ランダム・1 考えて選ぶ・2 使い道を選ぶ
      var n = 0, sawGold = false, sawMerit = false;
      var known = g.l.flags.where((f) => f.startsWith('scene:sp_e_')).toSet();
      while (!g.finished && n++ < 5000) {
        final p = g.prompt;
        expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
        if (p!.title == 'この年の心がけ') {
          for (final c in p.choices) {
            if (c.label == '蓄えを使う') sawGold = true;
            if (c.label == '功を願い出る' || c.label.contains('恩賞を願い出る')) sawMerit = true;
            if (c.label == '蓄えを使う' || c.label == '功を願い出る') {
              expect(_digits.hasMatch(c.hint!), isFalse);
            }
          }
        }
        if (p.title == '蓄えの使い道' || p.title == '恩賞の願い') {
          expect(p.choices.length, inInclusiveRange(4, 6), reason: p.title);
          seen[p.title] = [...?seen[p.title], ...p.choices];
          // 持っている物は並ばない。
          for (final e in _owned.entries) {
            if (g.hasFlag(e.key)) {
              expect(p.choices.map((c) => c.label), isNot(contains(spendLabel(g, e.value))), reason: e.key);
            }
          }
        }
        final now = g.l.flags.where((f) => f.startsWith('scene:sp_e_')).toSet();
        for (final f in now.difference(known)) {
          final id = f.substring(6);
          echoes[id] = (echoes[id] ?? 0) + 1;
          seen[id] = p.choices;
          final (flag, _) = kSpendEchoGap[id]!;
          expect(g.hasFlag(flag), isTrue, reason: '$id が持ち物なしに出た');
        }
        known = now;
        final before = {...g.l.flags};
        final i = mode == 2
            ? _spender(g, p, r, seed.isEven)
            : (mode == 0 ? r.range(0, p.choices.length - 1) : pickAmbitious(g, p, r));
        g.choose(i);
        if (p.title == '蓄えの使い道' || p.title == '恩賞の願い') {
          if (p.title == '蓄えの使い道') {
            spent++;
          } else {
            boons++;
          }
          for (final f in g.l.flags.difference(before)) {
            if (f.startsWith('sp_') && !f.contains('@')) kinds[f] = (kinds[f] ?? 0) + 1;
          }
          for (final f in g.l.flags.where((f) => f.contains('@'))) {
            final k = f.substring(0, f.indexOf('@'));
            if (!before.contains(f) && k != 'sp_gold' && k != 'sp_merit') kinds['use:$k'] = (kinds['use:$k'] ?? 0) + 1;
          }
        }
        expect(g.l.merit, greaterThanOrEqualTo(0));
        expect(g.l.gold, greaterThanOrEqualTo(0));
      }
      expect(g.finished, isTrue);
      if (g.age >= 20) {
        adults++;
        if (sawGold) goldShown++;
        if (sawMerit) meritShown++;
      }
    }
    final uses = kinds.keys.where((k) => k.startsWith('use:')).map((k) => k.substring(4)).toSet();
    // ignore: avoid_print
    print('【使い道】二十歳を越えた$adults人生: 蓄えの入り口 $goldShown・功の入り口 $meritShown／'
        '使った 銭$spent回・功$boons回・使い道${uses.length}種／続きの岐路 ${echoes.length}種 $echoes');
    expect(goldShown / adults, greaterThan(.3));
    expect(meritShown, greaterThan(20));
    expect(uses.length, greaterThanOrEqualTo(24));
    expect(echoes.length, greaterThanOrEqualTo(6));
    for (final e in seen.entries) {
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key}: ${c.label}');
        expect(c.hint!.isNotEmpty, isTrue);
        expect(_digits.hasMatch(c.label), isFalse, reason: '${e.key}: ${c.label}');
        expect(_digits.hasMatch(c.hint!), isFalse, reason: '${e.key}: ${c.hint}');
      }
    }
  });

  test('足す前と比べて、城主以上に届く割合と銭の貯まり方が大きく変わらない', () {
    (double, double, int) run(bool on) {
      spendingEnabled = on;
      var adults = 0, castle = 0;
      final gold40 = <int>[];
      for (var seed = 0; seed < 1000; seed++) {
        final rng = Rng(seed + 4242);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        final r = Rng(seed);
        var n = 0, g40 = -1;
        while (!g.finished && n++ < 4000) {
          if (g.age == 40 && g40 < 0) g40 = g.l.gold;
          g.choose(seed.isEven ? pickAmbitious(g, g.prompt!, r) : r.range(0, g.prompt!.choices.length - 1));
        }
        if (g.age < 15) continue;
        adults++;
        if (g.l.maxRank >= 5) castle++;
        if (g40 >= 0) gold40.add(g40);
      }
      gold40.sort();
      spendingEnabled = true;
      return (castle / adults, gold40[gold40.length ~/ 2].toDouble(), adults);
    }

    final (c0, g0, a0) = run(false);
    final (c1, g1, a1) = run(true);
    // ignore: avoid_print
    print('【使い道】城主以上 足す前 ${(c0 * 100).toStringAsFixed(1)}%（$a0）→ 足した後 ${(c1 * 100).toStringAsFixed(1)}%（$a1）'
        '／四十歳の銭の中央 $g0 → $g1');
    expect((c1 - c0).abs(), lessThan(.06));
    expect(g1, greaterThan(g0 * .5));
  });

  test('遺されたもの: 銭と功の使い道の行が出る', () {
    final g = _retainer(5);
    g.l.t = 50 * 2;
    for (final f in ['sp_m_henki', 'sp_kani', 'sp_kani_proved', 'sp_horse_fine', 'sp_armor_saved']) {
      g.setFlag(f);
    }
    final ids = rememberedEntries(g).map((e) => e.id).toList();
    expect(ids, contains('sp_m_henki'));
    expect(ids, contains('sp_kani'));
    final lines = remembrances(g);
    expect(lines.any((s) => s.contains('名にふさわしい働きで黙らせた')), isTrue);
    for (final s in lines) {
      expect(_digits.hasMatch(s), isFalse, reason: s);
    }
    const mine = ['sp_horse_fine', 'sp_armor_saved', 'sp_chaki', 'sp_house', 'sp_field_1', 'sp_kani', 'sp_m_henki', 'sp_tutor'];
    final have = kRemembrances.map((r) => r.id).toSet();
    for (final id in mine) {
      expect(have, contains(id));
    }
  });
}
