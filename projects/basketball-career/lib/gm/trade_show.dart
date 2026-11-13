import 'career.dart';
import 'league.dart';
import 'player.dart';
import 'trade.dart';

/// トレードの成立を「見せる」ための計算(成立前の様子と、成立後の比べ)。乱数は使わない。

/// 成立させる前の様子。
class TradeSnap {
  TradeSnap._({
    required this.partner,
    required this.give,
    required this.get,
    required this.givePicks,
    required this.getPicks,
    required this.rank,
    required this.partnerRank,
    required this.payroll,
    required this.starters,
    required this.valueOut,
    required this.valueIn,
  });

  final int partner;
  final List<Player> give, get;

  /// 指名権の名前(成立すると持ち主が変わるので、先に作っておく)。
  final List<String> givePicks, getPicks;

  /// 強さの順位(0が1位)。
  final int rank, partnerRank;
  final int payroll;

  /// 先発5人(id)。
  final List<int> starters;

  /// 自分のチームの目から見た、出すものと受け取るものの値打ち。
  final double valueOut, valueIn;
}

TradeSnap tradeSnap(Career c, TradeOffer o) {
  final me = c.me, other = c.teams[o.partner];
  final give = [for (final id in o.give) ...me.roster.where((p) => p.id == id)];
  final get = [for (final id in o.get) ...other.roster.where((p) => p.id == id)];
  double picksValue(List<int> ix) => ix.fold(0.0, (s, i) => s + pickValue(c.picks[i], me.mode, slotGuess(c.teams, c.picks[i].from), c.season));
  return TradeSnap._(
    partner: o.partner,
    give: give,
    get: get,
    givePicks: [for (final i in o.givePicks) c.picks[i].label(c.teams, c.season)],
    getPicks: [for (final i in o.getPicks) c.picks[i].label(c.teams, c.season)],
    rank: c.strengthRank(c.mine),
    partnerRank: c.strengthRank(o.partner),
    payroll: me.payroll,
    starters: [for (final p in me.order.take(5)) p.id],
    valueOut: give.fold(0.0, (s, p) => s + playerValue(p, me.mode)) + picksValue(o.givePicks),
    valueIn: get.fold(0.0, (s, p) => s + playerValue(p, me.mode)) + picksValue(o.getPicks),
  );
}

/// 成立したトレードの比べ。
class TradeResult {
  TradeResult({
    required this.snap,
    required this.rankAfter,
    required this.partnerRankAfter,
    required this.payrollAfter,
    required this.newStarters,
    required this.lostStarters,
    required this.grade,
    required this.label,
    required this.note,
  });

  final TradeSnap snap;
  final int rankAfter, partnerRankAfter, payrollAfter;

  /// 先発に入った選手と、先発から外れた選手の名前。
  final List<String> newStarters, lostStarters;

  /// 値打ちの釣り合いの評価(A〜D)と、その言葉・ひとこと。
  final String grade, label, note;
}

TradeResult tradeResult(Career c, TradeSnap s) {
  final me = c.me;
  final now = [for (final p in me.order.take(5)) p.id];
  String nameOf(int id) {
    for (final p in [...me.roster, ...s.give]) {
      if (p.id == id) return p.name;
    }
    return '';
  }

  final ratio = s.valueOut <= 0 ? (s.valueIn > 0 ? 2.0 : 1.0) : s.valueIn / s.valueOut;
  final (grade, label) = ratio >= 1.3
      ? ('A', '大きく得した')
      : ratio >= 1.05
          ? ('B', '少し得した')
          : ratio >= 0.85
              ? ('C', '釣り合い')
              : ('D', '払いすぎ');
  final modeNote = switch (me.mode) {
    TeamMode.contend => '今勝つ方針で見た値打ち(今の力を重く見る)',
    TeamMode.rebuild => '立て直しの方針で見た値打ち(若さと指名権を重く見る)',
    TeamMode.cutCost => '節約の方針で見た値打ち(年俸の安さを重く見る)',
    TeamMode.balanced => 'バランスの方針で見た値打ち',
  };
  return TradeResult(
    snap: s,
    rankAfter: c.strengthRank(c.mine),
    partnerRankAfter: c.strengthRank(s.partner),
    payrollAfter: me.payroll,
    newStarters: [for (final id in now) if (!s.starters.contains(id)) nameOf(id)],
    lostStarters: [for (final id in s.starters) if (!now.contains(id)) nameOf(id)],
    grade: grade,
    label: label,
    note: modeNote,
  );
}
