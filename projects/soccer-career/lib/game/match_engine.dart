import 'dart:math';

import '../models/attributes.dart';
import '../models/club.dart';
import '../models/injury.dart';
import '../models/player.dart';
import '../models/season.dart';
import '../models/traits.dart';
import 'formulas.dart';
import 'scenarios.dart';

/// 1つの局面を解決した結果。
class ScenarioResolution {
  const ScenarioResolution({
    required this.success,
    required this.text,
    required this.outcome,
    required this.ratingDelta,
    required this.key,
  });

  final bool success;
  final String text;
  final Outcome outcome;
  final double ratingDelta;

  /// 判定に使った能力値。成長の偏りに使う。
  final AttributeKey key;

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
    required this.minutes,
    required this.player,
    required this.club,
    this.international = false,
    Random? random,
  })  : assert(scenarios.length == minutes.length),
        _random = random ?? Random();

  final int matchday;
  final Club opponent;
  final bool home;
  final Appearance appearance;
  final List<Scenario> scenarios;

  /// 各局面が起きる時間（分）。特性の判定と表示に使う。
  final List<int> minutes;

  final Player player;
  final Club club;

  /// 代表戦か。リーグの順位表には影響しない。
  final bool international;

  final Random _random;

  final List<ScenarioResolution> resolutions = [];

  int _index = 0;

  bool get isFinished => _index >= scenarios.length;
  int get currentIndex => _index;
  Scenario get current => scenarios[_index];
  int get currentMinute => minutes[_index];

  /// 直前の手が失敗していたか。「負けず嫌い」の判定に使う。
  bool get afterFailure => resolutions.isNotEmpty && !resolutions.last.success;

  /// 「前半 23分」のような表示用の文字列。
  static String minuteLabel(int minute) =>
      minute <= 45 ? '前半 $minute分' : '後半 ${minute - 45}分';

  int get goals => resolutions.where((r) => r.isGoal).length;
  int get assists => resolutions.where((r) => r.isAssist).length;

  /// 成功した手で使った能力値。成長判定の偏りに使う。
  List<AttributeKey> get successfulKeys =>
      resolutions.where((r) => r.success).map((r) => r.key).toList();

  /// 現時点の評価点。基準値から増減を積み上げる。
  double get rating {
    final total = resolutions.fold<double>(
        Formulas.baseRating, (sum, r) => sum + r.ratingDelta);
    return total.clamp(Formulas.minRating, Formulas.maxRating);
  }

  /// この局面でその手を選んだときの成功率。特性とコンディションを含む。
  ///
  /// 画面に出す数字もこれを使う。表示と判定がずれると、
  /// 「70%と書いてあったのに」という不信感になる。
  double chanceFor(ScenarioOption option) {
    if (isFinished) return 0;
    final base = successChance(player.attributes[option.key], option.difficulty);
    final trait = player.traits.chanceBonus(
      minute: currentMinute,
      home: home,
      outcome: option.outcome,
      afterFailure: afterFailure,
    );
    final condition = conditionModifier(player.condition);
    return (base + trait + condition).clamp(0.05, 0.95);
  }

  /// 選んだ手を解決して次の局面へ進める。
  ScenarioResolution choose(ScenarioOption option) {
    final chance = chanceFor(option);
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
      key: option.key,
    );
    resolutions.add(resolution);
    _index++;
    return resolution;
  }

  /// 能力値と難易度から成功率を出す（特性・コンディション抜きの素の値）。
  ///
  /// 能力値が難易度ちょうどでも五分にはしない。難しい手を選ぶことに
  /// リスクを残さないと、常に一番おいしい選択肢を押すだけのゲームになる。
  static double successChance(int attribute, int difficulty) {
    final chance = 0.42 + (attribute - difficulty) * 0.011;
    return chance.clamp(0.05, 0.92);
  }

  /// コンディションが成功率に与える増減。
  static double conditionModifier(int condition) =>
      (condition - Formulas.conditionBaseline) * Formulas.conditionChanceSlope;

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
      // 出ていない試合に評価点を付けない。付けると平均評価と出場数に
      // 混ざり、出場機会の判断（decideAppearance）まで狂う。
      rating: appearance == Appearance.benched ||
              appearance == Appearance.injured
          ? null
          : rating,
      goals: goals,
      assists: assists,
      international: international,
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

/// 練習と試合の消耗をまとめた1週間の結果。
class WeekOutcome {
  const WeekOutcome({
    required this.attributes,
    required this.condition,
    required this.trained,
    this.injury,
  });

  final Attributes attributes;
  final int condition;

  /// 練習で伸びた能力。伸びなければ null。
  final AttributeKey? trained;

  /// 練習中に負傷したらその内容。
  final Injury? injury;
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
    bool international = false,
  }) {
    final count = switch (appearance) {
      Appearance.start => Formulas.scenariosPerStart,
      Appearance.sub => Formulas.scenariosPerSub,
      Appearance.benched || Appearance.injured => 0,
    };

    final pool = [...ScenarioPool.forPosition(player.position)]..shuffle(_random);
    final picked = pool.take(count).toList();

    return MatchInProgress(
      matchday: matchday,
      opponent: opponent,
      home: home,
      appearance: appearance,
      scenarios: picked,
      minutes: _minutesFor(count, appearance),
      player: player,
      club: club,
      international: international,
      random: _random,
    );
  }

  /// 局面の時間を散らす。途中出場なら後半だけ。
  List<int> _minutesFor(int count, Appearance appearance) {
    if (count == 0) return const [];
    final from = appearance == Appearance.sub ? 60 : 5;
    const to = 90;
    final span = (to - from) ~/ count;
    return [
      for (var i = 0; i < count; i++)
        from + span * i + _random.nextInt(max(1, span - 4)) + 2,
    ];
  }

  /// 成長判定。評価点が良かった試合だけ、1項目が伸びる可能性がある。
  ///
  /// 伸びる項目は、その試合で成功した手の能力に偏らせる。
  /// 選び方が選手を形作るのがキャリアものの面白さで、
  /// ただの乱数だと何を選んでも同じ選手になる。
  ///
  /// ポテンシャルに達したら伸びない。ピークを過ぎると伸びにくくなり、
  /// さらに歳を取ると落ちる。特性で前後する。
  Attributes grow(
    Player player,
    double? rating, {
    List<AttributeKey> used = const [],
  }) {
    if (rating == null) return player.attributes;

    final declineAge = Formulas.declineAge + player.traits.declineAgeOffset;
    if (player.age >= declineAge && _random.nextDouble() < 0.25) {
      return player.attributes.bump(_randomKey(), -1);
    }

    if (rating < Formulas.growthRatingThreshold) return player.attributes;
    if (player.atPotential) return player.attributes;

    final peakAge = Formulas.peakAge + player.traits.peakAgeOffset;
    final ageFactor = player.age <= peakAge ? 1.0 : 0.4;
    final margin = rating - Formulas.growthRatingThreshold;
    final chance =
        (0.18 + margin * 0.22) * ageFactor * player.traits.growthFactor(player.age);
    if (_random.nextDouble() >= chance) return player.attributes;

    final focus =
        used.isNotEmpty && _random.nextDouble() < Formulas.growthFocusChance;
    final key = focus ? used[_random.nextInt(used.length)] : _randomKey();
    return player.attributes.bump(key, 1);
  }

  /// 負傷するかどうかを判定する。
  ///
  /// 疲れているほど、歳を取っているほど起きやすい。ここが練習と休養の
  /// 選択に重みを与えている。休養を「伸びないから無駄」にしないための仕掛け。
  Injury? rollInjury(Player player, {required double baseChance}) {
    final fatigue = (Formulas.conditionBaseline - player.condition)
        .clamp(0, Formulas.conditionMax)
        .toDouble();
    final age = (player.age - Formulas.injuryAgeFrom).clamp(0, 20).toDouble();
    final chance = baseChance +
        fatigue * Formulas.injuryConditionSlope +
        age * Formulas.injuryPerAgeYear;

    if (_random.nextDouble() >= chance) return null;

    // 重い怪我ほど出にくくする。軽傷が大半で、たまに長期離脱。
    final roll = _random.nextDouble();
    final severity = roll < 0.6
        ? InjurySeverity.light
        : roll < 0.92
            ? InjurySeverity.moderate
            : InjurySeverity.severe;
    final kinds =
        InjuryKind.all.where((k) => k.severity == severity).toList();
    final kind = kinds[_random.nextInt(kinds.length)];
    final span = kind.maxMatches - kind.minMatches + 1;
    return Injury(
      name: kind.name,
      severity: kind.severity,
      matchesOut: kind.minMatches + _random.nextInt(span),
    );
  }

  /// 重傷の後遺症。能力とポテンシャルを削る。
  (Attributes, int) applySevereInjury(Player player, Injury injury) {
    if (injury.severity != InjurySeverity.severe) {
      return (player.attributes, player.potential);
    }
    final kind = InjuryKind.all.firstWhere((k) => k.name == injury.name,
        orElse: () => InjuryKind.all.last);
    return (
      player.attributes.bump(kind.affects, -Formulas.severeInjuryAttributeLoss),
      player.potential - Formulas.severeInjuryPotentialLoss,
    );
  }

  /// 試合後の1週間。試合の消耗と、練習または休養を反映する。
  ///
  /// 練習はポテンシャルに達していなければ一定確率で1伸びる。
  /// 休養は伸びない代わりにコンディションが戻る。疲れたまま練習を続けると
  /// 試合の成功率で払うことになる。
  WeekOutcome applyWeek(Player player, {required AttributeKey? training, required bool played}) {
    var condition = player.condition - (played ? Formulas.matchConditionCost : 0);
    var attributes = player.attributes;
    AttributeKey? trained;

    if (training == null) {
      condition += Formulas.restRecovery;
    } else {
      condition -= Formulas.trainingConditionCost;
      final canGrow = attributes.overallFor(player.position) < player.potential;
      if (canGrow && _random.nextDouble() < Formulas.trainingGrowthChance) {
        attributes = attributes.bump(training, 1);
        trained = training;
      }
    }

    final settled = condition.clamp(0, Formulas.conditionMax).toInt();
    // 練習した週だけ、練習中の負傷を判定する。休養に怪我のリスクは無い。
    final injury = training == null
        ? null
        : rollInjury(
            player.copyWith(condition: settled),
            baseChance: Formulas.injuryTrainingChance,
          );

    return WeekOutcome(
      attributes: attributes,
      condition: settled,
      trained: trained,
      injury: injury,
    );
  }

  AttributeKey _randomKey() =>
      AttributeKey.values[_random.nextInt(AttributeKey.values.length)];
}
