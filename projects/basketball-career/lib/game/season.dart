import 'dart:math';

import 'match.dart';
import 'player.dart';

/// 大会の舞台。段階ごとに味方と相手の強さが違う。
enum League {
  minibasket('ミニバス', 3, 34, 36),
  juniorHigh('中学', 4, 42, 44),
  highSchool('高校', 5, 50, 52),
  university('大学', 4, 56, 58),
  corporate('実業団', 4, 55, 57),
  proDomestic('国内プロ', 6, 62, 64),
  proAbroad('海外プロ', 6, 72, 76);

  const League(this.label, this.rounds, this.teamStrength, this.oppBase);
  final String label;

  /// 勝ち抜きの試合数(国内/海外プロは全試合を戦う)。
  final int rounds;
  final double teamStrength;
  final double oppBase;

  bool get elimination => this != proDomestic && this != proAbroad;
}

/// 大会(1シーズン)の結果。
class TournamentResult {
  const TournamentResult({
    required this.league,
    required this.matches,
    required this.wins,
    required this.achievement,
  });

  final League league;
  final List<MatchResult> matches;
  final int wins;

  /// 実績 0〜100。勝ち上がり6割・個人の評価4割。進路の評価に入る。
  final double achievement;

  int get games => matches.length;
  bool get champion => wins == league.rounds;
  double get ppg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.points) / games;
  double get rpg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.rebounds) / games;
  double get apg => games == 0 ? 0 : matches.fold(0, (s, m) => s + m.assists) / games;
}

/// 個人の評価 0〜100(50 が平均)。得点・リバウンド・アシストの1試合平均から。
double individualRating(double ppg, double rpg, double apg) =>
    (50 + (ppg - 8) * 2.0 + (rpg - 4) * 1.5 + (apg - 2) * 2.0)
        .clamp(0, 100)
        .toDouble();

/// 大会を戦う。勝ち抜きは負けたら終わり。
/// `chooseClutch` が null なら勝負どころは自動で選ぶ。
TournamentResult playTournament(
  Player p,
  League league, {
  required double form,
  required Random rng,
  Clutch Function(int margin)? chooseClutch,
}) {
  final matches = <MatchResult>[];
  var wins = 0;
  for (var r = 0; r < league.rounds; r++) {
    final opp = league.oppBase + r * 3 + (rng.nextDouble() - 0.5) * 8;
    final m = simulateMatch(
      p,
      teamStrength: league.teamStrength,
      oppStrength: opp,
      form: form,
      rng: rng,
      chooseClutch: chooseClutch,
    );
    matches.add(m);
    if (m.won) wins++;
    if (league.elimination && !m.won) break;
  }
  final n = matches.length;
  final ppg = matches.fold(0, (s, m) => s + m.points) / n;
  final rpg = matches.fold(0, (s, m) => s + m.rebounds) / n;
  final apg = matches.fold(0, (s, m) => s + m.assists) / n;
  final achievement =
      wins / league.rounds * 60 + individualRating(ppg, rpg, apg) * 0.4;
  return TournamentResult(
    league: league,
    matches: matches,
    wins: wins,
    achievement: achievement.clamp(0, 100).toDouble(),
  );
}
