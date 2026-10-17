import 'dart:math';

import 'at_bat.dart';
import 'player.dart';
import 'traits.dart';

/// 1試合(または大会通算)の個人成績。打者として/投手として、それぞれ数える。
class Line {
  const Line({
    this.atBats = 0,
    this.totalBases = 0,
    this.walks = 0,
    this.homeRuns = 0,
    this.faced = 0,
    this.strikeouts = 0,
    this.walksGiven = 0,
    this.hitsAllowed = 0,
    this.homeRunsAllowed = 0,
  });

  final int atBats, totalBases, walks, homeRuns; // 打者
  final int faced, strikeouts, walksGiven, hitsAllowed, homeRunsAllowed; // 投手

  Line operator +(Line o) => Line(
        atBats: atBats + o.atBats,
        totalBases: totalBases + o.totalBases,
        walks: walks + o.walks,
        homeRuns: homeRuns + o.homeRuns,
        faced: faced + o.faced,
        strikeouts: strikeouts + o.strikeouts,
        walksGiven: walksGiven + o.walksGiven,
        hitsAllowed: hitsAllowed + o.hitsAllowed,
        homeRunsAllowed: homeRunsAllowed + o.homeRunsAllowed,
      );

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
}

const _batterTurns = 4; // 1試合の打席
const _pitcherFaced = 18; // 1試合の対戦打者(先発1人ぶんの目安)

/// 相手の強さ `opp`(0〜99)で1試合ぶんの個人成績を出す。
Line playGame(Player p, int opp, Random rng) {
  var line = const Line();
  if (p.role != Role.pitcher) {
    final foe = Pitcher(control: opp, stuff: opp);
    for (var i = 0; i < _batterTurns; i++) {
      final r = simulateAtBat(foe, p.toBatter(), rng);
      line += Line(
        atBats: r == AtBatResult.walk ? 0 : 1,
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
  if (p.role != Role.batter) {
    final foe = Batter(contact: opp, power: opp, eye: opp);
    // スタミナが低いと長く投げられない(対戦数が減る)。
    final faced = (_pitcherFaced * (0.5 + p.of(Ability.stamina) / 200)).round();
    for (var i = 0; i < faced; i++) {
      final r = simulateAtBat(p.toPitcher(), foe, rng);
      line += Line(
        faced: 1,
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
      );
    }
  }
  return line;
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
