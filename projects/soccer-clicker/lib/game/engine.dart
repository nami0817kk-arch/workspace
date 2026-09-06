/// ゲームの状態遷移。すべて純粋関数で、[GameState] を受けて新しい状態を返す。
///
/// 乱数は呼び出し側から渡す。こうしないと試合結果のテストが書けない。
library;

import 'dart:math';

import 'formulas.dart';
import 'models.dart';

/// 操作が通らなかった理由。UI はこれを見てボタンを無効化する。
enum RejectReason { notEnoughEp, noSuchPlayer, noPlayers }

class GameEngine {
  const GameEngine();

  /// 画面をタップしたとき。
  GameState tap(GameState state, {required int nowMs}) => state.copyWith(
        ep: state.ep + Formulas.epPerTap(state.trainingLevel),
        totalTaps: state.totalTaps + 1,
        updatedAtMs: nowMs,
      );

  /// 経過時間ぶんの放置収入を加える。
  ///
  /// アプリを閉じていた間の回収にも、起動中の毎秒更新にも同じ経路を使う。
  /// 上限 [Formulas.offlineCap] を超えた分は捨てる。
  /// 時刻が巻き戻っていた場合（端末の時計変更）は何も加算しない。
  GameState applyElapsed(GameState state, {required int nowMs}) {
    final elapsedMs = nowMs - state.updatedAtMs;
    if (elapsedMs <= 0) return state.copyWith(updatedAtMs: nowMs);

    final cappedMs = min(elapsedMs, Formulas.offlineCap.inMilliseconds);
    final gained = Formulas.epPerSecond(state.coachLevel) * cappedMs / 1000;
    return state.copyWith(ep: state.ep + gained, updatedAtMs: nowMs);
  }

  /// [applyElapsed] で入る EP を、加算せずに見積もる（復帰時の表示用）。
  double previewOfflineGain(GameState state, {required int nowMs}) {
    final elapsedMs = nowMs - state.updatedAtMs;
    if (elapsedMs <= 0) return 0;
    final cappedMs = min(elapsedMs, Formulas.offlineCap.inMilliseconds);
    return Formulas.epPerSecond(state.coachLevel) * cappedMs / 1000;
  }

  int upgradeCost(GameState state, UpgradeKind kind) => switch (kind) {
        UpgradeKind.training =>
          Formulas.upgradeCost(Formulas.trainingBaseCost, state.trainingLevel),
        UpgradeKind.coach =>
          Formulas.upgradeCost(Formulas.coachBaseCost, state.coachLevel),
      };

  bool canBuyUpgrade(GameState state, UpgradeKind kind) =>
      state.ep >= upgradeCost(state, kind);

  /// 強化を1段買う。EP が足りなければ [RejectReason.notEnoughEp]。
  (GameState, RejectReason?) buyUpgrade(GameState state, UpgradeKind kind) {
    final cost = upgradeCost(state, kind);
    if (state.ep < cost) return (state, RejectReason.notEnoughEp);

    final spent = state.ep - cost;
    return switch (kind) {
      UpgradeKind.training => (
          state.copyWith(ep: spent, trainingLevel: state.trainingLevel + 1),
          null
        ),
      UpgradeKind.coach => (
          state.copyWith(ep: spent, coachLevel: state.coachLevel + 1),
          null
        ),
    };
  }

  /// 選手を1レベル上げる。
  (GameState, RejectReason?) trainPlayer(GameState state, String playerId) {
    final index = state.players.indexWhere((p) => p.id == playerId);
    if (index < 0) return (state, RejectReason.noSuchPlayer);

    final player = state.players[index];
    final cost = Formulas.trainCost(player.level);
    if (state.ep < cost) return (state, RejectReason.notEnoughEp);

    final players = List<Player>.of(state.players);
    players[index] = player.copyWith(level: player.level + 1);
    return (state.copyWith(ep: state.ep - cost, players: players), null);
  }

  /// 新しい選手を獲得する。素質は乱数で決まる。
  (GameState, RejectReason?) scoutPlayer(GameState state, Random random) {
    final cost = Formulas.scoutCost(state.players.length);
    if (state.ep < cost) return (state, RejectReason.notEnoughEp);

    final player = generatePlayer(random, seedIndex: state.players.length);
    return (
      state.copyWith(
        ep: state.ep - cost,
        players: [...state.players, player],
      ),
      null
    );
  }

  /// 試合を1つ消化する。勝てば報酬、規定数勝てばランクアップ。
  (GameState, MatchResult?, RejectReason?) playMatch(
    GameState state,
    Random random,
  ) {
    if (state.players.isEmpty) return (state, null, RejectReason.noPlayers);

    final opponent = Formulas.opponentRating(state.clubRank);
    // 総合力差 10 でおよそ勝率 +25%。実力差があっても番狂わせは残す。
    final edge = (state.squadRating - opponent) * 0.025;
    final winChance = (0.5 + edge).clamp(0.05, 0.95);
    final won = random.nextDouble() < winChance;

    if (!won) {
      return (
        state.copyWith(losses: state.losses + 1),
        MatchResult(
          won: false,
          opponentRating: opponent,
          reward: 0,
          rankedUp: false,
        ),
        null
      );
    }

    final wins = state.wins + 1;
    final rankedUp = wins >= Formulas.winsForRankUp(state.clubRank);
    final reward = Formulas.matchReward(state.clubRank);

    return (
      state.copyWith(
        ep: state.ep + reward,
        wins: rankedUp ? 0 : wins,
        clubRank: rankedUp ? state.clubRank + 1 : state.clubRank,
      ),
      MatchResult(
        won: true,
        opponentRating: opponent,
        reward: reward,
        rankedUp: rankedUp,
      ),
      null
    );
  }

  /// 初期状態。選手1人から始める。
  static GameState newGame({required int nowMs, Random? random}) {
    final rng = random ?? Random();
    return GameState(
      ep: 0,
      totalTaps: 0,
      players: [generatePlayer(rng, seedIndex: 0)],
      trainingLevel: 0,
      coachLevel: 0,
      clubRank: 1,
      wins: 0,
      losses: 0,
      updatedAtMs: nowMs,
    );
  }

  static const List<String> _firstNames = [
    '拓海', '蓮', '陽翔', '悠真', '大和', '颯太', '湊', '樹', '奏太', '陸',
  ];
  static const List<String> _lastNames = [
    '佐藤', '鈴木', '高橋', '田中', '渡辺', '伊藤', '山本', '中村', '小林', '加藤',
  ];

  /// 選手を1人生成する。素質は 20〜59。
  static Player generatePlayer(Random random, {required int seedIndex}) {
    final name = '${_lastNames[random.nextInt(_lastNames.length)]} '
        '${_firstNames[random.nextInt(_firstNames.length)]}';
    return Player(
      id: 'p$seedIndex-${random.nextInt(1 << 32)}',
      name: name,
      position: Position.values[random.nextInt(Position.values.length)],
      baseRating: 20 + random.nextInt(40),
    );
  }
}
