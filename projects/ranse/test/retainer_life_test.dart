import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/retainer_life.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出た岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// この岐路で亡くなった数（死因の文で見分ける）。
const _newDeaths = [
  '秘め事を漏らしたと疑われ',
  '傅いた若君の脇を固めて',
  '宿直の夜、主君の寝所に忍び入った曲者と',
  '御台所の内々の文を携えて',
];

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(rtLife(g), isTrue, reason: '$id が位三〜四の仕える身でない人に出た（${g.rankName()}・位${g.l.rank}）');
  expect(g.l.rank, inInclusiveRange(3, 4), reason: id);
  if (id.startsWith('rt_o_')) {
    expect(rtOku(g), isTrue, reason: '$id が奥で仕える女性でない人に出た');
  } else if (!const ['rt_himitsu', 'rt_himitsu_test', 'rt_kongi', 'rt_sekiji'].contains(id)) {
    expect(rtSamurai(g), isTrue, reason: '$id が侍でない人に出た');
  }
  if (id == 'rt_konin') expect(g.l.married, isFalse);
  final prev = kRetainerPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kRetainerGap[id];
    if (gap != null) {
      expect(rtSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
    }
  }
}

class _Run {
  final ids = <String>[];
  var years = 0;
}

/// 人生の終わりまで進める。新しく出た `rt_` の岐路と、位三〜四で仕えて迎えた年の数を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:rt_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    if (p!.title == 'この年の心がけ' && !g.isChild && rtLife(g)) out.years++;
    final now = g.l.flags.where((f) => f.startsWith('scene:rt_')).toSet();
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

/// 元服・裳着の手前まで進めた人生。生き延びなければ null。
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
  return g;
}

/// 元服のあと、近くの家に位三（ときに四）で仕えさせる。
void _serve(Game g, int rank) {
  final l = g.l;
  final f = nearest(g.alive, (f) => f.name, region: l.region, n: 1).first;
  l.rank = rank;
  if (l.maxRank < rank) l.maxRank = rank;
  l.lord = f.name;
  l.fav = 35;
  l.troops = rank == 4 ? 20 : 5;
  l.ronin = false;
  l.flags.remove('way_merchant');
  l.flags.remove('way_outlaw');
  l.flags.remove('priesthood');
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

void main() {
  test('場面の表: 二十五前後・id はすべて一度ずつ登録されている・筋の表の id も実在する', () {
    expect(kRetainerLifeIds.length, inInclusiveRange(22, 30));
    expect(kRetainerLifeIds.toSet().length, kRetainerLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kRetainerLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('rt_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('rt_')).length, kRetainerLifeIds.length);
    for (final id in kRetainerPrev.keys) {
      expect(kRetainerLifeIds.contains(id), isTrue, reason: id);
    }
    for (final id in kRetainerGap.keys) {
      expect(kRetainerPrev.containsKey(id), isTrue, reason: id);
    }
    final chains = <String, int>{};
    for (final v in kRetainerGap.values) {
      chains[v.$1] = (chains[v.$1] ?? 0) + 1;
    }
    expect(chains.length, greaterThanOrEqualTo(4), reason: '$chains');
    expect(chains.values.where((n) => n >= 2).length, greaterThanOrEqualTo(3), reason: '$chains');
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る。ほかの位には出ない', () {
    Game pick(bool female) {
      for (var s = 0;; s++) {
        final rng = Rng(s + 600);
        final x = Game(rng: rng);
        final b = rollBirth(rng);
        if (b.startYear > 1560 || b.female != female) continue;
        x.start(b);
        if (x.finished) continue;
        x.prompt = null;
        x.l.t = (1580 - x.l.startYear) * 2;
        _serve(x, 3);
        x.l.married = false;
        return x;
      }
    }

    final man = pick(false), woman = pick(true);
    final allPrev = kRetainerPrev.values.expand((v) => v).toSet();
    void reset(Game g) {
      g.l.rank = 3;
      g.l.married = false;
      g.meet('傅いた若君', '鶴丸', 50);
      for (final f in allPrev) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('rt_at:'));
    }

    for (final e in kRetainerPrev.entries) {
      final oku = e.key.startsWith('rt_o_');
      final g = oku ? woman : man;
      final other = oku ? man : woman;
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      reset(g);
      reset(other);
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      final gap = kRetainerGap[e.key]!;
      for (final x in [g, other]) {
        x.setFlag(e.value.first);
        x.setFlag('rt_at:${gap.$1}:${x.year}');
      }
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      for (final x in [g, other]) {
        x.l.flags.removeWhere((f) => f.startsWith('rt_at:'));
        x.setFlag('rt_at:${gap.$1}:${x.year - gap.$2}');
      }
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      g.l.rank = 4;
      expect(s.cond(g), isTrue, reason: '${e.key}: 位四');
      for (final r in [0, 1, 2, 5, 6, 8]) {
        g.l.rank = r;
        expect(s.cond(g), isFalse, reason: '${e.key}: 位$r');
      }
      g.l.rank = 3;
      // 男女の取り違え（主君の秘め事は女性にも出る）・嫁いだ女性。
      if (e.key != 'rt_himitsu_test') {
        expect(s.cond(other), isFalse, reason: '${e.key}: ${oku ? '男' : '女性'}');
      }
      if (oku) {
        g.l.married = true;
        expect(s.cond(g), isFalse, reason: '${e.key}: 嫁いだ女性');
        g.l.married = false;
      }
    }
  });

  test('位三〜四に届く人生を流しても例外がなく、その年がある成人に平均二つ以上出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, died = 0, years = 0;
    var women = 0, womenTotal = 0;
    final kinds = <String, int>{};
    for (var seed = 0; seed < 900; seed++) {
      final g = _grownUp(seed * 7 + 31);
      if (g == null) continue;
      final r = Rng(seed + 900);
      // 三人に二人は元服で位を置き直し、残りは足軽から考えて選んで上がるのを待つ。
      if (seed % 3 != 2) {
        _serve(g, seed % 5 == 0 ? 4 : 3);
      } else {
        _serve(g, 1);
        g.l.troops = 0;
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
    final later = kinds.keys.where(kRetainerPrev.containsKey).toSet();
    // ignore: avoid_print
    print('【中堅の侍の岐路】位三〜四の年があって二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        'その年 平均${(years / adults).toStringAsFixed(1)}・一つ以上 $withAny・女性 $women人生 平均${(womenTotal / (women == 0 ? 1 : women)).toStringAsFixed(2)}・'
        '出た種類 ${kinds.length}/${kRetainerLifeIds.length}・後段 ${later.length}・新しい岐路で亡くなった $died・'
        '出なかった ${kRetainerLifeIds.toSet().difference(kinds.keys.toSet())}・回数 $kinds');
    expect(adults, greaterThan(250));
    expect(avg, greaterThanOrEqualTo(2));
    expect(kinds.length, greaterThanOrEqualTo(kRetainerLifeIds.length - 3), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(7));
    expect(died / adults, lessThan(.05));
  });

  test('位三〜四に届かない人・仏門には出ない（ふつうの人生）', () {
    var never = 0, withYears = 0, total = 0;
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 41000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 51000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      if (g.l.maxRank < 3) {
        never++;
        expect(run.ids, isEmpty, reason: '位三に届かない人に ${run.ids}');
      }
      if (run.years > 0 && g.age >= 20) {
        withYears++;
        total += run.ids.length;
      }
    }
    // ignore: avoid_print
    print('【ふつうの人生の rt_】位三〜四の年がある成人 $withYears 人生 平均${(total / (withYears == 0 ? 1 : withYears)).toStringAsFixed(2)}');
    expect(never, greaterThan(200));
  });

  test('出た岐路の選択肢には匂わせがあり、ラベルにも匂わせにも数字が無い', () {
    expect(_seenChoices.length, greaterThanOrEqualTo(20), reason: '${_seenChoices.keys}');
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

  test('遺されたもの: 中堅の侍と奥の筋の旗を立てると、その行が出る', () {
    const flags = [
      'rt_chohei_saved',
      'rt_confidant',
      'rt_mori_shielded',
      'rt_haika_handed',
      'rt_chigyo_levee',
      'rt_chigyo_heard',
      'rt_takagari_shielded',
      'rt_habatsu_mediated',
      'rt_o_tsukai_done',
      'rt_o_mediated',
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
}
