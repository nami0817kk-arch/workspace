import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/castle_life.dart';
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
  '水の手の曲輪を見回っていて',
  '捕らえた間者の仲間を狩り出していた夜',
  '主家の遣わした目付に金子を包んだ',
  '主君の行いを面と向かって諫め',
];

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(clLife(g), isTrue, reason: '$id が城主・家老・宿老でない人に出た（${g.rankName()}・位${g.l.rank}）');
  expect(g.l.rank, inInclusiveRange(5, 7), reason: id);
  if (kCastleWifeIds.contains(id)) {
    expect(clWife(g), isTrue, reason: '$id が奥方でない人に出た');
  } else if (!kCastleBothIds.contains(id)) {
    expect(clLord(g), isTrue, reason: '$id が城を預かる身でない人に出た');
  }
  if (const ['cl_yotsugi', 'cl_domei'].contains(id)) expect(g.l.rank, greaterThanOrEqualTo(6), reason: id);
  if (const ['cl_rusu', 'cl_rusu_after'].contains(id)) {
    expect(g.l.female, isFalse, reason: id);
    expect(g.l.married, isTrue, reason: id);
  }
  if (id == 'cl_atotori') expect(g.l.hasKidAged(g.year, 8, 14), isTrue, reason: id);
  if (id == 'cl_yome') expect(g.l.hasKidAged(g.year, 15, 28), isTrue, reason: id);
  final prev = kCastlePrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kCastleGap[id];
    if (gap != null) {
      expect(clSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
    }
  }
}

class _Run {
  final ids = <String>[];
  var years = 0;
}

/// 人生の終わりまで進める。新しく出た `cl_` の岐路と、位五〜七で迎えた年の数を返す。
_Run _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = _Run();
  var known = g.l.flags.where((f) => f.startsWith('scene:cl_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    if (p!.title == '今年の重点' && !g.isChild && clLife(g)) out.years++;
    final now = g.l.flags.where((f) => f.startsWith('scene:cl_')).toSet();
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

/// 元服のあと、近くの家に位 [rank] で仕えさせる。
void _serve(Game g, int rank) {
  final l = g.l;
  final f = nearest(g.alive, (f) => f.name, region: l.region, n: 1).first;
  l.rank = rank;
  if (l.maxRank < rank) l.maxRank = rank;
  l.lord = f.name;
  l.fav = 45;
  l.troops = rank >= 5 ? (rank == 5 ? 40 : 70) : 20;
  l.ronin = false;
  l.flags.remove('way_merchant');
  l.flags.remove('way_outlaw');
  l.flags.remove('priesthood');
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

void main() {
  test('場面の表: 二十五前後・id はすべて一度ずつ登録されている・筋の表の id も実在する', () {
    expect(kCastleLifeIds.length, inInclusiveRange(22, 32));
    expect(kCastleLifeIds.toSet().length, kCastleLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kCastleLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('cl_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('cl_')).length, kCastleLifeIds.length);
    for (final id in [...kCastlePrev.keys, ...kCastleWifeIds, ...kCastleBothIds]) {
      expect(kCastleLifeIds.contains(id), isTrue, reason: id);
    }
    for (final id in kCastleGap.keys) {
      expect(kCastlePrev.containsKey(id), isTrue, reason: id);
    }
    expect(kCastlePrev.length, greaterThanOrEqualTo(4));
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る。ほかの位・身分なしには出ない', () {
    Game pick(bool female) {
      for (var s = 0;; s++) {
        final rng = Rng(s + 700);
        final x = Game(rng: rng);
        final b = rollBirth(rng);
        if (b.startYear > 1550 || b.female != female) continue;
        x.start(b);
        if (x.finished) continue;
        x.prompt = null;
        x.l.t = (1585 - x.l.startYear) * 2;
        _serve(x, 6);
        return x;
      }
    }

    final man = pick(false), woman = pick(true);
    final allPrev = kCastlePrev.values.expand((v) => v).toSet();
    void reset(Game g) {
      g.l.rank = 6;
      g.l.married = true;
      g.meet('伴侶', g.l.female ? '高政' : 'お春', 50);
      g.l.kids = 1;
      g.l.kidYears
        ..clear()
        ..add(g.year - 20);
      for (final f in allPrev) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('cl_at:'));
    }

    for (final e in kCastlePrev.entries) {
      final g = man;
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      reset(g);
      reset(woman);
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      final gap = kCastleGap[e.key]!;
      for (final x in [g, woman]) {
        x.setFlag(e.value.first);
        x.setFlag('cl_at:${gap.$1}:${x.year}');
      }
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      for (final x in [g, woman]) {
        x.l.flags.removeWhere((f) => f.startsWith('cl_at:'));
        x.setFlag('cl_at:${gap.$1}:${x.year - gap.$2}');
      }
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      for (final r in [5, 7]) {
        g.l.rank = r;
        expect(s.cond(g), isTrue, reason: '${e.key}: 位$r');
      }
      for (final r in [0, 1, 2, 3, 4, 8, 9]) {
        g.l.rank = r;
        expect(s.cond(g), isFalse, reason: '${e.key}: 位$r');
      }
      g.l.rank = 6;
      // 隠居・仏門・主家なし。
      g.setFlag('retired');
      expect(s.cond(g), isFalse, reason: '${e.key}: 隠居');
      g.l.flags.remove('retired');
      final lord = g.l.lord;
      g.l.lord = null;
      expect(s.cond(g), isFalse, reason: '${e.key}: 主家なし');
      g.l.lord = lord;
      // 城を預かる身の筋は、女城主でない女性には出ない。
      expect(s.cond(woman), isFalse, reason: '${e.key}: 女城主でない女性');
    }

    // 奥方の岐路は嫁いだ女性だけ。男・嫁いでいない女性・位四には出ない。
    for (final id in kCastleWifeIds) {
      final s = woman.adultScenes.firstWhere((x) => x.id == id);
      reset(woman);
      reset(man);
      expect(s.cond(woman), isTrue, reason: '$id: 奥方');
      expect(s.cond(man), isFalse, reason: '$id: 男');
      woman.l.married = false;
      expect(s.cond(woman), isFalse, reason: '$id: 嫁いでいない');
      woman.l.married = true;
      woman.l.rank = 4;
      expect(s.cond(woman), isFalse, reason: '$id: 位四');
    }
    // 女城主は城を預かる身の岐路に入る。
    reset(woman);
    woman.setFlag('onna_jo');
    expect(clLord(woman), isTrue);
    woman.l.flags.remove('onna_jo');
    expect(clLord(woman), isFalse);
  });

  test('位五〜七に届く人生を流しても例外がなく、その年がある成人に平均二つ以上出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, died = 0, years = 0;
    var women = 0, womenTotal = 0;
    final kinds = <String, int>{};
    for (var seed = 0; seed < 900; seed++) {
      final g = _grownUp(seed * 11 + 57);
      if (g == null) continue;
      final r = Rng(seed + 1900);
      // 三人に二人は元服で位五〜七に置き直し、残りは侍大将から考えて選んで上がるのを待つ。
      if (seed % 3 != 2) {
        _serve(g, 5 + seed % 3);
      } else {
        _serve(g, 4);
        g.l.merit = 100;
      }
      if (g.l.female) {
        // 女性は、嫁いだ奥方か、女城主と呼ばれた人として置く。
        if (seed % 2 == 0) {
          g.l.married = true;
          g.meet('伴侶', '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}', 50);
        }
        if (seed % 4 == 1) g.setFlag('onna_jo');
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
    final later = kinds.keys.where(kCastlePrev.containsKey).toSet();
    // ignore: avoid_print
    print('【城主・家老の岐路】位五〜七の年があって二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        'その年 平均${(years / adults).toStringAsFixed(1)}・一つ以上 $withAny・女性 $women人生 平均${(womenTotal / (women == 0 ? 1 : women)).toStringAsFixed(2)}・'
        '出た種類 ${kinds.length}/${kCastleLifeIds.length}・後段 ${later.length}・新しい岐路で亡くなった $died・'
        '出なかった ${kCastleLifeIds.toSet().difference(kinds.keys.toSet())}・回数 $kinds');
    expect(adults, greaterThan(250));
    expect(avg, greaterThanOrEqualTo(2));
    expect(kinds.length, greaterThanOrEqualTo(kCastleLifeIds.length - 3), reason: '$kinds');
    expect(later.length, greaterThanOrEqualTo(7));
    expect(died / adults, lessThan(.05));
  });

  test('位五に届かない人・身分なしには出ない（ふつうの人生）', () {
    var never = 0, withYears = 0, total = 0;
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 43000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 53000);
      final run = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      if (g.l.maxRank < 5) {
        never++;
        expect(run.ids, isEmpty, reason: '位五に届かない人に ${run.ids}');
      }
      if (run.years > 0 && g.age >= 20) {
        withYears++;
        total += run.ids.length;
      }
    }
    // ignore: avoid_print
    print('【ふつうの人生の cl_】位五〜七の年がある成人 $withYears 人生 平均${(total / (withYears == 0 ? 1 : withYears)).toStringAsFixed(2)}');
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

  test('遺されたもの: 城主・家老の筋の旗を立てると、その行が出る', () {
    const flags = [
      'cl_ishi_ano',
      'cl_iriai_walked',
      'cl_rojo_held',
      'cl_spy_trap',
      'cl_yt_mended',
      'cl_isame_heard',
      'cl_domei_warned',
      'cl_fudai_entrusted',
      'cl_kiki_envoy',
      'cl_w_hostages_kind',
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
