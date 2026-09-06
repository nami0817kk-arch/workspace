import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_clicker/game/engine.dart';
import 'package:soccer_clicker/game/formulas.dart';
import 'package:soccer_clicker/game/models.dart';

const engine = GameEngine();

GameState stateWith({
  double ep = 0,
  int trainingLevel = 0,
  int coachLevel = 0,
  int clubRank = 1,
  int wins = 0,
  List<Player>? players,
  int updatedAtMs = 0,
}) =>
    GameState(
      ep: ep,
      totalTaps: 0,
      players: players ?? const [],
      trainingLevel: trainingLevel,
      coachLevel: coachLevel,
      clubRank: clubRank,
      wins: wins,
      losses: 0,
      updatedAtMs: updatedAtMs,
    );

Player player({String id = 'p1', int baseRating = 40, int level = 1}) => Player(
      id: id,
      name: 'テスト 選手',
      position: Position.mid,
      baseRating: baseRating,
      level: level,
    );

void main() {
  group('タップ', () {
    test('未強化でも 1 EP 入る', () {
      final next = engine.tap(stateWith(), nowMs: 1000);
      expect(next.ep, 1);
      expect(next.totalTaps, 1);
      expect(next.updatedAtMs, 1000);
    });

    test('トレーニング強化で 1 回の獲得量が増える', () {
      final next = engine.tap(stateWith(trainingLevel: 2), nowMs: 0);
      expect(next.ep, Formulas.epPerTap(2));
      expect(next.ep, greaterThan(1));
    });
  });

  group('放置収入', () {
    test('コーチが居なければ増えない', () {
      final next = engine.applyElapsed(stateWith(), nowMs: 60000);
      expect(next.ep, 0);
      expect(next.updatedAtMs, 60000);
    });

    test('経過秒 × レートで入る', () {
      final next = engine.applyElapsed(stateWith(coachLevel: 4), nowMs: 10000);
      expect(next.ep, closeTo(Formulas.epPerSecond(4) * 10, 1e-9));
    });

    test('上限を超えた分は捨てる', () {
      final beyond = Formulas.offlineCap.inMilliseconds * 3;
      final next = engine.applyElapsed(stateWith(coachLevel: 1), nowMs: beyond);
      final capped = Formulas.epPerSecond(1) * Formulas.offlineCap.inSeconds;
      expect(next.ep, closeTo(capped, 1e-9));
    });

    test('時計が巻き戻っても EP は増えない', () {
      final state = stateWith(coachLevel: 10, ep: 5, updatedAtMs: 90000);
      final next = engine.applyElapsed(state, nowMs: 1000);
      expect(next.ep, 5);
      expect(next.updatedAtMs, 1000);
    });

    test('preview は加算せずに同じ額を返す', () {
      final state = stateWith(coachLevel: 4);
      final preview = engine.previewOfflineGain(state, nowMs: 10000);
      final applied = engine.applyElapsed(state, nowMs: 10000);
      expect(preview, closeTo(applied.ep, 1e-9));
      expect(state.ep, 0);
    });
  });

  group('強化の購入', () {
    test('EP が足りなければ拒否され、状態は変わらない', () {
      final state = stateWith(ep: 0);
      final (next, reason) = engine.buyUpgrade(state, UpgradeKind.training);
      expect(reason, RejectReason.notEnoughEp);
      expect(next.trainingLevel, 0);
      expect(next.ep, 0);
    });

    test('買うと EP が引かれ段階が上がる', () {
      final cost = engine.upgradeCost(stateWith(), UpgradeKind.training);
      final (next, reason) = engine.buyUpgrade(
        stateWith(ep: cost.toDouble()),
        UpgradeKind.training,
      );
      expect(reason, isNull);
      expect(next.trainingLevel, 1);
      expect(next.ep, 0);
    });

    test('買うほど次が高くなる', () {
      final first = engine.upgradeCost(stateWith(), UpgradeKind.coach);
      final second =
          engine.upgradeCost(stateWith(coachLevel: 1), UpgradeKind.coach);
      expect(second, greaterThan(first));
    });
  });

  group('選手の育成', () {
    test('レベルが上がり総合力が伸びる', () {
      final state = stateWith(ep: 10000, players: [player()]);
      final (next, reason) = engine.trainPlayer(state, 'p1');
      expect(reason, isNull);
      expect(next.players.single.level, 2);
      expect(
        next.players.single.rating,
        greaterThan(state.players.single.rating),
      );
    });

    test('居ない選手を指定すると拒否される', () {
      final state = stateWith(ep: 10000, players: [player()]);
      final (next, reason) = engine.trainPlayer(state, 'nope');
      expect(reason, RejectReason.noSuchPlayer);
      expect(next.players.single.level, 1);
    });

    test('総合力は 99 を超えない', () {
      final maxed = player(baseRating: 60, level: 40);
      expect(maxed.rating, 99);
    });
  });

  group('スカウト', () {
    test('EP を払って人数が増える', () {
      final cost = Formulas.scoutCost(1);
      final state = stateWith(ep: cost.toDouble(), players: [player()]);
      final (next, reason) = engine.scoutPlayer(state, Random(1));
      expect(reason, isNull);
      expect(next.players.length, 2);
      expect(next.ep, 0);
    });

    test('人数が増えるほど高い', () {
      expect(Formulas.scoutCost(5), greaterThan(Formulas.scoutCost(1)));
    });
  });

  group('試合', () {
    test('選手が居なければ試合できない', () {
      final (_, result, reason) = engine.playMatch(stateWith(), Random(1));
      expect(reason, RejectReason.noPlayers);
      expect(result, isNull);
    });

    test('必ず勝つ乱数なら報酬が入る', () {
      final state = stateWith(players: [player(baseRating: 99)]);
      final (next, result, _) = engine.playMatch(state, _FixedRandom(0.0));
      expect(result!.won, isTrue);
      expect(next.ep, result.reward);
      expect(result.reward, greaterThan(0));
    });

    test('必ず負ける乱数なら報酬は入らない', () {
      final state = stateWith(players: [player(baseRating: 1)]);
      final (next, result, _) = engine.playMatch(state, _FixedRandom(0.999));
      expect(result!.won, isFalse);
      expect(next.ep, 0);
      expect(next.losses, 1);
    });

    test('規定数勝つとランクが上がり勝ち数がリセットされる', () {
      final needed = Formulas.winsForRankUp(1);
      final state = stateWith(
        players: [player(baseRating: 99)],
        wins: needed - 1,
      );
      final (next, result, _) = engine.playMatch(state, _FixedRandom(0.0));
      expect(result!.rankedUp, isTrue);
      expect(next.clubRank, 2);
      expect(next.wins, 0);
    });

    test('ランクが上がると相手も強くなる', () {
      expect(
        Formulas.opponentRating(5),
        greaterThan(Formulas.opponentRating(1)),
      );
    });

    test('一方的でも番狂わせの目が残る', () {
      final strong = stateWith(players: [player(baseRating: 99)]);
      final (_, lost, _) = engine.playMatch(strong, _FixedRandom(0.96));
      expect(lost!.won, isFalse);

      final weak = stateWith(players: [player(baseRating: 1)], clubRank: 9);
      final (_, upset, _) = engine.playMatch(weak, _FixedRandom(0.04));
      expect(upset!.won, isTrue);
    });
  });

  group('スカッド総合力', () {
    test('選手が居なければ 0', () {
      expect(stateWith().squadRating, 0);
    });

    test('平均で出す', () {
      final state = stateWith(players: [
        player(id: 'a', baseRating: 40),
        player(id: 'b', baseRating: 60),
      ]);
      expect(state.squadRating, 50);
    });
  });

  group('セーブの往復', () {
    test('JSON にして戻しても内容が保たれる', () {
      final state = stateWith(
        ep: 1234.5,
        trainingLevel: 3,
        coachLevel: 2,
        clubRank: 4,
        wins: 1,
        players: [player(id: 'a', level: 7), player(id: 'b')],
        updatedAtMs: 999,
      );
      final restored = GameState.fromJson(state.toJson());
      expect(restored.ep, state.ep);
      expect(restored.trainingLevel, 3);
      expect(restored.clubRank, 4);
      expect(restored.players.length, 2);
      expect(restored.players.first.level, 7);
      expect(restored.updatedAtMs, 999);
      expect(restored.squadRating, state.squadRating);
    });
  });

  group('初期状態', () {
    test('選手1人・EP0 から始まる', () {
      final state = GameEngine.newGame(nowMs: 42, random: Random(1));
      expect(state.players.length, 1);
      expect(state.ep, 0);
      expect(state.clubRank, 1);
      expect(state.updatedAtMs, 42);
    });
  });
}

/// 常に同じ値を返す乱数。試合結果を固定するために使う。
class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
