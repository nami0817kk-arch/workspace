import 'career.dart';
import 'difficulty.dart';
import 'game.dart';
import 'life_log.dart';
import 'path.dart';
import 'player.dart';
import 'records.dart';
import 'traits.dart';
import 'flavor.dart';
import 'world.dart';

/// 選手情報の写し。育成中の選手も、殿堂に残った過去の選手も、同じ画面で見られるようにする。
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.name,
    required this.role,
    required this.age,
    required this.stage,
    required this.potential,
    required this.abilities,
    required this.traits,
    required this.records,
    required this.events,
    required this.overallHistory,
    this.proStartAge,
    this.proTeam,
    this.endingTitle,
    this.rivalName,
    this.rivalWins = 0,
    this.rivalLosses = 0,
    this.difficulty = Difficulty.normal,
    this.married = false,
    this.route,
    this.worldRecords = const [],
    this.position,
    this.overseasTeam,
    this.parentName,
    this.money = 0,
    this.investTotal = 0,
    this.rivalTalent,
  });

  final String name;
  final Role role;
  final int age;
  final Stage stage;
  final int potential;
  final Map<Ability, int> abilities;
  final Set<Trait> traits;
  final List<SeasonRecord> records;
  final List<LifeEvent> events;
  final List<int> overallHistory;
  final int? proStartAge;

  /// 入団した球団(架空)。プロ入りしていなければ null。
  final String? proTeam;

  /// 引退済みなら称号(「一流選手」など)。
  final String? endingTitle;
  final String? rivalName;
  final int rivalWins;
  final int rivalLosses;
  final Difficulty difficulty;

  /// 引退時に恋人と結婚していたか。
  final bool married;

  /// 選んだ進路(大学・社会人)。選んでいなければ null。
  final Course? route;

  /// 日本代表として出た世界大会の結果。
  final List<WorldRecord> worldRecords;

  /// 自分で決めた守備位置・役割(決めていなければ null)。
  final Pos? position;

  /// 海外(アメリカ)でいま所属している球団。海外にいなければ null。
  final String? overseasTeam;

  /// 二世のとき、親の名前。
  final String? parentName;

  /// 資産(万円)と、投資のレベルの合計(最大9)。
  final int money;
  final int investTotal;

  /// ライバルの素質(物語を作るのに使う)。
  final int? rivalTalent;

  int of(Ability a) => abilities[a] ?? 0;

  factory PlayerSnapshot.fromGame(Game g) => PlayerSnapshot(
        name: g.player.name,
        role: g.player.role,
        age: g.player.age,
        stage: g.stage,
        potential: g.player.potential,
        abilities: Map.of(g.player.abilities),
        traits: Set.of(g.player.traits),
        records: List.of(g.records),
        events: List.of(g.lifeLog),
        overallHistory: List.of(g.overallHistory),
        proStartAge: g.proStartAge,
        proTeam: g.proTeam,
        endingTitle: g.ending?.title,
        rivalName: g.cast.rival?.name,
        rivalWins: g.cast.rivalWins,
        rivalLosses: g.cast.rivalLosses,
        difficulty: g.difficulty,
        married: g.ending?.married ?? false,
        route: g.route,
        worldRecords: List.of(g.worldRecords),
        position: g.position,
        overseasTeam: g.overseas ? g.overseasTeam : null,
        parentName: g.parentName,
        money: g.money,
        investTotal: g.invests.values.fold(0, (a, b) => a + b),
        rivalTalent: g.cast.rival?.talent,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role.name,
        'age': age,
        'stage': stage.name,
        'potential': potential,
        'abilities': {for (final e in abilities.entries) e.key.name: e.value},
        'traits': [for (final t in traits) t.name],
        'records': [for (final r in records) r.toJson()],
        'events': [for (final e in events) e.toJson()],
        'overallHistory': overallHistory,
        'proStartAge': proStartAge,
        'proTeam': proTeam,
        'endingTitle': endingTitle,
        'rivalName': rivalName,
        'rivalWins': rivalWins,
        'rivalLosses': rivalLosses,
        'difficulty': difficulty.name,
        'married': married,
        'route': route?.name,
        'worldRecords': [for (final r in worldRecords) r.toJson()],
        'position': position?.name,
        'overseasTeam': overseasTeam,
        'parentName': parentName,
        'money': money,
        'investTotal': investTotal,
        'rivalTalent': rivalTalent,
      };

  /// 項目を足すときは既定値を置く(殿堂の古い記録を壊さない)。
  factory PlayerSnapshot.fromJson(Map<String, dynamic> j) {
    final ab = <Ability, int>{};
    for (final e in ((j['abilities'] as Map?) ?? const {}).entries) {
      final a = Ability.parse(e.key as String);
      if (a != null) ab[a] = (e.value as num).toInt();
    }
    return PlayerSnapshot(
      name: (j['name'] as String?) ?? '名無し',
      role: Role.values
          .firstWhere((r) => r.name == j['role'], orElse: () => Role.batter),
      age: (j['age'] as num?)?.toInt() ?? 0,
      stage: Stage.values
          .firstWhere((s) => s.name == j['stage'], orElse: () => Stage.retired),
      potential: (j['potential'] as num?)?.toInt() ?? 50,
      abilities: ab,
      traits: {
        for (final s in (j['traits'] as List?) ?? const [])
          if (Trait.parse(s as String) != null) Trait.parse(s)!,
      },
      records: [
        for (final r in (j['records'] as List?) ?? const [])
          SeasonRecord.fromJson((r as Map).cast<String, dynamic>()),
      ],
      events: [
        for (final e in (j['events'] as List?) ?? const [])
          LifeEvent.fromJson((e as Map).cast<String, dynamic>()),
      ],
      overallHistory: [
        for (final v in (j['overallHistory'] as List?) ?? const [])
          (v as num).toInt(),
      ],
      proStartAge: (j['proStartAge'] as num?)?.toInt(),
      proTeam: j['proTeam'] as String?,
      endingTitle: j['endingTitle'] as String?,
      rivalName: j['rivalName'] as String?,
      rivalWins: (j['rivalWins'] as num?)?.toInt() ?? 0,
      rivalLosses: (j['rivalLosses'] as num?)?.toInt() ?? 0,
      difficulty: Difficulty.parse(j['difficulty']),
      married: (j['married'] as bool?) ?? false,
      route: Course.values.where((c) => c.name == j['route']).firstOrNull,
      worldRecords: [
        for (final r in (j['worldRecords'] as List?) ?? const [])
          WorldRecord.fromJson((r as Map).cast<String, dynamic>()),
      ],
      position: Pos.parse(j['position'] as String?),
      overseasTeam: j['overseasTeam'] as String?,
      parentName: j['parentName'] as String?,
      money: (j['money'] as num?)?.toInt() ?? 0,
      investTotal: (j['investTotal'] as num?)?.toInt() ?? 0,
      rivalTalent: (j['rivalTalent'] as num?)?.toInt(),
    );
  }
}
