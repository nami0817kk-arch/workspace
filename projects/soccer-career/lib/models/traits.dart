import 'dart:math';

import '../game/scenarios.dart';

/// 選手の特性。キャリア開始時に2つ付く。
///
/// 数値の大小ではなく「どういう場面で強いか」を作るもの。
/// どれも一長一短にしてあり、上位互換の特性は無い。
enum Trait {
  clutch('クラッチ', '後半30分以降、成功率が上がる'),
  composed('冷静', 'ゴールに直結する手の成功率が上がる'),
  fighter('負けず嫌い', '失敗した直後の手は成功率が上がる'),
  homeHero('ホームの英雄', 'ホームで成功率が上がり、アウェイで少し下がる'),
  gambler('勝負師', 'ゴール・アシットの手が得意で、安全な手が苦手'),
  craftsman('職人', '安全な手が得意で、ゴールの手が少し苦手'),
  ironman('鉄人', '衰え始める年齢が2年遅い'),
  earlyBloomer('早熟', '若いうちに速く伸びるが、ピークが早い'),
  lateBloomer('大器晩成', '若いうちは伸びにくいが、ピークが遅く長い');

  const Trait(this.label, this.description);

  final String label;
  final String description;

  /// 同時には付かない組み合わせ。
  static const List<Set<Trait>> _exclusive = [
    {Trait.earlyBloomer, Trait.lateBloomer},
    {Trait.gambler, Trait.craftsman},
  ];

  static bool compatible(Trait a, Trait b) =>
      a != b && !_exclusive.any((s) => s.contains(a) && s.contains(b));

  /// 2つ引く。矛盾する組み合わせは避ける。
  static List<Trait> rollTwo(Random random) {
    final first = values[random.nextInt(values.length)];
    final rest = values.where((t) => compatible(first, t)).toList();
    final second = rest[random.nextInt(rest.length)];
    return [first, second];
  }

  /// 局面での成功率への加算。
  double chanceBonus({
    required int minute,
    required bool home,
    required Outcome outcome,
    required bool afterFailure,
  }) {
    switch (this) {
      case Trait.clutch:
        return minute >= 75 ? 0.08 : 0;
      case Trait.composed:
        return outcome == Outcome.goal ? 0.05 : 0;
      case Trait.fighter:
        return afterFailure ? 0.07 : 0;
      case Trait.homeHero:
        return home ? 0.05 : -0.02;
      case Trait.gambler:
        return outcome == Outcome.play ? -0.04 : 0.05;
      case Trait.craftsman:
        return outcome == Outcome.play ? 0.06 : (outcome == Outcome.goal ? -0.03 : 0);
      case Trait.ironman:
      case Trait.earlyBloomer:
      case Trait.lateBloomer:
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
}

/// 複数の特性をまとめて評価する。
extension TraitList on List<Trait> {
  double chanceBonus({
    required int minute,
    required bool home,
    required Outcome outcome,
    required bool afterFailure,
  }) =>
      fold(
        0,
        (sum, t) =>
            sum +
            t.chanceBonus(
              minute: minute,
              home: home,
              outcome: outcome,
              afterFailure: afterFailure,
            ),
      );

  int get peakAgeOffset => fold(0, (s, t) => s + t.peakAgeOffset);
  int get declineAgeOffset => fold(0, (s, t) => s + t.declineAgeOffset);
  double growthFactor(int age) =>
      fold(1.0, (f, t) => f * t.growthFactor(age));
}
