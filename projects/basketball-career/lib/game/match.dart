import 'dart:math';

import 'player.dart';
import 'traits.dart';

/// 勝負どころ(最後の攻防)で選べるプレー。
enum Clutch {
  drive('ドライブ', '切り込んで決める。ゴール下とドリブルが効く。2点。'),
  threePoint('3P', '外から狙う。成功すれば3点。'),
  pass('パス', '味方に任せる。パス力が効く。2点。'),
  defend('ディフェンス', '最後の相手の攻撃を止める。');

  const Clutch(this.label, this.description);
  final String label;
  final String description;
}

/// 試合の結果。
class MatchResult {
  const MatchResult({
    required this.won,
    required this.teamScore,
    required this.oppScore,
    required this.points,
    required this.rebounds,
    required this.assists,
    this.clutch,
    this.clutchSuccess,
  });

  final bool won;
  final int teamScore;
  final int oppScore;
  final int points;
  final int rebounds;
  final int assists;

  /// 勝負どころが訪れたときの選択と成否。訪れなければ null。
  final Clutch? clutch;
  final bool? clutchSuccess;

  int get margin => teamScore - oppScore;
}

/// 勝負どころに入る点差(最終クォーター終了時、この点差以内)。
const clutchWindow = 3;

double _noise(Random rng) =>
    (rng.nextDouble() + rng.nextDouble() + rng.nextDouble() - 1.5) / 1.5;

/// 勝負どころの成功率(0〜1)。`oppDefense` は相手の守備の強さ(0〜100)。
double clutchChance(Player p, Clutch c, double oppDefense, double form) {
  final opp = oppDefense / 100;
  final double raw = switch (c) {
    Clutch.drive =>
      0.22 + 0.55 * ((p.effective(Ability.inside) + p.effective(Ability.dribble)) / 200) - 0.25 * opp,
    Clutch.threePoint =>
      0.12 + 0.55 * (p.effective(Ability.threePoint) / 100) - 0.20 * opp,
    Clutch.pass =>
      0.28 + 0.45 * (p.effective(Ability.pass) / 100) - 0.12 * opp,
    Clutch.defend =>
      0.25 + 0.50 * (p.effective(Ability.defense) / 100) - 0.15 * opp,
  };
  return (raw * (0.8 + form * 0.2) + clutchBonus(p.traits)).clamp(0.03, 0.9);
}

/// 1試合を進める。
///
/// - `teamStrength` は味方(本人を除く)、`oppStrength` は相手の強さ(0〜100、50が平均)。
/// - `form` は体調(`Condition.form`)。
/// - 最終クォーター終了時に点差が `clutchWindow` 以内なら勝負どころ。
///   `chooseClutch` が選ぶ(null なら成功率が最も高いプレーを自動で選ぶ)。
MatchResult simulateMatch(
  Player p, {
  required double teamStrength,
  required double oppStrength,
  required double form,
  required Random rng,
  Clutch Function(int margin)? chooseClutch,
}) {
  final mine = teamStrength * 0.7 + p.overall * form * 0.3;
  var team = 0, opp = 0;
  for (var q = 0; q < 4; q++) {
    team += max(8, (18 + (mine - 50) * 0.12 + _noise(rng) * 5).round());
    opp += max(8, (18 + (oppStrength - 50) * 0.12 + _noise(rng) * 5).round());
  }

  // 個人成績。得点の取り分は攻撃力で、リバウンド・アシストは能力と身長で。
  final offense = (p.effective(Ability.threePoint) +
          p.effective(Ability.midRange) +
          p.effective(Ability.inside)) /
      3;
  final share = (0.10 + (offense - 30) / 300 + _noise(rng) * 0.03).clamp(0.04, 0.45);
  var points = (team * share * form).round();
  var rebounds = max(0, (p.effective(Ability.rebound) / 8 * form + _noise(rng) * 2).round());
  var assists = max(0, (p.effective(Ability.pass) / 14 * form + _noise(rng)).round());

  Clutch? used;
  bool? ok;
  if ((team - opp).abs() <= clutchWindow) {
    final choice = chooseClutch?.call(team - opp) ?? _bestClutch(p, oppStrength, form);
    used = choice;
    final success = rng.nextDouble() < clutchChance(p, choice, oppStrength, form);
    ok = success;
    switch (choice) {
      case Clutch.drive:
        if (success) {
          team += 2;
          points += 2;
        }
      case Clutch.threePoint:
        if (success) {
          team += 3;
          points += 3;
        }
      case Clutch.pass:
        if (success) {
          team += 2;
          assists += 1;
        }
      case Clutch.defend:
        // 守れなければ、相手が最後に決める。
        if (!success) opp += 2;
    }
  }

  final bool won;
  if (team == opp) {
    won = rng.nextDouble() < 0.5 + (mine - oppStrength) / 200;
    if (won) {
      team += 2;
    } else {
      opp += 2;
    }
  } else {
    won = team > opp;
  }

  return MatchResult(
    won: won,
    teamScore: team,
    oppScore: opp,
    points: points,
    rebounds: rebounds,
    assists: assists,
    clutch: used,
    clutchSuccess: ok,
  );
}

Clutch _bestClutch(Player p, double oppStrength, double form) {
  Clutch best = Clutch.drive;
  var bestScore = -1.0;
  for (final c in Clutch.values) {
    // 3P は成功率が低くても点が大きいので、期待値で比べる。
    final value = clutchChance(p, c, oppStrength, form) * (c == Clutch.threePoint ? 1.5 : 1.0);
    if (value > bestScore) {
      bestScore = value;
      best = c;
    }
  }
  return best;
}
