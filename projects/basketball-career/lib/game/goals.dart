import 'dart:math';

import 'events.dart';
import 'player.dart';
import 'season.dart';

/// 年の目標の種類。
enum GoalKind {
  /// 能力を伸ばす(年初からの伸び)。
  abilityUp,

  /// 大会で何勝かする(夏と冬の大きいほう)。
  tournamentWins,

  /// ライバルに勝つ。
  beatRival,

  /// 大会の平均得点。
  scorer,
}

/// 年のはじめに2つ出る目標のひとつ。確実なものと、挑戦的なもの。
class Goal {
  const Goal({
    required this.kind,
    required this.target,
    this.ability,
    this.stretch = false,
  });

  final GoalKind kind;

  /// 能力の伸び・勝ち数・平均得点の目標値。ライバルに勝つときは使わない。
  final int target;
  final Ability? ability;

  /// 挑戦的な目標か(ごほうびが大きい)。
  final bool stretch;

  String get label => switch (kind) {
        GoalKind.abilityUp => '${ability!.label}を今年中に +$target',
        GoalKind.tournamentWins => '大会で$target勝以上',
        GoalKind.beatRival => 'ライバルに勝つ',
        GoalKind.scorer => '大会の平均得点 $target点以上',
      };

  /// 達成のごほうび。
  Effect get reward {
    final a = ability;
    final big = stretch;
    return Effect(
      abilities: {
        if (a != null) a: big ? 3 : 2 else Ability.stamina: big ? 2 : 1,
      },
      morale: big ? 15 : 8,
      trait: null,
    );
  }

  String get rewardText {
    final a = ability ?? Ability.stamina;
    return '達成で ${a.label} +${stretch ? 3 : 2}、気持ち +${stretch ? 15 : 8}';
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'target': target,
        'ability': ability?.name,
        'stretch': stretch,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        kind: GoalKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => GoalKind.tournamentWins,
        ),
        target: (j['target'] as num?)?.toInt() ?? 1,
        ability: Ability.parse((j['ability'] as String?) ?? ''),
        stretch: (j['stretch'] as bool?) ?? false,
      );
}

/// 年のはじめに出す目標の候補(確実なもの1つ・挑戦的なもの1つ)。
/// [league] はいまの舞台、[rivalActive] はライバルが現れる年か、[focus] は直近の重点。
List<Goal> rollGoals(
  Player p, {
  required League league,
  required bool rivalActive,
  required Ability focus,
  required Random rng,
}) {
  final rounds = league.rounds;
  // 確実な目標: 重点の能力を少し伸ばすか、1〜2勝。
  final safe = rng.nextBool()
      ? Goal(kind: GoalKind.abilityUp, ability: focus, target: 3)
      : Goal(kind: GoalKind.tournamentWins, target: max(1, rounds ~/ 3));
  // 挑戦的な目標: 大きく伸ばす・勝ち上がる・ライバルに勝つ・点を取る。
  final pool = <Goal>[
    Goal(kind: GoalKind.abilityUp, ability: focus, target: 6, stretch: true),
    Goal(
        kind: GoalKind.tournamentWins,
        target: max(2, rounds - 1),
        stretch: true),
    if (rivalActive) const Goal(kind: GoalKind.beatRival, target: 1, stretch: true),
    Goal(kind: GoalKind.scorer, target: 12 + p.age ~/ 4, stretch: true),
  ];
  return [safe, pool[rng.nextInt(pool.length)]];
}
