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
  });

  /// 出場した試合数(打者または投手として)。
  final int games;

  // 打者
  final int atBats, hits, totalBases, walks, homeRuns;

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
      );

  // ── 打者の指標 ──
  bool get hasBatting => atBats + walks > 0;
  int get plateAppearances => atBats + walks;
  double? get battingAverage => atBats == 0 ? null : hits / atBats;
  double? get onBase =>
      plateAppearances == 0 ? null : (hits + walks) / plateAppearances;
  double? get slugging => atBats == 0 ? null : totalBases / atBats;
  double? get ops => hasBatting ? (onBase ?? 0) + (slugging ?? 0) : null;

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

  double? get era => outs == 0 ? null : runsAllowed * 27 / outs;

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
    );
  }
}

/// 1打席あたりに足す、失点推定の基準値(平均的な環境で防御率が4点前後になる値)。
const runBaseline = 0.10;

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
      line += Line(
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
      {required this.roundsWon, required this.rounds, required this.line});
  final int roundsWon;
  final int rounds;
  final Line line;

  bool get champion => roundsWon == rounds;

  /// 実績 0〜100。大会の勝ち上がり6割・個人の評価4割。
  /// `isDrafted` / `draftScore` の `achievement` に渡す。
  double get achievement =>
      100 * (0.6 * roundsWon / rounds) + 0.4 * line.rating;
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
  for (final opp in opponents) {
    final g = playGame(p, opp, rng);
    line += g;
    final pWin = (0.5 +
            (teamLevel - opp) / 100 +
            (g.rating - 50) / 200 +
            (condition + tournamentBonus(p.traits) - 50) / 500)
        .clamp(0.05, 0.95);
    if (rng.nextDouble() >= pWin) break;
    won++;
  }
  return Tournament(roundsWon: won, rounds: opponents.length, line: line);
}

/// プロの1シーズン(リーグ戦)。
class LeagueSeason {
  const LeagueSeason({
    required this.games,
    required this.wins,
    required this.losses,
    required this.line,
  });

  final int games;
  final int wins;
  final int losses;
  final Line line;

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
  int games = 143,
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
        .clamp(0.05, 0.95);
    final won = rng.nextDouble() < pWin;
    won ? wins++ : losses++;
    line += (starts && game.outs >= 15)
        ? game.withDecision(win: won, loss: !won)
        : game;
  }
  return LeagueSeason(games: games, wins: wins, losses: losses, line: line);
}
