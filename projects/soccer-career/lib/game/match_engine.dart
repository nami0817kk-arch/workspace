import 'dart:math';

import '../models/attributes.dart';
import '../models/club.dart';
import '../models/development.dart';
import '../models/injury.dart';
import '../models/physique.dart';
import '../models/player.dart';
import '../models/season.dart';
import '../models/support.dart';
import '../models/traits.dart';
import '../models/training.dart';
import 'dependencies.dart';
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
    this.detail,
  });

  final bool success;
  final String text;
  final Outcome outcome;
  final double ratingDelta;

  /// 判定に使った能力のカテゴリ。成長の偏りに使う。
  final AttributeKey key;

  /// 判定に使った詳細能力。あればこちらが伸びる。
  final Detail? detail;

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
    this.development = const Development(),
    this.teammateGoalMinutes = const [],
    this.concededMinutes = const [],
    this.allyBonus = 0,
    this.moodBonus = 0,
    this.extraRating = 0,
    this.weakFootMoments = const [],
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

  /// 経験・選択の癖・相手への慣れ・個人技。
  final Development development;

  /// 味方が決める時間。試合が始まる前に決めておく。
  ///
  /// 終わってからスコアを作ると、試合中に「今どうなっているか」が
  /// 存在しない。1点負けている終盤の1本と、3点リードでの1本が
  /// 同じ重さになってしまう。
  final List<int> teammateGoalMinutes;

  /// 相手が決める時間。
  final List<int> concededMinutes;

  /// 相方との呼吸。味方を活かす手にだけ効く。
  final double allyBonus;

  /// 気持ちと波（ゾーン／スランプ）。すべての手に同じだけ効く。
  final double moodBonus;

  /// 評価点への上乗せ。腕章を巻いている試合など。
  final double extraRating;

  /// 逆足で対応することになる局面。試合開始時に決めておく。
  ///
  /// 呼ぶたびに引き直すと、画面に出した成功率と判定がずれる。
  final List<bool> weakFootMoments;

  /// 代表戦か。リーグの順位表には影響しない。
  final bool international;

  final Random _random;

  final List<ScenarioResolution> resolutions = [];

  int _index = 0;

  bool get isFinished => _index >= scenarios.length;
  int get currentIndex => _index;
  Scenario get current => scenarios[_index];
  int get currentMinute => minutes[_index];

  /// 直前の手が失敗していたか。「負けず嫌い」「気分屋」の判定に使う。
  bool get afterFailure => resolutions.isNotEmpty && !resolutions.last.success;
  bool get afterSuccess => resolutions.isNotEmpty && resolutions.last.success;

  /// 自分が決めた得点の時間。
  final List<int> ownGoalMinutes = [];

  /// その時点での自分たちの得点。
  int scoredBy(int minute) =>
      teammateGoalMinutes.where((m) => m <= minute).length +
      ownGoalMinutes.where((m) => m <= minute).length;

  /// その時点での失点。
  int concededBy(int minute) =>
      concededMinutes.where((m) => m <= minute).length;

  /// 今の局面の時点でのスコア表示（例: 1 - 2）。
  String get scoreLine {
    final minute = isFinished ? 90 : currentMinute;
    return '${scoredBy(minute)} - ${concededBy(minute)}';
  }

  /// 今の局面の時点での得失点差。負けていれば負の数。
  int get margin {
    final minute = isFinished ? 90 : currentMinute;
    return scoredBy(minute) - concededBy(minute);
  }

  /// 終盤か。ここでの1点は重い。
  bool get lateGame => !isFinished && currentMinute >= Formulas.lateGameMinute;

  /// 今の状況を一言で。画面に出す。
  String? get situationLabel {
    if (isFinished) return null;
    if (!lateGame) return null;
    if (margin < 0) return '${-margin}点ビハインド・終盤';
    if (margin == 0) return '同点・終盤';
    return '$margin点リード・終盤';
  }

  /// 相手の戦い方。
  ClubStyle get opponentStyle => ClubStyle.of(opponent);

  /// 今の局面が逆足で対応するものか。
  bool get weakFootMoment =>
      !isFinished &&
      _index < weakFootMoments.length &&
      weakFootMoments[_index];

  /// 大一番か。格上との対戦と代表戦は、それだけで重い。
  bool get bigMatch =>
      international || opponent.strength - club.strength >= 8;

  /// 「前半 23分」のような表示用の文字列。
  static String minuteLabel(int minute) =>
      minute <= 45 ? '前半 $minute分' : '後半 ${minute - 45}分';

  int get goals => resolutions.where((r) => r.isGoal).length;
  int get assists => resolutions.where((r) => r.isAssist).length;

  /// 成功した手で使った能力。成長判定の偏りに使う。
  List<ScenarioResolution> get successes =>
      resolutions.where((r) => r.success).toList();

  /// 現時点の評価点。基準値から増減を積み上げ、特性の補正を足す。
  double get rating {
    final total = resolutions.fold<double>(
            Formulas.baseRating, (sum, r) => sum + r.ratingDelta) +
        player.traits.ratingBonus +
        extraRating;
    return total.clamp(Formulas.minRating, Formulas.maxRating);
  }

  /// この選択肢の判定に使う能力値。詳細があればそれ、無ければカテゴリ平均。
  ///
  /// 身体の補正込みで見る。同じ「ヘディング60」でも、190cm と 170cm では
  /// 競り合いの結果が変わってほしい。
  int attributeFor(ScenarioOption option) => option.detail != null
      ? player.effective(option.detail!)
      : player.effectiveFor(option.key);

  /// この局面でその手を選んだときの成功率。特性とコンディションを含む。
  ///
  /// 画面に出す数字もこれを使う。表示と判定がずれると、
  /// 「70%と書いてあったのに」という不信感になる。
  double chanceFor(ScenarioOption option) {
    if (isFinished) return 0;
    final base = successChance(attributeFor(option), option.difficulty);
    final trait = player.traits.chanceBonus(TraitContext(
      minute: currentMinute,
      home: home,
      outcome: option.outcome,
      afterFailure: afterFailure,
      afterSuccess: afterSuccess,
      key: option.key,
      detail: option.detail,
      scenarioId: current.id,
      international: international,
    ));
    final condition = conditionModifier(player.condition);
    // 相手の格。上のリーグほど同じ手が通らなくなる。
    final level = (Formulas.opponentBaseline - opponent.strength) *
        Formulas.opponentChanceSlope;
    // 自信は小さく効かせる。性格で試合が決まると能力を伸ばす意味が薄れる。
    final personality = player.personality.chanceModifier;

    // 積み上げてきたもの。型・個人技・相手への慣れ。
    final identity = development.identityBonusFor(option.key);
    final signature = development.signatureBonus(option.key, option.detail);
    final matchup = opponentStyle.hardFor == option.key
        ? -0.05 + development.adaptationFor(opponentStyle)
        : 0.0;

    // 大一番の重圧。経験と自信で薄まり、若く自信の無い選手ほど呑まれる。
    final pressure = bigMatch
        ? -0.05 +
            development.composure +
            (player.personality.confidence - 10) * 0.004
        : 0.0;

    // 相方との呼吸。パスを受ける側が動いてくれるかどうか。
    final ally = option.outcome == Outcome.assist ? allyBonus : 0.0;

    // 逆足。利き足でないほうで対応する局面は、精度がそのまま出る。
    final weakFoot = weakFootMoment && _usesFoot(option)
        ? -(5 - player.physique.weakFoot) * 0.03
        : 0.0;

    return (base +
            trait +
            condition +
            personality +
            level +
            identity +
            signature +
            matchup +
            pressure +
            ally +
            moodBonus +
            weakFoot)
        .clamp(0.05, 0.95);
  }

  /// 足で扱う手か。ヘディングと守備の局面に逆足は関係しない。
  static bool _usesFoot(ScenarioOption option) =>
      option.detail != Detail.heading &&
      (option.key == AttributeKey.shooting ||
          option.key == AttributeKey.passing ||
          option.key == AttributeKey.dribbling);

  /// 決めきれなかったときの文。
  static const String missedGoal = 'シュートは枠を捉えたが、GKが弾いた。';
  static const String missedAssist = '良いボールが入ったが、味方が決めきれなかった。';

  /// 選んだ手を解決して次の局面へ進める。
  ///
  /// 手そのものの成否と、それが得点になるかは別に扱う。
  /// 良い判断でも点にならない試合があるほうが、決まった1点が重くなる。
  ScenarioResolution choose(ScenarioOption option) {
    final chance = chanceFor(option);
    final success = _random.nextDouble() < chance;

    var delta = success ? Formulas.ratingPerSuccess : Formulas.ratingPerFailure;
    var outcome = option.outcome;
    var text = success ? option.successText : option.failureText;

    if (success && outcome != Outcome.play) {
      final converts = _random.nextDouble() <
          (outcome == Outcome.goal
              ? Formulas.goalConversion
              : Formulas.assistConversion);
      if (converts) {
        if (outcome == Outcome.goal) {
          // 追いついた・突き放した1点は重く見る。
          final before = margin;
          ownGoalMinutes.add(currentMinute);
          final decisive = lateGame && before <= 0;
          delta += Formulas.ratingPerGoal *
              (decisive ? Formulas.decisiveGoalFactor : 1.0);
        } else {
          delta += Formulas.ratingPerAssist;
        }
      } else {
        text = outcome == Outcome.goal ? missedGoal : missedAssist;
        outcome = Outcome.play;
      }
    }

    final resolution = ScenarioResolution(
      success: success,
      text: text,
      outcome: outcome,
      ratingDelta: delta,
      key: option.key,
      detail: option.detail,
    );
    resolutions.add(resolution);
    _index++;
    return resolution;
  }

  /// 期待される評価点の増減。自動で選ぶときの物差し。
  ///
  /// 決まる確率まで含めて見る。含めないと、自動進行が得点の手を
  /// 実際の価値より高く買ってしまう。
  double expectedDelta(ScenarioOption option) {
    final p = chanceFor(option);
    var gain = Formulas.ratingPerSuccess;
    if (option.outcome == Outcome.goal) {
      gain += Formulas.ratingPerGoal * Formulas.goalConversion;
    }
    if (option.outcome == Outcome.assist) {
      gain += Formulas.ratingPerAssist * Formulas.assistConversion;
    }
    return p * gain + (1 - p) * Formulas.ratingPerFailure;
  }

  /// スタイルに沿って手を1つ選ぶ。
  ///
  /// 「安全」は成功率、「バランス」は期待値、「勝負」は得点に繋がる手の中で
  /// 期待値が最も高いもの。人が選ぶときの癖を3つに絞った。
  ScenarioOption pickFor(SimStyle style) {
    final options = current.options;
    ScenarioOption best(Iterable<ScenarioOption> from, double Function(ScenarioOption) score) =>
        from.reduce((a, b) => score(a) >= score(b) ? a : b);

    switch (style) {
      case SimStyle.safe:
        return best(options, chanceFor);
      case SimStyle.balanced:
        return best(options, expectedDelta);
      case SimStyle.aggressive:
        final scoring = options.where((o) => o.outcome != Outcome.play);
        return best(scoring.isEmpty ? options : scoring, expectedDelta);
    }
  }

  /// 残りの局面を自動で解決する。
  void autoPlay(SimStyle style) {
    while (!isFinished) {
      choose(pickFor(style));
    }
  }

  /// 能力値と難易度から成功率を出す（特性・コンディション抜きの素の値）。
  ///
  /// 能力値が難易度ちょうどでも五分にはしない。難しい手を選ぶことに
  /// リスクを残さないと、常に一番おいしい選択肢を押すだけのゲームになる。
  static double successChance(int attribute, int difficulty) {
    final chance = 0.40 + (attribute - difficulty) * 0.009;
    return chance.clamp(0.05, 0.90);
  }

  /// コンディションが成功率に与える増減。
  static double conditionModifier(int condition) =>
      (condition - Formulas.conditionBaseline) * Formulas.conditionChanceSlope;

  /// この試合で回ってきたセットプレーの機会。finish() で確定する。
  String? deadBallText;

  /// セットプレーの好機を1度だけ判定する。
  ///
  /// キッカーを任される水準（[SetPieceSkills.isTaker]）に達している選手にだけ
  /// 回ってくる。居残り練習が試合の数字に出る唯一の道。
  (int, int) _resolveDeadBall() {
    if (!player.setPieces.isTaker) return (0, 0);
    final chance = switch (appearance) {
      Appearance.start => Formulas.deadBallChanceStart,
      Appearance.sub => Formulas.deadBallChanceSub,
      Appearance.benched || Appearance.injured => 0.0,
    };
    if (_random.nextDouble() >= chance) return (0, 0);

    final piece = player.setPieces.best;
    final skill = player.setPieces[piece];
    switch (piece) {
      case SetPiece.freeKick:
        final hit = _random.nextDouble() < (skill - 40) / 220;
        deadBallText = hit ? '直接FKを沈めた' : '直接FKは壁に当たった';
        return (hit ? 1 : 0, 0);
      case SetPiece.penalty:
        final hit = _random.nextDouble() < (0.55 + skill / 260).clamp(0.5, 0.95);
        deadBallText = hit ? 'PKを決めた' : 'PKを止められた';
        return (hit ? 1 : 0, 0);
      case SetPiece.corner:
        final hit = _random.nextDouble() < (skill - 30) / 200;
        deadBallText = hit ? 'CKから味方の頭に合わせた' : 'CKは跳ね返された';
        return (0, hit ? 1 : 0);
    }
  }

  /// 試合結果を確定させる。
  ///
  /// スコアはクラブ間の力量差から作り、そこに自分の得点を足す。
  /// 自分が決めた分は必ずチームの得点に反映される。
  MatchResult finish() {
    final teamGoals = teammateGoalMinutes.length;
    final concededGoals = concededMinutes.length;

    // 守備の選手は、失点の少なさで評価される。
    final defensive = _defensiveWeight(player.position);
    final defence = defensive == 0
        ? 0.0
        : defensive *
            ((Formulas.cleanSheetBase - max(0, concededGoals)) *
                    Formulas.cleanSheetSlope)
                .clamp(Formulas.cleanSheetMin, Formulas.cleanSheetMax);

    final (extraGoals, extraAssists) = _resolveDeadBall();
    final myGoals = goals + extraGoals;
    // 自分の得点は味方の得点に上乗せする。自分が決めた分は必ずスコアに出る。
    final scored = teamGoals + myGoals;
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
          : (rating +
                  defence +
                  extraGoals * Formulas.ratingPerGoal +
                  extraAssists * Formulas.ratingPerAssist)
              .clamp(Formulas.minRating, Formulas.maxRating),
      goals: myGoals,
      assists: assists + extraAssists,
      international: international,
    );
  }

  /// 失点の少なさをどれだけ自分の評価に乗せるか。
  ///
  /// GK と最終ラインは丸ごと、守備的MFは半分。前の選手は乗らない。
  static double _defensiveWeight(Position position) => switch (position) {
        Position.gk || Position.cb || Position.sb => 1.0,
        Position.dm => 0.5,
        _ => 0.0,
      };

}

/// 練習と試合の消耗をまとめた1週間の結果。
class WeekOutcome {
  const WeekOutcome({
    required this.attributes,
    required this.condition,
    required this.trained,
    this.setPieces = const SetPieceSkills(),
    this.physique = const Physique(
        heightCm: Physique.baseHeight, weightKg: Physique.baseWeight),
    this.drilled,
    this.learned,
    this.redirected = false,
    this.weakFootAwakened = false,
    this.injury,
  });

  final Attributes attributes;
  final int condition;

  /// 練習で伸びた詳細能力。伸びなければ null。
  final Detail? trained;

  /// 居残り練習の後のセットプレー精度。
  final SetPieceSkills setPieces;

  /// 居残りで伸びた種類。伸びなければ null。
  final SetPiece? drilled;

  /// 逆足練習の後の身体データ。
  final Physique physique;

  /// その週に覚えた個人技。
  final Signature? learned;

  /// 逆足が形になったか。
  final bool weakFootAwakened;

  /// 狙った能力が土台に阻まれ、土台のほうが伸びたか。
  final bool redirected;

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
  /// 直近の評価点と、監督の信頼から出場の仕方を決める。
  ///
  /// 信頼が厚いと多少調子を落としても使われ、構想外だと数字が良くても
  /// ベンチに座る。評価点だけで決めると監督との関係が飾りになる。
  static Appearance decideAppearance(
    List<MatchResult> recent, {
    double bonus = 0,
  }) {
    final rated =
        recent.where((r) => r.rating != null).map((r) => r.rating!).toList();
    if (rated.isEmpty) return Appearance.start;

    final window = rated.length <= Formulas.formWindow
        ? rated
        : rated.sublist(rated.length - Formulas.formWindow);
    final average =
        window.reduce((a, b) => a + b) / window.length + bonus;

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
    Development development = const Development(),
    double allyBonus = 0,
    double moodBonus = 0,
    double extraRating = 0,
    bool international = false,
  }) {
    final count = switch (appearance) {
      Appearance.start => Formulas.scenariosPerStart,
      Appearance.sub => Formulas.scenariosPerSub,
      Appearance.benched || Appearance.injured => 0,
    };

    final pool = [...ScenarioPool.forPosition(player.position)]..shuffle(_random);
    final picked = pool.take(count).toList();

    // 逆足で対応することになる局面を先に決めておく。両利きなら起きない。
    final weakFootChance =
        player.physique.foot == Foot.both ? 0.0 : Formulas.weakFootMomentChance;

    // 味方と相手の得点を、時間まで含めて先に決めておく。
    final advantage = club.strength - opponent.strength + (home ? 6 : -2);
    final teammateGoals = _poissonish((1.25 + advantage / 40) *
        Formulas.teammateGoalShareFor(player.position.family));
    final conceded = _poissonish(1.25 - advantage / 40);

    return MatchInProgress(
      matchday: matchday,
      opponent: opponent,
      home: home,
      appearance: appearance,
      scenarios: picked,
      minutes: _minutesFor(count, appearance),
      player: player,
      club: club,
      development: development,
      teammateGoalMinutes: _goalMinutes(teammateGoals),
      concededMinutes: _goalMinutes(conceded),
      allyBonus: allyBonus,
      moodBonus: moodBonus,
      extraRating: extraRating,
      weakFootMoments: [
        for (var i = 0; i < count; i++) _random.nextDouble() < weakFootChance,
      ],
      international: international,
      random: _random,
    );
  }

  /// 得点の時間を散らす。1分と90分に固まらないようにする。
  List<int> _goalMinutes(int count) {
    final minutes = [for (var i = 0; i < count; i++) 3 + _random.nextInt(88)];
    minutes.sort();
    return minutes;
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
  /// 詳細能力まで分かっていればそれが伸びる。決定力で決めた選手は
  /// 決定力が伸びる。選び方が選手を形作るのがキャリアものの面白さ。
  ///
  /// ポテンシャルに達したら伸びない。ピークを過ぎると伸びにくくなり、
  /// さらに歳を取ると落ちる。特性で前後する。
  Attributes grow(
    Player player,
    double? rating, {
    List<ScenarioResolution> used = const [],
    int declineOffset = 0,
    bool plateau = false,
    double environment = 1.0,
  }) {
    if (rating == null) return player.attributes;

    final declineAge = Formulas.declineAge +
        player.traits.declineAgeOffset +
        player.personality.declineAgeOffset +
        declineOffset;
    if (player.age >= declineAge && _random.nextDouble() < 0.25) {
      return player.attributes.bumpDetail(_randomDetail(), -1);
    }

    if (rating < Formulas.growthRatingThreshold) return player.attributes;
    if (player.atPotential) return player.attributes;

    // 若いほど伸びる。特性のピーク年齢のぶんだけ、曲線を後ろにずらす。
    final ageFactor =
        Formulas.growthByAge(player.age - player.traits.peakAgeOffset);
    final margin = rating - Formulas.growthRatingThreshold;
    // 停滞期はここを大きく削る。伸び続ける選手は居ない。
    final base = (0.18 + margin * 0.22) *
        ageFactor *
        player.traits.growthFactor(player.age) *
        environment *
        (plateau ? Formulas.plateauGrowthFactor : 1.0);
    final step = player.age <= Formulas.rapidGrowthAge ? 2 : 1;

    // 伸ばす先を先に決める。ポジションの重みで割り戻すために、
    // どのカテゴリが伸びるのかが分かってから確率を出す。
    final focus =
        used.isNotEmpty && _random.nextDouble() < Formulas.growthFocusChance;
    Detail wanted;
    if (!focus) {
      wanted = _randomDetail();
    } else {
      final pick = used[_random.nextInt(used.length)];
      wanted = pick.detail ??
          pick.key.details[_random.nextInt(pick.key.details.length)];
    }

    final chance = base *
        Formulas.growthShareFactor(
            Attributes.weightShare(player.position, wanted.category));
    if (_random.nextDouble() >= chance) return player.attributes;

    // 土台の許す範囲まで。届かなければ土台のほうが伸びる。
    return player.attributes
        .bumpDetail(Dependencies.resolve(wanted, player.attributes), step);
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
    final chance = (baseChance +
            fatigue * Formulas.injuryConditionSlope +
            age * Formulas.injuryPerAgeYear) *
        player.traits.injuryFactor;

    if (_random.nextDouble() >= chance) return null;

    // 重い怪我ほど出にくくする。軽傷が大半で、たまに長期離脱。
    final roll = _random.nextDouble();
    final severity = roll < 0.6
        ? InjurySeverity.light
        : roll < 1 - Formulas.severeInjuryShare
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
      player.attributes.bump(kind.affects, -Formulas.severeInjuryAttributeLoss,
          random: _random),
      player.potential - Formulas.severeInjuryPotentialLoss,
    );
  }

  /// 試合後の1週間。試合の消耗と、練習または休養を反映する。
  ///
  /// 練習メニューは扱うカテゴリの数だけ伸びる枠を持つ。複合メニューは
  /// 1枠あたりの確率が下がる代わりに2か所に触れ、その分だけ疲れる。
  /// 居残りはその上に積む。専属スタッフと生活習慣は、どちらの効きも底上げする。
  WeekOutcome applyWeek(
    Player player, {
    TrainingMenu menu = TrainingMenu.rest,
    SetPiece? drill,
    StaffTeam staff = const StaffTeam(),
    Habits habits = const Habits(),
    Development development = const Development(),
    bool plateau = false,
    double environment = 1.0,
    required bool played,
  }) {
    final costFactor = player.traits.conditionCostFactor;
    var condition = player.condition -
        (played ? (Formulas.matchConditionCost * costFactor).round() : 0);
    var attributes = player.attributes;
    var setPieces = player.setPieces;
    var physique = player.physique;
    Detail? trained;
    SetPiece? drilled;
    Signature? learned;
    var redirected = false;
    var awakened = false;

    if (menu.isRest) {
      condition += menu.recovery + staff.recoveryBonus + habits.recoveryBonus;
    } else {
      condition -= (menu.conditionCost * costFactor).round();
      final canGrow = attributes.overallFor(player.position) < player.potential;
      // プロ意識・専属コーチ・生活習慣が、同じ練習の身になり方を変える。
      final base = Formulas.trainingGrowthChance *
          Formulas.growthByAge(player.age - player.traits.peakAgeOffset) *
          menu.growthFactor *
          player.personality.trainingFactor *
          staff.growthFactor *
          habits.growthFactor *
          environment;
      final step = player.age <= Formulas.rapidGrowthAge ? 2 : 1;
      final effective = plateau ? base * Formulas.plateauGrowthFactor : base;
      if (canGrow) {
        for (final key in menu.keys) {
          // ポジションの重みで割り戻す。同じ練習が、どのポジションでも
          // 同じくらい総合力を動かすようにする。
          final chance = effective *
              Formulas.growthShareFactor(
                  Attributes.weightShare(player.position, key));
          if (_random.nextDouble() >= chance) continue;
          final ds = key.details;
          final wanted = ds[_random.nextInt(ds.length)];
          final target = Dependencies.resolve(wanted, attributes);
          if (target != wanted) redirected = true;
          attributes = attributes.bumpDetail(target, step);
          trained ??= target;
        }
      }

      // 逆足はひたすら反復するしかない。伸びは遅く、4に届くと形になる。
      if (menu.weakFoot && physique.weakFoot < 5) {
        if (_random.nextDouble() <
            Formulas.weakFootGrowthChance *
                player.personality.trainingFactor *
                staff.growthFactor) {
          physique = physique.copyWith(weakFoot: physique.weakFoot + 1);
          awakened = physique.weakFoot >= 4;
        }
      }

      // 積み上げた能力が一定を超えると、その練習の中で技を覚えることがある。
      learned = _rollSignature(
        attributes: attributes,
        menu: menu,
        development: development,
      );
    }

    // 居残り。全体練習の後にもう一段。上に行くほど1本の重みが軽くなる。
    if (drill != null) {
      condition -= Formulas.drillConditionCost;
      final current = setPieces[drill];
      final chance = Formulas.drillGrowthChance *
          player.personality.trainingFactor *
          staff.growthFactor *
          (1 - current / 130);
      if (current < SetPieceSkills.max && _random.nextDouble() < chance) {
        setPieces = setPieces.bump(drill, 1);
        drilled = drill;
      }
    }

    final settled = condition.clamp(0, Formulas.conditionMax).toInt();
    // 身体を動かした週だけ、練習中の負傷を判定する。休養だけの週にリスクは無い。
    final worked = !menu.isRest || drill != null;
    final injury = !worked
        ? null
        : rollInjury(
            player.copyWith(condition: settled),
            baseChance: Formulas.injuryTrainingChance *
                menu.injuryFactor *
                staff.injuryFactor *
                habits.injuryFactor,
          );

    return WeekOutcome(
      attributes: attributes,
      condition: settled,
      trained: trained,
      setPieces: setPieces,
      physique: physique,
      drilled: drilled,
      learned: learned,
      redirected: redirected,
      weakFootAwakened: awakened,
      injury: injury,
    );
  }

  /// その週に個人技を覚えるか。
  ///
  /// 練習しているカテゴリの中で、必要な水準に達している技だけが候補になる。
  /// 能力値が上がった結果として身に付くので、狙って取りには行けない。
  Signature? _rollSignature({
    required Attributes attributes,
    required TrainingMenu menu,
    required Development development,
  }) {
    if (development.signatures.length >= Signature.maxOwned) return null;
    final candidates = [
      for (final s in Signature.values)
        if (menu.keys.contains(s.key) &&
            !development.signatures.contains(s) &&
            attributes.detail(s.detail) >= Signature.requirement)
          s,
    ];
    if (candidates.isEmpty) return null;
    if (_random.nextDouble() >= Formulas.signatureChance) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  Detail _randomDetail() => Detail.values[_random.nextInt(Detail.values.length)];

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
