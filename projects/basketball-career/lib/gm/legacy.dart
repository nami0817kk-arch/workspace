import 'career.dart';
import 'personality.dart';
import 'player.dart';
import 'trade_ledger.dart';

/// GM の名鑑(2026-11-21 の作り込み D-1)。任期をまたいで残る「自分の歴史」。ごほうびは付けない(見返すためだけ)。
/// - 任期ごとの札(チーム・年数・成績の流れ・優勝・解任か勇退か)
/// - 育てた名選手の殿堂(通算・伸び方の型・特性・いちばんの年)
/// - 名場面の年表(自動で拾う)
/// 殿堂の選手は、次のリーグの歴史に「伝説の選手」として名前が残る。

/// 任期の札。
class TenureCard {
  const TenureCard({required this.team, required this.from, required this.to, required this.wins, required this.titles, required this.fired});
  final String team;
  final int from, to;

  /// シーズンごとの勝ち数(成績の流れ)。
  final List<int> wins;
  final int titles;
  final bool fired;

  Map<String, dynamic> toJson() => {'t': team, 'f': from, 'to': to, 'w': wins, 'c': titles, 'x': fired ? 1 : 0};
  static TenureCard fromJson(Map<String, dynamic> j) => TenureCard(
        team: j['t'] as String,
        from: j['f'] as int,
        to: j['to'] as int,
        wins: [for (final x in (j['w'] as List? ?? const [])) x as int],
        titles: (j['c'] as int?) ?? 0,
        fired: j['x'] == 1,
      );
}

/// 殿堂の選手。
class LegendCard {
  const LegendCard({required this.name, required this.pos, required this.pts, required this.seasons, required this.note, required this.best});
  final String name, pos, note, best;
  final int pts, seasons;

  Map<String, dynamic> toJson() => {'n': name, 'p': pos, 'pt': pts, 's': seasons, 'no': note, 'b': best};
  static LegendCard fromJson(Map<String, dynamic> j) =>
      LegendCard(name: j['n'] as String, pos: j['p'] as String, pts: j['pt'] as int, seasons: j['s'] as int, note: j['no'] as String, best: j['b'] as String);
}

/// [c] の任期の札(任期ごと)。
List<TenureCard> tenuresOf(Career c) {
  final out = <TenureCard>[];
  for (var i = 0; i < c.stints.length; i++) {
    final team = c.stints[i][0], from = c.stints[i][1];
    final to = i + 1 < c.stints.length ? c.stints[i + 1][1] - 1 : (c.history.isEmpty ? from : c.history.last.season);
    final recs = c.history.where((r) => r.season >= from && r.season <= to).toList();
    final last = i == c.stints.length - 1;
    out.add(TenureCard(
      team: c.teams[team].def.short,
      from: from,
      to: to,
      wins: [for (final r in recs) r.wins],
      titles: recs.where((r) => r.champion).length,
      fired: last ? c.fired : true,
    ));
  }
  return out;
}

/// [c] で育てた名選手(自分のチームで長く活躍した・自分で指名して力が80に届いた)。
List<LegendCard> legendsOf(Career c) {
  final all = <Player>[
    for (final t in c.teams) ...t.roster,
    ...c.freeAgents,
  ];
  final mineTeams = {for (final s in c.stints) s[0]};
  final out = <LegendCard>[];
  for (final p in all) {
    final withMe = p.career.where((x) => mineTeams.contains(x[1])).toList();
    final drafted = c.draftedIds.contains(p.id);
    final great = withMe.length >= 4 && (p.allStars >= 2 || p.careerTotals.pts >= 8000);
    if (!great && !(drafted && p.ovr >= 80)) continue;
    // いちばんの年(自分のチームで、平均の点がいちばん高い年)
    var best = '';
    var bp = -1.0;
    for (final x in withMe) {
      final ppg = x[2] == 0 ? 0.0 : x[3] / x[2];
      if (ppg > bp) {
        bp = ppg;
        best = '${x[0]}年目 ${ppg.toStringAsFixed(1)}点';
      }
    }
    final pers = personalityOf(p);
    out.add(LegendCard(
      name: p.name,
      pos: p.pos.short,
      pts: p.careerTotals.pts,
      seasons: withMe.length,
      note: [growthTypeOf(p).label, ...pers.traits.map((t) => t.label), if (drafted) '自分で指名'].join('・'),
      best: best,
    ));
  }
  out.sort((a, b) => b.pts.compareTo(a.pts));
  return out.take(8).toList();
}

/// [c] の名場面(自動で拾う。年表の古い順)。
List<String> momentsOf(Career c) {
  final out = <String>[];
  for (final r in c.history) {
    if (r.champion) out.add('${r.season}年目 ${c.teams[c.mine].def.short}で優勝');
    if (r.wins >= 60) out.add('${r.season}年目 ${r.wins}勝');
  }
  for (final a in c.awards) {
    if (a.team != c.mine) continue;
    if (a.kind == AwardKind.mvp || a.kind == AwardKind.finalsMvp) out.add('${a.season}年目 ${a.name}が${a.kind.label}');
  }
  final sc = c.scenarioOf;
  if (sc != null && c.scenarioResult == 1) out.add('お題「${sc.label}」を果たした');
  final (best, _) = c.tradeBestWorst;
  if (best != null) {
    final t = c.myTrades[best];
    final name = c.tradeNames[best];
    out.add('${t.season}年目 いちばんのトレード${name == null ? '' : '「$name」'}(${c.teams[t.partner].def.short}と・${tradeVerdict(c, t) == 1 ? '勝ち' : '五分'})');
  }
  return out;
}
