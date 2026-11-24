import '../l10n/tr.dart';
import '../logic/staff_market.dart';
import 'staff_member.dart';

/// チケット価格戦略。値上げは1人あたり収入を増やす一方で観客動員率を下げ、
/// 値下げはその逆になる(合計の増収効果は保証されない)。
enum TicketPricing { budget, standard, premium }

extension TicketPricingInfo on TicketPricing {
  String get label => switch (this) {
        TicketPricing.budget => Tr.pick('低価格', 'Cheap'),
        TicketPricing.standard => Tr.pick('標準', 'Standard'),
        TicketPricing.premium => Tr.pick('高価格', 'Expensive'),
      };

  String get description => switch (this) {
        TicketPricing.budget => Tr.pick('観客動員率+15%だが、1人あたり収入-25%',
            'Attendance +15%, but revenue per head -25%'),
        TicketPricing.standard => Tr.pick('標準の価格設定', 'The standard pricing'),
        TicketPricing.premium => Tr.pick('1人あたり収入+30%だが、観客動員率-20%',
            'Revenue per head +30%, but attendance -20%'),
      };

  /// 観客動員率に対する倍率。
  double get attendanceMultiplier => switch (this) {
        TicketPricing.budget => 1.15,
        TicketPricing.standard => 1.0,
        TicketPricing.premium => 0.8,
      };

  /// 試合収入(観客動員数に依存する部分)に対する倍率。
  double get revenueMultiplier => switch (this) {
        TicketPricing.budget => 0.75,
        TicketPricing.standard => 1.0,
        TicketPricing.premium => 1.3,
      };
}

/// [manager] はオーナーが雇う監督。毎試合の先発と構えを決める。
enum StaffRole {
  headCoach,
  scout,
  physio,
  youthCoach,
  fitnessCoach,
  manager,

  /// スポーツディレクター。移籍の交渉を任せられ、見極めが高いほど安くまとめる。
  sportingDirector,
}

extension StaffRoleInfo on StaffRole {
  String get label => switch (this) {
        StaffRole.headCoach => Tr.pick('ヘッドコーチ', 'First-Team Coach'),
        StaffRole.scout => Tr.pick('スカウト', 'Scout'),
        StaffRole.physio => Tr.pick('フィジオ', 'Physio'),
        StaffRole.youthCoach => Tr.pick('ユースコーチ', 'Youth Coach'),
        StaffRole.fitnessCoach => Tr.pick('フィットネスコーチ', 'Fitness Coach'),
        StaffRole.manager => Tr.pick('監督', 'Manager'),
        StaffRole.sportingDirector =>
          Tr.pick('スポーツディレクター', 'Director of Football'),
      };

  String get description => switch (this) {
        StaffRole.headCoach => Tr.pick(
            'トレーニングの成長効率を高める', 'Raises how much players gain from training'),
        StaffRole.scout => Tr.pick('スカウト選手の質を高め、費用を抑える',
            'Raises the quality of scouted players and lowers the cost'),
        StaffRole.physio => Tr.pick('負傷の発生率と療養期間を減らす',
            'Cuts how often injuries happen and how long they last'),
        // 見極めと指導で仕事が違う唯一の役職。どちらも要るが、揃えると高い。
        StaffRole.youthCoach => Tr.pick('見極めで良い子を集めて見立て、指導でアカデミー生を伸ばす',
            'Judging brings in and reads the youngsters; coaching develops them'),
        StaffRole.fitnessCoach => Tr.pick('週次トレーニングでの疲労回復量をさらに高める',
            'Further increases how much fatigue the weekly training recovers'),
        StaffRole.manager => Tr.pick(
            '毎試合の先発と構えを決める。試合はすべて監督に任せる',
            'Picks the XI and approach for every match; the matches are his to run'),
        StaffRole.sportingDirector => Tr.pick(
            '補強の交渉を任せられる(クラブとも選手とも)。見極めが高いほど言い値を安くまとめる',
            'Can run your transfer negotiations, with clubs and players. Better judging means lower prices'),
      };
}

enum FacilityType {
  trainingGround,
  stadium,
  youthFacility,
  commercialFacility,
  medicalCenter,
}

extension FacilityTypeInfo on FacilityType {
  String get label => switch (this) {
        FacilityType.trainingGround =>
          Tr.pick('トレーニング施設', 'Training Facilities'),
        FacilityType.stadium => Tr.pick('スタジアム', 'Stadium'),
        FacilityType.youthFacility => Tr.pick('ユース施設', 'Youth Facilities'),
        FacilityType.commercialFacility =>
          Tr.pick('商業施設', 'Commercial Facilities'),
        FacilityType.medicalCenter => Tr.pick('メディカルセンター', 'Medical Centre'),
      };

  String get description => switch (this) {
        FacilityType.trainingGround => Tr.pick(
            '選手の成長速度と疲労回復を高める', 'Speeds up player growth and fatigue recovery'),
        FacilityType.stadium =>
          Tr.pick('試合ごとの観客収入を増やす', 'Increases gate receipts from each match'),
        FacilityType.youthFacility => Tr.pick('ユース昇格候補の受け入れ枠を増やし、ユースでの伸びを速める',
            'Takes on more academy prospects and helps them develop faster'),
        FacilityType.commercialFacility => Tr.pick('スポンサー・グッズ収入と、上限までの観客収入を底上げする',
            'Lifts sponsorship and merchandise, and gate receipts up to their ceiling'),
        FacilityType.medicalCenter => Tr.pick('フィジオの効果と合わせて負傷リスク・療養期間をさらに減らす',
            'Works with your physio to cut injury risk and recovery time further'),
      };
}

/// クラブの施設レベル(1-8)と、雇っているスタッフ。ユーザークラブにのみ
/// 適用される。
///
/// スタッフは以前「役職ごとのレベル数値」だった。金を払えば誰でも同じだけ
/// 上がる仕組みで、誰を雇うかという判断が無かった。いまは人を雇う形にして、
/// 仕事の質はその人の能力から決まる。
class ClubInfrastructure {
  static const int maxLevel = 8;

  /// 役職ごとに雇っているスタッフ(その役職の主任)。空席なら null。
  final Map<StaffRole, StaffMember?> staff;

  /// 主任の下に雇っている人(複数人雇える役職だけ。2026-11-25 の第6段)。
  ///
  /// FM のように、スカウト・フィジオ・ユースコーチ・フィットネスコーチは
  /// 何人か雇える。監督・SD・ヘッドコーチは1人。人数の上限はクラブの部と
  /// 施設で決まる([maxStaffFor])。効き目は人数で逓減する([combinedAbility])。
  final Map<StaffRole, List<StaffMember>> assistants;
  final Map<FacilityType, int> facilityLevels;

  /// 工事中の施設と、完成する日。完成するまでレベルは上がらない(効き目も
  /// 出ない)。工事中の施設は重ねて増築できない。
  final Map<FacilityType, DateTime> construction;

  ClubInfrastructure({
    Map<StaffRole, StaffMember?>? staff,
    Map<StaffRole, List<StaffMember>>? assistants,
    Map<FacilityType, int>? facilityLevels,
    Map<FacilityType, DateTime>? construction,
  })  : staff = staff ?? {for (final r in StaffRole.values) r: null},
        assistants = assistants ?? {},
        facilityLevels =
            facilityLevels ?? {for (final f in FacilityType.values) f: 1},
        construction = construction ?? {};

  /// [type] が工事中なら完成する日。工事中でなければ null。
  DateTime? constructionReadyOn(FacilityType type) => construction[type];

  bool isUnderConstruction(FacilityType type) => construction.containsKey(type);

  StaffMember? staffFor(StaffRole role) => staff[role];

  /// 複数人を雇える役職か。監督・SD・ヘッドコーチは1人だけ。
  static bool roleAllowsMany(StaffRole role) => switch (role) {
        StaffRole.scout ||
        StaffRole.physio ||
        StaffRole.youthCoach ||
        StaffRole.fitnessCoach =>
          true,
        StaffRole.headCoach ||
        StaffRole.manager ||
        StaffRole.sportingDirector =>
          false,
      };

  /// 1つの役職に雇える人数の上限。
  static const int maxPerRole = 4;

  /// [role] に雇える人数の上限。クラブの部([divisionTier]、1が最上)と、
  /// その役職の仕事場になる施設のレベルで増える(スカウトは施設が要らない
  /// ので、施設の分は1人ぶん付けておく)。
  int maxStaffFor(StaffRole role, {required int divisionTier}) {
    if (!roleAllowsMany(role)) return 1;
    final tierBonus = divisionTier <= 1
        ? 2
        : divisionTier <= 3
            ? 1
            : 0;
    final facility = switch (role) {
      StaffRole.physio => facilityLevel(FacilityType.medicalCenter),
      StaffRole.youthCoach => facilityLevel(FacilityType.youthFacility),
      StaffRole.fitnessCoach => facilityLevel(FacilityType.trainingGround),
      _ => 3,
    };
    final facilityBonus = facility >= 6
        ? 2
        : facility >= 3
            ? 1
            : 0;
    return (1 + tierBonus + facilityBonus).clamp(1, maxPerRole);
  }

  /// [role] に就いている全員(主任が先)。
  List<StaffMember> membersFor(StaffRole role) => [
        if (staff[role] != null) staff[role]!,
        ...?assistants[role],
      ];

  /// [role] の人数。
  int headcount(StaffRole role) => membersFor(role).length;

  /// 雇っている全員。
  Iterable<StaffMember> get allStaff sync* {
    for (final r in StaffRole.values) {
      yield* membersFor(r);
    }
  }

  /// 2人目からの上乗せの割合。2人目は能力の3割、3人目はその半分…と逓減する。
  static const double extraStaffShare = 0.3;

  /// 同じ役職の何人かの能力(1-20)をまとめた、役職としての仕事の質(1-20)。
  /// いちばん高い人の能力に、2人目からを逓減して足す(上限20)。
  ///
  /// 「良い人が来ない部でも人数で補える。ただし1人の名手には及ばない」を
  /// 数字にしたもの(FM のスタッフの人数と同じ考え)。
  static double combinedAbility(Iterable<double> abilities) {
    final list = abilities.toList()..sort((a, b) => b.compareTo(a));
    if (list.isEmpty) return 1;
    var total = list.first;
    var share = extraStaffShare;
    for (final a in list.skip(1)) {
      total += a * share;
      share /= 2;
    }
    return total.clamp(1, 20).toDouble();
  }

  /// その役職の仕事の質(1-8)。空席なら1(=最低限、下部リーグの兼任扱い)。
  ///
  /// トレーニング効率・負傷率・スカウトの質などは以前からこの数値を見て
  /// 決まっている。人に置き換えても、そこから先の計算は変わらない。
  /// 複数人いるときは[combinedAbility]でまとめる(1人なら以前と同じ値)。
  int staffLevel(StaffRole role) {
    final members = membersFor(role);
    if (members.isEmpty) return 1;
    if (members.length == 1) return members.first.effectiveLevel;
    return StaffMember.levelFromAbility(
        combinedAbility(members.map((m) => m.roleAbility)));
  }

  /// その役職に就いている人の、能力1つぶんのレベル(1-8)。空席なら1。
  ///
  /// 役職の総合力ではなく特定の能力だけを見る仕事に使う(ユースコーチの
  /// 見極め=見立ての精度、指導=育成の伸び、など)。
  int staffAttributeLevel(StaffRole role, StaffAttribute a) {
    final members = membersFor(role);
    if (members.isEmpty) return 1;
    if (members.length == 1) return members.first.levelOf(a);
    return StaffMember.levelFromAbility(
        combinedAbility(members.map((m) => m.attribute(a).toDouble())));
  }

  /// [m] を加える。主任が空いていれば主任に、いれば部下に。
  void addMember(StaffMember m) {
    if (staff[m.role] == null) {
      staff[m.role] = m;
    } else {
      (assistants[m.role] ??= []).add(m);
    }
  }

  /// id が [staffId] の人を外す。主任が抜けたら、部下のうち能力の高い人が
  /// 主任に上がる。外した人を返す(いなければ null)。
  StaffMember? removeMember(String staffId) {
    for (final r in StaffRole.values) {
      if (staff[r]?.id == staffId) {
        final gone = staff[r];
        staff[r] = null;
        promoteAssistants();
        return gone;
      }
      final list = assistants[r];
      if (list == null) continue;
      final i = list.indexWhere((m) => m.id == staffId);
      if (i >= 0) {
        final gone = list.removeAt(i);
        if (list.isEmpty) assistants.remove(r);
        return gone;
      }
    }
    return null;
  }

  /// 主任が空いた役職に、部下のうち能力の高い人を上げる。
  void promoteAssistants() {
    for (final r in StaffRole.values) {
      if (staff[r] != null) continue;
      final list = assistants[r];
      if (list == null || list.isEmpty) continue;
      list.sort((a, b) => b.roleAbility.compareTo(a.roleAbility));
      staff[r] = list.removeAt(0);
      if (list.isEmpty) assistants.remove(r);
    }
  }
  int facilityLevel(FacilityType type) => facilityLevels[type] ?? 1;

  /// 役職を空けたまま置いたときの週俸(=0)との比較用に残している、
  /// 旧レベル制の週俸。セーブの移行でのみ使う。
  /// 週俸の相場を15%にした(StaffMember.staffWageFactor)のに合わせて 20→3。
  static int staffWeeklyWage(int level) => level * 3;

  /// スタジアム以外の施設を [currentLevel] から1段上げる工事費(万円)。
  ///
  /// 以前は `500×レベル²` に今いる部の倍率を掛けていて、1部ではLv7→8が
  /// 約510億円になった。いまは部でも国でも変えない、段ごとの固定の額
  /// (1.5億×レベル²: Lv1→2 1.5億、Lv4→5 24億、Lv7→8 73.5億)。
  static int facilityUpgradeCost(int currentLevel) =>
      15000 * currentLevel * currentLevel;

  /// スタジアムの1段で増える席の数。
  static const int stadiumSeatsPerLevel = 6000;

  /// スタジアムを [currentLevel] から1段上げるときの、1席あたりの工事費
  /// (万円)。大きなスタジアムほど上の層・屋根が要り、1席が高くつく
  /// (Lv1→2 20万円、Lv7→8 140万円)。部や国では変えない。
  static int stadiumSeatCost(int currentLevel) => 20 * currentLevel;

  /// スタジアムを [currentLevel] から1段上げる工事費(万円)。
  /// 増やす席の数 × 1席の値段(Lv1→2 12億、Lv4→5 48億、Lv7→8 84億)。
  static int stadiumUpgradeCost(int currentLevel) =>
      stadiumSeatsPerLevel * stadiumSeatCost(currentLevel);

  /// [type] を [currentLevel] から1段上げる工事費(万円)。補助・予算の
  /// 配分などの割引を掛ける前の額。
  static int upgradeCostFor(FacilityType type, int currentLevel) =>
      type == FacilityType.stadium
          ? stadiumUpgradeCost(currentLevel)
          : facilityUpgradeCost(currentLevel);

  /// スタジアム以外の施設の工期(月)。
  static const int buildMonths = 3;

  /// スタジアムのレベルに応じた収容人数。
  static int stadiumCapacity(int level) =>
      12000 + (level - 1) * stadiumSeatsPerLevel;

  /// ヘッドコーチ・トレーニング施設のレベルに応じたトレーニング成長効率の倍率。
  static double trainingGrowthMultiplier(
    int headCoachLevel,
    int trainingGroundLevel,
  ) =>
      1 + (headCoachLevel - 1) * 0.15 + (trainingGroundLevel - 1) * 0.08;

  /// トレーニング施設のレベルに応じた、週次の追加疲労回復量。
  static int fatigueRecoveryBonus(int trainingGroundLevel) =>
      (trainingGroundLevel - 1) * 3;

  /// フィットネスコーチのレベルに応じた、週次トレーニングでの追加疲労回復量
  /// (トレーニング施設の回復ボーナスに上乗せされる)。
  static int fitnessCoachRecoveryBonus(int fitnessCoachLevel) =>
      (fitnessCoachLevel - 1) * 2;

  /// フィジオのレベルに応じた負傷の発生率・療養期間の軽減係数(1.0で軽減なし)。
  static double injuryFactor(int physioLevel) =>
      (1 - (physioLevel - 1) * 0.09).clamp(0.35, 1.0);

  /// メディカルセンターのレベルに応じた、フィジオの効果に重ねてかかる
  /// 追加の負傷リスク軽減係数(1.0で軽減なし)。フィジオ単独では届かない
  /// 領域まで負傷リスクを下げられる、上級者向けの投資先。
  static double medicalCenterInjuryFactor(int medicalCenterLevel) =>
      (1 - (medicalCenterLevel - 1) * 0.06).clamp(0.6, 1.0);

  /// 商業施設のレベルに応じた、観客収入・スポンサー収入への倍率。
  ///
  /// 1段 +4%(Lv8 で 1.28 倍)。以前は1段 +10%(Lv8 で 1.7 倍)で、観客・
  /// スポンサー・グッズの全部に掛かり、工事費が部で変わらないため1部では
  /// 1季で元が取れて、資金が雪だるま式に増えた(2026-11-23 の実測)。
  static const double commercialStep = 0.04;
  static double commercialRevenueMultiplier(int level) =>
      1 + (level - 1) * commercialStep;

  int get totalStaffWeeklyWage =>
      allStaff.fold<int>(0, (s, m) => s + m.wage);

  bool upgradeFacility(FacilityType type) {
    final lvl = facilityLevel(type);
    if (lvl >= maxLevel) return false;
    facilityLevels[type] = lvl + 1;
    return true;
  }

  /// [type] の工事を始める。完成は [readyOn]。最大レベル・工事中なら false。
  bool startConstruction(FacilityType type, DateTime readyOn) {
    if (facilityLevel(type) >= maxLevel || isUnderConstruction(type)) {
      return false;
    }
    construction[type] = readyOn;
    return true;
  }

  /// [today] までに完成した工事を終え、レベルを1つ上げる。完成した施設を
  /// 返す(FacilityType の並び順)。
  List<FacilityType> completeConstructionDue(DateTime today) {
    final done = [
      for (final f in FacilityType.values)
        if (construction[f] != null && !construction[f]!.isAfter(today)) f,
    ];
    for (final f in done) {
      construction.remove(f);
      upgradeFacility(f);
    }
    return done;
  }

  /// セーブには役職ごとの全員を並べて書く('staffTeams'。主任が先)。
  /// 1人ずつの形('staff')は 2026-11-25 より前のセーブにだけある。
  Map<String, dynamic> toJson() => {
        'staffTeams': {
          for (final r in StaffRole.values)
            if (membersFor(r).isNotEmpty)
              r.name: [for (final m in membersFor(r)) m.toJson()],
        },
        'facilityLevels': facilityLevels.map((k, v) => MapEntry(k.name, v)),
        if (construction.isNotEmpty)
          'construction':
              construction.map((k, v) => MapEntry(k.name, v.toIso8601String())),
      };

  factory ClubInfrastructure.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClubInfrastructure();
    final staffJson = json['staff'] as Map<String, dynamic>?;
    // 複数人の形(2026-11-25 から)。あればこちらが正。古いセーブは1人ずつの
    // 'staff' を読み、主任だけ・部下なしの形にする(書くときは新しい形)。
    final teamsJson = json['staffTeams'] as Map<String, dynamic>?;
    final teams = {
      for (final r in StaffRole.values)
        r: [
          for (final m in (teamsJson?[r.name] as List?) ?? const [])
            if (m is Map) StaffMember.fromJson(m.cast<String, dynamic>()),
        ],
    };
    // 旧セーブはレベル数値しか持っていない。そのまま読むと全役職が空席に
    // なり、トレーニング効率も負傷率も一斉に最低へ落ちる。同じ働きをする
    // 人物を置いて続きから遊べるようにする(StaffMarket.fromLegacyLevel)。
    final legacyLevels = json['staffLevels'] as Map<String, dynamic>?;
    final facilityJson = json['facilityLevels'] as Map<String, dynamic>?;
    // 工事中の施設(2026-11-23 から)。無い旧セーブは工事なし。
    final constructionJson = json['construction'] as Map<String, dynamic>?;
    return ClubInfrastructure(
      construction: {
        for (final f in FacilityType.values)
          if (constructionJson?[f.name] case final String iso)
            if (DateTime.tryParse(iso) case final DateTime d) f: d,
      },
      staff: {
        for (final r in StaffRole.values)
          r: teamsJson != null
              ? teams[r]!.firstOrNull
              : switch ((staffJson?[r.name], legacyLevels?[r.name])) {
                  (final Map<String, dynamic> m, _) => StaffMember.fromJson(m),
                  (_, final int lvl) when lvl > 1 =>
                    StaffMarket.fromLegacyLevel(r, lvl),
                  _ => null,
                },
      },
      assistants: {
        for (final r in StaffRole.values)
          if (teams[r]!.length > 1) r: teams[r]!.sublist(1),
      },
      facilityLevels: {
        for (final f in FacilityType.values)
          f: (facilityJson?[f.name] as int?) ?? 1,
      },
    );
  }
}
