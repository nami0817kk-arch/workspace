import 'agent.dart';
import 'attributes.dart';
import 'club.dart';
import 'competition.dart';
import 'development.dart';
import 'reputation.dart';
import 'support.dart';
import 'training.dart';
import 'injury.dart';
import 'objective.dart';
import 'player.dart';
import 'season.dart';

/// 過去シーズンの記録。引退後に振り返るためのもの。
class SeasonRecord {
  const SeasonRecord({
    required this.year,
    required this.clubName,
    required this.tier,
    required this.leaguePosition,
    required this.stats,
    this.salary = 0,
    this.caps = 0,
    this.objectiveMet = false,
    this.countryId = 'yamato',
    this.continentalStage = ContinentalStage.none,
    this.cupStage = CupStage.none,
    this.worldCupStage = WorldCupStage.none,
    this.onLoan = false,
  });

  final int year;
  final String clubName;
  final int tier;
  final int leaguePosition;
  final SeasonStats stats;

  /// そのシーズンの年俸（万円）。
  final int salary;

  /// そのシーズンに出た代表戦の数。
  final int caps;

  /// 監督の目標を達成したか。
  final bool objectiveMet;

  /// そのシーズンを戦った国。
  final String countryId;

  /// そのシーズンの大陸カップの成績。
  final ContinentalStage continentalStage;

  /// そのシーズンの国内カップの成績。
  final CupStage cupStage;

  /// そのシーズンのワールドカップの成績。
  final WorldCupStage worldCupStage;

  /// ローンで戦ったシーズンか。
  final bool onLoan;

  Map<String, dynamic> toJson() => {
        'year': year,
        'clubName': clubName,
        'tier': tier,
        'leaguePosition': leaguePosition,
        'appearances': stats.appearances,
        'goals': stats.goals,
        'assists': stats.assists,
        'averageRating': stats.averageRating,
        'salary': salary,
        'caps': caps,
        'objectiveMet': objectiveMet,
        'countryId': countryId,
        'continentalStage': continentalStage.name,
        'cupStage': cupStage.name,
        'worldCupStage': worldCupStage.name,
        'onLoan': onLoan,
      };

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        year: json['year'] as int,
        clubName: json['clubName'] as String,
        tier: json['tier'] as int,
        leaguePosition: json['leaguePosition'] as int,
        stats: SeasonStats(
          appearances: json['appearances'] as int,
          goals: json['goals'] as int,
          assists: json['assists'] as int,
          averageRating: (json['averageRating'] as num).toDouble(),
        ),
        salary: json['salary'] as int? ?? 0,
        caps: json['caps'] as int? ?? 0,
        objectiveMet: json['objectiveMet'] as bool? ?? false,
        countryId: json['countryId'] as String? ?? 'yamato',
        continentalStage: ContinentalStage.values
                .any((v) => v.name == json['continentalStage'])
            ? ContinentalStage.values.byName(json['continentalStage'] as String)
            : ContinentalStage.none,
        cupStage: CupStage.values.any((v) => v.name == json['cupStage'])
            ? CupStage.values.byName(json['cupStage'] as String)
            : CupStage.none,
        worldCupStage:
            WorldCupStage.values.any((v) => v.name == json['worldCupStage'])
                ? WorldCupStage.values.byName(json['worldCupStage'] as String)
                : WorldCupStage.none,
        onLoan: json['onLoan'] as bool? ?? false,
      );
}

/// キャリア全体の状態。これ1つを保存すれば続きから再開できる。
class CareerState {
  CareerState({
    required this.player,
    required this.club,
    required this.league,
    required this.year,
    required this.fixtures,
    required this.results,
    required this.table,
    required this.history,
    required this.agent,
    required this.salary,
    required this.contractYears,
    this.countryId = 'yamato',
    this.professionalYears = 1,
    this.continentalExperience = false,
    this.continentalStage = ContinentalStage.none,
    this.cupStage = CupStage.none,
    this.worldCupStage = WorldCupStage.none,
    this.squadStatus = SquadStatus.registered,
    this.parentClub,
    this.releaseClause,
    this.loanBuyOption,
    this.reputation = const Reputation(),
    this.relations = const Relations(),
    this.finances = const Finances(),
    this.menu = TrainingMenu.rest,
    this.drill,
    this.staff = const StaffTeam(),
    this.habits = const Habits(),
    this.development = const Development(),
    this.objective,
    this.injury,
    this.caps = 0,
    this.internationalGoals = 0,
    this.pendingInternational = false,
    this.calledUp = false,
    this.simStyle = SimStyle.balanced,
    this.retired = false,
  });

  Player player;
  Club club;

  /// 所属リーグのクラブ一覧（自分のクラブを含む20チーム）。
  List<Club> league;

  int year;

  /// 対戦相手のクラブIDを節順に並べたもの。ホームかどうかは節の偶奇で決める。
  List<String> fixtures;

  /// 今シーズンの試合結果。
  List<MatchResult> results;

  /// 今シーズンの順位表。
  List<TableRow> table;

  /// 過去シーズンの記録。
  List<SeasonRecord> history;

  Agent agent;

  /// 今の年俸（万円）。
  int salary;

  /// 今週の練習メニュー。
  TrainingMenu menu;

  /// 今週の居残り練習。null ならやらない。
  SetPiece? drill;

  /// 自腹で雇っているスタッフ。
  StaffTeam staff;

  /// 生活習慣。睡眠と食事。
  Habits habits;

  /// 経験・選択の癖・相手への慣れ・個人技・停滞期。
  Development development;

  /// 契約の残り年数。0 になると必ず去就を決めることになる。
  int contractYears;

  /// 今いる国。所属クラブの国と同じだが、リーグの組み立てで使うので持つ。
  String countryId;

  /// プロになってからの年数。労働許可の審査に使う。
  int professionalYears;

  /// 大陸カップに出た経験があるか。労働許可の加点になる。
  bool continentalExperience;

  /// 今季の大陸カップの成績。
  ContinentalStage continentalStage;

  /// 今季の国内カップの成績。
  CupStage cupStage;

  /// 今季のワールドカップの成績。4年に1度だけ動く。
  WorldCupStage worldCupStage;

  /// ローン中なら、保有元のクラブ。
  Club? parentClub;

  /// ローンで他クラブに出ているか。
  bool get onLoan => parentClub != null;

  /// 契約に付いている違約金（万円）。これを超える評価になると話が動く。
  int? releaseClause;

  /// ローンに付いている買い取りオプションの金額（万円）。
  int? loanBuyOption;

  /// 今季、登録メンバーに入れているか。外れると試合に出られない。
  SquadStatus squadStatus;

  /// 市場価値・知名度・称号。
  Reputation reputation;

  /// 監督とチームメイトとの関係。
  Relations relations;

  /// お金。年俸から税・手数料・生活費を引いた残りが貯まる。
  Finances finances;

  /// 監督から与えられた今季の目標。
  SeasonObjective? objective;

  /// 負傷中ならその内容。
  Injury? injury;

  /// 通算の代表キャップ数と代表ゴール。
  int caps;
  int internationalGoals;

  /// 次に代表戦が待っているか（代表ウィーク）。
  bool pendingInternational;

  /// 今季、代表に招集されているか。
  bool calledUp;

  /// 自動で進めるときの選び方。
  SimStyle simStyle;

  /// 引退済みなら true。以後は試合をせず、通算成績だけを見せる。
  bool retired;

  /// リーグ戦の結果だけ。代表戦は節に数えない。
  List<MatchResult> get leagueResults =>
      results.where((r) => !r.international).toList();

  int get matchday => leagueResults.length + 1;
  bool get seasonFinished => leagueResults.length >= fixtures.length;

  /// 負傷離脱中か。
  bool get injured => injury != null;

  /// リーグ戦の個人成績。代表戦は含めない（監督の目標もこちらで見る）。
  SeasonStats get seasonStats => SeasonStats.from(leagueResults);

  /// 今季の代表戦の数。
  int get seasonCaps => results.where((r) => r.international).length;

  /// 通算の稼ぎ（万円）。終えたシーズンの分だけ数える。
  int get totalEarnings => history.fold(0, (s, h) => s + h.salary);

  Club opponentFor(int matchday) {
    final id = fixtures[matchday - 1];
    return league.firstWhere((c) => c.id == id);
  }

  /// ホームとアウェイを交互にする。厳密な日程表は作らない。
  bool isHome(int matchday) => matchday.isOdd;

  List<TableRow> get sortedTable {
    final rows = [...table];
    rows.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byDiff = b.goalDifference.compareTo(a.goalDifference);
      if (byDiff != 0) return byDiff;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return rows;
  }

  int get leaguePosition =>
      sortedTable.indexWhere((r) => r.clubId == club.id) + 1;

  /// 通算成績。今シーズンぶんも含める。
  SeasonStats get careerTotals {
    final all = [...history.map((h) => h.stats), seasonStats];
    final appearances = all.fold(0, (s, x) => s + x.appearances);
    if (appearances == 0) {
      return const SeasonStats(
          appearances: 0, goals: 0, assists: 0, averageRating: 0);
    }
    final weighted =
        all.fold<double>(0, (s, x) => s + x.averageRating * x.appearances);
    return SeasonStats(
      appearances: appearances,
      goals: all.fold(0, (s, x) => s + x.goals),
      assists: all.fold(0, (s, x) => s + x.assists),
      averageRating: weighted / appearances,
    );
  }

  Map<String, dynamic> toJson() => {
        'retired': retired,
        'player': player.toJson(),
        'club': club.toJson(),
        'league': league.map((c) => c.toJson()).toList(),
        'year': year,
        'fixtures': fixtures,
        'results': results.map((r) => r.toJson()).toList(),
        'table': table.map((r) => r.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'agent': agent.toJson(),
        'salary': salary,
        'menu': menu.name,
        'drill': drill?.name,
        'staff': staff.toJson(),
        'habits': habits.toJson(),
        'development': development.toJson(),
        'contractYears': contractYears,
        'countryId': countryId,
        'professionalYears': professionalYears,
        'continentalExperience': continentalExperience,
        'continentalStage': continentalStage.name,
        'cupStage': cupStage.name,
        'worldCupStage': worldCupStage.name,
        'parentClub': parentClub?.toJson(),
        'releaseClause': releaseClause,
        'loanBuyOption': loanBuyOption,
        'squadStatus': squadStatus.name,
        'reputation': reputation.toJson(),
        'relations': relations.toJson(),
        'finances': finances.toJson(),
        'objective': objective?.toJson(),
        'injury': injury?.toJson(),
        'caps': caps,
        'internationalGoals': internationalGoals,
        'pendingInternational': pendingInternational,
        'calledUp': calledUp,
        'simStyle': simStyle.name,
      };

  factory CareerState.fromJson(Map<String, dynamic> json) {
    // 練習はカテゴリ1つを選ぶ方式だった。古い保存データはその対応表で読む。
    final menuName = json['menu'] as String?;
    final legacyKey = json['training'] as String?;
    final menu = menuName != null &&
            TrainingMenu.values.any((m) => m.name == menuName)
        ? TrainingMenu.values.byName(menuName)
        : legacyKey != null && AttributeKey.values.any((k) => k.name == legacyKey)
            ? TrainingMenu.forKey(AttributeKey.values.byName(legacyKey))
            : TrainingMenu.rest;
    return CareerState(
      player: Player.fromJson(json['player'] as Map<String, dynamic>),
      club: Club.fromJson(json['club'] as Map<String, dynamic>),
      league: (json['league'] as List)
          .map((c) => Club.fromJson(c as Map<String, dynamic>))
          .toList(),
      year: json['year'] as int,
      fixtures: (json['fixtures'] as List).cast<String>(),
      results: (json['results'] as List)
          .map((r) => MatchResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      table: (json['table'] as List)
          .map((r) => TableRow.fromJson(r as Map<String, dynamic>))
          .toList(),
      history: (json['history'] as List)
          .map((h) => SeasonRecord.fromJson(h as Map<String, dynamic>))
          .toList(),
      // 以下は後から足した項目。古い保存データには無い。
      agent: Agent.fromJson(json['agent'] as Map<String, dynamic>?),
      salary: json['salary'] as int? ?? 300,
      menu: menu,
      drill: SetPiece.values.any((p) => p.name == json['drill'])
          ? SetPiece.values.byName(json['drill'] as String)
          : null,
      staff: StaffTeam.fromJson(json['staff'] as Map<String, dynamic>?),
      habits: Habits.fromJson(json['habits'] as Map<String, dynamic>?),
      development:
          Development.fromJson(json['development'] as Map<String, dynamic>?),
      contractYears: json['contractYears'] as int? ?? 2,
      countryId: json['countryId'] as String? ?? 'yamato',
      professionalYears: json['professionalYears'] as int? ?? 1,
      continentalExperience: json['continentalExperience'] as bool? ?? false,
      continentalStage: ContinentalStage.values
              .any((v) => v.name == json['continentalStage'])
          ? ContinentalStage.values.byName(json['continentalStage'] as String)
          : ContinentalStage.none,
      cupStage: CupStage.values.any((v) => v.name == json['cupStage'])
          ? CupStage.values.byName(json['cupStage'] as String)
          : CupStage.none,
      worldCupStage:
          WorldCupStage.values.any((v) => v.name == json['worldCupStage'])
              ? WorldCupStage.values.byName(json['worldCupStage'] as String)
              : WorldCupStage.none,
      parentClub: json['parentClub'] == null
          ? null
          : Club.fromJson(json['parentClub'] as Map<String, dynamic>),
      releaseClause: json['releaseClause'] as int?,
      loanBuyOption: json['loanBuyOption'] as int?,
      squadStatus:
          SquadStatus.values.any((v) => v.name == json['squadStatus'])
              ? SquadStatus.values.byName(json['squadStatus'] as String)
              : SquadStatus.registered,
      reputation:
          Reputation.fromJson(json['reputation'] as Map<String, dynamic>?),
      relations: Relations.fromJson(json['relations'] as Map<String, dynamic>?),
      finances: Finances.fromJson(json['finances'] as Map<String, dynamic>?),
      objective:
          SeasonObjective.fromJson(json['objective'] as Map<String, dynamic>?),
      injury: Injury.fromJson(json['injury'] as Map<String, dynamic>?),
      caps: json['caps'] as int? ?? 0,
      internationalGoals: json['internationalGoals'] as int? ?? 0,
      pendingInternational: json['pendingInternational'] as bool? ?? false,
      calledUp: json['calledUp'] as bool? ?? false,
      simStyle: SimStyle.values.any((s) => s.name == json['simStyle'])
          ? SimStyle.values.byName(json['simStyle'] as String)
          : SimStyle.balanced,
      retired: json['retired'] as bool? ?? false,
    );
  }
}
