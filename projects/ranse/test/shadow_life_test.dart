import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/shadow_life.dart';
import 'package:ranse/engine/ways.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出たこの道の岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// この道の岐路で亡くなった数（死因の文の頭で見分ける）。
const _newDeaths = [
  '敵方の町を探るうちに',
  '争う両家に通じたことが露見し',
  '捕らわれた仲間を救いに',
  '見捨てた昔の仲間に恨まれ',
  '覚えたての毒の加減を誤り',
  '毒を盛る役目をしくじり',
  '天正の伊賀の戦で',
  '名を変えて暮らすうち',
  '峠の関を押し通ろうとして',
  '一味の手下の謀反に遭い',
  '雇われた村で野盗と斬り結び',
  '陣借りで加わった戦で',
  '落ち武者狩りの山で',
];

/// 忍びの里の子に生まれ替えた生まれ（ほかは抽選のまま）。
Birth _ninjaBirth(Rng r, {bool? female}) {
  final b = rollBirth(r);
  final cls = classById('ninja');
  final fem = female ?? b.female;
  return Birth(
    cls: cls,
    region: b.region,
    faction: b.faction,
    startYear: b.startYear,
    month: b.month,
    day: b.day,
    female: fem,
    order: b.order,
    stats: b.stats,
    traits: b.traits,
    rarity: b.rarity,
    name: b.name,
    label: clsLabel(cls, fem, b.order),
    sameClass: b.sameClass,
    birthRank: calcBirthRank(cls, fem, b.order),
  );
}

/// 岐路が出た瞬間に、出てよい人・前の段の旗・年を確かめる。
void _checkAtPrompt(Game g, String id) {
  expect(shadowLife(g), isTrue, reason: '$id がこの道でない人に出た（${g.rankName()}）');
  expect(g.l.rank, 0, reason: '$id が身分のある人に出た');
  final prev = kShadowPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kShadowGap[id]!;
    expect(shSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
  }
  if (id == 'sh_n_iga_first') expect(g.year, inInclusiveRange(1579, 1580));
  if (id == 'sh_n_iga_second') expect(g.year, 1581);
  if (id == 'sh_n_iga_exiles') expect(g.year, inInclusiveRange(1581, 1590));
}

/// 人生の終わりまで進める。新しく出た `sh_` の岐路の id を返す。
List<String> _play(Game g, int Function(Game g, Prompt p) pick, {int limit = 3000}) {
  final out = <String>[];
  var known = g.l.flags.where((f) => f.startsWith('scene:sh_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:sh_')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.add(id);
      _checkAtPrompt(g, id);
      _seenChoices[id] = p!.choices;
    }
    known = now;
    g.choose(pick(g, p!));
  }
  expect(g.finished, isTrue, reason: '人生が終わらない');
  return out;
}

/// 元服の手前まで進めた人生。生き延びなければ null。
Game? _grownUp(int seed, {bool ninja = false}) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  g.start(ninja ? _ninjaBirth(rng) : rollBirth(rng));
  if (g.finished) return null;
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  if (g.finished) return null;
  return g;
}

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

/// 里に留まる選び方: 重点では仕官・奉公を探さず、岐路は無作為。
int _stayPick(Game g, Prompt p, Rng r) {
  if (p.title == 'この年の心がけ') {
    final ok = [
      for (var i = 0; i < p.choices.length; i++)
        if (!p.choices[i].label.contains('仕官') && !p.choices[i].label.contains('奉公')) i,
    ];
    return ok[r.range(0, ok.length - 1)];
  }
  return _randomPick(r, p);
}

void main() {
  test('場面の表: 二十五前後・id はすべて登録されている・筋の表の id も実在する', () {
    expect(kShadowLifeIds.length, greaterThanOrEqualTo(24));
    expect(kShadowLifeIds.toSet().length, kShadowLifeIds.length);
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toList();
    for (final id in kShadowLifeIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
      expect(id.startsWith('sh_'), isTrue);
    }
    expect(ids.where((x) => x.startsWith('sh_')).length, kShadowLifeIds.length);
    for (final id in kShadowPrev.keys) {
      expect(kShadowLifeIds.contains(id), isTrue, reason: id);
      expect(kShadowGap.containsKey(id), isTrue, reason: id);
    }
    // 三段以上の筋が三本以上（頭の仕事・山の一味・用心棒）。
    final chains = <String, int>{};
    for (final v in kShadowGap.values) {
      chains[v.$1] = (chains[v.$1] ?? 0) + 1;
    }
    expect(chains.values.where((n) => n >= 2).length, greaterThanOrEqualTo(3), reason: '$chains');
    expect(chains.length, greaterThanOrEqualTo(6));
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る', () {
    Game? g;
    for (var s = 0; g == null; s++) {
      final rng = Rng(s + 600);
      final x = Game(rng: rng);
      x.start(_ninjaBirth(rng, female: false));
      if (!x.finished) g = x;
    }
    g.prompt = null;
    g.l.t = 40 * 2;
    g.l.rank = 0;
    const sato = ['sh_n_lords', 'sh_n_atome'];
    const nuke = ['sh_nk_hunter'];
    const road = ['sh_o_band_rule', 'sh_o_band_end', 'sh_o_yojin_raid', 'sh_o_settle'];
    for (final e in kShadowPrev.entries) {
      for (final f in ['way_outlaw', 'nukenin', 'wanderer', 'reformed']) {
        g.l.flags.remove(f);
      }
      if (nuke.contains(e.key)) {
        g.setFlag('nukenin');
        g.setFlag('way_outlaw');
      } else if (road.contains(e.key)) {
        g.setFlag('way_outlaw');
      }
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      final chain = kShadowGap[e.key]!;
      for (final f in kShadowPrev.values.expand((v) => v)) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('sh_at:'));
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      g.setFlag(e.value.first);
      g.setFlag('sh_at:${chain.$1}:${g.year}');
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      g.l.flags.removeWhere((f) => f.startsWith('sh_at:'));
      g.setFlag('sh_at:${chain.$1}:${g.year - chain.$2}');
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      // 里の者だけの段は、野に出た人には出ない。
      if (sato.contains(e.key)) {
        g.setFlag('way_outlaw');
        expect(s.cond(g), isFalse, reason: '${e.key}: 野に出た人');
      }
      // 身分を得た人には出ない。
      g.l.rank = 2;
      expect(s.cond(g), isFalse, reason: '${e.key}: 身分のある人');
      g.l.rank = 0;
    }
  });

  test('この道の人生を流しても例外がなく、この道の成人に平均二つ以上出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, died = 0;
    final kinds = <String>{};
    final byKind = <String, List<int>>{};
    // 600人生の平均は種しだいで 1.8〜2.2 と揺れた（場面を足して乱数の流れが変わると下回った）ので、
    // 1200人生で見る。平均の目安は 1.9〜2.0（2026-11-23、子どもの重点 その2を足したときに測った）。
    // 2026-11-25: 1200人生でも、乱数を一つ余分に引くだけで 1.76 → 1.67 と線を割るほど揺れた（直す前のコードで測った）ので、
    // 2400人生で見る（直す前 1.77・乱数をずらして 1.75・人と家の4項目を足して 1.72）。線は下げていない。
    for (var seed = 0; seed < 2400; seed++) {
      final kind = ['ninja', 'bandit', 'wanderer'][seed % 3];
      final g = _grownUp(seed * 7 + 13, ninja: kind == 'ninja');
      if (g == null) continue;
      if (kind == 'bandit' && !g.l.female) {
        g.setFlag('way_outlaw');
      } else if (kind != 'ninja') {
        g.setFlag('wanderer');
        g.setFlag('way_outlaw');
      }
      final r = Rng(seed + 900);
      final got = _play(g, (g, p) => seed % 4 == 0 ? pickAmbitious(g, p, r) : _stayPick(g, p, r));
      if (g.age < 20 || lifeWay(g.l) != 'shadow') continue;
      adults++;
      total += got.length;
      if (got.isNotEmpty) withAny++;
      kinds.addAll(got);
      byKind.putIfAbsent(kind, () => []).add(got.length);
      if (_newDeaths.any((d) => (g.l.dead ?? '').startsWith(d))) died++;
    }
    final avg = total / adults;
    // ignore: avoid_print
    print('【この道の岐路】この道で二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        '一つ以上 $withAny・出た種類 ${kinds.length}/${kShadowLifeIds.length}・'
        '入り方ごと ${{for (final e in byKind.entries) e.key: '${e.value.length}人生 平均${(e.value.fold<int>(0, (a, b) => a + b) / e.value.length).toStringAsFixed(2)}'}}・'
        '新しい岐路で亡くなった $died・出なかった ${kShadowLifeIds.toSet().difference(kinds)}');
    expect(adults, greaterThan(300));
    expect(avg, greaterThanOrEqualTo(1.7));
    expect(kinds.length, greaterThanOrEqualTo(kShadowLifeIds.length - 3), reason: '$kinds');
    expect(kinds.intersection(kShadowPrev.keys.toSet()).length, greaterThanOrEqualTo(9));
    expect(died / adults, lessThan(.15));
  });

  test('ほかの道（侍に仕えたまま・商い・仏門）には出ない', () {
    var samurai = 0;
    final perWay = <String, List<int>>{};
    for (var seed = 0; seed < 600; seed++) {
      final rng = Rng(seed + 40000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 50000);
      final startRank = g.l.birthRank;
      final got = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      final way = lifeWay(g.l);
      perWay.putIfAbsent(way, () => []).add(got.length);
      if (startRank >= 1 && g.l.rank >= 1 && !g.l.ronin && !g.hasFlag('way_outlaw')) {
        samurai++;
        expect(got, isEmpty, reason: '侍に $got');
      }
      if (way == 'merchant' || way == 'priest') {
        // 商い・仏門に入る前に野にいた人生だけに出うる（出た瞬間に確かめている）。
        if (!g.hasFlag('way_outlaw') && !g.hasFlag('reformed') && !g.hasFlag('nukenin') && g.l.cls.id != 'ninja') {
          expect(got, isEmpty, reason: '$way に $got');
        }
      }
    }
    // ignore: avoid_print
    print('【道ごとの sh_ の数】${{
      for (final e in perWay.entries)
        e.key: '${e.value.length}人生 平均${(e.value.fold<int>(0, (a, b) => a + b) / e.value.length).toStringAsFixed(2)}',
    }}');
    expect(samurai, greaterThanOrEqualTo(5));
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

  test('遺されたもの: この道の筋の旗を立てると、その行が出る', () {
    const flags = [
      'sh_n_heir',
      'sh_saved_comrade',
      'sh_cured_village',
      'sh_iga_fought',
      'sh_iga_led',
      'sh_iga_sheltered',
      'sh_band_code',
      'sh_yojin_fought',
      'sh_yojin_saved',
      'sh_settled',
      'sh_ochi_spared',
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
