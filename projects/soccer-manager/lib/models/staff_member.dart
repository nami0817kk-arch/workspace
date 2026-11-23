import '../logic/manager_hr_engine.dart';
import 'club_infrastructure.dart';
import 'manager_profile.dart';
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
            'How much players gain from training. Matters for the first-team coach, youth coach and fitness coach.'),
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
      StaffRole.manager => const {
          StaffAttribute.judging: 2,
          StaffAttribute.coaching: 1,
          StaffAttribute.motivating: 1,
        },
      StaffRole.sportingDirector => const {
          StaffAttribute.judging: 3,
          StaffAttribute.motivating: 1,
        },
    };


/// スタッフの得意分野。
///
/// 能力値(1-20)は「どれだけ上手いか」しか表さないため、誰を雇っても
/// 育つ能力が同じだった。得意分野を持たせると、「攻撃を伸ばせる
/// ユースコーチ」と「守備を仕込めるユースコーチ」のどちらを取るか、という
/// 判断が生まれる。
enum StaffSpecialty { balanced, attacking, defending, goalkeeping, physical }

extension StaffSpecialtyInfo on StaffSpecialty {
  String get label => switch (this) {
        StaffSpecialty.balanced => Tr.pick('万能', 'All-round'),
        StaffSpecialty.attacking => Tr.pick('攻撃', 'Attacking'),
        StaffSpecialty.defending => Tr.pick('守備', 'Defending'),
        StaffSpecialty.goalkeeping => Tr.pick('GK', 'Goalkeeping'),
        StaffSpecialty.physical => Tr.pick('フィジカル', 'Physical'),
      };

  String get description => switch (this) {
        StaffSpecialty.balanced =>
          Tr.pick('特定の分野に偏らない。どの選手にも同じだけ効く。',
              'No particular leaning. Works the same for every player.'),
        StaffSpecialty.attacking => Tr.pick('得点に関わる能力を重点的に伸ばす。',
            'Pushes the attributes that put the ball in the net.'),
        StaffSpecialty.defending => Tr.pick('守備に関わる能力を重点的に伸ばす。',
            'Pushes the defensive side of the game.'),
        StaffSpecialty.goalkeeping => Tr.pick('ゴールキーパーの能力を重点的に伸ばす。',
            'Pushes goalkeeping, and only that.'),
        StaffSpecialty.physical => Tr.pick('走力・強さ・スタミナを重点的に伸ばす。',
            'Pushes running power, strength and stamina.'),
      };
}

/// クラブに雇うスタッフ1人。
class StaffMember {
  final String id;
  final String name;
  final int age;

  /// 就いている役職。空席のときはクラブ側が null で持つ。
  final StaffRole role;

  /// 1-20 の能力値。
  final Map<StaffAttribute, int> attributes;

  /// 週俸(万円)。契約時に決まる。引き抜きを断って残すときだけ上がる。
  int wage;

  /// 残り契約年数。0になると契約満了で去る。
  int contractYears;

  /// 得意分野。旧セーブには無いため、読み込み時は[StaffSpecialty.balanced]。
  final StaffSpecialty specialty;

  /// 監督だけが持つもの(考え方・好みの布陣・経歴・今の所属)。監督以外は null。
  ManagerProfile? manager;

  /// 自クラブで引退した選手なら、その選手の id(元選手の印)。
  final String? formerPlayerId;

  StaffMember({
    required this.id,
    required this.name,
    required this.age,
    required this.role,
    required this.attributes,
    required this.wage,
    this.contractYears = 2,
    this.specialty = StaffSpecialty.balanced,
    this.manager,
    this.formerPlayerId,
  });

  int attribute(StaffAttribute a) => attributes[a] ?? 1;

  /// 監督以外の役職の、解任の違約金の率(残りの契約の週俸に対して)。
  static const double staffSeveranceRate = 0.2;

  /// 解任の違約金の率。監督は[ManagerHrEngine.managerSeveranceRate]
  /// (全額。実在のクラブと同じ)、他の役職は[staffSeveranceRate]。
  double get severanceRate => role == StaffRole.manager
      ? ManagerHrEngine.managerSeveranceRate
      : staffSeveranceRate;

  /// 契約が満了する日(最後の季の6月30日)。[seasonEndYear]は今の季が
  /// 終わる年。[contractYears]は季の切り替わりで1つ減り、0で去るので、
  /// 残り1なら今の季の終わりで満了する。
  DateTime contractEndDate(int seasonEndYear) =>
      DateTime.utc(seasonEndYear + contractYears - 1, 6, 30);

  /// 今日[today]から満了日までの週数(切り上げ)。
  int weeksLeftOn(DateTime today, int seasonEndYear) {
    if (contractYears <= 0) return 0;
    final from = DateTime.utc(today.year, today.month, today.day);
    final days = contractEndDate(seasonEndYear).difference(from).inDays;
    if (days <= 0) return 0;
    return (days / 7).ceil();
  }

  /// 今日[today]に契約の途中で解任するときの違約金(万円)。残りの契約の
  /// 週俸(満了までの週数ぶん)に[severanceRate]を掛けたもの。契約が
  /// 切れていれば掛からない。
  ///
  /// 以前は残りを年単位で数えていて、5月に解任しても1年分払っていた。
  int severanceOn(DateTime today, int seasonEndYear) =>
      (wage * weeksLeftOn(today, seasonEndYear) * severanceRate).round();

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
  int get effectiveLevel => levelFromAbility(roleAbility);

  /// 1-20 の能力を 1-8 のレベルへ直す。
  static int levelFromAbility(double ability) {
    final level =
        ((ability - 1) / 19 * (ClubInfrastructure.maxLevel - 1)).round() + 1;
    return level.clamp(1, ClubInfrastructure.maxLevel);
  }

  /// 能力1つぶんのレベル(1-8)。
  ///
  /// 役職の総合力([effectiveLevel])は複数の能力を混ぜた値なので、
  /// 「見極めが高いほど見立てが正確」のように能力ごとに効かせたい仕事には
  /// 使えない。混ぜたまま使うと、指導だけが高い人でも見立てが鋭くなる。
  int levelOf(StaffAttribute a) => levelFromAbility(attribute(a).toDouble());

  /// 能力に見合った週俸の相場。交渉は行わず、この額で受けるかどうかだけ。
  ///
  /// 選手より安い。以前は `10 + 能力^2 * 0.9` で、能力8のコーチが週俸68
  /// (=5部の主力選手より高い)になり、給与予算の余裕(実測64)を1人で
  /// 使い切っていた。5つの役職があるのに1人しか雇えない状態だった。
  ///
  /// 裏方の待遇は選手ほど高くない、という当たり前の形に直す。
  static int askingWage(double roleAbility) =>
      (4 + roleAbility * roleAbility * 0.25).round();

  /// その規模のクラブに来るスタッフの、おおよその能力。
  ///
  /// 理事会がスタッフ人件費を見積もるのに使う(BoardEngine)。willJoin と
  /// 同じ式から導くので、実際に雇える人材と見積もりがずれない。
  static double expectedAbilityForTier(int divisionTier) =>
      (22 - divisionTier * 2.5 - 2).clamp(3, 20);

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
        'specialty': specialty.name,
        if (manager != null) 'manager': manager!.toJson(),
        if (formerPlayerId != null) 'formerPlayerId': formerPlayerId,
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
      specialty: StaffSpecialty.values.firstWhere(
        (v) => v.name == json['specialty'],
        orElse: () => StaffSpecialty.balanced,
      ),
      manager: json['manager'] is Map
          ? ManagerProfile.fromJson(
              (json['manager'] as Map).cast<String, dynamic>())
          : null,
      formerPlayerId: json['formerPlayerId'] as String?,
    );
  }
}
