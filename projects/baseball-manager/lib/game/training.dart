import 'dart:math';

import 'career.dart';
import 'player.dart';
import 'traits.dart';

const abilityCap = 99;

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
