import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/ashigaru_life.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/ways.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出た岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// この岐路で亡くなった数（死因の文の頭で見分ける）。
const _newDeaths = [
  '兵糧をくすねた咎を問われ',
  '組頭に回された危うい物見の役目で',
  '同郷の若い者と抜け駆けして',
  '偽りの首を差し出した咎で',
  '陣に流行った腹の病を看取るうち',
  '負け戦から落ち延びる途中',
  '主家が滅んだのち、降った先の先手に立って',
];

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(alLife(g), isTrue, reason: '$id が足軽でない人に出た（${g.rankName()}・最高位${g.l.maxRank}）');
  expect(g.l.female, isFalse, reason: '$id が女性に出た');
  if (id == 'al_ronin') {
    expect(alFormer(g), isTrue);
  } else {
    expect(alServing(g), isTrue, reason: '$id が仕えていない人に出た');
  }
  final prev = kAshigaruPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kAshigaruGap[id];
    if (gap != null) {
      expect(alSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
    }
  }
  if (id == 'al_teppo') expect(g.year, greaterThanOrEqualTo(1550));
  if (id == 'al_teppo_teach') expect(g.year, greaterThanOrEqualTo(1576));
  if (id == 'al_onsho_ta') expect(g.year, lessThan(1590));
  if (id == 'al_toritate') expect(g.l.rank, 2);
  if (id == 'al_kumi_eye') expect(g.l.rank, 1);
}

class _Run {
  final ids = <String>[];
  var ashigaruYears = 0;
}

/// 人生の終わりまで進める。新しく出た `al_` の岐路と、足軽として迎えた年の数を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:al_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    if (p!.title == 'この年の心がけ' && !g.isChild && alServing(g)) out.ashigaruYears++;
    final now = g.l.flags.where((f) => f.startsWith('scene:al_')).toSet();
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

/// 元服の手前まで進めた男の人生。生き延びなければ null。
Game? _grownUpMan(int seed) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  final b = rollBirth(rng);
  if (b.female) return null;
  g.start(b);
  if (g.finished) return null;
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  if (g.finished) return null;
  return g;
}

/// 近くの家に足軽として仕えさせる（仕官と同じ形）。
void _enlist(Game g) {
  final l = g.l;
  final f = nearest(g.alive, (f) => f.name, region: l.region, n: 1).first;
  l.rank = 1;
  if (l.maxRank < 1) l.maxRank = 1;
  l.lord = f.name;
  l.fav = 20;
  l.ronin = false;
  l.flags.remove('way_merchant');
  l.flags.remove('way_outlaw');
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

/// 仕えている間は重点を無作為に選び（出陣の年も、静かな年もある）、岐路も無作為。
int _servePick(Game g, Prompt p, Rng r) => _randomPick(r, p);

void main() {
  test('場面の表: 二十五前後・id はすべて一度ずつ登録されている・筋の表の id も実在する', () {
    expect(kAshigaruLifeIds.length, inInclusiveRange(22, 30));
    expect(kAshigaruLifeIds.toSet().length, kAshigaruLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kAshigaruLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('al_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('al_')).length, kAshigaruLifeIds.length);
    for (final id in kAshigaruPrev.keys) {
      expect(kAshigaruLifeIds.contains(id), isTrue, reason: id);
    }
    for (final id in kAshigaruGap.keys) {
      expect(kAshigaruPrev.containsKey(id), isTrue, reason: id);
    }
    // 二段以上の後段を持つ筋が三本以上。
    final chains = <String, int>{};
    for (final v in kAshigaruGap.values) {
      chains[v.$1] = (chains[v.$1] ?? 0) + 1;
    }
    expect(chains.values.where((n) => n >= 2).length, greaterThanOrEqualTo(3), reason: '$chains');
    expect(chains.length, greaterThanOrEqualTo(4));
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る。身分のない人には出ない', () {
    Game? g;
    for (var s = 0; g == null; s++) {
      final rng = Rng(s + 600);
      final x = Game(rng: rng);
      final b = rollBirth(rng);
      if (b.female || b.startYear > 1560) continue;
      x.start(b);
      if (!x.finished) g = x;
    }
    g.prompt = null;
    g.l.t = (1580 - g.l.startYear) * 2;
    _enlist(g);
    g.l.gun = true;
    final allPrev = kAshigaruPrev.values.expand((v) => v).toSet();
    for (final e in kAshigaruPrev.entries) {
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      g.l.rank = 1;
      g.meet('古参の足軽', '与平', 50);
      g.meet('同郷の仲間', '与作', 50);
      for (final f in allPrev) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('al_at:'));
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      g.setFlag(e.value.first);
      final gap = kAshigaruGap[e.key];
      if (gap != null) {
        g.setFlag('al_at:${gap.$1}:${g.year}');
        expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
        g.l.flags.removeWhere((f) => f.startsWith('al_at:'));
        g.setFlag('al_at:${gap.$1}:${g.year - gap.$2}');
      }
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      // 身分のない人・女性には出ない。
      g.l.rank = 0;
      expect(s.cond(g), isFalse, reason: '${e.key}: 身分のない人');
      g.l.rank = 1;
    }
  });

  test('足軽の年を持つ人生を流しても例外がなく、足軽の年がある成人に平均二つ以上出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, died = 0, years = 0;
    final kinds = <String, int>{};
    for (var seed = 0; seed < 900; seed++) {
      final g = _grownUpMan(seed * 7 + 13);
      if (g == null) continue;
      _enlist(g);
      final r = Rng(seed + 900);
      final run = _play(g, (g, p) => seed % 3 == 0 ? pickAmbitious(g, p, r) : _servePick(g, p, r));
      if (g.age < 20 || run.ashigaruYears == 0) continue;
      adults++;
      years += run.ashigaruYears;
      total += run.ids.length;
      if (run.ids.isNotEmpty) withAny++;
      for (final id in run.ids) {
        kinds[id] = (kinds[id] ?? 0) + 1;
      }
      if (_newDeaths.any((d) => (g.l.dead ?? '').startsWith(d))) died++;
    }
    final avg = total / adults;
    final later = kinds.keys.where(kAshigaruPrev.containsKey).toSet();
    // ignore: avoid_print
    print('【足軽の岐路】足軽の年があって二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        '足軽の年 平均${(years / adults).toStringAsFixed(1)}・一つ以上 $withAny・'
        '出た種類 ${kinds.length}/${kAshigaruLifeIds.length}・後段 ${later.length}・新しい岐路で亡くなった $died・'
        '出なかった ${kAshigaruLifeIds.toSet().difference(kinds.keys.toSet())}・回数 $kinds');
    expect(adults, greaterThan(220));
    expect(avg, greaterThanOrEqualTo(2));
    expect(kinds.length, greaterThanOrEqualTo(kAshigaruLifeIds.length - 3), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(8));
    expect(died / adults, lessThan(.1));
  });

  test('足軽にならなかった人・女性には出ない（ふつうの人生）', () {
    var never = 0, withYears = 0, total = 0;
    final perWay = <String, List<int>>{};
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 40000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 50000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      if (g.l.female || g.l.maxRank == 0) {
        never++;
        expect(run.ids, isEmpty, reason: '足軽でない人に ${run.ids}');
      }
      if (run.ashigaruYears > 0 && g.age >= 20) {
        withYears++;
        total += run.ids.length;
      }
      if (g.age >= 20) perWay.putIfAbsent(lifeWay(g.l), () => []).add(run.ids.length);
    }
    // ignore: avoid_print
    print('【ふつうの人生の al_】足軽の年がある成人 $withYears 人生 平均${(total / (withYears == 0 ? 1 : withYears)).toStringAsFixed(2)}・'
        '道ごと ${{for (final e in perWay.entries) e.key: '${e.value.length}人生 平均${(e.value.fold<int>(0, (a, b) => a + b) / e.value.length).toStringAsFixed(2)}'}}');
    expect(never, greaterThan(100));
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

  test('遺されたもの: 足軽の筋の旗を立てると、その行が出る', () {
    const flags = [
      'al_toritate',
      'al_kumi_head',
      'al_went_home',
      'al_told_mother',
      'al_freed_captive',
      'al_ochi_remembered',
      'al_teppo_teacher',
      'al_kosan_passed',
      'al_kura_ban',
      'al_old_banner',
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
