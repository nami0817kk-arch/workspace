import 'attributes.dart';

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
