import 'dart:math';

import '../data/name_pool.dart';
import '../models/player.dart';
import '../models/youth_league.dart';
import '../l10n/tr.dart';

/// ユースリーグ1節分の結果。
class YouthLeagueMatchday {
  final String opponentName;
  final int opponentStrength;
  final int goalsFor;
  final int goalsAgainst;

  const YouthLeagueMatchday({
    required this.opponentName,
    required this.opponentStrength,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  bool get isWin => goalsFor > goalsAgainst;
  bool get isDraw => goalsFor == goalsAgainst;
}

/// ユースの年間リーグを運営する。
///
/// 練習試合は毎週あったが、勝敗が何にも残らなかった。年間の順位表を持つと、
/// 「今年のユースはどうだったか」が言えるようになり、昇格させずに残す判断にも
/// 理由が生まれる(強いユースで勝たせて育てる、という選び方ができる)。
class YouthLeagueEngine {
  static final Random _rng = Random();

  /// 相手ユースの強さの散らばり(自クラブの平均総合力に対する増減幅)。
  static const int strengthSpread = 12;

  /// リーグを新しく作る。[prospectAverage]は自クラブのユースの平均総合力。
  static YouthLeague create({required int prospectAverage}) {
    final names = NamePool.clubNames(YouthLeague.teamCount - 1);
    final standings = <YouthLeagueStanding>[
      YouthLeagueStanding(
        name: Tr.pick('自クラブ ユース', 'Your academy'),
        strength: prospectAverage,
        isUser: true,
      ),
      for (final name in names)
        YouthLeagueStanding(
          name: Tr.pick('$name ユース', '$name academy'),
          strength: (prospectAverage +
                  _rng.nextInt(strengthSpread * 2 + 1) -
                  strengthSpread)
              .clamp(20, 90),
        ),
    ];

    // 自クラブの対戦順。全チームと2回ずつ当たるよう、相手の並びを2周する。
    final opponents = [
      for (var i = 1; i < standings.length; i++) i,
    ]..shuffle(_rng);
    final order = [...opponents, ...opponents.reversed];

    return YouthLeague(standings: standings, opponentOrder: order);
  }

  /// 今節の相手の強さ。試合のシミュレーション側へ渡す。
  static int? opponentStrengthFor(YouthLeague league) =>
      league.nextOpponent?.strength;

  /// 自クラブの結果を記録し、他チーム同士の結果も決めて1節進める。
  ///
  /// 自クラブの試合は[YouthMatchEngine]が詳細に行うため、ここには
  /// 得点だけを渡す。
  static YouthLeagueMatchday? recordUserResult(
    YouthLeague league, {
    required int goalsFor,
    required int goalsAgainst,
  }) {
    final opponent = league.nextOpponent;
    if (opponent == null) return null;

    league.userStanding.record(goalsFor, goalsAgainst);
    opponent.record(goalsAgainst, goalsFor);

    // 残りのチーム同士も当たらせる。順位表が自クラブの行だけ埋まっていると、
    // 「勝点は多いのに最下位」のような読めない表になる。
    final others = [
      for (final s in league.standings)
        if (!s.isUser && s != opponent) s,
    ]..shuffle(_rng);
    for (var i = 0; i + 1 < others.length; i += 2) {
      final home = others[i];
      final away = others[i + 1];
      final diff = home.strength - away.strength;
      final homeGoals = _rollGoals(1.4 + diff / 12);
      final awayGoals = _rollGoals(1.4 - diff / 12);
      home.record(homeGoals, awayGoals);
      away.record(awayGoals, homeGoals);
    }

    league.matchday++;
    return YouthLeagueMatchday(
      opponentName: opponent.name,
      opponentStrength: opponent.strength,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
    );
  }

  static int _rollGoals(double expected) {
    var goals = 0;
    for (var i = 0; i < 6; i++) {
      if (_rng.nextDouble() < (expected / 6).clamp(0.0, 0.95)) goals++;
    }
    return goals;
  }

  /// ユースの平均総合力。候補が居なければ相手の基準にできないため、
  /// 最低値を返す。
  static int prospectAverage(List<Player> prospects) {
    if (prospects.isEmpty) return 40;
    final total = prospects.fold<int>(0, (s, p) => s + p.overall);
    return (total / prospects.length).round();
  }

  /// 年間の得点王(自クラブのユース内)。得点が0なら null。
  static Player? topScorer(List<Player> prospects) {
    Player? best;
    for (final p in prospects) {
      if (p.youthMatchGoals <= 0) continue;
      if (best == null || p.youthMatchGoals > best.youthMatchGoals) best = p;
    }
    return best;
  }
}
