import 'dart:math';

import 'player.dart';

/// 天賦(才能の偏り)。能力ごとに生まれつき -2〜+2 の偏りがあり、
/// 得意な能力は経験点が少なくて済み、苦手な能力は多く要る。
/// 平均は0になるように抽選する(全体のバランスは変えない)。選手ごとに形が違うので、周回の楽しみになる。
const giftMin = -2;
const giftMax = 2;

/// 偏り1ぶんの、経験点の増減(1段階 8%)。
const giftCostStep = 0.08;

/// 天賦の抽選の重み(-2, -1, 0, +1, +2)。左右対称。
const _giftWeights = [8, 22, 40, 22, 8];

/// 全能力ぶん(使わない能力も。転向で使うようになったとき困らないように)抽選する。
Map<Ability, int> rollGifts(Random rng) {
  final d = <Ability, int>{};
  for (final a in Ability.values) {
    var x = rng.nextInt(100);
    var i = 0;
    while (x >= _giftWeights[i]) {
      x -= _giftWeights[i];
      i++;
    }
    d[a] = i + giftMin;
  }
  return d;
}

/// 経験点にかける倍率(得意ほど小さい)。
double giftCostMultiplier(int g) => 1 - giftCostStep * g.clamp(giftMin, giftMax);

String giftLabel(int g) => switch (g) {
      >= 2 => '天賦',
      1 => '得意',
      0 => '',
      -1 => '苦手',
      _ => '不得手',
    };

/// 説明文(画面の長押し用)。
String giftHint(int g) {
  if (g == 0) return '';
  final pct = (g.abs() * giftCostStep * 100).round();
  return g > 0 ? '才能がある。上げるのに要る経験点が$pct%少ない。' : '苦手。上げるのに要る経験点が$pct%多い。';
}

/// 役割で使う能力のうち、天賦が+2のものの数(「才能の塊」の判定など)。
int topGifts(Role r, Map<Ability, int> gifts) =>
    abilitiesOf(r).where((a) => (gifts[a] ?? 0) >= giftMax).length;

/// 二世: 親のいちばん得意な能力(使う能力のうち天賦が+1以上)を、子が受け継ぐ。
/// 受け継ぐとその能力の天賦が+1(上限+2)になる。無ければ null。
Ability? inheritedGift(Random rng, Role childRole, Map<Ability, int> parent) {
  final cands = [
    for (final a in abilitiesOf(childRole))
      if ((parent[a] ?? 0) >= 1) a,
  ];
  if (cands.isEmpty || rng.nextDouble() >= 0.5) return null;
  cands.sort((x, y) => (parent[y] ?? 0).compareTo(parent[x] ?? 0));
  return cands.first;
}
