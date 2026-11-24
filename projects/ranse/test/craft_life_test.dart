import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/craft_life.dart';
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
  '浅瀬の鯨に銛を打ちに',
  '海の衆に加わって沖の戦に出',
  '手負いの熊を追って奥山へ',
  '疫病の骸を運ぶうちに',
  '逃げ遅れた子を抱えたまま煙に',
];

/// 岐路が出た瞬間に、出てよい人・前の段の旗と間を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(crFits(g, id), isTrue, reason: '$id が${crKindOf(id)}でない人に出た（${g.l.cls.id}・${g.rankName()}・${g.l.region}）');
  expect(g.l.rank, 0, reason: '$id が身分のある人に出た');
  final prev = kCraftPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kCraftGap[id]!;
    expect(crSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
  }
}

/// 生業 → その生業の人か。
const _who = <String, bool Function(Game g)>{
  'sea': crSea,
  'mountain': crMountain,
  'artisan': crArtisan,
  'kawara': crKawara,
  'town': crTown,
};

class _Run {
  final ids = <String>[];

  /// 生業ごとに、その生業で迎えた大人の年の数。
  final years = <String, int>{};
}

/// 人生の終わりまで進める。新しく出た `cr_` の岐路と、生業ごとの年の数を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:cr_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    if (p!.title == 'この年の心がけ' && !g.isChild) {
      for (final e in _who.entries) {
        if (e.value(g)) out.years[e.key] = (out.years[e.key] ?? 0) + 1;
      }
    }
    final now = g.l.flags.where((f) => f.startsWith('scene:cr_')).toSet();
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

/// 身分を [cls] に置き換えた生まれ。
Birth _asClass(Birth b, String cls) {
  final c = classById(cls);
  return Birth(
    cls: c,
    region: b.region,
    faction: b.faction,
    startYear: b.startYear,
    month: b.month,
    day: b.day,
    female: b.female,
    order: b.order,
    stats: b.stats,
    traits: b.traits,
    rarity: b.rarity,
    name: b.name,
    label: clsLabel(c, b.female, b.order),
    sameClass: b.sameClass,
    birthRank: calcBirthRank(c, b.female, b.order),
  );
}

/// 身分を [cls] にして元服の手前まで進めた人生。生き延びなければ null。
Game? _grownUp(int seed, String cls) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  g.start(_asClass(rollBirth(rng), cls));
  if (g.finished) return null;
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  if (g.finished) return null;
  return g;
}

/// 病に伏したら「病を養う」を選ぶ（人が遊ぶ形。2026-11-24 に病の前触れを入れてから、
/// 養わずに押して務めると多くが亡くなり、生業の年が縮んで平均が線を割った）。
int _randomPick(Rng r, Prompt p) {
  final y = p.choices.indexWhere((c) => c.label == '病を養う');
  return y >= 0 ? y : r.range(0, p.choices.length - 1);
}

/// 生業に留まる選び方: 重点では仕官・奉公を探さず、岐路は無作為。
int _stayPick(Game g, Prompt p, Rng r) {
  if (p.title == 'この年の心がけ') {
    final y = p.choices.indexWhere((c) => c.label == '病を養う');
    if (y >= 0) return y;
    final ok = [
      for (var i = 0; i < p.choices.length; i++)
        if (!p.choices[i].label.contains('仕官') && !p.choices[i].label.contains('奉公')) i,
    ];
    return ok[r.range(0, ok.length - 1)];
  }
  return _randomPick(r, p);
}

/// 生業ごとに置く身分と、元服で足す旗。
const _setups = <String, (List<String>, String?)>{
  'sea': (['fisher'], null),
  'mountain': (['fisher'], null),
  'artisan': (['farmer', 'merchant', 'fisher'], 'cr_craft'),
  'kawara': (['beggar'], null),
  'town': (['merchant'], null),
};

void main() {
  test('場面の表: 三十前後・id はすべて一度ずつ登録されている・筋の表の id も実在する', () {
    expect(kCraftLifeIds.length, inInclusiveRange(28, 36));
    expect(kCraftLifeIds.toSet().length, kCraftLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kCraftLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('cr_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('cr_')).length, kCraftLifeIds.length);
    for (final id in kCraftPrev.keys) {
      expect(kCraftLifeIds.contains(id), isTrue, reason: id);
      expect(kCraftGap.containsKey(id), isTrue, reason: id);
    }
    expect(kCraftGap.length, kCraftPrev.length);
    expect(kCraftPrev.length, greaterThanOrEqualTo(4));
    // 五つの生業すべてに筋がある。
    expect(kCraftPrev.keys.map(crKindOf).toSet(), {'sea', 'mountain', 'artisan', 'kawara', 'town'});
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る。身分のある人には出ない', () {
    Game pick(String kind) {
      final (classes, flag) = _setups[kind]!;
      for (var s = 0;; s++) {
        final rng = Rng(s + 900);
        final x = Game(rng: rng);
        x.start(_asClass(rollBirth(rng), classes[s % classes.length]));
        if (x.finished) continue;
        x.prompt = null;
        x.l.t = 40 * 2;
        if (flag != null) x.setFlag(flag);
        if (crLivelihood(x) == kind) return x;
      }
    }

    final games = {for (final k in _setups.keys) k: pick(k)};
    final allPrev = kCraftPrev.values.expand((v) => v).toSet();
    for (final e in kCraftPrev.entries) {
      final kind = crKindOf(e.key);
      final g = games[kind]!;
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      for (final f in allPrev) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('cr_at:'));
      if (kind == 'artisan') g.meet('職人の弟子', '与助', 50);
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      final gap = kCraftGap[e.key]!;
      g.setFlag(e.value.first);
      g.setFlag('cr_at:${gap.$1}:${g.year}');
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      g.l.flags.removeWhere((f) => f.startsWith('cr_at:'));
      g.setFlag('cr_at:${gap.$1}:${g.year - gap.$2}');
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      g.l.rank = 1;
      expect(s.cond(g), isFalse, reason: '${e.key}: 身分あり');
      g.l.rank = 0;
      g.setFlag('retired');
      expect(s.cond(g), isFalse, reason: '${e.key}: 隠居');
      g.l.flags.remove('retired');
      // ほかの生業の人には出ない。
      for (final o in games.entries) {
        if (o.key == kind) continue;
        if (kind == 'town' && o.key == 'artisan' && crTown(o.value)) continue;
        for (final f in e.value) {
          o.value.setFlag(f);
        }
        o.value.l.flags.removeWhere((f) => f.startsWith('cr_at:'));
        o.value.setFlag('cr_at:${gap.$1}:${o.value.year - gap.$2}');
        expect(s.cond(o.value), isFalse, reason: '${e.key}: ${o.key} の人');
      }
    }
  });

  test('生業ごとに数百の人生を流しても例外がなく、その生業で二十歳を越えた人に平均二つ以上、筋の後段も出る', () {
    final kinds = <String, int>{};
    var allAdults = 0, died = 0;
    final results = <String, (int, double)>{};
    for (final kind in _setups.keys) {
      final (classes, flag) = _setups[kind]!;
      var adults = 0, total = 0, withAny = 0, years = 0;
      for (var seed = 0; adults < 600 && seed < 6000; seed++) {
        final g = _grownUp(seed * 13 + 101 + kind.length * 7919, classes[seed % classes.length]);
        if (g == null) continue;
        if (flag != null) g.setFlag(flag);
        if (crLivelihood(g) != kind) continue;
        final r = Rng(seed + 4100);
        final run = _play(g, (g, p) => seed % 3 == 0 ? _randomPick(r, p) : _stayPick(g, p, r));
        final y = run.years[kind] ?? 0;
        if (g.age < 20 || y == 0) continue;
        adults++;
        years += y;
        final mine = run.ids.where((id) => crKindOf(id) == kind).toList();
        total += mine.length;
        if (mine.isNotEmpty) withAny++;
        for (final id in run.ids) {
          kinds[id] = (kinds[id] ?? 0) + 1;
        }
        if (_newDeaths.any((d) => (g.l.dead ?? '').contains(d))) died++;
      }
      allAdults += adults;
      final avg = total / adults;
      // ignore: avoid_print
      print('【庶民の生業 $kind】その生業で二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
          'その年 平均${(years / adults).toStringAsFixed(1)}・一つ以上 $withAny');
      results[kind] = (adults, avg);
    }
    final later = kinds.keys.where(kCraftPrev.containsKey).toSet();
    // ignore: avoid_print
    print('【庶民の生業】出た種類 ${kinds.length}/${kCraftLifeIds.length}・後段 ${later.length}・新しい岐路で亡くなった $died／$allAdults・'
        '出なかった ${kCraftLifeIds.toSet().difference(kinds.keys.toSet())}・回数 $kinds');
    for (final e in results.entries) {
      expect(e.value.$1, greaterThanOrEqualTo(200), reason: e.key);
      expect(e.value.$2, greaterThanOrEqualTo(2), reason: e.key);
    }
    expect(kinds.length, greaterThanOrEqualTo(kCraftLifeIds.length - 2), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(8));
    expect(died / allAdults, lessThan(.05));
  });

  test('ふつうの人生でも、出るのはその生業の人だけ（武家に生まれ身分を保った人には出ない）', () {
    var samurai = 0, seen = 0;
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 61000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 71000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      seen += run.ids.length;
      if (const ['ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'daimyo'].contains(g.l.cls.id) &&
          g.l.rank > 0 &&
          g.l.maxRank > 0) {
        samurai++;
        expect(run.ids.where((id) => !kCraftEntryIds.contains(id)), isEmpty, reason: '武家に ${run.ids}');
      }
    }
    // ignore: avoid_print
    print('【ふつうの人生の cr_】600人生で $seen（武家で身分を保った $samurai 人生には出ない）');
    expect(samurai, greaterThan(15));
  });

  test('出た岐路の選択肢には匂わせがあり、ラベルにも匂わせにも数字が無い', () {
    expect(_seenChoices.length, greaterThanOrEqualTo(25), reason: '${_seenChoices.keys}');
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

  test('遺されたもの: 庶民の生業の旗を立てると、その行が出る', () {
    const flags = [
      'cr_fune_own',
      'cr_nanpa_saved',
      'cr_ochudo_thanked',
      'cr_kurabe_won',
      'cr_deshi_sent',
      'cr_mei_cut',
      'cr_niwa_master',
      'cr_gei_named',
      'cr_ekibyo_buried',
      'cr_kaji_broke',
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
