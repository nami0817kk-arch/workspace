import 'career.dart';
import 'inbox.dart';
import 'league.dart';

/// 試合を進める前の様子(進めたあとに比べて、報告を作る)。
class BlockSnapshot {
  BlockSnapshot._(this.wins, this.losses, this.confRank, this.logTop, this.maxMsg, this.round, this.block);

  factory BlockSnapshot.of(Career c) => BlockSnapshot._(
        c.me.wins,
        c.me.losses,
        c.confRank,
        c.log.isEmpty ? null : c.log.first,
        c.inbox.fold(0, (n, m) => m.id > n ? m.id : n),
        c.roundAt,
        c.block,
      );

  final int wins, losses, confRank, maxMsg, round, block;
  final String? logTop;
}

/// 進めた試合のまとめ。区切りを終えるたびに1枚で見せる。
class BlockReport {
  BlockReport({
    required this.fromGame,
    required this.toGame,
    required this.wins,
    required this.losses,
    required this.totalWins,
    required this.totalLosses,
    required this.rankBefore,
    required this.rankAfter,
    required this.east,
    required this.target,
    required this.pace,
    required this.highlights,
    required this.star,
    required this.myNews,
    required this.leagueNews,
    required this.newMail,
    required this.hasOffer,
    required this.deadlinePassed,
    this.deadlineTrades = const [],
    required this.seasonOver,
    required this.games,
  });

  /// この間の自分の試合。
  final List<GameResult> games;

  /// 何試合目から何試合目まで(1始まり)。
  final int fromGame, toGame;

  /// この間の勝ち負けと、シーズンの通算。
  final int wins, losses, totalWins, totalLosses;

  /// 地区の順位(進める前と後)。
  final int rankBefore, rankAfter;
  final bool east;

  /// オーナーの目標の勝ち数と、いまの勢いでの見込み。
  final int target, pace;

  final List<String> highlights;

  /// この間にいちばん点を取った選手(名前・1試合あたりの点・試合数)。
  final (String, double, int)? star;

  /// 自分のチームに関わる出来事と、リーグのほかの出来事。
  final List<String> myNews, leagueNews;

  /// 新しく届いた知らせ(返事が要るものが先)。
  final List<Message> newMail;

  /// トレードの申し込みが届いている。
  final bool hasOffer;

  /// この間にトレードの締め切りを過ぎた。
  final bool deadlinePassed;

  /// 締め切りを過ぎたとき: 今季のトレード(古い順。「トレード: 」は外してある)。
  final List<String> deadlineTrades;

  /// レギュラーシーズンが終わった(次はプレーオフ)。
  final bool seasonOver;

  int get played => wins + losses;

  /// [games] を渡さなければ、直前の区切りの試合のうち、進めた分(後ろから)を使う。
  static BlockReport make(Career c, BlockSnapshot s, [List<GameResult>? games]) {
    final me = c.me;
    final n = c.lastGames.length;
    games ??= c.lastGames.sublist(n - (me.wins + me.losses - s.wins - s.losses).clamp(0, n));
    final w = games.where((g) => g.winner == c.mine).length, l = games.length - w;
    // 新しい出来事(ログは新しい順に先頭へ入る。前の先頭の手前まで)
    final fresh = <String>[];
    for (final e in c.log) {
      if (identical(e, s.logTop)) break;
      final i = e.indexOf('年目 ');
      fresh.add(i >= 0 ? e.substring(i + 3) : e);
    }
    final mineShort = me.def.short;
    final myNews = <String>[];
    final leagueNews = <String>[];
    for (final e in fresh.reversed) {
      (e.contains(mineShort) ? myNews : leagueNews).add(e);
    }
    // 点を取った選手(この間の自分の試合のボックススコアから)
    final pts = <String, (int, int)>{};
    for (final g in games) {
      for (final b in g.box) {
        final x = pts[b.name] ?? (0, 0);
        pts[b.name] = (x.$1 + b.pts, x.$2 + 1);
      }
    }
    (String, double, int)? star;
    for (final e in pts.entries) {
      final avg = e.value.$1 / e.value.$2;
      if (e.value.$2 >= (games.length / 2).ceil() && (star == null || avg > star.$2)) star = (e.key, avg, e.value.$2);
    }
    final played = me.wins + me.losses;
    final deadlinePassed = s.block < tradeDeadlineBlock && c.block >= tradeDeadlineBlock;
    final prefix = '${c.season}年目 トレード: ';
    final deadlineTrades = deadlinePassed ? [for (final l in c.log.reversed) if (l.startsWith(prefix)) l.substring(prefix.length)] : const <String>[];
    final mail = [for (final m in c.inbox) if (m.id > s.maxMsg) m]..sort((a, b) => (b.needsAnswer ? 1 : 0) - (a.needsAnswer ? 1 : 0));
    return BlockReport(
      fromGame: c.roundAt - games.length + 1,
      toGame: c.roundAt,
      wins: w,
      losses: l,
      totalWins: me.wins,
      totalLosses: me.losses,
      rankBefore: s.confRank,
      rankAfter: c.confRank,
      east: me.east,
      target: c.target,
      pace: played == 0 ? 0 : (me.wins * gamesPerSeason / played).round(),
      highlights: c.highlightsOf(games).take(5).toList(),
      star: star,
      myNews: myNews,
      leagueNews: leagueNews,
      newMail: mail,
      hasOffer: c.incoming != null,
      deadlinePassed: deadlinePassed,
      deadlineTrades: deadlineTrades,
      seasonOver: c.phase == Phase.playoffs,
      games: games,
    );
  }
}
