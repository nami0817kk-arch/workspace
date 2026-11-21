import 'career.dart';
import 'league.dart';
import 'player.dart';
import 'trade.dart';

/// トレードの勝ち負け(2026-11-21 の作り込み T-4・T-6)。取引のあとの選手の今の値打ちで比べる。

/// 1件のトレードの今の値打ち。(こちらが得たもの, 相手が得たもの)。指名権は1本12で数える。
/// 選手がもういない(引退など)ときは、記録した力で数える。
(double, double) tradeValues(Career c, MyTrade t) {
  final all = <int, Player>{
    for (final team in c.teams) ...{for (final p in [...team.roster, ...team.twoWay]) p.id: p},
    for (final p in c.freeAgents) p.id: p,
  };
  double value(List<(int, String, int)> list) {
    var v = 0.0;
    for (final (id, _, ovr) in list) {
      final p = all[id];
      if (p != null) {
        v += playerValue(p, TeamMode.balanced).clamp(0.0, 1e9);
      } else {
        final x = (ovr - 45).clamp(0, 99);
        v += x * x / 10 * 0.5;
      }
    }
    return v;
  }

  return (value(t.get) + t.getPicks * 12, value(t.give) + t.givePicks * 12);
}

/// こちらから見たトレードの判定(1 勝ち・0 五分・-1 負け)。まだ1年たっていなければ null(判定まだ)。
int? tradeVerdict(Career c, MyTrade t) {
  if (c.season <= t.season) return null;
  final (mine, theirs) = tradeValues(c, t);
  final total = mine + theirs;
  if (total <= 0) return 0;
  final d = (mine - theirs) / total;
  return d > 0.15
      ? 1
      : d < -0.15
          ? -1
          : 0;
}
