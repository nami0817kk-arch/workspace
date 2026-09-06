/// エンジンと保存と時計をつなぐ層。UI はここだけを見る。
///
/// 時刻と乱数を外から差せるようにしてあるのは、放置収入と試合結果を
/// テストで固定するため。
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/save_store.dart';
import 'engine.dart';
import 'formulas.dart';
import 'models.dart';

typedef Clock = int Function();

class GameController extends ChangeNotifier {
  GameController({
    required this.store,
    Clock? clock,
    Random? random,
  })  : _clock = clock ?? _systemClock,
        _random = random ?? Random();

  static int _systemClock() => DateTime.now().millisecondsSinceEpoch;

  final SaveStore store;
  final Clock _clock;
  final Random _random;
  static const _engine = GameEngine();

  GameState? _state;
  Timer? _ticker;

  /// 復帰時に「留守中にこれだけ入った」と見せるための額。
  /// 一度表示したら [dismissOfflineGain] で消す。
  double offlineGain = 0;

  GameState get state => _state!;
  bool get isReady => _state != null;
  double get epPerTap => Formulas.epPerTap(state.trainingLevel);
  double get epPerSecond => Formulas.epPerSecond(state.coachLevel);

  /// セーブを読み、留守中の分を精算して開始する。
  Future<void> start() async {
    final loaded = await store.load();
    final now = _clock();

    if (loaded == null) {
      _state = GameEngine.newGame(nowMs: now, random: _random);
    } else {
      offlineGain = _engine.previewOfflineGain(loaded, nowMs: now);
      _state = _engine.applyElapsed(loaded, nowMs: now);
    }

    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
    await _persist();
  }

  void dismissOfflineGain() {
    offlineGain = 0;
    notifyListeners();
  }

  void _tick() {
    if (_state == null) return;
    // 起動中の毎秒加算も、放置と同じ経路を通す（二重加算を避けるため）。
    _state = _engine.applyElapsed(state, nowMs: _clock());
    notifyListeners();
    unawaited(_persist());
  }

  void tap() {
    _state = _engine.tap(state, nowMs: _clock());
    notifyListeners();
    unawaited(_persist());
  }

  int upgradeCost(UpgradeKind kind) => _engine.upgradeCost(state, kind);
  bool canBuy(UpgradeKind kind) => _engine.canBuyUpgrade(state, kind);

  int trainCost(Player player) => Formulas.trainCost(player.level);
  bool canTrain(Player player) => state.ep >= trainCost(player);

  int get scoutCost => Formulas.scoutCost(state.players.length);
  bool get canScout => state.ep >= scoutCost;

  bool get canPlayMatch => state.players.isNotEmpty;
  int get opponentRating => Formulas.opponentRating(state.clubRank);
  int get winsForRankUp => Formulas.winsForRankUp(state.clubRank);

  RejectReason? buyUpgrade(UpgradeKind kind) {
    final (next, reason) = _engine.buyUpgrade(state, kind);
    return _commit(next, reason);
  }

  RejectReason? trainPlayer(String playerId) {
    final (next, reason) = _engine.trainPlayer(state, playerId);
    return _commit(next, reason);
  }

  RejectReason? scout() {
    final (next, reason) = _engine.scoutPlayer(state, _random);
    return _commit(next, reason);
  }

  /// 試合を1つ消化する。拒否されたときは結果が null。
  (MatchResult?, RejectReason?) playMatch() {
    final (next, result, reason) = _engine.playMatch(state, _random);
    _commit(next, reason);
    return (result, reason);
  }

  RejectReason? _commit(GameState next, RejectReason? reason) {
    if (reason != null) return reason;
    _state = next;
    notifyListeners();
    unawaited(_persist());
    return null;
  }

  Future<void> _persist() => store.save(state);

  /// 最初からやり直す。
  Future<void> reset() async {
    await store.clear();
    _state = GameEngine.newGame(nowMs: _clock(), random: _random);
    offlineGain = 0;
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
