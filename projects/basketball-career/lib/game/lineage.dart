// 次の世代へ: 引退した選手の「子ども」か「教え子」として、次の選手を始める。
//
// 子どもは身長の素質と特性を1つ受け継ぎ、教え子は親(師匠)のいちばん得意な能力を少し教わって始まる。
// どちらも、親の栄誉が大きいほど素質が少し上がる。周回の動機を「物語」にする(殿堂の実績による初期能力の上乗せとは別)。
import 'dart:math';

import 'game.dart';
import 'player.dart';
import 'traits.dart';

/// 受け継ぐ形。
enum HeirKind {
  child('子ども', '身長の素質と、特性を1つ受け継ぐ。'),
  pupil('教え子', 'いちばん得意だった能力を教わって始まり、コーチとの信頼も高い。');

  const HeirKind(this.label, this.description);
  final String label;
  final String description;

  static HeirKind? fromName(Object? name) {
    for (final k in HeirKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// 次の選手が受け継ぐもの。
class Heir {
  const Heir({
    required this.kind,
    required this.parentName,
    required this.parentTitle,
    required this.generation,
    this.heightGenes,
    this.trait,
    this.taughtAbility,
    this.potentialBonus = 0,
  });

  final HeirKind kind;
  final String parentName;
  final String parentTitle;

  /// 何代目か(最初の選手が1、その次が2)。
  final int generation;

  /// 子ども: 身長の素質(親と、生まれの運の間)。
  final double? heightGenes;

  /// 子ども: 受け継ぐ特性。
  final Trait? trait;

  /// 教え子: 教わる能力(はじめから +[taughtBonus])。
  final Ability? taughtAbility;

  /// 素質(ポテンシャル)への上乗せ(親の栄誉で 0〜6)。
  final int potentialBonus;

  /// 受け継ぐものの説明(はじめの画面に出す)。
  List<String> get summary => [
        if (heightGenes != null) '身長の素質(親ゆずり)',
        if (trait != null) '特性「${trait!.label}」',
        if (taughtAbility != null) '${taughtAbility!.label} +$taughtBonus(教わった)',
        if (kind == HeirKind.pupil) 'コーチとの信頼 $pupilCoachBond から',
        if (potentialBonus > 0) '素質 +$potentialBonus',
      ];

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'parentName': parentName,
        'parentTitle': parentTitle,
        'generation': generation,
        'heightGenes': heightGenes,
        'trait': trait?.name,
        'taught': taughtAbility?.name,
        'potentialBonus': potentialBonus,
      };

  /// 読めなければ null(壊れた保存でも落ちない)。
  static Heir? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = HeirKind.fromName(j['kind']);
    if (kind == null) return null;
    Ability? taught;
    for (final a in Ability.values) {
      if (a.name == j['taught']) taught = a;
    }
    Trait? trait;
    for (final t in Trait.values) {
      if (t.name == j['trait']) trait = t;
    }
    return Heir(
      kind: kind,
      parentName: (j['parentName'] as String?) ?? '',
      parentTitle: (j['parentTitle'] as String?) ?? '',
      generation: ((j['generation'] as num?)?.toInt() ?? 2).clamp(2, 999),
      heightGenes: (j['heightGenes'] as num?)?.toDouble().clamp(0.0, 1.0),
      trait: trait,
      taughtAbility: taught,
      potentialBonus: ((j['potentialBonus'] as num?)?.toInt() ?? 0).clamp(0, maxHeirPotentialBonus),
    );
  }
}

/// 教え子が教わる能力の上乗せと、はじめのコーチとの信頼。
const taughtBonus = 6;
const pupilCoachBond = 45;

/// 親の栄誉による素質の上乗せの上限。
const maxHeirPotentialBonus = 6;

/// 親の栄誉による素質の上乗せ: プロになった +2、プロで優勝 +2、永久欠番か世界王者 +2。
int heirPotentialBonus({required bool wentPro, required bool proChampion, required bool legend}) =>
    ((wentPro ? 2 : 0) + (proChampion ? 2 : 0) + (legend ? 2 : 0)).clamp(0, maxHeirPotentialBonus);

/// 引退した選手から、次の選手が受け継ぐものを決める。
Heir heirOf(Game parent, HeirKind kind, Random rng,
    {required String title, required bool legend}) {
  final p = parent.player;
  final bonus = heirPotentialBonus(
    wentPro: parent.records.any((r) => r.league.name.startsWith('pro')),
    proChampion: parent.proTitles > 0,
    legend: legend,
  );
  final base = (
    kind: kind,
    parentName: p.name,
    parentTitle: title,
    generation: parent.generation + 1,
    potentialBonus: bonus,
  );
  switch (kind) {
    case HeirKind.child:
      final traits = p.traits.where((t) => t.positive).toList()..sort((a, b) => a.index.compareTo(b.index));
      return Heir(
        kind: base.kind,
        parentName: base.parentName,
        parentTitle: base.parentTitle,
        generation: base.generation,
        potentialBonus: base.potentialBonus,
        // 親と、生まれの運の間(親が大きいほど大きくなりやすい)。
        heightGenes: ((p.heightGenes + rng.nextDouble()) / 2).clamp(0.0, 1.0),
        trait: traits.isEmpty ? null : traits[rng.nextInt(traits.length)],
      );
    case HeirKind.pupil:
      final best = Ability.values.reduce((a, b) => p.of(b) > p.of(a) ? b : a);
      return Heir(
        kind: base.kind,
        parentName: base.parentName,
        parentTitle: base.parentTitle,
        generation: base.generation,
        potentialBonus: base.potentialBonus,
        taughtAbility: best,
      );
  }
}

/// 受け継いだ特性を、生まれつきの特性に足す(両立しないものは足さない)。
Set<Trait> withInherited(Set<Trait> innate, Heir? heir) {
  final t = heir?.trait;
  if (t == null || innate.contains(t) || !canGain(innate, t)) return innate;
  return gain(innate, t);
}
