import 'dart:math';

import 'player.dart';
import 'traits.dart';

/// 勝負どころ(最後の攻防)で選べるプレー。
enum Clutch {
  drive('ドライブ', '切り込んで決める。ゴール下とドリブルが効く。2点。'),
  threePoint('3P', '外から狙う。成功すれば3点。'),
  pass('パス', '味方に任せる。パス力が効く。2点。'),
  defend('ディフェンス', '最後の相手の攻撃を止める。'),
  drawFoul('ファウルをもらう', '強く当たってファウルを誘い、フリースロー2本を決める。フリースローが効く。');

  const Clutch(this.label, this.description);
  final String label;
  final String description;

  static Clutch? parse(String? s) {
    for (final c in Clutch.values) {
      if (c.name == s) return c;
    }
    return null;
  }
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
    this.teamQuarters = const [],
    this.oppQuarters = const [],
    this.opponent = '',
    this.vsRival = false,
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

  /// クォーターごとの得点(4つ)。延長・勝負どころの得点は含まない。
  final List<int> teamQuarters;
  final List<int> oppQuarters;

  /// 相手の名前(ライバルなら本人の名前)。
  final String opponent;
  final bool vsRival;

  int get margin => teamScore - oppScore;

  Map<String, dynamic> toJson() => {
        'won': won,
        'teamScore': teamScore,
        'oppScore': oppScore,
        'points': points,
        'rebounds': rebounds,
        'assists': assists,
        'clutch': clutch?.name,
        'clutchSuccess': clutchSuccess,
        'teamQuarters': teamQuarters,
        'oppQuarters': oppQuarters,
        'opponent': opponent,
        'vsRival': vsRival,
      };

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        won: (j['won'] as bool?) ?? false,
        teamScore: (j['teamScore'] as num?)?.toInt() ?? 0,
        oppScore: (j['oppScore'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
        rebounds: (j['rebounds'] as num?)?.toInt() ?? 0,
        assists: (j['assists'] as num?)?.toInt() ?? 0,
        clutch: Clutch.parse(j['clutch'] as String?),
        clutchSuccess: j['clutchSuccess'] as bool?,
        teamQuarters: [
          for (final v in (j['teamQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        oppQuarters: [
          for (final v in (j['oppQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        opponent: (j['opponent'] as String?) ?? '',
        vsRival: (j['vsRival'] as bool?) ?? false,
      );
}

/// 4クォーターが終わった時点の試合。勝負どころが訪れるなら、ここで止まって選ぶ。
class MatchState {
  const MatchState({
    required this.team,
    required this.opp,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.teamStrength,
    required this.oppStrength,
    required this.form,
    required this.teamQuarters,
    required this.oppQuarters,
    this.opponent = '',
    this.vsRival = false,
  });

  final int team;
  final int opp;
  final int points;
  final int rebounds;
  final int assists;
  final double teamStrength;
  final double oppStrength;
  final double form;
  final List<int> teamQuarters;
  final List<int> oppQuarters;
  final String opponent;
  final bool vsRival;

  int get margin => team - opp;

  /// 点差が近く、最後の攻防を選べるか。
  bool get needsClutch => margin.abs() <= clutchWindow;

  Map<String, dynamic> toJson() => {
        'team': team,
        'opp': opp,
        'points': points,
        'rebounds': rebounds,
        'assists': assists,
        'teamStrength': teamStrength,
        'oppStrength': oppStrength,
        'form': form,
        'teamQuarters': teamQuarters,
        'oppQuarters': oppQuarters,
        'opponent': opponent,
        'vsRival': vsRival,
      };

  factory MatchState.fromJson(Map<String, dynamic> j) => MatchState(
        team: (j['team'] as num?)?.toInt() ?? 0,
        opp: (j['opp'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
        rebounds: (j['rebounds'] as num?)?.toInt() ?? 0,
        assists: (j['assists'] as num?)?.toInt() ?? 0,
        teamStrength: (j['teamStrength'] as num?)?.toDouble() ?? 50,
        oppStrength: (j['oppStrength'] as num?)?.toDouble() ?? 50,
        form: (j['form'] as num?)?.toDouble() ?? 1,
        teamQuarters: [
          for (final v in (j['teamQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        oppQuarters: [
          for (final v in (j['oppQuarters'] as List?) ?? const [])
            (v as num).toInt()
        ],
        opponent: (j['opponent'] as String?) ?? '',
        vsRival: (j['vsRival'] as bool?) ?? false,
      );
}

/// 勝負どころに入る点差(最終クォーター終了時、この点差以内)。
const clutchWindow = 3;

double _noise(Random rng) =>
    (rng.nextDouble() + rng.nextDouble() + rng.nextDouble() - 1.5) / 1.5;

/// ファウルを誘える確率(強く当たる・切り込む力と、相手の守備)。
double foulDrawChance(Player p, double oppDefense) =>
    (0.30 +
            0.35 * ((p.effective(Ability.physical) + p.effective(Ability.dribble)) / 200) -
            0.10 * (oppDefense / 100))
        .clamp(0.1, 0.8);

/// フリースロー1本が入る確率。
double freeThrowChance(Player p, double form) =>
    (0.40 + 0.50 * (p.effective(Ability.freeThrow) / 100) + (form - 1) * 0.1 + clutchBonus(p.traits) * 0.5)
        .clamp(0.2, 0.95);

/// 勝負どころの成功率(0〜1)。`oppDefense` は相手の守備の強さ(0〜100)。
/// ファウルをもらうは「ファウルを誘って、2本とも決める」確率(1本だけでも1点は入る)。
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
    Clutch.drawFoul => foulDrawChance(p, oppDefense) *
        pow(freeThrowChance(p, form), 2).toDouble(),
  };
  // ポジションの持ち味。
  final perk = switch ((p.position, c)) {
    (Position.shootingGuard, Clutch.threePoint) => 0.08,
    (Position.powerForward, Clutch.drive) => 0.07,
    (Position.center, Clutch.defend) => 0.08,
    _ => 0.0,
  };
  if (c == Clutch.drawFoul) return raw.clamp(0.03, 0.9);
  return (raw * (0.8 + form * 0.2) + clutchBonus(p.traits) + perk)
      .clamp(0.03, 0.9);
}

/// 4クォーターを進める。点差が近ければ [MatchState.needsClutch]。
///
/// - `teamStrength` は味方(本人を除く)、`oppStrength` は相手の強さ(0〜100、50が平均)。
/// - `form` は体調(`Condition.form`)。
MatchState playQuarters(
  Player p, {
  required double teamStrength,
  required double oppStrength,
  required double form,
  required Random rng,
  String opponent = '',
  bool vsRival = false,
}) {
  final mine = teamStrength * 0.6 + p.overall * form * 0.4;
  var team = 0, opp = 0;
  final tq = <int>[], oq = <int>[];
  for (var q = 0; q < 4; q++) {
    final t = max(8, (18 + (mine - 50) * 0.12 + _noise(rng) * 5).round());
    final o = max(8, (18 + (oppStrength - 50) * 0.12 + _noise(rng) * 5).round());
    tq.add(t);
    oq.add(o);
    team += t;
    opp += o;
  }

  // 個人成績。得点の取り分は攻撃力で、リバウンド・アシストは能力と身長で。
  final offense = (p.effective(Ability.threePoint) +
          p.effective(Ability.midRange) +
          p.effective(Ability.inside)) /
      3;
  final share =
      (0.10 + (offense - 30) / 300 + _noise(rng) * 0.03).clamp(0.04, 0.45);
  return MatchState(
    team: team,
    opp: opp,
    points: (team * share * form).round(),
    rebounds: max(
        0,
        (p.effective(Ability.rebound) /
                    8 *
                    form *
                    (p.position == Position.center ? 1.2 : 1.0) +
                _noise(rng) * 2)
            .round()),
    assists:
        max(0, (p.effective(Ability.pass) / 14 * form + _noise(rng)).round()),
    teamStrength: mine,
    oppStrength: oppStrength,
    form: form,
    teamQuarters: tq,
    oppQuarters: oq,
    opponent: opponent,
    vsRival: vsRival,
  );
}

/// 試合を締める。勝負どころなら `choice`(null なら成功率の高いプレーを自動で選ぶ)で決める。
MatchResult finishMatch(Player p, MatchState s, Clutch? choice, Random rng) {
  var team = s.team, opp = s.opp, points = s.points, assists = s.assists;
  Clutch? used;
  bool? ok;
  if (s.needsClutch) {
    final c = choice ?? bestClutch(p, s.oppStrength, s.form);
    used = c;
    var success = rng.nextDouble() < clutchChance(p, c, s.oppStrength, s.form);
    if (c == Clutch.drawFoul) {
      // ファウルを誘えたか→フリースロー2本。入った本数だけ得点(2本とも入れば成功)。
      var made = 0;
      if (rng.nextDouble() < foulDrawChance(p, s.oppStrength)) {
        final ft = freeThrowChance(p, s.form);
        for (var i = 0; i < 2; i++) {
          if (rng.nextDouble() < ft) made++;
        }
      }
      team += made;
      points += made;
      success = made == 2;
    }
    ok = success;
    switch (c) {
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
      case Clutch.drawFoul:
        break; // 得点は上で加算済み
    }
  }

  final bool won;
  if (team == opp) {
    won = rng.nextDouble() < 0.5 + (s.teamStrength - s.oppStrength) / 200;
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
    rebounds: s.rebounds,
    assists: assists,
    clutch: used,
    clutchSuccess: ok,
    teamQuarters: s.teamQuarters,
    oppQuarters: s.oppQuarters,
    opponent: s.opponent,
    vsRival: s.vsRival,
  );
}

/// 1試合を通して進める(勝負どころは `chooseClutch` が選ぶ。null なら自動)。
MatchResult simulateMatch(
  Player p, {
  required double teamStrength,
  required double oppStrength,
  required double form,
  required Random rng,
  Clutch Function(int margin)? chooseClutch,
  String opponent = '',
  bool vsRival = false,
}) {
  final s = playQuarters(p,
      teamStrength: teamStrength,
      oppStrength: oppStrength,
      form: form,
      rng: rng,
      opponent: opponent,
      vsRival: vsRival);
  final choice = s.needsClutch ? chooseClutch?.call(s.margin) : null;
  return finishMatch(p, s, choice, rng);
}

/// 期待値がいちばん高いプレー。3P は成功率が低くても点が大きいので重みを付ける。
Clutch bestClutch(Player p, double oppStrength, double form) {
  Clutch best = Clutch.drive;
  var bestScore = -1.0;
  for (final c in Clutch.values) {
    // 期待値(2点を1とする)。ファウルは1本でも点になるので、成功率ではなく期待本数で比べる。
    final value = c == Clutch.drawFoul
        ? foulDrawChance(p, oppStrength) * freeThrowChance(p, form)
        : clutchChance(p, c, oppStrength, form) *
            (c == Clutch.threePoint ? 1.5 : 1.0);
    if (value > bestScore) {
      bestScore = value;
      best = c;
    }
  }
  return best;
}
