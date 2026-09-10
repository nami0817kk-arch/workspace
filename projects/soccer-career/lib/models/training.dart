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
  easy('流す', '軽く。伸びは薄いが、身体が残る。衰え始めが遅くなる',
      great: 0.02, flat: 0.45, cost: 0.5, injury: 0.5, strain: 22),
  normal('普通', 'いつもどおり',
      great: 0.15, flat: 0.15, cost: 1.0, injury: 1.0, strain: 50),
  hard('追い込む', '限界まで。大きく伸びるが、消耗も怪我も跳ね上がる。'
      '続ければ衰えが早く来る',
      great: 0.45, flat: 0.10, cost: 1.9, injury: 1.8, strain: 86);

  const TrainingEffort(
    this.label,
    this.description, {
    required this.great,
    required this.flat,
    required this.cost,
    required this.injury,
    required this.strain,
  });

  final String label;
  final String description;

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
  alone('一人でやる', '自分の型で黙々と。大成功は出ないが、空回りもしない'),
  partner('相方と組む', '呼吸が合う。手応えが出やすく、呼吸も深まる'),
  mentor('メンターに付く', '年長者から盗む。手応えが出やすく、身体も残る'),
  rival('競争相手と張り合う', '一番手応えが出る。そのぶん消耗し、怪我もしやすい');

  const TrainingCompanion(this.label, this.description);

  final String label;

  final String description;

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
  great('大成功', 'いつもより深く入った'),
  good('手応えあり', 'いつもどおり積んだ'),
  flat('空回り', '身体が言うことを聞かなかった');

  const TrainingOutcome(this.label, this.description);

  final String label;
  final String description;

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
  rest('休養', '完全に休む。コンディションが戻り、溜まった疲労も抜ける', [],
      conditionCost: 0, recovery: 30),
  lightWork('リカバリー', '軽く流す。しっかり戻して怪我も遠ざけるが、疲労は抜けない',
      [],
      conditionCost: 0, recovery: 38, injuryFactor: 0.6),
  sprint('スプリント', 'スピードを上げる', [AttributeKey.pace],
      conditionCost: 12, growthFactor: 1.1),
  strengthWork('ウェイト', '当たりに強くなる', [AttributeKey.physical],
      conditionCost: 12, growthFactor: 1.1, injuryFactor: 1.2),
  finishingWork('シュート', '枠に飛ばす回数を増やす', [AttributeKey.shooting],
      conditionCost: 10, growthFactor: 1.1),
  technique('テクニック', 'ボールを止めて運ぶ', [AttributeKey.dribbling],
      conditionCost: 10, growthFactor: 1.1),
  passingWork('パス＆コントロール', '味方に届ける', [AttributeKey.passing],
      conditionCost: 10, growthFactor: 1.1),
  defenceWork('守備', '奪う・止める', [AttributeKey.defending],
      conditionCost: 11, growthFactor: 1.1),
  keeperWork('GK専門', 'ゴール前の技術', [AttributeKey.goalkeeping],
      conditionCost: 11, growthFactor: 1.1),
  athletic('フィジカル総合', '走力と当たりを同時に',
      [AttributeKey.pace, AttributeKey.physical],
      conditionCost: 16, growthFactor: 0.65, injuryFactor: 1.4),
  attacking('攻撃練習', 'シュートと仕掛けを合わせて',
      [AttributeKey.shooting, AttributeKey.dribbling],
      conditionCost: 15, growthFactor: 0.65, injuryFactor: 1.2),
  tactical('戦術・判断', 'パスと守備の関係を詰める',
      [AttributeKey.passing, AttributeKey.defending],
      conditionCost: 14, growthFactor: 0.65),
  possession('ポゼッション', '運ぶ技術と配球を合わせて',
      [AttributeKey.dribbling, AttributeKey.passing],
      conditionCost: 14, growthFactor: 0.65),
  weakFootWork('逆足', '利き足でないほうだけを使う', [],
      conditionCost: 10, weakFoot: true);

  const TrainingMenu(
    this.label,
    this.description,
    this.keys, {
    required this.conditionCost,
    this.recovery = 0,
    this.growthFactor = 1.0,
    this.injuryFactor = 1.0,
    this.weakFoot = false,
  });

  final String label;
  final String description;

  /// 伸ばす対象。空なら休養系。
  final List<AttributeKey> keys;

  /// 消耗するコンディション。
  final int conditionCost;

  /// 回復するコンディション。
  final int recovery;

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
  freeKick('FK', '直接フリーキック'),
  penalty('PK', 'ペナルティキック'),
  corner('CK', 'コーナーキック');

  const SetPiece(this.label, this.description);

  final String label;
  final String description;
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
        freeKick:
            _c(freeKick + (piece == SetPiece.freeKick ? delta : 0)),
        penalty: _c(penalty + (piece == SetPiece.penalty ? delta : 0)),
        corner: _c(corner + (piece == SetPiece.corner ? delta : 0)),
      );

  static int _c(int v) => v.clamp(1, max);

  /// 一番得意な種類。蹴る役はここで決まる。
  SetPiece get best => SetPiece.values
      .reduce((a, b) => this[a] >= this[b] ? a : b);

  /// クラブでキッカーを任される水準。
  static const int takerThreshold = 55;

  /// クラブでキッカーを任されるか。
  bool get isTaker => this[best] >= takerThreshold;

  Map<String, dynamic> toJson() =>
      {'freeKick': freeKick, 'penalty': penalty, 'corner': corner};

  factory SetPieceSkills.fromJson(Map<String, dynamic>? json) => json == null
      ? const SetPieceSkills()
      : SetPieceSkills(
          freeKick: json['freeKick'] as int? ?? 20,
          penalty: json['penalty'] as int? ?? 25,
          corner: json['corner'] as int? ?? 20,
        );
}
