import 'career.dart';
import 'player.dart';

/// オフの契約を「見せる」ための計算(自由契約の日ごとの発表・オフのまとめ)。
/// どれも乱数を使わない(リーグの続きを変えない)。

/// 日を進める前の、自分の申し込みの様子。
class FaSnapshot {
  FaSnapshot({required this.day, required this.mine, required this.hadSheet});
  final int day;

  /// 申し込み中の選手の id → (選ばれる見込み, ほかの申し込みの数)。
  final Map<int, ({double chance, int rivals})> mine;
  final bool hadSheet;
}

FaSnapshot faSnapshot(Career c) => FaSnapshot(
      day: c.faDay,
      hadSheet: c.sheet != null,
      mine: {
        for (final p in c.freeAgents)
          if (c.myBid(p.id) != null) p.id: (chance: c.winChanceOf(p), rivals: c.rivalBids(p.id)),
      },
    );

/// 自分が申し込んでいた選手の、その日の結果。
enum BidOutcome { signed, lost, pending, dropped }

class BidResult {
  BidResult({required this.name, required this.ovr, required this.outcome, this.move, this.chanceBefore = 0, this.chanceAfter = 0, this.rivalsBefore = 0, this.rivalsAfter = 0});
  final String name;
  final int ovr;
  final BidOutcome outcome;

  /// 決まった契約(取った・取られた)。
  final FaMove? move;
  final double chanceBefore, chanceAfter;
  final int rivalsBefore, rivalsAfter;
}

/// 自由契約の1日の発表。
class FaDayReport {
  FaDayReport({required this.day, required this.mine, required this.signed, required this.newSheet, required this.daysLeft, required this.open});

  /// 終わった日(1始まり)。
  final int day;
  final List<BidResult> mine;

  /// この日に決まった契約(力の高い順)。
  final List<FaMove> signed;

  /// この日にオファーシートが届いたか。
  final bool newSheet;
  final int daysLeft;

  /// まだ決まっていない大物(力の高い順、上から3人)と、申し込んだチームの数。
  final List<(Player, int)> open;
}

FaDayReport faDayReport(Career c, FaSnapshot s) {
  final today = c.faMoves.where((m) => m.day == s.day).toList()..sort((a, b) => b.ovr.compareTo(a.ovr));
  final mine = <BidResult>[];
  for (final e in s.mine.entries) {
    final move = c.faMoves.where((m) => m.id == e.key).lastOrNull;
    final fa = c.freeAgents.where((p) => p.id == e.key).firstOrNull;
    final p = fa ?? _find(c, e.key);
    if (p == null) continue;
    if (move != null) {
      mine.add(BidResult(name: p.name, ovr: p.ovr, outcome: move.team == c.mine ? BidOutcome.signed : BidOutcome.lost, move: move));
    } else if (fa != null && c.myBid(e.key) != null) {
      mine.add(BidResult(
          name: p.name,
          ovr: p.ovr,
          outcome: BidOutcome.pending,
          chanceBefore: e.value.chance,
          chanceAfter: c.winChanceOf(fa),
          rivalsBefore: e.value.rivals,
          rivalsAfter: c.rivalBids(e.key)));
    } else {
      // 申し込みが消えた(登録や上限が埋まって取れなくなった、オファーシートで残る話になった など)
      mine.add(BidResult(name: p.name, ovr: p.ovr, outcome: BidOutcome.dropped));
    }
  }
  final open = [for (final p in c.freeAgents) if (c.isBigFa(p)) (p, c.bids[p.id]?.length ?? 0)]..sort((a, b) => b.$1.ovr.compareTo(a.$1.ovr));
  return FaDayReport(
    day: s.day + 1,
    mine: mine,
    signed: today,
    newSheet: !s.hadSheet && c.sheet != null,
    daysLeft: faDays - c.faDay,
    open: open.take(3).toList(),
  );
}

Player? _find(Career c, int id) {
  for (final t in c.teams) {
    for (final p in t.roster) {
      if (p.id == id) return p;
    }
  }
  for (final p in [...c.freeAgents, ...c.me.twoWay]) {
    if (p.id == id) return p;
  }
  return null;
}

/// オフで入れ替わった選手1人。
class OffChange {
  OffChange({required this.p, required this.how});
  final Player p;

  /// 入った: ドラフト・自由契約・トレード・2ウェイから。出た: 行き先。
  final String how;
}

/// オフのまとめ。
class OffSummary {
  OffSummary({required this.arrived, required this.left, required this.rankBefore, required this.rankAfter, required this.bigMoves});
  final List<OffChange> arrived, left;

  /// 強さの順位(0が1位。オフに入ったときと今)。オフに入ったときが分からなければ -1。
  final int rankBefore, rankAfter;

  /// リーグの大きな移籍(力の高い順、上から6件。自分のチームも含む)。
  final List<FaMove> bigMoves;
}

OffSummary offSummary(Career c) {
  final start = c.offStartIds.toSet();
  final nowIds = {for (final p in c.me.roster) p.id};
  final faTo = {for (final m in c.faMoves) m.id: m.team};
  final arrived = <OffChange>[
    for (final p in c.me.roster)
      if (!start.contains(p.id))
        OffChange(
            p: p,
            how: faTo[p.id] == c.mine
                ? '自由契約'
                : c.draftedIds.contains(p.id) && p.exp <= 1
                    ? 'ドラフト'
                    : 'トレード'),
  ]..sort((a, b) => b.p.ovr.compareTo(a.p.ovr));
  final left = <OffChange>[];
  for (final id in start) {
    if (nowIds.contains(id)) continue;
    final p = _find(c, id);
    if (p == null) continue;
    String how;
    if (c.me.twoWay.contains(p)) {
      how = '2ウェイへ';
    } else if (c.freeAgents.contains(p)) {
      how = '自由契約のまま';
    } else {
      final t = c.teams.firstWhere((t) => t.roster.contains(p));
      how = '${faTo[id] == t.index ? '自由契約で' : 'トレードで'}${t.def.short}へ';
    }
    left.add(OffChange(p: p, how: how));
  }
  left.sort((a, b) => b.p.ovr.compareTo(a.p.ovr));
  final big = [...c.faMoves]..sort((a, b) => b.ovr.compareTo(a.ovr));
  return OffSummary(
    arrived: arrived,
    left: left,
    rankBefore: c.offStartIds.isEmpty ? -1 : c.offStartRank,
    rankAfter: c.strengthRank(c.mine),
    bigMoves: big.take(6).toList(),
  );
}
