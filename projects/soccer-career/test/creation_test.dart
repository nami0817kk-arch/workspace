/// 最初の選手を自分で決めるところと、立つ側（左右）。
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
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/season.dart';
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

CareerController controller({int seed = 3}) => CareerController(
      repository: _MemoryRepository(),
      careerEngine: CareerEngine(random: Random(seed)),
      matchEngine: MatchEngine(random: Random(seed)),
      random: Random(seed),
    );

void main() {
  group('立つ側', () {
    test('利き足と合うかどうかが決まる', () {
      expect(Side.left.matches(Foot.left), isTrue);
      expect(Side.left.matches(Foot.right), isFalse);
      expect(Side.left.inverted(Foot.right), isTrue);
      // 両利きはどちらでも合う。中央はそもそも関係ない。
      expect(Side.right.matches(Foot.both), isTrue);
      expect(Side.center.matches(Foot.left), isTrue);
      expect(Side.center.inverted(Foot.left), isFalse);
    });

    test('左右を持つのはサイドバックとウイングだけ', () {
      expect(Position.sb.hasSide, isTrue);
      expect(Position.wg.hasSide, isTrue);
      for (final position in Position.values) {
        if (position == Position.sb || position == Position.wg) continue;
        expect(position.hasSide, isFalse, reason: position.name);
      }
    });

    test('中央の役割に側を指定しても、中央のまま', () async {
      final c = controller(seed: 51);
      await c.startCareer(
        name: '中央',
        position: Position.cm,
        age: 20,
        agent: Agent.pool.first,
        side: Side.left,
      );
      expect(c.state!.player.side, Side.center);
      expect(c.state!.player.positionLabel, Position.cm.label);
    });

    test('表示に左右が付く', () async {
      final c = controller(seed: 52);
      await c.startCareer(
        name: '左サイド',
        position: Position.sb,
        age: 20,
        agent: Agent.pool.first,
        side: Side.left,
        physique: const Physique(heightCm: 176, weightKg: 68, foot: Foot.left),
      );
      final player = c.state!.player;
      expect(player.positionLabel, 'LSB');
      expect(player.positionName, '左サイドバック');
      expect(player.isInverted, isFalse);
    });

    test('保存を往復しても残り、古い保存データは利き足に合う側になる', () async {
      final c = controller(seed: 53);
      await c.startCareer(
        name: '右ウイング',
        position: Position.wg,
        age: 20,
        agent: Agent.pool.first,
        side: Side.right,
        physique: const Physique(heightCm: 173, weightKg: 66, foot: Foot.left),
      );
      final json = c.state!.toJson();
      expect(CareerState.fromJson(json).player.side, Side.right);

      // 左右を持たせる前の保存データ。既定で右に寄せると、
      // 左利きのサイドの選手が急に不利になる。
      final playerJson = json['player'] as Map<String, dynamic>;
      playerJson.remove('side');
      expect(CareerState.fromJson(json).player.side, Side.left);
    });
  });

  group('逆足との噛み合わせ', () {
    test('合う側は逆足の局面が減り、逆サイドは増える', () {
      expect(Formulas.weakFootMomentOnSide,
          lessThan(Formulas.weakFootMomentChance));
      expect(Formulas.weakFootMomentInverted,
          greaterThan(Formulas.weakFootMomentChance));
    });

    test('実際に、逆サイドのほうが逆足の局面が多い', () async {
      int countFor(Side side) {
        final engine = MatchEngine(random: Random(9));
        final career = CareerEngine(random: Random(9)).startCareer(
          name: 'P',
          position: Position.wg,
          age: 24,
          agent: Agent.pool.first,
          side: side,
          physique:
              const Physique(heightCm: 175, weightKg: 70, foot: Foot.right),
        );
        var moments = 0;
        for (var i = 0; i < 200; i++) {
          final match = engine.start(
            matchday: 1,
            player: career.player,
            club: career.club,
            opponent: career.league.first,
            home: true,
            appearance: Appearance.start,
          );
          moments += match.weakFootMoments.where((m) => m).length;
        }
        return moments;
      }

      final onSide = countFor(Side.right);
      final inverted = countFor(Side.left);
      expect(inverted, greaterThan(onSide),
          reason: '逆サイドなのに逆足の局面が増えていない');
    });

    test('逆サイドは、シュートの手に内へ切り込むぶんが乗る', () async {
      final c = controller(seed: 55);
      await c.startCareer(
        name: '逆足ウイング',
        position: Position.wg,
        age: 24,
        agent: Agent.pool.first,
        side: Side.left,
        physique: const Physique(heightCm: 175, weightKg: 70, foot: Foot.right),
      );
      expect(c.state!.player.isInverted, isTrue);

      var seen = false;
      for (var i = 0; i < 10 && !seen; i++) {
        c.startNextMatch();
        final match = c.currentMatch;
        if (match == null) break;
        while (!match.isFinished) {
          for (final option in match.current.options) {
            if (match
                .factorsFor(option)
                .any((f) => f.label == '内へ切り込む')) {
              seen = true;
            }
          }
          match.choose(match.current.options.first);
        }
        await c.finishMatch();
      }
      expect(seen, isTrue, reason: 'シュートの手に何も乗っていない');
    });
  });

  group('能力の割り振り', () {
    test('基準値は1か所から出ている', () {
      for (final position in Position.values) {
        final base = CareerEngine.startingBaseFor(position);
        expect(base[AttributeKey.pace], isNotNull, reason: position.name);
        // GK 能力を持つのは GK だけ。
        expect(base.containsKey(AttributeKey.goalkeeping),
            position == Position.gk,
            reason: position.name);
      }
    });

    test('振ったぶんだけ、その能力が動く', () {
      CareerState build(Map<AttributeKey, int> tweaks) =>
          CareerEngine(random: Random(4)).startCareer(
            name: 'P',
            position: Position.st,
            age: 20,
            agent: Agent.pool.first,
            tweaks: tweaks,
          );

      final plain = build(const {});
      final tuned = build(const {
        AttributeKey.shooting: 6,
        AttributeKey.defending: -6,
      });
      expect(tuned.player.attributes[AttributeKey.shooting],
          plain.player.attributes[AttributeKey.shooting] + 6);
      expect(tuned.player.attributes[AttributeKey.defending],
          plain.player.attributes[AttributeKey.defending] - 6);
    });

    test('合計0なら、総合力はほとんど変わらない', () {
      // 振り分けで総合力を稼げてしまうと、割り振りが「正解探し」になる。
      var plainTotal = 0;
      var tunedTotal = 0;
      for (var seed = 0; seed < 40; seed++) {
        CareerState build(Map<AttributeKey, int> tweaks) =>
            CareerEngine(random: Random(seed)).startCareer(
              name: 'P',
              position: Position.st,
              age: 20,
              agent: Agent.pool.first,
              tweaks: tweaks,
            );
        plainTotal += build(const {}).player.overall;
        tunedTotal += build(const {
          AttributeKey.shooting: 6,
          AttributeKey.pace: 6,
          AttributeKey.defending: -6,
          AttributeKey.passing: -6,
        }).player.overall;
      }
      // ST はシュートとスピードの重みが高いので多少は上がるが、
      // 別人になるほどではない。
      expect((tunedTotal - plainTotal) / 40, lessThan(3.0));
    });

    test('身体を指定できる', () async {
      final c = controller(seed: 56);
      await c.startCareer(
        name: '大型',
        position: Position.st,
        age: 20,
        agent: Agent.pool.first,
        physique: const Physique(heightCm: 195, weightKg: 90, foot: Foot.left),
      );
      expect(c.state!.player.physique.heightCm, 195);
      expect(c.state!.player.physique.weightKg, 90);
      expect(c.state!.player.physique.foot, Foot.left);
    });
  });
}
