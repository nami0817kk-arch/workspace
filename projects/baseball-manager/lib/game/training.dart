import 'dart:math';

import 'career.dart';
import 'player.dart';
import 'traits.dart';

const abilityCap = 99;

/// 体の衰えが早い能力(パワー・走力・守備・球威・スタミナ)。ミート・選球眼・制球は技術なので遅い。
const physicalAbilities = {
  Ability.power,
  Ability.speed,
  Ability.fielding,
  Ability.stuff,
  Ability.stamina,
};

/// 年齢による能力の上限(体の限界)。経験点を振り分けても、これより上には上げられない。
/// 体の能力は29歳、技術の能力は32歳を過ぎると下がり始め、年を追うほど速く下がる
/// (2026-10-26 ユーザー「年取っても振り分けできるから能力が落ちない。現実と乖離してる」)。
/// 長持ち・鋼の肉体など(`declineMultiplier`)はゆるやか、早熟は速い。
/// `-DBAL_AGECAP=0` で上限なし(従来)。
/// 衰えの速さ(×10)。体の能力・技術の能力。`-DBAL_AGEP=25 -DBAL_AGET=17` で試せる。
const tAgePhys = int.fromEnvironment('BAL_AGEP', defaultValue: 25);
const tAgeTech = int.fromEnvironment('BAL_AGET', defaultValue: 17);

int ageCeiling(Player p, Ability a) {
  const on = bool.fromEnvironment('BAL_AGECAP', defaultValue: true);
  if (!on) return abilityCap;
  final phys = physicalAbilities.contains(a);
  final peak = phys ? 29 : 32;
  if (p.age <= peak) return abilityCap;
  final rate = (phys ? tAgePhys : tAgeTech) / 10 * declineMultiplier(p.traits);
  return (abilityCap - rate * pow(p.age - peak, 1.4)).round().clamp(20, abilityCap);
}

/// 上限を超えている能力を、上限まで下げる(年の変わり目)。下がった能力を(能力, 前, 後)で返す。
({Player player, List<(Ability, int, int)> drops}) applyAgeCeiling(Player p) {
  final next = Map<Ability, int>.of(p.abilities);
  final drops = <(Ability, int, int)>[];
  for (final a in abilitiesOf(p.role)) {
    final cap = ageCeiling(p, a);
    if (p.of(a) > cap) {
      drops.add((a, p.of(a), cap));
      next[a] = cap;
    }
  }
  return (player: drops.isEmpty ? p : p.copyWith(abilities: next), drops: drops);
}

/// 1年を進める。`focus` は今年の練習の重点(その選手の役割の能力から選ぶ)。
/// 二刀流は伸びが `0.6` 倍(練習が分散する代わりに両方使える)。
/// 重点は全量、それ以外は4分の1だけ伸びる/落ちる。年齢の曲線は `growthFactor`。
Player advanceYear(Player p, Ability focus, Random rng) {
  assert(abilitiesOf(p.role).contains(focus), 'focus が役割に無い能力');
  final next = Map<Ability, int>.of(p.abilities);
  for (final a in abilitiesOf(p.role)) {
    final noise = rng.nextDouble() * 2 - 1; // -1〜+1
    final delta = (yearlyDelta(p, a, focus) + noise).round();
    next[a] = (p.of(a) + delta).clamp(0, abilityCap);
  }
  return p.copyWith(age: p.age + 1, abilities: next);
}

/// 能力 `a` が1年で動く量(ノイズ抜き)。1年を季節に分けるときはこれを割って使う。
/// 伸びる年は素質が効き、下る年は重点を置いた能力が落ちにくい。
/// 二刀流は練習が分散する。伸びは25%減(衰えは変わらない)。
double yearlyDelta(Player p, Ability a, Ability focus) {
  final g = growthFactor(p.age);
  final talent = 0.5 + p.potential / 100; // 0.5〜1.5
  final split = p.role == Role.twoWay ? 0.75 : 1.0;
  final share = a == focus ? 1.0 : 0.25;
  return g >= 0
      ? 4.0 * g * talent * share * split * growthMultiplier(p.traits, p.age)
      : 3.0 * g * (a == focus ? 0.5 : 1.0) * declineMultiplier(p.traits);
}
