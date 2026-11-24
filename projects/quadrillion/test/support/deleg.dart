import 'dart:convert';
import 'dart:math' as math;

import 'package:quadrillion/game/game.dart';

import 'bot.dart';

/// 「責任者に任せる」（1.0.0+20）の釣り合いを測る道具。

/// 自動プレイの任せ方: none 全部自分で / all 責任者のいる事業を全部任せる / half 半分（1つおき）任せる
void delegMonth(Game g, String how, {int budget = 1}) {
  resolveEvents(g);
  if (g.won != null) {
    g.mode = 'endless';
    g.won = null;
  }
  // どの遊び方でも、空いている部下は責任者に置く（任せるかどうかだけを変えて比べる）
  if (g.managerPlan().isNotEmpty) g.placeManagers();
  var i = 0;
  for (final b in g.biz) {
    final on = g.canDeleg(b) && (how == 'all' || (how == 'half' && i++ % 2 == 0));
    g.setDeleg(b, on);
    if (on) g.setBudget(b, budget);
  }
  botMonth(g, units: true, mine: (b) => !g.delegated(b));
}

/// 30年後の数字
class DelegRun {
  final double cap, rev, power, cash;
  final int rank, biz, deleg;
  final String? over;
  DelegRun(Game g)
      : cap = g.cap,
        rev = g.rev,
        power = g.biz.fold(0.0, (a, b) => a + b.power),
        cash = g.cash,
        rank = g.rank,
        biz = g.biz.length,
        deleg = g.delegatedBiz().length,
        over = g.over;
}

/// 同じ種で [years] 年、[how] の任せ方で自動プレイする
DelegRun delegRun(int seed, String how, {int years = 30, int year = 1985, int budget = 1}) {
  final g = Game.newGame(SetupConfig(mode: 'endless', year: year, traits: const ['charm', 'careful']), rng: ParkMiller(seed));
  for (var m = 0; m < years * 12 && g.over == null; m++) {
    delegMonth(g, how, budget: budget);
  }
  resolveEvents(g);
  g.calcAll();
  return DelegRun(g);
}

double median(List<double> v) {
  final s = v.toList()..sort();
  return s.isEmpty ? double.nan : s[s.length ~/ 2];
}

/// 盤面をそっくり写す（セーブに出して読み直す）。乱数は [seed] から
Game cloneGame(Game g, int seed) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, rng: ParkMiller(seed));

/// 手1つの「事業の力の伸びの見込み」（商品の大当たり・不発をならした値。店が開いたとき・商品が出来上がったときの式と同じ掛け算）。
/// 人を雇う・広告・値付けは、力そのものは増やさないので 0
double expGain(Game g, Biz b, String k, double cost) {
  if (cost <= 0) return 0;
  if (k == 'build' || k == 'ext') return cost * g.pipeEff(b, cost) * (b.model == 'fc' ? 1.3 : 1);
  if (k != 'dev') return 0;
  final cap = g.capexOf(indm[b.ind]!);
  final sz = cost > cap * 6
      ? 2
      : cost > cap * 2
          ? 1
          : 0;
  final p = g.staffById(b.mgr);
  final kai = p != null ? p.ab['kai']! : g.pres.ab['kai']!;
  final hit = .08 + (g.culture == 'free' ? .08 : 0) + kai / 1000 + (g.hasT('genius') ? .08 : 0) + (g.hasT('tech') ? .05 : 0);
  final miss = math.max(.08, .3 - kai / 500);
  final m = hit * 5.5 * devHitMul[sz] + miss * .15 + (1 - hit - miss) * 1.3;
  return cost * g.pipeEff(b, cost) * m * (g.hasDeal('codev', indm[b.ind]!.cat) ? 1.5 : 1) * (b.model == 'fc' ? .6 : 1);
}

/// 人が同じお金（同じ月の枠・同じ手元の残し方）で、外さずに最善手を打つ役。1つの事業に月1つ。
/// 人が足りなければ足りない分を雇い、そうでなければ、枠に収まる手（店・工場を1／3／10、広げる、商品の3つの大きさ）のうち、
/// 力の伸びの見込み（[expGain]）がいちばん大きいものを打つ。性格の縛りは無い。手の数は数えない（お金だけをそろえて比べる）。
/// 返すのは、打った手の種類と払った額
({String k, double cost}) bestHand(Game g, Biz b) {
  final room = math.min(g.delegBudget(b), g.cash - g.delegReserve());
  final ap = g.ap;
  g.ap = 99;
  final c0 = g.cash;
  try {
    var need = g.crewNeedPeople(b);
    if (need > 0 && g.crewEff(b) < g.crewWant(b) * .95) {
      if (g.hireCost(b, need) > room) need = (room / g.hireCost(b, 1)).floor();
      if (need > 0) {
        g.hireN(b, need);
        return (k: 'crew', cost: c0 - g.cash);
      }
    }
    if (b.pipe.length >= 3) return (k: 'none', cost: 0);
    final opts = <(String, double, String Function())>[
      for (final n in buildUnits)
        if (g.buildCost(b, n) <= room) ('build', g.buildCost(b, n), () => g.buildN(b, n)),
      if (g.extendCost(b) <= room) ('ext', g.extendCost(b), () => g.extendN(b)),
      for (final sz in const [0, 1, 2])
        if (g.devCost(b, sz) <= room) ('dev', g.devCost(b, sz), () => g.developN(b, sz)),
    ];
    if (opts.isEmpty) return (k: 'none', cost: 0);
    opts.sort((x, y) => expGain(g, b, y.$1, y.$2).compareTo(expGain(g, b, x.$1, x.$2)));
    opts.first.$3();
    return (k: opts.first.$1, cost: c0 - g.cash);
  } finally {
    g.ap = ap;
  }
}

/// 任せたときと、人が同じお金で最善手を打ったときを比べた数字
class DelegVs {
  /// 責任者のいる事業の「動いている力」の合計（任せた・最善手・何もしない）
  double a = 0, b = 0, c = 0;

  /// 同じく月の売上の合計
  double ra = 0, rb = 0, rc = 0;

  /// 使ったお金と、打った手の力の伸びの見込みの合計（[expGain]。当たり外れに左右されない物差し）
  double spentA = 0, spentB = 0, gainA = 0, gainB = 0;
}

/// 任せたときと、人が同じお金で最善手を打ったときの伸びを比べる。
/// [base] の盤面（責任者のいる事業がある中盤）を3つに写し、[months] か月、ほかの手は打たずに進める:
///  A 責任者のいる事業を全部任せる　B 同じ事業に人が最善手　C 何もしない（市場の伸びと、責任者がもともと稼ぎを回す分だけ）
DelegVs delegVsBest(Game base, {int months = 60, int budget = 1, int seed = 5}) {
  final ids = base.biz.where(base.canDeleg).map((b) => b.id).toSet();
  double revOf(Game g) => g.biz.where((b) => ids.contains(b.id)).fold(0.0, (s, b) => s + b.rev);
  double powOf(Game g) => g.biz.where((b) => ids.contains(b.id)).fold(0.0, (s, b) => s + g.usedPow(b));
  final a = cloneGame(base, seed), b = cloneGame(base, seed), c = cloneGame(base, seed);
  final out = DelegVs();
  for (final x in a.biz) {
    if (ids.contains(x.id)) {
      a.setDeleg(x, true);
      a.setBudget(x, budget);
    }
  }
  for (final x in b.biz) {
    // 人の側の枠も同じ段にそろえる（任せてはいない）
    x.budget = budget;
  }
  for (var m = 0; m < months; m++) {
    for (final g in [a, b, c]) {
      resolveEvents(g);
    }
    for (final x in b.biz.toList()) {
      if (!ids.contains(x.id)) continue;
      // 見込みは、打つ前の盤面で数える
      final best = _peekBest(b, x);
      final r = bestHand(b, x);
      out.spentB += r.cost;
      if (r.k == best.$1) out.gainB += best.$2;
    }
    a.nextQuarter();
    for (final e in a.delegLog.where((e) => e.turn == a.turn)) {
      out.spentA += e.cost;
      final x = a.biz.where((x) => x.id == e.biz).firstOrNull;
      if (x != null) out.gainA += expGain(a, x, e.k, e.cost);
    }
    b.nextQuarter();
    c.nextQuarter();
  }
  for (final g in [a, b, c]) {
    resolveEvents(g);
    g.calcAll();
  }
  out
    ..a = powOf(a)
    ..b = powOf(b)
    ..c = powOf(c)
    ..ra = revOf(a)
    ..rb = revOf(b)
    ..rc = revOf(c);
  return out;
}

/// [bestHand] が打つはずの手の種類と、その力の伸びの見込み（打つ前に数える）
(String, double) _peekBest(Game g, Biz b) {
  final room = math.min(g.delegBudget(b), g.cash - g.delegReserve());
  final need = g.crewNeedPeople(b);
  if (need > 0 && g.crewEff(b) < g.crewWant(b) * .95 && (g.hireCost(b, need) <= room || (room / g.hireCost(b, 1)).floor() > 0)) return ('crew', 0);
  if (b.pipe.length >= 3) return ('none', 0);
  var best = ('none', 0.0);
  for (final o in <(String, double)>[
    for (final n in buildUnits)
      if (g.buildCost(b, n) <= room) ('build', g.buildCost(b, n)),
    if (g.extendCost(b) <= room) ('ext', g.extendCost(b)),
    for (final sz in const [0, 1, 2])
      if (g.devCost(b, sz) <= room) ('dev', g.devCost(b, sz)),
  ]) {
    final e = expGain(g, b, o.$1, o.$2);
    if (e > best.$2) best = (o.$1, e);
  }
  return best;
}
