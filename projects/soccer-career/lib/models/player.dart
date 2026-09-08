import '../game/formulas.dart';
import 'aptitude.dart';
import 'attributes.dart';
import 'nationality.dart';
import 'personality.dart';
import 'physique.dart';
import 'traits.dart';
import 'training.dart';

/// プレイヤーが操作する選手。
class Player {
  const Player({
    required this.name,
    required this.age,
    required this.position,
    this.side = Side.center,
    required this.attributes,
    required this.potential,
    this.nationality = Nationality.unknown,
    this.personality = const Personality(
        confidence: 10, ambition: 10, professionalism: 10, temper: 10),
    Aptitude? aptitude,
    this.physique = const Physique(
        heightCm: Physique.baseHeight, weightKg: Physique.baseWeight),
    this.setPieces = const SetPieceSkills(),
    this.traits = const [],
    this.condition = Formulas.conditionMax,
  }) : aptitude = aptitude ?? const Aptitude({});

  final String name;
  final int age;
  final Position position;

  /// 立つ側。左右のある役割（SB / WG）だけが持つ。
  ///
  /// 利き足と合っていれば逆足の局面が減り、逆サイドなら増える代わりに
  /// 内へ切り込んでシュートを打てる。どちらが得かは選手による。
  final Side side;

  /// 「LSB」のような表示。中央の役割では記号が付かない。
  String get positionLabel => '${side.mark}${position.label}';

  /// 「左サイドバック」のような表示。
  String get positionName => side == Side.center
      ? position.fullName
      : '${side.label}${position.fullName}';

  /// 利き足と逆のサイドに立っているか。
  bool get isInverted => side.inverted(physique.foot);

  final Attributes attributes;

  /// 総合力の上限。ここまでしか伸びない。画面には帯でしか見せない。
  final int potential;

  /// 国籍。外国人枠と労働許可、代表資格に効く。
  final Nationality nationality;

  /// 性格。伸ばすものではなく、経験で少しずつ変わる。
  final Personality personality;

  /// 身体データ。練習では動かず、オフの肉体改造でだけ変わる。
  final Physique physique;

  /// セットプレーの精度。居残り練習で伸ばす。
  final SetPieceSkills setPieces;

  /// ポジション適性。本職以外で出ると、その分だけ力を出せない。
  final Aptitude aptitude;

  final List<Trait> traits;

  /// 0〜100。試合と練習で減り、休養で戻る。低いと試合の成功率が落ちる。
  final int condition;

  /// 総合力。今のポジションの適性ぶんを引く。
  ///
  /// 本職なら引かれない。慣れないポジションで出ている選手は、
  /// 同じ能力値でも同じようには働けない。
  int get overall =>
      attributes.overallFor(position) - aptitude.penaltyFor(position);

  /// 本来の（適性を引く前の）そのポジションでの力。
  int overallAt(Position position) =>
      attributes.overallFor(position) - aptitude.penaltyFor(position);

  /// カテゴリ単位の、身体の補正まで含めた能力値。
  int effectiveFor(AttributeKey key) {
    final ds = key.details;
    return (ds.fold(0, (s, d) => s + effective(d)) / ds.length).round();
  }

  /// 身体の補正まで含めた、試合で実際に出る能力値。
  ///
  /// 蓄えた能力値そのものは書き換えない。増量した週に「伸びた」ように
  /// 見えてしまうと、練習で積み上げた数字の意味が濁る。
  int effective(Detail detail) => (attributes.detail(detail) +
          physique.bonusFor(detail))
      .clamp(Formulas.minAttribute, Formulas.maxAttribute)
      .toInt();

  bool get atPotential => overall >= potential;

  /// ポテンシャルの見せ方。数値そのものは隠す。
  String get potentialBand {
    final headroom = potential - overall;
    if (potential >= 88) return '別格';
    if (potential >= 80) return '高い';
    if (headroom >= 15) return '伸びしろ大';
    if (headroom >= 6) return '普通';
    return '頭打ち';
  }

  Player copyWith({
    int? age,
    Attributes? attributes,
    Position? position,
    Side? side,
   
    int? condition,
    Nationality? nationality,
    Personality? personality,
    Physique? physique,
    SetPieceSkills? setPieces,
    Aptitude? aptitude,
  }) =>
      Player(
        name: name,
        age: age ?? this.age,
        position: position ?? this.position,
        side: side ?? this.side,
        attributes: attributes ?? this.attributes,
        potential: potential,
        nationality: nationality ?? this.nationality,
        personality: personality ?? this.personality,
        physique: physique ?? this.physique,
        setPieces: setPieces ?? this.setPieces,
        aptitude: aptitude ?? this.aptitude,
        traits: traits,
        condition: (condition ?? this.condition)
            .clamp(0, Formulas.conditionMax)
            .toInt(),
      );

  /// ポテンシャルまで含めて作り直す。重傷の後遺症で使う。
  ///
  /// copyWith にポテンシャルを足さないのは、通常の成長で誤って
  /// 上限をいじれてしまうのを防ぐため。ここを通るのは怪我だけ。
  static Player rebuild(
    Player from, {
    required Attributes attributes,
    required int potential,
  }) =>
      Player(
        name: from.name,
        age: from.age,
        position: from.position,
        attributes: attributes,
        potential: potential,
        nationality: from.nationality,
        personality: from.personality,
        physique: from.physique,
        setPieces: from.setPieces,
        aptitude: from.aptitude,
        traits: from.traits,
        condition: from.condition,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'position': position.name,
        'side': side.name,
        'attributes': attributes.toJson(),
        'potential': potential,
        'nationality': nationality.toJson(),
        'personality': personality.toJson(),
        'physique': physique.toJson(),
        'setPieces': setPieces.toJson(),
        'aptitude': aptitude.toJson(),
        'traits': traits.map((t) => t.name).toList(),
        'condition': condition,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final attributes =
        Attributes.fromJson(json['attributes'] as Map<String, dynamic>);
    final position = Position.parse(json['position'] as String);
    final physique = Physique.fromJson(json['physique'] as Map<String, dynamic>?);
    return Player(
      name: json['name'] as String,
      age: json['age'] as int,
      position: position,
      // 左右を持たせる前の保存データは、利き足に合う側として読む。
      // 既定で右に寄せると、左利きのサイドバックが急に不利になる。
      side: json['side'] == null
          ? (position.hasSide
              ? (physique.foot == Foot.left ? Side.left : Side.right)
              : Side.center)
          : Side.parse(json['side'] as String?),
      attributes: attributes,
      // ポテンシャルを足す前の保存データには無い。今の総合力に少し上乗せする。
      potential: json['potential'] as int? ??
          (attributes.overallFor(position) + 8),
      // 国籍を持たせる前の保存データは、既定の国の選手として読む。
      nationality: Nationality.fromJson(
          json['nationality'] as Map<String, dynamic>?, 'yamato'),
      personality:
          Personality.fromJson(json['personality'] as Map<String, dynamic>?),
      // 身体データを持たせる前の保存データは標準体型として読む。
      physique: physique,
      setPieces:
          SetPieceSkills.fromJson(json['setPieces'] as Map<String, dynamic>?),
      // 適性を持たせる前の保存データは、今のポジションを本職として読む。
      aptitude: Aptitude.fromJson(
          json['aptitude'] as Map<String, dynamic>?, position),
      traits: [
        for (final n in (json['traits'] as List? ?? const []))
          if (Trait.values.any((t) => t.name == n))
            Trait.values.byName(n as String),
      ],
      condition: json['condition'] as int? ?? Formulas.conditionMax,
    );
  }
}
