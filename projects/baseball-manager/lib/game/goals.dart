import 'career.dart';
import 'player.dart';
import 'records.dart';

/// 今年の目標の種類。
enum GoalKind { rounds, rank, battingAverage, homeRuns, era, wins }

/// 年ごとの目標。大会(プロはシーズン)の成績で、達成かどうかが決まる。
/// 達成すると経験点と気持ち、届かなくても少し気持ちが下がるだけ。
class Goal {
  Goal(this.kind, this.target,
      {this.achieved, this.level = 1, double? baseTarget})
      : baseTarget = baseTarget ?? target;

  final GoalKind kind;

  /// 目標の値。回戦・順位・本数・勝利数は整数、打率・防御率は小数。
  final double target;

  /// むずかしさ(0=やさしい / 1=ふつう / 2=むずかしい)。高いほど、達成のごほうびが大きい。
  final int level;

  /// 「ふつう」のときの値。やさしい・むずかしいは、ここから動かす。
  final double baseTarget;

  /// むずかしさを変えた目標。`maxRounds` は大会の全体の回戦数(回戦の目標の上限)。
  Goal withLevel(int newLevel, {int maxRounds = 6}) {
    final b = baseTarget;
    final d = newLevel - 1; // -1, 0, +1
    final t = switch (kind) {
      GoalKind.rounds => (b + d).clamp(1, maxRounds).toDouble(),
      GoalKind.rank => (b - d).clamp(1, 6).toDouble(),
      GoalKind.battingAverage => (b + d * 0.020).clamp(0.150, 0.420),
      GoalKind.homeRuns => d < 0
          ? (b * 0.75).round().clamp(1, 60).toDouble()
          : d > 0
              ? (b * 1.3).ceil().clamp(1, 60).toDouble()
              : b,
      GoalKind.era => (b - d * 0.5).clamp(1.5, 7.0),
      GoalKind.wins => (b + d * 3).clamp(1, 25).toDouble(),
    };
    return Goal(kind, t, level: newLevel, baseTarget: b);
  }

  /// 判定済みなら達成したか。まだなら null。
  bool? achieved;

  String get text => switch (kind) {
        GoalKind.rounds => '今年の大会で${target.round()}勝以上',
        GoalKind.rank => '${target.round()}位以内',
        GoalKind.battingAverage => '打率${fmtRate(target)}以上',
        GoalKind.homeRuns => '本塁打${target.round()}本以上',
        GoalKind.era => '防御率${fmtEra(target)}以下',
        GoalKind.wins => '${target.round()}勝以上',
      };

  /// 成績が目標に届いたか。
  bool judge(SeasonRecord r) => switch (kind) {
        GoalKind.rounds => r.roundsWon >= target,
        GoalKind.rank => r.rank != null && r.rank! <= target,
        GoalKind.battingAverage => (r.line.battingAverage ?? 0) >= target,
        GoalKind.homeRuns => r.line.homeRuns >= target,
        GoalKind.era => r.line.era != null && r.line.era! <= target,
        GoalKind.wins => r.line.wins >= target,
      };

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'target': target,
        'achieved': achieved,
        'level': level,
        'baseTarget': baseTarget,
      };

  /// 項目を足すときは既定値を置く。
  static Goal? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = GoalKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (kind == null) return null;
    final target = (j['target'] as num?)?.toDouble() ?? 1;
    return Goal(kind, target,
        achieved: j['achieved'] as bool?,
        level: ((j['level'] as num?)?.toInt() ?? 1).clamp(0, 2),
        baseTarget: (j['baseTarget'] as num?)?.toDouble());
  }
}

/// 達成したときの経験点(種類ごと)。1年ぶんの練習で貯まる量の1〜2割ほど。
/// (プロは能力の伸びが小さいので、少なくしてある。多くすると全体のバランスが崩れる。)
int goalRewardExp(Stage s) => switch (s) {
      Stage.youth => 6,
      Stage.juniorHigh => 8,
      Stage.highSchool => 10,
      Stage.pathChoice => 10,
      Stage.pro => 6,
      Stage.retired => 0,
    };

const goalRewardMorale = 18;
const goalMissMorale = -5;

/// むずかしさごとの、ごほうびの倍率・気持ち。やさしいは少なく、むずかしいは多い。
/// 達成のしやすさはおよそ 75% / 50% / 25% なので、期待値は やさしい<ふつう≒むずかしい。
const goalExpScale = [0.5, 1.0, 2.0];
const goalMoraleReward = [10, goalRewardMorale, 30];
const goalMoraleMiss = [-3, goalMissMorale, -8];
const goalLevelLabels = ['やさしい', 'ふつう', 'むずかしい'];

/// その段階・むずかしさで達成したときの経験点(種類ごと)。
int goalExpFor(Stage s, int level) =>
    (goalRewardExp(s) * goalExpScale[level.clamp(0, 2)]).round();

/// 折れ線の表から、`x` の値を補間する(端は外側に伸ばさない)。
double _interp(List<(double, double)> table, double x) {
  if (x <= table.first.$1) return table.first.$2;
  for (var i = 1; i < table.length; i++) {
    if (x <= table[i].$1) {
      final (x0, y0) = table[i - 1];
      final (x1, y1) = table[i];
      return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
    }
  }
  return table.last.$2;
}

// 総合評価ごとの、プロの1シーズンの平均成績(tool/balance と test/goals_test の実測)。
const _hrTable = [
  (30.0, 5.0),
  (45.0, 10.3),
  (60.0, 15.6),
  (75.0, 22.4),
  (90.0, 33.2),
  (99.0, 44.9)
];
const _winsTable = [
  (30.0, 0.9),
  (45.0, 4.6),
  (60.0, 11.1),
  (75.0, 16.5),
  (90.0, 18.7)
];
const _eraTable = [
  (30.0, 6.34),
  (45.0, 5.05),
  (60.0, 3.87),
  (75.0, 2.82),
  (90.0, 1.91)
];
const _avgTable = [
  (30.0, 0.154),
  (45.0, 0.213),
  (60.0, 0.248),
  (75.0, 0.286),
  (90.0, 0.358),
  (99.0, 0.454)
];

/// その年の目標を決める。いまの総合評価 `ov` から、届くか届かないか五分五分ぐらいの高さにする。
/// 回戦数は `rounds`(大会の全体の回戦数)を超えない。`pick` は種類を選ぶ乱数(0〜1)。
Goal makeGoal({
  required Stage stage,
  required Role role,
  required double ov,
  required int rounds,
  required double pick,
}) {
  double round(double v, double step) => (v / step).round() * step;
  if (stage == Stage.pro) {
    final rank = Goal(GoalKind.rank, ov >= 75 ? 2 : (ov >= 60 ? 3 : 4));
    final bats = role != Role.pitcher;
    final pitches = role != Role.batter;
    final personal = <Goal>[
      if (bats) ...[
        Goal(GoalKind.battingAverage,
            round(_interp(_avgTable, ov) + 0.003, 0.005)),
        Goal(GoalKind.homeRuns,
            _interp(_hrTable, ov).roundToDouble().clamp(3, 60)),
      ],
      if (pitches) ...[
        Goal(GoalKind.era,
            round((_interp(_eraTable, ov) + 0.1).clamp(1.8, 6.0), 0.05)),
        Goal(GoalKind.wins,
            _interp(_winsTable, ov).roundToDouble().clamp(3, 25)),
      ],
    ];
    final all = [rank, ...personal];
    return all[(pick * all.length).floor().clamp(0, all.length - 1)];
  }
  final target = (1 + (ov / 25).floor()).clamp(1, rounds).toDouble();
  final roundsGoal = Goal(GoalKind.rounds, target);
  if (role != Role.pitcher && pick >= 0.5) {
    return Goal(GoalKind.battingAverage, ov >= 60 ? 0.300 : 0.250);
  }
  return roundsGoal;
}
