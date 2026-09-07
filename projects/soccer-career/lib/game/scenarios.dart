import '../models/attributes.dart';

/// 局面の選択がうまくいったときに何が起きるか。
enum Outcome {
  /// ゴール。
  goal,

  /// アシスト。
  assist,

  /// 得点には直結しないが、評価される good play。
  play,
}

/// 局面で選べる1つの手。
class ScenarioOption {
  const ScenarioOption({
    required this.label,
    required this.key,
    required this.difficulty,
    required this.outcome,
    required this.successText,
    required this.failureText,
  });

  final String label;

  /// 成否を判定する能力値。
  final AttributeKey key;

  /// 判定の基準値。能力値がこれと同じでも五分にはならず、少し不利。
  final int difficulty;

  final Outcome outcome;
  final String successText;
  final String failureText;
}

/// 試合中に提示される1つの局面。
class Scenario {
  const Scenario({
    required this.id,
    required this.situation,
    required this.options,
  });

  final String id;
  final String situation;
  final List<ScenarioOption> options;
}

/// ポジション別の局面プール。
///
/// 各局面は「難しいが得点に直結する手」と「安全だが見返りが小さい手」を
/// 対にしてある。どちらを選ぶかがこのゲームの判断そのものなので、
/// 常に正解になる選択肢を作らない。
class ScenarioPool {
  const ScenarioPool._();

  static List<Scenario> forPosition(Position position) => switch (position) {
        Position.fw => forward,
        Position.mf => midfield,
        Position.df => defence,
      };

  static const List<Scenario> forward = [
    Scenario(
      id: 'fw-box',
      situation: 'ペナルティエリア内でボールを受けた。DFが2枚寄せてくる。',
      options: [
        ScenarioOption(
          label: '強引にシュートを打つ',
          key: AttributeKey.shooting,
          difficulty: 72,
          outcome: Outcome.goal,
          successText: '寄せられる前に振り抜いた。ネットが揺れる。',
          failureText: '体勢が崩れ、枠を大きく外した。',
        ),
        ScenarioOption(
          label: '横の味方に落とす',
          key: AttributeKey.passing,
          difficulty: 55,
          outcome: Outcome.assist,
          successText: '柔らかく落としたボールを味方が流し込んだ。',
          failureText: 'パスがずれ、DFにカットされた。',
        ),
        ScenarioOption(
          label: 'キープして味方を待つ',
          key: AttributeKey.physical,
          difficulty: 48,
          outcome: Outcome.play,
          successText: '体を入れて時間を作り、攻撃を落ち着かせた。',
          failureText: '力負けしてボールを失った。',
        ),
      ],
    ),
    Scenario(
      id: 'fw-through',
      situation: '最終ラインの裏へスルーパスが出た。GKが飛び出してくる。',
      options: [
        ScenarioOption(
          label: 'ループシュートを狙う',
          key: AttributeKey.shooting,
          difficulty: 68,
          outcome: Outcome.goal,
          successText: 'GKの頭上を越えるループ。美しく決まった。',
          failureText: '高すぎた。ボールはバーの上へ消えた。',
        ),
        ScenarioOption(
          label: 'GKをかわして流し込む',
          key: AttributeKey.dribbling,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: '軽くかわして無人のゴールへ流し込んだ。',
          failureText: '足に当てられ、ボールがこぼれた。',
        ),
        ScenarioOption(
          label: '走り込む味方へ横パス',
          key: AttributeKey.passing,
          difficulty: 58,
          outcome: Outcome.assist,
          successText: '冷静な横パス。味方が無人のゴールへ押し込んだ。',
          failureText: 'パスが強すぎて味方が追いつけなかった。',
        ),
      ],
    ),
    Scenario(
      id: 'fw-cross',
      situation: 'サイドからクロスが上がる。DFとの空中戦になる。',
      options: [
        ScenarioOption(
          label: 'ヘディングで叩きつける',
          key: AttributeKey.physical,
          difficulty: 70,
          outcome: Outcome.goal,
          successText: '競り合いに勝ち、ヘディングをゴール左隅へ。',
          failureText: '競り負けて、DFにクリアされた。',
        ),
        ScenarioOption(
          label: 'ニアで潰れて味方を空ける',
          key: AttributeKey.physical,
          difficulty: 45,
          outcome: Outcome.assist,
          successText: 'ニアでDFを引き付け、空いた味方が押し込んだ。',
          failureText: '中途半端な動きで、味方ごと消えてしまった。',
        ),
        ScenarioOption(
          label: '下がってこぼれ球を狙う',
          key: AttributeKey.pace,
          difficulty: 60,
          outcome: Outcome.goal,
          successText: 'こぼれ球に誰よりも早く反応し、押し込んだ。',
          failureText: '読みが外れ、こぼれ球は相手の足元へ。',
        ),
      ],
    ),
  ];

  static const List<Scenario> midfield = [
    Scenario(
      id: 'mf-build',
      situation: '中盤でボールを持った。前線は密集、サイドは空いている。',
      options: [
        ScenarioOption(
          label: '縦にスルーパスを通す',
          key: AttributeKey.passing,
          difficulty: 70,
          outcome: Outcome.assist,
          successText: '密集の間を通す一本。FWが抜け出して決めた。',
          failureText: 'コースが甘く、インターセプトされた。',
        ),
        ScenarioOption(
          label: 'サイドへ大きく展開する',
          key: AttributeKey.passing,
          difficulty: 52,
          outcome: Outcome.play,
          successText: '逆サイドへ正確な展開。試合が動き出す。',
          failureText: '距離が足りず、タッチラインを割った。',
        ),
        ScenarioOption(
          label: '自分で持ち上がる',
          key: AttributeKey.dribbling,
          difficulty: 66,
          outcome: Outcome.play,
          successText: '2人剥がして前進。相手の守備が崩れた。',
          failureText: '囲まれて奪われ、カウンターを受けた。',
        ),
      ],
    ),
    Scenario(
      id: 'mf-shot',
      situation: 'ペナルティエリア手前にこぼれ球。前は空いている。',
      options: [
        ScenarioOption(
          label: 'ミドルシュートを打つ',
          key: AttributeKey.shooting,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: '鋭いミドルがゴール右上に突き刺さった。',
          failureText: 'ミートが甘く、GKの正面に飛んだ。',
        ),
        ScenarioOption(
          label: '中央へ持ち出してから叩く',
          key: AttributeKey.dribbling,
          difficulty: 62,
          outcome: Outcome.assist,
          successText: '角度を作ってから横へ。味方が押し込んだ。',
          failureText: '持ち出しが大きく、DFに引っかかった。',
        ),
        ScenarioOption(
          label: '無理せず作り直す',
          key: AttributeKey.passing,
          difficulty: 42,
          outcome: Outcome.play,
          successText: '後ろに戻して作り直し。危なげない判断。',
          failureText: 'バックパスが短く、相手に拾われかけた。',
        ),
      ],
    ),
    Scenario(
      id: 'mf-press',
      situation: '相手のビルドアップ。プレスに行くか、ブロックを作るか。',
      options: [
        ScenarioOption(
          label: '一気に寄せて奪いに行く',
          key: AttributeKey.defending,
          difficulty: 68,
          outcome: Outcome.play,
          successText: '寄せ切ってボールを奪取。ショートカウンターへ。',
          failureText: 'かわされ、間延びした中盤を使われた。',
        ),
        ScenarioOption(
          label: 'パスコースを切って待つ',
          key: AttributeKey.defending,
          difficulty: 50,
          outcome: Outcome.play,
          successText: 'コースを消し続け、相手は後ろに戻すしかなかった。',
          failureText: '中途半端な立ち位置で、間を通された。',
        ),
        ScenarioOption(
          label: '走力で背後をカバーする',
          key: AttributeKey.pace,
          difficulty: 58,
          outcome: Outcome.play,
          successText: '背後のスペースを消し切り、決定機を未然に潰した。',
          failureText: '戻り切れず、危険なスペースを空けた。',
        ),
      ],
    ),
  ];

  static const List<Scenario> defence = [
    Scenario(
      id: 'df-duel',
      situation: '快足のウイングと1対1。背後にはスペースがある。',
      options: [
        ScenarioOption(
          label: '飛び込んで奪いに行く',
          key: AttributeKey.defending,
          difficulty: 72,
          outcome: Outcome.play,
          successText: '足を伸ばして完璧なタックル。ボールだけを奪った。',
          failureText: '簡単にかわされ、決定機を作られた。',
        ),
        ScenarioOption(
          label: '間合いを保って遅らせる',
          key: AttributeKey.pace,
          difficulty: 55,
          outcome: Outcome.play,
          successText: '距離を保って遅らせ、味方の帰陣を待った。',
          failureText: '下がりすぎてシュートを許した。',
        ),
        ScenarioOption(
          label: '体を当てて外へ追い出す',
          key: AttributeKey.physical,
          difficulty: 62,
          outcome: Outcome.play,
          successText: '体を当ててタッチラインの外へ追い出した。',
          failureText: '倒してしまい、危険な位置でFKを与えた。',
        ),
      ],
    ),
    Scenario(
      id: 'df-cross',
      situation: '相手のクロスがゴール前へ。中には長身のFWがいる。',
      options: [
        ScenarioOption(
          label: '競り勝ってクリアする',
          key: AttributeKey.physical,
          difficulty: 68,
          outcome: Outcome.play,
          successText: '高い打点で跳ね返し、危険を完全に排除した。',
          failureText: '競り負け、決定的なヘディングを許した。',
        ),
        ScenarioOption(
          label: 'コースに入ってブロック',
          key: AttributeKey.defending,
          difficulty: 60,
          outcome: Outcome.play,
          successText: '体を投げ出してシュートをブロックした。',
          failureText: '一歩遅く、コースを空けてしまった。',
        ),
        ScenarioOption(
          label: '前に出てインターセプト',
          key: AttributeKey.pace,
          difficulty: 70,
          outcome: Outcome.play,
          successText: '読み切って前で断ち切り、そのまま攻撃に転じた。',
          failureText: '飛び出しが空振りし、背後を使われた。',
        ),
      ],
    ),
    Scenario(
      id: 'df-buildup',
      situation: '最終ラインでボールを持つ。相手FWがプレスに来る。',
      options: [
        ScenarioOption(
          label: '縦に長いフィードを蹴る',
          key: AttributeKey.passing,
          difficulty: 66,
          outcome: Outcome.assist,
          successText: '一本のフィードで前線へ。そのまま得点に繋がった。',
          failureText: '精度を欠き、簡単に相手ボールになった。',
        ),
        ScenarioOption(
          label: '運んでからパスを出す',
          key: AttributeKey.dribbling,
          difficulty: 58,
          outcome: Outcome.play,
          successText: '数歩持ち上がって相手を外し、確実に繋いだ。',
          failureText: '奪われて、自陣で決定機を与えた。',
        ),
        ScenarioOption(
          label: '安全に大きく蹴り出す',
          key: AttributeKey.physical,
          difficulty: 38,
          outcome: Outcome.play,
          successText: '無理をせずクリア。まずは危険を消した。',
          failureText: 'ミスキックになり、スローインを与えた。',
        ),
      ],
    ),
  ];
}
