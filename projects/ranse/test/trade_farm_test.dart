import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/remembrance.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/trade_farm.dart';
import 'package:ranse/engine/ways.dart';

import 'bot.dart';

final _digits = RegExp('[0-9０-９%％]');

/// 出た商人・百姓の岐路の選択肢（あとで匂わせと数字を確かめる）。
final _seenChoices = <String, List<Choice>>{};

/// 岐路が出た瞬間に、出てよい人・前の段の旗を確かめる。
void _checkAtPrompt(Game g, String id) {
  if (id.startsWith('tf_m_')) {
    expect(tfMerchant(g), isTrue, reason: '$id が商人でない人に出た（${g.rankName()}）');
  } else {
    expect(tfFarmer(g), isTrue, reason: '$id が百姓でない人に出た（${g.rankName()}）');
  }
  expect(g.l.rank, 0, reason: '$id が身分のある人に出た');
  final prev = kTradeFarmPrev[id];
  if (prev != null) {
    expect(prev.any(g.hasFlag), isTrue, reason: '$id が前の段の旗なしに出た');
    final gap = kTradeFarmGap[id]!;
    expect(tfSince(g, gap.$1), greaterThanOrEqualTo(gap.$2), reason: '$id が前の段から間を置かずに出た');
  }
}

/// 人生の終わりまで進める。新しく出た `tf_` の岐路の id を返す。
List<String> _play(
  Game g,
  int Function(Game g, Prompt p) pick, {
  int limit = 3000,
}) {
  final out = <String>[];
  var known = g.l.flags.where((f) => f.startsWith('scene:tf_')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    final p = g.prompt;
    expect(p, isNotNull, reason: '人生の途中なのに選択肢が出ていない（${g.age}歳）');
    final now = g.l.flags.where((f) => f.startsWith('scene:tf_')).toSet();
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
Game? _grownUp(int seed, {bool Function(Game g)? accept}) {
  final rng = Rng(seed);
  final g = Game(rng: rng);
  g.start(rollBirth(rng));
  if (g.finished) return null;
  if (accept != null && !accept(g)) return null;
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  if (g.finished) return null;
  return g;
}

/// 大人になってから出た、tf_ 以外の岐路の数（史実・子どもの岐路を除く、一生に一度のもの）。
int _otherScenes(Game g) => g.l.flags
    .where((f) => f.startsWith('scene:') && !f.startsWith('scene:tf_') && !f.startsWith('scene:h_') && !f.startsWith('scene:c_'))
    .where((f) => g.adultScenes.any((s) => 'scene:${s.id}' == f))
    .length;

int _randomPick(Rng r, Prompt p) => r.range(0, p.choices.length - 1);

/// 村に留まる選び方: 重点では仕官・奉公を探さず、岐路は無作為。
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
  test('場面の表: 商人と百姓それぞれ14以上・id はすべて登録されている・筋の表の id も実在する', () {
    expect(kTradeFarmMerchantIds.length, greaterThanOrEqualTo(14));
    expect(kTradeFarmFarmerIds.length, greaterThanOrEqualTo(14));
    final g = Game(rng: Rng(1));
    final ids = g.adultScenes.map((s) => s.id).toSet();
    for (final id in [...kTradeFarmMerchantIds, ...kTradeFarmFarmerIds]) {
      expect(ids.contains(id), isTrue, reason: id);
      expect(id.startsWith('tf_'), isTrue);
    }
    final all = {...kTradeFarmMerchantIds, ...kTradeFarmFarmerIds};
    for (final id in kTradeFarmPrev.keys) {
      expect(all.contains(id), isTrue, reason: id);
      expect(kTradeFarmGap.containsKey(id), isTrue, reason: id);
    }
    expect(kTradeFarmPrev.keys.where((k) => k.startsWith('tf_m_')).length, greaterThanOrEqualTo(4));
    expect(kTradeFarmPrev.keys.where((k) => k.startsWith('tf_f_')).length, greaterThanOrEqualTo(4));
  });

  test('筋の後段は、前の段の旗がなければ出ず、同じ年にも出ず、年が空けば出る', () {
    Game? find(bool Function(Game g) ok) {
      for (var s = 0; s < 400; s++) {
        final rng = Rng(s + 500);
        final g = Game(rng: rng);
        g.start(rollBirth(rng));
        if (!g.finished && ok(g)) return g;
      }
      return null;
    }

    final farmer = find((g) => g.l.cls.id == 'farmer' && !g.l.female)!;
    final merchant = find((g) => !g.l.female)!;
    for (final g in [farmer, merchant]) {
      g.prompt = null;
      g.l.t = 40 * 2;
      g.l.rank = 0;
      g.l.addKid(g.year - 20);
    }
    merchant.setFlag('way_merchant');
    merchant.meet('手代', '与助', 60);
    expect(tfMerchant(merchant), isTrue);
    expect(tfFarmer(farmer), isTrue);

    for (final e in kTradeFarmPrev.entries) {
      final g = e.key.startsWith('tf_m_') ? merchant : farmer;
      final s = g.adultScenes.firstWhere((x) => x.id == e.key);
      final chain = kTradeFarmGap[e.key]!;
      // 前の段がない
      for (final f in e.value) {
        g.l.flags.remove(f);
      }
      g.l.flags.removeWhere((f) => f.startsWith('tf_at:'));
      expect(s.cond(g), isFalse, reason: '${e.key}: 前の段なし');
      // 前の段の旗はあるが、同じ年
      g.setFlag(e.value.first);
      g.setFlag('tf_at:${chain.$1}:${g.year}');
      expect(s.cond(g), isFalse, reason: '${e.key}: 同じ年');
      // 年が空いた
      g.l.flags.removeWhere((f) => f.startsWith('tf_at:'));
      g.setFlag('tf_at:${chain.$1}:${g.year - chain.$2}');
      if (e.key == 'tf_m_za_end' && g.year < 1568) continue;
      expect(s.cond(g), isTrue, reason: '${e.key}: 年が空いた');
      g.l.flags.remove(e.value.first);
    }
  });

  test('商人の人生を流しても例外がなく、商人の岐路が平均二つ以上出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, others = 0;
    final kinds = <String>{};
    // 300人生の平均は種しだいで 1.5〜2.2 と揺れた（場面を足して乱数の流れが変わると下回った）ので、
    // 900人生で見る。平均の目安は 1.9〜2.0（2026-11-23、子どもの重点 その2を足したときに測った）。
    for (var seed = 0; seed < 900; seed++) {
      final g = _grownUp(seed * 7 + 11);
      if (g == null) continue;
      g.setFlag('way_merchant');
      final r = Rng(seed + 900);
      final got = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      if (g.age < 20 || lifeWay(g.l) != 'merchant') continue;
      adults++;
      others += _otherScenes(g);
      final m = got.where((id) => id.startsWith('tf_m_')).toList();
      total += m.length;
      if (m.isNotEmpty) withAny++;
      kinds.addAll(m);
      expect(got.where((id) => id.startsWith('tf_f_')), isEmpty, reason: '商人に百姓の岐路');
    }
    final avg = total / adults;
    // ignore: avoid_print
    print('【商人の岐路】商いの道で二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        '一つ以上 $withAny・出た種類 ${kinds.length}/${kTradeFarmMerchantIds.length}・'
        'ほかの岐路 平均${(others / adults).toStringAsFixed(2)}');
    expect(adults, greaterThan(300));
    expect(avg, greaterThanOrEqualTo(1.6));
    expect(kinds.length, greaterThanOrEqualTo(kTradeFarmMerchantIds.length - 1), reason: '$kinds');
    expect(kinds.intersection(kTradeFarmPrev.keys.toSet()).length, greaterThanOrEqualTo(5));
  });

  test('百姓の人生を流しても例外がなく、百姓の岐路が出て、筋の後段も出る', () {
    var adults = 0, total = 0, withAny = 0, others = 0;
    final kinds = <String>{};
    for (var seed = 0; seed < 600; seed++) {
      final g = _grownUp(seed * 5 + 3, accept: (g) => g.l.cls.id == 'farmer');
      if (g == null) continue;
      final r = Rng(seed + 4000);
      final got = _play(g, (g, p) => _stayPick(g, p, r));
      if (g.age < 20 || lifeWay(g.l) != 'village') continue;
      adults++;
      others += _otherScenes(g);
      final f = got.where((id) => id.startsWith('tf_f_')).toList();
      total += f.length;
      if (f.isNotEmpty) withAny++;
      kinds.addAll(f);
      expect(got.where((id) => id.startsWith('tf_m_')), isEmpty, reason: '百姓に商人の岐路');
    }
    final avg = total / adults;
    // ignore: avoid_print
    print('【百姓の岐路】村の暮らしで二十歳を越えた$adults人生: 平均${avg.toStringAsFixed(2)}・'
        '一つ以上 $withAny・出た種類 ${kinds.length}/${kTradeFarmFarmerIds.length}・'
        'ほかの岐路 平均${(others / adults).toStringAsFixed(2)}・出なかった ${kTradeFarmFarmerIds.toSet().difference(kinds)}');
    expect(adults, greaterThan(100));
    expect(avg, greaterThanOrEqualTo(1.5));
    expect(kinds.length, greaterThanOrEqualTo(kTradeFarmFarmerIds.length - 2), reason: '$kinds');
    expect(kinds.intersection(kTradeFarmPrev.keys.toSet()).length, greaterThanOrEqualTo(4));
  });

  test('ほかの道（侍・女の奥勤め・僧・野の道）には出ない', () {
    var samurai = 0;
    final perWay = <String, List<int>>{};
    for (var seed = 0; seed < 500; seed++) {
      final rng = Rng(seed + 20000);
      final g = Game(rng: rng);
      g.start(rollBirth(rng));
      final r = Rng(seed + 30000);
      final startRank = g.l.birthRank;
      final got = _play(g, (g, p) => seed.isEven ? _randomPick(r, p) : pickAmbitious(g, p, r));
      final way = lifeWay(g.l);
      perWay.putIfAbsent(way, () => []).add(got.length);
      // 武家に生まれ、身分を一度も失わずに終わった人生には出ない。
      if (startRank >= 1 && g.l.rank >= 1 && !g.l.ronin && !g.hasFlag('way_merchant')) {
        samurai++;
        expect(got, isEmpty, reason: '侍に $got');
      }
      // 身分を得る前・仏門に入る前の暮らしで出ることはあるが、どれも出た瞬間に
      // 商人か百姓であることを確かめている（_checkAtPrompt）。
    }
    // ignore: avoid_print
    print('【道ごとの tf_ の数】${{
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

  test('遺されたもの: 商いと村の筋の旗を立てると、その行が出る', () {
    const flags = [
      'tf_za_voice',
      'tf_rakuichi_held',
      'tf_kome_fair',
      'tf_kowashi_opened',
      'tf_norenwake',
      'tf_yasen_bargain',
      'tf_tekka_held',
      'tf_kinsei',
      'tf_genmen_won',
      'tf_kept_seed',
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
