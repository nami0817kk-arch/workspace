import 'dart:math';

import 'calendar.dart';
import 'career.dart';
import 'characters.dart';
import 'exp.dart';
import 'life.dart';
import 'path.dart';
import 'player.dart';
import 'difficulty.dart';
import 'goals.dart';
import 'life_log.dart';
import 'records.dart';
import 'flavor.dart';
import 'invest.dart';
import 'rival_story.dart';
import 'school.dart';
import 'snapshot.dart';
import 'world.dart';
import 'season.dart';
import 'awards.dart';
import 'marks.dart';
import 'traits.dart';
import 'training.dart' show abilityCap;

/// いま何を待っているか。画面はこれを見て出すものを決める。
enum Phase {
  term, // 季節の過ごし方を選ぶ
  event, // 出来事の選択肢を選ぶ
  pathChoice, // ドラフトに外れた。大学/社会人を選ぶか、諦めるか
  retired, // 終わり
}

/// 引退時のまとめ。
/// プロの年のはじめの、オフの過ごし方。
enum Offseason {
  camp('自主トレ', '疲れ+12。重点の能力の経験点+8。'),
  family('家族旅行', '疲れ-20、やる気+20。'),
  rehab('治療・調整', '疲れ-15。怪我中なら治りが1か月早まる。');

  const Offseason(this.label, this.description);
  final String label;
  final String description;
}

/// FA(フリーエージェント)の決断。
enum FaChoice { stay, contender, cash }

class Ending {
  const Ending({
    required this.title,
    required this.madePro,
    required this.proYears,
    required this.peakOverall,
    required this.championships,
    required this.wasTwoWay,
    this.rivalWins = 0,
    this.rivalLosses = 0,
    this.partnerName,
    this.titles = const [],
  });

  final String title;
  final bool madePro;
  final int proYears;
  final int peakOverall;
  final int championships;
  final bool wasTwoWay;
  final int rivalWins;
  final int rivalLosses;

  /// 絆が深かった恋人の名前(いれば結婚した)。
  final String? partnerName;
  bool get married => partnerName != null;

  /// 獲得したタイトル(年ごとに1つずつ、重複あり)。
  final List<String> titles;
}

/// 6歳から引退までの一代記を進める本体。画面には依存しない。
/// 乱数は注入する(テストで再現できる)。
class Game {
  Game._(this.rng, this.player, this.cast,
      [this.difficulty = Difficulty.normal]);

  /// 新しい選手で始める。`potential` を省くと乱数で決まる。
  factory Game.newGame({
    required String name,
    required Role role,
    required Random rng,
    int? potential,
    Difficulty difficulty = Difficulty.normal,
    PlayerSnapshot? parent,
  }) {
    // 二世: 親の素質を受け継ぎ(半分は親ゆずり)、良い特性を1つもらえることがある。
    final pot = potential ??
        (parent == null
            ? 30 + rng.nextInt(61)
            : ((parent.potential * 0.5 + (30 + rng.nextInt(61)) * 0.5) + 8)
                .round()
                .clamp(0, 100));
    var traits = rollInnateTraits(rng, role);
    if (parent != null && rng.nextDouble() < 0.6) {
      final cands = [
        for (final t in parent.traits)
          if (t.positive && t.appliesTo(role) && canGain(traits, t)) t
      ];
      if (cands.isNotEmpty) {
        traits = gain(traits, cands[rng.nextInt(cands.length)]);
      }
    }
    final p = Player(
      name: name,
      role: role,
      age: startAge,
      potential: pot,
      abilities: {for (final a in abilitiesOf(role)) a: 15},
      traits: traits,
    );
    final g = Game._(rng, p, Cast.initial(rng, role, p.traits), difficulty)
      .._wasTwoWay = role == Role.twoWay
      ..parentName = parent?.name;
    g.overallHistory.add(overall(p).round());
    g._note('stage', '${stageNameOf(Stage.youth)}を始めた');
    if (parent != null) {
      g._note('stage', '${parent.name}の子として生まれた(二世)');
    }
    g._newGoal();
    return g;
  }

  final Random rng;

  /// 難しさ。はじめに選び、その一生ずっと変わらない。
  final Difficulty difficulty;
  Player player;
  Condition condition = const Condition();
  int slot = 0; // 今年の何ターン目か(0始まり)。月単位か季節かは段階で決まる
  Cast cast; // 家族・ライバル・仲間・コーチ・恋人
  ExpPool exp = const ExpPool(); // 貯めた経験点。`spend` で能力に振り分ける
  Phase phase = Phase.term;
  GameEvent? pendingEvent;
  Ability _eventFocus = Ability.contact;

  Course? route; // 大学/社会人を選んだか
  bool turnedPro = false;
  int lowYears = 0;
  int proYears = 0;
  int peakOverall = 0;
  int championships = 0;
  bool _wasTwoWay = false;
  final List<double> achievements = []; // 夏の大会ごとの実績
  final List<String> log = []; // 画面に出す出来事の記録
  Outcome lastOutcome = Outcome.normal; // 直前のターンの出来(保存しない・画面の表示用)
  Map<Category, int> lastGain = const {}; // 直前のターンで貯まった経験点(保存しない・画面の表示用)
  Ending? ending;

  /// 引退後、殿堂(過去の選手の記録)に書き込み済みか。
  bool archived = false;

  /// 総合評価の推移。[0] が6歳の始まり、以降は年の終わりごとに1つずつ(人生のグラフ用)。
  final List<int> overallHistory = [];

  /// プロ入りした年齢。入っていなければ null。
  int? proStartAge;

  /// 入団した球団(架空)。プロ入りしてから。
  String? proTeam;

  /// プロのシーズンの途中経過(月ごとに進む)。シーズンが終わったら null に戻る。
  LeagueProgress? seasonProgress;

  /// 資産(万円)。プロの年俸が貯まり、投資に使える。
  int money = 0;

  /// 投資のレベル(0〜3)。
  final Map<Invest, int> invests = {};

  int investLevel(Invest i) => invests[i] ?? 0;

  /// 投資できる時: プロの間の、行動を選ぶ時。
  bool get canInvest => stage == Stage.pro && phase == Phase.term;

  /// 投資する。資産が足りない・最大レベルなら false。
  bool buyInvest(Invest i) {
    if (!canInvest) throw StateError('いまは投資できない');
    final cost = investCost(investLevel(i));
    if (cost == null || money < cost) return false;
    money -= cost;
    invests[i] = investLevel(i) + 1;
    log.add('${i.label}に投資した(Lv${invests[i]})。');
    _note('invest', '${i.label}に投資(Lv${invests[i]})');
    return true;
  }

  /// 二世のとき、親の名前(殿堂の選手)。
  String? parentName;

  /// 海外(アメリカ)のリーグでプレーしているか。移籍の判断はプロの間、年の最初だけ。
  bool overseas = false;

  /// 海外での所属(架空の球団)。
  String? overseasTeam;

  /// 自分で決めた守備位置・役割。決めていなければ null(適性がいちばん高い所を守る)。
  Pos? position;

  /// 実際に守るポジション。
  Pos get effectivePos => effectivePosition(player, position);

  /// 海外(アメリカ)へ移籍できる時: プロの24歳以上・総合評価70以上・年の最初。すでに海外なら不可。
  bool get canMoveOverseas =>
      phase == Phase.term &&
      slot == 0 &&
      stage == Stage.pro &&
      !overseas &&
      player.age >= 24 &&
      overall(player) >= 70;

  /// チーム移籍による、チーム力の増減(強豪へ+3、高額オファーの再建チーム-2)。
  int teamBoost = 0;
  bool faUsed = false;

  int get _proYears => records.where((r) => r.stage == Stage.pro).length;

  /// FA権を使える時: プロ8年目以降・国内・年の最初。一生に一度。
  bool get canUseFa =>
      phase == Phase.term &&
      slot == 0 &&
      stage == Stage.pro &&
      !overseas &&
      !faUsed &&
      _proYears >= 8;

  /// FA権を使う。残留(やる気+8)、強豪へ移籍(チーム力+3・契約金4000万・やる気-6)、
  /// 高額オファー(再建中のチームへ・チーム力-2・契約金1億)。
  void useFa(FaChoice c) {
    _require(Phase.term);
    if (!canUseFa) throw StateError('いまはFA権を使えない');
    faUsed = true;
    if (c == FaChoice.stay) {
      condition = condition.copyWith(morale: condition.morale + 8);
      log.add('FA権を行使せず、${proTeam ?? '今のチーム'}に残留した。');
      _note('team', 'FA権を行使せず残留');
      return;
    }
    final others = [
      for (final t in draftTeams)
        if (t != proTeam) t
    ];
    final next = others[rng.nextInt(others.length)];
    proTeam = next;
    if (c == FaChoice.contender) {
      teamBoost = 3;
      money += 4000;
      condition = condition.copyWith(morale: condition.morale - 6);
      log.add('FA宣言! 強豪の$nextに移籍した(契約金4000万円)。');
    } else {
      teamBoost = -2;
      money += 10000;
      log.add('FA宣言! 高額オファーを受けて$nextに移籍した(契約金1億円)。');
    }
    _note('team', 'FAで$nextに移籍');
    _newGoal();
  }

  /// 進学先(中学・高校)。入学の年に選ぶ。段階が変わると地元の学校に戻る。
  School school = School.local;

  bool get canChooseSchool =>
      phase == Phase.term &&
      slot == 0 &&
      (stage == Stage.juniorHigh || stage == Stage.highSchool) &&
      stageOf(player.age - 1) != stage;

  void chooseSchool(School s) {
    _require(Phase.term);
    if (!canChooseSchool) throw StateError('いまは進学先を決められない');
    school = s;
    log.add('${s.label}に進んだ。${s.description}');
    _note('stage', '${s.label}に入学');
  }

  bool offseasonDone = false;

  bool get canChooseOffseason =>
      phase == Phase.term && slot == 0 && stage == Stage.pro && !offseasonDone;

  /// オフの過ごし方を決める(年に1度。選ばなくてもよい)。`focus` は自主トレで伸ばす能力。
  void chooseOffseason(Offseason o, Ability focus) {
    _require(Phase.term);
    if (!canChooseOffseason) throw StateError('いまはオフの過ごし方を決められない');
    offseasonDone = true;
    switch (o) {
      case Offseason.camp:
        condition = condition.copyWith(fatigue: condition.fatigue + 12);
        if (abilitiesOf(player.role).contains(focus)) {
          exp = exp.add({categoryOf(focus): 8});
        }
        log.add('${_abilityJp(focus)}を鍛える自主トレに励んだ。');
      case Offseason.family:
        condition = condition.copyWith(
            fatigue: condition.fatigue - 20, morale: condition.morale + 20);
        log.add('家族とゆっくり過ごして、英気を養った。');
      case Offseason.rehab:
        condition = condition.copyWith(
          fatigue: condition.fatigue - 15,
          injuredTerms: max(0, condition.injuredTerms - 1),
        );
        log.add('体のケアと調整に専念した。');
    }
  }

  /// 日本に戻れる時: 海外にいて、プロの年の最初。
  bool get canReturnHome =>
      phase == Phase.term && slot == 0 && stage == Stage.pro && overseas;

  /// 海外のリーグへ移籍する。相手が強い環境で、年俸は桁違い(×2.5)。慣れない環境で気持ちが下がる。
  void moveOverseas() {
    _require(Phase.term);
    if (!canMoveOverseas) throw StateError('いまは海外へ移籍できない');
    overseas = true;
    overseasTeam = overseasTeams[rng.nextInt(overseasTeams.length)];
    condition = condition.copyWith(morale: condition.morale - 8);
    log.add('海を渡った! アメリカの$overseasTeamに移籍する。');
    _note('overseas', 'アメリカの$overseasTeamに移籍');
    _newGoal(); // 相手が強くなるので、目標も立て直す
  }

  /// 日本のリーグに戻る。
  void returnHome() {
    _require(Phase.term);
    if (!canReturnHome) throw StateError('いまは日本に戻れない');
    overseas = false;
    condition = condition.copyWith(morale: condition.morale + 6);
    log.add('日本のリーグに復帰した。');
    _note('overseas', '日本のリーグに復帰');
    _newGoal();
  }

  /// ポジションを決められる時: 中学・高校・進路(大学・社会人)の最初の年と、プロの毎年の最初。
  bool get canChoosePosition {
    if (phase != Phase.term || slot != 0) return false;
    if (stage == Stage.pro) return true;
    if (stage == Stage.youth || stage == Stage.retired) return false;
    return stageOf(player.age - 1) != stageOf(player.age);
  }

  /// ポジションを決める。決められる時だけ。選べないポジション(役割に合わない)は拒否。
  void choosePosition(Pos pos) {
    _require(Phase.term);
    if (!canChoosePosition) throw StateError('いまはポジションを決められない');
    if (!positionsFor(player.role).contains(pos)) {
      throw ArgumentError('この役割では選べない: ${pos.label}');
    }
    position = pos;
    final adj = positionTeamAdjust(player, pos);
    log.add('ポジションを${pos.label}に決めた。'
        '${adj == 0 ? '' : '(適性が低く、チーム力$adj)'}');
    _note('position', 'ポジションを${pos.label}に決めた');
  }

  /// 年ごとの成績(大会・シーズン)。成績画面とエンディングに出す。
  final List<SeasonRecord> records = [];

  /// 日本代表として出た世界大会(U-12・U-15・U-18・U-23・プロ)の結果。
  final List<WorldRecord> worldRecords = [];

  /// 直前に起きた出来事(同じものが続かないようにする)。
  String? _lastEventId;

  /// 最近起きた出来事(同じものが続かないように。保存はしない)。
  final List<String> _recentEvents = [];

  /// 今年の目標。年の初めに決まり、大会(プロはシーズン)の成績で達成かどうかが決まる。
  Goal? goal;

  /// これまでに行動した回数と、コーチから「多くを学んだ」ときの回数(ボーナスの大きさに使う)。
  int turnCount = 0;
  int lastCoachTurn = 0;

  /// 今年の練習(練習・特訓)と休養の回数。年末にログに出して戻す。
  /// 今季ここまでの月ごとの成績(4〜9月)。シーズンの記録に写して空にする。
  List<String> monthRows = [];
  int trainCount = 0;
  int restCount = 0;

  /// 同じ能力を重点に練習・特訓を続けた回数(継続は力なり)。
  int focusStreak = 0;
  Ability? lastFocus;

  /// 継続ボーナスの倍率: 3回続けて+2%、6回続けて+4%。
  double get streakBonus =>
      focusStreak >= 6 ? 1.04 : (focusStreak >= 3 ? 1.02 : 1.0);

  /// 人生の節目(入学・進路・ドラフト・特性の習得・転向・引退)。経歴の年表に出す。
  final List<LifeEvent> lifeLog = [];

  void _note(String kind, String text) =>
      lifeLog.add(LifeEvent(player.age, kind, text));

  Stage get stage => phase == Phase.retired
      ? Stage.retired
      : stageOf(player.age, turnedPro: turnedPro);

  /// ドラフトにかかるときの実績: 直近3回の大会の平均。
  double get recentAchievement {
    if (achievements.isEmpty) return 0;
    final r = achievements.length > 3
        ? achievements.sublist(achievements.length - 3)
        : achievements;
    return r.reduce((a, b) => a + b) / r.length;
  }

  /// ドラフトの見込み(運は含めない目安)。指名の前の年・再挑戦の間だけ。
  String? get draftOutlook {
    if (turnedPro || phase != Phase.term) return null;
    final inWindow =
        route != null || (stage == Stage.highSchool && player.age >= 17);
    if (!inWindow) return null;
    final margin = draftScore(player, recentAchievement) -
        (draftLine + difficulty.draftShift);
    if (margin >= 10) return 'ほぼ確実';
    if (margin >= 3) return '有望';
    if (margin >= -3) return '五分五分';
    if (margin >= -10) return '厳しい';
    return 'かなり厳しい';
  }

  /// プロで、総合が低い年が続いているときの、戦力外までの残り年数。なければ null。
  int? get releaseWarning {
    if (!turnedPro || lowYears <= 0 || phase == Phase.retired) return null;
    return releaseYears - lowYears;
  }

  // ── ターンの選択 ──

  /// 今のターンの表示名。月単位なら「7月」、季節なら「夏」。
  String get slotName => slotLabel(stage, slot);

  /// 今の年のターン数(12 または 4)。
  int get slotsInYear => slotsPerYear(stage);

  Motivation get motivation => motivationOf(condition.morale);

  /// 今のターンの過ごし方を決める。`focus` は練習・特訓・研究で伸ばす能力。
  /// 能力は直接は上がらず、経験点が貯まる。`spend` / `autoSpend` で振り分ける。
  void choose(Plan action, [Ability? focus]) {
    _require(Phase.term);
    final f = focus ?? abilitiesOf(player.role).first;
    if (!abilitiesOf(player.role).contains(f)) {
      throw ArgumentError('${player.role.name} にその能力は無い: ${f.name}');
    }
    final share = slotShare(stage);
    final wasInjured = condition.injured;
    turnCount++;
    final r = playTerm(player, condition, action, f, rng,
        share: share,
        trainBonus: trainerMultiplier(investLevel(Invest.trainer)),
        recoveryBonus: dietitianMultiplier(investLevel(Invest.dietitian)),
        injuryFactor: medicalFactor(investLevel(Invest.medical)));
    player = r.player;
    condition = r.condition;
    // _afterCast が経験点(コーチのボーナス)を直接足すことがあるので、先に評価する。
    var gained = wasInjured ? r.exp : _afterCast(action, f, r.exp);
    if (school.expMultiplier != 1.0 && gained.isNotEmpty) {
      gained = {
        for (final e in gained.entries)
          e.key: (e.value * school.expMultiplier).round(),
      };
    }
    if (school.fatigue > 0) {
      condition =
          condition.copyWith(fatigue: condition.fatigue + school.fatigue);
    }
    if (!wasInjured && (action == Plan.train || action == Plan.special)) {
      focusStreak = (lastFocus == f) ? focusStreak + 1 : 1;
      lastFocus = f;
      if (focusStreak == 6 && rng.nextDouble() < 0.25) {
        // 継続の先に開眼する(その能力が少し跳ねる)。
        player = player.copyWith(abilities: {
          ...player.abilities,
          f: (player.of(f) + 2).clamp(0, abilityCap),
        });
        log.add('${_abilityJp(f)}を鍛え続けた先に、開眼した!(+2)');
        _note('trait', '${_abilityJp(f)}に開眼');
      }
      final k = categoryOf(f);
      if (streakBonus > 1 && gained[k] != null) {
        gained = {...gained, k: (gained[k]! * streakBonus).round()};
      }
    }
    if (difficulty != Difficulty.normal) {
      gained = {
        for (final e in gained.entries)
          e.key: (e.value * difficulty.expMultiplier).round(),
      };
    }
    exp = exp.add(gained);
    lastGain = gained;
    lastOutcome = wasInjured ? Outcome.normal : r.outcome;
    if (action == Plan.train || action == Plan.special) trainCount++;
    if (action == Plan.rest) restCount++;
    if (r.gotInjured) {
      _note('injury', injuryNameOf(player.age, slot));
    }
    if (r.gotInjured) {
      log.add('怪我をしてしまった(${injuryNameOf(player.age, slot)})。');
    }
    if (isTournamentSlot(stage, slot)) {
      _playSummer();
    } else if (stage == Stage.pro && slot < 6) {
      _playLeagueMonth();
    }

    final e = drawEvent(rng,
        share: share,
        stage: stage,
        cast: cast,
        exclude: _lastEventId,
        recent: _recentEvents.toSet());
    if (e == null) {
      _nextSlot();
    } else {
      pendingEvent = e;
      _lastEventId = e.id;
      _recentEvents.add(e.id);
      if (_recentEvents.length > 4) _recentEvents.removeAt(0);
      _eventFocus = f;
      phase = Phase.event;
    }
  }

  void resolveEvent(int index) {
    _require(Phase.event);
    final ch = pendingEvent!.choices[index];
    final before = player.traits;
    final r = ch.risky != null
        ? ch.risky!(player, condition, _eventFocus, rng)
        : ch.apply(player, condition, _eventFocus);
    player = r.player;
    condition = r.condition;
    ch.onCast?.call(cast, rng);
    for (final t in player.traits.difference(before)) {
      _note('trait', '特性「${t.label}」を習得');
    }
    _checkCoach();
    pendingEvent = null;
    phase = Phase.term;
    _nextSlot();
  }

  // ── 経験点の振り分け ──

  /// 能力を1つ上げる。足りなければ false。
  bool spend(Ability a) {
    final r = buy(player, exp, a);
    if (r == null) return false;
    player = r.player;
    exp = r.pool;
    return true;
  }

  /// 買えるだけ上げる。上がった数を返す。
  int spendAll(Ability a) {
    final r = buyAll(player, exp, a);
    player = r.player;
    exp = r.pool;
    return r.bought;
  }

  /// おまかせ: 種類ごとに低い能力から順に振り分ける。
  void autoSpend() {
    final r = autoSpendExp(player, exp);
    player = r.player;
    exp = r.pool;
  }

  /// プロの間はいつでも役割を変えられる(二刀流にする/戻す)。
  void changeRole(Role to) {
    _require(Phase.term);
    player = switchRole(player, to, stage);
    if (to == Role.twoWay) _wasTwoWay = true;
    log.add('${roleNameOf(to)}に転向した。');
    _note('role', '${roleNameOf(to)}になった');
  }

  /// プロの間は自分で引退を決められる。
  void retire() {
    _require(Phase.term);
    if (!canChooseRetire(stage)) throw StateError('引退を選べるのはプロの間だけ');
    _retire('自ら引退を決めた');
  }

  // ── ドラフトに外れたとき ──

  void chooseRoute(Course r) {
    _require(Phase.pathChoice);
    route = r;
    phase = Phase.term;
    log.add('${courseNameOf(r)}で再挑戦する。');
    _note('route', '${courseNameOf(r)}で再挑戦');
  }

  void giveUp() {
    _require(Phase.pathChoice);
    _retire('プロを諦めた');
  }

  // ── 管理者機能(調整・検証用。ホーム画面のタイトルを7回タップで有効) ──
  //
  // 通常の遊びでは使わない。上限(特性は4つまで)や矛盾(大器晩成と早熟など)も無視して書き換える。

  /// 素質(0〜100)を書き換える。
  void adminSetPotential(int v) {
    player = player.copyWith(potential: v.clamp(0, 100));
  }

  /// 特性を、上限や矛盾を無視して丸ごと置き換える。
  void adminSetTraits(Set<Trait> t) {
    player = player.copyWith(traits: Set.of(t));
  }

  void adminSetAbility(Ability a, int v) {
    if (!abilitiesOf(player.role).contains(a)) return;
    player =
        player.copyWith(abilities: {...player.abilities, a: v.clamp(0, 99)});
  }

  /// 経験点を全種類に足す(負でも可。0未満にはならない)。
  void adminAddExp(int n) {
    exp = ExpPool({for (final c in Category.values) c: max(0, exp.of(c) + n)});
  }

  /// コーチのコツを書き換える。`tipsNeeded` 以上にすると、その場で特性を習得する。
  void adminSetCoachTips(int n) {
    final coach = cast.coach;
    if (coach == null) return;
    coach.tips = n.clamp(0, tipsNeeded);
    _checkCoach();
  }

  /// コーチが教える特性を差し替える(null なら教えられない)。
  void adminSetCoachTeaches(Trait? t) {
    final i = cast.members.indexWhere((m) => m.kind == Kind.coach);
    if (i < 0) return;
    final c = cast.members[i];
    cast.members[i] = Character(
      id: c.id,
      name: c.name,
      kind: c.kind,
      bond: c.bond,
      specialty: c.specialty,
      teaches: t,
      tips: c.tips,
      talent: c.talent,
    );
  }

  // ── 内部 ──

  String _abilityJp(Ability a) => switch (a) {
        Ability.contact => 'ミート',
        Ability.power => 'パワー',
        Ability.speed => '走力',
        Ability.fielding => '守備',
        Ability.eye => '選球眼',
        Ability.stuff => '球威',
        Ability.control => '制球',
        Ability.stamina => 'スタミナ',
      };

  /// 友情タッグ・コーチ・恋人/家族への影響。経験点の量を返す。
  Map<Category, int> _afterCast(
      Plan action, Ability focus, Map<Category, int> gained) {
    final out = Map<Category, int>.of(gained);
    final trains = action == Plan.train ||
        action == Plan.special ||
        action == Plan.match ||
        action == Plan.lesson;
    if (trains && gained.isNotEmpty) {
      final mate = cast.pickTagMate(focus, rng);
      if (mate != null) {
        for (final k in out.keys.toList()) {
          out[k] = (out[k]! * tagMultiplier * tagTraitMultiplier(player.traits))
              .round();
        }
        mate.addBond(8);
        log.add('${mate.name}と友情タッグ練習!');
      }
    }
    if (action == Plan.lesson) {
      final coach = cast.coach;
      if (coach != null) {
        coach.tips++;
        _checkCoach();
      }
    }
    if (action == Plan.social) {
      (cast.lover ?? cast.family)?.addBond(10);
    }
    return out;
  }

  /// コツが貯まったら、コーチの教える特性を習得する。
  void _checkCoach() {
    final coach = cast.coach;
    if (coach == null || coach.tips < tipsNeeded) return;
    coach.tips = 0;
    final t = coach.teaches;
    if (t != null && canGain(player.traits, t)) {
      player = player.copyWith(traits: gain(player.traits, t));
      log.add('${coach.name}のコツをつかんだ! 特性「${t.label}」を習得。');
      _note('trait', '特性「${t.label}」を習得(コーチ ${coach.name})');
    } else {
      // 学びのボーナスは、前の学びからの間があくほど大きい(コーチばかりが最善にならないように)。
      final bonus = min(40, 3 * (turnCount - lastCoachTurn));
      lastCoachTurn = turnCount;
      exp = exp.add(spreadExp(player.role, bonus));
      log.add('${coach.name}から多くを学んだ。(経験点を獲得)');
    }
  }

  void _require(Phase p) {
    if (phase != p) throw StateError('いまは ${phase.name} の段階: ${p.name} は選べない');
  }

  ({int team, List<int> opponents}) get _league => _leagueBase(stage);

  ({int team, List<int> opponents}) _leagueBase(Stage st) {
    final raw = _leagueRaw(st);
    final b = st == Stage.pro
        ? (team: raw.team + teamBoost, opponents: raw.opponents)
        : (st == Stage.juniorHigh || st == Stage.highSchool)
            ? (team: raw.team + school.teamAdjust, opponents: raw.opponents)
            : raw;
    if (overseas && st == Stage.pro) {
      // 海外は相手が強く(+3)。
      return (
        team: b.team,
        opponents: [for (final o in b.opponents) o + 3]
      );
    }
    return b;
  }

  ({int team, List<int> opponents}) _leagueRaw(Stage stage) => switch (stage) {
        Stage.youth => (team: 35, opponents: const [25, 30, 35, 40]),
        Stage.juniorHigh => (team: 42, opponents: const [32, 38, 44, 50]),
        Stage.highSchool => (team: 50, opponents: const [40, 46, 52, 58, 64]),
        Stage.pathChoice => (team: 58, opponents: const [48, 54, 60, 66]),
        _ => (team: 65, opponents: const [55, 60, 66, 72, 78]),
      };

  /// 年の初めに、今年の目標を決める。
  void _newGoal() {
    if (phase == Phase.retired) return;
    goal = makeGoal(
      stage: stage,
      role: player.role,
      ov: overall(player),
      rounds: _league.opponents.length,
      pick: rng.nextDouble(),
    );
  }

  /// 成績が出たら、目標を判定して、達成なら経験点と気持ちをもらう。
  void _judgeGoal(SeasonRecord r) {
    final g = goal;
    if (g == null || g.achieved != null) return;
    g.achieved = g.judge(r);
    if (g.achieved!) {
      final n = goalExpFor(stage, g.level);
      exp = exp.add(spreadExp(player.role, n));
      condition = condition.copyWith(
          morale: condition.morale + goalMoraleReward[g.level]);
      log.add('今年の目標「${g.text}」を達成! 経験点+$n(全種類)');
    } else {
      condition = condition.copyWith(
          morale: condition.morale + goalMoraleMiss[g.level]);
      log.add('今年の目標「${g.text}」には届かなかった。');
    }
  }

  /// 目標のむずかしさを選べる時(年の最初の行動の前)。
  bool get canChooseGoal =>
      goal != null &&
      goal!.achieved == null &&
      phase == Phase.term &&
      slot == 0;

  /// 目標のむずかしさを変える(0=やさしい / 1=ふつう / 2=むずかしい)。年の最初の行動の前だけ。
  void chooseGoalLevel(int level) {
    _require(Phase.term);
    if (!canChooseGoal) throw StateError('いまは目標を選べない');
    if (level < 0 || level > 2) throw ArgumentError('level $level');
    goal = goal!.withLevel(level, maxRounds: _league.opponents.length);
  }

  /// プロのシーズンの1か月ぶん(約20試合)を進める。怪我中は自分は出られない。
  void _playLeagueMonth() {
    final l = _league;
    final team = l.team +
        traitTeamBonus(player.traits) +
        positionTeamAdjust(player, effectivePos);
    final prev = seasonProgress ?? const LeagueProgress();
    // この1か月だけの成績を出してから、これまでに足す(月間の成績を見せるため)。
    final month = playLeagueChunk(
      traitAdjusted(player),
      LeagueProgress(games: prev.games),
      teamLevel: team,
      opponents: l.opponents,
      rng: rng,
      count: 20,
      condition: condition.value,
      available: !condition.injured,
    );
    seasonProgress = LeagueProgress(
      games: month.games,
      wins: prev.wins + month.wins,
      losses: prev.losses + month.losses,
      line: prev.line + month.line,
      missed: prev.missed + month.missed,
    );
    _monthlyReport(month);
  }

  /// 月ごとの成績をログに残す。出来が飛び抜けていれば「月間MVP」。
  void _monthlyReport(LeagueProgress m) {
    _allStar();
    final d = describeLine(m.line);
    if (m.missed >= 20) {
      monthRows.add('$slotName: 怪我で全休 / ${m.wins}勝${m.losses}敗');
      log.add('$slotName: 怪我で全試合を欠場。チームは${m.wins}勝${m.losses}敗。');
      return;
    }
    log.add('$slotName: ${d.isEmpty ? '' : '$d。'}チームは${m.wins}勝${m.losses}敗。');
    monthRows
        .add('$slotName: ${d.isEmpty ? '出場なし' : d} / ${m.wins}勝${m.losses}敗');
    final crowd = (1.5 +
        popularityOf(records, worldRecords) * 0.04 +
        (m.wins + m.losses == 0 ? 0 : m.wins / (m.wins + m.losses)) * 1.5);
    log.add('観客動員: 平均${crowd.toStringAsFixed(1)}万人。');
    final rs = storyOfCharacter(cast.rival)?.avoiding(proTeam);
    final duel =
        rs == null ? null : rivalDuelLine(rs, player.age, slot, m.line);
    if (duel != null) log.add(duel);
    final mvp = (m.line.hasBatting &&
            m.line.atBats >= 50 &&
            (m.line.ops ?? 0) >= 1.000) ||
        (m.line.hasPitching && m.line.outs >= 18 && (m.line.era ?? 99) <= 1.50);
    if (mvp) {
      log.add('$slotNameの月間MVPに選ばれた!');
      _note('title', '$slotNameの月間MVP');
      condition = condition.copyWith(morale: condition.morale + 5);
    }
  }

  /// シーズン中盤(4か月目)に、ここまでの成績と人気でオールスターに選ばれることがある。
  void _allStar() {
    if (slot != 3 || condition.injured) return;
    final prog = seasonProgress;
    if (prog == null || prog.line.games < 40) return;
    final l = prog.line;
    final pop = popularityOf(records, worldRecords);
    final good = (l.hasBatting && (l.ops ?? 0) >= 0.800) ||
        (l.hasPitching && (l.era ?? 99) <= 3.00);
    if (!good && pop < 55) return;
    log.add('ファン投票とリーグ推薦で、オールスターに選ばれた!');
    _note('title', 'オールスターに選出');
    condition = condition.copyWith(morale: condition.morale + 6);
  }

  /// シーズンの最後(10月)に、残りの試合を進めて、1年ぶんの結果にする。
  LeagueSeason _finishLeague(Player fighter, int team, List<int> opponents) {
    var prog = seasonProgress ?? const LeagueProgress();
    final rest = leagueGames - prog.games;
    if (rest > 0) {
      prog = playLeagueChunk(
        fighter,
        prog,
        teamLevel: team,
        opponents: opponents,
        rng: rng,
        count: rest,
        condition: condition.value,
        available: !condition.injured,
      );
    }
    seasonProgress = null;
    return prog.toSeason();
  }

  /// 大会(アマチュア)またはシーズン(プロ)を行い、成績を残す。
  void _playSummer() {
    final l = _league;
    final isPro = stage == Stage.pro;
    final fighter = traitAdjusted(player);
    final team = l.team +
        traitTeamBonus(player.traits) +
        positionTeamAdjust(player, effectivePos);
    final tournament = isPro
        ? null
        : playTournament(
            fighter,
            teamLevel: team,
            opponents: l.opponents,
            rng: rng,
            condition: condition.value,
          );
    final league = isPro ? _finishLeague(fighter, team, l.opponents) : null;

    var ach = tournament?.achievement ?? 0;
    bool? rivalWon;
    final rival = cast.rival;
    if (rival != null) {
      final mine = overall(player) + (rng.nextDouble() * 2 - 1) * 8;
      if (mine >= rivalLevel(rival, player.age)) {
        rivalWon = true;
        cast.rivalWins++;
        ach = min(100, ach + 5);
        condition = condition.copyWith(morale: condition.morale + 10);
        log.add('${rival.name}に勝った!');
      } else {
        rivalWon = false;
        cast.rivalLosses++;
        condition = condition.copyWith(morale: condition.morale - 8);
        log.add('${rival.name}に負けた…');
      }
      rival.addBond(5);
    }

    if (league != null) {
      final titles =
          titlesOf(league.line, games: league.games, rank: league.rank);
      final proBefore = records.where((r) => r.stage == Stage.pro).toList();
      final awards = awardsOf(
        league.line,
        games: league.games,
        firstYear: proBefore.isEmpty,
        prevGames: proBefore.isEmpty ? null : proBefore.last.line.games,
        fielding: player.abilities[Ability.fielding] ?? 0,
        isBatter: league.line.hasBatting && !league.line.hasPitching,
      );
      final rec = SeasonRecord(
        age: player.age,
        stage: stage,
        line: league.line,
        teamWins: league.wins,
        teamLosses: league.losses,
        rank: league.rank,
        titles: titles,
        rivalWon: rivalWon,
        overseas: overseas,
        awards: awards,
        months: List.of(monthRows),
        twoWay: player.role == Role.twoWay,
      );
      monthRows = [];
      records.add(rec);
      _judgeGoal(rec);
      if (league.missed > 0) log.add('怪我で${league.missed}試合を欠場した。');
      if (league.rank == 1) {
        championships++;
        log.add('リーグ優勝!');
        log.add(
            '優勝パレードには${paradeCrowd(popularityOf(records, worldRecords))}万人が集まった。');
        if (wonSeries(player.name, player.age, league.line)) {
          log.add('日本シリーズを制して、日本一に輝いた!');
          awards.add('日本一');
        } else {
          log.add('日本シリーズでは惜しくも敗れた。');
        }
      } else {
        log.add('今季は${league.rank}位(${league.wins}勝${league.losses}敗)。');
      }
      final d = describeLine(league.line);
      if (d.isNotEmpty) log.add('今季成績: $d');
      for (final t in titles) {
        log.add('タイトル獲得: $t!');
      }
      for (final w in awards) {
        log.add('表彰: $w!');
      }
      var careerBefore = const Line();
      for (final r in proBefore) {
        careerBefore += r.line;
      }
      for (final m in careerMarks(careerBefore, careerBefore + league.line)) {
        log.add('記録達成: $m!');
        _note('title', m);
      }
      log.add(coachWordOf(player));
      // 年俸が資産に入る。
      money += salaryOf(rec);
      final cm = cmFeeOf(popularityOf(records, worldRecords));
      if (cm > 0) {
        money += cm;
        log.add('CM出演料: ${fmtMoney(cm)}');
      }
      // 契約更改(前の年からの増減)。保存はせず、成績から計算する。
      final pro = records.where((r) => r.stage == Stage.pro).toList();
      final now = salaryOf(rec);
      if (pro.length >= 2) {
        final prev = salaryOf(pro[pro.length - 2]);
        final diff = now - prev;
        final mark = diff > 0
            ? '(アップ)'
            : diff < 0
                ? '(ダウン)'
                : '(現状維持)';
        log.add('契約更改: 年俸 ${fmtSalary(prev)} → ${fmtSalary(now)} $mark');
      } else {
        log.add('契約更改: 年俸 ${fmtSalary(now)}');
      }
    } else if (tournament != null) {
      achievements.add(ach);
      final rec = SeasonRecord(
        age: player.age,
        stage: stage,
        line: tournament.line,
        roundsWon: tournament.roundsWon,
        rounds: tournament.rounds,
        rivalWon: rivalWon,
      );
      records.add(rec);
      _judgeGoal(rec);
      _logRounds(tournament);
      if (tournament.champion) {
        championships++;
        log.add('夏の大会で優勝した!');
      } else {
        // 負けた試合(次の試合)の名前で、どこまで行ったかを伝える。
        final lost = roundLabel(tournament.roundsWon, tournament.rounds);
        log.add(tournament.roundsWon == 0
            ? '夏の大会は初戦で敗れた。'
            : tournament.roundsWon == tournament.rounds - 1
                ? '夏の大会は準優勝。'
                : '夏の大会は$lostで敗れた。');
      }
      final d = describeLine(tournament.line);
      if (d.isNotEmpty) log.add('大会成績: $d');
    }
    _playWorld();
  }

  /// 勝ち抜き戦の各試合を、ログに残す(相手・勝ち負け・自分の出来)。
  void _logRounds(Tournament t) {
    final own = affiliationOf(stage, player.name, proTeam: proTeam);
    for (var i = 0; i < t.games.length; i++) {
      final g = t.games[i];
      final name = opponentName(stage, player.age, i,
          corporate: route == Course.corporate, own: own);
      final d = describeGame(g.line);
      log.add('${g.won ? '○' : '●'} ${roundLabel(i, t.rounds)} vs $name'
          '${d.isEmpty ? '' : ' — $d'}'
          '${isHeroGame(g.line, won: g.won) ? ' ★殊勲(${heroNoteOf(g.line)})' : ''}');
      if (i == t.rounds - 1 && g.won && isHeroGame(g.line, won: true)) {
        _note('title', '決勝で殊勲の活躍');
      }
    }
  }

  /// この年に世界大会があれば、代表に選ばれたかを決め、選ばれたら日本代表として戦う。
  /// 選ばれるのは総合評価が目安を上回る選手(運±6)。怪我中は辞退。
  void _playWorld() {
    final ev =
        worldEventFor(stage: stage, age: player.age, hasRoute: route != null);
    if (ev == null) return;
    if (condition.injured) {
      log.add('${ev.name}の代表候補だったが、怪我で辞退した。');
      return;
    }
    final score = overall(player) + (rng.nextDouble() * 2 - 1) * 6;
    if (score < ev.selectLine) return;
    log.add('${ev.name}の日本代表に選ばれた!');
    _note('world', '${ev.name}の日本代表に選出');
    final t = playTournament(
      traitAdjusted(player),
      teamLevel: ev.team +
          traitTeamBonus(player.traits) +
          positionTeamAdjust(player, effectivePos),
      opponents: ev.opponents,
      rng: rng,
      condition: condition.value + worldBonus(player.traits),
    );
    final w = wrapWorld(event: ev, age: player.age, tournament: t);
    for (var i = 0; i < t.games.length; i++) {
      final d = describeGame(t.games[i].line);
      log.add('${t.games[i].won ? '○' : '●'} ${roundLabel(i, t.rounds)} '
          'vs ${ev.countries[i]}${d.isEmpty ? '' : ' — $d'}');
    }
    worldRecords.add(w.record);
    final rec = w.record;
    if (rec.champion) {
      log.add('${ev.name}で優勝! 日本が世界一になった!');
      _note('world', '${ev.name}で優勝(世界一)');
      condition = condition.copyWith(morale: condition.morale + 25);
      exp = exp.add(spreadExp(player.role, goalRewardExp(stage)));
    } else {
      log.add('${ev.name}は${rec.lostTo}に敗れ、${rec.resultText}。');
      _note('world', '${ev.name} ${rec.resultText}');
      condition = condition.copyWith(morale: condition.morale + 8);
    }
    final d = describeLine(rec.line);
    if (d.isNotEmpty) log.add('${ev.name}の成績: $d');
  }

  void _nextSlot() {
    if (slot + 1 >= slotsPerYear(stage)) {
      _endYear();
    } else {
      slot++;
    }
  }

  void _endYear() {
    final before = stage;
    slot = 0;
    offseasonDone = false;
    monthRows = [];
    seasonProgress = null;
    player = endOfYear(player);
    condition = endOfYearCondition(condition);
    final partner = cast.lover ?? cast.family;
    if (partner != null && partner.bond >= 50) {
      condition = condition.copyWith(fatigue: condition.fatigue - 5); // 支えてくれる
    }
    if (trainCount + restCount > 0) {
      log.add(yearSummaryOf(trainCount, restCount));
    }
    trainCount = 0;
    restCount = 0;
    peakOverall = max(peakOverall, overall(player).round());
    overallHistory.add(overall(player).round());
    // ライバルの人生の知らせ(進路・入団・活躍・引退)。
    final rs = storyOfCharacter(cast.rival)?.avoiding(proTeam);
    if (rs != null) log.addAll(rivalNews(rs, player.age));

    if (phase != Phase.retired) log.add('── ${player.age}歳 ──');
    final an = ageNote(player.age);
    if (an != null && phase != Phase.retired) log.add(an);
    if (turnedPro) {
      if (proTeam != null && proYears >= 1 && proYears % 3 == 0) {
        log.add('新人の${kohaiOf(proTeam!, player.age)}が入団してきた。');
      }
      proYears++;
      lowYears = nextLowYears(player, lowYears);
      if (mustRetire(player, lowYears)) {
        final why = isReleased(lowYears) ? '戦力外になった' : '年齢により引退した';
        log.add('$why。');
        _retire(isReleased(lowYears) ? '戦力外通告を受けて引退' : '年齢により引退');
      }
    } else if (route == null && player.age == proEntryAge + 1) {
      _draft();
    } else if (route != null && player.age == graduationAge(route!)) {
      _draft();
    }
    _rotateCast(before);
    _newGoal();
    if (turnedPro && phase != Phase.retired && proTeam != null) {
      log.add('${player.age}歳シーズン開幕。${overseas ? overseasTeam : proTeam}'
          'のスローガンは「${sloganOf(proTeam!, player.age)}」。'
          '本拠地は${stadiumOf(proTeam!)}。');
    }
  }

  /// 段階が変わったら、仲間とコーチが替わる(高校で恋人が現れる)。
  void _rotateCast(Stage before) {
    if (phase == Phase.retired) return;
    final after = stage;
    if (after != before) {
      cast.rotate(after, rng, player.role, player.traits);
      school = School.local;
      if (after != Stage.pro && after != Stage.pathChoice) {
        _note('stage', '${stageNameOf(after)}に進んだ');
      }
    }
  }

  void _draft() {
    final luck = (rng.nextDouble() * 2 - 1) * draftLuck;
    final margin = draftScore(player, recentAchievement) +
        luck -
        (draftLine + difficulty.draftShift);
    if (margin >= 0) {
      turnedPro = true;
      proStartAge = player.age;
      final team = draftTeams[rng.nextInt(draftTeams.length)];
      proTeam = team;
      final round = draftRound(margin);
      log.add('ドラフトで指名された! $team から$round位指名。');
      final mates = classmatesOf(player.name, team);
      log.add(
          '同期入団: ${[for (final m in mates) '${m.$1}(${m.$2}位)'].join('・')}');
      _note('draft', '$team から$round位指名を受けて、プロ入り');
    } else if (route == null) {
      log.add('ドラフトで指名されなかった。');
      _note('draft', 'ドラフトで指名されなかった');
      phase = Phase.pathChoice;
    } else {
      log.add('再挑戦も実らなかった。');
      _note('draft', '再挑戦のドラフトでも指名されなかった');
      _retire('再挑戦も実らず引退');
    }
  }

  void _retire(String reason) {
    _note('retire', reason);
    phase = Phase.retired;
    pendingEvent = null;
    ending = _buildEnding();
  }

  Ending _buildEnding() {
    final String title;
    if (!turnedPro && proYears == 0) {
      title = 'プロにはなれなかった';
    } else if (peakOverall >= 80) {
      title = 'レジェンド';
    } else if (peakOverall >= 65) {
      title = '一流選手';
    } else if (peakOverall >= 50) {
      title = 'レギュラー';
    } else {
      title = '無名の選手';
    }
    return Ending(
      title: title,
      madePro: turnedPro,
      proYears: proYears,
      peakOverall: peakOverall,
      championships: championships,
      wasTwoWay: _wasTwoWay,
      rivalWins: cast.rivalWins,
      rivalLosses: cast.rivalLosses,
      partnerName: (cast.lover != null && cast.lover!.bond >= 80)
          ? cast.lover!.name
          : null,
      titles: [for (final r in records) ...r.titles],
    );
  }

  // ── 保存 ──

  Map<String, dynamic> toJson() => {
        'player': player.toJson(),
        'condition': condition.toJson(),
        'slot': slot,
        'exp': exp.toJson(),
        'cast': cast.toJson(),
        'phase': phase.name,
        'pendingEvent': pendingEvent?.id,
        'eventFocus': _eventFocus.name,
        'route': route?.name,
        'turnedPro': turnedPro,
        'lowYears': lowYears,
        'proYears': proYears,
        'peakOverall': peakOverall,
        'championships': championships,
        'wasTwoWay': _wasTwoWay,
        'achievements': achievements,
        'archived': archived,
        'overallHistory': overallHistory,
        'proStartAge': proStartAge,
        'proTeam': proTeam,
        'position': position?.name,
        'overseas': overseas,
        'seasonProgress': seasonProgress?.toJson(),
        'parentName': parentName,
        'money': money,
        'invests': {for (final e in invests.entries) e.key.name: e.value},
        'overseasTeam': overseasTeam,
        'teamBoost': teamBoost,
        'school': school.name,
        'offseasonDone': offseasonDone,
        'faUsed': faUsed,
        'records': [for (final r in records) r.toJson()],
        'worldRecords': [for (final r in worldRecords) r.toJson()],
        'lifeLog': [for (final e in lifeLog) e.toJson()],
        'focusStreak': focusStreak,
        'turnCount': turnCount,
        'lastCoachTurn': lastCoachTurn,
        'monthRows': monthRows,
        'trainCount': trainCount,
        'restCount': restCount,
        'lastFocus': lastFocus?.name,
        'goal': goal?.toJson(),
        'difficulty': difficulty.name,
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Game.fromJson(Map<String, dynamic> j, Random rng) {
    T pick<T extends Enum>(List<T> all, Object? name, T orElse) {
      for (final v in all) {
        if (v.name == name) return v;
      }
      return orElse;
    }

    final player =
        Player.fromJson((j['player'] as Map?)?.cast<String, dynamic>() ?? {});
    final castJson = (j['cast'] as Map?)?.cast<String, dynamic>();
    final g = Game._(
      rng,
      player,
      castJson != null
          ? Cast.fromJson(castJson)
          : Cast.initial(rng, player.role, player.traits),
      Difficulty.parse(j['difficulty']),
    );
    g.condition = Condition.fromJson(
        (j['condition'] as Map?)?.cast<String, dynamic>() ?? {});
    g.slot = (j['slot'] as num?)?.toInt() ?? 0;
    g.focusStreak = (j['focusStreak'] as num?)?.toInt() ?? 0;
    g.turnCount = (j['turnCount'] as num?)?.toInt() ?? 0;
    g.lastCoachTurn = (j['lastCoachTurn'] as num?)?.toInt() ?? 0;
    g.monthRows = [
      for (final t in (j['monthRows'] as List?) ?? const []) t as String
    ];
    g.trainCount = (j['trainCount'] as num?)?.toInt() ?? 0;
    g.restCount = (j['restCount'] as num?)?.toInt() ?? 0;
    g.lastFocus = Ability.parse((j['lastFocus'] as String?) ?? '');
    g.exp = ExpPool.fromJson((j['exp'] as Map?)?.cast<String, dynamic>() ?? {});
    g.phase = pick(Phase.values, j['phase'], Phase.term);
    g.pendingEvent = events.where((e) => e.id == j['pendingEvent']).firstOrNull;
    if (g.phase == Phase.event && g.pendingEvent == null) g.phase = Phase.term;
    g._eventFocus = pick(Ability.values, j['eventFocus'], Ability.contact);
    g.route = Course.values.where((r) => r.name == j['route']).firstOrNull;
    g.turnedPro = (j['turnedPro'] as bool?) ?? false;
    g.lowYears = (j['lowYears'] as num?)?.toInt() ?? 0;
    g.proYears = (j['proYears'] as num?)?.toInt() ?? 0;
    g.peakOverall = (j['peakOverall'] as num?)?.toInt() ?? 0;
    g.championships = (j['championships'] as num?)?.toInt() ?? 0;
    g.archived = (j['archived'] as bool?) ?? false;
    g.overallHistory.addAll(((j['overallHistory'] as List?) ?? const [])
        .map((e) => (e as num).toInt()));
    g.proStartAge = (j['proStartAge'] as num?)?.toInt();
    g.proTeam = j['proTeam'] as String?;
    g.position = Pos.parse(j['position'] as String?);
    g.overseas = (j['overseas'] as bool?) ?? false;
    g.parentName = j['parentName'] as String?;
    final sp = j['seasonProgress'];
    if (sp is Map) {
      g.seasonProgress = LeagueProgress.fromJson(sp.cast<String, dynamic>());
    }
    g.money = (j['money'] as num?)?.toInt() ?? 0;
    for (final e in ((j['invests'] as Map?) ?? const {}).entries) {
      final i = Invest.parse(e.key as String);
      if (i != null) {
        g.invests[i] = (e.value as num).toInt().clamp(0, maxInvestLevel);
      }
    }
    g.overseasTeam = j['overseasTeam'] as String?;
    g.teamBoost = (j['teamBoost'] as num?)?.toInt() ?? 0;
    g.school = School.parse(j['school']);
    g.offseasonDone = (j['offseasonDone'] as bool?) ?? false;
    g.faUsed = (j['faUsed'] as bool?) ?? false;
    g.goal = Goal.fromJson(j['goal']);
    g.lifeLog.addAll([
      for (final e in (j['lifeLog'] as List?) ?? const [])
        LifeEvent.fromJson((e as Map).cast<String, dynamic>()),
    ]);
    g.worldRecords.addAll([
      for (final r in (j['worldRecords'] as List?) ?? const [])
        WorldRecord.fromJson((r as Map).cast<String, dynamic>()),
    ]);
    g.records.addAll([
      for (final r in (j['records'] as List?) ?? const [])
        SeasonRecord.fromJson((r as Map).cast<String, dynamic>()),
    ]);
    g._wasTwoWay = (j['wasTwoWay'] as bool?) ?? g.player.role == Role.twoWay;
    g.achievements.addAll(((j['achievements'] as List?) ?? const [])
        .map((e) => (e as num).toDouble()));
    g.slot = g.slot.clamp(0, slotsPerYear(g.stage) - 1);
    if (g.phase == Phase.retired) g.ending = g._buildEnding();
    return g;
  }
}
