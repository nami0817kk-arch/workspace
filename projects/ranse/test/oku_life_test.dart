import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/oku_life.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/retainer_life.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/ways.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出た岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// この岐路で亡くなった数（死因の文で見分ける）。
const _newDeaths = [
  '姫君の疱瘡の看病に詰めるうち',
  '囲まれた日に塀の上で薙刀を振るい',
  '囲みの破れる夜、姫君を逃がしたあと',
  '婚家の内情を実家へ漏らしたことが露見し',
  '預けられた屋敷を抜け出す夜に',
];

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(g.l.female, isTrue, reason: '$id が男に出た');
  expect(okLife(g), isTrue, reason: '$id が出てよくない人に出た（${g.rankName()}）');
  if (kOkuServingIds.contains(id)) {
    expect(okServing(g), isTrue, reason: '$id が奥で仕える女性でない人に出た（位${g.l.rank}・嫁ぎ${g.l.married}）');
  }
  if (kOkuWifeIds.contains(id)) {
    expect(okWife(g), isTrue, reason: '$id が武家に嫁いだ女性でない人に出た');
  }
  if (id == 'ok_goke' || id == 'ok_rakushoku') {
    expect(okWidow(g), isTrue, reason: '$id が後家でない人に出た');
  }
  final prev = kOkuPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kOkuGap[id];
    if (gap != null) {
      expect(okSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
    }
  }
}

class _Run {
  final ids = <String>[];
  final rt = <String>[];
}

/// 人生の終わりまで進める。新しく出た `ok_` と `rt_` の岐路を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:ok_') || f.startsWith('scene:rt_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:ok_') || f.startsWith('scene:rt_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      if (id.startsWith('rt_')) {
        out.rt.add(id);
        continue;
      }
      out.ids.add(id);
      _checkAtPrompt(g, id);
      _seenChoices[id] = p!.choices;
    }
    known = now;
    g.choose(pick(g, p!));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
  return out;
}

/// 女の子に生まれ、裳着の手前まで進めた人生。生き延びなければ null。
Game? _grownGirl(int seed) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  final b = rollBirth(rng);
  if (!b.female) return null;
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

/// 近くの家の奥に、位 [rank] で仕えさせる。
void _serve(Game g, int rank) {
  final l = g.l;
  final f = nearest(g.alive, (f) => f.name, region: l.region, n: 1).first;
  l.rank = rank;
  if (l.maxRank < rank) l.maxRank = rank;
  l.lord = f.name;
  l.fav = 35;
  l.troops = 0;
  l.ronin = false;
  l.flags.remove('way_merchant');
  l.flags.remove('way_outlaw');
  l.flags.remove('priesthood');
}

/// 武家に嫁がせる（位 [rank] で、主家は近くの家）。
void _wed(Game g, int rank) {
  _serve(g, rank);
  g.l.married = true;
  g.meet('伴侶', '中村家の${g.rng.pick(kGivenM)}', 50);
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

void main() {
  test('場面の表: 二十五前後・id はすべて一度ずつ登録されている・筋の表の id も実在する', () {
    expect(kOkuLifeIds.length, inInclusiveRange(22, 30));
    expect(kOkuLifeIds.toSet().length, kOkuLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kOkuLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('ok_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('ok_')).length, kOkuLifeIds.length);
    for (final id in [...kOkuPrev.keys, ...kOkuServingIds, ...kOkuWifeIds]) {
      expect(kOkuLifeIds.contains(id), isTrue, reason: id);
    }
    for (final id in kOkuGap.keys) {
      expect(kOkuPrev.containsKey(id), isTrue, reason: id);
    }
    expect(kOkuGap.length, kOkuPrev.length);
    final chains = <String>{for (final v in kOkuGap.values) v.$1};
    expect(chains.length, greaterThanOrEqualTo(4), reason: '$chains');
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る。男には出ない', () {
    Game pick(bool female) {
      for (var s = 0;; s++) {
        final rng = Rng(s + 700);
        final x = Game(rng: rng);
        final b = rollBirth(rng);
        if (b.startYear > 1540 || b.female != female) continue;
        x.start(b);
        if (x.finished) continue;
        x.prompt = null;
        x.l.t = (1585 - x.l.startYear) * 2;
        return x;
      }
    }

    final woman = pick(true), man = pick(false);
    final allPrev = kOkuPrev.values.expand((v) => v).toSet();
    void setup(Game g, String id) {
      final l = g.l;
      for (final f in allPrev) {
        l.flags.remove(f);
      }
      l.flags.removeWhere((f) => f.startsWith('ok_at:'));
      l.flags.remove('retired');
      l.people.remove('伴侶');
      l.kids = 0;
      l.kidYears.clear();
      _serve(g, 3);
      l.married = false;
      if (kOkuWifeIds.contains(id) || id == 'ok_kyoiku_after') {
        _wed(g, 3);
        if (id == 'ok_kyoiku_after') l.addKid(g.year - 15);
      } else if (id == 'ok_rakushoku') {
        g.meet('伴侶', '中村家の太郎', 50);
      }
    }

    for (final e in kOkuPrev.entries) {
      final s = woman.adultScenes.firstWhere((x) => x.id == e.key);
      final gap = kOkuGap[e.key]!;
      for (final g in [woman, man]) {
        setup(g, e.key);
        expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
        g.setFlag(e.value.first);
        g.setFlag('ok_at:${gap.$1}:${g.year}');
        expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
        g.l.flags.removeWhere((f) => f.startsWith('ok_at:'));
        g.setFlag('ok_at:${gap.$1}:${g.year - gap.$2}');
        expect(s.cond(g), g.l.female, reason: '${e.key}: 年が空いた（${g.l.female ? '女性' : '男'}）');
      }
      // 奥の段は嫁いだら出ない。嫁いだ女性の段は嫁いでいなければ出ない。
      if (kOkuServingIds.contains(e.key)) {
        woman.l.married = true;
        woman.meet('伴侶', '中村家の太郎', 50);
        expect(s.cond(woman), isFalse, reason: '${e.key}: 嫁いだ女性');
      }
      if (kOkuWifeIds.contains(e.key)) {
        woman.l.married = false;
        expect(s.cond(woman), isFalse, reason: '${e.key}: 嫁いでいない女性');
      }
    }
    // 男には、どの岐路の条件も偽。
    for (final id in kOkuLifeIds) {
      final s = man.adultScenes.firstWhere((x) => x.id == id);
      setup(man, id);
      for (final f in allPrev) {
        man.setFlag(f);
      }
      expect(s.cond(man), isFalse, reason: '$id が男に出る');
    }
  });

  test('奥で仕える女性・嫁いだ女性の人生を流しても例外がなく、女の道の成人に平均二つ以上出る', () {
    var adults = 0, total = 0, withAny = 0, died = 0, rtTotal = 0;
    var oku = 0, okuTotal = 0, wives = 0, wivesTotal = 0;
    final kinds = <String, int>{};
    for (var seed = 0; seed < 1800 && adults < 420; seed++) {
      final g = _grownGirl(seed * 7 + 13);
      if (g == null) continue;
      final r = Rng(seed + 500);
      // 三通り: 下女・女中頭で奥へ／奥女中で奥へ／武家に嫁いだ身。
      final kind = seed % 3;
      if (kind == 0) {
        _serve(g, 1 + seed % 2);
      } else if (kind == 1) {
        _serve(g, 3);
      } else {
        _wed(g, 1 + seed % 3);
      }
      final run = _play(g, (g, p) => seed.isEven ? pickAmbitious(g, p, r) : _randomPick(r, p));
      if (g.age < 20 || lifeWay(g.l) != 'woman') continue;
      adults++;
      total += run.ids.length;
      rtTotal += run.rt.length;
      if (kind == 2) {
        wives++;
        wivesTotal += run.ids.length;
      } else {
        oku++;
        okuTotal += run.ids.length;
      }
      if (run.ids.isNotEmpty) withAny++;
      for (final id in run.ids) {
        kinds[id] = (kinds[id] ?? 0) + 1;
      }
      if (_newDeaths.any((d) => (g.l.dead ?? '').contains(d))) died++;
    }
    final avg = total / adults;
    final later = kinds.keys.where(kOkuPrev.containsKey).toSet();
    // ignore: avoid_print
    print('【奥と嫁いだ女性の岐路】女の道で二十歳を越えた$adults人生: ok_ 平均${avg.toStringAsFixed(2)}・'
        'rt_ 平均${(rtTotal / adults).toStringAsFixed(2)}・一つ以上 $withAny・'
        '奥から $oku人生 平均${(okuTotal / (oku == 0 ? 1 : oku)).toStringAsFixed(2)}・'
        '嫁いだ身から $wives人生 平均${(wivesTotal / (wives == 0 ? 1 : wives)).toStringAsFixed(2)}・'
        '出た種類 ${kinds.length}/${kOkuLifeIds.length}・後段 ${later.length}・新しい岐路で亡くなった $died・'
        '出なかった ${kOkuLifeIds.toSet().difference(kinds.keys.toSet())}・回数 $kinds');
    expect(adults, greaterThan(250));
    expect(avg, greaterThanOrEqualTo(2));
    expect(kinds.length, greaterThanOrEqualTo(kOkuLifeIds.length - 3), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(7));
    expect(died / adults, lessThan(.05));
  });

  test('ふつうの人生: 男には出ず、女の道の成人の中堅の岐路（rt_ と ok_）が増えている', () {
    var womenAdults = 0, ok = 0, rt = 0;
    for (var seed = 0; seed < 900; seed++) {
      final rng = Rng(seed + 61000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 71000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      if (!g.l.female) {
        expect(run.ids, isEmpty, reason: '男に ${run.ids}');
        continue;
      }
      if (g.age >= 20 && lifeWay(g.l) == 'woman') {
        womenAdults++;
        ok += run.ids.length;
        rt += run.rt.length;
      }
    }
    // ignore: avoid_print
    print('【ふつうの人生の ok_】女の道で二十歳を越えた$womenAdults人生: ok_ 平均${(ok / womenAdults).toStringAsFixed(2)}・'
        'rt_ 平均${(rt / womenAdults).toStringAsFixed(2)}・合わせて ${((ok + rt) / womenAdults).toStringAsFixed(2)}');
    expect(womenAdults, greaterThan(40));
    expect(ok / womenAdults, greaterThanOrEqualTo(1.5));
    // 足す前は rt_ だけで女性の中堅の岐路が一人生に一つに届かなかった。合わせて二つを超える。
    expect((ok + rt) / womenAdults, greaterThan(2));
    expect(kRetainerLifeIds, isNotEmpty);
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

  test('遺されたもの: 奥と嫁いだ女性の筋の旗を立てると、その行が出る', () {
    const flags = [
      'ok_kane_found',
      'ok_houbai_saved',
      'ok_houbai_reunited',
      'ok_hoso_nursed',
      'ok_rakujo_hime',
      'ok_rojo_wall',
      'ok_rusu_kept',
      'ok_sobame_raised',
      'ok_ryoke_peace',
      'ok_shutome_keys',
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
