// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。外に見せるのは `String` の
// getter なので、持ち物は private のまま置く。
// ignore_for_file: prefer_initializing_formals

import '../game/formulas.dart';
import '../l10n/lang.dart';
import 'attributes.dart';
import 'entourage.dart';

/// その週、どこまで踏み込むか。
///
/// これまで週の選択は「どのメニューか」だけで、**踏み込む/流すの判断が無かった**。
/// 毎週同じ画面で同じものを選ぶだけなので、練習の週に手応えが無い。
///
/// 伸びの倍率は持たせない。**手応えの出方（大成功・空回り）そのものを動かす**。
/// 倍率と確率の両方を動かすと、どちらが効いているのか画面から追えなくなる。
enum TrainingEffort {
  easy(
    Say('流す', 'Take it easy'),
    Say('軽く。伸びは薄いが、身体が残る。衰え始めが遅くなる', 'Light work. Less growth, but the body holds up. Decline starts later'),
    great: 0.02,
    flat: 0.45,
    cost: 0.5,
    injury: 0.5,
    strain: 22,
  ),
  normal(
    Say('普通', 'Normal'),
    Say('いつもどおり', 'The usual'),
    great: 0.15,
    flat: 0.15,
    cost: 1.0,
    injury: 1.0,
    strain: 50,
  ),
  hard(
    Say('追い込む', 'Push hard'),
    Say('限界まで。大きく伸びるが、消耗も怪我も跳ね上がる。'
        '続ければ衰えが早く来る', 'To the limit. Big gains, but condition and injuries both spike. Keep it up and decline comes early'),
    great: 0.45,
    flat: 0.10,
    cost: 1.9,
    injury: 1.8,
    strain: 86,
  );

  const TrainingEffort(
    Say label,
    Say description, {
    required this.great,
    required this.flat,
    required this.cost,
    required this.injury,
    required this.strain,
  }) : _label = label,
       _description = description;

  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;

  /// 大成功・空回りの出やすさ。
  final double great;
  final double flat;

  /// コンディションの減り方と、怪我のしやすさ。
  final double cost;
  final double injury;

  /// この踏み込み方を続けたときに、身体の消耗が落ち着く先（0〜100）。
  ///
  /// コンディション（週ごとに上下する）とは別のもの。こちらは
  /// **何年その踏み込み方で来たか**を映し、衰え始めと重傷の重さを動かす。
  final double strain;
}

/// その週、誰と組むか。
///
/// 相方・メンター・競争相手は**試合の外で勝手に動く飾り**だった。
/// 週の選択に乗せて初めて、その人がクラブに居ることに意味が出る。
enum TrainingCompanion {
  alone(Say('一人でやる', 'On your own'), Say('自分の型で黙々と。大成功は出ないが、空回りもしない', 'Your own way, head down. No breakthroughs, but no wasted weeks either')),
  partner(Say('相方と組む', 'With your partner'), Say('呼吸が合う。手応えが出やすく、呼吸も深まる', 'You read each other. Good weeks come easily, and the understanding deepens')),
  mentor(Say('メンターに付く', 'With your mentor'), Say('年長者から盗む。手応えが出やすく、身体も残る', 'Learning from an older head. Good weeks come easily, and the body holds up')),
  rival(Say('競争相手と張り合う', 'Against your rival'), Say('一番手応えが出る。そのぶん消耗し、怪我もしやすい', 'The best weeks of all. It costs more condition, and the injury risk is higher'));

  const TrainingCompanion(Say label, Say description)
    : _label = label,
      _description = description;

  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;

  /// 誰と組むかで動く、大成功の出やすさ。
  double get greatBonus => switch (this) {
    TrainingCompanion.alone => 0,
    TrainingCompanion.partner => 0.08,
    TrainingCompanion.mentor => 0.10,
    TrainingCompanion.rival => 0.14,
  };

  /// 空回りの減り方（引く値）。
  ///
  /// **「一人でやる」は全指標で最下位だった**（実測ピーク 74.7 / 大成功 40 で、
  /// 組む3つはどれも上）。誰とも組まない週に固有の見返りが無かった。
  /// 大成功は出ないが崩れもしない——振れ幅の小さいほうを選ぶ手にする。
  double get flatRelief => switch (this) {
    TrainingCompanion.alone => 0.05,
    TrainingCompanion.partner => 0.025,
    TrainingCompanion.mentor => 0.025,
    TrainingCompanion.rival => 0.015,
  };

  /// 身体の消耗の落ち着き先を、どれだけ動かすか。
  double get strainShift => switch (this) {
    TrainingCompanion.alone => 0,
    TrainingCompanion.partner => 0,
    TrainingCompanion.mentor => -8,
    TrainingCompanion.rival => 10,
  };

  /// 消耗の増え方。誰かと組めば、その人の時間にも付き合うことになる。
  ///
  /// ここを 1.0 のままにすると、組める相手が居る限り
  /// 「一人でやる」を選ぶ理由が一つも無くなる。
  double get cost => switch (this) {
    TrainingCompanion.alone => 1.0,
    TrainingCompanion.partner => 1.15,
    TrainingCompanion.mentor => 1.15,
    TrainingCompanion.rival => 1.35,
  };

  /// 怪我のしやすさ。年長者は無理をしない。張り合うと引けなくなる。
  double get injury => switch (this) {
    TrainingCompanion.alone => 1.0,
    TrainingCompanion.partner => 1.0,
    TrainingCompanion.mentor => 0.8,
    TrainingCompanion.rival => 1.5,
  };

  /// **組んだ週に、ピッチの外で積むもの。**
  ///
  /// ここを持たせる前は、相方の呼吸・メンターのプロ意識・競争相手の立場が
  /// `CareerController._applyCompanion` の switch にだけ書いてあった。
  /// 選択肢の値打ちがその選択肢の外に散っていると、**表を読んでも
  /// 何が得られるのか分からず、検査も見つけられない**
  /// （`test/choice_balance_test.dart` は「相方と組む」が
  /// 「メンターに付く」に全項目で劣ると誤検出していた）。
  int get synergyGain => switch (this) {
    TrainingCompanion.partner => Formulas.companionSynergyGain,
    _ => 0,
  };

  /// 組んだ週に、プロ意識が1上がる確率。
  double get professionalismChance => switch (this) {
    TrainingCompanion.mentor => Formulas.mentorProfessionalismChance,
    _ => 0,
  };

  /// 組んだ週に上がる、ロッカールームでの立場。
  int get teammatesGain => switch (this) {
    TrainingCompanion.rival => Formulas.companionTeammatesGain,
    _ => 0,
  };

  /// その相手がクラブに居るか。居ない相手とは組めない。
  TeammateKind? get needs => switch (this) {
    TrainingCompanion.alone => null,
    TrainingCompanion.partner => TeammateKind.partner,
    TrainingCompanion.mentor => TeammateKind.mentor,
    TrainingCompanion.rival => TeammateKind.rival,
  };
}

/// その週の手応え。
///
/// 練習は「伸びたか伸びなかったか」しか出ていなかった。
/// 伸びなかった週が、運が悪かったのか踏み込みが足りなかったのかも分からない。
enum TrainingOutcome {
  great(Say('大成功', 'A great week'), Say('いつもより深く入った', 'You went deeper than usual')),
  good(Say('手応えあり', 'A good week'), Say('いつもどおり積んだ', 'You put in the usual work')),
  flat(Say('空回り', 'A wasted week'), Say('身体が言うことを聞かなかった', 'Your body would not do what you asked'));

  const TrainingOutcome(Say label, Say description)
    : _label = label,
      _description = description;

  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;

  /// 伸びの抽選を何回引くか。大成功なら2回、空回りなら0回。
  int get rolls => switch (this) {
    TrainingOutcome.great => 2,
    TrainingOutcome.good => 1,
    TrainingOutcome.flat => 0,
  };
}

/// 1週間の練習メニュー。
///
/// カテゴリを直接選ばせるのをやめ、「何をする1週間か」で選ばせる。
/// 単科は狙った所が確実に伸び、複合は2か所に触れる代わりに疲れる。
/// どちらが得かが状況で変わるから、毎週の選択に意味が出る。
enum TrainingMenu {
  rest(
    Say('休養', 'Rest'),
    Say('完全に休む。コンディションが戻り、溜まった疲労も抜ける', 'Complete rest. Condition comes back, and built-up fatigue clears'),
    [],
    conditionCost: 0,
    recovery: 30,
    fatigueRelief: Formulas.restFatigueRelief,
  ),
  lightWork(
    Say('リカバリー', 'Recovery'),
    Say('軽く流す。しっかり戻して怪我も遠ざけるが、疲労は抜けない', 'Light work. Good recovery and fewer injuries, but fatigue stays'),
    [],
    conditionCost: 0,
    recovery: 38,
    injuryFactor: 0.6,
  ),
  sprint(
    Say('スプリント', 'Sprints'),
    Say('スピードを上げる', 'Get quicker'),
    [AttributeKey.pace],
    conditionCost: 12,
    growthFactor: 1.1,
  ),
  strengthWork(
    Say('ウェイト', 'Weights'),
    Say('当たりに強くなる', 'Stand up to contact'),
    [AttributeKey.physical],
    conditionCost: 12,
    growthFactor: 1.1,
    injuryFactor: 1.2,
  ),
  finishingWork(
    Say('シュート', 'Shooting'),
    Say('枠に飛ばす回数を増やす', 'Hit the target more often'),
    [AttributeKey.shooting],
    conditionCost: 10,
    growthFactor: 1.1,
  ),
  technique(
    Say('テクニック', 'Technique'),
    Say('ボールを止めて運ぶ', 'Control it and carry it'),
    [AttributeKey.dribbling],
    conditionCost: 10,
    growthFactor: 1.1,
  ),
  passingWork(
    Say('パス＆コントロール', 'Passing and control'),
    Say('味方に届ける', 'Find your teammates'),
    [AttributeKey.passing],
    conditionCost: 10,
    growthFactor: 1.1,
  ),
  defenceWork(
    Say('守備', 'Defending'),
    Say('奪う・止める', 'Win it and stop it'),
    [AttributeKey.defending],
    conditionCost: 11,
    growthFactor: 1.1,
  ),
  keeperWork(
    Say('GK専門', 'Goalkeeping'),
    Say('ゴール前の技術', 'The craft of the six-yard box'),
    [AttributeKey.goalkeeping],
    conditionCost: 11,
    growthFactor: 1.1,
  ),
  athletic(
    Say('フィジカル総合', 'Full physical'),
    Say('走力と当たりを同時に', 'Running and contact together'),
    [AttributeKey.pace, AttributeKey.physical],
    conditionCost: 16,
    growthFactor: 0.65,
    injuryFactor: 1.4,
  ),
  attacking(
    Say('攻撃練習', 'Attacking'),
    Say('シュートと仕掛けを合わせて', 'Shooting and taking players on'),
    [AttributeKey.shooting, AttributeKey.dribbling],
    conditionCost: 15,
    growthFactor: 0.65,
    injuryFactor: 1.2,
  ),
  tactical(
    Say('戦術・判断', 'Tactics and decisions'),
    Say('パスと守備の関係を詰める', 'Tighten passing and defending together'),
    [AttributeKey.passing, AttributeKey.defending],
    conditionCost: 14,
    growthFactor: 0.65,
  ),
  possession(
    Say('ポゼッション', 'Possession'),
    Say('運ぶ技術と配球を合わせて', 'Carrying and distribution together'),
    [AttributeKey.dribbling, AttributeKey.passing],
    conditionCost: 14,
    growthFactor: 0.65,
  ),
  weakFootWork(Say('逆足', 'Weaker foot'), Say('利き足でないほうだけを使う', 'Nothing but your other foot'), [], conditionCost: 10, weakFoot: true);

  const TrainingMenu(
    Say label,
    Say description,
    this.keys, {
    required this.conditionCost,
    this.recovery = 0,
    this.fatigueRelief = 0,
    this.growthFactor = 1.0,
    this.injuryFactor = 1.0,
    this.weakFoot = false,
  }) : _label = label,
       _description = description;

  final Say _label;
  final Say _description;

  String get label => _label.t;
  String get description => _description.t;

  /// 伸ばす対象。空なら休養系。
  final List<AttributeKey> keys;

  /// 消耗するコンディション。
  final int conditionCost;

  /// 回復するコンディション。
  final int recovery;

  /// **溜まった疲労が抜ける量。**
  ///
  /// 完全に休んだ週だけ抜ける（リカバリーでは抜けない）。
  /// ここを持たせる前は `CareerController` が
  /// `menu == TrainingMenu.rest` と名指しで比べていて、
  /// **表の上では「休養」が「リカバリー」に全項目で劣って見えていた**
  /// （回復が少なく、怪我も遠のかない）。選択肢の値打ちは
  /// その選択肢に書く。
  final int fatigueRelief;

  /// 伸びやすさの倍率。1つの枠あたりに掛かる。
  final double growthFactor;

  /// 怪我のしやすさの倍率。
  final double injuryFactor;

  /// 逆足を鍛えるメニューか。能力値ではなく利き足の精度が動く。
  final bool weakFoot;

  bool get isRest => keys.isEmpty && !weakFoot;
  bool get isCompound => keys.length >= 2;

  /// GK の練習は GK だけに出す。
  bool availableFor(Position position) =>
      !keys.contains(AttributeKey.goalkeeping) || position == Position.gk;

  /// カテゴリだけを持っていた頃の保存データを読むための対応表。
  /// 新しいキャリアの最初の練習。ポジションに合った単科。
  ///
  /// 既定を「休養」にしていたため、育成タブを開かない人は1年間なにも
  /// 練習していなかった（シミュレーションで平均評価 5.9 の選手が出た）。
  static TrainingMenu defaultFor(Position position) => switch (position) {
    Position.gk => TrainingMenu.keeperWork,
    Position.cb || Position.sb => TrainingMenu.defenceWork,
    Position.dm || Position.cm => TrainingMenu.tactical,
    Position.am || Position.wg => TrainingMenu.possession,
    Position.st => TrainingMenu.attacking,
  };

  static TrainingMenu forKey(AttributeKey key) => switch (key) {
    AttributeKey.pace => TrainingMenu.sprint,
    AttributeKey.shooting => TrainingMenu.finishingWork,
    AttributeKey.passing => TrainingMenu.passingWork,
    AttributeKey.dribbling => TrainingMenu.technique,
    AttributeKey.defending => TrainingMenu.defenceWork,
    AttributeKey.physical => TrainingMenu.strengthWork,
    AttributeKey.goalkeeping => TrainingMenu.keeperWork,
  };
}

/// 居残りで磨く専門技術。
enum SetPiece {
  freeKick('FK', Say('直接フリーキック', 'Free kicks')),
  penalty('PK', Say('ペナルティキック', 'Penalties')),
  corner('CK', Say('コーナーキック', 'Corners'));

  const SetPiece(this.label, Say description) : _description = description;

  /// 略称（FK・PK・CK）はどちらの言語でも同じ。
  final String label;

  final Say _description;

  String get description => _description.t;
}

/// セットプレーの精度 1〜99。
///
/// 通常の能力値と分けてあるのは、これが「チームの蹴る役」を決めるものだから。
/// 総合力には乗らないが、蹴る役を任されれば試合ごとに得点が増える。
class SetPieceSkills {
  const SetPieceSkills({
    this.freeKick = 20,
    this.penalty = 25,
    this.corner = 20,
  });

  final int freeKick;
  final int penalty;
  final int corner;

  static const int max = 99;

  int operator [](SetPiece piece) => switch (piece) {
    SetPiece.freeKick => freeKick,
    SetPiece.penalty => penalty,
    SetPiece.corner => corner,
  };

  SetPieceSkills bump(SetPiece piece, int delta) => SetPieceSkills(
    freeKick: _c(freeKick + (piece == SetPiece.freeKick ? delta : 0)),
    penalty: _c(penalty + (piece == SetPiece.penalty ? delta : 0)),
    corner: _c(corner + (piece == SetPiece.corner ? delta : 0)),
  );

  static int _c(int v) => v.clamp(1, max);

  /// 一番得意な種類。蹴る役はここで決まる。
  SetPiece get best =>
      SetPiece.values.reduce((a, b) => this[a] >= this[b] ? a : b);

  /// クラブでキッカーを任される水準。
  static const int takerThreshold = 55;

  /// クラブでキッカーを任されるか。
  bool get isTaker => this[best] >= takerThreshold;

  Map<String, dynamic> toJson() => {
    'freeKick': freeKick,
    'penalty': penalty,
    'corner': corner,
  };

  factory SetPieceSkills.fromJson(Map<String, dynamic>? json) => json == null
      ? const SetPieceSkills()
      : SetPieceSkills(
          freeKick: json['freeKick'] as int? ?? 20,
          penalty: json['penalty'] as int? ?? 25,
          corner: json['corner'] as int? ?? 20,
        );
}
