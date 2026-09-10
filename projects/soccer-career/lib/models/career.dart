import 'dart:math';

import 'agent.dart';
import 'attributes.dart';
import 'club.dart';
import 'competition.dart';
import 'development.dart';
import 'entourage.dart';
import 'life.dart';
import 'news.dart';
import 'reputation.dart';
import 'support.dart';
import 'training.dart';
import 'traits.dart';
import 'injury.dart';
import 'objective.dart';
import 'promise.dart';
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
    this.overall = 0,
    this.promiseLabel,
    this.promiseKept = false,
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

  /// そのシーズンの世界大会の成績。
  final WorldCupStage worldCupStage;

  /// ローンで戦ったシーズンか。
  final bool onLoan;

  /// そのシーズンを終えた時点の総合力。0 は記録が無い（古い保存データ）。
  final int overall;

  /// そのシーズンに口にした約束。していなければ null。
  final String? promiseLabel;

  /// その約束を果たしたか。
  final bool promiseKept;

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
        'overall': overall,
        'promiseLabel': promiseLabel,
        'promiseKept': promiseKept,
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
        overall: json['overall'] as int? ?? 0,
        promiseLabel: json['promiseLabel'] as String?,
        promiseKept: json['promiseKept'] as bool? ?? false,
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
    this.effort = TrainingEffort.normal,
    this.companion = TrainingCompanion.alone,
    this.drill,
    this.staff = const StaffTeam(),
    this.habits = const Habits(),
    this.development = const Development(),
    this.manager,
    this.directive = Directive.none,
    this.competitor,
    this.partner,
    this.mentor,
    this.rival,
    this.rehab = RehabPlan.standard,
    this.rehabWatch = 0,
    this.mentorManager,
    this.morale = const Morale(),
    this.fatigue = const Fatigue(),
    this.form = const Momentum(),
    this.preseason = PreseasonPlan.camp,
    this.captain = false,
    this.captaincyOffered = false,
    this.squadNumber = 0,
    this.nickname,
    this.sponsor,
    this.sponsorOffer,
    this.charity = false,
    this.nationalTeamId,
    this.secondCareer,
    this.seenEvents = const [],
    this.news = const [],
    this.seasonStart,
    this.backedUpYear = 0,
    this.autoRestBelow = defaultAutoRestBelow,
    this.focus = const [],
    this.yellowCards = 0,
    this.suspension = 0,
    this.momentAttempts = const {},
    this.momentSuccesses = const {},
    this.traitHits = const {},
    this.tampered = false,
    this.tacticCredit = 0,
    this.objective,
    this.promise,
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

  /// 今週どこまで踏み込むか。
  ///
  /// 週の選択が「どのメニューか」だけだった頃は、毎週同じ画面で同じものを
  /// 選ぶだけで、練習の週に手応えが無かった。
  TrainingEffort effort;

  /// 今週、誰と組むか。
  ///
  /// 相方・メンター・競争相手は試合の外で勝手に動く飾りだった。
  TrainingCompanion companion;

  /// 今の顔ぶれで、実際に組める相手。
  List<TrainingCompanion> get companionChoices => [
        TrainingCompanion.alone,
        for (final c in TrainingCompanion.values)
          if (c.needs != null && teammateOf(c.needs!) != null) c,
      ];

  /// その役回りの選手。居なければ null。
  ///
  /// `rival` は別クラブで別のキャリアを歩む同期なので、練習の相手は
  /// クラブの中に居る `competitor`（同ポジションの競争相手）のほう。
  Teammate? teammateOf(TeammateKind kind) => switch (kind) {
        TeammateKind.partner => partner,
        TeammateKind.mentor => mentor,
        TeammateKind.rival => competitor,
      };

  /// 今週の居残り練習。null ならやらない。
  SetPiece? drill;

  /// 自腹で雇っているスタッフ。
  StaffTeam staff;

  /// 生活習慣。睡眠と食事。
  Habits habits;

  /// 経験・選択の癖・相手への慣れ・個人技・停滞期。
  Development development;

  /// 今の監督。戦術との相性が出場機会に効く。
  Manager? manager;

  /// クラブに伝えている方針。
  Directive directive;

  /// 同ポジションの競争相手。
  Teammate? competitor;

  /// 相方。呼吸が合うほど味方を活かす手が通る。
  Teammate? partner;

  /// メンター。若いうちだけ、練習の効きを上げる。
  Teammate? mentor;

  /// 同期のライバル。別のクラブで別のキャリアを歩む。
  Rival? rival;

  /// 復帰の進め方。
  RehabPlan rehab;

  /// 復帰してから何試合、再発の危険が高い状態か。
  int rehabWatch;

  /// 恩師（信頼の厚かった監督）の名前。よそのクラブから呼ぶことがある。
  String? mentorManager;

  /// 心の状態。身体とは別に管理する。
  Morale morale;

  /// 抜けきらない疲れ。シーズンを通して溜まる。
  Fatigue fatigue;

  /// 数試合だけ続く波（ゾーン／スランプ）。
  Momentum form;

  /// 今季のプレシーズンの過ごし方。
  PreseasonPlan preseason;

  /// キャプテンか。
  bool captain;

  /// キャプテンの打診が来ているか。
  bool captaincyOffered;

  /// 背番号。0 なら未設定。
  int squadNumber;

  /// ついた愛称。知名度が上がると付く。
  String? nickname;

  /// スパイクのスポンサー契約。
  Sponsor? sponsor;

  /// 届いているスポンサーの打診。
  Sponsor? sponsorOffer;

  /// 財団を作ったか。
  bool charity;

  /// 選んだ代表。複数の国籍を持つときだけ意味がある。
  String? nationalTeamId;

  /// 実際に代表として戦う国。選んでいなければ主国籍。
  String get nationalTeam => nationalTeamId ?? player.nationality.primary;

  /// 引退後に選んだ道。
  SecondCareer? secondCareer;

  /// もう起きた出来事のID。一度きりの出来事を繰り返さないために持つ。
  List<String> seenEvents;

  /// 世の中に出た見出し。新しいものが先頭。
  List<NewsItem> news;

  /// 今季の累積警告。シーズンをまたぐと消える（実際のリーグと同じ）。
  int yellowCards;

  /// 出場停止の残り試合数。0 なら出られる。
  int suspension;

  /// 出場停止か。
  bool get suspended => suspension > 0;

  /// 育てる方向。伸ばしたい詳細能力を選んでおく。
  ///
  /// 練習でも試合の成長でも、伸びる先が無作為だったので、何を選んでも
  /// 同じような選手になっていた。ここを決めておくと、練習の中で伸びる
  /// 項目と、試合の成長の無作為ぶんが、選んだ方向に寄る。
  /// **伸びる量は変わらない**——どこに乗るかだけが変わる。
  List<Detail> focus;

  /// 同時に選べる数。全部を伸ばすのは方向とは言わない。
  static const int maxFocus = 3;

  /// そのカテゴリの中で、方向に入っている詳細。
  List<Detail> focusIn(AttributeKey key) =>
      [for (final d in focus) if (d.category == key) d];

  /// このコンディションを下回ったら、その週は自動で休養にする。
  ///
  /// 0 なら自動では休まない。疲れたまま練習を続けると、伸びないうえに
  /// 怪我をして、その週の操作を忘れていただけで数試合を失う。
  int autoRestBelow;

  /// 自動休養の既定値。助言（[WeekPlan.tiredCondition]）より少し下に置く。
  /// 助言が先に出て、それでも放っておいたときにだけ効く。
  static const int defaultAutoRestBelow = 40;

  /// 選べるしきい値。0 は「しない」。
  static const List<int> autoRestChoices = [0, 30, 40, 50, 60];

  /// 最後に引き継ぎコードを出した年。0 なら一度も出していない。
  ///
  /// 保存は端末の中だけにあるので、ブラウザのデータを消すと消える。
  /// 何年ぶんか控えていないなら、シーズンの区切りで知らせる。
  int backedUpYear;

  /// 控えを取ってから何年経ったか。一度も取っていなければ、プロ入りからの年数。
  int get yearsSinceBackup =>
      backedUpYear == 0 ? professionalYears : year - backedUpYear;

  /// 今季の開幕時点の能力値。今季どれだけ伸びたかを出すために持つ。
  ///
  /// 能力値は毎週すこしずつ動くので、見ているだけでは伸びたことに
  /// 気付けない。開幕時を覚えておいて差を見せる。古い保存データには
  /// 無いので null を許す。
  Attributes? seasonStart;

  /// 今季、そのカテゴリで判定した局面の数。
  Map<AttributeKey, int> momentAttempts;

  /// そのうち成功した数。練習した能力が実際に通っているかを見る。
  Map<AttributeKey, int> momentSuccesses;

  /// そのコンディションなら、自動で休むか。
  /// 元気なのに休んでいるか。その週は何も伸びない。
  ///
  /// 休養が既定だった頃の保存データは、育成タブを開かない限り
  /// ずっと休養のまま。コンディション100で9節進んでいても、
  /// どこにもそう書いていなかった。
  bool get restingWhileFresh =>
      menu.isRest &&
      !shouldAutoRest(player.condition) &&
      player.condition >= restingWasteCondition;

  /// これ以上のコンディションで休むと、ほぼ何も戻らない。
  static const int restingWasteCondition = 85;

  bool shouldAutoRest(int condition) =>
      autoRestBelow > 0 && condition < autoRestBelow;

  /// 今季の収支の見込み。雇う前に足りるかどうかを見るためのもの。
  ///
  /// 実際に引かれるのと同じ式（[Finances.budgetFor]）から出す。
  SeasonBudget get budget => finances.budgetFor(
        salary: salary,
        agentFeePercent: agent.feePercent,
        staffCost: staff.costPerSeason,
        extraLivingRate: habits.livingCostExtra,
        sponsor: sponsor?.annual ?? 0,
      );

  /// このシーズンを終えたときの貯蓄の見込み。
  int get projectedSavings => finances.savings + budget.net;

  /// 今の使い方だと、シーズン末に貯蓄が尽きるか。
  ///
  /// 尽きると専属スタッフは全員離れる（`advanceSeason`）。
  bool get willRunOut => projectedSavings < 0;

  /// 今季の伸びと、その能力が試合で通った割合。
  List<CategoryGrowth> get seasonGrowth {
    final before = seasonStart;
    return [
      for (final key in AttributeKey.values)
        CategoryGrowth(
          key: key,
          before: before?[key] ?? player.attributes[key],
          now: player.attributes[key],
          attempts: momentAttempts[key] ?? 0,
          successes: momentSuccesses[key] ?? 0,
        ),
    ];
  }

  /// 監督の期待に、あと一歩で届くか。届くなら、その一言。
  ///
  /// 「得点関与 あと1」はクラブタブのカードにあるだけで、**局面を選ぶ画面には
  /// 無かった**。同じ局面が、シーズンのどこにいるかで意味を変えるようにする。
  /// 3つのうち2つで達成なので、「これで2つ目に届く」ときだけ出す。
  String? get objectiveReach {
    final objective = this.objective;
    if (objective == null) return null;
    final stats = seasonStats;
    final achieved = objective.achievedCount(stats);
    // すでに達成しているか、2つ以上足りないなら、今日の1本では届かない。
    if (achieved >= 2) return null;

    final goalsShort = objective.contributions - stats.goals - stats.assists;
    if (goalsShort == 1 && achieved == 1) {
      return '得点かアシストで、監督の期待に届く';
    }
    final appearancesShort = objective.appearances - stats.appearances;
    if (appearancesShort == 1 && achieved == 1) {
      return 'この試合に出れば、監督の期待に届く';
    }
    return null;
  }

  /// 口にした約束に、あと1で届くか。届くなら、その一言。
  ///
  /// 局面を選ぶ画面に出す。「この1本で約束が果たされる」という重みは、
  /// クラブタブのカードでは伝わらない。
  String? get promiseReach {
    final promise = this.promise;
    if (promise == null) return null;
    if (promise.kind == PromiseKind.rating) return null;
    final left = promise.target - promise.reached(seasonStats);
    if (left != 1) return null;
    return switch (promise.kind) {
      PromiseKind.goals => 'この1点で、約束を果たす',
      PromiseKind.contributions => '得点かアシストで、約束を果たす',
      PromiseKind.appearances => 'この試合に出れば、約束を果たす',
      PromiseKind.rating => null,
    };
  }

  /// 監督の求める形に沿ったぶんの、まだ信頼に乗っていない端数。
  ///
  /// 1試合で動くのは1未満なので、切り捨てると永遠に何も起きない。
  /// 持ち越して、溜まったら信頼に乗せる。
  double tacticCredit;

  /// 管理画面（開発用）で書き換えたキャリアか。
  ///
  /// 記録として信用できないことを画面に出すためだけに持つ。判定には使わない。
  /// 引き継ぎコードで持ち出せてしまうので、印は保存にも乗せる。
  bool tampered;

  /// 今季、それぞれの特性が成功率を動かした局面の数。
  ///
  /// 特性は名前だけ見ても効いたかどうか分からない。
  /// 「今季12回の局面で効いた」が出て初めて、付いている意味が分かる。
  Map<Trait, int> traitHits;

  /// 1試合ぶんの特性の効きを足す。
  void recordTraitHits(Map<Trait, int> hits) {
    if (hits.isEmpty) return;
    traitHits = {
      ...traitHits,
      for (final e in hits.entries) e.key: (traitHits[e.key] ?? 0) + e.value,
    };
  }

  /// 今季の局面を1つ記録する。
  void recordMoment(AttributeKey key, {required bool success}) {
    momentAttempts = {...momentAttempts, key: (momentAttempts[key] ?? 0) + 1};
    if (success) {
      momentSuccesses = {
        ...momentSuccesses,
        key: (momentSuccesses[key] ?? 0) + 1,
      };
    }
  }

  /// 新しいシーズンの起点にする。開幕時の能力を控え、局面の集計を空にする。
  void beginSeasonRecord() {
    seasonStart = player.attributes;
    momentAttempts = const {};
    momentSuccesses = const {};
    traitHits = const {};
  }

  /// 今の年齢のキャリア段階。
  CareerStage get stage => CareerStage.of(player.age);

  /// クラブの環境。保存はせず、クラブの強さと国の格から決まる。
  Facilities facilitiesWith(int prestige) =>
      Facilities.of(club, prestige: prestige);

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

  /// 今季の世界大会の成績。4年に1度だけ動く。
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

  /// 自分から口にした約束。1シーズンに1つだけ。取り消せない。
  ///
  /// `objective` が**向こうから降ってくる数字**なのに対して、こちらは
  /// 自分で選んだ数字。果たせば信頼と年俸が乗り、届かなければ両方を失う。
  ManagerPromise? promise;

  /// 約束を果たしたか。約束していなければ null。
  bool? get promiseKept => promise?.achievedBy(seasonStats);

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

  /// 保存データからカテゴリ別の集計を読む。知らないキーは捨てる。
  /// 知らない特性名（古い版で消したもの）は読み飛ばす。
  static Map<Trait, int> _traitCountsFrom(Object? json) {
    final result = <Trait, int>{};
    for (final e in (json as Map? ?? const {}).entries) {
      if (Trait.values.any((t) => t.name == e.key) && e.value is int) {
        result[Trait.values.byName(e.key as String)] = e.value as int;
      }
    }
    return result;
  }

  static Map<AttributeKey, int> _countsFrom(Object? json) {
    final result = <AttributeKey, int>{};
    for (final e in (json as Map? ?? const {}).entries) {
      if (AttributeKey.values.any((k) => k.name == e.key) && e.value is int) {
        result[AttributeKey.values.byName(e.key as String)] = e.value as int;
      }
    }
    return result;
  }

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
        'effort': effort.name,
        'companion': companion.name,
        'drill': drill?.name,
        'staff': staff.toJson(),
        'habits': habits.toJson(),
        'development': development.toJson(),
        'manager': manager?.toJson(),
        'directive': directive.name,
        'competitor': competitor?.toJson(),
        'partner': partner?.toJson(),
        'mentor': mentor?.toJson(),
        'rival': rival?.toJson(),
        'rehab': rehab.name,
        'rehabWatch': rehabWatch,
        'mentorManager': mentorManager,
        'morale': morale.toJson(),
        'fatigue': fatigue.toJson(),
        'form': form.toJson(),
        'preseason': preseason.name,
        'captain': captain,
        'captaincyOffered': captaincyOffered,
        'squadNumber': squadNumber,
        'nickname': nickname,
        'sponsor': sponsor?.toJson(),
        'sponsorOffer': sponsorOffer?.toJson(),
        'charity': charity,
        'nationalTeamId': nationalTeamId,
        'secondCareer': secondCareer?.name,
        'seenEvents': seenEvents,
        'news': news.map((n) => n.toJson()).toList(),
        'seasonStart': seasonStart?.toJson(),
        'backedUpYear': backedUpYear,
        'autoRestBelow': autoRestBelow,
        'focus': focus.map((d) => d.name).toList(),
        'yellowCards': yellowCards,
        'suspension': suspension,
        'tampered': tampered,
        'tacticCredit': tacticCredit,
        'traitHits': {
          for (final e in traitHits.entries) e.key.name: e.value,
        },
        'momentAttempts': {
          for (final e in momentAttempts.entries) e.key.name: e.value,
        },
        'momentSuccesses': {
          for (final e in momentSuccesses.entries) e.key.name: e.value,
        },
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
        'promise': promise?.toJson(),
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
      effort: TrainingEffort.values.any((e) => e.name == json['effort'])
          ? TrainingEffort.values.byName(json['effort'] as String)
          : TrainingEffort.normal,
      companion:
          TrainingCompanion.values.any((c) => c.name == json['companion'])
              ? TrainingCompanion.values.byName(json['companion'] as String)
              : TrainingCompanion.alone,
      drill: SetPiece.values.any((p) => p.name == json['drill'])
          ? SetPiece.values.byName(json['drill'] as String)
          : null,
      staff: StaffTeam.fromJson(json['staff'] as Map<String, dynamic>?),
      habits: Habits.fromJson(json['habits'] as Map<String, dynamic>?),
      development:
          Development.fromJson(json['development'] as Map<String, dynamic>?),
      // 監督を持たせる前の保存データには居ない。次のシーズンから付く。
      manager: json['manager'] == null
          ? null
          : Manager.fromJson(json['manager'] as Map<String, dynamic>?, Random()),
      directive: Directive.values.any((d) => d.name == json['directive'])
          ? Directive.values.byName(json['directive'] as String)
          : Directive.none,
      competitor:
          Teammate.fromJson(json['competitor'] as Map<String, dynamic>?),
      partner: Teammate.fromJson(json['partner'] as Map<String, dynamic>?),
      mentor: Teammate.fromJson(json['mentor'] as Map<String, dynamic>?),
      rival: Rival.fromJson(json['rival'] as Map<String, dynamic>?),
      rehab: RehabPlan.values.any((r) => r.name == json['rehab'])
          ? RehabPlan.values.byName(json['rehab'] as String)
          : RehabPlan.standard,
      rehabWatch: json['rehabWatch'] as int? ?? 0,
      mentorManager: json['mentorManager'] as String?,
      morale: Morale.fromJson(json['morale'] as Map<String, dynamic>?),
      fatigue: Fatigue.fromJson(json['fatigue'] as Map<String, dynamic>?),
      form: Momentum.fromJson(json['form'] as Map<String, dynamic>?),
      preseason: PreseasonPlan.values.any((p) => p.name == json['preseason'])
          ? PreseasonPlan.values.byName(json['preseason'] as String)
          : PreseasonPlan.camp,
      captain: json['captain'] as bool? ?? false,
      captaincyOffered: json['captaincyOffered'] as bool? ?? false,
      squadNumber: json['squadNumber'] as int? ?? 0,
      nickname: json['nickname'] as String?,
      sponsor: Sponsor.fromJson(json['sponsor'] as Map<String, dynamic>?),
      sponsorOffer:
          Sponsor.fromJson(json['sponsorOffer'] as Map<String, dynamic>?),
      charity: json['charity'] as bool? ?? false,
      nationalTeamId: json['nationalTeamId'] as String?,
      secondCareer:
          SecondCareer.values.any((c) => c.name == json['secondCareer'])
              ? SecondCareer.values.byName(json['secondCareer'] as String)
              : null,
      seenEvents:
          (json['seenEvents'] as List? ?? const []).cast<String>().toList(),
      news: [
        for (final n in (json['news'] as List? ?? const []))
          NewsItem.fromJson(n as Map<String, dynamic>),
      ],
      backedUpYear: json['backedUpYear'] as int? ?? 0,
      autoRestBelow:
          json['autoRestBelow'] as int? ?? defaultAutoRestBelow,
      focus: [
        for (final n in (json['focus'] as List? ?? const []))
          if (Detail.values.any((d) => d.name == n))
            Detail.values.byName(n as String),
      ],
      yellowCards: json['yellowCards'] as int? ?? 0,
      suspension: json['suspension'] as int? ?? 0,
      seasonStart: json['seasonStart'] is Map<String, dynamic>
          ? Attributes.fromJson(json['seasonStart'] as Map<String, dynamic>)
          : null,
      momentAttempts: _countsFrom(json['momentAttempts']),
      momentSuccesses: _countsFrom(json['momentSuccesses']),
      traitHits: _traitCountsFrom(json['traitHits']),
      tampered: json['tampered'] as bool? ?? false,
      tacticCredit: (json['tacticCredit'] as num?)?.toDouble() ?? 0,
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
      promise:
          ManagerPromise.fromJson(json['promise'] as Map<String, dynamic>?),
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
