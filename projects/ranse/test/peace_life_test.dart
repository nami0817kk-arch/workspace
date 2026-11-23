import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/adult.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/history_lines.dart';
import 'package:ranse/engine/peace.dart';
import 'package:ranse/engine/peace_life.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';

/// 泰平の世の暮らし（`peace_life.dart`、`pl_`）のテスト。
final _digits = RegExp('[0-9０-９%％]');

/// 泰平の世の重点の名（府の名は世界線で変わるので、決まった言い回しで見分ける）。
final _plFocus = RegExp(
  '屋敷に詰める|城の番を勤める|役方の勤めに励む|道場を開き|町の道場に通い|手習い所を開き|新田を拓く|'
  '廻船に荷を積み|謡と仕舞の稽古|俳諧の座に連なる|講の仲間と|家訓をしたため|縁組と、家の跡',
);

/// 徳川の世・江戸を前提にした言葉（歴史が変わった世の場面に出てはいけない）。
final _edoWords = RegExp('幕府|江戸|駿府|将軍');

const _samuraiOnly = {
  'pl_yakugae',
  'pl_kanjo_cho',
  'pl_fushin_ba',
  'pl_rusui',
  'pl_kenyaku',
  'pl_katoku',
  'pl_tsume',
  'pl_yaku',
};
const _townOnly = {
  'pl_machiwari',
  'pl_nakama',
  'pl_kaji',
  'pl_saiken',
  'pl_hikyaku',
  'pl_soba',
  'pl_kaisen',
};
const _villageOnly = {
  'pl_kenchi',
  'pl_murauke',
  'pl_yosui',
  'pl_shinden_kuwa',
  'pl_chosan',
  'pl_tenarai',
  'pl_shoya',
  'pl_nengu',
  'pl_shinden',
};
const _monkOnly = {
  'pl_honmatsu',
  'pl_terauke_tsutome',
  'pl_tomurai',
  'pl_gakuryo',
};
const _womenOnly = {'pl_rusu', 'pl_okuzutome', 'pl_enkiri', 'pl_goke'};
const _veteranOnly = {'pl_gatari', 'pl_furukizu', 'pl_teki', 'pl_gunki'};

/// 新しい `die()` の文（死ぬ結果は控えめ）。
const _plDeaths = [
  '敵討ちの旅の果てに立ち合い',
  'かぶき者の喧嘩に巻き込まれ',
  '蔵へ荷を取りに戻り',
  '村のために越訴し',
];

/// 出た岐路の選択肢（あとで匂わせ・数字・印を確かめる）。
final _seenChoices = <String, List<Choice>>{};

String _base(String id) =>
    id.endsWith('_again') ? id.substring(0, id.length - 6) : id;

/// 岐路が出た瞬間（選ぶ前）の年・身分・筋・世界線を確かめる。
void _checkScene(Game g, String id, Prompt p) {
  final l = g.l;
  final b = _base(id);
  final why = '$id ${g.year}年 ${g.rankName()} ${worldLine(g)}';
  expect(g.year, greaterThanOrEqualTo(kPeaceLifeFrom), reason: why);
  expect(peaceTime(g), isTrue, reason: why);
  expect(
    kPeaceLifeSceneIds.contains(b) || kPeaceLifeFocusTags.contains(b),
    isTrue,
    reason: why,
  );
  // 筋: 前の段の旗がなければ出ない。
  final roots = kPeaceLifeRoots[id];
  if (roots != null) expect(roots.any(g.hasFlag), isTrue, reason: why);
  expect(plRooted(g, id), isTrue, reason: why);
  // 世界線: 徳川の世の定めを前提にした岐路は史実どおりの世だけ。ほかの世の場面に、幕府や江戸の言葉は出ない。
  if (kPeaceLifeEdoScenes.contains(id)) expect(worldLine(g), 'real', reason: why);
  final words = [p.title, p.text, for (final c in p.choices) '${c.label}${c.hint}'].join();
  if (worldLine(g) != 'real') {
    expect(_edoWords.hasMatch(words), isFalse, reason: '$why $words');
  }
  if (g.hasFlag('history_odawara')) {
    expect(words.contains('江戸'), isFalse, reason: '$why $words');
  }
  // 身分
  if (_samuraiOnly.contains(b)) {
    expect(l.female, isFalse, reason: why);
    expect(l.rank, inInclusiveRange(1, 7), reason: why);
    expect(l.lord, isNotNull, reason: why);
    expect(g.hasFlag('retired'), isFalse, reason: why);
  }
  if (_townOnly.contains(b)) {
    expect(l.rank, 0, reason: why);
    expect(g.hasFlag('way_merchant') || l.cls.id == 'merchant', isTrue, reason: why);
    expect(g.hasFlag('priesthood'), isFalse, reason: why);
  }
  if (_villageOnly.contains(b)) {
    expect(l.rank, 0, reason: why);
    expect(['farmer', 'fisher'], contains(l.cls.id), reason: why);
    expect(g.hasFlag('priesthood'), isFalse, reason: why);
    expect(g.hasFlag('way_merchant'), isFalse, reason: why);
  }
  if (_monkOnly.contains(b)) expect(g.hasFlag('priesthood'), isTrue, reason: why);
  if (_womenOnly.contains(b)) expect(l.female, isTrue, reason: why);
  if (_veteranOnly.contains(b)) expect(g.hasFlag('first_battle'), isTrue, reason: why);
  if (b == 'pl_sankin_cost') {
    expect(l.rank, greaterThanOrEqualTo(5), reason: why);
    expect(g.year, greaterThanOrEqualTo(1635), reason: why);
  }
  if (b == 'pl_kaieki') expect(g.year, inInclusiveRange(1619, 1645), reason: why);
  if (b == 'pl_honmatsu') expect(g.year, greaterThanOrEqualTo(1632), reason: why);
  if (b == 'pl_terauke_tsutome') expect(g.year, greaterThanOrEqualTo(1638), reason: why);
  if (b == 'pl_mushuku') expect(g.hasFlag('way_outlaw'), isTrue, reason: why);
  if (b == 'pl_saishikan') expect(l.ronin, isTrue, reason: why);
  // 子の出る場面は、その歳・性別の実在の子の名で語る。
  if (b == 'pl_hoko_kid') {
    final k = l.kidAged(g.year, 10, 15);
    expect(k, isNotNull, reason: why);
    expect(p.text, contains(k!.name), reason: why);
  }
  if (b == 'pl_katoku') {
    final sons = l.kidsAged(g.year, 15, 45, false);
    expect(sons, isNotEmpty, reason: why);
    expect(sons.any((k) => p.text.contains(k.name)), isTrue, reason: why);
  }
  if (b == 'pl_musume_hoko') {
    final d = l.daughterAged(g.year, 11, 16);
    expect(d, isNotNull, reason: why);
    expect(p.text, contains(d!.name), reason: why);
  }
  if (b == 'pl_matsugo') {
    expect(l.kidsAged(g.year, 0, 999, false, false), isEmpty, reason: why);
  }
  if (b == 'pl_hoko_kaeri') {
    expect(l.livingKids.any((k) => !k.home && p.text.contains(k.name)), isTrue, reason: why);
  }
}

/// 「今年の重点」に並んだ泰平の世の重点を確かめる（一六〇一年より前・戦の絶えない世には出ない。上限まで）。
void _checkFocus(Game g, Prompt p) {
  final mine = [
    for (final c in p.choices)
      if (_plFocus.hasMatch(c.label)) c,
  ];
  final why = '${g.year}年 ${g.rankName()} ${mine.map((c) => c.label).join('／')}';
  if (!plPeace(g)) {
    expect(mine, isEmpty, reason: why);
    return;
  }
  expect(mine.length, lessThanOrEqualTo(kPeaceLifePerYear), reason: why);
  final l = g.l;
  for (final c in mine) {
    expect(c.hint, isNotNull, reason: why);
    expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
    expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
    // `bot.dart` の選び方が、休む・縁談の重点と取り違えない名。
    expect(RegExp('休|家族|妻|嫁').hasMatch(c.label), isFalse, reason: c.label);
    if (RegExp('詰める|城の番を勤める|役方').hasMatch(c.label)) {
      expect(l.female, isFalse, reason: why);
      expect(l.rank, inInclusiveRange(1, 7), reason: why);
    }
    if (RegExp('新田を拓く|講の仲間と|手習い所を開き').hasMatch(c.label)) {
      expect(l.rank, 0, reason: why);
    }
    if (c.label.contains('新田を拓く')) {
      expect(['farmer', 'fisher'], contains(l.cls.id), reason: why);
    }
    if (c.label.contains('廻船')) expect(g.hasFlag('way_merchant'), isTrue, reason: why);
    if (c.label.contains('道場')) expect(l.female, isFalse, reason: why);
    if (worldLine(g) != 'real') {
      expect(_edoWords.hasMatch('${c.label}${c.hint}'), isFalse, reason: why);
    }
  }
}

/// 人生の終わりまで進める。新しく出た泰平の世の岐路の id（はじめて出たものだけ）を返す。
List<String> _play(
  Game g,
  int Function(Game g, Prompt p) pick, {
  int limit = 6000,
}) {
  final out = <String>[];
  var known = g.l.flags.where((f) => f.startsWith('scene:pl_')).toSet();
  var n = 0;
  String? pending; // 選んだ泰平の世の重点（始めの一回）
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:pl_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.add(id);
      _checkScene(g, id, p!);
      _seenChoices.putIfAbsent(id, () => p.choices);
    }
    known = now;
    if (pending != null) {
      // 始めの一回の重点を選んだ年には、その岐路が起きる。
      expect(g.hasFlag('scene:$pending'), isTrue, reason: '$pending ${g.year}年');
      pending = null;
    }
    final i = pick(g, p!);
    if (p.title == '今年の重点') {
      _checkFocus(g, p);
      final label = p.choices[i].label;
      if (_plFocus.hasMatch(label)) {
        for (final o in peaceLifeTags(g)) {
          if (!g.hasFlag('scene:$o') && _tagOfLabel(label) == o) pending = o;
        }
      }
    }
    g.choose(i);
  }
  expect(g.finished, isTrue, reason: '人生が終わらない（${g.age}歳・${g.year}年）');
  return out;
}

String? _tagOfLabel(String label) {
  if (RegExp('詰める|城の番を勤める').hasMatch(label)) return 'pl_tsume';
  if (label.contains('役方')) return 'pl_yaku';
  if (label.contains('道場')) return 'pl_dojo';
  if (label.contains('手習い所')) return 'pl_terako';
  if (label.contains('新田を拓く')) return 'pl_shinden';
  if (label.contains('廻船')) return 'pl_kaisen';
  if (RegExp('謡と仕舞|俳諧の座').hasMatch(label)) return 'pl_haikai';
  if (label.contains('講の仲間')) return 'pl_ko';
  if (label.contains('家訓')) return 'pl_kakun';
  if (label.contains('縁組と')) return 'pl_engumi';
  return null;
}

/// 一六〇一年に大人として生きていられる生まれ（一五四五年からの生まれ）で、元服まで生きた人生。
Game? _lateBorn(int seed) {
  final rng = Rng(seed);
  final b = rollBirth(rng);
  if (b.startYear < 1545) return null;
  final g = Game(rng: rng);
  g.start(b);
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  return g.finished ? null : g;
}

/// 命を落としにくい選び方。泰平の世の重点が並んでいれば、[focusRate] の割合でそれを選ぶ。
int _pickCareful(Game g, Prompt p, Rng r, {double focusRate = 0}) {
  final cs = p.choices;
  if (p.title == '今年の重点') {
    final mine = [
      for (var i = 0; i < cs.length; i++)
        if (_plFocus.hasMatch(cs[i].label)) i,
    ];
    if (mine.isNotEmpty && r.chance(focusRate)) {
      return mine[r.range(0, mine.length - 1)];
    }
    for (final w in ['体を休める', '主君に尽くす', '奥向きに尽くす', '学問に励む']) {
      final i = cs.indexWhere((c) => c.label.contains(w));
      if (i >= 0 && r.chance(.5)) return i;
    }
    final safe = [
      for (var i = 0; i < cs.length; i++)
        if (!RegExp('戦に備える|版図|獲物|流れる').hasMatch(cs[i].label)) i,
    ];
    return safe.isEmpty ? 0 : safe[r.range(0, safe.length - 1)];
  }
  final safe = [
    for (var i = 0; i < cs.length; i++)
      if (!RegExp('命|討死|死|危う|ただでは|咎め|磔|助から|生きて帰|返り討ち').hasMatch(cs[i].hint ?? '')) i,
  ];
  return safe.isEmpty
      ? r.range(0, cs.length - 1)
      : safe[r.range(0, safe.length - 1)];
}

/// 元服のあと、泰平の世の岐路に合う暮らしへ置き直す（種で順に）。
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
      g.setFlag('first_battle');
      g.setFlag('pc_ronin');
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
    case 5: // 足軽
      l.rank = 1;
      l.maxRank = 1;
      l.lord = home();
      l.fav = 40;
      g.setFlag('first_battle');
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

void main() {
  test('表: 岐路は大人の岐路に一度ずつあり、重点は十、筋と出し分けの表は実在の岐路を指す', () {
    final g = Game(rng: Rng(1));
    final ids = [for (final s in g.adultScenes) s.id];
    final pl = ids.where((e) => e.startsWith('pl_')).toList();
    expect(pl.toSet().length, pl.length, reason: 'id の重複');
    for (final id in kPeaceLifeSceneIds) {
      expect(ids.where((e) => e == id).length, 1, reason: id);
    }
    expect(kPeaceLifeSceneIds.length, inInclusiveRange(40, 55));
    expect(kPeaceLifeSceneIds.toSet().length, kPeaceLifeSceneIds.length);
    expect(kPeaceLifeFocusTags.length, inInclusiveRange(8, 10));
    expect(
      pl.toSet(),
      {
        ...kPeaceLifeSceneIds,
        ...kPeaceLifeFocusTags,
        for (final t in kPeaceLifeFocusTags) '${t}_again',
      },
    );
    final byId = {for (final s in g.adultScenes) s.id: s};
    for (final t in kPeaceLifeFocusTags) {
      expect(byId[t]!.onlyForced, isTrue, reason: t);
      expect(byId[t]!.repeat, isFalse, reason: t);
      expect(byId['${t}_again']!.onlyForced, isTrue, reason: t);
      expect(byId['${t}_again']!.repeat, isTrue, reason: t);
    }
    for (final id in kPeaceLifeSceneIds) {
      expect(byId[id]!.onlyForced, isFalse, reason: id);
      expect(byId[id]!.repeat, isFalse, reason: id);
    }
    // 筋は六本以上。前の段の旗は、engine のどこかで立つ旗（`pl_` はこの中、`pc_` は peace.dart）。
    expect(kPeaceLifeRoots.length, greaterThanOrEqualTo(6));
    expect(kPeaceLifeSceneIds.toSet().containsAll(kPeaceLifeRoots.keys), isTrue);
    expect(kPeaceLifeSceneIds.toSet().containsAll(kPeaceLifeEdoScenes), isTrue);
    // 年の決まった史実の岐路ではない（その年の岐路を押しのけない）。
    for (final id in pl) {
      expect(id.startsWith('pl_'), isTrue);
    }
  });

  test('一六〇一年より前・戦の絶えない世には、重点も岐路も出ない（条件がすべて偽）', () {
    Game? young;
    for (var s = 0; young == null; s++) {
      young = _lateBorn(s);
    }
    expect(young.year, lessThan(kPeaceLifeFrom));
    for (var k = 0; k < 8; k++) {
      _shape(young, k);
      // 筋の旗をすべて立てても、年が来なければ出ない。
      for (final rs in kPeaceLifeRoots.values) {
        rs.forEach(young.setFlag);
      }
      expect(plPeace(young), isFalse);
      expect(peaceLifeTags(young), isEmpty);
      expect(peaceLifeFocusOptions(young), isEmpty);
      for (final s in young.adultScenes) {
        if (s.id.startsWith('pl_')) {
          expect(s.cond(young), isFalse, reason: '${s.id} ${young.year}年');
        }
      }
      expect(
        adultFocusOptions(young).any((o) => o.tag.startsWith('pl_')),
        isFalse,
      );
    }
    // 今川の世（乱世が続く）では、一六〇一年を過ぎても出ない。
    young.setFlag('history_okehazama');
    young.l.t = (1620 - young.l.startYear) * 2;
    expect(young.year, 1620);
    expect(plPeace(young), isFalse);
    expect(peaceLifeTags(young), isEmpty);
    for (final s in young.adultScenes) {
      if (s.id.startsWith('pl_')) expect(s.cond(young), isFalse, reason: s.id);
    }
  });

  test('筋の後段は、前の段の旗がなければ条件が偽', () {
    Game? g;
    for (var s = 0; g == null; s++) {
      g = _lateBorn(s + 50);
    }
    final byId = {for (final s in g.adultScenes) s.id: s};
    for (var k = 0; k < 8; k++) {
      _shape(g, k);
      g.l.flags.removeWhere(
        (f) => f.startsWith('pl_') || f.startsWith('pc_'),
      );
      for (final year in [1605, 1625, 1640]) {
        g.l.t = (year - g.l.startYear) * 2;
        for (final id in kPeaceLifeRoots.keys) {
          expect(plRooted(g, id), isFalse, reason: id);
          expect(byId[id]!.cond(g), isFalse, reason: '$id $year年');
        }
      }
    }
    // 旗を立てれば、筋は通る。
    for (final e in kPeaceLifeRoots.entries) {
      g.setFlag(e.value.first);
      expect(plRooted(g, e.key), isTrue, reason: e.key);
    }
  });

  test('重点の出し分け: 身分・道・世界線で名と数が合う', () {
    Game shaped(int k, int year, {bool female = false, String? line}) {
      for (var s = 0; ; s++) {
        final g = _lateBorn(s * 3 + k);
        if (g == null || g.l.female != female) continue;
        _shape(g, k);
        if (line != null) g.setFlag(line);
        g.l.t = (year - g.l.startYear) * 2;
        return g;
      }
    }

    // 侍: 府へ詰める・役方・道場。百姓の新田・商人の廻船は出ない。
    var g = shaped(0, 1612);
    var tags = peaceLifeTags(g);
    expect(tags, containsAll(['pl_tsume', 'pl_yaku', 'pl_dojo']));
    expect(tags, isNot(contains('pl_shinden')));
    expect(tags, isNot(contains('pl_kaisen')));
    expect(tags, isNot(contains('pl_ko')));
    expect(peaceLifeFocusOptions(g).length, kPeaceLifePerYear);
    expect(plSeat(g), '江戸');
    expect(plKogi(g), '幕府');
    // 世界線で府の名が替わる。
    expect(plSeat(shaped(0, 1612, line: 'history_sekigahara')), '大坂');
    expect(plSeat(shaped(0, 1612, line: 'history_honnoji')), '安土');
    expect(plSeat(shaped(0, 1612, line: 'history_yamazaki')), '京');
    expect(plSeat(shaped(0, 1612, line: 'history_odawara')), '駿府');
    expect(plKogi(shaped(0, 1612, line: 'history_sekigahara')), '公儀');
    final west = shaped(0, 1612, line: 'history_sekigahara');
    west.l.lord = '毛利';
    final labels = [
      for (var i = 0; i < 40; i++)
        for (final o in peaceLifeFocusOptions(west)) o.label,
    ];
    expect(labels, contains('大坂の屋敷に詰める'));
    expect(labels.any((x) => x.contains('江戸')), isFalse);
    // 商いの道: 廻船と講。役方は出ない。
    g = shaped(2, 1612);
    tags = peaceLifeTags(g);
    expect(tags, contains('pl_kaisen'));
    expect(tags, isNot(contains('pl_yaku')));
    expect(tags, isNot(contains('pl_shinden')));
    // 仏門: 手習い所（字が読めるとき）だけ。
    g = shaped(3, 1612);
    g.l.chi = 60;
    expect(peaceLifeTags(g), ['pl_terako']);
    g.l.chi = 30;
    expect(peaceLifeTags(g), isEmpty);
    // 野の道には何も出ない。
    expect(peaceLifeTags(shaped(4, 1612)), isEmpty);
    // 百姓: 新田。女性は道場が出ず、講は善光寺。
    for (var s = 0; ; s++) {
      final x = _lateBorn(s);
      if (x == null || x.l.cls.id != 'farmer' || x.l.rank != 0 || !x.l.female) continue;
      x.l.t = (1612 - x.l.startYear) * 2;
      x.l.gold = 30;
      x.l.ronin = false;
      x.l.flags.removeWhere(
        (f) => f == 'priesthood' || f == 'way_merchant' || f == 'way_outlaw' || f == 'retired',
      );
      final t = peaceLifeTags(x);
      expect(t, containsAll(['pl_shinden', 'pl_ko']));
      expect(t, isNot(contains('pl_dojo')));
      expect(t, isNot(contains('pl_tsume')));
      final all = [
        for (var i = 0; i < 40; i++)
          for (final o in peaceLifeFocusOptions(x)) o.label,
      ];
      expect(all, contains('講の仲間と、善光寺へ詣でる'));
      break;
    }
  });

  test('暮らしを置き直した九百人生: 岐路は一六〇一年からだけ出て、身分・筋・世界線に合い、匂わせがあり数字が無い', () {
    _seenChoices.clear();
    final seen = <String, int>{};
    var lives = 0, reached = 0, total = 0, reached20 = 0, total20 = 0, withScene = 0;
    var deaths = 0;
    for (var seed = 0; seed < 4200 && lives < 900; seed++) {
      final g = _lateBorn(seed * 5 + 2);
      if (g == null) continue;
      lives++;
      _shape(g, seed);
      // 歴史が変わった世・小田原の世を混ぜる。
      if (seed % 9 == 1) g.setFlag('history_sekigahara');
      if (seed % 9 == 3) g.setFlag('history_honnoji');
      if (seed % 9 == 5) g.setFlag('history_yamazaki');
      if (seed % 9 == 7) g.setFlag('history_odawara');
      if (seed % 31 == 8) g.setFlag('history_okehazama');
      final r = Rng(seed);
      final ids = _play(g, (g, p) => _pickCareful(g, p, r, focusRate: .35));
      if (g.hasFlag('history_okehazama')) expect(ids, isEmpty);
      if (_plDeaths.any((d) => (g.l.dead ?? '').contains(d))) deaths++;
      if (g.year >= kPeaceLifeFrom && plPeace(g)) {
        reached++;
        total += ids.length;
        if (ids.isNotEmpty) withScene++;
        if (g.year >= 1620) {
          reached20++;
          total20 += ids.length;
        }
      }
      for (final id in ids) {
        seen[id] = (seen[id] ?? 0) + 1;
      }
    }
    // ignore: avoid_print
    print(
      '【泰平の世の暮らし】$lives人生（泰平の世に届いた $reached・うち一六二〇年から $reached20）: '
      '平均 ${(total / reached).toStringAsFixed(2)}・一六二〇年から ${(total20 / reached20).toStringAsFixed(2)}・'
      '一つ以上 $withScene・新しい岐路での死 $deaths／'
      '${seen.length}種 ${(seen.entries.toList()..sort((a, b) => b.value - a.value)).map((e) => '${e.key.substring(3)} ${e.value}').join('・')}',
    );
    expect(reached, greaterThan(150));
    expect(total / reached, greaterThanOrEqualTo(3));
    expect(total20 / reached20, greaterThanOrEqualTo(5));
    expect(withScene / reached, greaterThan(.8));
    expect(seen.length, greaterThanOrEqualTo(45));
    expect(seen.keys.where((k) => k.endsWith('_again')).length, greaterThanOrEqualTo(5));
    expect(deaths / reached, lessThan(.03));
    for (final e in _seenChoices.entries) {
      expect(e.value.length, inInclusiveRange(2, 4), reason: e.key);
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key} ${c.label}');
        expect(c.hint!.length, greaterThan(5), reason: c.label);
        expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
        expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
        if (c.via != null) {
          expect(viaKnown(c.via!), isTrue, reason: '${e.key} ${c.via}');
        }
      }
    }
  });

  test('ふつうの人生: 一六〇一年に届いた人生は泰平の世の岐路に平均三つ以上、一六二〇年からは五つ以上出会う', () {
    var reached = 0, total = 0, reached20 = 0, total20 = 0;
    final vias = <String, int>{};
    for (var seed = 0; seed < 6000 && reached < 260; seed++) {
      final g = _lateBorn(seed * 7 + 11);
      if (g == null) continue;
      final r = Rng(seed);
      final before = _seenChoices.length;
      final ids = _play(
        g,
        (g, p) => seed.isEven
            ? _pickCareful(g, p, r)
            : _pickCareful(g, p, r, focusRate: .25),
      );
      if (_seenChoices.length != before) {
        for (final cs in _seenChoices.values) {
          for (final c in cs) {
            if (c.via != null) vias[c.via!] = (vias[c.via!] ?? 0) + 1;
          }
        }
      }
      if (g.year >= kPeaceLifeFrom && plPeace(g)) {
        reached++;
        total += ids.length;
        if (g.year >= 1620) {
          reached20++;
          total20 += ids.length;
        }
      }
    }
    // ignore: avoid_print
    print(
      '【泰平の世の暮らし・ふつうの人生】泰平の世に届いた $reached: 平均 ${(total / reached).toStringAsFixed(2)}／'
      '一六二〇年から $reached20: 平均 ${(total20 / reached20).toStringAsFixed(2)}',
    );
    expect(reached, greaterThanOrEqualTo(200));
    expect(total / reached, greaterThanOrEqualTo(3));
    expect(reached20, greaterThan(30));
    expect(total20 / reached20, greaterThanOrEqualTo(5));
    // 能力で増える手の印は、決めた語（武・知・政・魅・運、特性の名）だけ。
    for (final v in vias.keys) {
      expect(viaKnown(v), isTrue, reason: v);
    }
  });

  test('遺されたもの: 泰平の世の暮らしの旗に対応する行が出て、数字が無い', () {
    const flags = [
      'pl_kanjo_clean',
      'pl_kataki_done',
      'pl_kataki_spared',
      'pl_saiken_trust',
      'pl_soba_told',
      'pl_murauke_helped',
      'pl_yakunin_open',
      'pl_nengu_osso',
      'pl_tomurai_free',
      'pl_enkiri_helped',
      'pl_terako_girls',
      'pl_told_true',
      'pl_kikigaki',
    ];
    Game? g;
    for (var s = 0; g == null; s++) {
      g = _lateBorn(s + 800);
    }
    for (final f in flags) {
      expect(kRemembrances.where((r) => r.id == f).length, 1, reason: f);
      g.l.t = 65 * 2;
      g.l.flags.clear();
      g.l.people.clear();
      g.l.path.clear();
      g.l.focus.clear();
      g.l.kids = 0;
      g.setFlag(f);
      final mine = kRemembrances.firstWhere((r) => r.id == f).say(g);
      expect(RegExp('[0-9０-９]').hasMatch(mine), isFalse, reason: f);
      expect(remembrances(g), contains(mine), reason: f);
    }
    // 敵討ちの二つの行は同じ組（一行だけ出る）。
    g.l.flags.clear();
    g.setFlag('pl_kataki_done');
    g.setFlag('pl_kataki_spared');
    final ids = [for (final r in rememberedEntries(g)) r.id];
    expect(ids.where((i) => i.startsWith('pl_kataki')).length, 1);
    expect(ids, contains('pl_kataki_done'));
  });
}
