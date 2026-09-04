import 'club_infrastructure.dart';
import '../l10n/tr.dart';

/// スタッフの能力値(1-20)。
///
/// 役職ごとに「効く能力」が違う。見極めの高いヘッドコーチも、指導の高い
/// スカウトも仕事の役には立たない。誰をどの役職に置くかが判断になるよう、
/// 能力は共通の4項目にしてある。
enum StaffAttribute { coaching, judging, medical, motivating }

extension StaffAttributeInfo on StaffAttribute {
  String get label => switch (this) {
        StaffAttribute.coaching => Tr.pick('指導', 'Coaching'),
        StaffAttribute.judging => Tr.pick('見極め', 'Judging ability'),
        StaffAttribute.medical => Tr.pick('医療', 'Physiotherapy'),
        StaffAttribute.motivating => Tr.pick('動機づけ', 'Motivating'),
      };

  String get description => switch (this) {
        StaffAttribute.coaching => Tr.pick(
            'トレーニングで選手をどれだけ伸ばせるか。ヘッドコーチ・ユースコーチ・フィットネスコーチに効く。',
            'How much players gain from training. Matters for the head coach, youth coach and fitness coach.'),
        StaffAttribute.judging => Tr.pick(
            '選手の実力と伸びしろを見抜く精度。スカウトとユースコーチに効く。',
            'How accurately he reads a player\'s ability and potential. Matters for scouts and the youth coach.'),
        StaffAttribute.medical => Tr.pick('負傷の予防と療養の早さ。フィジオに効く。',
            'Injury prevention and recovery speed. Matters for the physio.'),
        StaffAttribute.motivating => Tr.pick(
            '選手の士気を引き上げる力。どの役職でも少しずつ効く。',
            'How well he lifts morale. Matters a little in every role.'),
      };
}

/// 役職ごとに、仕事の質を決める能力。ここに無い能力はその役職では働かない。
Map<StaffAttribute, int> staffRoleWeights(StaffRole role) => switch (role) {
      StaffRole.headCoach => const {
          StaffAttribute.coaching: 3,
          StaffAttribute.motivating: 1,
        },
      StaffRole.fitnessCoach => const {
          StaffAttribute.coaching: 3,
          StaffAttribute.medical: 1,
        },
      StaffRole.youthCoach => const {
          StaffAttribute.coaching: 2,
          StaffAttribute.judging: 2,
        },
      StaffRole.scout => const {
          StaffAttribute.judging: 3,
          StaffAttribute.motivating: 1,
        },
      StaffRole.physio => const {
          StaffAttribute.medical: 3,
          StaffAttribute.motivating: 1,
        },
    };

/// クラブに雇うスタッフ1人。
class StaffMember {
  final String id;
  final String name;
  final int age;

  /// 就いている役職。空席のときはクラブ側が null で持つ。
  final StaffRole role;

  /// 1-20 の能力値。
  final Map<StaffAttribute, int> attributes;

  /// 週俸(万円)。契約時に確定し、以後は変わらない。
  final int wage;

  /// 残り契約年数。0になると契約満了で去る。
  int contractYears;

  StaffMember({
    required this.id,
    required this.name,
    required this.age,
    required this.role,
    required this.attributes,
    required this.wage,
    this.contractYears = 2,
  });

  int attribute(StaffAttribute a) => attributes[a] ?? 1;

  /// この役職での仕事の質(1-20)。役職に関係ある能力だけの加重平均。
  ///
  /// スカウトに指導20の人を置いても、見極めが低ければ質は上がらない。
  double get roleAbility {
    final weights = staffRoleWeights(role);
    var sum = 0.0;
    var total = 0;
    for (final e in weights.entries) {
      sum += attribute(e.key) * e.value;
      total += e.value;
    }
    return total == 0 ? 1 : sum / total;
  }

  /// 既存の仕組みが使っている 1-8 のレベルへ変換する。
  ///
  /// トレーニング効率・負傷率・スカウトの質などは、すべてこのレベルを見て
  /// 決まっている。人に置き換えても、そこから先の計算は変えなくて済む。
  int get effectiveLevel {
    final level = ((roleAbility - 1) / 19 * (ClubInfrastructure.maxLevel - 1))
            .round() +
        1;
    return level.clamp(1, ClubInfrastructure.maxLevel);
  }

  /// 能力に見合った週俸の相場。交渉は行わず、この額で受けるかどうかだけ。
  static int askingWage(double roleAbility) =>
      (10 + roleAbility * roleAbility * 0.9).round();

  /// この能力のスタッフが、その規模のクラブの誘いを受けるか。
  ///
  /// 5部のクラブに指導20のコーチは来ない。良いスタッフを雇えること自体が
  /// クラブを大きくした見返りになる。
  static bool willJoin({
    required double roleAbility,
    required int divisionTier,
    required int confidence,
  }) {
    // ティアが上(数字が小さい)ほど、高い能力のスタッフが応じる。
    final ceiling = 22 - divisionTier * 2.5 + (confidence - 50) / 25;
    return roleAbility <= ceiling;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'role': role.name,
        'attributes': {
          for (final e in attributes.entries) e.key.name: e.value,
        },
        'wage': wage,
        'contractYears': contractYears,
      };

  static StaffMember fromJson(Map<String, dynamic> json) {
    final rawAttrs = (json['attributes'] as Map?) ?? const {};
    return StaffMember(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      role: StaffRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => StaffRole.headCoach,
      ),
      attributes: {
        for (final a in StaffAttribute.values)
          a: (rawAttrs[a.name] as int?) ?? 1,
      },
      wage: json['wage'] as int,
      contractYears: json['contractYears'] as int? ?? 2,
    );
  }
}
