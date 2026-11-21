// 文の持ち物（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../l10n/lang.dart';
import '../models/attributes.dart';
import '../models/pitch.dart';

/// 局面の選択がうまくいったときに何が起きるか。
enum Outcome {
  /// ゴール。
  goal,

  /// アシスト。
  assist,

  /// 得点には直結しないが、評価される良いプレー。
  play,
}

/// **その局面での役どころ。布石か、仕留めか。**
///
/// 局面ごとに手で付けるのではなく、その局面の3つの手から機械的に決める
/// （`Scenario.roleOf`）。手で付けると、局面を足したときに付け忘れて
/// 「なぜかコンボが出ない局面」ができる。
enum ComboRole {
  /// どちらでもない手。
  none,

  /// **布石。** 通っても見返りは小さいが、次の仕留めが深くなる。
  setup,

  /// **仕留め。** 布石の後なら、通りやすく、決まりやすい。
  finish,
}

/// **外したときに、相手にどれだけの好機を渡すか**（2026-11-15）。
///
/// 以前は手を外しても評価点が下がるだけで、失点は試合開始時に決まった
/// まま動かなかった。「競り負け、決定的なヘディングを許した」と書いて
/// あっても、スコアは何も変わらない。守る選手の3つの手は種類が揃って
/// いて（センターバックは12局面のうち9つが3つとも止める手）、
/// 状況の重み（`MatchStakes`）でも差が付かなかった。差を付けられるのは
/// **外したときに何が起きるか**だけ。
///
/// 段は失敗の文と揃える。「スローインを与えた」手に失点の危なさを
/// 付けると、画面が嘘をつく（`concede_test` が見張る）。
enum Exposure {
  /// 外しても、すぐ失点にはつながらない。
  none,

  /// シュートを打たれる。
  shot,

  /// 決定機を与える。
  chance,

  /// PK を与える・PK を止めにいく。
  penalty,
}

/// 局面で選べる1つの手。
class ScenarioOption {
  const ScenarioOption({
    required Say label,
    required this.key,
    this.detail,
    required this.difficulty,
    required this.outcome,
    required Say successText,
    required Say failureText,
    this.foul = 0,
    this.preventsGoal = false,
    this.exposure = Exposure.none,
    this.lingering = false,
  }) : _label = label,
       _successText = successText,
       _failureText = failureText;

  /// **文は日本語と英語の2つを持つ**（[Say]）。この表は `static const`
  /// なので `tr()` を直に書けない。外には `String` のまま見せる。
  final Say _label;

  String get label => _label.t;

  /// 成否を判定する能力のカテゴリ。
  final AttributeKey key;

  /// 判定に使う詳細能力。無ければカテゴリの平均で判定する。
  final Detail? detail;

  /// 判定の基準値。能力値がこれと同じでも五分にはならず、少し不利。
  final int difficulty;

  final Outcome outcome;

  final Say _successText;
  final Say _failureText;

  String get successText => _successText.t;
  String get failureText => _failureText.t;

  /// その手の荒さ。0 なら審判は出てこない。
  ///
  /// 1.0 なら選んだ時点で必ず警告（止めるための反則）。
  /// 0〜1 の間なら、失敗したときにその確率で警告。
  final double foul;

  /// 選べば必ず警告になる手か。
  bool get isTacticalFoul => foul >= 1.0;

  /// 通れば、これから入るはずだった失点を1つ消す手か。
  ///
  /// 止めるための反則が「警告を受けるだけの損な手」にならないように、
  /// 実際に防いでいるものを効かせる。
  final bool preventsGoal;

  /// 外したときに相手へ渡す好機。自陣の局面の手にだけ付く。
  final Exposure exposure;

  /// **通っても、相手の攻撃が終わらない手か**（2026-11-15）。
  ///
  /// 遅らせる・構える・見送る・蹴り返す手は、通っても攻撃は続く。
  /// 以前はこうした受け身の手が一番易しく、外しても一番安全で、
  /// 弱みが1つも無かった——守る選手の局面の多くで、答えがいつも同じだった。
  /// 奪う手（[preventsGoal]）は通れば攻撃を終わらせる。その対にする。
  final bool lingering;
}

/// その局面が出てくる展開。
///
/// 試合の中身が展開と噛み合っていないと、終盤に2点を追いながら
/// 「無難につないで作り直す」局面ばかりが来る。局面そのものに
/// 出どころを持たせて、状況に合ったものと入れ替える。
enum ScenarioTempo {
  /// いつでも出る。試合の骨格はこちら。
  any,

  /// 追いかける展開でだけ出る。リスクを取る手が並ぶ。
  chase,

  /// 守り切る展開でだけ出る。時間の使い方が問われる。
  hold,
}

/// 試合中に提示される1つの局面。
class Scenario {
  const Scenario({
    required this.id,
    required Say situation,
    required this.spot,
    required this.options,
    this.tempo = ScenarioTempo.any,
  }) : _situation = situation;

  final String id;

  final Say _situation;

  String get situation => _situation.t;

  /// この局面が起きているピッチ上の場所。
  ///
  /// 既定値は置かない。場所の無い局面は絵にできないので、
  /// 局面を足すときに必ず決めることになる。
  final PitchSpot spot;

  final List<ScenarioOption> options;

  /// この局面が出てくる展開。
  final ScenarioTempo tempo;

  /// **その手の役どころ。**
  ///
  /// 仕留めは「得点に繋がる手のうち一番難しいもの」、
  /// 布石は「無難な手のうち一番易しいもの」。
  /// **仕留めより難しい布石は置かない**——それはただの遠回りになる。
  /// 仕留めが無い局面（3つとも無難な手）には布石も置かない。
  ///
  /// **同じ `Outcome` で難易度だけ違う手が、どの局面にもある。**
  /// `mf-build` の「サイドへ展開」52 と「自分で持ち上がる」66 はどちらも
  /// `play` で、見返りが同じなら難しいほうを選ぶ理由が無い。実測で、
  /// 育て方を4つ変えても**答えの決まった23局面が1つも動かなかった**
  /// （`test/choice_sim.dart`）。
  ///
  /// **布石を難しいほうへ移す案は、測って外した**（2026-09-23）。
  /// 同じ `Outcome` で難しいだけの手に役どころを与える狙いだったが、
  /// 布石が通りにくくなるぶん繋がる回数が減り、「一手だけ待つ」型の
  /// ゴールが 88 → 86、タイトルが 4.21 → 3.80 と下がった
  /// （`test/setup_sim.dart`）。**死んでいる手は、まだ死んでいる。**
  ComboRole roleOf(ScenarioOption option) {
    final scoring = [
      for (final o in options)
        if (o.outcome != Outcome.play) o,
    ];
    if (scoring.isEmpty) return ComboRole.none;
    final finish = scoring.reduce(
      (a, b) => b.difficulty > a.difficulty ? b : a,
    );
    if (identical(option, finish)) return ComboRole.finish;

    final plain = [
      for (final o in options)
        if (o.outcome == Outcome.play && o.difficulty < finish.difficulty) o,
    ];
    if (plain.isEmpty) return ComboRole.none;
    final setup = plain.reduce((a, b) => b.difficulty < a.difficulty ? b : a);
    return identical(option, setup) ? ComboRole.setup : ComboRole.none;
  }
}

/// ポジション別の局面プール。
///
/// 各局面は「難しいが得点に直結する手」と「安全だが見返りが小さい手」を
/// 対にしてある。どちらを選ぶかがこのゲームの判断そのものなので、
/// 常に正解になる選択肢を作らない。
///
/// 1試合で3つ引くので、各ポジション7つあれば同じ組み合わせは
/// 数試合に一度しか出ない。3つしか無いと毎試合同じ顔ぶれになる。
class ScenarioPool {
  const ScenarioPool._();

  static List<Scenario> forPosition(Position position) =>
      forFamily(position.family);

  static List<Scenario> forFamily(ScenarioFamily family) => switch (family) {
    ScenarioFamily.goalkeeper => goalkeeper,
    ScenarioFamily.defence => defence,
    ScenarioFamily.midfield => midfield,
    ScenarioFamily.forward => forward,
  };

  /// 展開に関係なく引ける局面。試合の骨格はこちらから引く。
  static List<Scenario> neutralFor(ScenarioFamily family) =>
      forFamily(family).where((s) => s.tempo == ScenarioTempo.any).toList();

  /// その展開のときにだけ出る局面。
  static List<Scenario> tempoFor(ScenarioFamily family, ScenarioTempo tempo) =>
      forFamily(family).where((s) => s.tempo == tempo).toList();

  static const List<Scenario> goalkeeper = [
    Scenario(
      id: 'gk-oneonone',
      spot: PitchSpot.ownBox,
      situation: Say('相手FWが抜け出した。1対1。距離を詰めるか、構えて待つか。', 'A striker is through on goal. One on one. Close him down, or hold your ground?'),
      options: [
        ScenarioOption(
          label: Say('飛び出して距離を詰める', 'Rush out and close him down'),
          key: AttributeKey.goalkeeping,
          // **構えるのと同じ能力では判定しない。** 同じ見返りで難易度だけ
          // 高い手は、判定する能力まで同じだと逃げ道が無い（尖らせても
          // 選べない）。飛び出しは間合いの詰め方＝セービングの領分。
          detail: Detail.reflexes,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('一気に間合いを詰め、足元でシュートを止めた。', 'You closed the gap in a flash and smothered the shot at his feet.'),
          failureText: Say('飛び出しが早く、ループで頭上を抜かれた。', 'You came too early and he lobbed it over your head.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('構えてコースを消す', 'Stand up and cut off the angle'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('体を大きく見せてコースを消し、正面で止めた。', 'You made yourself big, cut off the angle and blocked it square on.'),
          failureText: Say('読みが外れ、逆を突かれた。', 'You guessed wrong and he went the other way.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('足を使って時間を稼ぐ', 'Use your feet and buy time'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('寄せる角度を変えて遅らせ、DFの帰陣を待てた。', 'You shifted your angle to delay him and your defenders got back.'),
          failureText: Say('中途半端な位置取りで、簡単に打たれた。', 'You were caught half in, half out and he shot past you easily.'),
          exposure: Exposure.chance,
          lingering: true,
        ),
      ],
    ),
    Scenario(
      id: 'gk-cross',
      spot: PitchSpot.ownBox,
      situation: Say('ゴール前に高いクロス。相手FWと自分のDFが競っている。', 'A high cross into the box. A striker and one of your defenders are contesting it.'),
      options: [
        ScenarioOption(
          label: Say('パンチングで弾く', 'Punch it clear'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('混戦を避けて遠くへ弾き出した。', 'You beat the crowd and punched it a long way clear.'),
          failureText: Say('パンチングが弱く、こぼれ球を押し込まれかけた。', 'Your punch was weak and the loose ball was nearly turned in.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('キャッチに行く', 'Come and catch it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('最高点で掴み、そのまま速攻を始めた。', 'You claimed it at the highest point and set off a counter.'),
          failureText: Say('手から弾き、目の前に落としてしまった。', 'It slipped through your hands and dropped right in front of goal.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('ラインに留まってDFに任せる', 'Stay on your line and leave it to the defence'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('DFがクリアしやすい位置を保ち、危険を消した。', 'You held a position your defender could clear from and killed the danger.'),
          failureText: Say('DFと譲り合い、誰も触れなかった。', 'You and your defender left it to each other, and nobody touched it.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'gk-pk',
      spot: PitchSpot.ownGoalLine,
      situation: Say('PKを与えてしまった。キッカーが助走に入る。', 'You have given away a penalty. The taker starts his run-up.'),
      options: [
        ScenarioOption(
          label: Say('読んで先に飛ぶ', 'Guess and dive early'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 78,
          outcome: Outcome.play,
          successText: Say('読み勝った。両手で弾き出し、スタジアムが沸いた。', 'You read it right. Both hands pushed it away and the stadium erupted.'),
          failureText: Say('逆に飛んだ。ボールは反対側へ。', 'You dived the wrong way. The ball went in on the other side.'),
          exposure: Exposure.penalty,
        ),
        ScenarioOption(
          label: Say('ぎりぎりまで待つ', 'Wait as long as you can'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 74,
          outcome: Outcome.play,
          successText: Say('最後まで待ち、反応でセーブした。', 'You waited to the last instant and saved it on reaction.'),
          failureText: Say('待ちすぎて、隅への強いボールに届かなかった。', 'You waited too long and could not reach the firm shot into the corner.'),
          exposure: Exposure.penalty,
        ),
        ScenarioOption(
          label: Say('中央で構える', 'Hold your ground in the middle'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 66,
          outcome: Outcome.play,
          successText: Say('キッカーが迷った。真ん中に蹴ったボールを止めた。', 'The taker had second thoughts. He hit it down the middle and you saved it.'),
          failureText: Say('キッカーは迷わず隅へ蹴った。', 'The taker never hesitated and buried it in the corner.'),
          exposure: Exposure.penalty,
        ),
      ],
    ),
    Scenario(
      id: 'gk-distribution',
      spot: PitchSpot.ownBox,
      situation: Say('ボールをキャッチした。相手は前掛かりで、前線に味方が1人残っている。', 'You have caught the ball. They are pushed right up, and one teammate is still upfield.'),
      options: [
        ScenarioOption(
          label: Say('前線へロングスローを投げる', 'Throw a long ball upfield'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 68,
          outcome: Outcome.assist,
          successText: Say('一本のスローで前線へ。味方が抜け出して決めた。', 'One throw found him upfield. He broke clear and scored.'),
          failureText: Say('距離が足りず、相手に拾われた。', 'The throw was short and they picked it up.'),
        ),
        ScenarioOption(
          label: Say('大きく蹴り出す', 'Kick it long'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('陣地を大きく回復し、相手の圧力を逃した。', 'You won a lot of ground and relieved the pressure.'),
          failureText: Say('キックが流れ、相手のスローインになった。', 'The kick sliced away and gave them a throw-in.'),
        ),
        ScenarioOption(
          label: Say('近くのDFに繋ぐ', 'Roll it to a nearby defender'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 42,
          outcome: Outcome.play,
          successText: Say('落ち着いて繋ぎ、ビルドアップを始めた。', 'You played it calmly and started the build-up.'),
          failureText: Say('DFへのパスが弱く、相手FWに狙われた。', 'The pass to your defender was weak and a striker pounced on it.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'gk-longshot',
      spot: PitchSpot.ownGoalLine,
      situation: Say('25mからのミドルシュート。ボールが揺れながら飛んでくる。', 'A shot from 25 yards. The ball is swerving as it comes.'),
      options: [
        ScenarioOption(
          label: Say('キャッチする', 'Catch it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 74,
          outcome: Outcome.play,
          successText: Say('揺れるボールを胸に収めた。', 'You took the swerving ball into your chest.'),
          failureText: Say('手から弾き、こぼれ球を詰められた。', 'It bounced out of your hands and they tucked away the rebound.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('横に弾く', 'Push it wide'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('無理をせず、コーナーへ弾き出した。', 'You took no chances and pushed it out for a corner.'),
          failureText: Say('弾いた先に相手がいた。', 'You pushed it straight to an opponent.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('体で受ける', 'Block it with your body'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('体の正面で受け止め、こぼれ球も自分で抑えた。', 'You took it square on your body and smothered the rebound yourself.'),
          failureText: Say('当たったボールが、股の間へ転がった。', 'It struck you and squirmed through your legs.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'gk-sweeper',
      spot: PitchSpot.ownEdge,
      situation: Say('DFの背後に長いボール。相手FWと自分、どちらが先に触るか。', 'A long ball in behind your defence. You or the striker, whoever gets there first.'),
      options: [
        ScenarioOption(
          label: Say('エリアの外まで飛び出してクリア', 'Sprint out beyond the box to clear'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('エリア外で先に触り、大きくクリアした。', 'You got there first outside the box and cleared it long.'),
          failureText: Say('間に合わず、無人のゴールを狙われた。', 'You did not get there, and they had an open goal to aim at.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('エリア内で待って処理する', 'Stay in your box and deal with it there'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('慌てず待ってエリア内で処理した。ただ、相手はまだ詰めている。', 'You waited calmly and dealt with it inside the box. He is still coming, though.'),
          failureText: Say('待ちすぎて、FWにボールを収められた。', 'You waited too long and he brought the ball under control.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('DFに声をかけて任せる', 'Call it and leave it to your defender'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 36,
          outcome: Outcome.play,
          successText: Say('声で味方を動かし、DFが先に触った。こぼれは相手の近くだ。', 'Your shout moved him and your defender got there first. The loose ball drops near an opponent.'),
          failureText: Say('指示が伝わらず、DFとぶつかった。', 'Your call did not get through and you collided with your defender.'),
          exposure: Exposure.chance,
          lingering: true,
        ),
      ],
    ),
    Scenario(
      id: 'gk-lastminute',
      spot: PitchSpot.ownBox,
      situation: Say('相手が人数をかけてきたコーナー。GKまで前に出てきている。', 'A corner with everyone forward. Even their keeper has come up.'),
      options: [
        ScenarioOption(
          label: Say('飛び出してキャッチ', 'Come for it and catch it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('混戦の中で掴み切った。試合を締めた。', 'You claimed it in the crowd and shut the game down.'),
          failureText: Say('触れず、こぼれ球を詰められた。', 'You never got near it and they turned in the rebound.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('ライン上で待つ', 'Stay on your line'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 60,
          outcome: Outcome.play,
          successText: Say('ライン上で反応し、至近距離を止めた。', 'You reacted on your line and saved it from point-blank range.'),
          failureText: Say('密集で視界を塞がれ、反応できなかった。', 'The crowd blocked your view and you could not react.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('クリア後に前へ投げて速攻', 'Clear it and throw long to counter'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 64,
          outcome: Outcome.assist,
          successText: Say('クリアを拾って前へ投げ、無人のゴールに味方が決めた。', 'You gathered the clearance, threw it long, and a teammate scored into an empty net.'),
          failureText: Say('投げたボールが弱く、相手に渡った。', 'Your throw was weak and they got the ball back.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'gk-corner',
      spot: PitchSpot.ownGoalLine,
      situation: Say('相手のコーナーキック。ゴール前は人で埋まっている。', 'Their corner. The box is packed with bodies.'),
      options: [
        ScenarioOption(
          label: Say('パンチングで弾き出す', 'Punch it away'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('拳で遠くへ弾いた。危険な場所から消えた。', 'Your fist sent it a long way clear, out of the danger area.'),
          failureText: Say('中途半端な弾きが、相手の前にこぼれた。', 'A half-hearted punch dropped right in front of an opponent.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('飛び出して掴む', 'Come and claim it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('人垣の中から両手で掴み取った。ゴール前が静かになる。', 'You rose through the bodies and caught it in both hands. The box went quiet.'),
          failureText: Say('人に当たって届かず、ゴール前に落ちた。', 'You hit a body on the way and it dropped in front of goal.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('ライン上に残って備える', 'Stay on your line and be ready'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('至近距離のヘディングに反応し、足で止めた。', 'You reacted to a header from close range and kept it out with your foot.'),
          failureText: Say('見送ったボールが、そのままゴールへ向かった。', 'You let it go and it carried on into the net.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'gk-backpass',
      spot: PitchSpot.ownBox,
      situation: Say('味方から苦しいバックパス。相手FWが全力で寄せてくる。', 'An awkward backpass from a teammate. A striker is sprinting in.'),
      options: [
        ScenarioOption(
          label: Say('大きく蹴り出す', 'Kick it long'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('タッチラインの外まで蹴り出した。相手ボールで、また始まる。', 'You hammered it out of play. Their throw, and here it comes again.'),
          failureText: Say('ミートせず、相手の足元へ転がった。', 'You did not get a clean strike and it rolled to his feet.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('持ち出してかわす', 'Take it past him'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 75,
          outcome: Outcome.play,
          successText: Say('一歩ずらして寄せをかわし、時間を作った。', 'You shifted it a yard, beat the press and bought yourself time.'),
          failureText: Say('足元をつつかれ、無人のゴールを晒した。', 'He poked it off your toe and left your goal exposed.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('空いた味方へ短くつける', 'Clip it short to a free teammate'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 53,
          outcome: Outcome.play,
          successText: Say('寄せの外へ的確につけ、相手のプレスを外した。', 'You picked out the man beyond the press and beat their pressure.'),
          failureText: Say('パスが弱く、危険な位置で奪われた。', 'Your pass was weak and you lost it in a dangerous spot.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'gk-rebound',
      spot: PitchSpot.ownGoalLine,
      situation: Say('一度は弾いた。こぼれ球に相手が詰めてくる。', 'You parried it once. An opponent is charging in on the loose ball.'),
      options: [
        ScenarioOption(
          label: Say('前に出て抑え込む', 'Come out and smother it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('体ごと覆いかぶさり、ボールを収めた。', 'You spread yourself over the ball and gathered it.'),
          failureText: Say('一歩遅れ、先に足を出された。', 'You were a step late and he got his foot there first.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('足でコーナーに逃げる', 'Hook it out for a corner'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('伸ばした足に当て、ラインの外へ逃した。', 'You got a foot to it and turned it out of play.'),
          failureText: Say('当たりが甘く、ゴール前に残ってしまった。', 'You barely got a touch and it stayed in front of goal.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('構え直して次に備える', 'Reset and get ready for the next one'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('角度を切って構え、至近距離の一撃を弾き返した。', 'You set yourself at the right angle and parried the follow-up from close range.'),
          failureText: Say('重心が残り、逆を突かれた。', 'Your weight was still back and he went the other way.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'gk-rain',
      spot: PitchSpot.ownBox,
      situation: Say('雨脚が強い。ゴール前に浮き球が落ちてくる。手が滑る。', 'Heavy rain. A floated ball is dropping into your box. Your hands are slipping.'),
      options: [
        ScenarioOption(
          label: Say('キャッチにいく', 'Go and catch it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 74,
          outcome: Outcome.play,
          successText: Say('濡れたボールを、指先までしっかり掴んだ。', 'You held the wet ball right to your fingertips.'),
          failureText: Say('手からこぼれ、ゴール前に転がった。', 'It squirmed out of your hands and rolled across the box.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('両手で確実に弾く', 'Parry it firmly with both hands'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 56,
          outcome: Outcome.play,
          successText: Say('無理をせず前に弾き、味方がクリアした。', 'You took no chances, pushed it out, and a teammate cleared.'),
          failureText: Say('弾いた先に相手がいた。', 'You pushed it straight to an opponent.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('味方に任せて声を出す', 'Shout and leave it to your defence'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('一声でDFが動き、危なげなく処理した。', 'One call moved your defender and it was dealt with comfortably.'),
          failureText: Say('声が届かず、味方と交錯した。', 'Your shout did not carry and you ran into your own man.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'gk-line',
      spot: PitchSpot.ownEdge,
      situation: Say('押し込まれている。最終ラインがずるずる下がってきた。', 'You are under siege. Your back line keeps dropping deeper.'),
      options: [
        ScenarioOption(
          label: Say('声でラインを押し上げる', 'Shout your line forward'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 60,
          outcome: Outcome.play,
          successText: Say('ラインが揃い、相手の攻撃が窮屈になった。', 'Your line squeezed up and their attack ran out of room.'),
          failureText: Say('中途半端に上げ、背後を取られた。', 'You pushed up half-heartedly and they got in behind.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('自分が高い位置を取る', 'Take up a higher position yourself'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 68,
          outcome: Outcome.play,
          successText: Say('背後のボールを先回りして処理した。', 'You got round in front of the ball in behind and dealt with it.'),
          failureText: Say('出た背中を狙われ、ループを浴びた。', 'They spotted the space behind you and lobbed you.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('深く構えて跳ね返しに備える', 'Sit deep and be ready for the rebounds'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('立て続けのシュートを、体で止め続けた。', 'You blocked shot after shot with your body.'),
          failureText: Say('押し込まれ続け、シュートを浴びた。', 'They kept you pinned back and the shots kept coming.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    // ---- 追いかける展開 ----
    Scenario(
      id: 'gk-chase-quick',
      spot: PitchSpot.ownBox,
      situation: Say('1点を追う終盤。キャッチした。すぐに攻撃を始めたい。', 'Late on, a goal down. You have caught it. You want to attack at once.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('前線へ大きく投げる', 'Throw it long upfield'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 66,
          outcome: Outcome.assist,
          successText: Say('一投で戦況が変わった。そのまま形になり、点が入った。', 'One throw changed the game. It stuck, and the goal came.'),
          failureText: Say('距離が足りず、中盤で拾われた。', 'The throw was short and they picked it up in midfield.'),
        ),
        ScenarioOption(
          label: Say('近くの味方に素早く付ける', 'Give it quickly to someone close'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 44,
          outcome: Outcome.play,
          successText: Say('止まらずに前を向かせた。攻撃が途切れない。', 'You kept him facing forward without breaking stride. The attack flowed on.'),
          failureText: Say('相手が待っていた。危うく奪われかけた。', 'They were waiting for it and nearly won it off you.'),
        ),
        ScenarioOption(
          label: Say('蹴って一気に押し込む', 'Kick it long and pin them back'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('深い位置まで届いた。全体を押し上げられる。', 'It reached deep into their half. Everyone can push up now.'),
          failureText: Say('力んで大きく外へ出た。時間だけが過ぎる。', 'You over-hit it and it went out. Time ticks away.'),
        ),
      ],
    ),
    Scenario(
      id: 'gk-chase-corner',
      spot: PitchSpot.box,
      situation: Say('ロスタイムのコーナー。GKも上がれと言われた。', 'A corner in stoppage time. They have told you to go up.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('相手ゴール前まで上がって競る', 'Go up into their box and compete'),
          key: AttributeKey.shooting,
          detail: Detail.heading,
          difficulty: 80,
          outcome: Outcome.goal,
          successText: Say('誰も自分を捕まえていなかった。頭で押し込んだ。', 'Nobody had picked you up. You headed it in.'),
          failureText: Say('打点が合わず、後ろへ流れていった。', 'You mistimed your jump and it drifted behind you.'),
        ),
        ScenarioOption(
          label: Say('前で潰れて味方に触らせる', 'Get in front and let a teammate finish'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('相手GKを釣り出した。空いた場所に味方が入る。', 'You drew their keeper out and a teammate took the space.'),
          failureText: Say('中途半端な位置で、誰の邪魔にもならなかった。', 'You ended up in no man\'s land, in nobody\'s way.'),
        ),
        ScenarioOption(
          label: Say('上がらずにゴールに残る', 'Stay back in your own goal'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 36,
          outcome: Outcome.play,
          successText: Say('冷静に残った。返された一本を難なく処理する。', 'You stayed back calmly and dealt with the clearance without fuss.'),
          failureText: Say('中途半端に前へ出て、逆に慌てた。', 'You half went forward and ended up in a panic.'),
        ),
      ],
    ),
    Scenario(
      id: 'gk-chase-line',
      spot: PitchSpot.ownEdge,
      situation: Say('攻めるためにラインが高い。背後は広く空いている。', 'Your line is high so you can attack. There is a lot of space behind.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('迷わず飛び出して処理する', 'Come out without hesitating'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('一歩目が早かった。ペナルティエリアの外で刈り取る。', 'Your first step was quick. You cut it out beyond the box.'),
          failureText: Say('判断が遅れ、先に触られた。', 'You made your mind up too late and he got there first.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('大きくクリアしてやり過ごす', 'Clear it long and ride it out'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('無理をせず遠くへ。危険な時間をやり過ごした。', 'You took no chances and sent it far. The dangerous spell passed.'),
          failureText: Say('ミートせず、相手の前へ転がった。', 'You did not strike it cleanly and it rolled out in front of an opponent.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('拾ってそのまま前線へ繋ぐ', 'Gather it and play it straight upfield'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 64,
          outcome: Outcome.assist,
          successText: Say('拾った流れのまま一本。守備が攻撃に変わった。', 'One pass out of the clearance. Defence turned into attack.'),
          failureText: Say('慌てて蹴り、誰にも合わなかった。', 'You rushed the kick and found nobody.'),
        ),
      ],
    ),
    // ---- 守り切る展開 ----
    Scenario(
      id: 'gk-hold-cross',
      spot: PitchSpot.ownBox,
      situation: Say('1点リードの終盤。放り込みが続く。', 'Late on, a goal up. The balls keep coming in.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('飛び出してキャッチする', 'Come and claim it'),
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('人の間を抜けて掴み取った。味方の息が整う。', 'You came through the bodies and took it. Your teammates can breathe.'),
          failureText: Say('触れずに後ろへ流れ、慌ててゴールへ戻った。', 'You missed it and it drifted behind you. You scrambled back to your goal.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('パンチングで遠くへ弾く', 'Punch it a long way clear'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 54,
          outcome: Outcome.play,
          successText: Say('確実に、そして遠くへ弾いた。二次攻撃は無い。', 'Firm, and a long way out. There is no second ball.'),
          failureText: Say('当たりが浅く、目の前にこぼれた。', 'You caught it thin and it dropped right in front of you.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('ゴールを空けずに構える', 'Hold your position and keep the goal covered'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 42,
          outcome: Outcome.play,
          successText: Say('動かない判断が正しかった。ヘディングを正面で受ける。', 'Standing still was the right call. You took the header square on.'),
          failureText: Say('立ち位置が半歩ずれ、際どいコースを許した。', 'You were half a yard out of position and let one past at a tight angle.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'gk-hold-clock',
      spot: PitchSpot.ownBox,
      situation: Say('ロスタイム。ゴールキック。時間を使いたい。', 'Stoppage time. A goal kick. You want to use the clock.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('ゆっくり準備して時間を使う', 'Take your time setting up'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 68,
          outcome: Outcome.play,
          successText: Say('主審に急かされるぎりぎりまで使った。残りは僅か。', 'You used every second until the referee got impatient. Not long left.'),
          failureText: Say('あからさますぎて警告を受けた。', 'It was too obvious and you were booked.'),
          foul: 0.6,
        ),
        ScenarioOption(
          label: Say('味方に繋いで保持する', 'Play it short and keep possession'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('短くつないで回した。相手に触らせない。', 'Short passes, keeping it moving. They cannot get near it.'),
          failureText: Say('寄せられて、自陣で危うく奪われかけた。', 'They pressed up and you were nearly robbed in your own half.'),
        ),
        ScenarioOption(
          label: Say('大きく蹴って相手陣へ返す', 'Kick it long and give it back to them'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('深い位置まで飛んだ。ただ、ボールは相手のものになる。', 'It flew deep into their half. The ball is theirs now, though.'),
          failureText: Say('短くなり、そのまま押し返された。', 'It fell short and came straight back at you.'),
          lingering: true,
        ),
      ],
    ),
    Scenario(
      id: 'gk-hold-wall',
      spot: PitchSpot.ownEdge,
      situation: Say('終盤、危険な位置でフリーキックを与えた。壁を作る。', 'Late on, you have given away a free kick in a dangerous spot. Set your wall.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('壁を厚くしてコースを消す', 'Make the wall bigger and block the angle'),
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 66,
          outcome: Outcome.play,
          successText: Say('狙える場所を消し切った。壁に当たって終わる。', 'You shut off everything he could aim at. It hit the wall and ended there.'),
          failureText: Say('壁の位置がずれ、空けた側を狙われた。', 'Your wall was in the wrong place and he aimed at the side you left open.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('壁を薄くして自分で見る', 'Make the wall smaller so you can see'),
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('視界を確保していた。反応して弾き出す。', 'You kept your line of sight, reacted, and pushed it away.'),
          failureText: Say('見えていても届かなかった。', 'You saw it all the way and still could not reach it.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('味方に指示して人を捕まえる', 'Organise your defence and pick up the runners'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('大声で全員を動かした。それでもキッカーは狙ってくる。', 'You shouted everyone into position. He is still going to have a go, though.'),
          failureText: Say('指示が通らず、ニアで一人余らせた。', 'Your instructions did not get through and you left a man free at the near post.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
      ],
    ),
  ];

  static const List<Scenario> forward = [
    Scenario(
      id: 'fw-box',
      spot: PitchSpot.box,
      situation: Say('ペナルティエリア内でボールを受けた。DFが2枚寄せてくる。', 'You have the ball inside the box. Two defenders are closing in.'),
      options: [
        ScenarioOption(
          label: Say('強引にシュートを打つ', 'Force a shot away'),
          key: AttributeKey.shooting,
          detail: Detail.shotPower,
          difficulty: 72,
          outcome: Outcome.goal,
          successText: Say('寄せられる前に振り抜いた。ネットが揺れる。', 'You swung at it before they got there. The net bulged.'),
          failureText: Say('体勢が崩れ、枠を大きく外した。', 'You lost your balance and dragged it well wide.'),
        ),
        ScenarioOption(
          label: Say('横の味方に落とす', 'Lay it off square'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 55,
          outcome: Outcome.assist,
          successText: Say('柔らかく落としたボールを味方が流し込んだ。', 'Your soft lay-off was swept home by a teammate.'),
          failureText: Say('パスがずれ、DFにカットされた。', 'Your pass was off and a defender cut it out.'),
        ),
        ScenarioOption(
          label: Say('キープして味方を待つ', 'Hold it up and wait for support'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 48,
          outcome: Outcome.play,
          successText: Say('体を入れて時間を作り、攻撃を落ち着かせた。', 'You got your body in and bought time to settle the attack.'),
          failureText: Say('力負けしてボールを失った。', 'You were muscled off it and lost the ball.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-through',
      spot: PitchSpot.box,
      situation: Say('最終ラインの裏へスルーパスが出た。GKが飛び出してくる。', 'A through ball in behind the back line. The keeper is rushing out.'),
      options: [
        ScenarioOption(
          label: Say('ループシュートを狙う', 'Try to lob him'),
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 68,
          outcome: Outcome.goal,
          successText: Say('GKの頭上を越えるループ。美しく決まった。', 'A lob over the keeper\'s head. Beautifully taken.'),
          failureText: Say('高すぎた。ボールはバーの上へ消えた。', 'Too high. The ball disappeared over the bar.'),
        ),
        ScenarioOption(
          label: Say('GKをかわして流し込む', 'Round the keeper and slot it in'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: Say('軽くかわして無人のゴールへ流し込んだ。', 'You went past him easily and rolled it into the empty net.'),
          failureText: Say('足に当てられ、ボールがこぼれた。', 'He got a foot to it and the ball squirmed away.'),
        ),
        ScenarioOption(
          label: Say('走り込む味方へ横パス', 'Square ball to the runner'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 58,
          outcome: Outcome.assist,
          successText: Say('冷静な横パス。味方が無人のゴールへ押し込んだ。', 'A calm pass square, and your teammate tapped it into the empty net.'),
          failureText: Say('パスが強すぎて味方が追いつけなかった。', 'Your pass was too firm and he could not catch it.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-cross',
      spot: PitchSpot.box,
      situation: Say('サイドからクロスが上がる。DFとの空中戦になる。', 'A cross is coming in from the wing. It is you against a defender in the air.'),
      options: [
        ScenarioOption(
          label: Say('ヘディングで叩きつける', 'Head it down hard'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 70,
          outcome: Outcome.goal,
          successText: Say('競り合いに勝ち、ヘディングをゴール左隅へ。', 'You won the header and planted it into the bottom left corner.'),
          failureText: Say('競り負けて、DFにクリアされた。', 'You lost the header and the defender cleared.'),
        ),
        ScenarioOption(
          label: Say('ニアで潰れて味方を空ける', 'Attack the near post and make space'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 45,
          outcome: Outcome.assist,
          successText: Say('ニアでDFを引き付け、空いた味方が押し込んだ。', 'You pulled the defender to the near post and a teammate finished at the back.'),
          failureText: Say('中途半端な動きで、味方ごと消えてしまった。', 'You went half-heartedly and took your own teammate out of it.'),
        ),
        ScenarioOption(
          label: Say('下がってこぼれ球を狙う', 'Drop off and look for the rebound'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 60,
          outcome: Outcome.goal,
          successText: Say('こぼれ球に誰よりも早く反応し、押し込んだ。', 'You read the rebound quicker than anyone and turned it in.'),
          failureText: Say('読みが外れ、こぼれ球は相手の足元へ。', 'You guessed wrong and the loose ball fell to an opponent.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-counter',
      spot: PitchSpot.ownThird,
      situation: Say('自陣でボールを奪った。相手DFは2人だけ、こちらは自分と味方の2人。', 'You have won the ball in your own half. Only two defenders back, and it is two of you.'),
      options: [
        ScenarioOption(
          label: Say('全力で駆け上がって受ける', 'Sprint forward to receive it'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.goal,
          successText: Say('DFを置き去りにして受け、そのまま決めた。', 'You left them behind, took it, and finished it yourself.'),
          failureText: Say('追いつかれ、シュートはブロックされた。', 'They caught you up and your shot was blocked.'),
        ),
        ScenarioOption(
          label: Say('DFを引き付けて味方に流す', 'Draw the defenders and slide it to your teammate'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 78,
          outcome: Outcome.assist,
          successText: Say('DFを2人とも引き付けてから流し、味方がフリーで決めた。', 'You pulled both defenders in before releasing it. He finished unmarked.'),
          failureText: Say('引き付けすぎて、自分ごと潰された。', 'You held it too long and got crowded out.'),
        ),
        ScenarioOption(
          label: Say('無理せずポゼッションに切り替える', 'Take no chances and switch to keeping the ball'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 40,
          outcome: Outcome.play,
          successText: Say('速攻を捨てて確実に繋ぎ、押し込む形を作った。', 'You passed up the counter, kept it safe and built the pressure instead.'),
          failureText: Say('判断が遅れ、相手の帰陣を許した。', 'You hesitated and let them get back into shape.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-pk',
      spot: PitchSpot.penaltySpot,
      situation: Say('PKを獲得した。キッカーは自分。GKがラインで揺さぶってくる。', 'You have won a penalty. You are taking it. The keeper is dancing on his line.'),
      options: [
        ScenarioOption(
          label: Say('隅を狙って強く蹴る', 'Hit it hard into the corner'),
          key: AttributeKey.shooting,
          detail: Detail.shotPower,
          difficulty: 56,
          outcome: Outcome.goal,
          successText: Say('GKの逆を突いた。隅に突き刺さる。', 'You went the opposite way to the keeper. Buried in the corner.'),
          failureText: Say('狙いすぎてポストに当たり、外へ。', 'You aimed too fine. Off the post and away.'),
        ),
        ScenarioOption(
          label: Say('GKの動きを見て逆に蹴る', 'Wait for the keeper and go the other way'),
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 66,
          outcome: Outcome.goal,
          successText: Say('GKが先に動いた。ゆっくりと逆へ転がした。', 'He went first. You rolled it slowly the other way.'),
          failureText: Say('GKが動かず、弱いキックを止められた。', 'He never moved and saved the weak kick.'),
        ),
        ScenarioOption(
          label: Say('味方に譲る', 'Let someone else take it'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 30,
          outcome: Outcome.play,
          successText: Say('調子の良い味方に譲った。チームは冷静に決めた。', 'You handed it to the man in form. He put it away calmly.'),
          failureText: Say('譲った味方が外し、責任だけが残った。', 'He missed, and all you got out of it was the blame.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-press',
      spot: PitchSpot.opponentGoal,
      situation: Say('相手GKがビルドアップを始める。前線からプレスに行くか。', 'Their keeper is starting the build-up. Press from the front?'),
      options: [
        ScenarioOption(
          label: Say('GKに全力で寄せる', 'Close the keeper down flat out'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.goal,
          successText: Say('GKのパスミスを誘い、無人のゴールへ蹴り込んだ。', 'You forced him into a mistake and rolled it into the empty net.'),
          failureText: Say('簡単にかわされ、背後を大きく空けた。', 'He went past you easily and left a huge gap behind.'),
        ),
        ScenarioOption(
          label: Say('パスコースを切って追い込む', 'Cut off the passing lane and force him wide'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('コースを限定し、相手は苦し紛れに蹴り出した。', 'You limited his options and he hacked it clear in desperation.'),
          failureText: Say('寄せが甘く、楽に前線へ繋がれた。', 'Your press was half-hearted and they played out easily.'),
        ),
        ScenarioOption(
          label: Say('守備ブロックに戻る', 'Drop back into the defensive block'),
          key: AttributeKey.physical,
          detail: Detail.stamina,
          difficulty: 40,
          outcome: Outcome.play,
          successText: Say('無駄走りをせず、守備の形を整えた。', 'You saved your legs and kept the shape.'),
          failureText: Say('戻りが遅れ、中盤との距離が空いた。', 'You were slow getting back and a gap opened up to the midfield.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-lastminute',
      spot: PitchSpot.box,
      situation: Say('コーナーキックがこぼれてきた。詰めれば届く位置にいる。', 'A corner has broken loose. You are close enough to reach it.'),
      options: [
        ScenarioOption(
          label: Say('ボレーで叩く', 'Hit it on the volley'),
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 72,
          outcome: Outcome.goal,
          successText: Say('完璧なボレー。スタジアムが揺れた。', 'A perfect volley. The stadium shook.'),
          failureText: Say('当たり損ないが宇宙へ飛んでいった。', 'You caught it all wrong and it sailed into orbit.'),
        ),
        ScenarioOption(
          label: Say('トラップしてから狙う', 'Take a touch first, then shoot'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 78,
          outcome: Outcome.goal,
          successText: Say('一度収めて冷静に流し込んだ。', 'You took it under control and slotted it home calmly.'),
          failureText: Say('トラップが大きく、寄せられて潰された。', 'Your touch was heavy and you were crowded out.'),
        ),
        ScenarioOption(
          label: Say('ファーの味方へ折り返す', 'Cut it back to the far post'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 56,
          outcome: Outcome.assist,
          successText: Say('ファーへの折り返しを味方が押し込んだ。', 'Your cutback to the far post was turned in.'),
          failureText: Say('折り返しが弱く、クリアされた。', 'Your cutback was weak and it was cleared.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-header',
      spot: PitchSpot.farPost,
      situation: Say('ファーサイドへのクロス。DFと並んで走り込んだ。', 'A cross to the far post. You and a defender are running in together.'),
      options: [
        ScenarioOption(
          label: Say('ヘディングで叩きつける', 'Head it down hard'),
          key: AttributeKey.shooting,
          detail: Detail.heading,
          difficulty: 70,
          outcome: Outcome.goal,
          successText: Say('高い打点から地面に叩きつけた。GKは動けない。', 'You got up high and planted it into the ground. The keeper had no chance.'),
          failureText: Say('当たりが薄く、枠の上へ消えた。', 'You caught it thin and it went over the bar.'),
        ),
        ScenarioOption(
          label: Say('折り返して中央へ', 'Head it back into the middle'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 60,
          outcome: Outcome.assist,
          successText: Say('頭で中央へ折り返し、味方が押し込んだ。', 'You headed it back into the middle and a teammate turned it in.'),
          failureText: Say('折り返しが弱く、GKに収まった。', 'Your header back was weak and the keeper claimed it.'),
        ),
        ScenarioOption(
          label: Say('DFを引き付けてスペースを空ける', 'Pull the defenders away to make space'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 48,
          outcome: Outcome.play,
          successText: Say('2人を引き連れ、空いた場所から味方が飛び込んだ。', 'You took two of them with you and a teammate attacked the space.'),
          failureText: Say('中途半端な動きで、逆に味方の邪魔になった。', 'You went half-heartedly and only got in your teammate\'s way.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-offside',
      spot: PitchSpot.finalThird,
      situation: Say('最終ラインぎりぎりでの駆け引き。出し手が顔を上げた。', 'A duel on the shoulder of the last defender. The passer has his head up.'),
      options: [
        ScenarioOption(
          label: Say('一気に裏へ抜ける', 'Go now and get in behind'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('半歩の駆け引きに勝ち、フリーで前を向いた。', 'You won the half-yard and turned with the ball, free.'),
          failureText: Say('出るのが早く、旗が上がった。', 'You went too early and the flag went up.'),
        ),
        ScenarioOption(
          label: Say('足元で受けにいく', 'Come short to receive it'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 61,
          outcome: Outcome.play,
          successText: Say('下りて受け、味方の押し上げを待った。', 'You dropped in, took it, and waited for support.'),
          failureText: Say('背後から潰され、ボールを失った。', 'You were crowded out from behind and lost it.'),
        ),
        ScenarioOption(
          label: Say('ワンテンポ遅らせて出る', 'Hold your run a beat, then go'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 63,
          outcome: Outcome.play,
          successText: Say('出し手と目が合った。完璧なタイミングで抜け出した。', 'You caught the passer\'s eye. Perfect timing, and you were clear.'),
          failureText: Say('待ちすぎて、コースを消された。', 'You waited too long and the lane was shut.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-hold',
      spot: PitchSpot.edgeOfBox,
      situation: Say('背負って受けた。DFが背中から強く当たってくる。', 'You have received it with your back to goal. A defender is leaning in hard.'),
      options: [
        ScenarioOption(
          label: Say('体を張ってキープ', 'Hold him off and keep it'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('当たりに耐え、味方が上がる時間を作った。', 'You took the contact and bought time for support to arrive.'),
          failureText: Say('力負けし、後ろから刈り取られた。', 'You were outmuscled and robbed from behind.'),
        ),
        ScenarioOption(
          label: Say('反転してシュート', 'Turn and shoot'),
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: Say('当たりをいなして反転、そのまま振り抜いた。', 'You rode the challenge, spun, and let fly.'),
          failureText: Say('反転したが、DFに体を寄せられて打てなかった。', 'You turned, but he got tight and you could not get a shot away.'),
        ),
        ScenarioOption(
          label: Say('ワンタッチで味方に落とす', 'Lay it off first time'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 54,
          outcome: Outcome.assist,
          successText: Say('触っただけの落としが、走り込む味方に完璧に合った。', 'A simple lay-off, weighted perfectly for the runner.'),
          failureText: Say('落とし所が甘く、相手に渡った。', 'Your lay-off was loose and they picked it up.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-rebound',
      spot: PitchSpot.box,
      situation: Say('GKが弾いた。こぼれ球が目の前に転がってくる。', 'The keeper has parried it. The loose ball is rolling in front of you.'),
      options: [
        ScenarioOption(
          label: Say('飛び込んで押し込む', 'Throw yourself at it'),
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 58,
          outcome: Outcome.goal,
          successText: Say('誰よりも早く反応し、ゴールに押し込んだ。', 'You reacted quicker than anyone and bundled it in.'),
          failureText: Say('半歩遅れ、DFに掻き出された。', 'You were half a step late and a defender hacked it away.'),
        ),
        ScenarioOption(
          label: Say('落ち着いて浮かせる', 'Lift it over calmly'),
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 68,
          outcome: Outcome.goal,
          successText: Say('倒れ込むGKの上を、柔らかく越えた。', 'It floated softly over the sprawling keeper.'),
          failureText: Say('浮かせすぎ、クロスバーを叩いた。', 'You lifted it too much and hit the crossbar.'),
        ),
        ScenarioOption(
          label: Say('横の味方に合わせる', 'Square it to a teammate'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 52,
          outcome: Outcome.assist,
          successText: Say('無人のゴール前へ。味方は流し込むだけだった。', 'Across to an empty goal. All he had to do was pass it in.'),
          failureText: Say('横パスが強すぎ、味方が合わせられなかった。', 'Your square ball was too firm and he could not reach it.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-solo',
      spot: PitchSpot.middle,
      situation: Say('中盤で前を向いた。相手は3人、味方が追い越そうとしている。', 'You have turned with the ball in midfield. Three of them ahead, a teammate overlapping.'),
      options: [
        ScenarioOption(
          label: Say('仕掛けて一人で行く', 'Take them on yourself'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 76,
          outcome: Outcome.goal,
          successText: Say('3人を置き去りにして、そのまま流し込んだ。', 'You left all three behind and rolled it in.'),
          failureText: Say('2人目に引っかかり、カウンターを浴びた。', 'The second man caught you and they broke away.'),
        ),
        ScenarioOption(
          label: Say('追い越す味方へ流す', 'Release the overlapping runner'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 58,
          outcome: Outcome.assist,
          successText: Say('完璧なタイミングで流し、味方が沈めた。', 'Perfectly timed, and he buried it.'),
          failureText: Say('タイミングが合わず、オフサイドになった。', 'Your timing was off and he was flagged offside.'),
        ),
        ScenarioOption(
          label: Say('スピードで一気に運ぶ', 'Carry it forward at pace'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.play,
          successText: Say('一気に敵陣深くまで運び、味方を押し上げた。', 'You drove deep into their half and pushed the whole team up.'),
          failureText: Say('運びすぎて囲まれ、奪われた。', 'You carried it too far, got surrounded and lost it.'),
        ),
      ],
    ),
    // ---- 追いかける展開 ----
    Scenario(
      id: 'fw-chase-narrow',
      spot: PitchSpot.edgeOfBox,
      situation: Say('1点を追う終盤。相手は全員が引いた。狭い場所しか空いていない。', 'Late on, a goal down. They are all behind the ball. Only tight spaces left.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('壁の外からミドルを叩く', 'Hit one from outside the wall'),
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 68,
          outcome: Outcome.goal,
          successText: Say('振り抜いた一発が、人の壁を越えて突き刺さった。', 'Your strike flew over the bodies and found the net.'),
          failureText: Say('打点が定まらず、DFの足に当たった。', 'You never got on top of it and it hit a defender\'s leg.'),
        ),
        ScenarioOption(
          label: Say('密集へ強引に持ち込む', 'Force your way into the crowd'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 80,
          outcome: Outcome.goal,
          successText: Say('二人をかわし、そのまま流し込んだ。', 'You beat two and rolled it in.'),
          failureText: Say('三人目に足を出され、転がされた。', 'The third man got a foot in and brought you down.'),
        ),
        ScenarioOption(
          label: Say('いったん外へ預けて作り直す', 'Reset by playing it out wide'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 48,
          outcome: Outcome.play,
          successText: Say('慌てずに外へ。攻撃の形が整い直した。', 'No panic. Out wide, and the shape came back.'),
          failureText: Say('パスが軽く、あっさり跳ね返された。', 'Your pass was limp and it came straight back.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-chase-corner',
      spot: PitchSpot.box,
      situation: Say('1点ビハインドでコーナーキック。GKまで上がってきた。', 'A corner with you a goal down. Even the keeper has come up.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('ニアに飛び込んで合わせる', 'Attack the near post'),
          key: AttributeKey.shooting,
          detail: Detail.heading,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: Say('ニアで一瞬速く触った。コースが変わってゴールへ。', 'You got there a split second early. The flick changed its course and in it went.'),
          failureText: Say('タイミングが合わず、頭上を越えていった。', 'Your timing was off and it went over your head.'),
        ),
        ScenarioOption(
          label: Say('こぼれ球に詰める', 'Attack the rebound'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 66,
          outcome: Outcome.goal,
          successText: Say('弾かれた瞬間に反応していた。押し込んだ。', 'You were moving the instant it was parried. You turned it in.'),
          failureText: Say('一歩遅れ、目の前でクリアされた。', 'You were a step late and it was cleared in front of you.'),
        ),
        ScenarioOption(
          label: Say('マークを引き連れて味方を空ける', 'Take your marker away to free a teammate'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 44,
          outcome: Outcome.play,
          successText: Say('二人を連れて動き、中央にぽっかり空間ができた。', 'You dragged two with you and a hole opened in the middle.'),
          failureText: Say('動きを読まれ、誰も釣れなかった。', 'They read your run and nobody followed.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-chase-press',
      spot: PitchSpot.opponentGoal,
      situation: Say('ロスタイム。相手GKが足元に持っている。前から追うか。', 'Stoppage time. Their keeper has it at his feet. Press him?'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('全力で寄せて蹴らせない', 'Close him down flat out and block the kick'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 68,
          outcome: Outcome.goal,
          successText: Say('寄せ切った足にボールが当たり、そのままゴールへ転がった。', 'The ball hit your outstretched leg and rolled into the goal.'),
          failureText: Say('届かない。頭上を大きく蹴り出された。', 'You did not get there. He lofted it over your head.'),
        ),
        ScenarioOption(
          label: Say('コースを切って外へ誘導する', 'Cut the angle and force him outside'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('中を切って外へ蹴らせた。味方が回収する。', 'You shut the inside and forced him wide. Your teammate collected it.'),
          failureText: Say('角度が甘く、中央へ通された。', 'Your angle was poor and he played it through the middle.'),
        ),
        ScenarioOption(
          label: Say('蹴らせて跳ね返りを詰める', 'Let him kick and attack the second ball'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 62,
          outcome: Outcome.goal,
          successText: Say('GKのキックを跳ね返し、こぼれを押し込んだ。', 'You won the header from his kick and turned in the loose ball.'),
          failureText: Say('跳ね返したが、こぼれは相手に渡った。', 'You won it, but the loose ball fell to them.'),
        ),
      ],
    ),
    // ---- 守り切る展開 ----
    Scenario(
      id: 'fw-hold-corner',
      spot: PitchSpot.cornerFlag,
      situation: Say('1点リードの終盤。相手コーナー付近でボールを持てた。', 'Late on, a goal up. You have the ball near their corner flag.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('隅で体を張って時間を使う', 'Shield it in the corner and run the clock'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('背中で守り、30秒を削り取った。', 'You protected it with your back and ate up thirty seconds.'),
          failureText: Say('寄せられて奪われた。時間を渡してしまった。', 'They closed you down and won it. You gave the time back.'),
        ),
        ScenarioOption(
          label: Say('仕掛けて反則をもらいに行く', 'Invite the challenge and win a foul'),
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('足を出させて倒れた。試合が止まる。', 'He stuck a leg out and you went down. The game stops.'),
          failureText: Say('思い切りが足りず、簡単に触られた。', 'You did not commit to it and he took it off you easily.'),
        ),
        ScenarioOption(
          label: Say('空いた背後へ抜け出す', 'Break into the space behind'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: Say('前がかりの背後は無人だった。走り切って決めた。', 'There was nobody behind their high line. You ran it in and scored.'),
          failureText: Say('追いつかれ、体を寄せられて終わった。', 'They caught you up, got tight, and that was that.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-hold-counter',
      spot: PitchSpot.finalThird,
      situation: Say('1点リードの終盤。前残りしていたところへボールが出た。', 'Late on, a goal up. You stayed forward, and the ball has come to you.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('独走して仕留めに行く', 'Run with it and finish it yourself'),
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 72,
          outcome: Outcome.goal,
          successText: Say('長い距離を運び、最後は冷静に流し込んだ。', 'You carried it a long way and finished calmly.'),
          failureText: Say('息が上がっていた。シュートは力なく転がった。', 'You were out of breath. The shot rolled weakly wide.'),
        ),
        ScenarioOption(
          label: Say('併走する味方へ渡す', 'Give it to the man alongside you'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 56,
          outcome: Outcome.assist,
          successText: Say('見えていた。ノータッチで通り、味方が決めた。', 'You had seen him. It went straight through and he scored.'),
          failureText: Say('出しどころを探しすぎて、戻られた。', 'You looked for the pass too long and they got back.'),
        ),
        ScenarioOption(
          label: Say('深い位置まで運んで時間を使う', 'Carry it deep and use the clock'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 48,
          outcome: Outcome.play,
          successText: Say('無理をせず深くまで運んだ。時計だけが進む。', 'You took no chances and carried it deep. Only the clock moves.'),
          failureText: Say('触り損ねてラインを割った。', 'You miscontrolled it and it went out of play.'),
        ),
      ],
    ),
    Scenario(
      id: 'fw-hold-alone',
      spot: PitchSpot.finalThird,
      situation: Say('守り切りたい終盤。前線は自分ひとり。相手の最終ラインが持ち上がる。', 'Late on, trying to see it out. You are alone up front. Their defender steps forward.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('ひとりで追い回して蓋をする', 'Chase him down on your own'),
          key: AttributeKey.physical,
          detail: Detail.stamina,
          difficulty: 74,
          outcome: Outcome.play,
          successText: Say('走り続け、前を向かせなかった。ベンチが手を叩く。', 'You kept running and never let him turn. The bench applauds.'),
          failureText: Say('足が止まり、易々と持ち上がられた。', 'Your legs went and he strolled forward.'),
        ),
        ScenarioOption(
          label: Say('中央を切って外へ追い出す', 'Shut the middle and force him wide'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 41,
          outcome: Outcome.play,
          successText: Say('中を消して外へ。危険な角度は作らせない。', 'Inside shut, outside open. No dangerous angles for them.'),
          failureText: Say('立ち位置がずれ、中央を通された。', 'You were out of position and he played it through the middle.'),
        ),
        ScenarioOption(
          label: Say('思い切って奪いに行く', 'Go for the ball'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 78,
          outcome: Outcome.goal,
          successText: Say('足を伸ばして奪い、そのまま持ち込んで決めた。', 'You stretched out, won it, carried it on and scored.'),
          failureText: Say('かわされ、一気に背後を突かれた。', 'He went past you and they were straight in behind.'),
          foul: 0.45,
        ),
      ],
    ),
  ];

  static const List<Scenario> midfield = [
    Scenario(
      id: 'mf-build',
      spot: PitchSpot.middle,
      situation: Say('中盤でボールを持った。前線は密集、サイドは空いている。', 'You have the ball in midfield. It is crowded ahead, but the wings are open.'),
      options: [
        ScenarioOption(
          label: Say('縦にスルーパスを通す', 'Thread a through ball'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 79,
          outcome: Outcome.assist,
          successText: Say('密集の間を通す一本。FWが抜け出して決めた。', 'One pass between the bodies. The striker broke clear and scored.'),
          failureText: Say('コースが甘く、インターセプトされた。', 'Your angle was poor and it was intercepted.'),
        ),
        ScenarioOption(
          label: Say('サイドへ大きく展開する', 'Switch it out wide'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 53,
          outcome: Outcome.play,
          successText: Say('逆サイドへ正確な展開。試合が動き出す。', 'An accurate switch to the far side. The game opens up.'),
          failureText: Say('距離が足りず、タッチラインを割った。', 'It fell short and went out of play.'),
        ),
        ScenarioOption(
          label: Say('運んでからラストパス', 'Carry it, then play the final ball'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 53,
          outcome: Outcome.assist,
          successText: Say('自分で運んで相手を引き付け、空いた味方へ最後の一本を出した。', 'You drove at them, drew them in, and found the free man with the final pass.'),
          failureText: Say('運んだところで囲まれ、出しどころを失った。', 'You carried it into trouble and ran out of options.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-shot',
      spot: PitchSpot.edgeOfBox,
      situation: Say('ペナルティエリア手前にこぼれ球。前は空いている。', 'A loose ball just outside the box. There is space ahead of you.'),
      options: [
        ScenarioOption(
          label: Say('ミドルシュートを打つ', 'Shoot from distance'),
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 60,
          outcome: Outcome.goal,
          successText: Say('鋭いミドルがゴール右上に突き刺さった。', 'A crisp strike into the top right corner.'),
          failureText: Say('ミートが甘く、GKの正面に飛んだ。', 'You did not catch it cleanly and it flew straight at the keeper.'),
        ),
        ScenarioOption(
          label: Say('中央へ持ち出してから叩く', 'Carry it inside, then lay it off'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 71,
          outcome: Outcome.assist,
          successText: Say('角度を作ってから横へ。味方が押し込んだ。', 'You made the angle, then slid it square. A teammate turned it in.'),
          failureText: Say('持ち出しが大きく、DFに引っかかった。', 'Your touch was heavy and a defender got in the way.'),
        ),
        ScenarioOption(
          label: Say('無理せず作り直す', 'Reset without forcing it'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 43,
          outcome: Outcome.play,
          successText: Say('後ろに戻して作り直し。危なげない判断。', 'Back and start again. A safe, sensible call.'),
          failureText: Say('バックパスが短く、相手に拾われかけた。', 'Your backpass was short and they nearly got to it.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-press',
      spot: PitchSpot.middle,
      situation: Say('相手のビルドアップ。プレスに行くか、ブロックを作るか。', 'They are building from the back. Press, or set your block?'),
      options: [
        ScenarioOption(
          label: Say('一気に寄せて奪いに行く', 'Press hard and go win it'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 69,
          outcome: Outcome.play,
          successText: Say('寄せ切ってボールを奪取。ショートカウンターへ。', 'You closed him down and won it. Straight into a short counter.'),
          failureText: Say('かわされ、間延びした中盤を使われた。', 'He went past you and used the gap you had left in midfield.'),
          foul: 0.45,
        ),
        ScenarioOption(
          label: Say('パスコースを切って待つ', 'Cut the lane and wait'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 55,
          outcome: Outcome.play,
          successText: Say('コースを消し続け、相手は後ろに戻すしかなかった。', 'You kept shutting the lanes and they had to go backwards.'),
          failureText: Say('中途半端な立ち位置で、間を通された。', 'You were caught in between and they played through you.'),
        ),
        ScenarioOption(
          label: Say('走力で背後をカバーする', 'Use your legs to cover in behind'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 51,
          outcome: Outcome.play,
          successText: Say('背後のスペースを消し切り、決定機を未然に潰した。', 'You shut off the space behind and killed the chance before it existed.'),
          failureText: Say('戻り切れず、危険なスペースを空けた。', 'You did not get back and left dangerous space open.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-freekick',
      spot: PitchSpot.edgeOfBox,
      situation: Say('ゴール正面25mでFKを得た。壁は5枚。', 'A free kick, 25 yards out, central. A five-man wall.'),
      options: [
        ScenarioOption(
          label: Say('壁を越えて直接狙う', 'Go for goal over the wall'),
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 79,
          outcome: Outcome.goal,
          successText: Say('壁を越えて落ちる軌道。GKは一歩も動けなかった。', 'Up over the wall and dipping. The keeper never moved.'),
          failureText: Say('壁に当たった。こぼれ球は相手へ。', 'It hit the wall and they picked up the loose ball.'),
        ),
        ScenarioOption(
          label: Say('ファーへ巻いたボールを入れる', 'Bend one to the far post'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 61,
          outcome: Outcome.assist,
          successText: Say('ファーへの巻いたボールを、味方が頭で合わせた。', 'Your bent ball to the far post was met by a teammate\'s head.'),
          failureText: Say('GKに直接キャッチされた。', 'The keeper claimed it comfortably.'),
        ),
        ScenarioOption(
          label: Say('短くつないで崩す', 'Work it short'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 63,
          outcome: Outcome.assist,
          successText: Say('短く出して壁をずらし、空いた味方へ通した。', 'A short pass pulled the wall across and found the free man.'),
          failureText: Say('短いパスを読まれ、カットされた。', 'They read the short one and cut it out.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-transition',
      spot: PitchSpot.middle,
      situation: Say('相手のカウンター。自分の前にボール保持者、後ろは手薄。', 'They are counter-attacking. The man on the ball is in front of you, little cover behind.'),
      options: [
        ScenarioOption(
          label: Say('体を張って止める', 'Stand him up and win it'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 67,
          outcome: Outcome.play,
          successText: Say('正面から止め切った。相手の勢いを断った。', 'You stopped him square on and killed their momentum.'),
          failureText: Say('吹き飛ばされ、決定機を許した。', 'You were brushed aside and let a clear chance in.'),
        ),
        ScenarioOption(
          label: Say('ファウルで止める', 'Stop him with a foul'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('カードは覚悟の上。戦術的ファウルで流れを切った。', 'A card was the price. A tactical foul, and the attack is dead.'),
          failureText: Say('ファウルが遅れ、アドバンテージで流された。', 'Your foul came too late and the referee played the advantage.'),
        ),
        ScenarioOption(
          label: Say('遅らせて味方の帰陣を待つ', 'Delay him until help arrives'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 49,
          outcome: Outcome.play,
          successText: Say('巧みに遅らせ、味方が戻る時間を作った。', 'You delayed him cleverly and bought time for your teammates to get back.'),
          failureText: Say('簡単に抜かれ、数的不利のまま攻め込まれた。', 'He went past you easily and they attacked with the extra man.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-switch',
      spot: PitchSpot.middleFlank,
      situation: Say('相手が片側に寄っている。逆サイドに味方がフリーで待っている。', 'They have shifted to one side. A teammate is free on the far side.'),
      options: [
        ScenarioOption(
          label: Say('40mのサイドチェンジを通す', 'Hit a 40-yard switch'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 73,
          outcome: Outcome.assist,
          successText: Say('一本で逆サイドへ。フリーの味方が持ち込んで決めた。', 'One pass to the far side. The free man drove in and scored.'),
          failureText: Say('風に流され、タッチラインを割った。', 'The wind took it and it went out of play.'),
        ),
        ScenarioOption(
          label: Say('近くの味方と繋いで運ぶ', 'Work it forward with short passes'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 47,
          outcome: Outcome.play,
          successText: Say('テンポ良く繋ぎ、相手を走らせた。', 'Quick, crisp passes that made them run.'),
          failureText: Say('狭い場所で引っかかり、奪われた。', 'You got caught in a tight space and lost it.'),
        ),
        ScenarioOption(
          label: Say('密集を抜けて折り返す', 'Beat the crowd and cut it back'),
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 55,
          outcome: Outcome.assist,
          successText: Say('密集を細かいタッチで抜け、中へ折り返した。', 'Short touches through the crowd, then a ball back into the middle.'),
          failureText: Say('抜けきれず、密集の中で失った。', 'You could not get out and lost it in the crowd.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-late',
      spot: PitchSpot.betweenLines,
      situation: Say('ボールは自分の足元。前に空きはなく、味方も動き出さない。', 'The ball is at your feet. Nothing ahead, and nobody making a move.'),
      options: [
        ScenarioOption(
          label: Say('ペナルティエリアに飛び込む', 'Make a run into the box'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 67,
          outcome: Outcome.goal,
          successText: Say('走り込んだところに折り返しが来た。同点弾。', 'The cutback found you as you arrived. The equaliser.'),
          failureText: Say('走り込んだが、ボールは来なかった。', 'You made the run, but the ball never came.'),
        ),
        ScenarioOption(
          label: Say('早いクロスを上げる', 'Put an early cross in'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 67,
          outcome: Outcome.assist,
          successText: Say('早いクロスにFWが合わせた。', 'Your early cross was met by the striker.'),
          failureText: Say('クロスは誰にも合わず、流れた。', 'The cross found nobody and ran away.'),
        ),
        ScenarioOption(
          label: Say('外して中へ通す', 'Take him on and play it inside'),
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 49,
          outcome: Outcome.assist,
          successText: Say('一人を外して中へ。動き出した味方に合った。', 'You took one man out and played it inside, right into his stride.'),
          failureText: Say('外しきれず、ボールを引っ掛けられた。', 'You could not get past him and he hooked the ball away.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-halfspace',
      spot: PitchSpot.betweenLines,
      situation: Say('ライン間で前を向いて受けた。中央は密集、外は空いている。', 'You have turned between the lines. Packed in the middle, space out wide.'),
      options: [
        ScenarioOption(
          label: Say('スルーパスを通す', 'Thread a through ball'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 78,
          outcome: Outcome.assist,
          successText: Say('密集の隙間を通した。抜け出した味方が決めた。', 'Through the gap in the crowd. The runner broke clear and scored.'),
          failureText: Say('狙いは見えていたが、体に当たった。', 'You saw the pass, but it hit a body.'),
        ),
        ScenarioOption(
          label: Say('持ち上がって外へ流す', 'Carry it in, then roll it wide'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 59,
          outcome: Outcome.assist,
          successText: Say('中へ運んで引き付け、外の味方へ流した。そのまま決まった。', 'You drew them inside, then rolled it out to the wing. He finished it.'),
          failureText: Say('持ち上がったところで潰された。', 'You were crowded out as you carried it.'),
        ),
        ScenarioOption(
          label: Say('後ろに戻して作り直す', 'Play back and start again'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 47,
          outcome: Outcome.play,
          successText: Say('無理をせず、攻撃をやり直した。', 'No risks. You started the attack again.'),
          failureText: Say('戻したパスが短く、狙われた。', 'Your pass back was short and they went after it.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-recover',
      spot: PitchSpot.middle,
      situation: Say('ボールを失った直後。5秒以内に取り返したい。', 'You have just lost the ball. You want it back within five seconds.'),
      options: [
        ScenarioOption(
          label: Say('即座に潰しに行く', 'Go and win it back at once'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 71,
          outcome: Outcome.play,
          successText: Say('振り向く前に潰し、そのまま攻撃に転じた。', 'You got there before he could turn and went straight on the attack.'),
          failureText: Say('かわされ、前を向かれた。', 'He went past you and turned with the ball.'),
          foul: 0.45,
        ),
        ScenarioOption(
          label: Say('パスコースに立つ', 'Stand in the passing lane'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('出しどころを消し、苦し紛れの縦パスを奪った。', 'You shut his options and won the hopeful pass forward.'),
          failureText: Say('読みが外れ、逆を取られた。', 'You guessed wrong and he went the other way.'),
        ),
        ScenarioOption(
          label: Say('自陣に戻って形を作る', 'Get back and rebuild the shape'),
          key: AttributeKey.physical,
          detail: Detail.stamina,
          difficulty: 49,
          outcome: Outcome.play,
          successText: Say('全力で戻り、守備の枚数を揃えた。', 'You sprinted back and made the numbers up.'),
          failureText: Say('足が止まり、間に合わなかった。', 'Your legs went and you did not get there.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-longshot',
      spot: PitchSpot.edgeOfBox,
      situation: Say('相手のブロックが下がった。ミドルのコースが空いている。', 'Their block has dropped off. There is room to shoot from distance.'),
      options: [
        ScenarioOption(
          label: Say('ミドルシュートを打つ', 'Shoot from distance'),
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 73,
          outcome: Outcome.goal,
          successText: Say('無回転気味の一撃。ゴール左上に突き刺さった。', 'A knuckling strike into the top left corner.'),
          failureText: Say('当たり損ね。ボールは大きく枠を外れた。', 'A poor connection. The ball flew well wide.'),
        ),
        ScenarioOption(
          label: Say('前線に楔を入れる', 'Play it into the striker'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 69,
          outcome: Outcome.assist,
          successText: Say('足元に鋭く入り、そこから流れるように決まった。', 'A sharp pass into his feet, and it flowed from there into a goal.'),
          failureText: Say('強すぎた。相手に当たって跳ね返った。', 'Too firm. It bounced off him and away.'),
        ),
        ScenarioOption(
          label: Say('運んでからスルーパス', 'Carry it, then thread one through'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 53,
          outcome: Outcome.assist,
          successText: Say('下がったブロックの前を運び、間へスルーパスを通した。', 'You carried it in front of the block and threaded it between the lines.'),
          failureText: Say('運んだところで寄せられ、パスがずれた。', 'You were closed down as you carried it and the pass went astray.'),
        ),
      ],
    ),
    Scenario(
      id: 'mf-tempo',
      spot: PitchSpot.ownThird,
      situation: Say('押し込まれている時間帯。味方の足が止まってきた。', 'You are under the cosh. Your teammates\' legs are going.'),
      options: [
        ScenarioOption(
          label: Say('ボールを持って時間を作る', 'Keep the ball and buy time'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 64,
          outcome: Outcome.play,
          successText: Say('一人で相手を2人剥がし、チームが息を吹き返した。', 'You beat two men on your own and the team came back to life.'),
          failureText: Say('囲まれ、危険な位置で奪われた。', 'You were surrounded and lost it in a dangerous area.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('縦に速く展開して逃げる', 'Go long and quickly to relieve it'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('一本で押し返し、相手を自陣へ戻した。', 'One pass pushed them back into their own half.'),
          failureText: Say('精度を欠き、すぐに返された。', 'You lacked the accuracy and it came straight back.'),
        ),
        ScenarioOption(
          label: Say('相手のキーマンを消す', 'Take their key man out of the game'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 54,
          outcome: Outcome.play,
          successText: Say('起点を消し続け、波が止まった。', 'You kept cutting off their source and the wave stopped.'),
          failureText: Say('振り切られ、決定機を作られた。', 'He shook you off and created a clear chance.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'mf-corner',
      spot: PitchSpot.cornerFlag,
      situation: Say('自分がコーナーキックを蹴る。中の枚数は五分。', 'You are taking the corner. Even numbers in the box.'),
      options: [
        ScenarioOption(
          label: Say('ニアに速いボール', 'A quick ball to the near post'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 70,
          outcome: Outcome.assist,
          successText: Say('速い球にニアで合わせた。そらしたボールがネットへ。', 'He met your quick ball at the near post. The flick found the net.'),
          failureText: Say('速すぎて誰も触れず、そのまま流れた。', 'It was too quick. Nobody touched it and it ran away.'),
        ),
        ScenarioOption(
          label: Say('ファーへふわりと上げる', 'A floated ball to the far post'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 63,
          outcome: Outcome.assist,
          successText: Say('大外で待つ味方の頭にぴたりと合った。', 'It dropped right onto the head of the man at the back post.'),
          failureText: Say('滞空時間が長く、GKに掴まれた。', 'It hung in the air too long and the keeper claimed it.'),
        ),
        ScenarioOption(
          label: Say('ショートコーナーで崩す', 'Work a short corner'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 56,
          outcome: Outcome.play,
          successText: Say('短くつないで角度を変え、崩しの形を作った。', 'A short pass changed the angle and opened them up.'),
          failureText: Say('狭い場所で奪われ、カウンターを受けた。', 'You lost it in a tight space and they broke away.'),
        ),
      ],
    ),
    // ---- 追いかける展開 ----
    Scenario(
      id: 'mid-chase-jam',
      spot: PitchSpot.betweenLines,
      situation: Say('1点を追う終盤。ボールは持てるが、前が渋滞している。', 'Late on, a goal down. You can keep the ball, but it is jammed ahead.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('一気に縦へ通す', 'Go straight down the middle'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 75,
          outcome: Outcome.assist,
          successText: Say('リスクを承知の縦一本。味方が抜け出して決めた。', 'A risky ball forward. The runner broke clear and scored.'),
          failureText: Say('読まれていた。カットされてカウンターを浴びる。', 'They had read it. Cut out, and they broke away.'),
        ),
        ScenarioOption(
          label: Say('運んで最後の一本を通す', 'Carry it and play the final ball'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 73,
          outcome: Outcome.assist,
          successText: Say('渋滞の脇を運び、最後の一本を通した。', 'You carried it round the jam and found the final pass.'),
          failureText: Say('運んだが、出す前に寄せられた。', 'You carried it, but they got to you before you could release it.'),
        ),
        ScenarioOption(
          label: Say('思い切ってミドルを狙う', 'Have a go from distance'),
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 79,
          outcome: Outcome.goal,
          successText: Say('前が空いていた。振り抜いた一発がゴールへ。', 'There was space ahead. Your strike found the net.'),
          failureText: Say('当たりが薄く、GKの正面へ飛んだ。', 'You caught it thin and it flew straight at the keeper.'),
        ),
      ],
    ),
    Scenario(
      id: 'mid-chase-second',
      spot: PitchSpot.edgeOfBox,
      situation: Say('押し込んでいる。こぼれ球がペナルティエリアの外へ落ちてくる。', 'You are on top. A loose ball drops just outside the box.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('落ち際を叩く', 'Hit it on the drop'),
          key: AttributeKey.shooting,
          detail: Detail.shotPower,
          difficulty: 77,
          outcome: Outcome.goal,
          successText: Say('ワンバウンドを叩いた。伸びたボールがネットを揺らす。', 'You met it on the bounce. The ball dipped and rattled the net.'),
          failureText: Say('ミートせず、大きく上へ外した。', 'You did not catch it cleanly and dragged it high.'),
        ),
        ScenarioOption(
          label: Say('ワンタッチで中へ折り返す', 'Flick it back into the middle first time'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 66,
          outcome: Outcome.assist,
          successText: Say('触っただけのボールが、走り込む味方にぴたりと合った。', 'A single touch landed perfectly in the runner\'s path.'),
          failureText: Say('力が入りすぎ、誰にも合わなかった。', 'You put too much into it and it found nobody.'),
        ),
        ScenarioOption(
          label: Say('収めてから中へ通す', 'Take a touch, then play it in'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 51,
          outcome: Outcome.assist,
          successText: Say('こぼれ球をぴたりと収め、中の味方へ通した。', 'You killed the loose ball dead and played it into the middle.'),
          failureText: Say('収めるのに手間取り、寄せられた。', 'You took too long settling it and were closed down.'),
        ),
      ],
    ),
    Scenario(
      id: 'mid-chase-high',
      spot: PitchSpot.finalThird,
      situation: Say('時間が無い。ラインを上げて前から奪いに行く指示が出た。', 'Time is short. The order is to push up and win it high.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('前で潰しに行く', 'Go and win it high'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 71,
          outcome: Outcome.play,
          successText: Say('出どころを読んで奪った。一気に押し込む。', 'You read where it was going and took it. Straight on top of them.'),
          failureText: Say('外され、背後に広大な空間を残した。', 'You were beaten and left a huge space behind you.'),
          foul: 0.45,
        ),
        ScenarioOption(
          label: Say('奪って運び、ラストパス', 'Win it, carry it, then the final pass'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 71,
          outcome: Outcome.assist,
          successText: Say('奪った勢いのまま運び、並走した味方へ出した。', 'You carried it on the momentum of the tackle and found the man alongside.'),
          failureText: Say('運んだが追いつかれ、出しどころを失った。', 'You carried it, got caught, and ran out of options.'),
        ),
        ScenarioOption(
          label: Say('縦パスを引っ掛けてそのまま', 'Stick a leg in on the forward pass'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 81,
          outcome: Outcome.goal,
          successText: Say('足に当てて奪い、そのまま持ち込んで決めた。', 'You got a foot to it, won it, carried it on and scored.'),
          failureText: Say('足だけが出て、簡単に外された。', 'Only your leg went and he beat you easily.'),
        ),
      ],
    ),
    // ---- 守り切る展開 ----
    Scenario(
      id: 'mid-hold-keep',
      spot: PitchSpot.middle,
      situation: Say('1点リードの終盤。まずは安全にボールを持っておきたい。', 'Late on, a goal up. First of all you want to keep it safe.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('後ろに戻して回す', 'Play back and recycle it'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 41,
          outcome: Outcome.play,
          successText: Say('無理をせず後ろへ。相手を走らせて時間を使った。', 'No risks, back it goes. You made them run and used the clock.'),
          failureText: Say('弱い戻しを狙われ、肝を冷やした。', 'They pounced on your weak pass back and gave you a scare.'),
        ),
        ScenarioOption(
          label: Say('背負ってキープする', 'Hold it up with your back to goal'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 59,
          outcome: Outcome.play,
          successText: Say('体を入れて渡さない。相手が焦れてファウルした。', 'Body in, and he cannot get it. He got frustrated and fouled you.'),
          failureText: Say('押し負けて、危ない位置で失った。', 'You were outmuscled and lost it in a bad area.'),
        ),
        ScenarioOption(
          label: Say('空いた背後へ一本通す', 'Play one into the space behind'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 77,
          outcome: Outcome.assist,
          successText: Say('前がかりの背後は空いていた。通って試合が決まった。', 'There was space behind their high line. It found him and settled the game.'),
          failureText: Say('弱いボールになり、あっさり回収された。', 'Your pass was weak and they gathered it easily.'),
        ),
      ],
    ),
    Scenario(
      id: 'mid-hold-block',
      spot: PitchSpot.middle,
      situation: Say('相手が前がかりになってきた。中央を締めろと指示が飛ぶ。', 'They are committing men forward. The call is to shut the middle.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('二度追いして潰す', 'Chase him down twice'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 65,
          outcome: Outcome.play,
          successText: Say('一度かわされてから追い直し、奪い返した。', 'He beat you once, you went again, and you won it back.'),
          failureText: Say('二度目も届かず、前を向かれた。', 'You did not get there the second time either and he turned.'),
          foul: 0.45,
        ),
        ScenarioOption(
          label: Say('位置を取って通させない', 'Take up the position and let nothing through'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 51,
          outcome: Outcome.play,
          successText: Say('立つべき場所に立ち続けた。中央は完全に消えている。', 'You stood where you had to stand. The middle is completely shut.'),
          failureText: Say('一瞬の緩みを突かれ、間で受けられた。', 'You switched off for a second and they received between the lines.'),
        ),
        ScenarioOption(
          label: Say('奪ってカウンターの起点になる', 'Win it and start the counter'),
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 73,
          outcome: Outcome.assist,
          successText: Say('奪った瞬間に前を見ていた。そのまま試合を決めた。', 'You were looking forward the instant you won it. That settled the game.'),
          failureText: Say('顔が上がらず、時間だけを失った。', 'You never got your head up and only lost time.'),
        ),
      ],
    ),
    Scenario(
      id: 'mid-hold-clock',
      spot: PitchSpot.finalFlank,
      situation: Say('ロスタイム。相手陣の深い位置でボールを持っている。', 'Stoppage time. You have the ball deep in their half.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('体を入れて反則をもらう', 'Get your body in and win a foul'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 43,
          outcome: Outcome.play,
          successText: Say('先に体を入れた。相手が倒し、試合が止まる。', 'You got there first. He pulled you down and the game stops.'),
          failureText: Say('入り方が甘く、逆に奪われた。', 'Your body position was poor and you lost it instead.'),
        ),
        ScenarioOption(
          label: Say('コーナー付近まで運ぶ', 'Carry it to the corner flag'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 65,
          outcome: Outcome.play,
          successText: Say('隅まで運んで置いた。もう時間は残っていない。', 'You took it to the corner and parked it. There is no time left.'),
          failureText: Say('運ぶ途中で引っ掛けられた。', 'You were tripped on the way.'),
        ),
        ScenarioOption(
          label: Say('そのまま持ち込んで打つ', 'Carry on and shoot'),
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 81,
          outcome: Outcome.goal,
          successText: Say('誰も来なかった。最後の1本がそのまま決勝点になった。', 'Nobody came to meet you. The last shot of the game won it.'),
          failureText: Say('狙いすぎた。GKに読まれていた。', 'You aimed too fine and the keeper had read it.'),
        ),
      ],
    ),
    Scenario(
      id: 'mid-hold-stop',
      spot: PitchSpot.middle,
      situation: Say('1点リードの終盤。中盤で引っ掛けられ、相手が前を向いた。', 'Late on, a goal up. You have been dispossessed in midfield and he has turned.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('後ろから引っ掛けて止める', 'Grab him from behind to stop it'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 33,
          outcome: Outcome.play,
          foul: 1,
          preventsGoal: true,
          successText: Say('前を向かせなかった。警告と引き換えに、失点を防いだ。', 'You stopped him turning. A booking for a goal, and worth it.'),
          failureText: Say('止めきれず、警告だけを受けた。', 'You did not stop him, and all you got was the card.'),
        ),
        ScenarioOption(
          label: Say('正面から奪い返す', 'Win it back square on'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 51,
          outcome: Outcome.play,
          foul: 0.4,
          successText: Say('足を伸ばして奪い返した。歓声が上がる。', 'You stretched out and won it back. The crowd roars.'),
          failureText: Say('足だけが出た。かわされる。', 'Only your leg went in. He beat you.'),
        ),
        ScenarioOption(
          label: Say('下がって陣形を整える', 'Drop off and get the shape back'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 66,
          outcome: Outcome.play,
          successText: Say('引いて構え直した。無理はしない。', 'You dropped off and reset. No risks.'),
          failureText: Say('下がりすぎて、外から放り込まれた。', 'You dropped too deep and they put crosses in from wide.'),
        ),
      ],
    ),
  ];

  static const List<Scenario> defence = [
    Scenario(
      id: 'df-duel',
      spot: PitchSpot.ownFlank,
      situation: Say('快足のウイングと1対1。背後にはスペースがある。', 'One on one with a quick winger. There is space behind you.'),
      options: [
        ScenarioOption(
          label: Say('飛び込んで奪いに行く', 'Dive in and win it'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('足を伸ばして完璧なタックル。ボールだけを奪った。', 'You stretched out for a perfect tackle. All ball.'),
          failureText: Say('簡単にかわされ、決定機を作られた。', 'He went past you easily and created a clear chance.'),
          foul: 0.45,
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('間合いを保って遅らせる', 'Keep your distance and delay him'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 55,
          outcome: Outcome.play,
          successText: Say('距離を保って遅らせ、味方の帰陣を待った。', 'You held your distance, delayed him, and waited for cover.'),
          failureText: Say('下がりすぎてシュートを許した。', 'You dropped off too far and let him shoot.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('体を当てて外へ追い出す', 'Put your body in and force him out of play'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('体を当ててタッチラインの外へ追い出した。', 'You leaned in and forced him out over the touchline.'),
          failureText: Say('倒してしまい、危険な位置でFKを与えた。', 'You brought him down and gave away a free kick in a dangerous spot.'),
          foul: 0.45,
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'df-cross',
      spot: PitchSpot.ownBox,
      situation: Say('相手のクロスがゴール前へ。中には長身のFWがいる。', 'Their cross is coming into the box. There is a tall striker in there.'),
      options: [
        ScenarioOption(
          label: Say('競り勝ってクリアする', 'Win the header and clear it'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 56,
          outcome: Outcome.play,
          successText: Say('高い打点で跳ね返し、危険を完全に排除した。', 'You got up high, headed it clear and killed the danger completely.'),
          failureText: Say('競り負け、決定的なヘディングを許した。', 'You lost the header and let in a header on goal.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('コースに入ってブロック', 'Get in the line and block it'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('体を投げ出してシュートをブロックした。こぼれ球に人が集まる。', 'You threw yourself in the way and blocked the shot. Bodies pile in on the rebound.'),
          failureText: Say('一歩遅く、コースを空けてしまった。', 'You were a step late and left the lane open.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('前に出てインターセプト', 'Step up and intercept'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('読み切って前で断ち切り、そのまま攻撃に転じた。', 'You read it, cut it out in front, and went straight on the attack.'),
          failureText: Say('飛び出しが空振りし、背後を使われた。', 'You stepped out and missed it, and they used the space behind.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
      ],
    ),
    Scenario(
      id: 'df-buildup',
      spot: PitchSpot.ownEdge,
      situation: Say('最終ラインでボールを持つ。相手FWがプレスに来る。', 'You have the ball on the last line. A striker is pressing.'),
      options: [
        ScenarioOption(
          label: Say('縦に長いフィードを蹴る', 'Hit a long ball forward'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 66,
          outcome: Outcome.assist,
          successText: Say('一本のフィードで前線へ。そのまま得点に繋がった。', 'One long ball found the front. It led straight to a goal.'),
          failureText: Say('精度を欠き、簡単に相手ボールになった。', 'You lacked the accuracy and gave it away easily.'),
        ),
        ScenarioOption(
          label: Say('運んでからパスを出す', 'Carry it, then pass'),
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('数歩持ち上がって相手を外し、確実に繋いだ。', 'A few yards forward took him out of it, and the pass found its man.'),
          failureText: Say('奪われて、自陣で決定機を与えた。', 'You were robbed and gave away a clear chance in your own half.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('安全に大きく蹴り出す', 'Clear it long and safe'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 38,
          outcome: Outcome.play,
          successText: Say('無理をせずクリア。まずは危険を消した。', 'No risks. Cleared. The danger is gone for now.'),
          failureText: Say('ミスキックになり、スローインを与えた。', 'You miskicked it and gave away a throw-in.'),
        ),
      ],
    ),
    Scenario(
      id: 'df-setpiece',
      spot: PitchSpot.box,
      situation: Say('味方のコーナーキック。自分もゴール前に上がっている。', 'Your corner. You have gone up into the box.'),
      options: [
        ScenarioOption(
          label: Say('ニアに飛び込んでヘディング', 'Attack the near post and head it'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 58,
          outcome: Outcome.goal,
          successText: Say('ニアで競り勝ち、頭で叩き込んだ。DFの得点。', 'You won it at the near post and buried the header. A goal for a defender.'),
          failureText: Say('マークを外せず、触れなかった。', 'You could not shake your marker and never got near it.'),
        ),
        ScenarioOption(
          label: Say('ファーでこぼれ球を待つ', 'Wait at the back post for the loose ball'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 78,
          outcome: Outcome.assist,
          successText: Say('こぼれ球を折り返し、味方が押し込んだ。', 'You turned the loose ball back and a teammate bundled it in.'),
          failureText: Say('ボールは来ず、カウンターの戻りが遅れた。', 'It never came, and you were slow getting back for the counter.'),
        ),
        ScenarioOption(
          label: Say('上がらずリスク管理する', 'Stay back and manage the risk'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 40,
          outcome: Outcome.play,
          successText: Say('残っていたおかげでカウンターを未然に防いだ。', 'Staying back paid off. You snuffed out the counter before it started.'),
          failureText: Say('一人残ったが、それでも背後を突かれた。', 'You stayed back on your own, and they still got in behind.'),
        ),
      ],
    ),
    Scenario(
      id: 'df-offside',
      spot: PitchSpot.ownThird,
      situation: Say('相手FWが裏を狙って動き出した。ラインの判断を任されている。', 'A striker is making a run in behind. The line is your call.'),
      options: [
        ScenarioOption(
          label: Say('ラインを上げてオフサイドを取る', 'Push the line up and catch him offside'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 78,
          outcome: Outcome.play,
          successText: Say('完璧なラインコントロール。旗が上がった。', 'Perfect line. The flag went up.'),
          failureText: Say('ラインが揃わず、1人が残して裏を取られた。', 'Your line was not level, one man held it, and they got in behind.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('走り合いで潰す', 'Race him for it'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.play,
          successText: Say('走り負けせず、シュートコースを消した。', 'You matched him and shut off the shooting angle.'),
          failureText: Say('スピードで置き去りにされた。', 'He left you for dead with his pace.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('ラインを下げて守る', 'Drop the line and defend'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 36,
          outcome: Outcome.play,
          successText: Say('無理をせず下がって、ゴール前を固めた。相手はまだ持っている。', 'No risks. You dropped off and packed the box. He still has the ball, though.'),
          failureText: Say('下がりすぎて、ミドルシュートを打たれた。', 'You dropped too deep and let him shoot from distance.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
      ],
    ),
    Scenario(
      id: 'df-goalline',
      spot: PitchSpot.ownGoalLine,
      situation: Say('GKがかわされた。無人のゴールに向かってシュートが飛んでくる。', 'The keeper has been beaten. The shot is heading for an empty net.'),
      options: [
        ScenarioOption(
          label: Say('ゴールライン上でクリア', 'Clear it off the line'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 78,
          outcome: Outcome.play,
          successText: Say('ライン上で掻き出した。歓声が上がる。', 'You hooked it off the line. The crowd roars.'),
          failureText: Say('間に合わず、ボールはゴールへ向かった。', 'You did not get there and the ball went in.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('スライディングでコースを消す', 'Slide in and block the lane'),
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 66,
          outcome: Outcome.play,
          successText: Say('滑り込んでブロック。大きなファインプレー。', 'You slid in and blocked it. A huge piece of defending.'),
          failureText: Say('滑ったが届かなかった。', 'You slid in and never got there.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('GKの位置に入って構える', 'Take the keeper\'s place on the line'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 42,
          outcome: Outcome.play,
          successText: Say('体を大きく見せて、シュートを自分に当てさせた。こぼれはまだゴール前。', 'You made yourself big and the shot hit you. The loose ball is still in the box.'),
          failureText: Say('構えたが、股の間を狙われた。', 'You set yourself, but he went through your legs.'),
          exposure: Exposure.chance,
          lingering: true,
        ),
      ],
    ),
    Scenario(
      id: 'df-overlap',
      spot: PitchSpot.finalFlank,
      situation: Say('攻撃の流れで自分がサイドを駆け上がった。前にはスペース。', 'You have surged up the wing in open play. There is space ahead.'),
      options: [
        ScenarioOption(
          label: Say('深くえぐってクロス', 'Get to the byline and cross'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 62,
          outcome: Outcome.assist,
          successText: Say('ライン際までえぐったクロスを、FWが押し込んだ。', 'You got right to the byline and the striker turned your cross in.'),
          failureText: Say('追いつかれ、クロスは当たってしまった。', 'They caught you up and the cross was blocked.'),
        ),
        ScenarioOption(
          label: Say('中に切れ込んでシュート', 'Cut inside and shoot'),
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 76,
          outcome: Outcome.goal,
          successText: Say('切れ込んで放ったシュートが決まった。DFらしからぬ一撃。', 'You cut inside and scored. Not what you expect from a defender.'),
          failureText: Say('シュートは大きく外れ、戻る距離だけが残った。', 'The shot flew well wide, and now you have the run back.'),
        ),
        ScenarioOption(
          label: Say('早めに味方へ預ける', 'Give it early to a teammate'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 44,
          outcome: Outcome.play,
          successText: Say('無理をせず預け、自分は守備位置へ戻った。', 'No risks. You gave it and got back into position.'),
          failureText: Say('預けたパスが弱く、相手に拾われた。', 'Your pass was weak and they picked it up.'),
        ),
      ],
    ),
    Scenario(
      id: 'df-transition',
      spot: PitchSpot.ownThird,
      situation: Say('数的不利のカウンター。自分ひとりで2人を見ている。', 'A counter with you outnumbered. You are watching two of them on your own.'),
      options: [
        ScenarioOption(
          label: Say('ボール保持者に寄せて奪う', 'Close the man on the ball and win it'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 74,
          outcome: Outcome.play,
          successText: Say('思い切って足を伸ばし、ボールだけを突いた。', 'You committed, stretched out, and took the ball cleanly.'),
          failureText: Say('かわされ、2対0になった。', 'He beat you, and now it is two on none.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('遅らせて味方の戻りを待つ', 'Delay them until help arrives'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('下がりながら時間を作り、味方が戻ってきた。', 'You dropped off, bought time, and your teammates got back.'),
          failureText: Say('下がりすぎて、シュートコースを与えた。', 'You dropped too deep and gave him the shooting lane.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('ファウルで止める', 'Stop him with a foul'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 55,
          outcome: Outcome.play,
          successText: Say('カードは出たが、決定的な場面を消した。', 'The card came, but you killed a clear chance.'),
          failureText: Say('倒しきれず、そのまま持ち運ばれた。', 'You did not bring him down and he carried on.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'df-longball',
      spot: PitchSpot.middle,
      situation: Say('前線へ長いボール。相手FWと並んで落下点に入る。', 'A long ball forward. You are under it alongside their striker.'),
      options: [
        ScenarioOption(
          label: Say('ヘディングで跳ね返す', 'Head it clear'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 61,
          outcome: Outcome.play,
          successText: Say('高い打点で叩き、はるか前方へ跳ね返した。', 'You got up high and sent it a long way back.'),
          failureText: Say('競り負け、背後に流された。', 'You lost the header and it was flicked in behind you.'),
        ),
        ScenarioOption(
          label: Say('胸で落として味方につなぐ', 'Cushion it on your chest to a teammate'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 62,
          outcome: Outcome.play,
          successText: Say('柔らかく落とし、そこから組み立てが始まった。', 'A soft lay-off, and the move began from there.'),
          failureText: Say('落とし所がずれ、拾われた。', 'Your lay-off was off and they picked it up.'),
        ),
        ScenarioOption(
          label: Say('体を入れて先に触る', 'Get your body in and touch it first'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 56,
          outcome: Outcome.play,
          successText: Say('先に体を入れ、相手を背負ったまま処理した。', 'You got in front of him and dealt with it with him on your back.'),
          failureText: Say('入れ替わられ、突破を許した。', 'He got in front of you and broke through.'),
        ),
      ],
    ),
    Scenario(
      id: 'df-star',
      spot: PitchSpot.ownEdge,
      situation: Say('相手のエースに付く。背番号10が下がって受けたがっている。', 'You are marking their best player. The number 10 wants to drop in and receive.'),
      options: [
        ScenarioOption(
          label: Say('どこまでも付いていく', 'Follow him everywhere'),
          // **走って付いていく手は、立ち位置ではなく脚で決まる。**
          // 「距離を取ってスペースを埋める」と同じマークで判定していたので、
          // 難しいだけの手になっていた。
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('前を向かせず、ボールを引き出す前に潰した。', 'You never let him turn, and killed it before he got the ball.'),
          failureText: Say('空けた背後を、別の選手に使われた。', 'Another player used the space you had left.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('受け渡してコースを消す', 'Hand him over and shut the lane'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 66,
          outcome: Outcome.play,
          successText: Say('味方に受け渡し、縦のパスコースを消し切った。', 'You handed him over and shut the forward pass completely.'),
          failureText: Say('受け渡しが曖昧になり、間で受けられた。', 'The hand-over was vague and he received between the lines.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('距離を取ってスペースを埋める', 'Keep your distance and fill the space'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 40,
          outcome: Outcome.play,
          successText: Say('危険な場所を先に埋め、何もさせなかった。', 'You filled the dangerous area first and gave him nothing.'),
          failureText: Say('自由に持たれ、決定的なパスを通された。', 'He had time on the ball and found the killer pass.'),
          exposure: Exposure.chance,
          lingering: true,
        ),
      ],
    ),
    Scenario(
      id: 'df-scramble',
      spot: PitchSpot.ownGoalLine,
      situation: Say('ゴール前の混戦。ボールがどこにあるか分からない。', 'Bodies everywhere in the box. Nobody knows where the ball is.'),
      options: [
        ScenarioOption(
          label: Say('思い切りクリアする', 'Just get it clear'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('当てるだけでいい。大きく蹴り出した。', 'Contact is enough. You hammered it clear.'),
          failureText: Say('空振り。ボールは足元を抜けていった。', 'You swung and missed. The ball went past your foot.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('足を伸ばしてつつく', 'Stretch out a leg and poke it'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 68,
          outcome: Outcome.play,
          successText: Say('シュートの瞬間に爪先が届き、コースを変えた。', 'Your toe got there as he shot and took it off line.'),
          failureText: Say('足に当たらず、フリーで打たれた。', 'You never touched it and he had a free shot.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('GKに預ける', 'Give it to the keeper'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('落ち着いてGKへ。危険な時間が終わった。', 'Calmly back to the keeper. The dangerous spell is over.'),
          failureText: Say('弱いバックパスを狙われた。', 'They pounced on your weak pass back.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'df-penaltybox',
      spot: PitchSpot.ownBox,
      situation: Say('PA内で背後を取られた。足を出せばPKになる。', 'He has got in behind you inside the box. A leg in means a penalty.'),
      options: [
        ScenarioOption(
          label: Say('体を寄せて自由を奪う', 'Get tight and take his options away'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 70,
          outcome: Outcome.play,
          successText: Say('触れずに寄せ切り、苦し紛れのシュートに終わらせた。', 'You stayed tight without touching him, and he snatched at the shot.'),
          failureText: Say('寄せ切れず、狙い澄まされた。', 'You did not get tight enough and he picked his spot.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('足を出して止める', 'Put a leg in and stop it'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 77,
          outcome: Outcome.play,
          successText: Say('完璧なタイミング。ボールだけを大きく弾いた。', 'Perfect timing. All ball, cleared a long way.'),
          failureText: Say('足に掛かった。主審がスポットを指した。', 'You caught his leg. The referee pointed to the spot.'),
          exposure: Exposure.penalty,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('コースだけ消して見送る', 'Block the lane and let it go'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 57,
          outcome: Outcome.play,
          successText: Say('シュートコースに入り、体に当てて防いだ。', 'You got in the line of the shot and it hit you.'),
          failureText: Say('中途半端な位置取りで、股の間を狙われた。', 'You were caught in between and he went through your legs.'),
          exposure: Exposure.chance,
          lingering: true,
        ),
      ],
    ),
    // ---- 追いかける展開 ----
    Scenario(
      id: 'def-chase-up',
      spot: PitchSpot.middle,
      situation: Say('1点を追う終盤。センターバックも前に出ろと言われた。', 'Late on, a goal down. Even the centre-backs have been told to go up.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('セットプレーで前線に上がる', 'Go up for the set piece'),
          key: AttributeKey.shooting,
          detail: Detail.heading,
          difficulty: 78,
          outcome: Outcome.goal,
          successText: Say('高さで完全に勝った。叩きつけたヘディングがゴールへ。', 'You won it in the air comfortably and powered the header goalwards.'),
          failureText: Say('競り合いの的を絞られていた。跳ね返された。', 'They had you covered in the air and it was headed clear.'),
        ),
        ScenarioOption(
          label: Say('最終ラインから縦に付ける', 'Play it forward from the back'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 62,
          outcome: Outcome.assist,
          successText: Say('一本で前線へ。そのまま形になり、点が入った。', 'One pass into the front. It stuck, and the goal came.'),
          failureText: Say('距離が合わず、味方の足には届かなかった。', 'The weight was wrong and it never reached him.'),
        ),
        ScenarioOption(
          label: Say('残ってリスクを管理する', 'Stay back and manage the risk'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 42,
          outcome: Outcome.play,
          successText: Say('一人だけ残った判断が効いた。カウンターの芽を摘む。', 'Your call to be the one who stayed back paid off. The counter died early.'),
          failureText: Say('位置取りを誤り、危ない場面を作った。', 'You got your position wrong and let a dangerous moment happen.'),
        ),
      ],
    ),
    Scenario(
      id: 'def-chase-overlap',
      spot: PitchSpot.finalFlank,
      situation: Say('サイドで数的優位。上がっていいと言われている。', 'You have the extra man out wide. You have been told you can go.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('追い越してクロスを上げる', 'Overlap and cross'),
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 66,
          outcome: Outcome.assist,
          successText: Say('深い位置から折り返した。味方が合わせて決めた。', 'You cut it back from deep and a teammate finished it.'),
          failureText: Say('ボールが流れ、逆サイドまで抜けていった。', 'It ran away from everyone and out on the far side.'),
        ),
        ScenarioOption(
          label: Say('中へ持ち込んで打つ', 'Carry it inside and shoot'),
          key: AttributeKey.shooting,
          detail: Detail.shotPower,
          difficulty: 78,
          outcome: Outcome.goal,
          successText: Say('誰も出てこなかった。強烈な一撃が突き刺さる。', 'Nobody came out to meet you. A fierce strike found the net.'),
          failureText: Say('無理な体勢で、力なく枠を外れた。', 'You were off balance and it dribbled wide.'),
        ),
        ScenarioOption(
          label: Say('味方に預けて自陣へ戻る', 'Give it to a teammate and get back'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 40,
          outcome: Outcome.play,
          successText: Say('確実に預けて素早く戻った。穴は空いていない。', 'You gave it safely and got back quickly. No gaps.'),
          failureText: Say('パスがずれ、上がった背後を突かれかけた。', 'Your pass was off and they nearly used the space you had left.'),
        ),
      ],
    ),
    Scenario(
      id: 'def-chase-line',
      spot: PitchSpot.middle,
      situation: Say('ラインを高く保って押し込む。裏のリスクは承知の上。', 'Hold the line high and squeeze them. You know the risk behind.'),
      tempo: ScenarioTempo.chase,
      options: [
        ScenarioOption(
          label: Say('高い位置で潰しに行く', 'Go and win it high'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('出る勇気が実った。相手陣で奪い返す。', 'Your courage paid off. You won it back in their half.'),
          failureText: Say('空振り。背後は無人だった。', 'You swung and missed. There was nobody behind you.'),
        ),
        ScenarioOption(
          label: Say('背後を消しながら前に出る', 'Step up while covering behind'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.play,
          successText: Say('足の速さで両方をこなした。リスクを消して押し上げる。', 'You had the pace to do both. Risk gone, and the team pushed up.'),
          failureText: Say('中途半端になり、どちらも間に合わなかった。', 'You were caught in between and did neither in time.'),
        ),
        ScenarioOption(
          label: Say('楔を跳ね返して前へ送る', 'Head the forward pass away and send it on'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('当たり負けせずに跳ね返し、攻撃を続けさせた。', 'You stood up to the contact, headed it away, and kept the attack going.'),
          failureText: Say('入れ替わられ、一気に運ばれた。', 'He got in front of you and was away.'),
        ),
      ],
    ),
    // ---- 守り切る展開 ----
    Scenario(
      id: 'def-hold-box',
      spot: PitchSpot.ownBox,
      situation: Say('1点リード。ゴール前に人が集まる。またクロスが上がる。', 'A goal up. The box is full. Another cross is coming in.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('高さで跳ね返す', 'Win it in the air'),
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('一番高い位置で触った。危なげなくクリア。', 'You got there at the highest point. Cleared comfortably.'),
          failureText: Say('競り負けて、頭で逸らされた。', 'You lost the header and he flicked it on.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('GKに任せてコースを消す', 'Leave it to the keeper and block the runners'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 52,
          outcome: Outcome.play,
          successText: Say('触らずに人を捕まえた。GKが安心して出られる。', 'You picked up the runners without touching it. The keeper can come freely.'),
          failureText: Say('中途半端に手を出し、GKと交錯した。', 'You reached half-heartedly and collided with your keeper.'),
          exposure: Exposure.chance,
        ),
        ScenarioOption(
          label: Say('前へ大きく蹴り出して起点にする', 'Clear it long and make it an attack'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 70,
          outcome: Outcome.assist,
          successText: Say('クリアがそのまま前線へ届き、試合を決める1点になった。', 'Your clearance reached the front and became the goal that won the game.'),
          failureText: Say('中途半端な高さになり、拾われて押し込まれかけた。', 'The height was all wrong. They picked it up and nearly turned it in.'),
          exposure: Exposure.shot,
        ),
      ],
    ),
    Scenario(
      id: 'def-hold-duel',
      spot: PitchSpot.ownFlank,
      situation: Say('守り切りたい終盤。目の前で1対1を仕掛けられた。', 'Late on, trying to see it out. He is taking you on, one on one.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('飛び込まずに遅らせる', 'Delay him without diving in'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('足を出さずに時間を稼いだ。味方が戻ってくる。', 'You kept your feet and ran the clock. Your teammates are getting back.'),
          failureText: Say('下がりすぎて、打たれる距離を渡した。', 'You dropped too deep and gave him room to shoot.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('体を当てて外へ追い出す', 'Put your body in and force him out of play'),
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('肩でぶつかって外へ。ただ、相手のスローインで続く。', 'Shoulder to shoulder and out of play. Their throw, though, so it goes on.'),
          failureText: Say('当たりが浅く、中へ入り込まれた。', 'You caught him thin and he came inside you.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
        ScenarioOption(
          label: Say('足を出して奪い切る', 'Put a leg in and take the ball'),
          key: AttributeKey.defending,
          detail: Detail.tackling,
          difficulty: 74,
          outcome: Outcome.play,
          successText: Say('完璧なタックル。ボールだけを奪った。', 'A perfect tackle. All ball.'),
          failureText: Say('足に引っ掛けた。危険な位置でのファウル。', 'You caught his leg. A foul in a dangerous spot.'),
          foul: 0.45,
          exposure: Exposure.shot,
          preventsGoal: true,
        ),
      ],
    ),
    Scenario(
      id: 'def-hold-clock',
      spot: PitchSpot.ownThird,
      situation: Say('ロスタイム。自陣でボールを持っている。時間を使いたい。', 'Stoppage time. You have the ball in your own half. You want to use the clock.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('大きく蹴り出す', 'Kick it long'),
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 46,
          outcome: Outcome.play,
          successText: Say('迷わず遠くへ。時間は減るが、ボールは相手に渡る。', 'Far and without hesitating. Time comes off, but they get the ball.'),
          failureText: Say('当たり損ねてタッチを割らず、拾われた。', 'You caught it badly, it stayed in play, and they picked it up.'),
          lingering: true,
        ),
        ScenarioOption(
          label: Say('つないで時間を使う', 'Keep it and use the clock'),
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 50,
          outcome: Outcome.play,
          successText: Say('落ち着いて回した。相手が追いかけるだけの時間になる。', 'You kept it moving calmly. All they can do is chase.'),
          failureText: Say('狙われていた。危ない位置で引っ掛けた。', 'They were waiting for it. You lost it in a bad area.'),
          exposure: Exposure.shot,
        ),
        ScenarioOption(
          label: Say('相手を誘い出してかわす', 'Invite him in and go past him'),
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 72,
          outcome: Outcome.play,
          successText: Say('寄せてきた相手を外し、味方を前に進ませた。', 'You drew him in, went past him, and sent your team forward.'),
          failureText: Say('自陣で失った。肝を冷やす場面になった。', 'You lost it in your own half. That was a scare.'),
          exposure: Exposure.chance,
        ),
      ],
    ),
    Scenario(
      id: 'def-hold-stop',
      spot: PitchSpot.ownThird,
      situation: Say('リードして終盤。相手のカウンター。前は無人だ。', 'A goal up, late on. They are counter-attacking. There is nobody ahead of you.'),
      tempo: ScenarioTempo.hold,
      options: [
        ScenarioOption(
          label: Say('ユニフォームを掴んで止める', 'Grab his shirt and stop him'),
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 50,
          outcome: Outcome.play,
          foul: 1,
          preventsGoal: true,
          successText: Say('掴んで止めた。警告は覚悟の上。失点は防いだ。', 'You grabbed him and stopped it. A booking, and worth it. No goal.'),
          failureText: Say('掴んだが振り切られた。警告だけが残った。', 'You grabbed him and he shook you off. All you got was the card.'),
        ),
        ScenarioOption(
          label: Say('並走して食らいつく', 'Run with him and stay with it'),
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 58,
          outcome: Outcome.play,
          successText: Say('走り切って追いついた。最後は体を入れて止める。', 'You kept running and caught him, then got your body in to stop it.'),
          failureText: Say('離された。数的不利のまま運ばれる。', 'He left you behind and they carried on with the extra man.'),
          exposure: Exposure.chance,
          preventsGoal: true,
        ),
        ScenarioOption(
          label: Say('中を切って遅らせる', 'Shut the inside and delay him'),
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 68,
          outcome: Outcome.play,
          successText: Say('外へ追い出した。味方が戻る時間を作れた。', 'You forced him outside and bought time for your teammates to get back.'),
          failureText: Say('中を通された。危ない場面になった。', 'He came inside you. That was a dangerous moment.'),
          exposure: Exposure.shot,
          lingering: true,
        ),
      ],
    ),
  ];
}
