/// 監督との約束。
///
/// 監督が与える `SeasonObjective` は**向こうから降ってくる数字**で、
/// プレイヤーは受け取るだけだった。約束は逆に、**自分から数字を口にする**。
/// 「今季15ゴール」と言った瞬間にシーズンの意味が変わり、
/// 達成すれば信頼と年俸が乗り、届かなければ両方を失う。
///
/// 大きく出るほど見返りも罰も大きい。安全に生きるか、賭けるか。
library;

import 'season.dart';

/// 何を約束するか。
enum PromiseKind {
  goals('ゴール'),
  contributions('得点関与'),
  appearances('出場'),
  rating('平均評価');

  const PromiseKind(this.label);

  final String label;
}

/// どれだけ大きく出るか。見返りと罰の大きさ。
///
/// ここがこの機能のバランス調整点。**信頼は監督が代われば白紙に戻る**ので、
/// 年俸の側を効き目の中心に置いてある。
///
/// 見返りと罰は、**実測した達成率で割り戻して**決めてある
/// （`test/promise_sim.dart`、2304シーズン: 67% / 52% / 30%）。
/// 見返りだけを「大きく出るほど大きく」して罰を素直に増やすと、
/// 3回に1回しか通らない `bold` が**押してはいけないボタン**になる。
/// どの出方を選んでも、期待値はわずかに前向きになる幅に置いた。
enum PromiseWeight {
  modest('控えめに言う',
      trustKept: 4, trustBroken: 6, salaryKept: 1.04, salaryBroken: 0.94),
  fair('順当に言う',
      trustKept: 11, trustBroken: 11, salaryKept: 1.09, salaryBroken: 0.91),
  bold('大きく出る',
      trustKept: 30, trustBroken: 12, salaryKept: 1.25, salaryBroken: 0.90);

  const PromiseWeight(
    this.label, {
    required this.trustKept,
    required this.trustBroken,
    required this.salaryKept,
    required this.salaryBroken,
  });

  final String label;

  /// 果たしたときに乗る監督の信頼。
  final int trustKept;

  /// 果たせなかったときに失う監督の信頼。
  final int trustBroken;

  /// 契約更改の年俸に掛かる倍率。
  final double salaryKept;
  final double salaryBroken;
}

/// 口にした約束。1シーズンに1つだけ。取り消せない。
class ManagerPromise {
  const ManagerPromise({
    required this.kind,
    required this.target,
    required this.weight,
    required this.year,
  });

  final PromiseKind kind;

  /// 目標値。平均評価だけ小数を使う。
  final double target;

  final PromiseWeight weight;

  /// 約束したシーズン。シーズンが変われば約束も消える。
  final int year;

  /// 今の到達値。
  double reached(SeasonStats stats) => switch (kind) {
        PromiseKind.goals => stats.goals.toDouble(),
        PromiseKind.contributions => (stats.goals + stats.assists).toDouble(),
        PromiseKind.appearances => stats.appearances.toDouble(),
        PromiseKind.rating => stats.averageRating,
      };

  bool achievedBy(SeasonStats stats) => reached(stats) >= target;

  String get targetLabel => kind == PromiseKind.rating
      ? target.toStringAsFixed(1)
      : target.round().toString();

  /// 「今季 15 ゴール」。
  String get label => switch (kind) {
        PromiseKind.goals => '今季 $targetLabel ゴール',
        PromiseKind.contributions => '今季 得点関与 $targetLabel',
        PromiseKind.appearances => '今季 $targetLabel 試合出場',
        PromiseKind.rating => '今季 平均評価 $targetLabel',
      };

  /// 「あと3」。届いていれば null。
  String? shortfall(SeasonStats stats) {
    final left = target - reached(stats);
    if (left <= 0) return null;
    return kind == PromiseKind.rating
        ? '${left.toStringAsFixed(2)} 足りない'
        : 'あと${left.ceil()}';
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'target': target,
        'weight': weight.name,
        'year': year,
      };

  static ManagerPromise? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ManagerPromise(
      kind: PromiseKind.values.any((v) => v.name == json['kind'])
          ? PromiseKind.values.byName(json['kind'] as String)
          : PromiseKind.goals,
      target: (json['target'] as num).toDouble(),
      weight: PromiseWeight.values.any((v) => v.name == json['weight'])
          ? PromiseWeight.values.byName(json['weight'] as String)
          : PromiseWeight.fair,
      year: json['year'] as int,
    );
  }
}
