import '../models/attributes.dart';

/// 局面の選択がうまくいったときに何が起きるか。
enum Outcome {
  /// ゴール。
  goal,

  /// アシスト。
  assist,

  /// 得点には直結しないが、評価される良いプレー。
  play,
}

/// 局面で選べる1つの手。
class ScenarioOption {
  const ScenarioOption({
    required this.label,
    required this.key,
    this.detail,
    required this.difficulty,
    required this.outcome,
    required this.successText,
    required this.failureText,
  });

  final String label;

  /// 成否を判定する能力のカテゴリ。
  final AttributeKey key;

  /// 判定に使う詳細能力。無ければカテゴリの平均で判定する。
  final Detail? detail;

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

  static const List<Scenario> goalkeeper = [
    Scenario(
      id: 'gk-oneonone',
      situation: '相手FWが抜け出した。1対1。距離を詰めるか、構えて待つか。',
      options: [
        ScenarioOption(
          label: '飛び出して距離を詰める',
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 70,
          outcome: Outcome.play,
          successText: '一気に間合いを詰め、足元でシュートを止めた。',
          failureText: '飛び出しが早く、ループで頭上を抜かれた。',
        ),
        ScenarioOption(
          label: '構えてコースを消す',
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 58,
          outcome: Outcome.play,
          successText: '体を大きく見せてコースを消し、正面で止めた。',
          failureText: '読みが外れ、逆を突かれた。',
        ),
        ScenarioOption(
          label: '足を使って時間を稼ぐ',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 50,
          outcome: Outcome.play,
          successText: '寄せる角度を変えて遅らせ、DFの帰陣を待てた。',
          failureText: '中途半端な位置取りで、簡単に決められた。',
        ),
      ],
    ),
    Scenario(
      id: 'gk-cross',
      situation: 'ゴール前に高いクロス。相手FWと自分のDFが競っている。',
      options: [
        ScenarioOption(
          label: 'パンチングで弾く',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 62,
          outcome: Outcome.play,
          successText: '混戦を避けて遠くへ弾き出した。',
          failureText: 'パンチングが弱く、こぼれ球を押し込まれかけた。',
        ),
        ScenarioOption(
          label: 'キャッチに行く',
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 72,
          outcome: Outcome.play,
          successText: '最高点で掴み、そのまま速攻を始めた。',
          failureText: '手から弾き、目の前に落としてしまった。',
        ),
        ScenarioOption(
          label: 'ラインに留まってDFに任せる',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 46,
          outcome: Outcome.play,
          successText: 'DFがクリアしやすい位置を保ち、危険を消した。',
          failureText: 'DFと譲り合い、誰も触れなかった。',
        ),
      ],
    ),
    Scenario(
      id: 'gk-pk',
      situation: 'PKを与えてしまった。キッカーが助走に入る。',
      options: [
        ScenarioOption(
          label: '読んで先に飛ぶ',
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 78,
          outcome: Outcome.play,
          successText: '読み勝った。両手で弾き出し、スタジアムが沸いた。',
          failureText: '逆に飛んだ。ボールは反対側へ。',
        ),
        ScenarioOption(
          label: 'ぎりぎりまで待つ',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 74,
          outcome: Outcome.play,
          successText: '最後まで待ち、反応でセーブした。',
          failureText: '待ちすぎて、隅への強いボールに届かなかった。',
        ),
        ScenarioOption(
          label: '中央で構える',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 66,
          outcome: Outcome.play,
          successText: 'キッカーが迷った。真ん中に蹴ったボールを止めた。',
          failureText: 'キッカーは迷わず隅へ蹴った。',
        ),
      ],
    ),
    Scenario(
      id: 'gk-distribution',
      situation: 'ボールをキャッチした。相手は前掛かりで、前線に味方が1人残っている。',
      options: [
        ScenarioOption(
          label: '前線へロングスローを投げる',
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 68,
          outcome: Outcome.assist,
          successText: '一本のスローで前線へ。味方が抜け出して決めた。',
          failureText: '距離が足りず、相手に拾われた。',
        ),
        ScenarioOption(
          label: '大きく蹴り出す',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 50,
          outcome: Outcome.play,
          successText: '陣地を大きく回復し、相手の圧力を逃した。',
          failureText: 'キックが流れ、相手のスローインになった。',
        ),
        ScenarioOption(
          label: '近くのDFに繋ぐ',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 42,
          outcome: Outcome.play,
          successText: '落ち着いて繋ぎ、ビルドアップを始めた。',
          failureText: 'DFへのパスが弱く、相手FWに狙われた。',
        ),
      ],
    ),
    Scenario(
      id: 'gk-longshot',
      situation: '25mからのミドルシュート。ボールが揺れながら飛んでくる。',
      options: [
        ScenarioOption(
          label: 'キャッチする',
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 74,
          outcome: Outcome.play,
          successText: '揺れるボールを胸に収めた。',
          failureText: '手から弾き、こぼれ球を詰められた。',
        ),
        ScenarioOption(
          label: '横に弾く',
          key: AttributeKey.goalkeeping,
          detail: Detail.reflexes,
          difficulty: 58,
          outcome: Outcome.play,
          successText: '無理をせず、コーナーへ弾き出した。',
          failureText: '弾いた先に相手がいた。',
        ),
        ScenarioOption(
          label: '体で受ける',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 52,
          outcome: Outcome.play,
          successText: '体の正面で受け止め、こぼれ球も自分で抑えた。',
          failureText: '当たったボールが股を抜けた。',
        ),
      ],
    ),
    Scenario(
      id: 'gk-sweeper',
      situation: 'DFの背後に長いボール。相手FWと自分、どちらが先に触るか。',
      options: [
        ScenarioOption(
          label: 'エリアの外まで飛び出してクリア',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 70,
          outcome: Outcome.play,
          successText: 'エリア外で先に触り、大きくクリアした。',
          failureText: '間に合わず、無人のゴールへ蹴り込まれた。',
        ),
        ScenarioOption(
          label: 'エリア内で待って処理する',
          key: AttributeKey.goalkeeping,
          detail: Detail.gkPositioning,
          difficulty: 56,
          outcome: Outcome.play,
          successText: '慌てず待ち、エリア内で確実に処理した。',
          failureText: '待ちすぎて、FWにボールを収められた。',
        ),
        ScenarioOption(
          label: 'DFに声をかけて任せる',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 48,
          outcome: Outcome.play,
          successText: '声で味方を動かし、DFが先に触った。',
          failureText: '指示が伝わらず、DFとぶつかった。',
        ),
      ],
    ),
    Scenario(
      id: 'gk-lastminute',
      situation: '後半アディショナルタイム、1点リード。相手GKまで上がってきたコーナー。',
      options: [
        ScenarioOption(
          label: '飛び出してキャッチ',
          key: AttributeKey.goalkeeping,
          detail: Detail.handling,
          difficulty: 72,
          outcome: Outcome.play,
          successText: '混戦の中で掴み切った。試合を締めた。',
          failureText: '触れず、こぼれ球を押し込まれた。',
        ),
        ScenarioOption(
          label: 'ライン上で待つ',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 60,
          outcome: Outcome.play,
          successText: 'ライン上で反応し、至近距離を止めた。',
          failureText: '密集で視界を塞がれ、反応できなかった。',
        ),
        ScenarioOption(
          label: 'クリア後に前へ投げて速攻',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 64,
          outcome: Outcome.assist,
          successText: 'クリアを拾って前へ投げ、無人のゴールに味方が決めた。',
          failureText: '投げたボールが弱く、相手に渡った。',
        ),
      ],
    ),
  ];

  static const List<Scenario> forward = [
    Scenario(
      id: 'fw-box',
      situation: 'ペナルティエリア内でボールを受けた。DFが2枚寄せてくる。',
      options: [
        ScenarioOption(
          label: '強引にシュートを打つ',
          key: AttributeKey.shooting,
          detail: Detail.shotPower,
          difficulty: 72,
          outcome: Outcome.goal,
          successText: '寄せられる前に振り抜いた。ネットが揺れる。',
          failureText: '体勢が崩れ、枠を大きく外した。',
        ),
        ScenarioOption(
          label: '横の味方に落とす',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 55,
          outcome: Outcome.assist,
          successText: '柔らかく落としたボールを味方が流し込んだ。',
          failureText: 'パスがずれ、DFにカットされた。',
        ),
        ScenarioOption(
          label: 'キープして味方を待つ',
          key: AttributeKey.physical,
          detail: Detail.strength,
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
          detail: Detail.finishing,
          difficulty: 68,
          outcome: Outcome.goal,
          successText: 'GKの頭上を越えるループ。美しく決まった。',
          failureText: '高すぎた。ボールはバーの上へ消えた。',
        ),
        ScenarioOption(
          label: 'GKをかわして流し込む',
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: '軽くかわして無人のゴールへ流し込んだ。',
          failureText: '足に当てられ、ボールがこぼれた。',
        ),
        ScenarioOption(
          label: '走り込む味方へ横パス',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
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
          detail: Detail.jumping,
          difficulty: 70,
          outcome: Outcome.goal,
          successText: '競り合いに勝ち、ヘディングをゴール左隅へ。',
          failureText: '競り負けて、DFにクリアされた。',
        ),
        ScenarioOption(
          label: 'ニアで潰れて味方を空ける',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 45,
          outcome: Outcome.assist,
          successText: 'ニアでDFを引き付け、空いた味方が押し込んだ。',
          failureText: '中途半端な動きで、味方ごと消えてしまった。',
        ),
        ScenarioOption(
          label: '下がってこぼれ球を狙う',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 60,
          outcome: Outcome.goal,
          successText: 'こぼれ球に誰よりも早く反応し、押し込んだ。',
          failureText: '読みが外れ、こぼれ球は相手の足元へ。',
        ),
      ],
    ),
    Scenario(
      id: 'fw-counter',
      situation: '自陣でボールを奪った。相手DFは2人だけ、こちらは自分と味方の2人。',
      options: [
        ScenarioOption(
          label: '全力で駆け上がって受ける',
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 66,
          outcome: Outcome.goal,
          successText: 'DFを置き去りにして受け、そのまま決めた。',
          failureText: '追いつかれ、シュートはブロックされた。',
        ),
        ScenarioOption(
          label: 'DFを引き付けて味方に流す',
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 60,
          outcome: Outcome.assist,
          successText: 'DFを2人とも引き付けてから流し、味方がフリーで決めた。',
          failureText: '引き付けすぎて、自分ごと潰された。',
        ),
        ScenarioOption(
          label: '無理せずポゼッションに切り替える',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 40,
          outcome: Outcome.play,
          successText: '速攻を捨てて確実に繋ぎ、押し込む形を作った。',
          failureText: '判断が遅れ、相手の帰陣を許した。',
        ),
      ],
    ),
    Scenario(
      id: 'fw-pk',
      situation: 'PKを獲得した。キッカーは自分。GKがラインで揺さぶってくる。',
      options: [
        ScenarioOption(
          label: '隅を狙って強く蹴る',
          key: AttributeKey.shooting,
          detail: Detail.shotPower,
          difficulty: 62,
          outcome: Outcome.goal,
          successText: 'GKの逆を突いた。隅に突き刺さる。',
          failureText: '狙いすぎてポストに当たり、外へ。',
        ),
        ScenarioOption(
          label: 'GKの動きを見て逆に蹴る',
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 58,
          outcome: Outcome.goal,
          successText: 'GKが先に動いた。ゆっくりと逆へ転がした。',
          failureText: 'GKが動かず、弱いキックを止められた。',
        ),
        ScenarioOption(
          label: '味方に譲る',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 30,
          outcome: Outcome.play,
          successText: '調子の良い味方に譲った。チームは冷静に決めた。',
          failureText: '譲った味方が外し、責任だけが残った。',
        ),
      ],
    ),
    Scenario(
      id: 'fw-press',
      situation: '相手GKがビルドアップを始める。前線からプレスに行くか。',
      options: [
        ScenarioOption(
          label: 'GKに全力で寄せる',
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.goal,
          successText: 'GKのパスミスを誘い、無人のゴールへ蹴り込んだ。',
          failureText: '簡単にかわされ、背後を大きく空けた。',
        ),
        ScenarioOption(
          label: 'パスコースを切って追い込む',
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 52,
          outcome: Outcome.play,
          successText: 'コースを限定し、相手は苦し紛れに蹴り出した。',
          failureText: '寄せが甘く、楽に前線へ繋がれた。',
        ),
        ScenarioOption(
          label: '守備ブロックに戻る',
          key: AttributeKey.physical,
          detail: Detail.stamina,
          difficulty: 40,
          outcome: Outcome.play,
          successText: '無駄走りをせず、守備の形を整えた。',
          failureText: '戻りが遅れ、中盤との距離が空いた。',
        ),
      ],
    ),
    Scenario(
      id: 'fw-lastminute',
      situation: '後半アディショナルタイム。コーナーキックがこぼれてきた。',
      options: [
        ScenarioOption(
          label: 'ボレーで叩く',
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 76,
          outcome: Outcome.goal,
          successText: '完璧なボレー。スタジアムが揺れた。',
          failureText: '当たり損ないが宇宙へ飛んでいった。',
        ),
        ScenarioOption(
          label: 'トラップしてから狙う',
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 64,
          outcome: Outcome.goal,
          successText: '一度収めて冷静に流し込んだ。',
          failureText: 'トラップが大きく、寄せられて潰された。',
        ),
        ScenarioOption(
          label: 'ファーの味方へ折り返す',
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 56,
          outcome: Outcome.assist,
          successText: 'ファーへの折り返しを味方が押し込んだ。',
          failureText: '折り返しが弱く、クリアされた。',
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
          detail: Detail.vision,
          difficulty: 70,
          outcome: Outcome.assist,
          successText: '密集の間を通す一本。FWが抜け出して決めた。',
          failureText: 'コースが甘く、インターセプトされた。',
        ),
        ScenarioOption(
          label: 'サイドへ大きく展開する',
          key: AttributeKey.passing,
          detail: Detail.longPassing,
          difficulty: 52,
          outcome: Outcome.play,
          successText: '逆サイドへ正確な展開。試合が動き出す。',
          failureText: '距離が足りず、タッチラインを割った。',
        ),
        ScenarioOption(
          label: '自分で持ち上がる',
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
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
          detail: Detail.longShots,
          difficulty: 74,
          outcome: Outcome.goal,
          successText: '鋭いミドルがゴール右上に突き刺さった。',
          failureText: 'ミートが甘く、GKの正面に飛んだ。',
        ),
        ScenarioOption(
          label: '中央へ持ち出してから叩く',
          key: AttributeKey.dribbling,
          detail: Detail.ballControl,
          difficulty: 62,
          outcome: Outcome.assist,
          successText: '角度を作ってから横へ。味方が押し込んだ。',
          failureText: '持ち出しが大きく、DFに引っかかった。',
        ),
        ScenarioOption(
          label: '無理せず作り直す',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
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
          detail: Detail.tackling,
          difficulty: 68,
          outcome: Outcome.play,
          successText: '寄せ切ってボールを奪取。ショートカウンターへ。',
          failureText: 'かわされ、間延びした中盤を使われた。',
        ),
        ScenarioOption(
          label: 'パスコースを切って待つ',
          key: AttributeKey.defending,
          detail: Detail.interceptions,
          difficulty: 50,
          outcome: Outcome.play,
          successText: 'コースを消し続け、相手は後ろに戻すしかなかった。',
          failureText: '中途半端な立ち位置で、間を通された。',
        ),
        ScenarioOption(
          label: '走力で背後をカバーする',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 58,
          outcome: Outcome.play,
          successText: '背後のスペースを消し切り、決定機を未然に潰した。',
          failureText: '戻り切れず、危険なスペースを空けた。',
        ),
      ],
    ),
    Scenario(
      id: 'mf-freekick',
      situation: 'ゴール正面25mでFKを得た。壁は5枚。',
      options: [
        ScenarioOption(
          label: '壁を越えて直接狙う',
          key: AttributeKey.shooting,
          detail: Detail.longShots,
          difficulty: 78,
          outcome: Outcome.goal,
          successText: '壁を越えて落ちる軌道。GKは一歩も動けなかった。',
          failureText: '壁に当たった。こぼれ球は相手へ。',
        ),
        ScenarioOption(
          label: 'ファーへ巻いたボールを入れる',
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 60,
          outcome: Outcome.assist,
          successText: 'ファーへの巻いたボールを、味方が頭で合わせた。',
          failureText: 'GKに直接キャッチされた。',
        ),
        ScenarioOption(
          label: '横に出してリスタート',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 36,
          outcome: Outcome.play,
          successText: '意表を突く横パスから、攻撃を組み立て直した。',
          failureText: 'ただの相手ボールになった。',
        ),
      ],
    ),
    Scenario(
      id: 'mf-transition',
      situation: '相手のカウンター。自分の前にボール保持者、後ろは手薄。',
      options: [
        ScenarioOption(
          label: '体を張って止める',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 66,
          outcome: Outcome.play,
          successText: '正面から止め切った。相手の勢いを断った。',
          failureText: '吹き飛ばされ、決定機を許した。',
        ),
        ScenarioOption(
          label: 'ファウルで止める',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 44,
          outcome: Outcome.play,
          successText: 'カードは覚悟の上。戦術的ファウルで流れを切った。',
          failureText: 'ファウルが遅れ、アドバンテージで流された。',
        ),
        ScenarioOption(
          label: '遅らせて味方の帰陣を待つ',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 56,
          outcome: Outcome.play,
          successText: '巧みに遅らせ、味方が戻る時間を作った。',
          failureText: '簡単に抜かれ、数的不利のまま攻め込まれた。',
        ),
      ],
    ),
    Scenario(
      id: 'mf-switch',
      situation: '相手が片側に寄っている。逆サイドに味方がフリーで待っている。',
      options: [
        ScenarioOption(
          label: '40mのサイドチェンジを通す',
          key: AttributeKey.passing,
          detail: Detail.vision,
          difficulty: 64,
          outcome: Outcome.assist,
          successText: '一本で逆サイドへ。フリーの味方が持ち込んで決めた。',
          failureText: '風に流され、タッチラインを割った。',
        ),
        ScenarioOption(
          label: '近くの味方と繋いで運ぶ',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 46,
          outcome: Outcome.play,
          successText: 'テンポ良く繋ぎ、相手を走らせた。',
          failureText: '狭い場所で引っかかり、奪われた。',
        ),
        ScenarioOption(
          label: '密集を1人で突破する',
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 72,
          outcome: Outcome.goal,
          successText: '3人をかわして持ち込み、自ら決めた。',
          failureText: '2人目に止められ、カウンターを食らった。',
        ),
      ],
    ),
    Scenario(
      id: 'mf-late',
      situation: '後半40分、1点ビハインド。ボールは自分の足元、前に空きはない。',
      options: [
        ScenarioOption(
          label: 'ペナルティエリアに飛び込む',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 66,
          outcome: Outcome.goal,
          successText: '走り込んだところに折り返しが来た。同点弾。',
          failureText: '走り込んだが、ボールは来なかった。',
        ),
        ScenarioOption(
          label: '早いクロスを上げる',
          key: AttributeKey.passing,
          detail: Detail.crossing,
          difficulty: 58,
          outcome: Outcome.assist,
          successText: '早いクロスにFWが合わせた。',
          failureText: 'クロスは誰にも合わず、流れた。',
        ),
        ScenarioOption(
          label: 'テンポを落として組み立てる',
          key: AttributeKey.dribbling,
          detail: Detail.agility,
          difficulty: 44,
          outcome: Outcome.play,
          successText: '焦らず組み立て、良い形を作った。',
          failureText: '時間だけが過ぎていった。',
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
          detail: Detail.tackling,
          difficulty: 72,
          outcome: Outcome.play,
          successText: '足を伸ばして完璧なタックル。ボールだけを奪った。',
          failureText: '簡単にかわされ、決定機を作られた。',
        ),
        ScenarioOption(
          label: '間合いを保って遅らせる',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 55,
          outcome: Outcome.play,
          successText: '距離を保って遅らせ、味方の帰陣を待った。',
          failureText: '下がりすぎてシュートを許した。',
        ),
        ScenarioOption(
          label: '体を当てて外へ追い出す',
          key: AttributeKey.physical,
          detail: Detail.strength,
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
          detail: Detail.jumping,
          difficulty: 68,
          outcome: Outcome.play,
          successText: '高い打点で跳ね返し、危険を完全に排除した。',
          failureText: '競り負け、決定的なヘディングを許した。',
        ),
        ScenarioOption(
          label: 'コースに入ってブロック',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 60,
          outcome: Outcome.play,
          successText: '体を投げ出してシュートをブロックした。',
          failureText: '一歩遅く、コースを空けてしまった。',
        ),
        ScenarioOption(
          label: '前に出てインターセプト',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
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
          detail: Detail.longPassing,
          difficulty: 66,
          outcome: Outcome.assist,
          successText: '一本のフィードで前線へ。そのまま得点に繋がった。',
          failureText: '精度を欠き、簡単に相手ボールになった。',
        ),
        ScenarioOption(
          label: '運んでからパスを出す',
          key: AttributeKey.dribbling,
          detail: Detail.dribbling,
          difficulty: 58,
          outcome: Outcome.play,
          successText: '数歩持ち上がって相手を外し、確実に繋いだ。',
          failureText: '奪われて、自陣で決定機を与えた。',
        ),
        ScenarioOption(
          label: '安全に大きく蹴り出す',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 38,
          outcome: Outcome.play,
          successText: '無理をせずクリア。まずは危険を消した。',
          failureText: 'ミスキックになり、スローインを与えた。',
        ),
      ],
    ),
    Scenario(
      id: 'df-setpiece',
      situation: '味方のコーナーキック。自分もゴール前に上がっている。',
      options: [
        ScenarioOption(
          label: 'ニアに飛び込んでヘディング',
          key: AttributeKey.physical,
          detail: Detail.jumping,
          difficulty: 70,
          outcome: Outcome.goal,
          successText: 'ニアで競り勝ち、頭で叩き込んだ。DFの得点。',
          failureText: 'マークを外せず、触れなかった。',
        ),
        ScenarioOption(
          label: 'ファーでこぼれ球を待つ',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 56,
          outcome: Outcome.assist,
          successText: 'こぼれ球を折り返し、味方が押し込んだ。',
          failureText: 'ボールは来ず、カウンターの戻りが遅れた。',
        ),
        ScenarioOption(
          label: '上がらずリスク管理する',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 40,
          outcome: Outcome.play,
          successText: '残っていたおかげでカウンターを未然に防いだ。',
          failureText: '一人残ったが、それでも背後を突かれた。',
        ),
      ],
    ),
    Scenario(
      id: 'df-offside',
      situation: '相手FWが裏を狙って動き出した。ラインの判断を任されている。',
      options: [
        ScenarioOption(
          label: 'ラインを上げてオフサイドを取る',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 68,
          outcome: Outcome.play,
          successText: '完璧なラインコントロール。旗が上がった。',
          failureText: 'ラインが揃わず、1人が残して裏を取られた。',
        ),
        ScenarioOption(
          label: '走り合いで潰す',
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 64,
          outcome: Outcome.play,
          successText: '走り負けせず、シュートコースを消した。',
          failureText: 'スピードで置き去りにされた。',
        ),
        ScenarioOption(
          label: 'ラインを下げて守る',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 42,
          outcome: Outcome.play,
          successText: '無理をせず下がって、ゴール前を固めた。',
          failureText: '下がりすぎて、ミドルシュートを打たれた。',
        ),
      ],
    ),
    Scenario(
      id: 'df-goalline',
      situation: 'GKがかわされた。無人のゴールに向かってシュートが飛んでくる。',
      options: [
        ScenarioOption(
          label: 'ゴールライン上でクリア',
          key: AttributeKey.defending,
          detail: Detail.marking,
          difficulty: 74,
          outcome: Outcome.play,
          successText: 'ライン上で掻き出した。歓声が上がる。',
          failureText: '間に合わず、ボールはネットへ。',
        ),
        ScenarioOption(
          label: 'スライディングでコースを消す',
          key: AttributeKey.pace,
          detail: Detail.acceleration,
          difficulty: 66,
          outcome: Outcome.play,
          successText: '滑り込んでブロック。大きなファインプレー。',
          failureText: '滑ったが届かなかった。',
        ),
        ScenarioOption(
          label: 'GKの位置に入って構える',
          key: AttributeKey.physical,
          detail: Detail.strength,
          difficulty: 48,
          outcome: Outcome.play,
          successText: '体を大きく見せて、シュートを自分に当てさせた。',
          failureText: '構えたが、股を抜かれた。',
        ),
      ],
    ),
    Scenario(
      id: 'df-overlap',
      situation: '攻撃の流れで自分がサイドを駆け上がった。前にはスペース。',
      options: [
        ScenarioOption(
          label: '深くえぐってクロス',
          key: AttributeKey.pace,
          detail: Detail.sprintSpeed,
          difficulty: 62,
          outcome: Outcome.assist,
          successText: 'ライン際までえぐったクロスを、FWが押し込んだ。',
          failureText: '追いつかれ、クロスは当たってしまった。',
        ),
        ScenarioOption(
          label: '中に切れ込んでシュート',
          key: AttributeKey.shooting,
          detail: Detail.finishing,
          difficulty: 76,
          outcome: Outcome.goal,
          successText: '切れ込んで放ったシュートが決まった。DFらしからぬ一撃。',
          failureText: 'シュートは大きく外れ、戻る距離だけが残った。',
        ),
        ScenarioOption(
          label: '早めに味方へ預ける',
          key: AttributeKey.passing,
          detail: Detail.shortPassing,
          difficulty: 44,
          outcome: Outcome.play,
          successText: '無理をせず預け、自分は守備位置へ戻った。',
          failureText: '預けたパスが弱く、相手に拾われた。',
        ),
      ],
    ),
  ];
}
