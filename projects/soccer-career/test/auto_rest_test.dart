/// 疲れているときに自動で休むしくみ。
///
/// 毎週の操作を忘れても、そこだけは踏み外さないようにするためのもの。
/// 黙って差し替えると「練習したのに伸びない」と見えるので、
/// 効いたことが必ず分かるところまでを縛る。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/training.dart';
import 'package:soccer_career/state/career_controller.dart';

class _MemoryRepository implements SaveRepository {
  CareerState? _saved;

  @override
  Future<CareerState?> load() async => _saved;

  @override
  Future<void> save(CareerState state) async => _saved = state;

  @override
  Future<void> clear() async => _saved = null;
}

Future<CareerController> started(
    {int seed = 3, Position position = Position.st}) async {
  final c = CareerController(
    repository: _MemoryRepository(),
    careerEngine: CareerEngine(random: Random(seed)),
    matchEngine: MatchEngine(random: Random(seed)),
    random: Random(seed),
  );
  await c.startCareer(
      name: '検証', position: position, age: 24, agent: Agent.pool.first);
  return c;
}

void main() {
  group('元気なのに休んでいる', () {
    test('コンディションが高いまま休養だと、伸びないと分かる', () async {
      final c = await started();
      final state = c.state!;
      state.autoRestBelow = 0;

      await c.setMenu(TrainingMenu.rest);
      state.player = state.player.copyWith(condition: 100);
      expect(state.restingWhileFresh, isTrue);

      // 疲れているときの休養は、休養として正しいので出さない。
      state.player = state.player.copyWith(condition: 40);
      expect(state.restingWhileFresh, isFalse);

      // 練習しているなら出さない。
      state.player = state.player.copyWith(condition: 100);
      await c.setMenu(TrainingMenu.defaultFor(state.player.position));
      expect(state.restingWhileFresh, isFalse);
    });

    test('自動休養が効いている週とは、区別が付く', () async {
      final c = await started();
      final state = c.state!;
      state.autoRestBelow = 40;
      await c.setMenu(TrainingMenu.rest);
      state.player = state.player.copyWith(condition: 20);
      // 自動休養のほうが先。両方が同時に出ることはない。
      expect(state.shouldAutoRest(state.player.condition), isTrue);
      expect(state.restingWhileFresh, isFalse);
    });
  });

  test('新しいキャリアは、そのポジションの練習をした状態で始まる', () async {
    // 既定が休養だと、育成タブを開かない人は1年間なにも伸びない。
    for (final position in Position.values) {
      final c = await started(position: position);
      final menu = c.state!.menu;
      expect(menu.isRest, isFalse, reason: position.label);
      expect(menu, TrainingMenu.defaultFor(position));
      if (position == Position.gk) {
        expect(menu.keys, contains(AttributeKey.goalkeeping));
      } else {
        expect(menu.keys, isNot(contains(AttributeKey.goalkeeping)));
      }
    }
  });

  group('しきい値', () {
    test('既定では効いている', () async {
      final c = await started();
      expect(c.state!.autoRestBelow, CareerState.defaultAutoRestBelow);
      expect(c.state!.shouldAutoRest(CareerState.defaultAutoRestBelow - 1),
          isTrue);
      expect(
          c.state!.shouldAutoRest(CareerState.defaultAutoRestBelow), isFalse);
    });

    test('0 にすると、どれだけ疲れていても自動では休まない', () async {
      final c = await started();
      await c.setAutoRestBelow(0);
      expect(c.state!.shouldAutoRest(1), isFalse);
    });

    test('保存を往復しても残り、古い保存データには既定が入る', () async {
      final c = await started();
      await c.setAutoRestBelow(60);
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).autoRestBelow, 60);
      expect(
        CareerState.fromJson(json..remove('autoRestBelow')).autoRestBelow,
        CareerState.defaultAutoRestBelow,
      );
    });

    test('シーズンを跨いでも消えない', () async {
      final c = await started(seed: 41);
      await c.setAutoRestBelow(50);
      while (!c.state!.seasonFinished) {
        await c.simulateMatch();
      }
      await c.finishSeason();
      await c.advanceSeason(accepted: c.renewalOffer!);
      expect(c.state!.autoRestBelow, 50);
    });
  });

  group('効いたとき', () {
    test('疲れていたら練習も居残りも止めて、その旨を残す', () async {
      final c = await started(seed: 42);
      final state = c.state!;
      await c.setAutoRestBelow(60);
      await c.setMenu(TrainingMenu.athletic);
      await c.setDrill(SetPiece.freeKick);
      // 試合ぶんの消耗を引くと、しきい値を割る値にしておく。
      state.player = state.player.copyWith(condition: 55);

      final before = state.player.setPieces[SetPiece.freeKick];
      await c.simulateMatch();

      expect(c.lastWeek.autoRested, isTrue, reason: '自動で休んでいない');
      // 休養なので消耗せず、戻っている。
      expect(c.state!.player.condition, greaterThan(55 - Formulas.matchConditionCost));
      // 居残りも止まっているので、セットプレーは伸びない。
      expect(c.state!.player.setPieces[SetPiece.freeKick], before);
      // 選んだメニューそのものは変えない（来週また使う）。
      expect(c.state!.menu, TrainingMenu.athletic);
      expect(c.state!.drill, SetPiece.freeKick);
    });

    test('元気なときは、選んだ練習がそのまま行われる', () async {
      final c = await started(seed: 43);
      await c.setAutoRestBelow(30);
      await c.setMenu(TrainingMenu.sprint);
      await c.simulateMatch();
      expect(c.lastWeek.autoRested, isFalse);
    });

    test('試合ぶんの消耗を引いたあとの値で決める', () {
      // 試合前は足りていても、出れば割ることがある。そこを見ないと
      // 疲れ切った状態で練習させてしまう。
      final player = CareerEngine(random: Random(1))
          .startCareer(
              name: 'P',
              position: Position.st,
              age: 24,
              agent: Agent.pool.first)
          .player
          .copyWith(condition: 50);
      final played = MatchEngine.conditionAfterMatch(player, played: true);
      final benched = MatchEngine.conditionAfterMatch(player, played: false);
      expect(played, lessThan(50));
      expect(benched, 50);
    });
  });
}
