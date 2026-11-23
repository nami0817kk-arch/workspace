import 'dart:math' as math;

import 'package:quadrillion/game/game.dart';

import 'bot.dart';

/// 序盤の遊びやすさの数え方（1.0.0+17）。値段を「1単位の固定額」にしたあと、
/// はじめの3年に「買えるものが何も無い月」「1手も打てない月」がどれだけ続くかを、自動プレイで数える。
class EarlyStat {
  /// 数えた月
  int months = 0;

  /// 月のはじめに、お金を使う手（新しい事業・自分の事業を育てる手・足りない人・広告・部下の採用）が1つも払えなかった月
  int noBuy = 0;

  /// 事業を持っているのに、その事業を育てる手（店を増やす・広げる・商品を作る）が1つも払えなかった月
  int noGrow = 0;

  /// 1手も打てなかった月（月のはじめに手が0）
  int noMove = 0;

  /// 「育てる手が払えない」が続いたいちばん長い月数
  int streak = 0;

  /// 事業にお金を使う手を1つも打たなかった月（社長の日銭稼ぎだけで終わった月）
  int workOnly = 0;

  /// 最初の事業を始めたあと、次に育てる手を打てるまでの月数（打てなかったら数えた月数）
  int firstGrowAfter = -1;

  /// 3年後の月の売上
  double rev = 0;

  /// 途中で倒れた
  bool over = false;
}

/// その事業を育てる手のいちばん安い値段。[small] は「今ある店・工場を広げる」（元手の4分の1）を数に入れるか
double growMin(Game s, Biz b, bool small) => math.min(small ? s.extendCost(b) : double.infinity, math.min(s.buildCost(b, 1), s.devCost(b, 0)));

/// お金を使う手のいちばん安い値段（新しい事業・育てる手・足りない人・広告・部下の採用）
double cheapestBuy(Game s, bool small) {
  var m = double.infinity;
  for (final i in s.liveInds()) {
    if (!s.biz.any((b) => b.ind == i.id)) m = math.min(m, s.capexOf(i));
  }
  for (final b in s.biz) {
    m = math.min(m, growMin(s, b, small));
    final need = s.crewNeedPeople(b);
    if (need > 0) m = math.min(m, s.hireCost(b, need));
    if (b.ad <= 0) m = math.min(m, s.invBase(b) * .25);
  }
  for (final p in s.cands) {
    m = math.min(m, p.salary * 2);
  }
  return m;
}

/// 素直な新人の遊び方で [months] か月進めて数える。
/// 事業が無ければ、払える中で利益率のいちばん高い業種を始める。あれば、足りない人 → 育てる手（手元の8割まで。店を1つ、仕掛かりがあれば小さな改良、
/// どちらも払えなければ [small] のとき「広げる」）の順に打ち、払えなければ残りの手は日銭稼ぎに回す
EarlyStat playEarly(Game s, {int months = 36, bool small = true}) {
  final st = EarlyStat();
  var run = 0, startedAt = -1;
  for (var t = 0; t < months; t++) {
    resolveEvents(s);
    if (s.over != null) {
      st.over = true;
      break;
    }
    st.months++;
    if (cheapestBuy(s, small) > s.cash) st.noBuy++;
    if (s.biz.isNotEmpty && s.biz.every((b) => growMin(s, b, small) > s.cash)) {
      st.noGrow++;
      run++;
      st.streak = math.max(st.streak, run);
    } else {
      run = 0;
    }
    if (s.ap <= 0) st.noMove++;
    var grown = 0;
    if (s.biz.isEmpty) {
      final l = s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList()..ssort((a, b) => b.mg.compareTo(a.mg));
      if (l.isNotEmpty) {
        s.startBiz(l[0].id);
        startedAt = t;
      }
    }
    for (var k = 0; k < 6 && s.ap > 0; k++) {
      final b = (s.biz.toList()..ssort((x, y) => y.rev.compareTo(x.rev))).firstOrNull;
      if (b == null) {
        s.presAct('work');
        continue;
      }
      final need = s.crewNeedPeople(b);
      final c0 = s.cash, budget = s.cash * .8;
      if (need > 0) {
        if (s.hireCost(b, need) <= s.cash) {
          s.hireN(b, need);
        } else {
          s.presAct('work');
        }
        continue;
      }
      if (b.pipe.where((p) => p.k == 'build').isEmpty && s.buildCost(b, 1) <= budget) {
        s.buildN(b, 1);
      } else if (b.pipe.where((p) => p.k == 'dev').isEmpty && s.devCost(b, 0) <= budget) {
        s.developN(b, 0);
      } else if (small && b.pipe.isEmpty && s.extendCost(b) <= budget) {
        s.extendN(b);
      } else {
        s.presAct('work');
      }
      if (s.cash < c0) grown++;
    }
    if (grown == 0) st.workOnly++;
    if (grown > 0 && startedAt >= 0 && st.firstGrowAfter < 0) st.firstGrowAfter = t - startedAt;
    s.nextQuarter();
  }
  if (st.firstGrowAfter < 0) st.firstGrowAfter = st.months;
  st.rev = s.rev;
  return st;
}

typedef EarlyAvg = ({double noBuy, double noGrow, double noMove, double streak, double workOnly, double firstGrow, double rev, int over, int worst});

/// 年・難しさごとに、乱数を変えて [seeds] 回ぶんの平均を出す
EarlyAvg earlyAvg(int year, String diff, {int seeds = 12, int months = 36, bool small = true}) {
  var nb = 0, ng = 0, nm = 0, sk = 0, wo = 0, fb = 0, ov = 0, worst = 0;
  var rev = 0.0;
  for (var i = 0; i < seeds; i++) {
    final s = Game.newGame(SetupConfig(mode: 'world', year: year, diff: diff, traits: const []), rng: ParkMiller(101 + i * 7));
    final st = playEarly(s, months: months, small: small);
    nb += st.noBuy;
    ng += st.noGrow;
    nm += st.noMove;
    sk += st.streak;
    wo += st.workOnly;
    fb += st.firstGrowAfter;
    rev += st.rev;
    if (st.over) ov++;
    worst = math.max(worst, st.streak);
  }
  return (
    noBuy: nb / seeds,
    noGrow: ng / seeds,
    noMove: nm / seeds,
    streak: sk / seeds,
    workOnly: wo / seeds,
    firstGrow: fb / seeds,
    rev: rev / seeds,
    over: ov,
    worst: worst
  );
}
