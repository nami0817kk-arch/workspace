import 'dart:math';

import '../game/formulas.dart';
import 'attributes.dart';
import 'club.dart';
import 'player.dart';
import 'season.dart';

/// 相手クラブの戦い方。
///
/// クラブごとに保存はしない。IDから決めることで、同じクラブとは毎回
/// 同じ噛み合わせになり、「あそこは苦手だ」という記憶が成立する。
enum ClubStyle {
  pressing('ハイプレス', 'パスを出す余裕が無い', AttributeKey.passing),
  defensive('堅守速攻', 'ゴール前を固めてくる', AttributeKey.shooting),
  technical('技巧派', 'ボールを持たれる', AttributeKey.defending),
  physical('肉弾戦', '当たりが強く、仕掛けが潰される', AttributeKey.dribbling);

  const ClubStyle(this.label, this.description, this.hardFor);

  final String label;
  final String description;

  /// この相手に対して難しくなる能力。
  final AttributeKey hardFor;

  /// クラブIDから決める。ハッシュではなく符号の和で出すのは、
  /// 実行ごとに変わらないようにするため。
  static ClubStyle of(Club club) {
    final sum = club.id.codeUnits.fold<int>(0, (a, b) => a + b);
    return ClubStyle.values[sum % ClubStyle.values.length];
  }
}

/// 積み上げると身に付く個人技。
///
/// 能力値が一定に達した選手が、その練習を続けているうちに覚える。
/// 覚えると、その技が出る局面だけ確率が上がる。
enum Signature {
  // ---- 運ぶ・かわす ----
  turn('切り返し', Detail.ballControl),
  closeControl('足元の収まり', Detail.ballControl),
  slalom('持ち出し', Detail.dribbling),
  feint('緩急', Detail.agility),

  // ---- 配る ----
  noLook('ノールックパス', Detail.vision),
  spread('展開力', Detail.longPassing),
  throughBall('刺すパス', Detail.shortPassing),
  earlyCross('早いクロス', Detail.crossing),

  // ---- 決める ----
  knuckle('無回転シュート', Detail.shotPower),
  placement('流し込み', Detail.finishing),
  volley('ボレー', Detail.longShots),
  attackTheBall('打点', Detail.heading),

  // ---- 止める ----
  read('読み', Detail.interceptions),
  timing('足を出す間', Detail.tackling),
  bodyPosition('立ち位置', Detail.marking),

  // ---- 走る・当たる ----
  burst('初速の一歩', Detail.acceleration),
  afterburner('伸びる足', Detail.sprintSpeed),
  shoulder('体の入れ方', Detail.strength),
  spring('跳ぶ間合い', Detail.jumping),

  // ---- GK ----
  handsUp('1対1の間合い', Detail.reflexes),
  command('飛び出しの判断', Detail.gkPositioning),
  safeHands('確実な処理', Detail.handling);

  const Signature(this.label, this.detail);

  final String label;

  /// 元になる詳細能力。
  final Detail detail;

  AttributeKey get key => detail.category;

  /// 覚えるのに必要な能力値。
  ///
  /// 72 だと、育てた選手のほぼ全員が3つとも覚えていた。
  /// 「その選手にしか無いもの」であってほしいので、上に置く。
  static const int requirement = 78;

  /// 同時に持てる数。何でも出来る選手にしない。
  static const int maxOwned = 3;

  /// **そのポジションで意味を持つ技か。**
  ///
  /// ここが無かったので、実測（`test/craft_sim.dart`）で
  /// **GK の95%が「無回転シュート」を覚え、CB の52%が
  /// 「ノールックパス」を覚えていた**。伸びた詳細能力に自動で付くだけで、
  /// 何をする選手なのかを一切見ていなかった。
  ///
  /// GK の技はフィールドの選手には付かず、その逆も無い。
  /// 前線の技は守る選手に、守りの技は前線の選手に付かない——
  /// **「その選手にしか無いもの」は、まずその選手がやることの中から出る。**
  bool fitsPosition(Position position) {
    final family = position.family;
    if (key == AttributeKey.goalkeeping) {
      return family == ScenarioFamily.goalkeeper;
    }
    // GK が覚えられるのは、GK の技と**身体の技**（競り合い・跳ぶ間合い）。
    // GK 専用の詳細能力は3つしか無いので、ここを閉じると
    // **全員が同じ3つを揃えて終わる**。
    if (family == ScenarioFamily.goalkeeper) {
      return key == AttributeKey.physical;
    }
    return switch (key) {
      // 決める技は、守るのが仕事の選手には出ない（ヘディングだけは別）。
      AttributeKey.shooting =>
        detail == Detail.heading || family != ScenarioFamily.defence,
      // 止める技は、点を取るのが仕事の選手には出ない。
      AttributeKey.defending => family != ScenarioFamily.forward,
      _ => true,
    };
  }

  /// そのポジションで覚えられる技。
  static List<Signature> forPosition(Position position) => [
    for (final s in values)
      if (s.fitsPosition(position)) s,
  ];
}

/// キャリアを通じて積み上がるもの。
///
/// 能力値とは別に、「何試合を戦い」「どんな手を選び」「誰と当たってきたか」を
/// 覚えておく。同じ能力値でも、10年やってきた選手と新人は同じではない。
class Development {
  const Development({
    this.experience = 0,
    this.choices = const {},
    this.faced = const {},
    this.signatures = const [],
    this.growthStreak = 0,
    this.plateau = 0,
    this.breakthroughs = 0,
    this.greatWeeks = 0,
    this.points = const {},
    this.strain = Formulas.strainNeutral,
    this.dedication = const {},
  });

  /// 試合経験値。出場のたびに積む。
  final int experience;

  /// どの能力の手を選んできたか。プレイング・アイデンティティの元。
  final Map<AttributeKey, int> choices;

  /// どの戦い方の相手と当たってきたか。
  final Map<ClubStyle, int> faced;

  /// 覚えた個人技。
  final List<Signature> signatures;

  /// 連続で伸びた回数。溜まると停滞期に入る。
  final int growthStreak;

  /// 停滞期の残り試合数。0 なら平常。
  final int plateau;

  /// 限界突破した回数。
  final int breakthroughs;

  /// まだ振っていない経験点。カテゴリごとに持つ。
  ///
  /// 成長は**全部自動**で、プレイヤーが伸ばす先を選ぶ余地が無かった。
  /// 練習の種類でカテゴリは選べるが、その中のどれが伸びるかは運任せ。
  /// 経験点は「伸びるはずだったぶん」を貯めておいて、自分で振れるようにする。
  ///
  /// カテゴリを跨いで使うことはできない。パスの練習で守備は伸びない。
  final Map<AttributeKey, int> points;

  /// 振れる経験点の合計。
  int get totalPoints => points.values.fold(0, (a, b) => a + b);

  /// 練習で大成功した週の数。
  ///
  /// **限界を超えられるのは、自分を追い込んだ選手だけ**。
  /// 週の選択（`TrainingEffort`）が、届く高さそのものを動かす唯一の道。
  /// これが無いと、追い込んでもピークに早く着くだけで、同じ選手になる
  /// （実測: 流す 74.4 / 普通 74.6 / 追い込む 74.9）。
  final int greatWeeks;

  /// **どの項目を、何回狙って伸ばそうとしてきたか。**
  ///
  /// 伸びたかどうかではなく「狙った回数」を数える——頭打ちで土台に
  /// 回された回も積み上げに入れないと、**鎖の深い項目ほど永久に尖れない**。
  /// 積むほど土台を先行できる幅が広がる（`Dependencies.headroomFor`）。
  final Map<Detail, int> dedication;

  /// その項目にどれだけ積んだか。
  int dedicationOf(Detail detail) => dedication[detail] ?? 0;

  /// 狙った項目を1回ぶん積む。
  Development aiming(Detail detail) =>
      copyWith(dedication: {...dedication, detail: dedicationOf(detail) + 1});

  /// 身体の消耗 0〜100。最近どう踏み込んできたかが寄っていく先。
  ///
  /// 衰え始めの年齢と、重傷の引きやすさを動かす。計算は `Formulas`
  /// （`driftStrain` / `declineOffsetForStrain`）にあり、ここは値を持つだけ。
  /// 既定は 50（＝「普通」で来た選手）。知らない保存データもここに落ちる。
  final double strain;

  /// 画面に出す言葉。
  ///
  /// **判定そのもの（衰え始めの増減）から作る。** 別に境目を書くと、
  /// 数字を触ったときに「やや軽い」と出ているのに何も付いていない、
  /// という食い違いが起きる（実際、境目を測り直したときにそうなった）。
  String get strainLabel => switch (Formulas.declineOffsetForStrain(strain)) {
    2 => '軽い',
    1 => 'やや軽い',
    -1 => '重い',
    -2 => '限界',
    _ => '普通',
  };

  /// アイデンティティが決まるのに要る選択の数。
  static const int identityThreshold = 30;

  /// 停滞期に入る連続成長回数。
  static const int plateauStreak = 12;

  bool get inPlateau => plateau > 0;

  /// 選択の癖から決まる自分の型。まだ足りなければ null。
  AttributeKey? get identity {
    final total = choices.values.fold(0, (a, b) => a + b);
    if (total < identityThreshold) return null;
    final top = choices.entries.reduce((a, b) => a.value >= b.value ? a : b);
    // 突出していなければ型は無い。何でも選ぶ選手は何者でもない。
    return top.value * 3 >= total ? top.key : null;
  }

  String get identityLabel => switch (identity) {
    AttributeKey.pace => '走る選手',
    AttributeKey.shooting => '仕留める選手',
    AttributeKey.passing => '組み立てる選手',
    AttributeKey.dribbling => '仕掛ける選手',
    AttributeKey.defending => '潰す選手',
    AttributeKey.physical => '身体で戦う選手',
    AttributeKey.goalkeeping => '守る選手',
    null => 'まだ型が無い',
  };

  /// 自分の型に沿った手の成功率への上乗せ。
  ///
  /// +3%/−1% では、**局面の98%に付いていて平均 +1.5%** という
  /// 「常に少しだけ効く飾り」だった（実測）。型を通すか監督に合わせるかが
  /// 選択になるには、通したときの見返りも、逆らったときの代償も要る。
  ///
  /// **上乗せではなく偏りにする。** 得意 +5%／それ以外 −4% で、平均すると
  /// ほぼ増減しない。型を持つことは強くなることではなく、尖ること。
  double identityBonusFor(AttributeKey key) =>
      identity == null ? 0 : (identity == key ? 0.05 : -0.04);

  /// その戦い方に慣れているぶんの上乗せ。当たるほど苦手ではなくなる。
  ///
  /// 上限 0.04 では、苦手（−5%）を薄めきる前にキャリアが終わる。
  /// **苦手を深くして、慣れで消しきれる**ようにすると、
  /// 「あそこは苦手だ」が「もう苦手ではない」に変わる瞬間が出る。
  /// 32回（3〜4シーズン）で消えきる。速すぎると苦手が最初の1年で終わる。
  double adaptationFor(ClubStyle style, {double factor = 1.0}) =>
      min(0.08, (faced[style] ?? 0) * 0.0025 * factor);

  /// 経験からくる落ち着き。大一番の重圧を薄める。
  ///
  /// 0.05 上限では、大一番の重圧（−5%）が**キャリア中盤で完全に消える**
  /// （実測: 大一番の平均が −0.10%＝実質ゼロ）。重圧を深くして、
  /// 経験がそれを埋める形にする。若い選手の大一番は本当に怖い。
  double get composure => min(0.10, experience / 1500);

  /// 覚えた個人技による上乗せを、技ごとに分けて返す。
  ///
  /// 合計だけを返していた頃は、画面に「なぜこの数字なのか」を出せなかった。
  /// 覚えた技が試合のどこで効いているのかが見えないと、
  /// 積み上げと試合が別のものに見える。
  /// **その技が噛み合う手だけ、深く効く。**
  ///
  /// 0.05 / 0.02 に置いていた頃、実測（`influence_sim`）で個人技の持ち分は
  /// 増減の 6.0% しかなく、**1人あたり 2.83個＝誰でも3つ揃う**ので
  /// 選ぶ余地も無かった。特性で先に踏んだのと同じ「**影響度 = 頻度 × 深さ**」。
  ///
  /// 技そのものの手（`detail` が一致）は深く、同じカテゴリの手は浅いまま——
  /// **広く薄く効かせると、また「常に少し効く飾り」に戻る。**
  Map<Signature, double> signatureFactors(AttributeKey key, Detail? detail) {
    final result = <Signature, double>{};
    for (final s in signatures) {
      if (detail != null && s.detail == detail) {
        result[s] = Formulas.signatureOnDetail;
      } else if (s.key == key) {
        result[s] = Formulas.signatureOnKey;
      }
    }
    return result;
  }

  /// 覚えた個人技による上乗せ。
  double signatureBonus(AttributeKey key, Detail? detail) =>
      signatureFactors(key, detail).values.fold(0.0, (a, b) => a + b);

  /// 1試合ぶんの積み上げ。
  Development afterMatch({
    required Appearance appearance,
    required bool international,
    ClubStyle? style,
    Iterable<AttributeKey> used = const [],
  }) {
    final gained = switch (appearance) {
      Appearance.start => 3,
      Appearance.sub => 1,
      Appearance.benched || Appearance.injured || Appearance.suspended => 0,
    };
    if (gained == 0) {
      return copyWith(plateau: max(0, plateau - 1));
    }

    final nextChoices = {...choices};
    for (final key in used) {
      nextChoices[key] = (nextChoices[key] ?? 0) + 1;
    }
    final nextFaced = {...faced};
    if (style != null) nextFaced[style] = (nextFaced[style] ?? 0) + 1;

    return copyWith(
      experience: experience + gained + (international ? 2 : 0),
      choices: nextChoices,
      faced: nextFaced,
      plateau: max(0, plateau - 1),
    );
  }

  /// 伸びた/伸びなかったを受けて、停滞期の出入りを決める。
  ///
  /// 伸び続けた選手はどこかで足踏みする。ここが無いと、上手くいっている
  /// 間はひたすら右肩上がりで、キャリアの起伏が消える。
  Development afterGrowth({
    required bool grew,
    required Random random,
    double plateauFactor = 1.0,
  }) {
    if (!grew) return this;
    final streak = growthStreak + 1;
    if (streak < plateauStreak) return copyWith(growthStreak: streak);
    final length = ((4 + random.nextInt(6)) * plateauFactor).round();
    return copyWith(growthStreak: 0, plateau: max(1, length));
  }

  /// 個人技を覚える。**ポジションで意味を持つものだけ。**
  ///
  /// ここを通らない道があると、そこから漏れる——実際、ピッチ外の出来事
  /// （`LifeEffect.insight`）がポジションを見ずに配っていて、
  /// **GK の60%が「無回転シュート」を覚えていた**。
  /// 練習の側だけ直しても塞がらないので、**入口をここ1つに絞って見る**。
  Development learn(Signature signature, {Position? position}) =>
      signatures.contains(signature) ||
          signatures.length >= Signature.maxOwned ||
          (position != null && !signature.fitsPosition(position))
      ? this
      : copyWith(signatures: [...signatures, signature]);

  /// その選手が、いま覚えられる技。出来事の「閃き」の読み替え先。
  ///
  /// 閃いたのに**そのポジションでは意味の無い技**だった、では
  /// 出来事そのものが無かったことになる。同じ場面で積んできたものから出す。
  Signature? insightFor(Player player) {
    final ready = [
      for (final s in Signature.forPosition(player.position))
        if (!signatures.contains(s) &&
            player.attributes.detail(s.detail) >= Signature.requirement)
          s,
    ];
    if (ready.isEmpty) return null;
    // 一番伸ばしてきた項目のもの。**そこを積んだから閃いた**、という形。
    ready.sort(
      (a, b) => player.attributes
          .detail(b.detail)
          .compareTo(player.attributes.detail(a.detail)),
    );
    return ready.first;
  }

  Development copyWith({
    int? experience,
    Map<AttributeKey, int>? choices,
    Map<ClubStyle, int>? faced,
    List<Signature>? signatures,
    int? growthStreak,
    int? plateau,
    int? breakthroughs,
    int? greatWeeks,
    Map<AttributeKey, int>? points,
    double? strain,
    Map<Detail, int>? dedication,
  }) => Development(
    experience: experience ?? this.experience,
    choices: choices ?? this.choices,
    faced: faced ?? this.faced,
    signatures: signatures ?? this.signatures,
    growthStreak: growthStreak ?? this.growthStreak,
    plateau: plateau ?? this.plateau,
    breakthroughs: breakthroughs ?? this.breakthroughs,
    greatWeeks: greatWeeks ?? this.greatWeeks,
    points: points ?? this.points,
    strain: strain ?? this.strain,
    dedication: dedication ?? this.dedication,
  );

  Map<String, dynamic> toJson() => {
    'experience': experience,
    'choices': {for (final e in choices.entries) e.key.name: e.value},
    'faced': {for (final e in faced.entries) e.key.name: e.value},
    'signatures': signatures.map((s) => s.name).toList(),
    'growthStreak': growthStreak,
    'plateau': plateau,
    'breakthroughs': breakthroughs,
    'greatWeeks': greatWeeks,
    'strain': strain,
    'dedication': {for (final e in dedication.entries) e.key.name: e.value},
    'points': {for (final e in points.entries) e.key.name: e.value},
  };

  factory Development.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Development();
    final choices = <AttributeKey, int>{};
    for (final e in (json['choices'] as Map? ?? const {}).entries) {
      if (AttributeKey.values.any((k) => k.name == e.key)) {
        choices[AttributeKey.values.byName(e.key as String)] = e.value as int;
      }
    }
    final faced = <ClubStyle, int>{};
    for (final e in (json['faced'] as Map? ?? const {}).entries) {
      if (ClubStyle.values.any((s) => s.name == e.key)) {
        faced[ClubStyle.values.byName(e.key as String)] = e.value as int;
      }
    }
    return Development(
      experience: json['experience'] as int? ?? 0,
      choices: choices,
      faced: faced,
      signatures: [
        for (final n in (json['signatures'] as List? ?? const []))
          if (Signature.values.any((s) => s.name == n))
            Signature.values.byName(n as String),
      ],
      growthStreak: json['growthStreak'] as int? ?? 0,
      plateau: json['plateau'] as int? ?? 0,
      breakthroughs: json['breakthroughs'] as int? ?? 0,
      greatWeeks: json['greatWeeks'] as int? ?? 0,
      // 知らない保存データは「普通で来た選手」として読む。
      strain: (json['strain'] as num?)?.toDouble() ?? Formulas.strainNeutral,
      dedication: {
        for (final e in (json['dedication'] as Map? ?? const {}).entries)
          if (Detail.values.any((d) => d.name == e.key))
            Detail.values.byName(e.key as String): e.value as int,
      },
      points: {
        for (final e in (json['points'] as Map? ?? const {}).entries)
          if (AttributeKey.values.any((k) => k.name == e.key))
            AttributeKey.values.byName(e.key as String): e.value as int,
      },
    );
  }
}

/// 能力カテゴリの今季の伸び。
class CategoryGrowth {
  const CategoryGrowth({
    required this.key,
    required this.before,
    required this.now,
    required this.attempts,
    required this.successes,
  });

  final AttributeKey key;

  /// 今季の開幕時の値と、今の値。
  final int before;
  final int now;

  /// 今季、その能力で判定した局面の数と、成功した数。
  final int attempts;
  final int successes;

  int get growth => now - before;

  bool get hasMoments => attempts > 0;

  /// 成功率（0〜1）。局面が無ければ null。
  double? get successRate => attempts == 0 ? null : successes / attempts;
}
