/// **役割（ロール）。同じポジションでも、求められるものが違う。**
///
/// 総合力はポジションの重み付き平均なので、そのポジションが求めないものを
/// 伸ばすほど総合力が下がる（実測で、中盤の選手を守備一本で育てると
/// ピークが 75.4 → 69.4、代表は 35 → 4 キャップまで落ちた）。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/role.dart';
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

Player _cm({required int defending, required int rest}) => Player(
  name: 'テスト',
  position: Position.cm,
  age: 26,
  potential: 90,
  attributes: Attributes.fromDetails({
    for (final d in Detail.values)
      d: d.category == AttributeKey.defending ? defending : rest,
  }),
);

void main() {
  group('役割の形', () {
    test('どのポジションにも役割が用意してある', () {
      for (final position in Position.values) {
        final roles = PlayerRole.values.where((r) => r.position == position);
        expect(roles.length, greaterThanOrEqualTo(2), reason: position.name);
      }
    });

    test('どの役割も、どれかの戦術から届く', () {
      // 誰も使わない役割は、就く道が無い＝存在しないのと同じ。
      for (final role in PlayerRole.values) {
        expect(role.tactics, isNotEmpty, reason: role.name);
      }
    });

    test('役割が無い監督の下も、4分の1くらいはある', () {
      // **どの監督の下でも就けると、役割はただの付け替えになる。**
      // 実測: 40通り（8ポジション × 5戦術）のうち 30 で就ける。
      // 残りの4分の1は「移籍するか監督が代わるのを待つ」ことになる。
      var offered = 0;
      for (final position in Position.values) {
        for (final tactic in Tactic.values) {
          if (PlayerRole.offeredBy(tactic, position).isNotEmpty) offered++;
        }
      }
      final total = Position.values.length * Tactic.values.length;
      expect(offered, lessThan(total));
      expect(offered, greaterThanOrEqualTo((total * 0.6).round()));
    });

    test('どの戦術でも、就ける役割がある', () {
      for (final tactic in Tactic.values) {
        final offered = [
          for (final p in Position.values)
            ...PlayerRole.offeredBy(tactic, p),
        ];
        expect(offered, isNotEmpty, reason: tactic.name);
      }
    });

    test('重みは、そのポジションの標準と同じ並び', () {
      for (final role in PlayerRole.values) {
        expect(role.weights.length, AttributeKey.values.length);
        expect(role.weights.every((w) => w >= 0), isTrue);
      }
    });

    test('GK 以外の役割は GK 能力を数えない', () {
      // 数えると、フィールドの選手が GK 能力を伸ばす意味を持ってしまう。
      final gkIndex = AttributeKey.values.indexOf(AttributeKey.goalkeeping);
      for (final role in PlayerRole.values) {
        if (role.position == Position.gk) continue;
        expect(role.weights[gkIndex], 0, reason: role.name);
      }
    });
  });

  group('効き方', () {
    test('尖った選手は、合う役割のほうが高く測られる', () {
      final player = _cm(defending: 95, rest: 60);
      final standard = player.attributes.overallFor(Position.cm);
      final dynamo = player.attributes.overallFor(
        Position.cm,
        weights: PlayerRole.dynamo.weights,
      );
      expect(dynamo, greaterThan(standard));
    });

    test('平らな選手は、どの役割でも変わらない', () {
      // **ここが崩れると、役割はただの上乗せになる。**
      // 重みの置き換えなので、全部同じ能力なら測り方を変えても同じ。
      final player = _cm(defending: 70, rest: 70);
      for (final role in PlayerRole.values) {
        if (role.position != Position.cm) continue;
        expect(
          player.attributes.overallFor(Position.cm, weights: role.weights),
          player.attributes.overallFor(Position.cm),
          reason: role.name,
        );
      }
    });

    test('尖った向きと逆の役割を選べば、下がる', () {
      final player = _cm(defending: 95, rest: 60);
      expect(
        player.attributes.overallFor(
          Position.cm,
          weights: PlayerRole.playmaker.weights,
        ),
        lessThan(player.attributes.overallFor(Position.cm)),
      );
    });

    test('ポジションに合わない役割は効かない', () {
      // コンバートで置き去りになった役割を、黙って効かせない。
      final player = _cm(
        defending: 95,
        rest: 60,
      ).copyWith(role: PlayerRole.poacher);
      expect(player.roleWeights, isNull);
      expect(player.overall, _cm(defending: 95, rest: 60).overall);
    });
  });

  group('就き方', () {
    Future<CareerController> started() async {
      final controller = CareerController(
        repository: _MemoryRepository(),
        careerEngine: CareerEngine(random: Random(4)),
        matchEngine: MatchEngine(random: Random(4)),
        random: Random(4),
      );
      await controller.startCareer(
        name: '検証',
        position: Position.cm,
        age: 22,
        agent: Agent.pool.first,
      );
      return controller;
    }

    test('監督が使っていない役割には就けない', () async {
      final controller = await started();
      final offered = controller.roleChoices;
      final notOffered = PlayerRole.values.firstWhere(
        (r) => r.position == Position.cm && !offered.contains(r),
        orElse: () => PlayerRole.poacher,
      );
      await controller.setRole(notOffered);
      expect(controller.state!.player.role, isNull);
    });

    test('監督が使っている役割には就ける。もう一度選べば外れる', () async {
      final controller = await started();
      final offered = controller.roleChoices;
      expect(offered, isNotEmpty, reason: '監督が使っている役割が1つも無い');
      await controller.setRole(offered.first);
      expect(controller.state!.player.role, offered.first);
      await controller.setRole(null);
      expect(controller.state!.player.role, isNull);
    });

    test('役割は、保存して読み直しても残る', () async {
      final controller = await started();
      final offered = controller.roleChoices;
      expect(offered, isNotEmpty, reason: '監督が使っている役割が1つも無い');
      await controller.setRole(offered.first);
      final state = controller.state!;
      expect(
        CareerState.fromJson(state.toJson()).player.role,
        offered.first,
      );

      // 役割を知らない保存データは「標準」で読む。
      final json = state.toJson();
      (json['player'] as Map<String, dynamic>).remove('role');
      expect(CareerState.fromJson(json).player.role, isNull);
    });
  });
}
