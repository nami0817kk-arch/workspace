import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/save_repository.dart';
import '../game/career_engine.dart';
import '../game/formulas.dart';
import '../game/match_engine.dart';
import '../game/dependencies.dart';
import '../game/life_events.dart';
import '../game/national.dart';
import '../game/newsroom.dart';
import '../game/scenarios.dart';
import '../game/person.dart';
import '../game/weekly_plan.dart';
import '../models/agent.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/competition.dart';
import '../models/development.dart';
import '../models/entourage.dart';
import '../models/injury.dart';
import '../models/life.dart';
import '../models/life_event.dart';
import '../models/news.dart';
import '../models/personality.dart';
import '../models/promise.dart';
import '../game/promises.dart';
import '../models/traits.dart';
import '../models/look.dart';
import '../models/physique.dart';
import '../models/player.dart';
import '../models/season.dart';
import '../game/world.dart';
import '../models/support.dart';
import '../models/training.dart';

/// 試合を終えた1週間で起きたこと。画面で一度見せる。
class WeekReport {
  const WeekReport({
    this.timeline = const [],
    this.autoRested = false,
    this.outcome,
    this.companion = TrainingCompanion.alone,
    this.trained,
    this.learned,
    this.weakFootAwakened = false,
    this.plateau = false,
    this.drilled,
    this.redirected = false,
    this.deadBall,
    this.newInjury,
    this.recovered = false,
  });

  /// その試合で起きたこと（得点・失点の時間）。
  final List<MatchEvent> timeline;

  /// 練習で伸びた詳細能力。
  /// 疲れていたので、自動で休養にした週か。
  ///
  /// 黙って差し替えると「練習したのに伸びない」と見える。
  final bool autoRested;

  /// その週の手応え。休養の週は null。
  ///
  /// 伸びなかった週が、運が悪かったのか踏み込みが足りなかったのかが
  /// 分からないままだった。
  final TrainingOutcome? outcome;

  /// その週、誰と組んだか。
  final TrainingCompanion companion;

  final Detail? trained;

  /// その週に覚えた個人技。
  final Signature? learned;

  /// 逆足が形になったか。
  final bool weakFootAwakened;

  /// 停滞期に入っているか。
  final bool plateau;

  /// 居残りで伸びたセットプレー。
  final SetPiece? drilled;

  /// 狙った能力が土台に阻まれ、土台のほうが伸びたか。
  final bool redirected;

  /// 試合で回ってきたセットプレーの結果。
  final String? deadBall;

  /// 新たに負傷したらその内容。
  final Injury? newInjury;

  /// 離脱から復帰したか。
  final bool recovered;

  bool get isEmpty =>
      trained == null &&
      learned == null &&
      !weakFootAwakened &&
      drilled == null &&
      deadBall == null &&
      newInjury == null &&
      !recovered;
}

/// 自動で進めた区間のまとめ。
class SimReport {
  const SimReport({
    required this.results,
    required this.stoppedBy,
    this.injury,
  });

  final List<MatchResult> results;

  /// 何で止まったか。
  final SimStop stoppedBy;

  /// 負傷で止まったならその内容。
  final Injury? injury;

  int get played => results.length;
  int get won => results.where((r) => r.won).length;
  int get drawn => results.where((r) => r.drawn).length;
  int get lost => played - won - drawn;
  int get goals => results.fold(0, (s, r) => s + r.goals);
  int get assists => results.fold(0, (s, r) => s + r.assists);

  double? get averageRating {
    final rated = results.where((r) => r.rating != null).toList();
    if (rated.isEmpty) return null;
    return rated.fold<double>(0, (s, r) => s + r.rating!) / rated.length;
  }
}

/// 自動進行が止まる理由。
enum SimStop {
  seasonEnd('シーズン終了'),
  injury('負傷'),
  callUp('代表ウィーク'),
  limit('区切り');

  const SimStop(this.label);

  final String label;
}

/// アプリ全体の状態。画面はこれを購読する。
class CareerController extends ChangeNotifier {
  CareerController({
    SaveRepository? repository,
    CareerEngine? careerEngine,
    MatchEngine? matchEngine,
    Random? random,
  })  : _repository = repository ?? SaveRepository(),
        _career = careerEngine ?? CareerEngine(),
        _match = matchEngine ?? MatchEngine(),
        _random = random ?? Random();

  final SaveRepository _repository;
  final CareerEngine _career;
  final MatchEngine _match;
  /// 波・停滞・出来事の抽選に使う。差し込めるようにしてあるのは、
  /// バランスのシミュレーションを同じ種で再現できるようにするため。
  final Random _random;
  late final LifeEvents _life = LifeEvents(random: _random);

  /// 決着を待っているピッチ外の出来事。画面はこれを見て問いかけを出す。
  LifeEvent? pendingEvent;

  /// 能力値の総量。伸びたかどうかの判定に使う。
  static int _sumOf(Attributes attributes) =>
      Detail.values.fold(0, (s, d) => s + attributes.detail(d));

  /// 見出しを積む。古いものから落として、直近だけを持つ。
  void _publish(CareerState state, List<NewsItem> items) {
    if (items.isEmpty) return;
    state.news = [...items, ...state.news].take(Newsroom.keep).toList();
  }

  /// 直近の見出し。
  List<NewsItem> get news => _state?.news ?? const [];

  /// 次の試合が持つ意味。
  FixtureStake get stake =>
      _state == null ? FixtureStake.none : Newsroom.stakeFor(_state!);

  /// 試合を1つ終えるごとの、心と身体の積み上げ。
  ///
  /// 出れば気持ちが上がり、外れれば沈む。疲れは戻らずに溜まっていく。
  /// 好不調の波はここで出入りする。
  void _updateMood(CareerState state, MatchResult result) {
    final played = result.appearance == Appearance.start ||
        result.appearance == Appearance.sub;

    // 落ち込みだけは特性で和らぐ。上がるほうは誰でも同じ。
    final swing = switch (result.appearance) {
      Appearance.start => 1,
      Appearance.sub => 1,
      Appearance.benched => -3,
      Appearance.injured => -4,
      // 自分のせいで出られないのが一番こたえる。
      Appearance.suspended => -5,
    };
    final traits = state.player.traits;
    var morale = state.morale.bump(swing < 0
        ? (swing * traits.moraleFactor).round()
        : (swing * traits.moraleGainFactor).round());
    if (played && result.won) {
      morale = morale.bump((1 * traits.moraleGainFactor).round());
    }
    if (played && (result.rating ?? 6) >= 7.5) {
      morale = morale.bump((2 * traits.moraleGainFactor).round());
    }
    state.morale = morale;

    // 疲れの溜まり方は特性で変わる。
    final gained = switch (result.appearance) {
      Appearance.start => 3,
      Appearance.sub => 2,
      Appearance.benched || Appearance.injured || Appearance.suspended => 0,
    };
    state.fatigue =
        state.fatigue.add((gained * state.player.traits.fatigueFactor).round());

    // 波。続いていれば1試合ぶん進め、切れていれば直近の出来から引き直す。
    state.form = state.form.tick();
    if (!state.form.isActive) {
      state.form = Momentum.roll(
        _random,
        recent: [
          for (final r in state.leagueResults)
            if (r.rating != null) r.rating!,
        ],
        // 波に乗りやすい選手は、良いほうにも悪いほうにも振れやすい。
        factor: state.player.traits.formFactor,
      );
    }

    // ピッチの外の出来事。試合と試合の間に起きる。
    if (pendingEvent == null && _life.fires()) {
      // 名前のある人は、出来事に出てきて初めて人になる。
      final people = <PersonKind, String>{
        if (state.manager != null) PersonKind.manager: state.manager!.name,
        if (state.competitor != null)
          PersonKind.competitor: state.competitor!.name,
        if (state.partner != null) PersonKind.partner: state.partner!.name,
        if (state.mentor != null) PersonKind.mentor: state.mentor!.name,
        if (state.rival != null) PersonKind.rival: state.rival!.name,
        PersonKind.agent: state.agent.name,
      };
      pendingEvent = _life.pick(
        LifeContext(
          age: state.player.age,
          fame: state.reputation.fame,
          savings: state.finances.savings,
          abroad: state.club.countryId != state.player.nationality.primary,
          afterInjury: state.rehabWatch > 0,
          sponsorOffered: state.sponsorOffer != null,
          captaincyOffered: state.captaincyOffered,
          lowMorale: state.morale.needsCare,
          people: people,
          overall: state.player.overall,
        ),
        seen: state.seenEvents.toSet(),
      )?.withNames(people);
    }
  }

  /// 出来事に答える。効きはすべて小さいが、選んだことは残る。
  Future<void> resolveEvent(LifeChoice choice) async {
    final state = _state;
    final event = pendingEvent;
    if (state == null || event == null) return;

    final e = choice.effect;
    state.morale = state.morale.bump(e.morale);
    state.reputation =
        state.reputation.copyWith(fame: state.reputation.fame + e.fame);
    state.relations =
        state.relations.bump(manager: e.manager, teammates: e.teammates);
    // 入る金も出ていく金も、貯蓄の増減として同じ扱いにする。
    if (e.money != 0) state.finances = state.finances.spend(-e.money);
    state.fatigue = state.fatigue.add(e.fatigue);

    var personality = state.player.personality;
    personality = personality.bump(PersonalityAxis.confidence, e.confidence);
    personality = personality.bump(PersonalityAxis.ambition, e.ambition);
    personality =
        personality.bump(PersonalityAxis.professionalism, e.professionalism);
    personality = personality.bump(PersonalityAxis.temper, e.temper);
    // 練習の外で身に付くもの。土台が足りなければ土台のほうが伸びる。
    //
    // **ポテンシャルに達していたら伸びない。** 練習も試合の成長も上限で
    // 止まるのに、出来事だけが突き抜けると、上限そのものが意味を失う。
    var attributes = state.player.attributes;
    if (e.train != null && !state.player.atPotential) {
      attributes = attributes.bumpDetail(
          Dependencies.resolve(e.train!, attributes), e.trainAmount);
    }
    state.player = state.player.copyWith(
      personality: personality,
      attributes: attributes,
      condition: state.player.condition + e.condition,
    );
    // 閃き。すでに3つ持っていれば何も起きない（learn が弾く）。
    if (e.insight != null) {
      state.development = state.development.learn(e.insight!);
    }

    switch (e.special) {
      case LifeSpecial.acceptSponsor:
        state.sponsor = state.sponsorOffer;
        state.sponsorOffer = null;
      case LifeSpecial.declineSponsor:
        state.sponsorOffer = null;
      case LifeSpecial.takeCaptain:
        state.captain = true;
        state.captaincyOffered = false;
      case LifeSpecial.declineCaptain:
        state.captaincyOffered = false;
      case LifeSpecial.foundCharity:
        state.charity = true;
      case LifeSpecial.none:
        break;
    }
    // 外から見える節目は、見出しにも残す。
    final headline = Newsroom.lifeMoment(state, e.special);
    if (headline != null) _publish(state, [headline]);

    if (event.once && !state.seenEvents.contains(event.id)) {
      state.seenEvents = [...state.seenEvents, event.id];
    }
    pendingEvent = null;
    await _persist();
  }

  /// プレシーズンの過ごし方を決める。
  Future<void> setPreseason(PreseasonPlan plan) async {
    final state = _state;
    if (state == null) return;
    state.preseason = plan;
    state.player = state.player.copyWith(condition: plan.condition);
    state.reputation = state.reputation
        .copyWith(fame: state.reputation.fame + plan.fame);
    await _persist();
  }

  /// 代表を選ぶ。複数の国籍を持っているときだけ意味がある。
  Future<void> chooseNationalTeam(String countryId) async {
    final state = _state;
    if (state == null) return;
    if (!state.player.nationality.has(countryId)) return;
    state.nationalTeamId = countryId;
    await _persist();
  }

  /// 引退後の道を選ぶ。
  Future<void> chooseSecondCareer(SecondCareer choice) async {
    final state = _state;
    if (state == null) return;
    state.secondCareer = choice;
    await _persist();
  }

  /// 引退後の道の見立て。
  SecondCareer get suggestedSecondCareer => _state == null
      ? SecondCareer.quiet
      : _career.secondCareerFor(_state!);

  /// 今節の起用。評価点で決めたうえで、疲れていれば休まされることがある。
  Appearance _selectionFor(CareerState state) {
    final decided = MatchEngine.decideAppearance(
      state.leagueResults,
      bonus: _appearanceBonus(state),
    );
    if (decided != Appearance.start) return decided;
    return _match.rotates(
      condition: state.player.condition,
      fatigue: state.fatigue.value,
    )
        ? Appearance.sub
        : Appearance.start;
  }

  /// 出場機会の下駄。監督の信頼・戦術との相性・方針・序列を足し合わせる。
  ///
  /// 評価点だけで決めると、監督も方針も競争相手も飾りになる。
  /// 練習した週の負傷判定に使う土台の確率。
  ///
  /// 専属スタッフ・生活習慣・累積疲労・復帰直後かどうかで変わる。
  /// 判定（`rollInjury`）と管理画面の「効き」が同じ式を読むために切り出してある。
  static double injuryBaseChanceFor(CareerState state) =>
      Formulas.injuryBaseChance *
      state.staff.injuryFactor *
      state.habits.injuryFactor *
      state.fatigue.injuryFactor *
      // 復帰直後は無理が効かない。強行すればここで返ってくる。
      (state.rehabWatch > 0 ? state.rehab.relapseFactor : 1.0);

  /// 今のまま練習した週に怪我をする確率。
  double get injuryChanceNow {
    final state = _state;
    if (state == null) return 0;
    return MatchEngine.injuryChance(state.player,
        baseChance: injuryBaseChanceFor(state));
  }

  /// 次節の起用の見通し。判定と同じ式から出す。
  SelectionOutlook? get outlook {
    final state = _state;
    if (state == null || state.retired) return null;
    return SelectionOutlook.of(state, bonus: _appearanceBonus(state));
  }

  static double _appearanceBonus(CareerState state) {
    var bonus = Person.appearanceBonusFrom(state.relations);
    final manager = state.manager;
    if (manager != null) {
      bonus += manager.appearanceBonus(
          state.player.attributes, state.player.position);
    }
    bonus += state.directive.appearanceBonus;
    // 同ポジションの競争相手との力の差。序列はここで決まる。
    final competitor = state.competitor;
    if (competitor != null) {
      bonus +=
          ((state.player.overall - competitor.overall) * 0.02).clamp(-0.15, 0.15);
    }
    return bonus;
  }

  /// 練習の効きに掛かる環境の倍率。クラブの設備・メンター・方針。
  static double _environmentFactor(CareerState state) {
    final facilities =
        state.facilitiesWith(World.byId(state.club.countryId).prestige);
    return facilities.growthFactor *
        (state.mentor?.mentorFactor(state.player.age) ?? 1.0) *
        state.directive.growthFactor *
        state.morale.growthFactor *
        state.preseason.growthFactor;
  }

  CareerState? _state;
  MatchInProgress? _inProgress;
  bool _loading = true;

  /// 直近の1週間で起きたこと。試合結果の画面で見せる。
  WeekReport lastWeek = const WeekReport();

  CareerState? get state => _state;
  MatchInProgress? get currentMatch => _inProgress;
  bool get loading => _loading;
  bool get hasCareer => _state != null;

  Future<void> init() async {
    _state = await _repository.load();
    _loading = false;
    notifyListeners();
  }

  Future<void> startCareer({
    required String name,
    required Position position,
    required int age,
    required Agent agent,
    Side side = Side.center,
    Physique? physique,
    PlayerLook? look,
    int? squadNumber,
    String? countryId,
    Map<AttributeKey, int> tweaks = const {},
  }) async {
    _state = _career.startCareer(
      name: name,
      position: position,
      age: age,
      agent: agent,
      side: side,
      physique: physique,
      look: look,
      squadNumber: squadNumber,
      countryId: countryId,
      tweaks: tweaks,
    );
    _state!.beginSeasonRecord();
    _inProgress = null;
    lastWeek = const WeekReport();
    await _persist();
  }

  /// 今週の練習メニューを決める。
  Future<void> setMenu(TrainingMenu menu) async {
    final state = _state;
    if (state == null) return;
    state.menu = menu;
    await _persist();
  }

  /// 今週の居残り練習を決める。null ならやらない。
  Future<void> setDrill(SetPiece? drill) async {
    final state = _state;
    if (state == null) return;
    state.drill = drill;
    await _persist();
  }

  /// 今週どこまで踏み込むか。
  Future<void> setEffort(TrainingEffort effort) async {
    final state = _state;
    if (state == null) return;
    state.effort = effort;
    await _persist();
  }

  /// 今週、誰と組むか。居ない相手は選べない。
  Future<void> setCompanion(TrainingCompanion companion) async {
    final state = _state;
    if (state == null) return;
    if (!state.companionChoices.contains(companion)) return;
    state.companion = companion;
    await _persist();
  }

  /// 組んだ相手との関係が、その週に動く。
  void _applyCompanion(CareerState state, TrainingCompanion companion) {
    switch (companion) {
      case TrainingCompanion.alone:
        return;
      case TrainingCompanion.partner:
        final partner = state.partner;
        if (partner == null) return;
        state.partner = partner
            .withSynergy(partner.synergy + Formulas.companionSynergyGain);
      case TrainingCompanion.mentor:
        // 年長者から盗む。プロ意識はゆっくりしか動かない。
        if (_random.nextDouble() < Formulas.mentorProfessionalismChance) {
          state.player = state.player.copyWith(
            personality: state.player.personality
                .bump(PersonalityAxis.professionalism, 1),
          );
        }
      case TrainingCompanion.rival:
        // 張り合うと、ロッカールームでの立場が上がる。
        state.relations = state.relations
            .bump(teammates: Formulas.companionTeammatesGain);
    }
  }

  /// 監督に約束する。1シーズンに1つだけ。取り消せない。
  ///
  /// 与えられた目標と違って、これは**自分で選んだ数字**。
  /// 果たせば信頼と年俸が乗り、届かなければ両方を失う。
  Future<void> makePromise(ManagerPromise promise) async {
    final state = _state;
    if (state == null) return;
    if (!PromiseOffers.canPromise(state)) return;
    state.promise = promise;
    // 口にしたことは記事になる。逃げ道を消すのがこの機能の要。
    _publish(state, [Newsroom.promiseMade(state, promise)]);
    await _persist();
  }

  /// クラブに方針を伝える。
  Future<void> setDirective(Directive directive) async {
    final state = _state;
    if (state == null) return;
    state.directive = directive;
    state.relations = state.relations.bump(
      manager: directive.managerDrift,
      teammates: directive.teammatesDrift,
    );
    await _persist();
  }

  /// 復帰の進め方を決める。
  Future<void> setRehab(RehabPlan plan) async {
    final state = _state;
    if (state == null) return;
    state.rehab = plan;
    await _persist();
  }

  /// ポジションを変える。適性が足りなければ何も起きない。
  ///
  /// 本職を離れると総合力が落ちるが、出続ければ適性は上がっていく。
  /// 衰えた選手が生き延びる道であり、序列争いから逃げる道でもある。
  bool convertPosition(Position position) {
    final state = _state;
    if (state == null) return false;
    if (!state.player.aptitude.canConvert(position)) return false;
    state.player = state.player.copyWith(position: position);
    _persist();
    return true;
  }

  /// 生活習慣を変える。
  Future<void> setHabits(Habits habits) async {
    final state = _state;
    if (state == null) return;
    state.habits = habits;
    await _persist();
  }

  /// 専属スタッフを雇う（level 0 で解雇）。
  ///
  /// 契約金は貯蓄から前払いする。払えないなら雇えない。
  bool hireStaff(StaffKind kind, int level) {
    final state = _state;
    if (state == null) return false;
    final next = state.staff.withLevel(kind, level);
    final delta = next.costPerSeason - state.staff.costPerSeason;
    if (delta > state.finances.savings) return false;
    state.staff = next;
    _persist();
    return true;
  }

  /// 自動で進めるときの選び方を決める。
  Future<void> setSimStyle(SimStyle style) async {
    final state = _state;
    if (state == null) return;
    state.simStyle = style;
    await _persist();
  }

  /// 次の試合を始める。
  ///
  /// 代表ウィークなら代表戦、負傷中なら試合には出ない。
  ///
  /// [forcedScenarios] は管理画面（開発用）から局面を指定して入るときだけ使う。
  void startNextMatch({List<Scenario>? forcedScenarios}) {
    final state = _state;
    if (state == null || state.retired) return;
    if (state.pendingInternational) return startInternational();
    if (state.seasonFinished) return;

    final matchday = state.matchday;
    _inProgress = _match.start(
      forcedScenarios: forcedScenarios,
      matchday: matchday,
      player: state.player,
      club: state.club,
      opponent: state.opponentFor(matchday),
      home: state.isHome(matchday),
      development: state.development,
      allyBonus: state.partner?.synergyBonus ?? 0,
      moodBonus: state.morale.chanceModifier + state.form.chanceModifier,
      extraRating: state.captain ? Formulas.captainRatingBonus : 0,
      // 監督が重く見る能力。試合で選んだことが監督に届く唯一の経路。
      favoured: state.manager?.tactic.favours ?? const [],
      // 累積疲労は終盤の落ち込みに効く。ここまで試合の中では何も起きなかった。
      fatigue: state.fatigue.value,
      appearance: state.suspended
          ? Appearance.suspended
          : state.injured
              ? Appearance.injured
              // 登録メンバーから外れていると、そもそもベンチにも入れない。
              : !state.squadStatus.canPlay
                  ? Appearance.benched
                  : _selectionFor(state),
    );
    notifyListeners();
  }

  /// 代表戦を始める。招集されていなければ何も起きない（週だけ消える）。
  void startInternational() {
    final state = _state;
    if (state == null || !state.pendingInternational) return;

    if (!state.calledUp || state.injured) {
      state.pendingInternational = false;
      _persist();
      return;
    }

    _inProgress = _match.start(
      matchday: state.matchday,
      player: state.player,
      club: National.home,
      opponent: _career.extras.pickOpponent(),
      home: true,
      appearance: Appearance.start,
      development: state.development,
      international: true,
    );
    notifyListeners();
  }

  ScenarioResolution? choose(int optionIndex) {
    final match = _inProgress;
    if (match == null || match.isFinished) return null;
    final resolution = match.choose(match.current.options[optionIndex]);
    notifyListeners();
    return resolution;
  }

  /// 今の試合を最後まで自動で進めて終える。
  ///
  /// 局面の途中からでも呼べる。残りをスタイルに沿って選ぶ。
  Future<MatchResult?> simulateMatch() async {
    final state = _state;
    if (state == null) return null;
    if (_inProgress == null) startNextMatch();
    final match = _inProgress;
    if (match == null) return null;
    match.autoPlay(state.simStyle);
    return finishMatch();
  }

  /// 止まる理由が出るまで自動で進める。
  ///
  /// 負傷・代表ウィーク・シーズン終了で止まる。何も起きなくても
  /// [limit] 試合で一度止めて、状況を見せる。
  Future<SimReport> simulateUntilEvent({int limit = 38}) async {
    final results = <MatchResult>[];
    var stop = SimStop.limit;
    Injury? injury;

    for (var i = 0; i < limit; i++) {
      final state = _state;
      if (state == null || state.retired) break;
      if (state.seasonFinished) {
        stop = SimStop.seasonEnd;
        break;
      }
      if (state.pendingInternational) {
        stop = SimStop.callUp;
        break;
      }
      final wasInjured = state.injured;
      final result = await simulateMatch();
      if (result == null) break;
      results.add(result);

      if (!wasInjured && lastWeek.newInjury != null) {
        stop = SimStop.injury;
        injury = lastWeek.newInjury;
        break;
      }
      if (_state!.seasonFinished) {
        stop = SimStop.seasonEnd;
        break;
      }
      if (_state!.pendingInternational) {
        stop = SimStop.callUp;
        break;
      }
    }

    return SimReport(results: results, stoppedBy: stop, injury: injury);
  }

  /// 試合を終えて結果を反映する。成長・練習・負傷もここでまとめて進める。
  Future<MatchResult?> finishMatch() async {
    final state = _state;
    final match = _inProgress;
    if (state == null || match == null) return null;

    final result = match.finish();
    _career.applyResult(state, result);

    if (state.rehabWatch > 0) state.rehabWatch--;
    _applyCards(state, result);
    _updateMood(state, result);
    _publish(state, Newsroom.afterMatch(state, result));

    // 出たポジションの適性と、相方との呼吸が伸びる。
    if (result.appearance == Appearance.start ||
        result.appearance == Appearance.sub) {
      state.player = state.player.copyWith(
        aptitude: state.player.aptitude.playedAt(state.player.position),
      );
      final partner = state.partner;
      if (partner != null) {
        // 出ただけで +2 だった頃は、プレイヤーの関与がゼロだった。
        // 味方を活かす手を選んだぶんが、そのまま呼吸になる。
        state.partner = partner.withSynergy(
            partner.synergy + 1 + result.assistAttempts * 2);
      }
      _applyTacticFit(state, result);
    }

    // 経験・選択の癖・相手への慣れは、出た試合ぶんだけ積み上がる。
    state.development = state.development.afterMatch(
      appearance: result.appearance,
      international: result.international,
      style: ClubStyle.of(match.opponent),
      used: match.resolutions.map((r) => r.key),
    );

    // どの能力で、何回勝負して、何回通ったか。練習の答え合わせに使う。
    for (final resolution in match.resolutions) {
      state.recordMoment(resolution.key, success: resolution.success);
    }
    // どの特性が、何回の局面で効いたか。特性の答え合わせに使う。
    state.recordTraitHits(match.traitHits);

    if (result.international) {
      state.pendingInternational = false;
      _inProgress = null;
      lastWeek = WeekReport(timeline: match.timeline);
      await _persist();
      return result;
    }

    var player = state.player;
    Injury? newInjury;
    var recovered = false;

    if (state.injured) {
      // 離脱中は成長も練習もしない。試合数だけ消化する。
      final next = state.injury!.tick();
      if (next.healed) {
        state.injury = null;
        recovered = true;
        state.rehabWatch = Formulas.rehabWatchMatches;
        player = player.copyWith(condition: state.rehab.conditionOnReturn);
      } else {
        state.injury = next;
      }
      lastWeek =
          WeekReport(timeline: match.timeline, recovered: recovered);
    } else {
      final before = _sumOf(player.attributes);
      player = player.copyWith(
        attributes: _match.grow(
          player,
          result.rating,
          used: match.successes,
          focus: state.focus,
          declineOffset: state.staff.declineAgeOffset,
          plateau: state.development.inPlateau,
          environment: _environmentFactor(state),
        ),
      );
      // 疲れているなら、その週は自動で休む。居残りも止める
      // （居残りだけ残すと、休んだつもりで怪我をする）。
      final tired = state.shouldAutoRest(
        MatchEngine.conditionAfterMatch(player,
            played: result.appearance != Appearance.benched),
      );
      // 組む相手が移籍でいなくなっていたら、一人に戻す。
      // 居ない相手と組んだことにして手応えだけ上がるのが一番まずい。
      if (!state.companionChoices.contains(state.companion)) {
        state.companion = TrainingCompanion.alone;
      }
      final companion =
          tired ? TrainingCompanion.alone : state.companion;
      final week = _match.applyWeek(
        player,
        menu: tired ? TrainingMenu.rest : state.menu,
        effort: tired ? TrainingEffort.easy : state.effort,
        companion: companion,
        drill: tired ? null : state.drill,
        staff: state.staff,
        habits: state.habits,
        development: state.development,
        focus: state.focus,
        plateau: state.development.inPlateau,
        environment: _environmentFactor(state),
        played: result.appearance != Appearance.benched,
      );
      player = player.copyWith(
        attributes: week.attributes,
        condition: week.condition,
        setPieces: week.setPieces,
        physique: week.physique,
      );
      // 完全に休んだ週だけ、溜まった疲労が抜ける。リカバリーでは抜けない。
      if ((tired ? TrainingMenu.rest : state.menu) == TrainingMenu.rest) {
        state.fatigue = state.fatigue.add(-Formulas.restFatigueRelief);
      }
      // 追い込んだ週の積み上げ。限界突破の条件になる。
      if (week.outcome == TrainingOutcome.great) {
        state.development = state.development
            .copyWith(greatWeeks: state.development.greatWeeks + 1);
      }
      // 伸びが続けば、どこかで足踏みが来る。
      state.development = state.development.afterGrowth(
        grew: _sumOf(week.attributes) > before,
        random: _random,
        plateauFactor: state.player.traits.plateauFactor,
      );
      if (week.learned != null) {
        state.development = state.development.learn(week.learned!);
      }
      newInjury = week.injury ??
          _match.rollInjury(player, baseChance: injuryBaseChanceFor(state));
      if (newInjury != null) {
        // 復帰の進め方で離脱の長さが変わる。
        newInjury = Injury(
          name: newInjury.name,
          severity: newInjury.severity,
          matchesOut: max(
            1,
            (state.rehab.lengthFor(newInjury) *
                    state.player.traits.rehabFactor)
                .round(),
          ),
        );
        final (attributes, potential) =
            _match.applySevereInjury(player, newInjury);
        player = Player.rebuild(player, attributes: attributes, potential: potential);
        state.injury = newInjury;
      }
      // 組んだ相手との関係は、組んだその週に動く。
      // 「一緒に練習した」ことが呼吸にもロッカールームにも届く。
      _applyCompanion(state, companion);

      lastWeek = WeekReport(
        timeline: match.timeline,
        autoRested: tired,
        outcome: week.outcome,
        companion: companion,
        trained: week.trained,
        learned: week.learned,
        weakFootAwakened: week.weakFootAwakened,
        plateau: state.development.inPlateau,
        drilled: week.drilled,
        redirected: week.redirected,
        deadBall: match.deadBallText,
        newInjury: newInjury,
      );
    }

    state.player = player;

    // 代表の招集は節が進むごとに見直す。
    state.calledUp = _career.extras.shouldCallUp(state);
    if (_career.extras.isBreakAfter(result.matchday) && !state.seasonFinished) {
      state.pendingInternational = true;
    }

    _inProgress = null;
    await _persist();
    return result;
  }

  List<TransferOffer> get offers =>
      _state == null ? const [] : _career.offersFor(_state!);

  TransferOffer? get renewalOffer =>
      _state == null ? null : _career.renewalOffer(_state!);

  ClubFate get fate =>
      _state == null ? ClubFate.stay : _career.fateOf(_state!);

  bool get canRetire => _state != null && _career.canRetire(_state!);
  bool get mustRetire => _state != null && _career.mustRetire(_state!);

  (NegotiationResult, TransferOffer?) negotiate(TransferOffer offer) {
    final state = _state;
    if (state == null) return (NegotiationResult.refused, offer);
    return _career.negotiate(state, offer);
  }

  /// 代理人に売り込ませる前金（万円）。
  int get solicitCost =>
      _state == null ? 0 : _career.solicitCostFor(_state!);

  /// 代理人に売り込ませる。前金は貯蓄から引かれる。
  (bool, List<TransferOffer>) solicitOffers() {
    final state = _state;
    if (state == null) return (false, const []);
    final result = _career.solicitOffers(state);
    _persist();
    return result;
  }

  int takeHome(int salary) =>
      _state == null ? salary : _career.takeHome(_state!, salary);

  /// シーズン終了時の処理（大陸カップの結果を確定させる）。
  Future<void> finishSeason() async {
    final state = _state;
    if (state == null || !state.seasonFinished) return;
    _career.resolveSeasonEnd(state);
    // 口にした約束の結末を、記事として残す。
    if (state.promise != null &&
        !state.news.any((n) =>
            n.year == state.year &&
            n.matchday == state.fixtures.length &&
            n.headline.contains(state.promise!.label))) {
      _publish(state, [Newsroom.promiseSettled(state)]);
    }
    final fate = _career.fateOf(state);
    _publish(
      state,
      Newsroom.afterSeason(
        state,
        promoted: fate == ClubFate.promoted,
        relegated: fate == ClubFate.relegated,
        champion: state.leaguePosition == 1 && state.club.tier == 1,
      ),
    );
    await _persist();
  }

  /// 今の移籍市場の状態。
  /// 移籍市場の窓と、いま話が動くかどうか。
  ///
  /// 窓は計算していたのに**どこにも出ていなかった**ので、「契約が残っている
  /// から来ないのか、時期ではないのか」が分からなかった。理由まで書く。
  String get transferWindowLabel {
    final state = _state;
    if (state == null) return '';
    final window = transferWindow;
    if (!window.isOpen) {
      return '${window.label}。話が動くのはシーズンの終わり。';
    }
    if (state.contractYears > 1) {
      return '${window.label}。ただし契約があと${state.contractYears}年ある——'
          '残り1年になるまで、よそからは動かせない。';
    }
    return '${window.label}。契約は残り${state.contractYears}年、話が来る。';
  }

  TransferWindow get transferWindow =>
      _state == null ? TransferWindow.closed : _career.competitions.windowAt(_state!);

  Future<void> advanceSeason({
    required TransferOffer accepted,
    BodyPlan bodyPlan = BodyPlan.maintain,
  }) async {
    final state = _state;
    if (state == null) return;
    final moved = accepted.club.name != state.club.name;
    // 貯蓄が尽きると専属スタッフは全員離れる。黙って消えると、
    // 翌季から練習が効かなくなった理由が分からない。
    final hadStaff = !state.staff.isEmpty;
    _state =
        _career.advanceSeason(state, accepted: accepted, bodyPlan: bodyPlan);
    if (hadStaff && _state!.staff.isEmpty) {
      _publish(_state!, [Newsroom.staffDismissed(_state!)]);
    }
    if (moved || accepted.isRenewal) {
      _publish(_state!, [
        Newsroom.transfer(
          _state!,
          toClub: accepted.club.name,
          fee: accepted.fee,
          loan: accepted.loan,
          renewal: accepted.isRenewal && !moved,
        ),
      ]);
    }
    // 新しいクラブで登録メンバーに入れるかを決める。
    _state!.squadStatus = _career.competitions.registrationFor(_state!);
    // 今季の伸びは、このシーズンの開幕からの差で見る。
    _state!.beginSeasonRecord();
    _inProgress = null;
    lastWeek = const WeekReport();
    await _persist();
  }

  Future<void> retire() async {
    final state = _state;
    if (state == null) return;
    _state = _career.retire(state);
    _inProgress = null;
    await _persist();
  }

  /// 生活水準を変える。金の使い道は、毎週ではなく気が向いたときに決める。
  /// 監督の求める形に沿ったか。信頼をその場で動かす。
  ///
  /// 監督は `fitFor` で能力値だけを見ていた——「あなたの数字」を採点する
  /// 装置で、あなたが何を選んだかは見ていなかった。ここで初めて、
  /// 試合の選択が監督に届く。**監督に合わせるか、自分の型を通すか**。
  void _applyTacticFit(CareerState state, MatchResult result) {
    final manager = state.manager;
    if (manager == null) return;
    final shift = manager.trustShift(
      followed: result.followedTactic,
      against: result.againstTactic,
    );
    if (shift == 0) return;
    state.tacticCredit += shift;
    // 端数を持ち越す。1試合で1未満しか動かないので、切り捨てると何も起きない。
    final whole = state.tacticCredit.truncate();
    if (whole == 0) return;
    state.tacticCredit -= whole;
    state.relations = state.relations.bump(manager: whole);
  }

  /// カードと出場停止。リーグ戦だけが累積の対象。
  ///
  /// 出場停止は「その試合に出られなかった」ことで1つ減る。試合を消化して
  /// いないのに減らすと、停止が空振りする。
  void _applyCards(CareerState state, MatchResult result) {
    if (result.international) return;
    if (result.appearance == Appearance.suspended) {
      state.suspension = max(0, state.suspension - 1);
      return;
    }
    if (result.sentOff) {
      state.suspension += Formulas.banForRedCard;
      // 退場のぶんの警告は累積に数えない（実際の運用と同じ）。
      _publish(state, [Newsroom.sentOff(state, result)]);
      return;
    }
    state.yellowCards += result.yellowCards;
    if (state.yellowCards >= Formulas.yellowCardsForBan) {
      state.yellowCards -= Formulas.yellowCardsForBan;
      state.suspension += Formulas.banForYellows;
    }
  }

  /// 育てる方向を切り替える。すでに入っていれば外す。
  ///
  /// 上限まで入っているときに新しく足そうとしても、何も起きない。
  /// 黙って古いものを落とすと、何が外れたのか分からない。
  Future<void> toggleFocus(Detail detail) async {
    final state = _state;
    if (state == null) return;
    final next = [...state.focus];
    if (next.remove(detail)) {
      state.focus = next;
    } else {
      if (next.length >= CareerState.maxFocus) return;
      state.focus = [...next, detail];
    }
    await _persist();
  }

  /// 自動で休養にするしきい値を決める。0 なら自動では休まない。
  Future<void> setAutoRestBelow(int condition) async {
    final state = _state;
    if (state == null) return;
    state.autoRestBelow = condition.clamp(0, 100);
    await _persist();
  }

  Future<void> setLifestyle(int level) async {
    final state = _state;
    if (state == null) return;
    state.finances = state.finances.withLifestyle(level);
    await _persist();
  }

  /// 引き継ぎコードを見せたことを記録する。
  ///
  /// 保存は端末の中にしか無いので、控えを取っていない年数が
  /// そのまま失う年数になる。
  Future<void> markBackedUp() async {
    final state = _state;
    if (state == null) return;
    state.backedUpYear = state.year;
    await _persist();
  }

  /// 引き継ぎコードを作る。キャリアが無ければ null。
  String? exportCode() {
    final state = _state;
    return state == null ? null : SaveRepository.encode(state);
  }

  /// 引き継ぎコードから復元する。読めなければ false を返し、今のキャリアは触らない。
  Future<bool> importCode(String code) async {
    final restored = SaveRepository.decode(code);
    if (restored == null) return false;
    _state = restored;
    _inProgress = null;
    pendingEvent = null;
    lastWeek = const WeekReport();
    await _persist();
    return true;
  }

  Future<void> deleteCareer() async {
    await _repository.clear();
    _state = null;
    _inProgress = null;
    notifyListeners();
  }

  /// 管理画面（開発用）から状態を書き換える。
  ///
  /// 口を1つに絞って、必ず「改変済み」の印を付ける。印が無いと、
  /// 引き継ぎコードで持ち出した壊れた記録が普通のキャリアに紛れる。
  Future<void> applyAdmin(void Function(CareerState state) change) async {
    final state = _state;
    if (state == null) return;
    change(state);
    state.tampered = true;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final state = _state;
    if (state != null) await _repository.save(state);
    notifyListeners();
  }
}
