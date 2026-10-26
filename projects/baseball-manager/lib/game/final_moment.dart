import 'dart:math';

import 'life.dart';
import 'player.dart';

/// 決勝の見せ場(アマの大会の決勝の、勝負を決める場面の決断)。
///
/// 決勝まで勝ち進むと、最後の場面でどう勝負するかを3つから選べる。選んだ作戦に合った能力が高いほど、
/// 勝つ確率が上がる(`finalBonus`)。強振は能力しだいで大きくぶれる賭け。決勝の個人成績は変わらない。
const finalMomentId = 'final-moment';

/// 決断で足す勝つ確率の基準のずれ(平均で全体のバランスが変わらないように)。
const _baseline = -0.02;

/// 投手として決断するか(投手と二刀流の投手側ではなく、役割が投手のとき)。
bool _asPitcher(Player p) => p.role == Role.pitcher;

/// 3つの作戦の(ラベル, 使う能力, 賭けか)。
List<(String, Ability, bool)> finalStances(Player p) => _asPitcher(p)
    ? const [
        ('渾身のストレートで押し切る', Ability.stuff, true),
        ('コースを突いて打ち取る', Ability.control, false),
        ('緩急をつけて打たせて取る', Ability.stamina, false),
      ]
    : const [
        ('強振で一発を狙う', Ability.power, true),
        ('コンパクトに当てにいく', Ability.contact, false),
        ('粘って四球を選ぶ', Ability.eye, false),
      ];

String _abilityShort(Ability a) => switch (a) {
      Ability.contact => 'ミート',
      Ability.power => 'パワー',
      Ability.speed => '走力',
      Ability.fielding => '守備',
      Ability.eye => '選球眼',
      Ability.stuff => '球威',
      Ability.control => '制球',
      Ability.stamina => 'スタミナ',
    };

/// 決勝の見せ場の出来事。ラベルに、使う能力の値を添える(どれが得意か分かる)。
GameEvent finalMomentEvent(Player p) {
  final pitcher = _asPitcher(p);
  final stances = finalStances(p);
  return GameEvent(
    finalMomentId,
    pitcher
        ? '決勝、最終回。1点リードで、最後のマウンドに立つ。どう勝負する?'
        : '決勝、最終回。1点を追う場面で、チャンスの打席が回ってきた。どう勝負する?',
    [
      for (final s in stances)
        EventChoice(
            '${s.$1}(${_abilityShort(s.$2)} ${p.of(s.$2)}${s.$3 ? '・賭け' : ''})',
            (pl, c, f) => (player: pl, condition: c)),
    ],
  );
}

/// 作戦 `index`(0〜2)で足す、決勝に勝つ確率。使う能力が50なら基準のまま、高いほど上がる(最大±約0.12)。
/// 1つ目(強振・渾身の直球)は賭けで、ぶれが大きい。
double finalBonus(int index, Player p, Random rng) {
  final s = finalStances(p)[index];
  final base = (p.of(s.$2) - 50) / 400;
  final swing = s.$3 ? (rng.nextDouble() - 0.5) * 0.14 : 0.0;
  final safe = index == 2 ? 0.02 : 0.0; // 粘る・打たせて取るは、少し堅い
  return base + swing + safe + _baseline;
}
