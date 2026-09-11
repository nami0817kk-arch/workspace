import 'dart:math';

import '../models/attributes.dart';
import '../models/cup.dart';
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

/// 試合で起きたことの種類。
enum MatchEventKind {
  ownGoal('あなたのゴール'),
  ownAssist('あなたのアシスト'),
  teammateGoal('味方のゴール'),
  conceded('失点'),
  sentOffThem('相手に退場者'),
  sentOffUs('味方が退場');

  const MatchEventKind(this.label);

  final String label;

  bool get isOurs =>
      this != MatchEventKind.conceded && this != MatchEventKind.sentOffUs;
}

/// **試合を動かす展開。** 局面ではないが、残りの試合の条件を変える。
///
/// 試合の中でプレイヤーが触るのは 2〜6 の局面だけで、そのあいだ試合は
/// 何も起きていなかった。「11人対10人になった」「リードされた相手が
/// 前に出てきた」——**選ぶことはできないが、次の手の意味が変わる**もの。
enum MatchTurn {
  /// 相手に退場者。数的優位。
  numbersUp('相手に退場者'),

  /// 味方が退場。数的不利。
  numbersDown('味方が退場'),

  /// リードされた相手が前に出てくる。点は取りやすくなる。
  opponentOpen('相手が前がかり'),

  /// リードした相手が引いて固める。点が取りにくくなる。
  opponentShut('相手が守りを固めた');

  const MatchTurn(this.label);

  final String label;
}

/// 試合で起きたこと1つ。
class MatchEvent {
  const MatchEvent({required this.minute, required this.kind});

  final int minute;
  final MatchEventKind kind;
}

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

/// 成功率を作っている要素ひとつ。
///
/// 画面に出すためだけの飾りではない。[MatchInProgress.chanceFor] は
/// 地力とこれらの合計で出す。別々に書くと、片方を触ったときに
/// 表示と判定がずれる（このゲームで一番やってはいけないこと）。
class ChanceFactor {
  const ChanceFactor(this.label, this.value);

  /// 何が効いているのか。特性名・個人技名・相手の戦い方など。
  final String label;

  /// 成功率への増減。0.05 なら +5%。
  final double value;

  int get percent => (value * 100).round();

  /// 表示に値する大きさか。1%未満は並べても読めない。
  bool get notable => percent.abs() >= 1;
}

/// 試合1つぶんの進行状態。UI はこれを介して局面を1つずつ進める。
class MatchInProgress {
  MatchInProgress({
    required this.matchday,
    required this.opponent,
    required this.home,
    required this.appearance,
    required this.scenarios,
    this.reserves = const [],
    required this.minutes,
    required this.player,
    required this.club,
    this.development = const Development(),
    this.favoured = const [],
    this.fatigue = 0,
    List<int> teammateGoalMinutes = const [],
    double? expectedTeammateGoals,
    this.concededMinutes = const [],
    this.allyBonus = 0,
    this.moodBonus = 0,
    this.extraRating = 0,
    this.weakFootMoments = const [],
    this.sentOffThemMinute,
    this.sentOffUsMinute,
    this.international = false,
    this.cup,
    Random? random,
  }) : assert(scenarios.length == minutes.length),
       teammateGoalMinutes = [...teammateGoalMinutes],
       expectedTeammateGoals =
           expectedTeammateGoals ?? teammateGoalMinutes.length.toDouble(),
       _random = random ?? Random() {
    _adapt();
  }

  final int matchday;
  final Club opponent;
  final bool home;
  final Appearance appearance;

  /// 引いた局面。展開に合う控えがあれば、その場で差し替わる。
  final List<Scenario> scenarios;

  /// 展開が傾いたときに差し替える控えの局面。
  ///
  /// 終盤に2点を追っているのに「無難につないで作り直す」局面しか
  /// 来ないと、試合の中身と状況が噛み合わない。骨格は展開に依らない
  /// 局面で組み、終盤だけをここから入れ替える。
  final List<Scenario> reserves;

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

  /// 味方が決める得点の見込み（試合開始時の期待値）。
  ///
  /// アシストが決まるには「この後に味方が決める予定」が要る。その予定は
  /// 隠されているので、画面と自動進行には予定そのものではなく、
  /// 力関係と残り時間から出るこの見込みを使う（[assistConversionAt]）。
  final double expectedTeammateGoals;

  /// 累積疲労 0〜100。終盤の落ち込みに効く。
  ///
  /// これまで疲労はローテーションと怪我にしか効いていなかった。
  final int fatigue;

  /// 終盤の消耗。後半に入ってから、時間とともに効いてくる。
  ///
  /// スタミナが高ければほとんど落ちず、累積疲労が溜まっていれば深く落ちる。
  /// 判定にも画面にもこの1つを使う。
  double get lateFatigue {
    if (isFinished) return 0;
    final minute = currentMinute;
    if (minute <= Formulas.lateFatigueFrom) return 0;
    final progress =
        ((minute - Formulas.lateFatigueFrom) / (90 - Formulas.lateFatigueFrom))
            .clamp(0.0, 1.0);
    final stamina = player.effective(Detail.stamina);
    final drop =
        Formulas.lateFatigueBase -
        (stamina - Formulas.conditionBaseline) *
            Formulas.lateFatiguePerStamina +
        fatigue * Formulas.lateFatiguePerFatigue;
    return -drop.clamp(0.0, Formulas.lateFatigueMax) * progress;
  }

  /// 監督が重く見る能力。空なら何も求めていない（バランス型）。
  ///
  /// 試合で選んだことが監督に届くのは、ここを通ってだけ。
  final List<AttributeKey> favoured;

  /// 監督の求める形に沿った手・逆らった手の数。
  int followedTactic = 0;
  int againstTactic = 0;

  /// その試合の**ノリ** 0〜[Formulas.momentumMax]。
  ///
  /// 成功を重ねるほど上がり、失敗で 0 に戻る。効くのは成功率ではなく
  /// **決まる確率**（ゴール・アシスト）。成功率に乗せると安全な手が
  /// さらに強くなるだけで、また一本道になる。
  int momentum = 0;

  /// ノリが、決まる確率を何倍にするか。判定にも画面にも同じここから出す。
  double get momentumFactor => 1 + momentum * Formulas.momentumPerStep;

  /// 今この局面で、その手が決まる確率（ゴール）。
  double goalConversionNow() =>
      Formulas.goalConversion * momentumFactor * turnConversionFactor;

  /// 今の局面で構えている切り札。局面が変われば外れる。
  ///
  /// 個人技は身に付くと常に少しだけ効くだけの飾りだった。
  /// 1試合に1回、「この局面で出す」と決められるようにする。
  Signature? armed;

  /// この試合でもう切り札を使ったか。
  bool signatureSpent = false;

  /// 構えて外したか。力んだぶんが、その試合の残りに残る。
  bool signatureMissed = false;

  /// 今の局面で構えられる切り札。
  ///
  /// **その局面に出せる手が無ければ構えられない。** 覚えた技と、
  /// 目の前の局面が噛み合ったときだけ選択肢になる。
  List<Signature> get armable {
    if (isFinished || signatureSpent) return const [];
    return [
      for (final s in development.signatures)
        if (current.options.any((o) => o.detail == s.detail)) s,
    ];
  }

  /// その手に、構えた切り札が乗るか。
  bool signatureLands(ScenarioOption option) =>
      armed != null && !signatureSpent && option.detail == armed!.detail;

  /// 切り札を構える（null で外す）。乗らない技は構えられない。
  void arm(Signature? signature) {
    if (signature == null) {
      armed = null;
      return;
    }
    if (armable.contains(signature)) armed = signature;
  }

  /// 味方を活かす手を選んだ回数。相方との呼吸はここから伸びる。
  ///
  /// これまでは出場するだけで +2 で、プレイヤーの関与がゼロだった。
  int assistAttempts = 0;

  /// その手が監督の求める形か。画面にも判定にも同じものを使う。
  bool isFavoured(ScenarioOption option) =>
      favoured.isNotEmpty && favoured.contains(option.key);

  /// 相手が決める時間。
  ///
  /// 止めるための反則が通ると、ここから1つ消える。
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

  /// カップ戦なら、その大会。リーグ戦なら null。
  final CupKind? cup;

  final Random _random;

  final List<ScenarioResolution> resolutions = [];

  /// 受けた警告の時間。2枚目で退場になる。
  final List<int> yellowMinutes = [];

  /// この試合で、局面の成功率を動かした特性とその回数。
  ///
  /// 「クラッチ」と書いてあるだけでは、効いたのかどうか分からない。
  /// 手を選んだ瞬間に効いていた特性を数えて、シーズンの集計に回す。
  final Map<Trait, int> traitHits = {};

  /// 一発退場した時間。2枚目の警告なら、そちらの時間が入る。
  int? sentOffMinute;

  bool get sentOff => sentOffMinute != null;

  int get yellowCards => yellowMinutes.length;

  int _index = 0;

  /// 退場したらそこで終わり。残りの局面は来ない。
  bool get isFinished => sentOff || _index >= scenarios.length;
  int get currentIndex => _index;
  Scenario get current => scenarios[_index];
  int get currentMinute => minutes[_index];

  /// 今の局面を、そのときの展開に合ったものへ差し替える。
  ///
  /// 局面に入った時点で1度だけ動かす。表示のたびに引き直すと、
  /// 画面を開き直すだけで局面が変わってしまう。
  void _adapt() {
    if (isFinished || reserves.isEmpty) return;
    final want = tempoNow;
    if (want == ScenarioTempo.any || scenarios[_index].tempo == want) return;
    final used = scenarios.map((s) => s.id).toSet();
    for (final candidate in reserves) {
      if (candidate.tempo == want && !used.contains(candidate.id)) {
        scenarios[_index] = candidate;
        return;
      }
    }
  }

  /// 今の局面が、どういう展開のものか。
  ///
  /// 得点の時間は試合開始時に決まっているので、その局面の時間での
  /// スコアがそのまま使える。
  ScenarioTempo get tempoNow {
    if (isFinished) return ScenarioTempo.any;
    final minute = currentMinute;
    final gap = margin;
    if (gap < 0) {
      final from = gap <= -2
          ? Formulas.bigDeficitMinute
          : Formulas.situationalMinute;
      return minute >= from ? ScenarioTempo.chase : ScenarioTempo.any;
    }
    if (gap > 0 && minute >= Formulas.situationalMinute) {
      return ScenarioTempo.hold;
    }
    return ScenarioTempo.any;
  }

  /// 直前の手が失敗していたか。「負けず嫌い」「気分屋」の判定に使う。
  bool get afterFailure => resolutions.isNotEmpty && !resolutions.last.success;
  bool get afterSuccess => resolutions.isNotEmpty && resolutions.last.success;

  /// 自分が決めた得点の時間。
  final List<int> ownGoalMinutes = [];

  /// 自分のアシストの時間。
  final List<int> ownAssistMinutes = [];

  /// この後に味方が決める予定があるか。
  bool _hasTeammateGoalAfter(int minute) =>
      teammateGoalMinutes.any((m) => m > minute);

  /// その時間に通したアシストの手が、実際にアシストになる見込み。
  ///
  /// 「この後に味方が決める」確率 × 決まる確率。終盤ほど低く、弱いクラブほど
  /// 低い。予定そのものを見ると未来が漏れるので、期待値から出す。
  /// 画面の「アシスト N%」と自動進行の物差しはこれを使う。
  /// ノリ込みの、アシストが決まる確率。
  double assistConversionNow(int minute) =>
      assistConversionAt(minute) * momentumFactor * turnConversionFactor;

  double assistConversionAt(int minute) {
    final remaining = ((90 - minute) / 90).clamp(0.0, 1.0);
    final chance = 1 - exp(-expectedTeammateGoals * remaining);
    return Formulas.assistConversion * chance;
  }

  /// アシストが決まった。この後に入る予定だった味方の得点を今に引き寄せる。
  ///
  /// 以前は「抜け出した味方が決めた」と書いてあるのにスコアが 0-0 のままだった。
  /// 引き寄せるだけで足さないのは、足すと自分のクラブだけ点が増えるため。
  /// **流れの中の1本。** この後に入る予定だった味方の得点を、自分が決める。
  ///
  /// **足すのではなく置き換える**——足すと自分のクラブだけ点が増える
  /// （アシストのときに踏んだのと同じ穴）。取れなければ false。
  bool _takeTeammateGoal(int minute) {
    final index = teammateGoalMinutes.indexWhere((m) => m > minute);
    if (index < 0) return false;
    final when = teammateGoalMinutes.removeAt(index);
    ownGoalMinutes.add(when);
    ownGoalMinutes.sort();
    return true;
  }

  /// 局面と局面のあいだに、流れの中で1本決めるか。
  ///
  /// **局面でしか点が入らないと、1試合の最大得点が局面の数で頭打ちになる**
  /// （ふつうの試合は2局面）。実測で、中盤の選手は20年で1試合2点を一度も
  /// 取らず、守備の選手は通算0ゴールだった。
  /// ノリが乗っているほど起きる——**自分のしたことが返ってくる形**にする。
  bool _rollFlowGoal() {
    if (momentum <= 0) return false;
    final share = Formulas.flowGoalShareFor(player.position.family);
    if (share <= 0) return false;
    final chance =
        Formulas.flowGoalChance * share * momentumFactor * turnConversionFactor;
    if (_random.nextDouble() >= chance) return false;
    return _takeTeammateGoal(currentMinute);
  }

  void _claimTeammateGoal(int minute) {
    final index = teammateGoalMinutes.indexWhere((m) => m > minute);
    if (index < 0) return;
    teammateGoalMinutes[index] = minute;
    teammateGoalMinutes.sort();
  }

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
  ///
  /// 局面が展開に合わせて差し替わる時間帯（[tempoNow]）は、終盤より前でも
  /// 出す。「なぜ急に勝負を迫る局面が来たのか」が分からないと、
  /// 差し替えがただの気まぐれに見える。
  String? get situationLabel {
    if (isFinished) return null;
    final late = lateGame;
    if (!late && tempoNow == ScenarioTempo.any) return null;
    final when = late ? '終盤' : '残り30分';
    if (margin < 0) return '${-margin}点ビハインド・$when';
    if (margin == 0) return '同点・$when';
    return '$margin点リード・$when';
  }

  /// 試合で起きたことを、時間順に並べたもの。
  ///
  /// 終わったあとに「どんな試合だったか」を思い出せるようにする。
  /// 数字だけの結果画面は、38試合ぶん並べても記憶に残らない。
  List<MatchEvent> get timeline {
    final events = <MatchEvent>[
      // アシストで引き寄せた味方の得点は、アシストの行として1つにまとめる。
      for (final m in teammateGoalMinutes)
        if (!ownAssistMinutes.contains(m))
          MatchEvent(minute: m, kind: MatchEventKind.teammateGoal),
      for (final m in concededMinutes)
        MatchEvent(minute: m, kind: MatchEventKind.conceded),
      for (final m in ownGoalMinutes)
        MatchEvent(minute: m, kind: MatchEventKind.ownGoal),
      for (final m in ownAssistMinutes)
        MatchEvent(minute: m, kind: MatchEventKind.ownAssist),
      if (sentOffThemMinute != null)
        MatchEvent(
          minute: sentOffThemMinute!,
          kind: MatchEventKind.sentOffThem,
        ),
      if (sentOffUsMinute != null)
        MatchEvent(minute: sentOffUsMinute!, kind: MatchEventKind.sentOffUs),
    ]..sort((a, b) => a.minute.compareTo(b.minute));
    return events;
  }

  /// 相手の戦い方。
  ClubStyle get opponentStyle => ClubStyle.of(opponent);

  /// 今の局面が逆足で対応するものか。
  bool get weakFootMoment =>
      !isFinished && _index < weakFootMoments.length && weakFootMoments[_index];

  /// 退場者が出る時間。**試合開始時に決めて固定する。**
  ///
  /// 呼ぶたびに引き直すと、画面に出した成功率と判定がずれる
  /// （逆足の局面と同じ理屈）。null なら起きない。
  final int? sentOffThemMinute;
  final int? sentOffUsMinute;

  /// **いま効いている展開。** 局面ではないが、次の手の条件を変える。
  ///
  /// 退場は時間で決まり、相手の出方はスコアで決まる。どちらも
  /// **選べない**——自分の選択でないものが試合を動かしている、という手触り。
  List<MatchTurn> get turns {
    if (isFinished) return const [];
    final minute = currentMinute;
    final found = <MatchTurn>[];
    final them = sentOffThemMinute;
    final us = sentOffUsMinute;
    if (them != null && minute >= them) found.add(MatchTurn.numbersUp);
    if (us != null && minute >= us) found.add(MatchTurn.numbersDown);
    // リードされた相手は前に出る。リードした相手は引く。
    if (minute >= Formulas.situationalMinute) {
      if (margin > 0) found.add(MatchTurn.opponentShut);
      if (margin < 0) found.add(MatchTurn.opponentOpen);
    }
    return found;
  }

  /// 展開が、その手の成功率をどれだけ動かすか。
  double turnBonusFor(ScenarioOption option) {
    var total = 0.0;
    for (final turn in turns) {
      total += switch (turn) {
        MatchTurn.numbersUp => Formulas.numbersUpBonus,
        MatchTurn.numbersDown => -Formulas.numbersDownPenalty,
        // 相手の出方は、点に絡む手にだけ効く。無難な手は変わらない。
        MatchTurn.opponentOpen =>
          option.outcome == Outcome.play ? 0.0 : Formulas.opponentOpenBonus,
        MatchTurn.opponentShut =>
          option.outcome == Outcome.play ? 0.0 : -Formulas.opponentShutPenalty,
      };
    }
    return total;
  }

  /// 展開が、決まる確率に掛かる倍率。
  double get turnConversionFactor {
    var factor = 1.0;
    for (final turn in turns) {
      factor *= switch (turn) {
        MatchTurn.numbersUp => Formulas.numbersUpConversion,
        MatchTurn.numbersDown => Formulas.numbersDownConversion,
        _ => 1.0,
      };
    }
    return factor;
  }

  /// 流れの中で決めた本数。局面の外で入ったぶん。
  int flowGoals = 0;

  /// 流れの中の1本を、どう書くか。守備の選手はセットプレーの的になる。
  String get _flowGoalText => switch (player.position.family) {
    ScenarioFamily.forward => 'こぼれ球に詰めていた。流れの中から、押し込んだ。',
    ScenarioFamily.midfield => '二列目から遅れて入ってきた。流れの中から、叩き込んだ。',
    ScenarioFamily.defence => 'セットプレー。マークを外して、頭で合わせた。',
    ScenarioFamily.goalkeeper => '流れの中から決めた。',
  };

  /// 大一番か。格上との対戦と代表戦は、それだけで重い。
  bool get bigMatch => international || opponent.strength - club.strength >= 8;

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
    final total =
        Formulas.baseRating +
        resolutions.fold<double>(0, (sum, r) => sum + r.ratingDelta) *
            ratingScale +
        player.traits.ratingBonus +
        extraRating;
    return total.clamp(Formulas.minRating, Formulas.maxRating);
  }

  /// 局面ごとの評価点を、**1試合ぶんの重み**に割り戻す倍率。
  ///
  /// 重い試合は8局面、ふつうの試合は2局面。割り戻さないと、
  /// 重い試合に出ただけで評価点が跳ね、薄い試合に出ると下がる
  /// （＝出た試合の重さが、そのまま平均評価になってしまう）。
  /// 途中出場が先発より軽いことは、これまでどおり残す。
  double get ratingScale {
    if (scenarios.isEmpty) return 1;
    final reference = appearance == Appearance.sub
        ? Formulas.ratingScenarios * 2 / 3
        : Formulas.ratingScenarios.toDouble();
    return reference / scenarios.length;
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
    final total = factorsFor(option)
        .fold<double>(baseChanceFor(option), (sum, f) => sum + f.value);
    return total.clamp(0.05, 0.95);
  }

  /// その手を特性から見たときの文脈。判定と記録で同じものを使う。
  TraitContext traitContextFor(ScenarioOption option) => TraitContext(
    minute: currentMinute,
    home: home,
    outcome: option.outcome,
    afterFailure: afterFailure,
    afterSuccess: afterSuccess,
    key: option.key,
    detail: option.detail,
    scenarioId: current.id,
    international: international,
    bigMatch: bigMatch,
    margin: margin,
    weakFoot: weakFootMoment && _usesFoot(option),
    abroad: club.countryId != player.nationality.primary,
    substitute: appearance == Appearance.sub,
  );

  /// 能力と難度だけで決まる地力。ここに増減が乗る。
  double baseChanceFor(ScenarioOption option) =>
      successChance(attributeFor(option), option.difficulty);

  /// その手の成功率を動かしているもの。大きい順に並べて返す。
  ///
  /// 特性・個人技・型・相手の戦い方・相方・気持ち・逆足は、これまで
  /// 数字の中に溶けていて画面に出ていなかった。育てたものが試合の
  /// どこで効いているのかが見えないと、育成と試合が別のゲームに見える。
  List<ChanceFactor> factorsFor(ScenarioOption option) {
    if (isFinished) return const [];
    final factors = <ChanceFactor>[];

    // 生まれ持った特性。効いている特性だけを名前で出す。
    final context = traitContextFor(option);
    for (final trait in player.traits) {
      final value = trait.chanceBonus(context);
      if (value != 0) factors.add(ChanceFactor(trait.label, value));
    }

    // 試合を動かした展開。**選べないものが効いているときこそ、画面に出す。**
    for (final turn in turns) {
      final value = switch (turn) {
        MatchTurn.numbersUp => Formulas.numbersUpBonus,
        MatchTurn.numbersDown => -Formulas.numbersDownPenalty,
        MatchTurn.opponentOpen =>
          option.outcome == Outcome.play ? 0.0 : Formulas.opponentOpenBonus,
        MatchTurn.opponentShut =>
          option.outcome == Outcome.play ? 0.0 : -Formulas.opponentShutPenalty,
      };
      if (value != 0) factors.add(ChanceFactor(turn.label, value));
    }

    factors.add(ChanceFactor('コンディション', conditionModifier(player.condition)));

    // 終盤の消耗。スタミナで薄まり、累積疲労で深くなる。
    final late = lateFatigue;
    if (late != 0) factors.add(ChanceFactor('終盤の消耗', late));

    // 相手の格。上のリーグほど同じ手が通らなくなる。
    factors.add(
      ChanceFactor(
        opponent.strength >= club.strength ? '格上の相手' : '格下の相手',
        (Formulas.opponentBaseline - opponent.strength) *
            Formulas.opponentChanceSlope,
      ),
    );

    // 自信は小さく効かせる。性格で試合が決まると能力を伸ばす意味が薄れる。
    factors.add(ChanceFactor('自信', player.personality.chanceModifier));

    // 積み上げてきたもの。型・個人技・相手への慣れ。
    if (development.identity != null) {
      factors.add(
        ChanceFactor(
          development.identityLabel,
          development.identityBonusFor(option.key),
        ),
      );
    }
    for (final entry
        in development.signatureFactors(option.key, option.detail).entries) {
      factors.add(ChanceFactor(entry.key.label, entry.value));
    }
    // 構えた切り札。判定にも画面にも、同じここから出る。
    if (signatureLands(option)) {
      factors.add(
        ChanceFactor('${armed!.label}（切り札）', Formulas.signatureArmedBonus),
      );
    }
    // 外したぶんの力み。その試合の残り全部に効く。
    if (signatureMissed) {
      factors.add(const ChanceFactor('力んだ', -Formulas.signatureMissPenalty));
    }
    if (opponentStyle.hardFor == option.key) {
      factors.add(
        ChanceFactor(
          opponentStyle.label,
          -Formulas.styleMismatch +
              development.adaptationFor(
                opponentStyle,
                factor: player.traits.adaptationFactor,
              ),
        ),
      );
    }

    // 大一番の重圧。経験と自信で薄まり、若く自信の無い選手ほど呑まれる。
    if (bigMatch) {
      factors.add(
        ChanceFactor(
          '大一番',
          -Formulas.bigMatchPressure +
              development.composure +
              (player.personality.confidence - 10) * 0.004,
        ),
      );
    }

    // 相方との呼吸。パスを受ける側が動いてくれるかどうか。
    if (option.outcome == Outcome.assist && allyBonus != 0) {
      factors.add(ChanceFactor('相方との呼吸', allyBonus));
    }

    factors.add(ChanceFactor('気持ち・波', moodBonus));

    // 逆足。利き足でないほうで対応する局面は、精度がそのまま出る。
    if (weakFootMoment && _usesFoot(option)) {
      factors.add(ChanceFactor('逆足', -(5 - player.physique.weakFoot) * 0.03));
    }

    // 逆サイドの選手は、内へ切り込んで利き足で打てる。
    if (player.isInverted && option.key == AttributeKey.shooting) {
      factors.add(const ChanceFactor('内へ切り込む', Formulas.invertedShootingBonus));
    }

    factors.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    return factors;
  }

  /// どの手にも同じだけ効いているもの。相手の格・コンディション・気持ちなど。
  ///
  /// 手を選ぶときの材料にはならないので、選択肢の側には出さない。
  /// 「今日はこういう日だ」として1度だけ見せる。
  List<ChanceFactor> get sharedFactors {
    if (isFinished) return const [];
    final options = current.options;
    final byOption = [for (final o in options) _factorMap(o)];
    final result = <ChanceFactor>[];
    for (final factor in factorsFor(options.first)) {
      if (byOption.every((m) => m[factor.label] == factor.value)) {
        result.add(factor);
      }
    }
    return result;
  }

  /// その手にだけ効いているもの。手を選ぶときに見るのはこちら。
  List<ChanceFactor> distinctFactorsFor(ScenarioOption option) {
    if (isFinished) return const [];
    final shared = sharedFactors.map((f) => f.label).toSet();
    return [
      for (final f in factorsFor(option))
        if (!shared.contains(f.label)) f,
    ];
  }

  Map<String, double> _factorMap(ScenarioOption option) => {
    for (final f in factorsFor(option)) f.label: f.value,
  };

  /// 足で扱う手か。ヘディングと守備の局面に逆足は関係しない。
  static bool _usesFoot(ScenarioOption option) =>
      option.detail != Detail.heading &&
      (option.key == AttributeKey.shooting ||
          option.key == AttributeKey.passing ||
          option.key == AttributeKey.dribbling);

  /// 決めきれなかったときの文。
  static const String missedGoal = 'シュートは枠を捉えたが、GKが弾いた。';
  static const String missedAssist = '良いボールが入ったが、味方が決めきれなかった。';

  /// その手がカードを招く確率。画面にも出すので、判定と同じ式から出す。
  ///
  /// 気性が荒いほど、際どい場面で足が出る。
  double cardChanceFor(ScenarioOption option) {
    if (option.foul <= 0) return 0;
    if (option.isTacticalFoul) return 1;
    final temper = (player.personality.temper - 10) * Formulas.cardPerTemper;
    return (option.foul *
            (Formulas.cardChanceBase + temper) *
            player.traits.cardFactor)
        .clamp(0.0, 0.95);
  }

  /// カードを1枚受ける。2枚目なら退場。
  void _book(int minute) {
    yellowMinutes.add(minute);
    if (yellowMinutes.length >= 2) sentOffMinute = minute;
  }

  /// 選んだ手を解決して次の局面へ進める。
  ///
  /// 手そのものの成否と、それが得点になるかは別に扱う。
  /// 良い判断でも点にならない試合があるほうが、決まった1点が重くなる。
  ScenarioResolution choose(ScenarioOption option) {
    final chance = chanceFor(option);
    final success = _random.nextDouble() < chance;

    // 監督は「何を選んだか」を見ている。
    if (favoured.isNotEmpty) {
      if (favoured.contains(option.key)) {
        followedTactic++;
      } else {
        againstTactic++;
      }
    }
    // 味方を活かす手を選んだこと自体が、相方との呼吸を育てる。
    if (option.outcome == Outcome.assist) assistAttempts++;

    final context = traitContextFor(option);
    for (final trait in player.traits) {
      if (trait.chanceBonus(context) != 0) {
        traitHits[trait] = (traitHits[trait] ?? 0) + 1;
      }
    }

    var delta = success ? Formulas.ratingPerSuccess : Formulas.ratingPerFailure;
    var outcome = option.outcome;
    var text = success ? option.successText : option.failureText;

    if (success && outcome != Outcome.play) {
      // 決定機を作った。決まらなくても、無難な手とは違う。
      delta += Formulas.ratingPerChance;
      final rolled =
          _random.nextDouble() <
          (outcome == Outcome.goal
              ? goalConversionNow()
              : Formulas.assistConversion *
                    momentumFactor *
                    turnConversionFactor);
      // アシストは、この後に味方が決める予定があるときだけ決まる。
      // 決まった瞬間にその得点を今に引き寄せてスコアに乗せる。
      // 予定が無いのに点を足すと、自分のクラブだけが強くなる。
      final converts =
          rolled &&
          (outcome != Outcome.assist || _hasTeammateGoalAfter(currentMinute));
      if (converts) {
        if (outcome == Outcome.assist) {
          ownAssistMinutes.add(currentMinute);
          _claimTeammateGoal(currentMinute);
        }
        if (outcome == Outcome.goal) {
          // 追いついた・突き放した1点は重く見る。
          final before = margin;
          ownGoalMinutes.add(currentMinute);
          final decisive = lateGame && before <= 0;
          delta +=
              Formulas.ratingPerGoal *
              (decisive ? Formulas.decisiveGoalFactor : 1.0);
        } else {
          delta += Formulas.ratingPerAssist;
        }
      } else {
        text = outcome == Outcome.goal ? missedGoal : missedAssist;
        outcome = Outcome.play;
      }
    }

    // 止めた。これから入るはずだった失点が1つ消える。
    if (success && option.preventsGoal) {
      final index = concededMinutes.indexWhere((m) => m > currentMinute);
      if (index >= 0) {
        concededMinutes.removeAt(index);
        delta += Formulas.ratingPerGoalPrevented;
      }
    }

    // 審判。止めるための反則は選んだ時点で、荒い手は失敗したときに。
    final minute = currentMinute;
    var booked = false;
    if (option.isTacticalFoul) {
      booked = true;
    } else if (!success && option.foul > 0) {
      booked = _random.nextDouble() < cardChanceFor(option);
    }
    if (booked) {
      delta += Formulas.ratingPerYellow;
      _book(minute);
      if (sentOff) delta += Formulas.ratingPerRedCard;
      text = sentOff ? '$text 2枚目の警告。退場を命じられた。' : '$text 審判が笛を吹き、警告を受けた。';
    }

    // ノリ。成功を重ねるほど決まるようになり、失敗で消える。
    // 難しい手を通したほうが乗る（無難な手を積むだけでは上がりきらない）。
    if (success) {
      momentum =
          (momentum +
                  (option.outcome == Outcome.play
                      ? 1
                      : Formulas.momentumFromChance))
              .clamp(0, Formulas.momentumMax);
    } else {
      momentum = 0;
    }

    // 構えた切り札は、乗った手を選んだ時点で使い切る。
    // 外したら力みが残る（構えるだけならただ得、では判断にならない）。
    if (signatureLands(option)) {
      signatureSpent = true;
      if (success) {
        text = '$text ${armed!.label}が出た。';
      } else {
        signatureMissed = true;
        text = '$text ${armed!.label}を狙って、力んだ。';
      }
    }
    armed = null;

    final resolution = ScenarioResolution(
      success: success,
      text: text,
      outcome: outcome,
      ratingDelta: delta,
      key: option.key,
      detail: option.detail,
    );
    resolutions.add(resolution);

    // **局面のあとも試合は続いている。** ノリが乗っていれば、
    // 次の局面までのあいだに流れの中から1本決めることがある。
    if (_rollFlowGoal()) {
      flowGoals++;
      resolutions.add(
        ScenarioResolution(
          success: true,
          text: _flowGoalText,
          outcome: Outcome.goal,
          ratingDelta: Formulas.ratingPerGoal,
          key: AttributeKey.shooting,
        ),
      );
    }

    _index++;
    _adapt();
    return resolution;
  }

  /// 期待される評価点の増減。自動で選ぶときの物差し。
  ///
  /// 決まる確率まで含めて見る。含めないと、自動進行が得点の手を
  /// 実際の価値より高く買ってしまう。
  double expectedDelta(ScenarioOption option) {
    final p = chanceFor(option);
    var gain = Formulas.ratingPerSuccess;
    if (option.outcome != Outcome.play) gain += Formulas.ratingPerChance;
    // 自動進行にもノリを見せる。見ないと、自動で進めるだけでは
    // 「刻んでから決めにいく」が一度も起きない（切り札と同じ理屈）。
    if (option.outcome == Outcome.goal) {
      gain += Formulas.ratingPerGoal * goalConversionNow();
    }
    if (option.outcome == Outcome.assist) {
      gain += Formulas.ratingPerAssist * assistConversionNow(currentMinute);
    }
    // カードのぶんを引く。ここを入れないと、自動進行が「止めるための反則」を
    // 代償なしの安い手として選び続ける。
    final card = option.isTacticalFoul
        ? Formulas.ratingPerYellow
        : (1 - p) * cardChanceFor(option) * Formulas.ratingPerYellow;
    // 止めたぶんも数える。片方だけ入れると、ただ損な手に見える。
    final prevented = option.preventsGoal
        ? p * Formulas.ratingPerGoalPrevented
        : 0.0;
    return p * gain + (1 - p) * Formulas.ratingPerFailure + card + prevented;
  }

  /// スタイルに沿って手を1つ選ぶ。
  ///
  /// 「安全」は成功率、「バランス」は期待値、「勝負」は得点に繋がる手の中で
  /// 期待値が最も高いもの。人が選ぶときの癖を3つに絞った。
  ScenarioOption pickFor(SimStyle style) {
    final options = current.options;
    ScenarioOption best(
      Iterable<ScenarioOption> from,
      double Function(ScenarioOption) score,
    ) => from.reduce((a, b) => score(a) >= score(b) ? a : b);

    // 監督の求める形は、評価点には乗らないが信頼に乗る。
    // 見ないと自動進行が監督を無視し続け、出場機会をじわじわ失う。
    // 明らかに良い手を覆さない重さで、迷ったときだけ効かせる。
    double safeScore(ScenarioOption o) =>
        chanceFor(o) + (isFavoured(o) ? Formulas.tacticPickBonus : 0);
    double valueScore(ScenarioOption o) =>
        expectedDelta(o) + (isFavoured(o) ? Formulas.tacticPickBonus : 0);

    switch (style) {
      case SimStyle.safe:
        return best(options, safeScore);
      case SimStyle.balanced:
        return best(options, valueScore);
      case SimStyle.aggressive:
        final scoring = options.where((o) => o.outcome != Outcome.play);
        return best(scoring.isEmpty ? options : scoring, valueScore);
    }
  }

  /// 自動で進めるときに、切り札を構えるか決める。
  ///
  /// **選ぶはずの手に乗るなら構える。** 見ないと、自動で進めるだけで
  /// 切り札が一度も使われず、個人技が飾りに戻る（監督の求める形と同じ理屈）。
  void autoArm(SimStyle style) {
    if (signatureSpent || armed != null || isFinished) return;
    final pick = pickFor(style);
    for (final signature in armable) {
      if (pick.detail == signature.detail) {
        arm(signature);
        return;
      }
    }
  }

  /// 残りの局面を自動で解決する。
  void autoPlay(SimStyle style) {
    while (!isFinished) {
      autoArm(style);
      choose(pickFor(style));
    }
  }

  /// 能力値と難易度から成功率を出す（特性・コンディション抜きの素の値）。
  ///
  /// 能力値が難易度ちょうどでも五分にはしない。難しい手を選ぶことに
  /// リスクを残さないと、常に一番おいしい選択肢を押すだけのゲームになる。
  static double successChance(int attribute, int difficulty) {
    final chance =
        0.40 + (attribute - difficulty) * Formulas.attributeChanceSlope;
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
    // セットプレーの名手は、少し早くキッカーを任される。
    final threshold =
        SetPieceSkills.takerThreshold + player.traits.deadBallThresholdOffset;
    if (player.setPieces[player.setPieces.best] < threshold) return (0, 0);
    final chance = switch (appearance) {
      Appearance.start => Formulas.deadBallChanceStart,
      Appearance.sub => Formulas.deadBallChanceSub,
      Appearance.benched || Appearance.injured || Appearance.suspended => 0.0,
    };
    if (_random.nextDouble() >= chance) return (0, 0);

    final piece = player.setPieces.best;
    final skill = player.setPieces[piece];
    // セットプレーの時間。試合の中のどこかで起きたことにする。
    final minute = 15 + _random.nextInt(70);
    switch (piece) {
      case SetPiece.freeKick:
        final hit = _random.nextDouble() < (skill - 40) / 220;
        deadBallText = hit ? '直接FKを沈めた' : '直接FKは壁に当たった';
        if (hit) ownGoalMinutes.add(minute);
        return (hit ? 1 : 0, 0);
      case SetPiece.penalty:
        final hit =
            _random.nextDouble() < (0.55 + skill / 260).clamp(0.5, 0.95);
        deadBallText = hit ? 'PKを決めた' : 'PKを止められた';
        if (hit) ownGoalMinutes.add(minute);
        return (hit ? 1 : 0, 0);
      case SetPiece.corner:
        final hit = _random.nextDouble() < (skill - 30) / 200;
        deadBallText = hit ? 'CKから味方の頭に合わせた' : 'CKは跳ね返された';
        if (hit) ownAssistMinutes.add(minute);
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
    // 統率者は無失点のときだけ上乗せされる。失点した試合は同じ。
    final defence = defensive == 0
        ? 0.0
        : defensive *
              ((Formulas.cleanSheetBase - max(0, concededGoals)) *
                      Formulas.cleanSheetSlope)
                  .clamp(Formulas.cleanSheetMin, Formulas.cleanSheetMax) *
              (concededGoals == 0 ? player.traits.cleanSheetFactor : 1.0);

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
      rating:
          appearance == Appearance.benched ||
              appearance == Appearance.injured ||
              appearance == Appearance.suspended
          ? null
          : (rating +
                    defence +
                    extraGoals * Formulas.ratingPerGoal +
                    extraAssists * Formulas.ratingPerAssist)
                .clamp(Formulas.minRating, Formulas.maxRating),
      goals: myGoals,
      assists: assists + extraAssists,
      yellowCards: yellowCards,
      sentOff: sentOff,
      goalMinutes: [...ownGoalMinutes]..sort(),
      assistMinutes: [...ownAssistMinutes]..sort(),
      international: international,
      cup: cup,
      followedTactic: followedTactic,
      againstTactic: againstTactic,
      assistAttempts: assistAttempts,
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
      heightCm: Physique.baseHeight,
      weightKg: Physique.baseWeight,
    ),
    this.drilled,
    this.learned,
    this.redirected = false,
    this.weakFootAwakened = false,
    this.injury,
    this.outcome,
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

  /// その週の手応え。休養の週は null。
  final TrainingOutcome? outcome;

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
  ///
  /// 信頼が厚いと多少調子を落としても使われ、構想外だと数字が良くても
  /// ベンチに座る。評価点だけで決めると監督との関係が飾りになる。
  ///
  /// **外れた試合には評価点が付かない。** そのため、外れている間は窓の中身が
  /// 変わらず、一度ベンチに落ちた選手が永久に出られなかった。外れ続けるほど
  /// 評価を甘く見て、[Formulas.benchPatience] 試合外れたら必ず一度は
  /// ベンチに入れる。戻り道が無いと、そこでキャリアが終わってしまう。
  /// 直近で試合を動かしたぶんの下駄。
  ///
  /// **点を取る選手は干されない。** 評価点だけで決めていたので、
  /// 「6.8だが決めている」選手と「7.0だが何もしていない」選手を
  /// 区別できていなかった。平均は変動を嫌うので、そのままだと
  /// 安全な手が常に正しくなる。
  static double decisiveBonus(List<MatchResult> recent, Position position) {
    final window = recent.length <= Formulas.formWindow
        ? recent
        : recent.sublist(recent.length - Formulas.formWindow);
    final acts = window.fold<int>(0, (a, r) => a + r.decisiveFor(position));
    return min(acts * Formulas.decisivePerAct, Formulas.decisiveBonusMax);
  }

  static Appearance decideAppearance(
    List<MatchResult> recent, {
    double bonus = 0,
  }) {
    final rated = recent
        .where((r) => r.rating != null)
        .map((r) => r.rating!)
        .toList();
    if (rated.isEmpty) return Appearance.start;

    final idle = idleRun(recent);
    final forgiveness = min(
      idle * Formulas.benchRecoveryPerMatch,
      Formulas.benchRecoveryMax,
    );
    final average = formAverage(rated) + bonus + forgiveness;

    if (average >= Formulas.benchThreshold) return Appearance.start;
    if (average >= Formulas.squadThreshold || idle >= Formulas.benchPatience) {
      return Appearance.sub;
    }
    return Appearance.benched;
  }

  /// 直近の出来。最新 [Formulas.formWindow] 試合の平均。
  ///
  /// 試合数が足りないぶんは基準点（[Formulas.baseRating]）で埋める。
  /// 埋めないと、デビュー戦の 4.9 だけで翌節ベンチ外になっていた。
  /// 1試合の出来で判断されるのは、キャリアの始まりとして厳しすぎる。
  /// 出場の見通し（[SelectionOutlook]）も同じ式を使う。
  static double formAverage(List<double> rated) {
    if (rated.isEmpty) return Formulas.baseRating;
    final window = rated.length <= Formulas.formWindow
        ? rated
        : rated.sublist(rated.length - Formulas.formWindow);
    final padded = Formulas.formWindow - window.length;
    return (window.reduce((a, b) => a + b) + padded * Formulas.baseRating) /
        Formulas.formWindow;
  }

  /// 最後にピッチに立ってから、何試合続けて外れているか。
  ///
  /// 怪我での離脱も同じに数える。長く離れた選手が、戻った初戦から
  /// 先発に収まるほうが不自然なので、まずベンチから戻す。
  static int idleRun(List<MatchResult> recent) {
    var count = 0;
    for (final result in recent.reversed) {
      if (result.rating != null) break;
      count++;
    }
    return count;
  }

  /// 疲れているときに、監督が休ませるかどうか。
  ///
  /// 好調なら毎試合フル出場、では連戦の重みが出ない。ここがあると
  /// 「途中出場から入る試合」が生まれ、コンディションの管理に意味が出る。
  bool rotates({required int condition, required int fatigue}) {
    final chance =
        Formulas.rotationBase +
        max(0, Formulas.conditionBaseline - condition) *
            Formulas.rotationPerCondition +
        fatigue * Formulas.rotationPerFatigue;
    return _random.nextDouble() < chance.clamp(0.0, Formulas.rotationMax);
  }

  /// その試合で提示する局面の数。
  ///
  /// **重い試合だけを厚くする。** 全部を等しく3局面にすると、1試合が
  /// 「3回タップして終わり」の薄さに固定される。
  static int scenarioCount(Appearance appearance, {required bool big}) =>
      switch (appearance) {
        Appearance.start =>
          big ? Formulas.scenariosPerBigStart : Formulas.scenariosPerStart,
        Appearance.sub =>
          big ? Formulas.scenariosPerBigSub : Formulas.scenariosPerSub,
        Appearance.benched || Appearance.injured || Appearance.suspended => 0,
      };

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
    CupKind? cup,
    List<AttributeKey> favoured = const [],
    int fatigue = 0,
    List<Scenario>? forcedScenarios,
    bool big = false,
  }) {
    final count = scenarioCount(appearance, big: big);

    // 試合の骨格は展開に依らない局面から引き、終盤に効く局面は控えに回す。
    final family = player.position.family;
    final pool = [...ScenarioPool.neutralFor(family)]..shuffle(_random);
    // 管理画面（開発用）から局面を指定して入ることがある。
    // 管理画面（開発用）から局面を指定して入ることがある。
    // **渡された数が足りなければ繰り返して埋める**——局面の数は試合の重さで
    // 2〜6 に変わるので、呼ぶ側が何枚要るかを知りようがない
    // （3枚決め打ちで渡していて、重い試合に当たると assert で落ちていた）。
    final picked = forcedScenarios != null && forcedScenarios.isNotEmpty
        ? [
            for (var i = 0; i < count; i++)
              forcedScenarios[i % forcedScenarios.length],
          ]
        : pool.take(count).toList();
    final reserves = count == 0
        ? const <Scenario>[]
        : ([
            ...ScenarioPool.tempoFor(family, ScenarioTempo.chase),
            ...ScenarioPool.tempoFor(family, ScenarioTempo.hold),
          ]..shuffle(_random));

    // 逆足で対応することになる局面を先に決めておく。両利きなら起きない。
    // 立つ側と利き足の噛み合わせで頻度が変わる。
    final weakFootChance = player.physique.foot == Foot.both
        ? 0.0
        : switch (player.side) {
            Side.center => Formulas.weakFootMomentChance,
            _ =>
              player.side.matches(player.physique.foot)
                  ? Formulas.weakFootMomentOnSide
                  : Formulas.weakFootMomentInverted,
          };

    // 味方と相手の得点を、時間まで含めて先に決めておく。
    final advantage = club.strength - opponent.strength + (home ? 6 : -2);
    final teammateGoals = _poissonish(
      (1.25 + advantage / 40) *
          Formulas.teammateGoalShareFor(player.position.family),
    );
    final conceded = _poissonish(1.25 - advantage / 40);

    return MatchInProgress(
      matchday: matchday,
      opponent: opponent,
      home: home,
      appearance: appearance,
      scenarios: picked,
      reserves: reserves,
      minutes: _minutesFor(count, appearance),
      player: player,
      club: club,
      development: development,
      favoured: favoured,
      fatigue: fatigue,
      teammateGoalMinutes: _goalMinutes(teammateGoals),
      expectedTeammateGoals:
          (1.25 + advantage / 40) *
          Formulas.teammateGoalShareFor(player.position.family),
      concededMinutes: _goalMinutes(conceded),
      allyBonus: allyBonus,
      moodBonus: moodBonus,
      extraRating: extraRating,
      weakFootMoments: [
        for (var i = 0; i < count; i++) _random.nextDouble() < weakFootChance,
      ],
      // 退場の時間は試合開始時に決めておく。呼ぶたびに引き直すと、
      // 画面に出した成功率と判定がずれる（逆足の局面と同じ理屈）。
      sentOffThemMinute: _random.nextDouble() < Formulas.redCardThemChance
          ? 20 + _random.nextInt(60)
          : null,
      sentOffUsMinute: _random.nextDouble() < Formulas.redCardUsChance
          ? 20 + _random.nextInt(60)
          : null,
      international: international,
      cup: cup,
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
    List<Detail> focus = const [],
    int declineOffset = 0,
    bool plateau = false,
    double environment = 1.0,
    Development development = const Development(),
    void Function(Detail detail)? aimed,
    void Function(AttributeKey key, int step)? toPoints,
  }) {
    if (rating == null) return player.attributes;

    final declineAge =
        Formulas.declineAge +
        player.traits.declineAgeOffset +
        player.personality.declineAgeOffset +
        declineOffset;
    if (player.age >= declineAge && _random.nextDouble() < 0.25) {
      return player.attributes.bumpDetail(_randomDetail(), -1);
    }

    if (rating < Formulas.growthRatingThreshold) return player.attributes;
    // ポテンシャルに達したら止まる。超越の1項目だけは、上限まで伸び続ける。
    final transcending = player.atPotential && player.canTranscend;
    if (player.atPotential && !transcending) return player.attributes;

    // 若いほど伸びる。特性のピーク年齢のぶんだけ、曲線を後ろにずらす。
    final ageFactor = Formulas.growthByAge(
      player.age - player.traits.peakAgeOffset,
    );
    final margin = rating - Formulas.growthRatingThreshold;
    // 停滞期はここを大きく削る。伸び続ける選手は居ない。
    final base =
        (0.18 + margin * 0.22) *
        ageFactor *
        player.traits.growthFactor(player.age) *
        // 伸びしろのある選手は速く伸びる。近づくほど遅くなる。
        Formulas.potentialDrive(player.overall, player.potential) *
        environment *
        (plateau ? Formulas.plateauGrowthFactor : 1.0);
    final step = Formulas.growthStep(
      player.age,
      player.overall,
      player.potential,
    );

    // 伸ばす先を先に決める。ポジションの重みで割り戻すために、
    // どのカテゴリが伸びるのかが分かってから確率を出す。
    final fromPlay =
        used.isNotEmpty && _random.nextDouble() < Formulas.growthFocusChance;
    Detail wanted;
    if (transcending) {
      wanted = player.transcendDetail!;
    } else if (fromPlay) {
      final pick = used[_random.nextInt(used.length)];
      wanted =
          pick.detail ??
          pick.key.details[_random.nextInt(pick.key.details.length)];
    } else if (focus.isNotEmpty) {
      // 無作為だったぶんは、選んだ方向に乗せる。
      // 伸びる量は変わらず、どこに乗るかだけが変わる。
      wanted = focus[_random.nextInt(focus.length)];
    } else {
      wanted = _randomDetail();
    }

    final chance =
        base *
        Formulas.growthShareFactor(
          Attributes.weightShare(player.position, wanted.category),
        );
    if (_random.nextDouble() >= chance) return player.attributes;

    // 自分で振るなら、伸びるはずだったぶんを経験点にして持ち越す。
    // どこに振るかはプレイヤーが決めるので、ここでは土台を見ない。
    if (toPoints != null) {
      toPoints(wanted.category, step);
      return player.attributes;
    }
    // 土台の許す範囲まで。届かなければ土台のほうが伸びる。
    // **積んだ項目ほど、土台を先行できる**（尖った選手はここで作られる）。
    aimed?.call(wanted);
    final target = Dependencies.resolve(
      wanted,
      player.attributes,
      ceilingOf: player.ceilingFor,
      dedicationOf: development.dedicationOf,
    );
    return player.attributes.bumpDetail(
      target,
      step,
      max: player.ceilingFor(target),
    );
  }

  /// 負傷するかどうかを判定する。
  ///
  /// 疲れているほど、歳を取っているほど起きやすい。ここが練習と休養の
  /// 選択に重みを与えている。休養を「伸びないから無駄」にしないための仕掛け。
  /// その週に怪我をする確率。振らずに値だけ出す。
  ///
  /// 画面（管理画面の「効き」）と判定が同じ式を読むために切り出してある。
  /// 別に書くと、数字を触ったときに画面が嘘をつく。
  static double injuryChance(Player player, {required double baseChance}) {
    final worn = (Formulas.conditionBaseline - player.condition)
        .clamp(0, Formulas.conditionMax)
        .toDouble();
    final age = (player.age - Formulas.injuryAgeFrom).clamp(0, 20).toDouble();
    return (baseChance +
            worn * Formulas.injuryConditionSlope +
            age * Formulas.injuryPerAgeYear) *
        player.traits.injuryFactor;
  }

  /// 溜まった疲労で、重傷の割合がどこまで上がるか。
  ///
  /// 数だけ増えて軽傷ばかりなら、無理を通すのはまだ得な賭けになる。
  /// 溜まった疲労と、身体の消耗で、重傷の割合がどこまで上がるか。
  ///
  /// 追い込み続けた身体は、同じ怪我でも重いほうを引く。
  static double severeShareFor(
    int fatigue, {
    double strain = Formulas.strainNeutral,
  }) =>
      ((Formulas.severeInjuryShare + fatigue * Formulas.severePerFatigue) *
              Formulas.severeFactorForStrain(strain))
          .clamp(0.0, Formulas.severeShareMax);

  Injury? rollInjury(
    Player player, {
    required double baseChance,
    int fatigue = 0,
    double strain = Formulas.strainNeutral,
  }) {
    final chance = injuryChance(player, baseChance: baseChance);

    if (_random.nextDouble() >= chance) return null;

    // 重い怪我ほど出にくくする。軽傷が大半で、たまに長期離脱。
    // 疲れ切った身体ほど、重いほうを引く。
    final severeShare = severeShareFor(fatigue, strain: strain);
    final roll = _random.nextDouble();
    final severity = roll < 0.6 * (1 - severeShare)
        ? InjurySeverity.light
        : roll < 1 - severeShare
        ? InjurySeverity.moderate
        : InjurySeverity.severe;
    final kinds = InjuryKind.all.where((k) => k.severity == severity).toList();
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
    final kind = InjuryKind.all.firstWhere(
      (k) => k.name == injury.name,
      orElse: () => InjuryKind.all.last,
    );
    return (
      player.attributes.bump(
        kind.affects,
        -Formulas.severeInjuryAttributeLoss,
        random: _random,
      ),
      player.potential - Formulas.severeInjuryPotentialLoss,
    );
  }

  /// 試合ぶんの消耗を引いたあとのコンディション。
  ///
  /// 自動で休ませるかどうかは、練習に入る時点の値で決める。
  /// 判定と別に計算すると、しきい値と実際の挙動がずれる。
  static int conditionAfterMatch(Player player, {required bool played}) =>
      player.condition -
      (played
          ? (Formulas.matchConditionCost * player.traits.conditionCostFactor)
                .round()
          : 0);

  /// 試合後の1週間。試合の消耗と、練習または休養を反映する。
  ///
  /// 練習メニューは扱うカテゴリの数だけ伸びる枠を持つ。複合メニューは
  /// 1枠あたりの確率が下がる代わりに2か所に触れ、その分だけ疲れる。
  /// 居残りはその上に積む。専属スタッフと生活習慣は、どちらの効きも底上げする。
  WeekOutcome applyWeek(
    Player player, {
    TrainingMenu menu = TrainingMenu.rest,
    TrainingEffort effort = TrainingEffort.normal,
    TrainingCompanion companion = TrainingCompanion.alone,
    SetPiece? drill,
    StaffTeam staff = const StaffTeam(),
    Habits habits = const Habits(),
    Development development = const Development(),
    List<Detail> focus = const [],
    bool plateau = false,
    double environment = 1.0,
    int fatigue = 0,
    void Function(Detail detail)? aimed,
    void Function(AttributeKey key, int step)? toPoints,
    required bool played,
  }) {
    final costFactor = player.traits.conditionCostFactor;
    var condition = conditionAfterMatch(player, played: played);
    var attributes = player.attributes;
    var setPieces = player.setPieces;
    var physique = player.physique;
    Detail? trained;
    SetPiece? drilled;
    Signature? learned;
    var redirected = false;
    var awakened = false;

    // その週の手応え。休養の週には出さない。
    final outcome = menu.isRest
        ? TrainingOutcome.good
        : rollOutcome(
            random: _random,
            effort: effort,
            companion: companion,
            condition: condition,
            professionalism: player.personality.professionalism,
          );

    if (menu.isRest) {
      condition +=
          (menu.recovery * player.traits.restFactor).round() +
          staff.recoveryBonus +
          habits.recoveryBonus;
    } else {
      condition -=
          (menu.conditionCost * costFactor * effort.cost * companion.cost)
              .round();
      final canGrow = attributes.overallFor(player.position) < player.potential;
      // ポテンシャルに達しても、超越の1項目だけはそのカテゴリの練習で伸びる。
      final transcend = player.transcendDetail;
      final onlyTranscend =
          !canGrow &&
          transcend != null &&
          Player.transcending(player, attributes) &&
          menu.keys.contains(transcend.category);
      // プロ意識・専属コーチ・生活習慣が、同じ練習の身になり方を変える。
      final base =
          Formulas.trainingGrowthChance *
          Formulas.growthByAge(player.age - player.traits.peakAgeOffset) *
          menu.growthFactor *
          player.personality.trainingFactor *
          player.traits.trainingFactor *
          Formulas.potentialDrive(player.overall, player.potential) *
          staff.growthFactor *
          habits.growthFactor *
          environment;
      final step = Formulas.growthStep(
        player.age,
        player.overall,
        player.potential,
      );
      final effective = plateau ? base * Formulas.plateauGrowthFactor : base;
      if (canGrow || onlyTranscend) {
        // 大成功なら2回、空回りなら0回。倍率ではなく**引く回数**で効かせる。
        // 「大成功で2つ伸びた」と画面で数えられるようにするため。
        for (var draw = 0; draw < outcome.rolls; draw++) {
          for (final key in menu.keys) {
            if (onlyTranscend && key != transcend.category) continue;
            // ポジションの重みで割り戻す。同じ練習が、どのポジションでも
            // 同じくらい総合力を動かすようにする。
            final chance =
                effective *
                Formulas.growthShareFactor(
                  Attributes.weightShare(player.position, key),
                );
            if (_random.nextDouble() >= chance) continue;
            // 自分で振るなら、伸びるはずだったぶんを経験点にする。
            if (toPoints != null) {
              toPoints(key, step);
              continue;
            }
            // 同じカテゴリの中に方向があれば、そこから選ぶ。
            // 練習が「カテゴリのどれか」ではなく「決めた項目」になる。
            final inFocus = [
              for (final d in focus)
                if (d.category == key) d,
            ];
            final ds = inFocus.isEmpty ? key.details : inFocus;
            final wanted = onlyTranscend
                ? transcend
                : ds[_random.nextInt(ds.length)];
            aimed?.call(wanted);
            final target = Dependencies.resolve(
              wanted,
              attributes,
              ceilingOf: player.ceilingFor,
              dedicationOf: development.dedicationOf,
            );
            if (target != wanted) redirected = true;
            attributes = attributes.bumpDetail(
              target,
              step,
              max: player.ceilingFor(target),
            );
            trained ??= target;
          }
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
      final chance =
          Formulas.drillGrowthChance *
          player.personality.trainingFactor *
          player.traits.setPieceFactor *
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
            baseChance:
                Formulas.injuryTrainingChance *
                menu.injuryFactor *
                effort.injury *
                companion.injury *
                staff.injuryFactor *
                habits.injuryFactor,
            fatigue: fatigue,
            strain: development.strain,
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
      outcome: menu.isRest ? null : outcome,
    );
  }

  /// その週の手応えを引く。
  ///
  /// 画面に出す確率と、実際に引く確率を別に書かない。
  /// 「追い込む」を毎週押すのが最適解にならないように、
  /// **コンディションが低いほど空回りしやすい**のがここの要。
  static TrainingOutcome rollOutcome({
    required Random random,
    required TrainingEffort effort,
    required TrainingCompanion companion,
    required int condition,
    required int professionalism,
  }) {
    final odds = outcomeOdds(
      effort: effort,
      companion: companion,
      condition: condition,
      professionalism: professionalism,
    );
    final roll = random.nextDouble();
    if (roll < odds.great) return TrainingOutcome.great;
    if (roll < odds.great + odds.flat) return TrainingOutcome.flat;
    return TrainingOutcome.good;
  }

  /// 大成功・空回りの出やすさ。画面にもこの数字を出す。
  static ({double great, double flat}) outcomeOdds({
    required TrainingEffort effort,
    required TrainingCompanion companion,
    required int condition,
    required int professionalism,
  }) {
    final gap = condition - Formulas.conditionBaseline;
    final great =
        (effort.great +
                companion.greatBonus +
                gap * Formulas.trainingGreatPerCondition +
                (professionalism - 10) * Formulas.trainingGreatPerPro)
            .clamp(0.0, Formulas.trainingGreatMax);
    final flat =
        (effort.flat -
                companion.flatRelief -
                gap * Formulas.trainingFlatPerCondition)
            .clamp(0.0, Formulas.trainingFlatMax);
    return (great: great, flat: flat);
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

  Detail _randomDetail() =>
      Detail.values[_random.nextInt(Detail.values.length)];

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
