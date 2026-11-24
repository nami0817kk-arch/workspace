import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/ending.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/history.dart';
import 'package:ranse/engine/history_lines.dart';
import 'package:ranse/engine/peace.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/ways.dart';

import 'bot.dart';

/// 亡くなるまで続く（一六〇一年からの世）のテスト。
final _digits = RegExp('[0-9０-９%％]');

/// 出た泰平の岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

const _samuraiOnly = {
  'pc_meshihanachi',
  'pc_osaka_jin',
  'pc_osaka_toyotomi',
  'pc_junshi',
  'pc_sankin',
  'pc_shimabara',
};
const _merchantOnly = {'pc_edo_shop', 'pc_shuin', 'pc_kaikin', 'pc_daimyo_kashi'};
const _womenOnly = {'pc_hatago', 'pc_edo_yashiki', 'pc_ooku', 'pc_ooku_okite'};
const _villageOnly = {'pc_gonin', 'pc_shinden'};

/// 岐路が出た瞬間（選ぶ前）の身分・年を確かめる。
void _checkScene(Game g, String id) {
  final l = g.l;
  final why = '$id ${g.year}年 ${g.rankName()}';
  expect(g.year, greaterThanOrEqualTo(kPeaceFrom), reason: why);
  expect(kPeaceSceneIds, contains(id), reason: why);
  if (kPeaceEdoScenes.contains(id)) expect(worldLine(g), 'real', reason: why);
  if (kPeaceAnyLineScenes.contains(id)) expect(peaceTime(g), isTrue, reason: why);
  final root = kPeaceRoots[id];
  if (root != null) expect(g.hasFlag(root), isTrue, reason: why);
  if (_samuraiOnly.contains(id)) {
    expect(l.female, isFalse, reason: why);
    expect(l.rank, inInclusiveRange(1, 7), reason: why);
    expect(l.lord, isNotNull, reason: why);
  }
  if (id == 'pc_osaka_ronin' || id == 'pc_osaka_natsu' || id == 'pc_ronin_life') {
    expect(l.ronin, isTrue, reason: why);
    expect(l.rank, 0, reason: why);
  }
  if (id == 'pc_osaka_toyotomi') expect(l.lord, '織田', reason: why);
  if (id == 'pc_osaka_jin') expect(l.lord, isNot('織田'), reason: why);
  if (_merchantOnly.contains(id)) {
    expect(g.hasFlag('way_merchant'), isTrue, reason: why);
    expect(l.rank, 0, reason: why);
  }
  if (_womenOnly.contains(id)) expect(l.female, isTrue, reason: why);
  if (_villageOnly.contains(id)) {
    expect(['farmer', 'fisher'], contains(l.cls.id), reason: why);
    expect(l.rank, 0, reason: why);
  }
  if (id == 'pc_jiin') expect(g.hasFlag('priesthood'), isTrue, reason: why);
  if (id == 'pc_ikkoku' || id == 'pc_fushin') {
    expect(l.rank, inInclusiveRange(5, 8), reason: why);
  }
  if (id == 'pc_osaka_ronin' || id == 'pc_osaka_jin' || id == 'pc_osaka_toyotomi') {
    expect(g.year, 1614, reason: why);
  }
  if (id == 'pc_ikkoku' || id == 'pc_osaka_natsu') expect(g.year, 1615, reason: why);
  if (id == 'pc_shimabara') expect(g.year, 1638, reason: why);
  if (id == 'pc_kaifu') expect(g.year, 1603, reason: why);
  if (id == 'pc_kikin') expect(g.year, 1642, reason: why);
}

/// 人生の終わりまで進める。新しく出た泰平の岐路の id を返す。
List<String> _play(
  Game g,
  int Function(Game g, Prompt p) pick, {
  int limit = 6000,
  void Function(Game g, Prompt p)? onPrompt,
}) {
  final out = <String>[];
  var known = g.l.flags.where((f) => f.startsWith('scene:pc_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:pc_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.add(id);
      _checkScene(g, id);
      _seenChoices.putIfAbsent(id, () => p!.choices);
    }
    known = now;
    onPrompt?.call(g, p!);
    g.choose(pick(g, p!));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない（${g.age}歳・${g.year}年）');
  return out;
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

/// 命を落としにくい選び方（泰平の世まで生きる人生を増やす）。重点は身分に合うものを選び、
/// 岐路は危うさを匂わせる手を避ける。
int _pickCareful(Game g, Prompt p, Rng r) {
  final cs = p.choices;
  if (p.title == 'この年の心がけ') {
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
      if (!RegExp('命|討死|死|危う|ただでは|咎め|磔|助から|生きて帰').hasMatch(cs[i].hint ?? '')) i,
  ];
  return safe.isEmpty
      ? r.range(0, cs.length - 1)
      : safe[r.range(0, safe.length - 1)];
}

/// 元服のあと、泰平の岐路に合う暮らしへ置き直す（種で順に）。
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

void main() {
  test('年号は元和・寛永・明暦まで続き、豊臣の家は豊臣と呼ぶ', () {
    // 生まれは一五二五年から（天文より前を「天文-2年」にしない）。
    expect(gengo(1525), '大永5年');
    expect(gengo(1528), '享禄元年');
    expect(gengo(1529), '享禄2年');
    expect(gengo(1532), '天文元年');
    expect(gengo(1614), '慶長19年');
    expect(gengo(1615), '元和元年');
    expect(gengo(1624), '寛永元年');
    expect(gengo(1637), '寛永14年');
    expect(gengo(1657), '明暦3年');
    Game? g;
    for (var s = 0; g == null; s++) {
      g = _lateBorn(s);
    }
    while (!g.finished && g.year < 1590) {
      g.choose(0);
    }
    if (!g.finished && worldLine(g) == 'real' && g.l.lord != '織田') {
      expect(houseName(g, '織田'), '豊臣');
      expect(houseName(g, '松平'), '徳川');
    }
  });

  test('一六〇一年を越えても人生は続き、必ず死か天下統一で終わる（三千人生。没年は一六六〇年代まで）', () {
    final deathYears = <int>[];
    var after1600 = 0, victory = 0, maxAge = 0;
    for (var seed = 0; seed < 3000; seed++) {
      final rng = Rng(seed * 3 + 1);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed);
      _play(
        g,
        (g, p) => seed.isEven
            ? r.range(0, p.choices.length - 1)
            : (seed % 4 == 1 ? pickAmbitious(g, p, r) : _pickCareful(g, p, r)),
      );
      // 終わり方は、死か天下統一だけ（「乱世を生き抜いた」で終わる決まりは、もう無い）。
      expect(g.l.end, anyOf(isNull, 'victory'));
      if (g.l.end == 'victory') {
        victory++;
        expect(g.l.victory, isTrue);
      } else {
        expect(g.l.dead, isNotNull);
        deathYears.add(g.year);
      }
      expect(g.age, lessThanOrEqualTo(Game.kMaxAge + 1));
      if (g.age > maxAge) maxAge = g.age;
      if (g.year >= 1601) after1600++;
    }
    deathYears.sort();
    final late = deathYears.where((y) => y >= 1601).toList();
    // ignore: avoid_print
    print(
      '【没年】三千人生: 一六〇一年からの世で終わった人生 $after1600（天下統一 $victory）'
      '／没年 最大${deathYears.last}・一六〇一年からの没年の中央${late.isEmpty ? '-' : late[late.length ~/ 2]}'
      '／一六一六年から ${deathYears.where((y) => y >= 1616).length}・一六三六年から ${deathYears.where((y) => y >= 1636).length}'
      '／最高齢 $maxAge',
    );
    expect(after1600, greaterThan(150));
    expect(deathYears.last, greaterThan(1620));
    // 生まれは一五六八年までで、寿命の上限は kMaxAge。
    expect(deathYears.last, lessThanOrEqualTo(1568 + Game.kMaxAge + 1));
    expect(deathYears.last, lessThan(1670));
  });

  test('一六〇〇年からの年表: 史実の世では幕府が開かれ豊臣が滅び、歴史が変わった世では別の出来事が起きる', () {
    // 表: 一六〇〇年の戦のあとの史実が二十件以上、どの世界線にも一六〇一年からの出来事が三件以上。
    final later = kHistory.where(
      (e) => e.year >= 1601 || e.id == 'kaieki_1600',
    );
    expect(later.length, greaterThanOrEqualTo(20));
    expect(later.map((e) => e.id).toSet().length, later.length);
    for (final line in ['west', 'nobunaga', 'akechi', 'imagawa']) {
      final n = kAltHistory.where((e) => e.only == line && e.year >= 1601);
      expect(n.length, greaterThanOrEqualTo(3), reason: line);
      // 徳川の世の出来事は、その世では起きない。
      for (final id in ['edo_bakufu', 'osaka_natsu', 'sankin', 'shimabara']) {
        expect(kSkipEvents[line], contains(id), reason: '$line $id');
      }
    }
    final ids = {for (final e in kHistoryInOrder) e.id};
    expect(ids.containsAll(skipEventIds()), isTrue);

    Game grown(int from) {
      for (var s = from; ; s++) {
        final g = _lateBorn(s);
        if (g != null && g.l.rank < 8) return g;
      }
    }

    String logOf(Game g) => g.l.log.map((e) => e.txt).join('\n');

    // 史実どおりの世
    var g = grown(0);
    g.l.log.clear();
    applyHistory(g, 1660);
    var t = logOf(g);
    expect(worldLine(g), 'real');
    for (final w in ['江戸に幕府', '大坂夏の陣', '一国一城令', '武家諸法度', '元和の大殉教', '参勤交代', '原の古城', '寛永の飢饉', '明暦の大火']) {
      expect(t, contains(w));
    }
    if (g.l.lord != '織田') expect(g.fa['織田']!.alive, isFalse);
    if (g.l.lord != '長宗我部') expect(g.fa['長宗我部']!.alive, isFalse);
    expect(g.fa['松平']!.alive, isTrue);

    // 西軍が勝った世
    g = grown(40);
    g.setFlag('history_sekigahara');
    g.l.log.clear();
    applyHistory(g, 1660);
    t = logOf(g);
    expect(t, isNot(contains('江戸に幕府')));
    expect(t, isNot(contains('大坂夏の陣')));
    expect(t, isNot(contains('参勤交代')));
    expect(t, contains('秀頼の子の代'));
    expect(t, contains('寛永の飢饉')); // 天災はどの世でも
    expect(g.fa['織田']!.alive, isTrue);

    // 信長の世・明智の世・今川の世
    for (final (flag, word) in [
      ('history_honnoji', '織田の世は三代'),
      ('history_yamazaki', '東西ふたつの天下'),
      ('history_okehazama', '天下人のいないまま'),
    ]) {
      g = grown(80);
      g.setFlag(flag);
      g.l.log.clear();
      applyHistory(g, 1660);
      t = logOf(g);
      expect(t, contains(word), reason: flag);
      expect(t, isNot(contains('江戸に幕府')), reason: flag);
      expect(t, isNot(contains('原の古城')), reason: flag);
    }

    // 小さな分岐: 小田原で北条が残った世では、幕府は駿府に開かれる。
    g = grown(120);
    g.setFlag('history_odawara');
    g.l.log.clear();
    applyHistory(g, 1660);
    t = logOf(g);
    expect(t, contains('駿府に幕府'));
    expect(t, isNot(contains('江戸に幕府')));
    expect(t, contains('駿府と国元'));
    expect(t, isNot(contains('明暦の大火')));
    // 長篠・川中島の続き
    g = grown(160);
    g.setFlag('history_nagashino');
    g.l.log.clear();
    applyHistory(g, 1660);
    if (g.fa['武田']!.alive) expect(logOf(g), contains('武田の赤備え'));
  });

  test('泰平の岐路の表: すべて大人の岐路に一度ずつあり、歴史が変わった世の出し分けの表に入っている', () {
    final g = Game(rng: Rng(1));
    final ids = [for (final s in g.adultScenes) s.id];
    for (final id in kPeaceSceneIds) {
      expect(ids.where((e) => e == id).length, 1, reason: id);
    }
    final pc = ids.where((e) => e.startsWith('pc_')).toSet();
    expect(pc, kPeaceSceneIds);
    expect(pc.length, greaterThanOrEqualTo(28));
    expect(kPeaceSceneIds.containsAll(kPeaceHistoryScenes), isTrue);
    expect(kPeaceSceneIds.containsAll(kPeaceRoots.keys), isTrue);
    expect(kPeaceEdoScenes.containsAll(kPeaceEdoTownScenes), isTrue);
    for (final id in kPeaceHistoryScenes) {
      expect(isHistoryScene(id), isTrue, reason: id);
    }
    for (final line in ['west', 'nobunaga', 'akechi', 'imagawa']) {
      expect(kSkipScenes[line]!.containsAll(kPeaceEdoScenes), isTrue, reason: line);
    }
    expect(
      kFlagSkipScenes['history_odawara']!.containsAll(kPeaceEdoTownScenes),
      isTrue,
    );
    // 一六〇一年より前は、どの岐路の条件も偽。
    Game? young;
    for (var s = 0; young == null; s++) {
      young = _lateBorn(s);
    }
    expect(young.year, lessThan(kPeaceFrom));
    for (var k = 0; k < 8; k++) {
      _shape(young, k);
      for (final s in young.adultScenes) {
        if (s.id.startsWith('pc_')) {
          expect(s.cond(young), isFalse, reason: '${s.id} ${young.year}年');
        }
      }
    }
    expect(peaceTime(young), isFalse);
  });

  test('泰平の岐路は一六〇一年からだけ出て、身分・前の段の旗に合う人にだけ出る（匂わせがあり、数字が無い）', () {
    _seenChoices.clear();
    final seen = <String, int>{};
    var lives = 0, reached = 0, withScene = 0, warAfter = 0;
    for (var seed = 0; seed < 4200 && lives < 900; seed++) {
      final g = _lateBorn(seed * 5 + 2);
      if (g == null) continue;
      lives++;
      _shape(g, seed);
      final r = Rng(seed);
      final ids = _play(
        g,
        (g, p) => _pickCareful(g, p, r),
        onPrompt: (g, p) {
          // 史実どおりの世の戦の絶えた年には、出陣の岐路も「戦に備える」も出ない。
          if (peaceTime(g) && g.l.rank < 8) {
            if (p.title == '出陣' || p.title == '初陣') warAfter++;
            if (p.title == 'この年の心がけ') {
              expect(p.choices.any((c) => c.label == '戦に備える'), isFalse);
            }
          }
        },
      );
      if (g.year >= kPeaceFrom) reached++;
      if (ids.isNotEmpty) withScene++;
      for (final id in ids) {
        seen[id] = (seen[id] ?? 0) + 1;
      }
    }
    // ignore: avoid_print
    print(
      '【泰平の岐路】$lives人生（一六〇一年に届いた $reached・岐路に出会った $withScene）: '
      '${seen.length}種 ${(seen.entries.toList()..sort((a, b) => b.value - a.value)).map((e) => '${e.key.substring(3)} ${e.value}').join('・')}',
    );
    expect(warAfter, 0);
    expect(reached, greaterThan(150));
    expect(seen.length, greaterThanOrEqualTo(22));
    expect(withScene / reached, greaterThan(.6));
    for (final e in _seenChoices.entries) {
      expect(e.value.length, inInclusiveRange(2, 4), reason: e.key);
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key} ${c.label}');
        expect(c.hint!.length, greaterThan(5), reason: c.label);
        expect(_digits.hasMatch(c.label), isFalse, reason: c.label);
        expect(_digits.hasMatch(c.hint!), isFalse, reason: c.hint);
      }
    }
  });

  test('ふつうの人生では、泰平の岐路は一六〇一年より前に出ず、歴史が変わった世に徳川の世の岐路は出ない', () {
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 9000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      if (seed % 5 == 0 && !g.finished) g.setFlag('history_sekigahara');
      if (seed % 5 == 1 && !g.finished) g.setFlag('history_honnoji');
      final r = Rng(seed);
      _play(
        g,
        (g, p) => seed.isEven ? r.range(0, p.choices.length - 1) : _pickCareful(g, p, r),
      );
    }
  });

  test('泰平の世で亡くなった人に手書きの最期が付き、乱世を生き抜いた最期は一六〇一年からの穏やかな死にだけ出る', () {
    final byId = {for (final e in kHandEndings) e.id: e};
    expect(byId.length, kHandEndings.length); // id は重複しない
    final eraIds = {
      for (final e in kHandEndings)
        if (e.kinds != null && e.kinds!.contains('era')) e.id,
    };
    expect(eraIds.length, greaterThan(100));
    expect(eraIds.containsAll(kEraUntil.keys), isTrue);
    final taihei = {
      for (final e in kHandEndings)
        if (e.id.contains('_taihei')) e.id,
    };
    expect(taihei.length, greaterThanOrEqualTo(14));
    // 泰平の受け皿は、幼くして以外の九つの道にある。
    expect(
      {for (final id in taihei) byId[id]!.way},
      kWays.keys.where((w) => w != 'young').toSet(),
    );

    var late = 0, viaEra = 0, viaTaihei = 0;
    final gotEra = <String>{}, gotTaihei = <String>{};
    for (var seed = 0; seed < 5000 && late < 700; seed++) {
      final g = _lateBorn(seed * 7 + 3);
      if (g == null) continue;
      _shape(g, seed);
      final r = Rng(seed);
      _play(g, (g, p) => _pickCareful(g, p, r));
      final e = buildEnding(g);
      expect(e.handId, isNotNull, reason: '${e.way}/${e.kind} ${g.year}年');
      expect(e.title, isNotEmpty);
      expect(e.text, isNot(contains('{')));
      expect(e.text, isNot(contains('null')));
      expect(e.kind, isNot('era'));
      final def = byId[e.handId]!;
      if (eraIds.contains(def.id) && !def.kinds!.contains(e.kind)) {
        // era の最期は、一六〇一年からの世に天寿か病で亡くなった人にだけ。文に合う年までに限る。
        expect(g.year, greaterThanOrEqualTo(1601), reason: def.id);
        expect(['tenju', 'byo'], contains(e.kind), reason: def.id);
        expect(
          g.year,
          lessThanOrEqualTo(kEraUntil[def.id] ?? kEraUntilDefault),
          reason: def.id,
        );
        expect(e.text, contains('それからほどなく、'), reason: def.id);
        viaEra++;
        gotEra.add(def.id);
      }
      if (taihei.contains(def.id)) {
        expect(g.year, greaterThanOrEqualTo(1601), reason: def.id);
        viaTaihei++;
        gotTaihei.add(def.id);
      }
      if (g.year < 1601) {
        expect(eraIds.contains(def.id) && !def.kinds!.contains(e.kind), isFalse);
        expect(taihei.contains(def.id), isFalse);
      } else {
        late++;
      }
    }
    // ignore: avoid_print
    print(
      '【泰平の最期】一六〇一年からの世で終わった $late人生: 乱世を生き抜いた最期 $viaEra（${gotEra.length}種）'
      '・泰平の受け皿と筋の最期 $viaTaihei（${gotTaihei.length}種）',
    );
    expect(late, greaterThan(200));
    expect(viaEra, greaterThan(10));
    expect(gotEra.length, greaterThanOrEqualTo(8));
    expect(viaTaihei, greaterThan(10));
    expect(gotTaihei.length, greaterThanOrEqualTo(5));
  });

  test('古い保存（一六〇一年で終わった人生）の最期も、これまでどおり読める', () {
    Game? g;
    for (var s = 0; g == null; s++) {
      g = _lateBorn(s);
    }
    final r = Rng(5);
    while (!g.finished && g.year < 1601) {
      g.choose(_pickCareful(g, g.prompt!, r));
    }
    if (g.finished) return;
    g.l.end = 'era';
    final e = buildEnding(g);
    expect(e.kind, 'era');
    expect(e.handId, isNotNull);
    expect(e.text, isNot(contains('それからほどなく、')));
    expect(e.kindName, '乱世を生き抜く');
  });
}
