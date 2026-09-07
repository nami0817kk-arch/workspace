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

  /// 練習で伸びた能力。
  final AttributeKey? trained;

  /// 新たに負傷したらその内容。
  final Injury? newInjury;

  /// 離脱から復帰したか。
  final bool recovered;

  bool get isEmpty => trained == null && newInjury == null && !recovered;
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
    } else {
      player = player.copyWith(
        attributes: _match.grow(
          player,
          result.rating,
          used: match.successfulKeys,
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

    if (recovered) lastWeek = const WeekReport(recovered: true);
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
