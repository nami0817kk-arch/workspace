import 'dart:math';

import 'player.dart';
import 'talent.dart';

/// 経験点の種類。練習で貯まり、同じ種類の能力にだけ振り分けられる。
enum Category {
  batting('打撃'),
  running('守備走塁'),
  pitching('投球');

  const Category(this.label);
  final String label;
}

Category categoryOf(Ability a) => switch (a) {
      Ability.contact || Ability.power || Ability.eye => Category.batting,
      Ability.speed || Ability.fielding => Category.running,
      Ability.stuff || Ability.control || Ability.stamina => Category.pitching,
    };

/// その役割が実際に使える経験点の種類(投手の「打撃」のように、使い道が無いものは除く)。
List<Category> usableCategories(Role r) => [
      for (final c in Category.values)
        if (abilitiesOf(r).any((a) => categoryOf(a) == c)) c
    ];

/// 「全種類に n」という報酬を、使える種類にだけ配る(使えない種類は増やさない)。
/// 実際に使える量は変えない(バランスはそのまま)。
Map<Category, int> spreadExp(Role r, int n) =>
    {for (final c in usableCategories(r)) c: n};

/// 役割ごとの補正。能力が少ない投手は、重点以外に割く分が少なく、1能力あたりの伸びが
/// 打者より速くなってしまう(重点1＋他0.25×(n-1) を n で割った値が、打者と揃うようにする)。
/// 二刀流は逆に能力が多く薄まるので補正が上がるが、練習の分散(×0.6)は別に掛かる。
double roleExpFactor(Role r) {
  final n = abilitiesOf(r).length;
  const batterShare = (1 + 0.25 * 4) / 5;
  return batterShare / ((1 + 0.25 * (n - 1)) / n) * (r == Role.pitcher ? pitcherPace : 1.0);
}

/// 投手の伸びの補正(2026-10-21)。経験点を1能力あたりで揃えても、投手は打者よりプロに入りやすく
/// レジェンドも多かった(`tool/balance.dart 600 normal`: 平凡のプロ入り 打者43%/投手62%、レジェンド 3%/19%)。
/// 能力が3つで底上げが効き、投球の経験点が1つの種類に集まるため。0.85 にすると揃う
/// (平凡 43.3%/43.8%・レジェンド 3.0%/4.0%、上手い 47.2%/46.2%・レジェンド 23.2%/21.5%)。0.75 だと投手が低すぎる(31%)。
const pitcherPace = int.fromEnvironment('BAL_PPACE', defaultValue: 85) / 100;

/// 能力1ぶん(基準)を経験点にしたときの量。練習の伸びはこれを掛けて貯まる。
const expPerPoint = 8;

/// 能力を現在値 `value` から1上げるのに要る経験点。高いほど上がりにくい。
/// `gift` はその能力の天賦(-2〜+2。得意なほど安い。`talent.dart`)。
int expCost(int value, [int gift = 0]) =>
    max(1, ((6 + value ~/ 6) * giftCostMultiplier(gift)).round());

/// やる気。気持ち(0〜100)から決まり、練習で貯まる経験点の量が変わる。
enum Motivation {
  terrible('絶不調', 0.7),
  bad('不調', 0.85),
  normal('普通', 1.0),
  good('好調', 1.15),
  great('絶好調', 1.3);

  const Motivation(this.label, this.expMultiplier);
  final String label;
  final double expMultiplier;
}

Motivation motivationOf(int morale) {
  if (morale >= 80) return Motivation.great;
  if (morale >= 60) return Motivation.good;
  if (morale >= 40) return Motivation.normal;
  if (morale >= 20) return Motivation.bad;
  return Motivation.terrible;
}

/// 貯めた経験点。種類ごとに持つ。
class ExpPool {
  const ExpPool([this._m = const {}]);
  final Map<Category, int> _m;

  int of(Category c) => _m[c] ?? 0;
  int get total => Category.values.fold(0, (a, c) => a + of(c));

  ExpPool add(Map<Category, int> gain) => ExpPool({
        for (final c in Category.values) c: of(c) + (gain[c] ?? 0),
      });

  ExpPool spend(Category c, int n) => ExpPool({
        for (final k in Category.values) k: of(k) - (k == c ? n : 0),
      });

  Map<String, dynamic> toJson() =>
      {for (final c in Category.values) c.name: of(c)};

  factory ExpPool.fromJson(Map<String, dynamic> j) => ExpPool({
        for (final c in Category.values) c: (j[c.name] as num?)?.toInt() ?? 0,
      });
}

/// 能力 `a` を1つ上げる。経験点が足りない/上限なら null。
({Player player, ExpPool pool})? buy(Player p, ExpPool pool, Ability a) {
  if (!abilitiesOf(p.role).contains(a)) return null;
  final v = p.of(a);
  final cost = expCost(v, p.gift(a));
  final c = categoryOf(a);
  if (v >= 99 || pool.of(c) < cost) return null;
  return (
    player: p.copyWith(abilities: {...p.abilities, a: v + 1}),
    pool: pool.spend(c, cost),
  );
}

/// 買えるだけ買う。
({Player player, ExpPool pool, int bought}) buyAll(
    Player p, ExpPool pool, Ability a) {
  var n = 0;
  for (;;) {
    final r = buy(p, pool, a);
    if (r == null) return (player: p, pool: pool, bought: n);
    p = r.player;
    pool = r.pool;
    n++;
  }
}

/// おまかせ: 種類ごとに、いちばん低い能力から順に買う。
({Player player, ExpPool pool}) autoSpendExp(Player p, ExpPool pool) {
  var bought = true;
  while (bought) {
    bought = false;
    for (final c in Category.values) {
      final cands = [
        for (final a in abilitiesOf(p.role))
          if (categoryOf(a) == c && p.of(a) < 99) a,
      ]..sort((x, y) => p.of(x).compareTo(p.of(y)));
      for (final a in cands) {
        final r = buy(p, pool, a);
        if (r != null) {
          p = r.player;
          pool = r.pool;
          bought = true;
          break;
        }
      }
    }
  }
  return (player: p, pool: pool);
}
