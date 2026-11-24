import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/adult.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/life.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/spending.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 三十歳の [cls] の家に生まれた人（身分・道は消してある）。
Game _person(String cls, {bool female = false, int seed = 0}) {
  for (var s = seed; ; s++) {
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

/// 大人の年の初め（「この年の心がけ」の問いが出ている）まで、ランダムに選んで進めた Game。
Game _atYearStart(
  int seed, {
  bool reseed = false,
  void Function(Game g)? onCheckpoint,
}) {
  for (var s = seed; ; s++) {
    final rng = Rng(s + 3300);
    final g = Game(rng: rng, onCheckpoint: onCheckpoint)
      ..reseedAtCheckpoint = reseed;
    g.start(rollBirth(rng));
    final r = Rng(s + 4400);
    var n = 0;
    while (!g.finished && n++ < 400 && !(g.atYearStart && g.age >= 18)) {
      g.choose(r.range(0, g.prompt!.choices.length - 1));
    }
    if (g.atYearStart) return g;
  }
}

/// 年の初めなら、見込み [p] で一覧から一つ選んで使う（使ったら true）。
bool _maybeBuy(Game g, Rng r, double p) {
  if (!spendingOpen(g) || !r.chance(p)) return false;
  final m = spendingMenu(g);
  if (m.isEmpty) return false;
  return spendingBuy(g, m[r.range(0, m.length - 1)].id) != null;
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
  test('表: 銭の使い道は二十前後・功は十前後。続きの岐路は一度ずつ登録され、心がけの入り口と旧い岐路は無い', () {
    expect(kSpendGoldIds.length, inInclusiveRange(18, 24));
    expect(kSpendMeritIds.length, inInclusiveRange(8, 13));
    final all = [...kSpendGoldIds, ...kSpendMeritIds];
    expect(all.toSet().length, all.length);
    for (final id in all) {
      expect(id.startsWith('sp_'), isTrue, reason: id);
    }
    final g = Game(rng: Rng(1));
    final adult = g.adultScenes.map((s) => s.id).toList();
    for (final id in kSpendEchoIds) {
      expect(adult.where((x) => x == id).length, 1, reason: id);
    }
    // 2026-11-25: 心がけの「蓄えを使う」「功を願い出る」と、その岐路（sp_spend / sp_boon）は外した。
    expect(adult, isNot(contains('sp_spend')));
    expect(adult, isNot(contains('sp_boon')));
    for (final s in g.adultScenes.where((s) => kSpendEchoIds.contains(s.id))) {
      expect(s.onlyForced, isFalse);
      expect(s.repeat, isFalse);
    }
    expect(kSpendEchoGap.keys.toSet(), kSpendEchoIds.toSet());
  });

  test('使い道は年の初めにだけ使え、一覧には買えるものが全部並び、値が出る。心がけには入り口が無い', () {
    var g = _atYearStart(0);
    for (var k = 1; g.l.female || g.hasFlag('sp_horse'); k++) {
      g = _atYearStart(k * 10);
    }
    g.l
      ..rank = 3
      ..maxRank = 3
      ..lord = _home(g)
      ..fav = 40
      ..gold = 5000
      ..merit = kPromo[4]!.merit + 200;
    for (final f in ['priesthood', 'retired', 'way_merchant', 'way_outlaw']) {
      g.l.flags.remove(f);
    }
    expect(spendingOpen(g), isTrue);
    expect(spendingClosedReason(g), isNull);
    expect(_focusLabels(g), isNot(contains('蓄えを使う')));
    expect(_focusLabels(g), isNot(contains('功を願い出る')));
    final m = spendingMenu(g);
    expect(m.where((i) => !i.merit).map((i) => i.id).toList(), spendGoldIds(g));
    expect(m.where((i) => i.merit).map((i) => i.id).toList(), spendMeritIds(g));
    expect(m.length, greaterThan(5), reason: '全部並ぶ（前は三つから五つ）');
    for (final i in m) {
      expect(i.cost, greaterThan(0));
      expect(i.price, i.merit ? '功${i.cost}' : '${i.cost}貫');
    }

    // 持ち物は一つずつ、何度でも買える物も同じ年には一度だけ。銭と功が減り、見聞録に残る。
    final gold0 = g.l.gold;
    final horse = m.firstWhere((i) => i.id == 'sp_horse');
    expect(spendingBuy(g, 'sp_horse'), isNotNull);
    expect(g.l.gold, gold0 - horse.cost);
    expect(g.hasFlag('sp_horse'), isTrue);
    expect(g.l.log.first.txt, startsWith('【蓄えの使い道】'));
    expect(spendingMenu(g).map((i) => i.id), isNot(contains('sp_horse')));
    expect(spendingBuy(g, 'sp_horse'), isNull);
    expect(spendingBuy(g, 'sp_gift'), isNotNull);
    expect(
      spendingMenu(g).map((i) => i.id),
      isNot(contains('sp_gift')),
      reason: '献上は一年に一度',
    );
    // 買ったあとも、年の初めの問いのまま（心がけを選べる）。
    expect(g.atYearStart, isTrue);
    expect(g.prompt!.title, 'この年の心がけ');

    // 功は、次の昇進に要る分を割り込まない。
    final need = kPromo[4]!.merit;
    for (final id in spendMeritIds(g)) {
      expect(
        g.l.merit - spendingMenu(g).firstWhere((i) => i.id == id).cost,
        greaterThanOrEqualTo(need),
      );
    }
    final merit0 = g.l.merit;
    expect(spendingBuy(g, spendMeritIds(g).first), isNotNull);
    expect(g.l.merit, lessThan(merit0));
    expect(g.l.merit, greaterThanOrEqualTo(need));

    // 心がけを選ぶと、その年はもう使えない。次の年の初めにはまた使え、献上もまた並ぶ。
    g.choose(0);
    var n = 0;
    while (!g.finished && !g.atYearStart && n++ < 50) {
      expect(spendingOpen(g), isFalse);
      expect(spendingMenu(g), isEmpty);
      expect(spendingBuy(g, 'sp_gift'), isNull);
      expect(spendingClosedReason(g), isNotNull);
      g.choose(0);
    }
    if (!g.finished &&
        g.l.rank >= 1 &&
        g.l.rank < 8 &&
        g.l.lord != null &&
        (g.fa[g.l.lord]?.alive ?? false) &&
        !g.hasFlag('retired')) {
      g.l.gold = 5000;
      expect(spendingMenu(g).map((i) => i.id), contains('sp_gift'));
      expect(spendingMenu(g).map((i) => i.id), isNot(contains('sp_horse')));
    }

    // 子どものうちは使えない。仕えていない人・隠居・大名には功の使い道が無い。
    final rng = Rng(77);
    final c = Game(rng: rng)..start(rollBirth(rng));
    expect(spendingOpen(c), isFalse);
    if (!c.finished) expect(spendingClosedReason(c), contains('子ども'));
    final f = _person('farmer');
    f.l.merit = 999;
    expect(spendMeritIds(f), isEmpty);
    final r = _retainer(3);
    r.l.merit = 999;
    r.setFlag('retired');
    expect(spendMeritIds(r), isEmpty);
    r.l.flags.remove('retired');
    r.l.rank = 8;
    expect(spendMeritIds(r), isEmpty);
  });

  test('年の初めに使ったら、その年の保存に入る: 再開すると同じ問いが出て、買った物が残る', () {
    var checked = 0, bought = 0, mid = 0;
    for (var s = 0; s < 160; s++) {
      String? saved;
      int? seed;
      final g = _atYearStart(
        s * 7,
        reseed: true,
        onCheckpoint: (g) {
          if (g.finished) return;
          saved = jsonEncode({
            'life': g.l.toJson(),
            'world': g.fa.values.map((f) => f.toJson()).toList(),
          });
          seed = g.checkpointSeed;
        },
      );
      g.l.gold += 3000;
      final pick = Rng(s + 600);
      final ids = <String>[];
      for (var k = 0; k < 2; k++) {
        final m = spendingMenu(g);
        if (m.isEmpty) break;
        final id = m[pick.range(0, m.length - 1)].id;
        expect(spendingBuy(g, id), isNotNull);
        ids.add(id);
      }
      if (ids.isEmpty) continue;
      bought++;
      // 半分は、心がけを選んで年の途中まで進めてから閉じる。
      if (s.isOdd) {
        for (var k = 0; k < 2 && !g.finished; k++) {
          g.choose(pick.range(0, g.prompt!.choices.length - 1));
        }
        mid++;
      }
      if (g.finished) continue;
      final p = g.prompt!;
      final j = jsonDecode(saved!) as Map<String, dynamic>;
      final g2 = Game(rng: Rng(1))..reseedAtCheckpoint = true;
      g2.restore(
        Life.fromJson(j['life'] as Map<String, dynamic>),
        {
          for (final e in (j['world'] as List))
            (e as Map<String, dynamic>)['n'] as String: Faction.fromJson(e),
        },
        seed: seed,
        replay: [...g.choiceLog],
      );
      final p2 = g2.prompt!;
      expect(p2.title, p.title, reason: '種 $s');
      expect(p2.text, p.text, reason: '種 $s');
      expect(
        p2.choices.map((c) => c.label).toList(),
        p.choices.map((c) => c.label).toList(),
        reason: '種 $s',
      );
      expect(
        jsonEncode(g2.l.toJson()),
        jsonEncode(g.l.toJson()),
        reason: '種 $s',
      );
      // 保存に買ったことが入っている。
      final sl = Life.fromJson(j['life'] as Map<String, dynamic>);
      for (final id in ids) {
        expect(
          sl.flags.any((f) => f.startsWith('spb_$id@')),
          isTrue,
          reason: '種 $s $id',
        );
      }
      checked++;
    }
    // ignore: avoid_print
    print('【使い道の再開】使った$bought・確かめた$checked（年の途中まで進めた$mid）');
    expect(checked, greaterThan(100));
  });

  test('身分・暮らしごとに、合う使い道が並ぶ', () {
    // 百姓: 田・下人・家。武具や官位・献上は並ばない。
    final f = _person('farmer');
    f.l.gold = 5000;
    final fi = spendGoldIds(f);
    expect(fi, containsAll(['sp_field', 'sp_genin', 'sp_house', 'sp_alms']));
    for (final x in [
      'sp_horse',
      'sp_sword',
      'sp_kani',
      'sp_gift',
      'sp_roto',
      'sp_shop',
      'sp_robe',
    ]) {
      expect(fi, isNot(contains(x)), reason: '百姓に $x');
    }
    // 城主: 名馬・具足・郎党・官位・献上。田と下人は並ばない。
    final c = _retainer(5);
    c.l.gold = 5000;
    final ci = spendGoldIds(c);
    expect(
      ci,
      containsAll([
        'sp_horse',
        'sp_armor',
        'sp_sword',
        'sp_roto',
        'sp_kani',
        'sp_gift',
        'sp_chaki',
      ]),
    );
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
    for (final x in [
      'sp_house',
      'sp_armor',
      'sp_horse',
      'sp_tutor',
      'sp_robe',
    ]) {
      expect(pi, isNot(contains(x)), reason: '僧に $x');
    }
    // 奥で仕える未婚の女性: 晴れ着。家・武具・郎党は並ばない。
    final w = _retainer(3, female: true);
    w.l.gold = 5000;
    final wi = spendGoldIds(w);
    expect(wi, contains('sp_robe'));
    for (final x in [
      'sp_house',
      'sp_armor',
      'sp_horse',
      'sp_roto',
      'sp_sword',
      'sp_gun',
    ]) {
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
    expect(
      spendMeritIds(c),
      containsAll([
        'sp_m_chigyo',
        'sp_m_suikyo',
        'sp_m_henki',
        'sp_m_sword',
        'sp_m_tea',
      ]),
    );
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
      final g = [
        c,
        m,
        w,
        f,
      ].firstWhere((x) => spendGoldIds(x).contains(e.value), orElse: () => c);
      expect(spendGoldIds(g), contains(e.value), reason: '${e.key} を持つ前');
      g.setFlag(e.key);
      expect(
        spendGoldIds(g),
        isNot(contains(e.value)),
        reason: '${e.key} を持ったあと',
      );
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

  test('ふつうの人生で年の初めに使っても例外がなく、持っている物は並ばず、続きの岐路は持ち物があるときだけ', () {
    var adults = 0, menuShown = 0, spent = 0, boons = 0;
    final uses = <String>{};
    final echoes = <String, int>{};
    final seen = <String, List<Choice>>{};
    for (var seed = 0; seed < 900; seed++) {
      final rng = Rng(seed + 81000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 91000);
      final mode = seed % 3; // 0 ランダム・1 考えて選ぶ・2 使い道をよく使う
      var n = 0, sawMenu = false;
      var known = g.l.flags.where((f) => f.startsWith('scene:sp_e_')).toSet();
      while (!g.finished && n++ < 5000) {
        expect(g.prompt, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
        if (spendingOpen(g)) {
          final m = spendingMenu(g);
          if (m.isNotEmpty) sawMenu = true;
          for (final e in _owned.entries) {
            if (g.hasFlag(e.key)) {
              expect(
                m.map((i) => i.id),
                isNot(contains(e.value)),
                reason: e.key,
              );
            }
          }
          for (final i in m) {
            expect(i.hint.isNotEmpty, isTrue);
            expect(_digits.hasMatch(i.label), isFalse, reason: i.label);
            expect(_digits.hasMatch(i.hint), isFalse, reason: i.hint);
          }
          final m0 = g.l.merit;
          final before = {...g.l.flags};
          if (_maybeBuy(g, r, mode == 2 ? .6 : .15)) {
            if (g.l.merit < m0) {
              boons++;
            } else {
              spent++;
            }
            for (final f in g.l.flags.difference(before)) {
              if (f.startsWith('spb_')) {
                uses.add(f.substring(4, f.indexOf('@')));
              }
            }
          }
        }
        final now = g.l.flags.where((f) => f.startsWith('scene:sp_e_')).toSet();
        for (final f in now.difference(known)) {
          final id = f.substring(6);
          echoes[id] = (echoes[id] ?? 0) + 1;
          seen[id] = g.prompt!.choices;
          final (flag, _) = kSpendEchoGap[id]!;
          expect(g.hasFlag(flag), isTrue, reason: '$id が持ち物なしに出た');
        }
        known = now;
        final q = g.prompt!;
        g.choose(
          mode == 1 ? pickAmbitious(g, q, r) : r.range(0, q.choices.length - 1),
        );
        expect(g.l.merit, greaterThanOrEqualTo(0));
        expect(g.l.gold, greaterThanOrEqualTo(0));
      }
      expect(g.finished, isTrue);
      if (g.age >= 20) {
        adults++;
        if (sawMenu) menuShown++;
      }
    }
    // ignore: avoid_print
    print(
      '【使い道】二十歳を越えた$adults人生: 一覧に使い道が並んだ $menuShown／'
      '使った 銭$spent回・功$boons回・使い道${uses.length}種／続きの岐路 ${echoes.length}種 $echoes',
    );
    expect(menuShown / adults, greaterThan(.5));
    expect(boons, greaterThan(20));
    expect(uses.length, greaterThanOrEqualTo(24));
    expect(echoes.length, greaterThanOrEqualTo(6));
    for (final e in seen.entries) {
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key}: ${c.label}');
        expect(c.hint!.isNotEmpty, isTrue);
        expect(
          _digits.hasMatch(c.label),
          isFalse,
          reason: '${e.key}: ${c.label}',
        );
        expect(
          _digits.hasMatch(c.hint!),
          isFalse,
          reason: '${e.key}: ${c.hint}',
        );
      }
    }
  });

  test('使わない人生と比べて、城主以上に届く割合と銭の貯まり方が大きく変わらない', () {
    (double, double, int) run(bool on) {
      spendingEnabled = on;
      var adults = 0, castle = 0;
      final gold40 = <int>[];
      for (var seed = 0; seed < 1000; seed++) {
        final rng = Rng(seed + 4242);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        final r = Rng(seed);
        final buy = Rng(seed + 777);
        var n = 0, g40 = -1;
        while (!g.finished && n++ < 4000) {
          if (g.age == 40 && g40 < 0) g40 = g.l.gold;
          // 前の「蓄えを使う」は二年に一度・数ある心がけの一つだったので、年の初めに一割あまりの見込みで使う人に見立てる。
          _maybeBuy(g, buy, .12);
          g.choose(
            seed.isEven
                ? pickAmbitious(g, g.prompt!, r)
                : r.range(0, g.prompt!.choices.length - 1),
          );
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
    print(
      '【使い道】城主以上 使わない ${(c0 * 100).toStringAsFixed(1)}%（$a0）→ 使う ${(c1 * 100).toStringAsFixed(1)}%（$a1）'
      '／四十歳の銭の中央 $g0 → $g1',
    );
    expect((c1 - c0).abs(), lessThan(.06));
    expect(g1, greaterThan(g0 * .5));
  });

  test('遺されたもの: 銭と功の使い道の行が出る', () {
    final g = _retainer(5);
    g.l.t = 50 * 2;
    for (final f in [
      'sp_m_henki',
      'sp_kani',
      'sp_kani_proved',
      'sp_horse_fine',
      'sp_armor_saved',
    ]) {
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
    const mine = [
      'sp_horse_fine',
      'sp_armor_saved',
      'sp_chaki',
      'sp_house',
      'sp_field_1',
      'sp_kani',
      'sp_m_henki',
      'sp_tutor',
    ];
    final have = kRemembrances.map((r) => r.id).toSet();
    for (final id in mine) {
      expect(have, contains(id));
    }
  });
}
