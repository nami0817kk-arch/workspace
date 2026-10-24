import 'dart:math';

import 'match.dart';
import 'player.dart';

/// 特性。能力とは別に、選手の個性として効き方を変える。
enum Trait {
  lateBloomer('大器晩成', '少年期は伸びが鈍いが、19歳以降に大きく伸びる。', true),
  earlyBloomer('早熟', '若いうちは伸びが大きいが、衰えも早い。', false),
  hardWorker('努力家', '練習の伸びが1割増える。', true),
  genius('天才肌', '伸びが2割増える。', true),
  sturdy('頑丈', '怪我をしにくい。', true),
  glassBody('ガラスの肉体', '怪我をしやすいが、伸びは1.15倍。', false),
  ironMan('鉄人', '疲れが溜まりにくい。', true),
  sunny('前向き', '気持ちが上がりやすく、下がりにくい。', true),
  clutch('勝負強い', '勝負どころの成功率が上がる。', true),
  nervy('ノミの心臓', '勝負どころの成功率が下がる。', false),
  starPower('華がある', '進路の評価に+5。', true),
  longevity('長持ち', '衰えがゆるやか。', true),

  // ── バスケ特有 ──
  wingspan('長いウイングスパン', '腕が長い。リバウンドとディフェンスが+4、ブロックが増える。', true),
  lefty('左利き', '相手が慣れていない。勝負どころのドライブと3Pの成功率+4%。', true),
  basketballIq('バスケIQ', '試合の読みが鋭い。パス・ミドル・ディフェンスの伸びが1.25倍。', true),
  shooterBorn('3Pの申し子', 'シュートタッチが天性のもの。3Pとフリースローの伸びが1.3倍。', true),
  lockdown('守備の鬼', '相手のエースを抑え込む。ディフェンスとスピードの伸びが1.2倍、スティールが増える。', true),
  athletic('アスレチック', 'ずば抜けた身体能力。スピードとフィジカルの伸びが1.2倍。', true),
  captain('キャプテンシー', 'チームをまとめる。チームワークが薄れにくく、大会の味方の強さ+0.5。', true),
  gameSmart('試合巧者', '流れを読む。ハーフタイムの作戦と相性の効きが1.3倍。', true);

  const Trait(this.label, this.description, this.positive);
  final String label;
  final String description;

  /// 良い特性か(画面の色分けや、抽選の重みに使う)。
  final bool positive;

  static Trait? parse(String s) {
    for (final t in Trait.values) {
      if (t.name == s) return t;
    }
    return null;
  }
}

const maxTraits = 4;

/// 同時に持てない組み合わせ。
const _conflicts = <Trait, Trait>{
  Trait.lateBloomer: Trait.earlyBloomer,
  Trait.sturdy: Trait.glassBody,
  Trait.clutch: Trait.nervy,
};

bool _conflict(Trait a, Trait b) => _conflicts[a] == b || _conflicts[b] == a;

bool canGain(Set<Trait> have, Trait t) =>
    !have.contains(t) &&
    have.length < maxTraits &&
    !have.any((h) => _conflict(h, t));

Set<Trait> gain(Set<Trait> have, Trait t) =>
    canGain(have, t) ? {...have, t} : have;

/// 生まれつきの特性。0〜2個。良い特性が出やすい(悪いものは半分)。
Set<Trait> rollInnateTraits(Random rng) {
  final r = rng.nextDouble();
  final n = r < 0.35 ? 0 : (r < 0.80 ? 1 : 2);
  var have = <Trait>{};
  for (var i = 0; i < n; i++) {
    final pool = [
      for (final t in Trait.values)
        if (canGain(have, t)) ...List.filled(t.positive ? 2 : 1, t),
    ];
    if (pool.isEmpty) break;
    have = gain(have, pool[rng.nextInt(pool.length)]);
  }
  return have;
}

// ── 効き方。各システムはここだけを見る ──

double growthMultiplier(Set<Trait> t, int age) {
  var m = 1.0;
  if (t.contains(Trait.lateBloomer)) m *= age < 19 ? 0.7 : 1.4;
  if (t.contains(Trait.earlyBloomer)) m *= age < 16 ? 1.3 : 1.0;
  if (t.contains(Trait.hardWorker)) m *= 1.1;
  if (t.contains(Trait.genius)) m *= 1.2;
  if (t.contains(Trait.glassBody)) m *= 1.15;
  return m;
}

/// 能力ごとの伸びの倍率(バスケ特有の特性)。伸びる年にだけ効く。
double abilityGrowthMultiplier(Set<Trait> t, Ability a) {
  var m = 1.0;
  if (t.contains(Trait.basketballIq) &&
      (a == Ability.pass || a == Ability.midRange || a == Ability.defense)) {
    m *= 1.25;
  }
  if (t.contains(Trait.shooterBorn) &&
      (a == Ability.threePoint || a == Ability.freeThrow)) {
    m *= 1.3;
  }
  if (t.contains(Trait.lockdown) &&
      (a == Ability.defense || a == Ability.speed)) {
    m *= 1.2;
  }
  if (t.contains(Trait.athletic) &&
      (a == Ability.speed || a == Ability.physical)) {
    m *= 1.2;
  }
  return m;
}

/// 実効値への加算(長い腕はリバウンドとディフェンスに効く)。
double effectiveBonus(Set<Trait> t, Ability a) =>
    t.contains(Trait.wingspan) && (a == Ability.rebound || a == Ability.defense)
        ? 4
        : 0;

/// 勝負どころのプレーごとの加算(左利きはドライブと3P)。
double clutchPlayBonus(Set<Trait> t, Clutch c) =>
    t.contains(Trait.lefty) && (c == Clutch.drive || c == Clutch.threePoint)
        ? 0.04
        : 0;

/// 1試合のスティール・ブロックの倍率。
double stealMultiplier(Set<Trait> t) => t.contains(Trait.lockdown) ? 1.3 : 1.0;
double blockMultiplier(Set<Trait> t) => t.contains(Trait.wingspan) ? 1.3 : 1.0;

/// チームワークが毎ターン薄れる量(キャプテンシーは半分)。
int teamworkDecay(Set<Trait> t) => t.contains(Trait.captain) ? 1 : 2;

/// 大会の味方の強さへの加算。
double traitTeamBonus(Set<Trait> t) => t.contains(Trait.captain) ? 0.5 : 0.0;

/// ハーフタイムの作戦と相手の持ち味との相性の効きの倍率。
double halftimeFitMultiplier(Set<Trait> t) =>
    t.contains(Trait.gameSmart) ? 1.3 : 1.0;

double declineMultiplier(Set<Trait> t) {
  var m = 1.0;
  if (t.contains(Trait.earlyBloomer)) m *= 1.3;
  if (t.contains(Trait.longevity)) m *= 0.6;
  return m;
}

double injuryMultiplier(Set<Trait> t) {
  var m = 1.0;
  if (t.contains(Trait.sturdy)) m *= 0.5;
  if (t.contains(Trait.glassBody)) m *= 1.8;
  return m;
}

double fatigueMultiplier(Set<Trait> t) => t.contains(Trait.ironMan) ? 0.7 : 1.0;

double moraleGainMultiplier(Set<Trait> t) =>
    t.contains(Trait.sunny) ? 1.5 : 1.0;
double moraleLossMultiplier(Set<Trait> t) =>
    t.contains(Trait.sunny) ? 0.5 : 1.0;

/// 勝負どころの成功率に足す値(0〜1 の確率)。
double clutchBonus(Set<Trait> t) =>
    (t.contains(Trait.clutch) ? 0.10 : 0) -
    (t.contains(Trait.nervy) ? 0.10 : 0);

/// 進路の点数に足す値。
double scoutBonus(Set<Trait> t) => t.contains(Trait.starPower) ? 5 : 0;
