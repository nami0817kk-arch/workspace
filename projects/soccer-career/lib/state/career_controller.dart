import 'package:flutter/foundation.dart';

import '../data/save_repository.dart';
import '../game/career_engine.dart';
import '../game/match_engine.dart';
import '../models/agent.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/season.dart';

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

  /// 直近の1週間で練習により伸びた能力。画面で一度見せたら消す。
  AttributeKey? lastTrained;

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
    await _persist();
  }

  /// 今週の練習を決める。null は休養。
  Future<void> setTraining(AttributeKey? focus) async {
    final state = _state;
    if (state == null) return;
    state.training = focus;
    await _persist();
  }

  /// 次の試合を始める。出場の仕方は直近の評価点で決まる。
  void startNextMatch() {
    final state = _state;
    if (state == null || state.seasonFinished || state.retired) return;

    final matchday = state.matchday;
    _inProgress = _match.start(
      matchday: matchday,
      player: state.player,
      club: state.club,
      opponent: state.opponentFor(matchday),
      home: state.isHome(matchday),
      appearance: MatchEngine.decideAppearance(state.results),
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

  /// 試合を終えて結果を反映する。成長判定と1週間の練習・消耗もここで行う。
  Future<MatchResult?> finishMatch() async {
    final state = _state;
    final match = _inProgress;
    if (state == null || match == null) return null;

    final result = match.finish();
    _career.applyResult(state, result);

    var player = state.player.copyWith(
      attributes: _match.grow(
        state.player,
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
    lastTrained = week.trained;
    state.player = player;

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
