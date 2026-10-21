import 'dart:math';

import 'at_bat.dart';
import 'player.dart';
import 'traits.dart';

/// 1試合(または大会・シーズン通算)の個人成績。打者として/投手として、それぞれ数える。
class Line {
  const Line({
    this.games = 0,
    this.atBats = 0,
    this.hits = 0,
    this.totalBases = 0,
    this.walks = 0,
    this.homeRuns = 0,
    this.faced = 0,
    this.outs = 0,
    this.strikeouts = 0,
    this.walksGiven = 0,
    this.hitsAllowed = 0,
    this.homeRunsAllowed = 0,
    this.runsRaw = 0,
    this.starts = 0,
    this.wins = 0,
    this.losses = 0,
    this.doubles = 0,
    this.triples = 0,
    this.battingStrikeouts = 0,
    this.rbi = 0,
    this.stolenBases = 0,
  });

  /// 出場した試合数(打者または投手として)。
  final int games;

  // 打者
  final int atBats, hits, totalBases, walks, homeRuns;

  /// 打者の詳しい記録: 二塁打・三塁打・三振・打点・盗塁。
  final int doubles, triples, battingStrikeouts, rbi, stolenBases;

  // 投手
  final int faced, outs, strikeouts, walksGiven, hitsAllowed, homeRunsAllowed;

  /// 失点の推定の素(出来事ごとの得点価値の合計)。実際の失点は [runsAllowed]。
  final double runsRaw;
  final int starts, wins, losses;

  Line operator +(Line o) => Line(
        games: games + o.games,
        atBats: atBats + o.atBats,
        hits: hits + o.hits,
        totalBases: totalBases + o.totalBases,
        walks: walks + o.walks,
        homeRuns: homeRuns + o.homeRuns,
        faced: faced + o.faced,
        outs: outs + o.outs,
        strikeouts: strikeouts + o.strikeouts,
        walksGiven: walksGiven + o.walksGiven,
        hitsAllowed: hitsAllowed + o.hitsAllowed,
        homeRunsAllowed: homeRunsAllowed + o.homeRunsAllowed,
        runsRaw: runsRaw + o.runsRaw,
        starts: starts + o.starts,
        wins: wins + o.wins,
        losses: losses + o.losses,
        doubles: doubles + o.doubles,
        triples: triples + o.triples,
        battingStrikeouts: battingStrikeouts + o.battingStrikeouts,
        rbi: rbi + o.rbi,
        stolenBases: stolenBases + o.stolenBases,
      );

  Line withDecision({bool win = false, bool loss = false}) => Line(
        games: games,
        atBats: atBats,
        hits: hits,
        totalBases: totalBases,
        walks: walks,
        homeRuns: homeRuns,
        faced: faced,
        outs: outs,
        strikeouts: strikeouts,
        walksGiven: walksGiven,
        hitsAllowed: hitsAllowed,
        homeRunsAllowed: homeRunsAllowed,
        runsRaw: runsRaw,
        starts: starts,
        wins: wins + (win ? 1 : 0),
        losses: losses + (loss ? 1 : 0),
        doubles: doubles,
        triples: triples,
        battingStrikeouts: battingStrikeouts,
        rbi: rbi,
        stolenBases: stolenBases,
      );

  // ── 打者の指標 ──
  bool get hasBatting => atBats + walks > 0;
  int get plateAppearances => atBats + walks;
  double? get battingAverage => atBats == 0 ? null : hits / atBats;
  double? get onBase =>
      plateAppearances == 0 ? null : (hits + walks) / plateAppearances;
  double? get slugging => atBats == 0 ? null : totalBases / atBats;
  double? get ops => hasBatting ? (onBase ?? 0) + (slugging ?? 0) : null;

  /// 長打率 − 打率(長打を打つ力だけを見る)。
  double? get isolatedPower =>
      atBats == 0 ? null : (slugging ?? 0) - (battingAverage ?? 0);

  /// 打席あたりの四球率・三振率。
  double? get walkRate =>
      plateAppearances == 0 ? null : walks / plateAppearances;
  double? get strikeoutRate =>
      plateAppearances == 0 ? null : battingStrikeouts / plateAppearances;

  /// 三振1つあたりの四球(選球眼の指標)。
  double? get walkPerStrikeout =>
      battingStrikeouts == 0 ? null : walks / battingStrikeouts;

  /// OPS+ ふうの指標。リーグ平均(OPS .720)を100として、何倍か。
  /// 打席が少ない(20未満)と、指標が極端になるので出さない。
  int? get opsPlus => ops == null || plateAppearances < 20
      ? null
      : (100 * ops! / leagueOps).round().clamp(0, 999);

  // ── 投手の指標 ──
  bool get hasPitching => faced > 0;

  /// 失点の推定。打球の結果ごとの得点価値から作る(走者の動きまでは再現しない)。
  double get runsAllowed => max(0, runsRaw + runBaseline * faced);
  double get inningsPitched => outs / 3;

  /// 「123回1/3」の形。
  String get inningsText {
    final r = outs % 3;
    return '${outs ~/ 3}${r == 0 ? '' : ' $r/3'}';
  }

  /// 防御率。**30回以上投げた(90アウト〜)ときは、下限 `minSeasonEra`**(現実の記録でも1点を切る年はほぼ無い。
  /// 失点の推定が0になるほど抑えた選手が「防御率0.00」で1シーズン投げ切るのを防ぐ)。
  /// 1試合や1か月の防御率は、0.00になりうる。勝敗(`decidedStart`)は下限を使わない失点で決める。
  double? get era {
    if (outs == 0) return null;
    final e = runsAllowed * 27 / outs;
    return outs >= 90 ? max(e, minSeasonEra) : e;
  }

  /// WHIP(1回あたりに出した走者の数)。
  double? get whip =>
      outs == 0 ? null : (walksGiven + hitsAllowed) / inningsPitched;

  /// 9回あたりの奪三振・与四球・被本塁打。
  double? get strikeoutsPer9 => outs == 0 ? null : strikeouts * 27 / outs;
  double? get walksPer9 => outs == 0 ? null : walksGiven * 27 / outs;
  double? get homeRunsPer9 => outs == 0 ? null : homeRunsAllowed * 27 / outs;

  /// 与四球1つあたりの奪三振。
  double? get strikeoutPerWalk =>
      walksGiven == 0 ? null : strikeouts / walksGiven;

  /// 被打率(打者のうち、四球を除いた対戦での被安打の割合)。
  double? get battingAverageAgainst {
    final ab = faced - walksGiven;
    return ab <= 0 ? null : hitsAllowed / ab;
  }

  /// 勝率。勝ち負けがあれば。
  double? get winRate => wins + losses == 0 ? null : wins / (wins + losses);

  /// ERA+ ふうの指標。リーグ平均(防御率3.90)を100として、何倍良いか。
  /// 投球回が少ない(9回未満)と、指標が極端になるので出さない。
  int? get eraPlus => era == null || era! <= 0 || outs < 27
      ? null
      : (100 * leagueEra / era!).round().clamp(0, 999);

  /// 打者としての評価 0〜100(50 が平均)。打席が無ければ null。
  double? get battingRating {
    if (atBats == 0) return null;
    final v = (totalBases + 0.5 * walks) / (atBats + walks); // 平均でおよそ 0.35
    return (50 + (v - 0.35) * 120).clamp(0, 100).toDouble();
  }

  /// 投手としての評価 0〜100(50 が平均)。対戦が無ければ null。
  double? get pitchingRating {
    if (faced == 0) return null;
    final v = (strikeouts - walksGiven - hitsAllowed - homeRunsAllowed) / faced;
    return (50 + (v + 0.10) * 150).clamp(0, 100).toDouble();
  }

  /// 個人の評価。二刀流は両方の平均。
  double get rating {
    final r = [battingRating, pitchingRating].whereType<double>().toList();
    return r.isEmpty ? 50 : r.reduce((a, b) => a + b) / r.length;
  }

  Map<String, dynamic> toJson() => {
        'games': games,
        'atBats': atBats,
        'hits': hits,
        'totalBases': totalBases,
        'walks': walks,
        'homeRuns': homeRuns,
        'faced': faced,
        'outs': outs,
        'strikeouts': strikeouts,
        'walksGiven': walksGiven,
        'hitsAllowed': hitsAllowed,
        'homeRunsAllowed': homeRunsAllowed,
        'runsRaw': runsRaw,
        'starts': starts,
        'wins': wins,
        'losses': losses,
        'doubles': doubles,
        'triples': triples,
        'battingStrikeouts': battingStrikeouts,
        'rbi': rbi,
        'stolenBases': stolenBases,
      };

  /// 項目を足すときは既定値を置く。
  factory Line.fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return Line(
      games: i('games'),
      atBats: i('atBats'),
      hits: i('hits'),
      totalBases: i('totalBases'),
      walks: i('walks'),
      homeRuns: i('homeRuns'),
      faced: i('faced'),
      outs: i('outs'),
      strikeouts: i('strikeouts'),
      walksGiven: i('walksGiven'),
      hitsAllowed: i('hitsAllowed'),
      homeRunsAllowed: i('homeRunsAllowed'),
      runsRaw: (j['runsRaw'] as num?)?.toDouble() ?? 0,
      starts: i('starts'),
      wins: i('wins'),
      losses: i('losses'),
      doubles: i('doubles'),
      triples: i('triples'),
      battingStrikeouts: i('battingStrikeouts'),
      rbi: i('rbi'),
      stolenBases: i('stolenBases'),
    );
  }
}

/// リーグ平均のOPSと防御率(OPS+・ERA+ の基準)。
const leagueOps = 0.720;
const leagueEra = 3.90;

/// 1打席あたりに足す、失点推定の基準値(平均的な環境で防御率が4点前後になる値)。
const runBaseline = 0.10;

/// シーズン(30回以上)の防御率の下限。
const minSeasonEra = 0.90;

/// その打席の打点(走者の動きは再現しないので、結果ごとの確率で決める)。
int _rbiOf(AtBatResult r, Random rng) {
  final x = rng.nextDouble();
  return switch (r) {
    AtBatResult.homeRun => 1 + (x < 0.40 ? 1 : 0) + (x < 0.12 ? 1 : 0),
    AtBatResult.triple => x < 0.55 ? 1 : 0,
    AtBatResult.double => x < 0.50 ? (x < 0.12 ? 2 : 1) : 0,
    AtBatResult.single => x < 0.28 ? (x < 0.05 ? 2 : 1) : 0,
    _ => 0,
  };
}

/// 結果ごとの得点価値(平均的なアウトとの差。アウトは負)。
double _runValue(AtBatResult r) => switch (r) {
      AtBatResult.walk => 0.33,
      AtBatResult.single => 0.47,
      AtBatResult.double => 0.78,
      AtBatResult.triple => 1.09,
      AtBatResult.homeRun => 1.40,
      AtBatResult.out || AtBatResult.strikeout => -0.27,
    };

const _batterTurns = 4; // 1試合の打席
const _pitcherFaced = 18; // 1試合の対戦打者(先発1人ぶんの目安)

/// 相手の強さ `opp`(0〜99)で1試合ぶんの個人成績を出す。
/// `bat` / `pitch` で、その試合に打つか・投げるかを絞れる(先発ローテーションなど)。
/// `facedBase` は投手の対戦打者数の基準(スタミナで増減する)。
Line playGame(
  Player p,
  int opp,
  Random rng, {
  bool bat = true,
  bool pitch = true,
  int facedBase = _pitcherFaced,
}) {
  var line = const Line();
  var appeared = false;
  var started = 0;
  if (bat && p.role != Role.pitcher) {
    appeared = true;
    final foe = Pitcher(control: opp, stuff: opp);
    for (var i = 0; i < _batterTurns; i++) {
      final r = simulateAtBat(foe, p.toBatter(), rng);
      final onBase = r == AtBatResult.walk || r == AtBatResult.single;
      line += Line(
        doubles: r == AtBatResult.double ? 1 : 0,
        triples: r == AtBatResult.triple ? 1 : 0,
        battingStrikeouts: r == AtBatResult.strikeout ? 1 : 0,
        rbi: _rbiOf(r, rng),
        // 出塁したあとの盗塁。走力が高いほど走る。
        stolenBases: onBase &&
                rng.nextDouble() <
                    ((p.of(Ability.speed) - 35) / 300).clamp(0.0, 0.2)
            ? 1
            : 0,
        atBats: r == AtBatResult.walk ? 0 : 1,
        hits: const {
          AtBatResult.single,
          AtBatResult.double,
          AtBatResult.triple,
          AtBatResult.homeRun,
        }.contains(r)
            ? 1
            : 0,
        walks: r == AtBatResult.walk ? 1 : 0,
        totalBases: switch (r) {
          AtBatResult.single => 1,
          AtBatResult.double => 2,
          AtBatResult.triple => 3,
          AtBatResult.homeRun => 4,
          _ => 0,
        },
        homeRuns: r == AtBatResult.homeRun ? 1 : 0,
      );
    }
  }
  if (pitch && p.role != Role.batter) {
    appeared = true;
    started = 1;
    final foe = Batter(contact: opp, power: opp, eye: opp);
    // スタミナが低いと長く投げられない(対戦数が減る)。
    final faced = (facedBase * (0.5 + p.of(Ability.stamina) / 200)).round();
    for (var i = 0; i < faced; i++) {
      final r = simulateAtBat(p.toPitcher(), foe, rng);
      line += Line(
        faced: 1,
        outs: (r == AtBatResult.out || r == AtBatResult.strikeout) ? 1 : 0,
        strikeouts: r == AtBatResult.strikeout ? 1 : 0,
        walksGiven: r == AtBatResult.walk ? 1 : 0,
        hitsAllowed: const {
          AtBatResult.single,
          AtBatResult.double,
          AtBatResult.triple,
        }.contains(r)
            ? 1
            : 0,
        homeRunsAllowed: r == AtBatResult.homeRun ? 1 : 0,
        runsRaw: _runValue(r),
      );
    }
  }
  return appeared ? line + Line(games: 1, starts: started) : line;
}

/// 大会(トーナメント)の結果。
class Tournament {
  const Tournament(
      {required this.roundsWon,
      required this.rounds,
      required this.line,
      this.games = const []});
  final int roundsWon;
  final int rounds;
  final Line line;

  /// 各試合の中身(相手の強さ・勝ったか・個人の成績)。
  final List<TournamentGame> games;

  bool get champion => roundsWon == rounds;

  /// 実績 0〜100。大会の勝ち上がり6割・個人の評価4割。
  /// `isDrafted` / `draftScore` の `achievement` に渡す。
  double get achievement =>
      100 * (0.6 * roundsWon / rounds) + 0.4 * line.rating;
}

/// 勝ち抜き戦の1試合。
class TournamentGame {
  const TournamentGame(
      {required this.opponent, required this.won, required this.line});
  final int opponent;
  final bool won;
  final Line line;
}

/// 自チームの強さ `teamLevel` で、`opponents` の順に戦う勝ち抜き戦。
/// 勝つ確率は、チーム力の差・その試合での個人の出来・体調 `condition`(0〜100、50が普通)で決まる。
/// 負けたら終わり。
Tournament playTournament(
  Player p, {
  required int teamLevel,
  required List<int> opponents,
  required Random rng,
  int condition = 50,
}) {
  var line = const Line();
  var won = 0;
  final games = <TournamentGame>[];
  for (final opp in opponents) {
    final g = playGame(p, opp, rng);
    line += g;
    final pWin = (0.5 +
            (teamLevel - opp) / 100 +
            (g.rating - 50) / 200 +
            (condition + tournamentBonus(p.traits) - 50) / 500)
        .clamp(0.0, 1.0);
    final roll = rng.nextDouble();
    final win = isShutout(g) || roll < pWin;
    games.add(TournamentGame(opponent: opp, won: win, line: g));
    if (!win) break;
    won++;
  }
  return Tournament(
      roundsWon: won, rounds: opponents.length, line: line, games: games);
}

/// 決勝の直前まで進めた途中経過。決勝で「見せ場の決断」を選べるように、決勝の勝ち負けだけ未決にしてある。
/// (決勝の個人成績 `finalLine` は先に決めてあり、決断で変わるのは勝つ確率 `pWin` だけ)。
class FinalMoment {
  const FinalMoment({
    required this.games,
    required this.line,
    required this.roundsWon,
    required this.rounds,
    required this.opponent,
    required this.finalLine,
    required this.pWin,
  });

  /// 決勝の前までの試合(全部勝っている)。
  final List<TournamentGame> games;
  final Line line;
  final int roundsWon;
  final int rounds;
  final int opponent;
  final Line finalLine;
  final double pWin;

  Map<String, dynamic> toJson() => {
        'games': [
          for (final g in games)
            {'opponent': g.opponent, 'won': g.won, 'line': g.line.toJson()}
        ],
        'line': line.toJson(),
        'roundsWon': roundsWon,
        'rounds': rounds,
        'opponent': opponent,
        'finalLine': finalLine.toJson(),
        'pWin': pWin,
      };

  factory FinalMoment.fromJson(Map<String, dynamic> j) => FinalMoment(
        games: [
          for (final g in (j['games'] as List? ?? const []))
            TournamentGame(
              opponent: ((g as Map)['opponent'] as num).toInt(),
              won: g['won'] == true,
              line: Line.fromJson((g['line'] as Map).cast<String, dynamic>()),
            )
        ],
        line: Line.fromJson((j['line'] as Map).cast<String, dynamic>()),
        roundsWon: (j['roundsWon'] as num).toInt(),
        rounds: (j['rounds'] as num).toInt(),
        opponent: (j['opponent'] as num).toInt(),
        finalLine:
            Line.fromJson((j['finalLine'] as Map).cast<String, dynamic>()),
        pWin: (j['pWin'] as num).toDouble(),
      );
}

/// `playTournamentToFinal` の結果。決勝まで進んだら `moment`(決勝は未決)、そこで負けていたら `done`。
class TournamentProgress {
  const TournamentProgress({this.done, this.moment});
  final Tournament? done;
  final FinalMoment? moment;
}

/// `playTournament` と同じ順で、**決勝の勝ち負けの手前まで**進める。
/// 決勝より前で負ければ、その結果(`done`)を返す。決勝まで来たら `moment`。
TournamentProgress playTournamentToFinal(
  Player p, {
  required int teamLevel,
  required List<int> opponents,
  required Random rng,
  int condition = 50,
}) {
  var line = const Line();
  var won = 0;
  final games = <TournamentGame>[];
  for (var i = 0; i < opponents.length; i++) {
    final opp = opponents[i];
    final g = playGame(p, opp, rng);
    final pWin = (0.5 +
            (teamLevel - opp) / 100 +
            (g.rating - 50) / 200 +
            (condition + tournamentBonus(p.traits) - 50) / 500)
        .clamp(0.0, 1.0);
    if (i == opponents.length - 1) {
      // 決勝: 勝ち負けは、見せ場の決断のあとで決める。
      return TournamentProgress(
        moment: FinalMoment(
          games: games,
          line: line,
          roundsWon: won,
          rounds: opponents.length,
          opponent: opp,
          finalLine: g,
          pWin: pWin,
        ),
      );
    }
    line += g;
    final roll = rng.nextDouble();
    final win = isShutout(g) || roll < pWin;
    games.add(TournamentGame(opponent: opp, won: win, line: g));
    if (!win) {
      return TournamentProgress(
          done: Tournament(
              roundsWon: won,
              rounds: opponents.length,
              line: line,
              games: games));
    }
    won++;
  }
  // 試合が無い(通常は無い)。
  return TournamentProgress(
      done: Tournament(
          roundsWon: won, rounds: opponents.length, line: line, games: games));
}

/// 決勝を決める。`bonus` は見せ場の決断で変わる勝つ確率(足し算)。無失点の登板は負けない(`isShutout`)。
Tournament finishFinal(FinalMoment m, double bonus, Random rng) {
  final roll = rng.nextDouble();
  final win = isShutout(m.finalLine) || roll < (m.pWin + bonus).clamp(0.0, 1.0);
  return Tournament(
    roundsWon: m.roundsWon + (win ? 1 : 0),
    rounds: m.rounds,
    line: m.line + m.finalLine,
    games: [
      ...m.games,
      TournamentGame(opponent: m.opponent, won: win, line: m.finalLine),
    ],
  );
}

/// プロのシーズン(リーグ戦)。
class LeagueSeason {
  const LeagueSeason({
    required this.games,
    required this.wins,
    required this.losses,
    required this.line,
    this.missed = 0,
  });

  final int games;
  final int wins;
  final int losses;
  final Line line;

  /// 自分が出られなかった試合数(怪我)。
  final int missed;

  double get winPct => games == 0 ? 0 : wins / games;

  /// 順位(6球団)。勝率から決める。
  int get rank => leagueRank(winPct);
}

/// 勝率から順位(1〜6位)を決める。
int leagueRank(double winPct) {
  if (winPct >= 0.600) return 1;
  if (winPct >= 0.550) return 2;
  if (winPct >= 0.510) return 3;
  if (winPct >= 0.480) return 4;
  if (winPct >= 0.440) return 5;
  return 6;
}

/// シーズンの途中経過。月ごとに少しずつ進め、最後に [LeagueSeason] になる。
class LeagueProgress {
  const LeagueProgress({
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.line = const Line(),
    this.missed = 0,
  });

  final int games;
  final int wins;
  final int losses;
  final Line line;

  /// 怪我などで、自分は出られなかった試合数。
  final int missed;

  double get winPct => games == 0 ? 0 : wins / games;

  /// 暫定の順位(いまの勝率から)。
  int get rank => leagueRank(winPct);

  LeagueSeason toSeason() => LeagueSeason(
      games: games, wins: wins, losses: losses, line: line, missed: missed);

  Map<String, dynamic> toJson() => {
        'games': games,
        'wins': wins,
        'losses': losses,
        'line': line.toJson(),
        'missed': missed,
      };

  factory LeagueProgress.fromJson(Map<String, dynamic> j) => LeagueProgress(
        games: (j['games'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        line: Line.fromJson((j['line'] as Map?)?.cast<String, dynamic>() ?? {}),
        missed: (j['missed'] as num?)?.toInt() ?? 0,
      );
}

/// シーズンの続きを `count` 試合ぶん進める。`available` が false(怪我)なら、自分は出ず、
/// チーム力だけで勝ち負けが決まる。試合の決め方は [playLeagueSeason] と同じ。
LeagueProgress playLeagueChunk(
  Player p,
  LeagueProgress prog, {
  required int teamLevel,
  required List<int> opponents,
  required Random rng,
  required int count,
  int condition = 50,
  bool available = true,
}) {
  var line = prog.line;
  var wins = prog.wins, losses = prog.losses, missed = prog.missed;
  for (var i = 0; i < count; i++) {
    final g = prog.games + i;
    final opp = opponents[g % opponents.length];
    if (!available) {
      final pWin = (0.5 + (teamLevel - opp) / 100).clamp(0.0, 1.0);
      rng.nextDouble() < pWin ? wins++ : losses++;
      missed++;
      continue;
    }
    final starts = p.role != Role.batter && g % startInterval == 0;
    final game = playGame(p, opp, rng,
        bat: p.role != Role.pitcher, pitch: starts, facedBase: 27);
    final pWin = (0.5 +
            (teamLevel - opp) / 100 +
            (game.rating - 50) / 400 +
            (condition + tournamentBonus(p.traits) - 50) / 800)
        .clamp(0.0, 1.0);
    final won = rng.nextDouble() < pWin;
    won ? wins++ : losses++;
    line += (starts && game.outs >= 15) ? decidedStart(game, won) : game;
  }
  return LeagueProgress(
      games: prog.games + count,
      wins: wins,
      losses: losses,
      line: line,
      missed: missed);
}

/// 5回(15アウト)以上投げて無失点(完封に近い登板)か。勝ち抜き戦では、この試合はチームも負けない
/// (防御率0なのに敗戦、という不自然さを防ぐ。乱数は先に引いて並びは変えない)。
/// ペナントでは、チームの勝敗は変えず、投手の「負け」だけを付けない(`decidedStart`)。
/// ペナントまで強制すると、投手のリーグ優勝が倍になってバランスが崩れた。
bool isShutout(Line game) => game.outs >= 15 && game.runsAllowed < 0.5;

/// 5回以上投げた先発の勝敗を付ける。勝ちはチームが勝った試合。
/// **負けは、チームが負け、かつ自分が失点した試合だけ**(無失点なのに負けにはならない。
/// 勝敗も付かない試合になる)。防御率0なのに敗戦、という不自然さを防ぐ。
Line decidedStart(Line game, bool teamWon) =>
    game.withDecision(win: teamWon, loss: !teamWon && game.runsAllowed >= 0.5);

/// プロの1シーズンの試合数。
const leagueGames = 143;

/// 先発の登板間隔(試合数)。5試合に1度、先発する。
const startInterval = 5;

/// プロのシーズンを通して遊ぶ。打者は全試合に出て、投手は5試合に1度先発する(二刀流は両方)。
/// 先発した試合は、5回(15アウト)以上投げていれば、チームの勝ち負けが勝敗になる。
LeagueSeason playLeagueSeason(
  Player p, {
  required int teamLevel,
  required List<int> opponents,
  required Random rng,
  int condition = 50,
  int games = leagueGames,
}) {
  var line = const Line();
  var wins = 0, losses = 0;
  for (var g = 0; g < games; g++) {
    final opp = opponents[g % opponents.length];
    final starts = p.role != Role.batter && g % startInterval == 0;
    final game = playGame(p, opp, rng,
        bat: p.role != Role.pitcher, pitch: starts, facedBase: 27);
    final pWin = (0.5 +
            (teamLevel - opp) / 100 +
            (game.rating - 50) / 400 +
            (condition + tournamentBonus(p.traits) - 50) / 800)
        .clamp(0.0, 1.0);
    final won = rng.nextDouble() < pWin;
    won ? wins++ : losses++;
    line += (starts && game.outs >= 15) ? decidedStart(game, won) : game;
  }
  return LeagueSeason(games: games, wins: wins, losses: losses, line: line);
}
