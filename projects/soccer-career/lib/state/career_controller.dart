import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/save_repository.dart';
import '../game/career_engine.dart';
import '../game/formulas.dart';
import '../game/match_engine.dart';
import '../game/life_events.dart';
import '../game/national.dart';
import '../game/person.dart';
import '../models/agent.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/competition.dart';
import '../models/development.dart';
import '../models/entourage.dart';
import '../models/injury.dart';
import '../models/life.dart';
import '../models/life_event.dart';
import '../models/personality.dart';
import '../models/physique.dart';
import '../models/player.dart';
import '../models/season.dart';
import '../game/world.dart';
import '../models/support.dart';
import '../models/training.dart';

/// 試合を終えた1週間で起きたこと。画面で一度見せる。
class WeekReport {
  const WeekReport({
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

  /// 練習で伸びた詳細能力。
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

  /// 試合を1つ終えるごとの、心と身体の積み上げ。
  ///
  /// 出れば気持ちが上がり、外れれば沈む。疲れは戻らずに溜まっていく。
  /// 好不調の波はここで出入りする。
  void _updateMood(CareerState state, MatchResult result) {
    final played = result.appearance == Appearance.start ||
        result.appearance == Appearance.sub;

    var morale = state.morale.bump(switch (result.appearance) {
      Appearance.start => 1,
      Appearance.sub => 1,
      Appearance.benched => -3,
      Appearance.injured => -4,
    });
    if (played && result.won) morale = morale.bump(1);
    if (played && (result.rating ?? 6) >= 7.5) morale = morale.bump(2);
    state.morale = morale;

    state.fatigue = state.fatigue.add(switch (result.appearance) {
      Appearance.start => 3,
      Appearance.sub => 2,
      Appearance.benched || Appearance.injured => 0,
    });

    // 波。続いていれば1試合ぶん進め、切れていれば直近の出来から引き直す。
    state.form = state.form.tick();
    if (!state.form.isActive) {
      state.form = Momentum.roll(
        _random,
        recent: [
          for (final r in state.leagueResults)
            if (r.rating != null) r.rating!,
        ],
      );
    }

    // ピッチの外の出来事。試合と試合の間に起きる。
    if (pendingEvent == null && _life.fires()) {
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
        ),
        seen: state.seenEvents.toSet(),
      );
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
    state.player = state.player.copyWith(
      personality: personality,
      condition: state.player.condition + e.condition,
    );

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

  /// 出場機会の下駄。監督の信頼・戦術との相性・方針・序列を足し合わせる。
  ///
  /// 評価点だけで決めると、監督も方針も競争相手も飾りになる。
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
  }) async {
    _state = _career.startCareer(
      name: name,
      position: position,
      age: age,
      agent: agent,
    );
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
  void startNextMatch() {
    final state = _state;
    if (state == null || state.retired) return;
    if (state.pendingInternational) return startInternational();
    if (state.seasonFinished) return;

    final matchday = state.matchday;
    _inProgress = _match.start(
      matchday: matchday,
      player: state.player,
      club: state.club,
      opponent: state.opponentFor(matchday),
      home: state.isHome(matchday),
      development: state.development,
      allyBonus: state.partner?.synergyBonus ?? 0,
      moodBonus: state.morale.chanceModifier + state.form.chanceModifier,
      extraRating: state.captain ? Formulas.captainRatingBonus : 0,
      appearance: state.injured
          ? Appearance.injured
          // 登録メンバーから外れていると、そもそもベンチにも入れない。
          : !state.squadStatus.canPlay
              ? Appearance.benched
              : MatchEngine.decideAppearance(
                  state.leagueResults,
                  bonus: _appearanceBonus(state),
                ),
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
    _updateMood(state, result);

    // 出たポジションの適性と、相方との呼吸が伸びる。
    if (result.appearance == Appearance.start ||
        result.appearance == Appearance.sub) {
      state.player = state.player.copyWith(
        aptitude: state.player.aptitude.playedAt(state.player.position),
      );
      final partner = state.partner;
      if (partner != null) {
        state.partner = partner.withSynergy(partner.synergy + 2);
      }
    }

    // 経験・選択の癖・相手への慣れは、出た試合ぶんだけ積み上がる。
    state.development = state.development.afterMatch(
      appearance: result.appearance,
      international: result.international,
      style: ClubStyle.of(match.opponent),
      used: match.resolutions.map((r) => r.key),
    );

    if (result.international) {
      state.pendingInternational = false;
      _inProgress = null;
      lastWeek = const WeekReport();
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
      lastWeek = WeekReport(recovered: recovered);
    } else {
      final before = _sumOf(player.attributes);
      player = player.copyWith(
        attributes: _match.grow(
          player,
          result.rating,
          used: match.successes,
          declineOffset: state.staff.declineAgeOffset,
          plateau: state.development.inPlateau,
          environment: _environmentFactor(state),
        ),
      );
      final week = _match.applyWeek(
        player,
        menu: state.menu,
        drill: state.drill,
        staff: state.staff,
        habits: state.habits,
        development: state.development,
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
      // 伸びが続けば、どこかで足踏みが来る。
      state.development = state.development.afterGrowth(
        grew: _sumOf(week.attributes) > before,
        random: _random,
      );
      if (week.learned != null) {
        state.development = state.development.learn(week.learned!);
      }
      newInjury = week.injury ??
          _match.rollInjury(
            player,
            baseChance: Formulas.injuryBaseChance *
                state.staff.injuryFactor *
                state.habits.injuryFactor *
                state.fatigue.injuryFactor *
                // 復帰直後は無理が効かない。強行すればここで返ってくる。
                (state.rehabWatch > 0 ? state.rehab.relapseFactor : 1.0),
          );
      if (newInjury != null) {
        // 復帰の進め方で離脱の長さが変わる。
        newInjury = Injury(
          name: newInjury.name,
          severity: newInjury.severity,
          matchesOut: state.rehab.lengthFor(newInjury),
        );
        final (attributes, potential) =
            _match.applySevereInjury(player, newInjury);
        player = Player.rebuild(player, attributes: attributes, potential: potential);
        state.injury = newInjury;
      }
      lastWeek = WeekReport(
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
    await _persist();
  }

  /// 今の移籍市場の状態。
  TransferWindow get transferWindow =>
      _state == null ? TransferWindow.closed : _career.competitions.windowAt(_state!);

  Future<void> advanceSeason({
    required TransferOffer accepted,
    BodyPlan bodyPlan = BodyPlan.maintain,
  }) async {
    final state = _state;
    if (state == null) return;
    _state =
        _career.advanceSeason(state, accepted: accepted, bodyPlan: bodyPlan);
    // 新しいクラブで登録メンバーに入れるかを決める。
    _state!.squadStatus = _career.competitions.registrationFor(_state!);
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

  Future<void> _persist() async {
    final state = _state;
    if (state != null) await _repository.save(state);
    notifyListeners();
  }
}
