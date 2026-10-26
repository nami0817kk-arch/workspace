import 'dart:math';

import 'rival.dart';
import 'season.dart';

/// 順位表の1行。
class Standing {
  const Standing(this.name, this.wins, this.losses, {this.isUs = false});
  final String name;
  final int wins;
  final int losses;
  final bool isUs;
}

/// リーグ戦(予選)のチーム数と、決勝トーナメント(プレーオフ)に進める順位。
int leagueTeams(League l) => l == League.national ? 4 : 8;
int playoffSpots(League l) => l == League.national ? 2 : 4;

/// リーグ戦(予選)の順位表。勝ち抜き戦では null。
///
/// 他のチームの成績は作り物だが、自分と戦った相手には自分との勝敗を入れ、
/// 「決勝トーナメントに進んだか」と「順位が進出圏か」が必ず食い違わないようにそろえる。
/// 同じ大会の結果からは、いつも同じ表になる(乱数の種を試合の結果から作る)。
List<Standing>? standingsOf(TournamentResult t, {String usName = '自チーム'}) {
  final l = t.league;
  if (l.playoffRounds == 0) return null;
  final regular = t.matches.take(l.rounds).toList();
  if (regular.length < l.rounds) return null;
  final seed = regular.fold<int>(
      l.index * 7919, (s, m) => (s * 31 + m.teamScore * 3 + m.oppScore) & 0x3fffffff);
  final rng = Random(seed);

  // 自分と戦った相手(重複は1チーム)と、そのチームとの勝敗。
  final vsUs = <String, ({int w, int l})>{};
  for (final m in regular) {
    final name = m.opponent.isEmpty ? opponentTeamName(l, rng) : m.opponent;
    final prev = vsUs[name] ?? (w: 0, l: 0);
    // 相手から見た勝敗(自分が勝てば相手の負け)。
    vsUs[name] = m.won ? (w: prev.w, l: prev.l + 1) : (w: prev.w + 1, l: prev.l);
  }
  final names = [...vsUs.keys];
  var guard = 0;
  while (names.length < leagueTeams(l) - 1 && guard++ < 200) {
    final n = opponentTeamName(l, rng);
    if (!names.contains(n) && n != usName) names.add(n);
  }

  final usW = t.regularWins, usL = l.rounds - t.regularWins;
  final others = <Standing>[];
  for (final n in names.take(leagueTeams(l) - 1)) {
    final h2h = vsUs[n] ?? (w: 0, l: 0);
    final rest = max(0, l.rounds - h2h.w - h2h.l);
    final p = 0.2 + rng.nextDouble() * 0.6;
    var w = h2h.w;
    for (var i = 0; i < rest; i++) {
      if (rng.nextDouble() < p) w++;
    }
    others.add(Standing(n, w, l.rounds - w));
  }

  // 進出したかと順位をそろえる。
  final qualified = t.reachedPlayoffs;
  final spots = playoffSpots(l);
  others.sort((a, b) => b.wins.compareTo(a.wins));
  if (qualified) {
    // 自分より勝ち数が多いチームは spots-1 まで。超えた分は自分と同じ勝ち数に(並べば自分が上)。
    for (var i = spots - 1; i < others.length; i++) {
      if (others[i].wins > usW) {
        others[i] = Standing(others[i].name, usW, l.rounds - usW);
      }
    }
  } else {
    // 自分より上(並びは相手が上)のチームを spots 以上にする。
    for (var i = 0; i < spots && i < others.length; i++) {
      if (others[i].wins < usW) {
        others[i] = Standing(others[i].name, usW, l.rounds - usW);
      }
    }
  }
  final us = Standing(usName, usW, usL, isUs: true);
  final all = [...others, us];
  all.sort((a, b) {
    final c = b.wins.compareTo(a.wins);
    if (c != 0) return c;
    // 並んだときは、進出したなら自分が上、進めなかったなら相手が上。
    if (a.isUs) return qualified ? -1 : 1;
    if (b.isUs) return qualified ? 1 : -1;
    return 0;
  });
  return all;
}

/// 順位表での自分の順位(1 始まり)。
int? ourRank(List<Standing>? table) {
  if (table == null) return null;
  final i = table.indexWhere((s) => s.isUs);
  return i < 0 ? null : i + 1;
}
