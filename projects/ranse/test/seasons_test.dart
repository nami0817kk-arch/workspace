import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/seasons.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出た岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  final child = id.startsWith('sn_c_');
  expect(g.isChild, child, reason: '$id が${g.age}歳に出た');
  final who = kSeasonWho[id];
  if (who != null) {
    expect(who(g), isTrue, reason: '$id が出てはいけない人に出た（${g.rankName()}・位${g.l.rank}・${g.l.cls.id}）');
  }
  if (id == 'sn_nenga' || id == 'sn_yabusame' || id == 'sn_toro') {
    expect(g.l.rank, inInclusiveRange(1, 7), reason: id);
  }
  if (id == 'sn_c_hina' || id == 'sn_tanabata') expect(g.l.female, isTrue, reason: id);
  if (id == 'sn_c_shobu' || id == 'sn_inji') expect(g.l.female, isFalse, reason: id);
  final prev = kSeasonPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kSeasonGap[id]!;
    expect(snSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
  }
}

class _Run {
  final ids = <String>[];
}

/// 人生の終わりまで進める。新しく出た `sn_` の岐路（年越しは回数ぶん）を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 4000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:sn_')).toSet();
  var toshi = 0;
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:sn_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.ids.add(id);
      _checkAtPrompt(g, id);
      _seenChoices[id] = p!.choices;
    }
    known = now;
    final t = g.l.flags.where((f) => f.startsWith('sn_toshi_n:')).toList();
    final tn = t.isEmpty ? 0 : int.parse(t.first.substring(11));
    if (tn > toshi && tn > 1) out.ids.add('sn_toshikoshi');
    toshi = tn;
    g.choose(pick(g, p!));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
  return out;
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

/// 一生に一度の岐路（史実・季節を除く）の数。押しのけ具合を測るため。
int _others(Game g) => g.l.flags
    .where((f) => f.startsWith('scene:') && !f.startsWith('scene:sn_'))
    .length;

void main() {
  test('場面の表: 三十前後・id はすべて一度ずつ登録され、季節と筋の表の id も実在する', () {
    final all = [...kSeasonIds, ...kSeasonChildIds];
    expect(all.length, inInclusiveRange(28, 36));
    expect(all.toSet().length, all.length);
    final g = Game(rng: Rng(1));
    final adult = g.adultScenes.map((s) => s.id).toList();
    final child = g.childScenes.map((s) => s.id).toList();
    for (final id in kSeasonIds) {
      expect(adult.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('sn_') && !id.startsWith('sn_c_'), isTrue, reason: id);
    }
    for (final id in kSeasonChildIds) {
      expect(child.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('sn_c_'), isTrue, reason: id);
    }
    expect(adult.where(isSeasonScene).length, kSeasonIds.length);
    expect(child.where(isSeasonScene).length, kSeasonChildIds.length);
    for (final id in all) {
      expect(kSeasonOf[id], inInclusiveRange(0, 3), reason: id);
    }
    for (final id in [...kSeasonPrev.keys, ...kSeasonWho.keys, ...kSeasonRepeatIds]) {
      expect(kSeasonIds.contains(id), isTrue, reason: id);
    }
    for (final id in kSeasonGap.keys) {
      expect(kSeasonPrev.containsKey(id), isTrue, reason: id);
    }
    expect(kSeasonPrev.length, greaterThanOrEqualTo(3));
    // 年越しだけが何度でも出る。
    for (final s in g.adultScenes.where((s) => isSeasonScene(s.id))) {
      expect(s.repeat, kSeasonRepeatIds.contains(s.id), reason: s.id);
      expect(s.onlyForced, isFalse, reason: s.id);
    }
  });

  /// 三十歳の男。[cls] の家に生まれた人。
  Game man(String cls) {
    for (var s = 0;; s++) {
      final rng = Rng(s + 300);
      final x = Game(rng: rng);
      final b = rollBirth(rng);
      if (b.female || b.startYear > 1550 || b.cls.id != cls) continue;
      x.start(b);
      if (x.finished) continue;
      x.prompt = null;
      x.l.t = 30 * 2;
      x.l
        ..rank = 0
        ..lord = null
        ..married = false;
      x.l.flags.remove('priesthood');
      x.l.flags.remove('retired');
      x.l.flags.remove('way_merchant');
      x.l.flags.remove('way_outlaw');
      return x;
    }
  }

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る', () {
    final g = man('lowsamurai');
    final home = (g.fa[g.l.home]?.alive ?? false) ? g.l.home : g.alive.first.name;
    g.l
      ..rank = 3
      ..maxRank = 3
      ..lord = home;
    final allPrev = kSeasonPrev.values.expand((v) => v).toSet();
    for (final e in kSeasonPrev.entries) {
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      for (final f in allPrev) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('sn_at:'));
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      final gap = kSeasonGap[e.key]!;
      g.setFlag(e.value.first);
      g.setFlag('sn_at:${gap.$1}:${g.year}');
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      g.l.flags.removeWhere((f) => f.startsWith('sn_at:'));
      g.setFlag('sn_at:${gap.$1}:${g.year - gap.$2}');
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
    }
    // 身分の書き分け: 武家の行事は百姓に、百姓の行事は武家に出ない。
    final nenga = g.adultScenes.firstWhere((x) => x.id == 'sn_nenga');
    final mushi = g.adultScenes.firstWhere((x) => x.id == 'sn_mushiokuri');
    final tanagyo = g.adultScenes.firstWhere((x) => x.id == 'sn_tanagyo');
    expect(nenga.cond(g), isTrue);
    expect(mushi.cond(g), isFalse);
    expect(tanagyo.cond(g), isFalse);
    final f = man('farmer');
    expect(nenga.cond(f), isFalse);
    expect(mushi.cond(f), isTrue);
    f.setFlag('priesthood');
    expect(tanagyo.cond(f), isTrue);
    expect(mushi.cond(f), isFalse);
  });

  test('ふつうの人生を流しても例外がなく、成人に平均二つ以上・子ども時代に一つ以上出て、身分の書き分けと筋が合う', () {
    var adults = 0, adultTotal = 0, adultAny = 0;
    var kids = 0, kidTotal = 0, kidAny = 0, died = 0;
    var bushiNenga = 0, farmerMushi = 0;
    final kinds = <String, int>{};
    for (var seed = 0; seed < 800; seed++) {
      final rng = Rng(seed + 61000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 71000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      final childIds = run.ids.where((x) => x.startsWith('sn_c_')).toList();
      final adultIds = run.ids.where((x) => !x.startsWith('sn_c_')).toList();
      for (final id in run.ids) {
        kinds[id] = (kinds[id] ?? 0) + 1;
      }
      if (g.age >= 15) {
        kids++;
        kidTotal += childIds.length;
        if (childIds.isNotEmpty) kidAny++;
      }
      if (g.age >= 20) {
        adults++;
        adultTotal += adultIds.length;
        if (adultIds.isNotEmpty) adultAny++;
      }
      if ((g.l.dead ?? '').contains('印地打ち')) died++;
      if (adultIds.contains('sn_nenga')) bushiNenga++;
      if (adultIds.contains('sn_mushiokuri')) farmerMushi++;
    }
    final aAvg = adultTotal / adults, kAvg = kidTotal / kids;
    final later = kinds.keys.where(kSeasonPrev.containsKey).toSet();
    // ignore: avoid_print
    print('【季節の岐路】二十歳を越えた$adults人生: 平均${aAvg.toStringAsFixed(2)}・一つ以上 $adultAny／'
        '子ども時代を越えた$kids人生: 子どもの場面 平均${kAvg.toStringAsFixed(2)}・一つ以上 $kidAny／'
        '出た種類 ${kinds.length}/${kSeasonIds.length + kSeasonChildIds.length}・後段 ${later.length}・印地打ちで亡くなった $died・'
        '武家の年賀 $bushiNenga・百姓の虫送り $farmerMushi・'
        '出なかった ${{...kSeasonIds, ...kSeasonChildIds}.difference(kinds.keys.toSet())}・回数 $kinds');
    expect(adults, greaterThan(300));
    expect(aAvg, greaterThanOrEqualTo(2));
    expect(kAvg, greaterThanOrEqualTo(1));
    expect(kinds.length, greaterThanOrEqualTo(kSeasonIds.length + kSeasonChildIds.length - 4), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(3));
    expect(died / adults, lessThan(.02));
  });

  test('大名に置いた人生では、国人の年賀が出る（出た瞬間に一国の主であることも確かめる）', () {
    final kinds = <String, int>{};
    var lords = 0;
    for (var seed = 0; seed < 200; seed++) {
      final rng = Rng(seed * 7 + 5100);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 5300);
      var n = 0;
      while (!g.finished && g.isChild && n++ < 200) {
        g.choose(r.range(0, g.prompt!.choices.length - 1));
      }
      if (g.finished) continue;
      g.choose(0);
      if (g.finished) continue;
      final home = (g.fa[g.l.home]?.alive ?? false) ? g.l.home : g.alive.first.name;
      g.l
        ..rank = 8
        ..maxRank = 8
        ..lord = home
        ..gold = 100;
      g.l.flags.remove('priesthood');
      g.l.flags.remove('way_merchant');
      g.l.flags.remove('way_outlaw');
      lords++;
      final run = _play(g, (g, p) => pickAmbitious(g, p, r));
      for (final id in run.ids) {
        kinds[id] = (kinds[id] ?? 0) + 1;
      }
    }
    // ignore: avoid_print
    print('【季節の岐路・大名】$lords人生: $kinds');
    // 出た瞬間の身分は `_checkAtPrompt` が確かめている（家が滅んで身分を失ったあとは、その身分の行事が出うる）。
    expect(kinds['sn_lord_nenga'] ?? 0, greaterThan(10));
    expect(kinds['sn_nenga'] ?? 0, lessThan(kinds['sn_lord_nenga']!));
  });

  test('ほかの岐路を押しのけない: 季節の岐路を外した Game と比べ、ほかの一生に一度の岐路の平均がほとんど変わらない', () {
    (double, int) measure(bool without) {
      var total = 0, n = 0;
      for (var seed = 0; seed < 600; seed++) {
        final rng = Rng(seed + 83000);
        final g = Game(rng: rng);
        if (without) {
          g.adultScenes.removeWhere((s) => isSeasonScene(s.id));
          g.childScenes.removeWhere((s) => isSeasonScene(s.id));
        }
        g.start(rollBirth(rng));
        final r = Rng(seed + 93000);
        _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
        if (g.age < 20) continue;
        n++;
        total += _others(g);
      }
      return (total / n, n);
    }

    final (b, nb) = measure(true);
    final (a, na) = measure(false);
    // ignore: avoid_print
    print('【季節の岐路の押しのけ】二十歳を越えた人生の、ほかの一生に一度の岐路 足す前 ${b.toStringAsFixed(2)}（$nb人生）→ '
        '足した後 ${a.toStringAsFixed(2)}（$na人生）');
    expect(a, greaterThan(b * .95));
  });

  test('出た岐路の選択肢には匂わせがあり、ラベルにも匂わせにも数字が無い', () {
    expect(_seenChoices.length, greaterThanOrEqualTo(24), reason: '${_seenChoices.keys}');
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

  test('遺されたもの: 季節の旗を立てると、その行が出る（子ども向けの行は子どもにも）', () {
    const flags = [
      'sn_odori_wed',
      'sn_tsuki_kept',
      'sn_yabu_master',
      'sn_toro_foe',
      'sn_tanagyo_poor',
      'sn_susu_reunited',
      'sn_wish_kept',
      'sn_c_kakizome_praised',
      'sn_c_lost_helped',
      'sn_c_inoko_shared',
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
      final child = f.startsWith('sn_c_');
      g.l.t = (child ? 10 : 45) * 2;
      g.l.flags.clear();
      g.l.people.clear();
      g.l.focus.clear();
      g.l.kids = 0;
      g.setFlag(f);
      expect(rememberedEntries(g).map((r) => r.id), contains(f), reason: f);
      for (final s in remembrances(g)) {
        expect(_digits.hasMatch(s), isFalse, reason: s);
      }
    }
  });
}
