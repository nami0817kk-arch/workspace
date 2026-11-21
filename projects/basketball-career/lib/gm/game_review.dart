import 'game_sim.dart';
import 'league.dart';

/// 采配した試合のあとの「ふりかえり」(2026-11-21、試合画面の向上 4)。
/// 試合の中身([SimResult])から、勝因・敗因、采配の効き目、両チームの主役を数える。どれも見せるためだけで、試合は変えない。

/// 試合の始めからの秒(延長は5分ずつ)。
int elapsedOf(int period, int clock) => period < 4 ? period * 720 + (720 - clock) : 2880 + (period - 4) * 300 + (300 - clock);

/// 勝因・敗因の1つ。[value] は自分から見た差(点か本数)。
class ReviewReason {
  const ReviewReason(this.text, this.value);
  final String text;
  final int value;
}

/// 采配1つの効き目。その後3分(試合の時間)の、自分と相手の点。
class CallEffect {
  const CallEffect(this.call, this.mine, this.theirs);
  final LiveCall call;
  final int mine, theirs;
  int get diff => mine - theirs;
}

/// 両チームの、試合の数字の合計。
class _Sums {
  _Sums(SimTeam t) {
    for (final l in boxLinesOf(t)) {
      tpm += l.tpm;
      tpa += l.tpa;
      fgm += l.fgm;
      ftm += l.ftm;
      reb += l.reb;
      tov += l.tov;
    }
    // 控え(出場時間の長い5人より下)の点
    final idx = [for (var i = 0; i < t.order.length; i++) i]..sort((a, b) => t.secs[b].compareTo(t.secs[a]));
    for (final i in idx.skip(5)) {
      bench += ptsAt(t, i);
    }
  }
  int tpm = 0, tpa = 0, fgm = 0, ftm = 0, reb = 0, tov = 0, bench = 0;
  int get twoPts => (fgm - tpm) * 2;
}

/// 勝因(勝ったとき)か敗因(負けたとき)を、差の大きい順に3つまで。[mineSide] は自分のチーム(0 ホーム・1 アウェー)。
List<ReviewReason> reasonsOf(SimResult r, int mineSide) {
  final me = _Sums(mineSide == 0 ? r.home : r.away), op = _Sums(mineSide == 0 ? r.away : r.home);
  final my = (mineSide == 0 ? r.home : r.away).pts, their = (mineSide == 0 ? r.away : r.home).pts;
  final won = my > their;
  String signed(int v) => v > 0 ? '+$v' : '$v';
  final all = <ReviewReason>[
    ReviewReason('3ポイントで${signed((me.tpm - op.tpm) * 3)}点(${me.tpm}本対${op.tpm}本)', (me.tpm - op.tpm) * 3),
    ReviewReason('2点のシュートで${signed(me.twoPts - op.twoPts)}点', me.twoPts - op.twoPts),
    ReviewReason('フリースローで${signed(me.ftm - op.ftm)}点', me.ftm - op.ftm),
    ReviewReason('リバウンドで${me.reb >= op.reb ? '${me.reb - op.reb}本勝った' : '${op.reb - me.reb}本負けた'}(${me.reb}対${op.reb})', me.reb - op.reb),
    ReviewReason(me.tov <= op.tov ? '相手のミスがこちらより${op.tov - me.tov}本多い' : 'こちらのミスが相手より${me.tov - op.tov}本多い', op.tov - me.tov),
    ReviewReason('控えの得点で${signed(me.bench - op.bench)}点(${me.bench}対${op.bench})', me.bench - op.bench),
  ];
  // 勝ったなら自分に有利だったもの、負けたなら不利だったものを、差の大きい順に
  final picked = all.where((x) => won ? x.value > 0 : x.value < 0).toList()..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  return picked.take(3).toList();
}

/// 采配ごとの、その後3分(試合の時間)の得失点。
List<CallEffect> callEffectsOf(SimResult r, List<LiveCall> calls, int mineSide) => [
      for (final c in calls)
        () {
          final from = elapsedOf(c.period, c.clock), to = from + 180;
          var mine = 0, theirs = 0;
          for (final e in r.events) {
            final at = elapsedOf(e.period, e.clockStart);
            final pts = e.points;
            if (at >= from && at < to) {
              if (e.side == mineSide) {
                mine += pts;
              } else {
                theirs += pts;
              }
            }
          }
          return CallEffect(c, mine, theirs);
        }(),
    ];

/// 両チームの主役(ゲームスコアがいちばん高い選手)。(自分, 相手) の (名前, 点, リバウンド, アシスト)。
((String, int, int, int), (String, int, int, int)) starsOf(SimResult r, int mineSide) {
  (String, int, int, int) best(SimTeam t) {
    final lines = boxLinesOf(t)..sort((a, b) => b.gameScore.compareTo(a.gameScore));
    final l = lines.first;
    return (l.name, l.pts, l.reb, l.ast);
  }

  return (best(mineSide == 0 ? r.home : r.away), best(mineSide == 0 ? r.away : r.home));
}

/// 見せるための試合結果(ボックススコアの画面に渡す。リーグには数えない)。
GameResult reviewResultOf(SimResult sim, Team home, Team away, int mine) {
  final h = sim.home, a = sim.away;
  final mineHome = mine == home.index;
  return GameResult(
    home: home.index,
    away: away.index,
    homePts: h.pts,
    awayPts: a.pts,
    quarters: [...h.periods.take(4), ...a.periods.take(4)],
    overtime: [for (var k = 4; k < h.periods.length; k++) ...[h.periods[k], a.periods[k]]],
    box: boxLinesOf(mineHome ? h : a),
    oppBox: boxLinesOf(mineHome ? a : h),
    chance: winChance(home.strength, away.strength),
    homeStr: home.strength,
    awayStr: away.strength,
    flow: sim.flow,
    plays: sim.plays,
    leadChanges: sim.leadChanges,
    homeMaxLead: sim.homeMaxLead,
    awayMaxLead: sim.awayMaxLead,
  );
}

/// 流れの線に付ける印(試合の分と、ひとこと)。采配と、3Q以降の逆転。
List<(int, String, bool)> flowMarksOf(SimResult r, List<LiveCall> calls, String Function(LiveCall) callName) {
  final out = <(int, String, bool)>[
    for (final c in calls) (elapsedOf(c.period, c.clock) ~/ 60, callName(c), true),
  ];
  var lead = 0;
  for (final e in r.events) {
    final now = (e.homePts - e.awayPts).sign;
    if (now != 0 && lead != 0 && now != lead && e.period >= 2) {
      out.add((elapsedOf(e.period, e.clockEnd) ~/ 60, '逆転 ${e.awayPts}-${e.homePts}', false));
    }
    if (now != 0) lead = now;
  }
  return out;
}
