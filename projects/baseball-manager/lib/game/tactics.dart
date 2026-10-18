import 'player.dart';

/// 大会・シーズン最終月の前に選ぶ作戦。そのときだけ能力が少し変わる(本当の能力は変わらない)。
enum Tactic {
  steady('堅実', '当てる・制球を重視。安定して戦う。'),
  aggressive('強気', '長打・球威を重視。当たれば大きいが、粗くなる。'),
  scout('研究', '相手を分析。チームの勝ちやすさが上がる。');

  const Tactic(this.label, this.description);
  final String label;
  final String description;
}

/// 研究のとき、チーム力に足す値。
int tacticTeamBonus(Tactic t) => t == Tactic.scout ? 4 : 0;

/// 作戦に合わせて、その大会だけの能力にした選手。元の選手は変えない。
Player tacticAdjusted(Player p, Tactic t) {
  final delta = switch (t) {
    Tactic.steady => {
        Ability.contact: 6,
        Ability.eye: 4,
        Ability.power: -3,
        Ability.control: 6,
        Ability.stuff: -3,
      },
    Tactic.aggressive => {
        Ability.power: 10,
        Ability.contact: -6,
        Ability.eye: -4,
        Ability.stuff: 8,
        Ability.control: -6,
      },
    Tactic.scout => const <Ability, int>{},
  };
  final next = {
    for (final e in p.abilities.entries)
      e.key: (e.value + (delta[e.key] ?? 0)).clamp(0, 99),
  };
  return p.copyWith(abilities: next);
}
