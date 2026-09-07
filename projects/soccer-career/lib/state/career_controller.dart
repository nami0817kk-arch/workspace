import 'package:flutter/foundation.dart';

import '../data/save_repository.dart';
import '../game/career_engine.dart';
import '../game/formulas.dart';
import '../game/match_engine.dart';
import '../game/national.dart';
import '../models/agent.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/injury.dart';
import '../models/player.dart';
import '../models/season.dart';

/// 試合を終えた1週間で起きたこと。画面で一度見せる。
class WeekReport {
  const WeekReport({this.trained, this.newInjury, this.recovered = false});

  /// 練習で伸びた詳細能力。
  final Detail? trained;

  /// 新たに負傷したらその内容。
  final Injury? newInjury;

  /// 離脱から復帰したか。
  final bool recovered;

  bool get isEmpty => trained == null && newInjury == null && !recovered;
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
  })  : _repository = repository ?? SaveRepository(),
        _career = careerEngine ?? CareerEngine(),
        _match = matchEngine ?? MatchEngine();

  final SaveRepository _repository;
  final CareerEngine _career;
  final MatchEngine _match;

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

  /// 今週の練習を決める。null は休養。
  Future<void> setTraining(AttributeKey? focus) async {
    final state = _state;
    if (state == null) return;
    state.training = focus;
    await _persist();
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
      appearance: state.injured
          ? Appearance.injured
          : MatchEngine.decideAppearance(state.leagueResults),
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
        player = player.copyWith(condition: Formulas.conditionAfterInjury);
      } else {
        state.injury = next;
      }
      lastWeek = WeekReport(recovered: recovered);
    } else {
      player = player.copyWith(
        attributes: _match.grow(
          player,
          result.rating,
          used: match.successes,
        ),
      );
      final week = _match.applyWeek(
        player,
        training: state.training,
        played: result.appearance != Appearance.benched,
      );
      player = player.copyWith(
        attributes: week.attributes,
        condition: week.condition,
      );
      newInjury = week.injury ??
          _match.rollInjury(player, baseChance: Formulas.injuryBaseChance);
      if (newInjury != null) {
        final (attributes, potential) =
            _match.applySevereInjury(player, newInjury);
        player = Player.rebuild(player, attributes: attributes, potential: potential);
        state.injury = newInjury;
      }
      lastWeek = WeekReport(trained: week.trained, newInjury: newInjury);
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

  int takeHome(int salary) =>
      _state == null ? salary : _career.takeHome(_state!, salary);

  Future<void> advanceSeason({required TransferOffer accepted}) async {
    final state = _state;
    if (state == null) return;
    _state = _career.advanceSeason(state, accepted: accepted);
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
