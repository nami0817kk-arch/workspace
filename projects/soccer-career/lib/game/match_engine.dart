import 'dart:math';

import '../models/attributes.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/season.dart';
import 'formulas.dart';
import 'scenarios.dart';

/// 1つの局面を解決した結果。
class ScenarioResolution {
  const ScenarioResolution({
    required this.success,
    required this.text,
    required this.outcome,
    required this.ratingDelta,
  });

  final bool success;
  final String text;
  final Outcome outcome;
  final double ratingDelta;

  bool get isGoal => success && outcome == Outcome.goal;
  bool get isAssist => success && outcome == Outcome.assist;
}

/// 試合1つぶんの進行状態。UI はこれを介して局面を1つずつ進める。
class MatchInProgress {
  MatchInProgress({
    required this.matchday,
    required this.opponent,
    required this.home,
    required this.appearance,
    required this.scenarios,
    required this.player,
    required this.club,
    Random? random,
  }) : _random = random ?? Random();

  final int matchday;
  final Club opponent;
  final bool home;
  final Appearance appearance;
  final List<Scenario> scenarios;

  final Player player;
  final Club club;
  final Random _random;

  final List<ScenarioResolution> resolutions = [];

  int _index = 0;

  bool get isFinished => _index >= scenarios.length;
  int get currentIndex => _index;
  Scenario get current => scenarios[_index];

  int get goals => resolutions.where((r) => r.isGoal).length;
  int get assists => resolutions.where((r) => r.isAssist).length;

  /// 現時点の評価点。基準値から増減を積み上げる。
  double get rating {
    final total = resolutions.fold<double>(
        Formulas.baseRating, (sum, r) => sum + r.ratingDelta);
    return total.clamp(Formulas.minRating, Formulas.maxRating);
  }

  /// 選んだ手を解決して次の局面へ進める。
  ScenarioResolution choose(ScenarioOption option) {
    final attribute = player.attributes[option.key];
    final chance = successChance(attribute, option.difficulty);
    final success = _random.nextDouble() < chance;

    var delta = success ? Formulas.ratingPerSuccess : Formulas.ratingPerFailure;
    if (success) {
      if (option.outcome == Outcome.goal) delta += Formulas.ratingPerGoal;
      if (option.outcome == Outcome.assist) delta += Formulas.ratingPerAssist;
    }

    final resolution = ScenarioResolution(
      success: success,
      text: success ? option.successText : option.failureText,
      outcome: option.outcome,
      ratingDelta: delta,
    );
    resolutions.add(resolution);
    _index++;
    return resolution;
  }

  /// 能力値と難易度から成功率を出す。
  ///
  /// 能力値が難易度ちょうどでも五分にはしない。難しい手を選ぶことに
  /// リスクを残さないと、常に一番おいしい選択肢を押すだけのゲームになる。
  static double successChance(int attribute, int difficulty) {
    final chance = 0.42 + (attribute - difficulty) * 0.011;
    return chance.clamp(0.05, 0.92);
  }

  /// 試合結果を確定させる。
  ///
  /// スコアはクラブ間の力量差から作り、そこに自分の得点を足す。
  /// 自分が決めた分は必ずチームの得点に反映される。
  MatchResult finish() {
    final advantage = club.strength - opponent.strength + (home ? 6 : -2);
    final teamGoals = _poissonish(1.25 + advantage / 40);
    final concededGoals = _poissonish(1.25 - advantage / 40);

    final scored = max(teamGoals, goals);
    return MatchResult(
      matchday: matchday,
      opponentName: opponent.name,
      home: home,
      scored: scored,
      conceded: max(0, concededGoals),
      appearance: appearance,
      rating: appearance == Appearance.benched ? null : rating,
      goals: goals,
      assists: assists,
    );
  }

  /// 得点数のばらつき。厳密なポアソンではないが、0〜5点の分布として十分。
  int _poissonish(double mean) {
    final m = mean.clamp(0.2, 4.0);
    var goals = 0;
    for (var i = 0; i < 6; i++) {
      if (_random.nextDouble() < m / 6) goals++;
    }
    return goals;
  }
}

/// 試合を組み立てる。
class MatchEngine {
  MatchEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 直近の評価点から、その試合の出場の仕方を決める。
  ///
  /// 実績が無いうち（デビュー前）は先発から始める。プレイヤーが最初の試合で
  /// いきなりベンチ外になると、何もしないまま数試合が過ぎてしまう。
  static Appearance decideAppearance(List<MatchResult> recent) {
    final rated =
        recent.where((r) => r.rating != null).map((r) => r.rating!).toList();
    if (rated.isEmpty) return Appearance.start;

    final window = rated.length <= Formulas.formWindow
        ? rated
        : rated.sublist(rated.length - Formulas.formWindow);
    final average = window.reduce((a, b) => a + b) / window.length;

    if (average < Formulas.squadThreshold) return Appearance.benched;
    if (average < Formulas.benchThreshold) return Appearance.sub;
    return Appearance.start;
  }

  MatchInProgress start({
    required int matchday,
    required Player player,
    required Club club,
    required Club opponent,
    required bool home,
    required Appearance appearance,
  }) {
    final count = switch (appearance) {
      Appearance.start => Formulas.scenariosPerStart,
      Appearance.sub => Formulas.scenariosPerSub,
      Appearance.benched => 0,
    };

    final pool = [...ScenarioPool.forPosition(player.position)]..shuffle(_random);
    final picked = pool.take(count).toList();

    return MatchInProgress(
      matchday: matchday,
      opponent: opponent,
      home: home,
      appearance: appearance,
      scenarios: picked,
      player: player,
      club: club,
      random: _random,
    );
  }

  /// 成長判定。評価点が良かった試合だけ、1項目が伸びる可能性がある。
  ///
  /// ピークを過ぎると伸びにくくなり、さらに歳を取ると落ちる。
  /// 現役の終わりが来ることが、キャリアものの緊張感になる。
  Attributes grow(Player player, double? rating) {
    if (rating == null) return player.attributes;

    if (player.age >= Formulas.declineAge && _random.nextDouble() < 0.25) {
      final key = AttributeKey.values[_random.nextInt(AttributeKey.values.length)];
      return player.attributes.bump(key, -1);
    }

    if (rating < Formulas.growthRatingThreshold) return player.attributes;

    final ageFactor = player.age <= Formulas.peakAge ? 1.0 : 0.4;
    final margin = rating - Formulas.growthRatingThreshold;
    final chance = (0.18 + margin * 0.22) * ageFactor;
    if (_random.nextDouble() >= chance) return player.attributes;

    final key = AttributeKey.values[_random.nextInt(AttributeKey.values.length)];
    return player.attributes.bump(key, 1);
  }
}
