import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/daimyo_life.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出た岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// この岐路で亡くなった数（死因の文で見分ける）。
const _newDeaths = [
  '川の見回りに出て足をすくわれ',
  '火を止めようと馬を出し',
  '寺を壊させた恨みを抱く僧',
  '寝返らせた敵の将を遠ざけたのち',
  '隠居させた叔父の屋敷を一人で訪ね',
  '都の宿所で町衆の年寄たち',
  '侮る重臣たちの屋敷を見舞いに',
];

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(dmLife(g), isTrue, reason: '$id が大名でない人に出た（${g.rankName()}・位${g.l.rank}）');
  expect(g.l.rank, 8, reason: id);
  if (kDaimyoNearIds.contains(id)) {
    expect(g.share, greaterThanOrEqualTo(.3), reason: '$id が天下に手の届かない大名に出た');
  }
  if (kDaimyoWomanIds.contains(id)) expect(g.l.female, isTrue, reason: '$id が男に出た');
  if (id == 'dm_w_genpuku') {
    expect(dmRegent(g), isTrue, reason: id);
    expect(g.l.hasKidAged(g.year, 14, 20), isTrue, reason: id);
  }
  if (id == 'dm_senrei') expect(g.year, inInclusiveRange(1550, 1600), reason: id);
  final prev = kDaimyoPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kDaimyoGap[id];
    if (gap != null) {
      expect(dmSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
    }
  }
}

class _Run {
  final ids = <String>[];
  var years = 0;
}

/// 人生の終わりまで進める。新しく出た `dm_` の岐路と、位八で迎えた年の数を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:dm_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    if (p!.title == 'この年の心がけ' && !g.isChild && dmLife(g)) out.years++;
    final now = g.l.flags.where((f) => f.startsWith('scene:dm_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.ids.add(id);
      _checkAtPrompt(g, id);
      _seenChoices[id] = p.choices;
    }
    known = now;
    g.choose(pick(g, p));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
  return out;
}

/// 元服・裳着を済ませた人生。生き延びなければ null。
Game? _grownUp(int seed) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  g.start(rollBirth(rng));
  if (g.finished) return null;
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  if (g.finished) return null;
  g.choose(0); // 元服・裳着
  if (g.finished) return null;
  return g;
}

/// 自分の国の家（滅んでいれば近い家）の当主にする。
void _rule(Game g) {
  final l = g.l;
  final home = (g.fa[l.home]?.alive ?? false)
      ? l.home
      : nearest(g.alive, (f) => f.name, region: l.region, n: 1).first.name;
  l
    ..rank = 8
    ..maxRank = 8
    ..lord = home
    ..gold = 100
    ..troops = 0
    ..ronin = false;
  l.flags.remove('way_merchant');
  l.flags.remove('way_outlaw');
  l.flags.remove('priesthood');
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

/// `engine_test.dart` の【天下】と同じ遊び方で、大名から始めた人生の天下統一を数える。
/// [without] なら `dm_` の岐路を外した Game で測る（足す前と比べるため）。
(int, int) _tenka(int lives, {required bool without, int base = 31337}) {
  var n = 0, victory = 0;
  for (var seed = 0; seed < lives; seed++) {
    final rng = Rng(seed + base);
    final g = Game(rng: rng);
    if (without) g.adultScenes.removeWhere((s) => s.id.startsWith('dm_'));
    g.start(rollBirth(rng));
    playChildhood(g, Rng(seed));
    if (g.finished) continue;
    g.choose(0);
    if (g.finished) continue;
    final home = g.fa[g.l.home]!.alive ? g.l.home : g.alive.first.name;
    g.l
      ..rank = 8
      ..maxRank = 8
      ..lord = home
      ..gold = 100;
    final rest = g.prompt!.choices.indexWhere((c) => c.label.contains('休'));
    g.choose(rest < 0 ? g.prompt!.choices.length - 1 : rest);
    n++;
    var k = 0;
    final r = Rng(seed);
    while (!g.finished && k++ < 3000) {
      final p = g.prompt!;
      var i = -1;
      if (p.title == 'この年の心がけ') {
        i = p.choices.indexWhere((c) => c.label == '版図を広げる');
        if (g.l.gold < 30 || r.chance(.25)) {
          i = p.choices.indexWhere((c) => c.label == '軍備を整える');
        }
        if (g.l.hp < g.l.maxhp * .4) {
          i = p.choices.indexWhere((c) => c.label.contains('休') || c.label.contains('家族'));
        }
      } else if (p.title == '侵攻') {
        i = 0;
      }
      if (i < 0) i = pickAmbitious(g, p, r);
      g.choose(i);
    }
    if (g.l.victory) victory++;
  }
  return (n, victory);
}

/// 幼少期をランダムに遊ぶ（`engine_test.dart` と同じ）。
void playChildhood(Game g, Rng r) {
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
}

void main() {
  test('場面の表: 三十前後・id はすべて一度ずつ登録されている・筋の表の id も実在する', () {
    expect(kDaimyoLifeIds.length, inInclusiveRange(26, 36));
    expect(kDaimyoLifeIds.toSet().length, kDaimyoLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kDaimyoLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('dm_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('dm_')).length, kDaimyoLifeIds.length);
    for (final id in [...kDaimyoPrev.keys, ...kDaimyoNearIds, ...kDaimyoWomanIds]) {
      expect(kDaimyoLifeIds.contains(id), isTrue, reason: id);
    }
    for (final id in kDaimyoGap.keys) {
      expect(kDaimyoPrev.containsKey(id), isTrue, reason: id);
    }
    expect(kDaimyoPrev.length, greaterThanOrEqualTo(5));
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る。位七以下・隠居には出ない', () {
    Game pick(bool female) {
      for (var s = 0;; s++) {
        final rng = Rng(s + 900);
        final x = Game(rng: rng);
        final b = rollBirth(rng);
        if (b.startYear > 1550 || b.female != female) continue;
        x.start(b);
        if (x.finished) continue;
        x.prompt = null;
        x.l.t = (1585 - x.l.startYear) * 2;
        _rule(x);
        return x;
      }
    }

    final man = pick(false), woman = pick(true);
    final allPrev = kDaimyoPrev.values.expand((v) => v).toSet();
    void reset(Game g) {
      g.l.rank = 8;
      for (final f in allPrev) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('dm_at:'));
      // 天下に手が届く者の段も確かめられるように、自分の家を大きくしておく。
      g.fa[g.l.lord]!.power = 2000;
    }

    for (final e in kDaimyoPrev.entries) {
      final g = kDaimyoWomanIds.contains(e.key) ? woman : man;
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      reset(g);
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      final gap = kDaimyoGap[e.key]!;
      g.setFlag(e.value.first);
      g.setFlag('dm_at:${gap.$1}:${g.year}');
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      g.l.flags.removeWhere((f) => f.startsWith('dm_at:'));
      g.setFlag('dm_at:${gap.$1}:${g.year - gap.$2}');
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      for (final r in [0, 1, 3, 5, 6, 7]) {
        g.l.rank = r;
        expect(s.cond(g), isFalse, reason: '${e.key}: 位$r');
      }
      g.l.rank = 8;
      g.setFlag('retired');
      expect(s.cond(g), isFalse, reason: '${e.key}: 隠居');
      g.l.flags.remove('retired');
    }

    // 天下の岐路は勢力の割合が三割に届かなければ出ない。女の当主の岐路は男には出ない。
    reset(man);
    reset(woman);
    for (final id in kDaimyoNearIds.where((x) => !kDaimyoPrev.containsKey(x))) {
      final s = man.adultScenes.firstWhere((x) => x.id == id);
      expect(s.cond(man), isTrue, reason: '$id: 大きな家');
      man.fa[man.l.lord]!.power = 3;
      expect(s.cond(man), isFalse, reason: '$id: 小さな家');
      man.fa[man.l.lord]!.power = 2000;
    }
    final w = woman.adultScenes.firstWhere((x) => x.id == 'dm_w_anadori');
    expect(w.cond(woman), isTrue);
    expect(w.cond(man), isFalse);
    // 後見の元服は、後見に立った人で、十四〜二十の子がいるときだけ。
    final gp = woman.adultScenes.firstWhere((x) => x.id == 'dm_w_genpuku');
    woman.l.kids = 1;
    woman.l.kidYears
      ..clear()
      ..add(woman.year - 15);
    expect(gp.cond(woman), isFalse, reason: '後見でない');
    woman.mark('幼い当主の後見として、一国の政を担った');
    expect(gp.cond(woman), isTrue, reason: '後見');
    woman.l.kidYears
      ..clear()
      ..add(woman.year - 5);
    expect(gp.cond(woman), isFalse, reason: '子が幼い');
  });

  test('大名の人生を流しても例外がなく、位八の年がある成人に平均二つ以上出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, died = 0, years = 0;
    var women = 0, womenTotal = 0;
    final kinds = <String, int>{};
    for (var seed = 0; seed < 600; seed++) {
      final g = _grownUp(seed * 13 + 71);
      if (g == null) continue;
      final r = Rng(seed + 2900);
      _rule(g);
      if (g.l.female && seed % 3 == 0) {
        // 三人に一人の女性は、幼い当主の後見に立った人として置く。
        g.mark('幼い当主の後見として、一国の政を担った');
        g.l.married = false;
        g.l.addKid(g.year - 6);
      }
      final run = _play(g, (g, p) => seed.isEven ? pickAmbitious(g, p, r) : _randomPick(r, p));
      if (g.age < 20 || run.years == 0) continue;
      adults++;
      years += run.years;
      total += run.ids.length;
      if (g.l.female) {
        women++;
        womenTotal += run.ids.length;
      }
      if (run.ids.isNotEmpty) withAny++;
      for (final id in run.ids) {
        kinds[id] = (kinds[id] ?? 0) + 1;
      }
      if (_newDeaths.any((d) => (g.l.dead ?? '').contains(d))) died++;
    }
    final avg = total / adults;
    final later = kinds.keys.where(kDaimyoPrev.containsKey).toSet();
    // ignore: avoid_print
    print('【大名の岐路】位八の年があって二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        'その年 平均${(years / adults).toStringAsFixed(1)}・一つ以上 $withAny・女性 $women人生 平均${(womenTotal / (women == 0 ? 1 : women)).toStringAsFixed(2)}・'
        '出た種類 ${kinds.length}/${kDaimyoLifeIds.length}・後段 ${later.length}・新しい岐路で亡くなった $died・'
        '出なかった ${kDaimyoLifeIds.toSet().difference(kinds.keys.toSet())}・回数 $kinds');
    expect(adults, greaterThan(250));
    expect(avg, greaterThanOrEqualTo(2));
    expect(kinds.length, greaterThanOrEqualTo(kDaimyoLifeIds.length - 3), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(7));
    expect(died / adults, lessThan(.05));
  });

  test('位八に届かない人には出ない（ふつうの人生）', () {
    var never = 0;
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 47000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 57000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      if (g.l.maxRank < 8) {
        never++;
        expect(run.ids, isEmpty, reason: '位八に届かない人に ${run.ids}');
      }
    }
    expect(never, greaterThan(400));
  });

  test('出た岐路の選択肢には匂わせがあり、ラベルにも匂わせにも数字が無い', () {
    expect(_seenChoices.length, greaterThanOrEqualTo(22), reason: '${_seenChoices.keys}');
    for (final e in _seenChoices.entries) {
      expect(e.value.length, inInclusiveRange(2, 4), reason: e.key);
      for (final c in e.value) {
        expect(c.hint, isNotNull, reason: '${e.key}: ${c.label}');
        expect(c.hint!.trim(), isNotEmpty);
        expect(_digits.hasMatch(c.label), isFalse, reason: '${e.key}: ${c.label}');
        expect(_digits.hasMatch(c.hint!), isFalse, reason: '${e.key}: ${c.hint}');
      }
    }
  });

  test('遺されたもの: 大名の筋の旗を立てると、その行が出る', () {
    const flags = [
      'dm_shinden_menjo',
      'dm_joka_plan_saved',
      'dm_tokusei_fair',
      'dm_chokumei',
      'dm_senrei_noslave',
      'dm_tori_raised',
      'dm_ichi_reconciled',
      'dm_t_buji',
      'dm_t_fumi_wrote',
      'dm_w_proved',
    ];
    for (final f in flags) {
      expect(kRemembrances.any((r) => r.id == f), isTrue, reason: f);
      Game? g;
      for (var s = 0; g == null; s++) {
        final rng = Rng(s + 77);
        final x = Game(rng: rng);
        x.start(rollBirth(rng));
        if (!x.finished) g = x;
      }
      g.l.t = 45 * 2;
      g.l.flags.clear();
      g.l.people.clear();
      g.l.focus.clear();
      g.l.kids = 0;
      g.setFlag(f);
      expect(rememberedEntries(g).map((r) => r.id), contains(f), reason: f);
    }
  });

  test('天下統一の届きやすさ: 大名から始めた人生で、足す前と大きく変わらない', () {
    final (n0, v0) = _tenka(300, without: true);
    final (n1, v1) = _tenka(300, without: false);
    final p0 = v0 / n0, p1 = v1 / n1;
    // ignore: avoid_print
    print('【大名の岐路と天下】大名から始めた人生 足す前 $v0/$n0（${(p0 * 100).toStringAsFixed(1)}%）・'
        '足した後 $v1/$n1（${(p1 * 100).toStringAsFixed(1)}%）');
    // 同じ種でも乱数の流れが変わるので、揺れの分だけ幅を取る（目安は五分の差以内）。
    expect((p1 - p0).abs(), lessThan(.12));
  });
}
