import 'dart:math';

import '../game/scenarios.dart';
import 'attributes.dart';

/// 局面で特性を評価するときの文脈。
class TraitContext {
  const TraitContext({
    required this.minute,
    required this.home,
    required this.outcome,
    required this.afterFailure,
    required this.afterSuccess,
    required this.key,
    required this.detail,
    required this.scenarioId,
    required this.international,
  });

  final int minute;
  final bool home;
  final Outcome outcome;
  final bool afterFailure;
  final bool afterSuccess;
  final AttributeKey key;
  final Detail? detail;
  final String scenarioId;
  final bool international;
}

/// 選手の特性。キャリア開始時に2つ、たまに欠点が1つ付く。
///
/// 数値の大小ではなく「どういう場面で強いか（弱いか）」を作るもの。
/// どれも一長一短にしてあり、上位互換の特性は無い。
enum Trait {
  // ---- 場面 ----
  clutch('クラッチ', '後半30分以降、成功率が上がる'),
  composed('冷静', 'ゴールに直結する手の成功率が上がる'),
  fighter('負けず嫌い', '失敗した直後の手は成功率が上がる'),
  homeHero('ホームの英雄', 'ホームで成功率が上がり、アウェイで少し下がる'),
  gambler('勝負師', 'ゴール・アシストの手が得意で、安全な手が苦手'),
  craftsman('職人', '安全な手が得意で、ゴールの手が少し苦手'),
  bigGame('大舞台', '代表戦で成功率が上がる'),
  penaltyKing('PK職人', 'PKの局面で大きく有利'),
  captain('キャプテンシー', '評価点が少し高くつく'),

  // ---- 得意技 ----
  aerialAce('空中戦の鬼', 'ヘディングと競り合いに強い'),
  sprinter('スプリンター', 'スピード勝負に強い'),
  playmaker('司令塔', 'パスの手に強い'),
  poacher('ポーチャー', '決定力の手に強い'),
  wall('鉄壁', '守備の手に強い'),

  // ---- 体 ----
  ironman('鉄人', '衰え始める年齢が2年遅い'),
  robust('頑丈', '怪我をしにくい'),
  engine('無尽蔵', '試合と練習の消耗が少ない'),
  earlyBloomer('早熟', '若いうちに速く伸びるが、ピークが早い'),
  lateBloomer('大器晩成', '若いうちは伸びにくいが、ピークが遅く長い'),

  // ---- 欠点 ----
  fragile('怪我がち', '怪我をしやすい', flaw: true),
  moody('気分屋', '直前の結果に引きずられる。成功の後は強く、失敗の後は弱い', flaw: true),
  slowStarter('スロースターター', '前半30分までは成功率が下がる', flaw: true);

  const Trait(this.label, this.description, {this.flaw = false});

  final String label;
  final String description;

  /// 欠点なら true。長所と同じ引き方はしない。
  final bool flaw;

  /// 同時には付かない組み合わせ。
  static const List<Set<Trait>> _exclusive = [
    {Trait.earlyBloomer, Trait.lateBloomer},
    {Trait.gambler, Trait.craftsman},
    {Trait.robust, Trait.fragile},
    {Trait.fighter, Trait.moody},
    {Trait.clutch, Trait.slowStarter},
  ];

  static bool compatible(Trait a, Trait b) =>
      a != b && !_exclusive.any((s) => s.contains(a) && s.contains(b));

  static List<Trait> get strengths => values.where((t) => !t.flaw).toList();
  static List<Trait> get flaws => values.where((t) => t.flaw).toList();

  /// 長所を2つ引き、3割で欠点が1つ付く。矛盾する組み合わせは避ける。
  static List<Trait> roll(Random random, {double flawChance = 0.3}) {
    final picked = <Trait>[];
    final pool = [...strengths]..shuffle(random);
    for (final t in pool) {
      if (picked.length >= 2) break;
      if (picked.every((p) => compatible(p, t))) picked.add(t);
    }
    if (random.nextDouble() < flawChance) {
      final candidates = flaws.where((f) => picked.every((p) => compatible(p, f))).toList();
      if (candidates.isNotEmpty) {
        picked.add(candidates[random.nextInt(candidates.length)]);
      }
    }
    return picked;
  }

  /// 局面での成功率への加算。
  double chanceBonus(TraitContext c) {
    switch (this) {
      case Trait.clutch:
        return c.minute >= 75 ? 0.08 : 0;
      case Trait.composed:
        return c.outcome == Outcome.goal ? 0.05 : 0;
      case Trait.fighter:
        return c.afterFailure ? 0.07 : 0;
      case Trait.homeHero:
        return c.international ? 0 : (c.home ? 0.05 : -0.02);
      case Trait.gambler:
        return c.outcome == Outcome.play ? -0.04 : 0.05;
      case Trait.craftsman:
        return c.outcome == Outcome.play
            ? 0.06
            : (c.outcome == Outcome.goal ? -0.03 : 0);
      case Trait.bigGame:
        return c.international ? 0.08 : 0;
      case Trait.penaltyKing:
        return c.scenarioId.contains('-pk') ? 0.12 : 0;
      case Trait.aerialAce:
        return c.detail == Detail.heading || c.detail == Detail.jumping ? 0.08 : 0;
      case Trait.sprinter:
        return c.key == AttributeKey.pace ? 0.06 : 0;
      case Trait.playmaker:
        return c.key == AttributeKey.passing ? 0.05 : 0;
      case Trait.poacher:
        return c.detail == Detail.finishing ? 0.07 : 0;
      case Trait.wall:
        return c.key == AttributeKey.defending ? 0.06 : 0;
      case Trait.moody:
        return c.afterSuccess ? 0.05 : (c.afterFailure ? -0.06 : 0);
      case Trait.slowStarter:
        return c.minute < 30 ? -0.05 : 0;
      case Trait.captain:
      case Trait.ironman:
      case Trait.robust:
      case Trait.engine:
      case Trait.earlyBloomer:
      case Trait.lateBloomer:
      case Trait.fragile:
        return 0;
    }
  }

  int get peakAgeOffset => switch (this) {
        Trait.earlyBloomer => -2,
        Trait.lateBloomer => 3,
        _ => 0,
      };

  int get declineAgeOffset => switch (this) {
        Trait.ironman => 2,
        Trait.lateBloomer => 2,
        _ => 0,
      };

  /// 成長判定の倍率。年齢で変わる。
  double growthFactor(int age) => switch (this) {
        Trait.earlyBloomer => age <= 22 ? 1.4 : 0.85,
        Trait.lateBloomer => age <= 22 ? 0.7 : 1.25,
        _ => 1.0,
      };

  /// 負傷確率の倍率。
  double get injuryFactor => switch (this) {
        Trait.robust => 0.6,
        Trait.fragile => 1.7,
        _ => 1.0,
      };

  /// 試合・練習の消耗の倍率。
  double get conditionCostFactor => switch (this) {
        Trait.engine => 0.6,
        _ => 1.0,
      };

  /// 試合ごとの評価点への加算。
  double get ratingBonus => switch (this) {
        Trait.captain => 0.15,
        _ => 0,
      };
}

/// 複数の特性をまとめて評価する。
extension TraitList on List<Trait> {
  double chanceBonus(TraitContext c) => fold(0, (sum, t) => sum + t.chanceBonus(c));

  int get peakAgeOffset => fold(0, (s, t) => s + t.peakAgeOffset);
  int get declineAgeOffset => fold(0, (s, t) => s + t.declineAgeOffset);
  double growthFactor(int age) => fold(1.0, (f, t) => f * t.growthFactor(age));
  double get injuryFactor => fold(1.0, (f, t) => f * t.injuryFactor);
  double get conditionCostFactor => fold(1.0, (f, t) => f * t.conditionCostFactor);
  double get ratingBonus => fold(0, (s, t) => s + t.ratingBonus);
}
