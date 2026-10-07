/// 最初の選手を自分で決めるところと、立つ側（左右）。
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:soccer_career/ui/screens/create_player_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/look.dart';
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
  /// **始めるのに要るものは、最初の画面に収まっている。**
  ///
  /// 決めることは11あって全体は3画面ぶんあるが、始めるのに本当に要るのは
  /// 名前と代理人だけ（年齢も身体も見た目も割り振りも既定で埋まっている）。
  /// 以前は「今回狙うもの」（2周目向けの挑戦の宣言）が名前より上にあり、
  /// **代理人は下から400pxのところ**にあったので、こだわらない人まで
  /// 3画面スクロールしてからでないと始められなかった。
  testWidgets('始めるのに要るものは、最初の画面に収まっている', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = CareerController(repository: _MemoryRepository());
    await tester.pumpWidget(
      MaterialApp(home: CreatePlayerScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    double topOf(Finder f) =>
        tester.getTopLeft(f.first).dy;

    // 名前と代理人が、開いた時点で画面の中にある。
    expect(topOf(find.widgetWithText(TextField, '選手名')), lessThan(844));
    expect(topOf(find.text('代理人')), lessThan(844));

    // 始めるボタンは下に固定してあるので、スクロールしなくても押せる。
    final button = find.widgetWithText(FilledButton, 'キャリアを始める');
    expect(button, findsOneWidget);
    expect(topOf(button), lessThan(844));

    // 挑戦の宣言（2周目向け）は、こだわる人が下まで見たときに出る。
    expect(topOf(find.text('今回狙うもの')), greaterThan(844));
  });

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
      expect(
        Formulas.weakFootMomentOnSide,
        lessThan(Formulas.weakFootMomentChance),
      );
      expect(
        Formulas.weakFootMomentInverted,
        greaterThan(Formulas.weakFootMomentChance),
      );
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
          physique: const Physique(
            heightCm: 175,
            weightKg: 70,
            foot: Foot.right,
          ),
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
      expect(inverted, greaterThan(onSide), reason: '逆サイドなのに逆足の局面が増えていない');
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
            if (match.factorsFor(option).any((f) => f.label == '内へ切り込む')) {
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

  group('見た目', () {
    test('選んだ見た目が残る', () async {
      final c = controller(seed: 61);
      await c.startCareer(
        name: '見た目',
        position: Position.st,
        age: 20,
        agent: Agent.pool.first,
        look: const PlayerLook(skin: 4, hair: HairStyle.curly, hairColor: 3),
        squadNumber: 27,
      );
      final player = c.state!.player;
      expect(player.look.skin, 4);
      expect(player.look.hair, HairStyle.curly);
      expect(c.state!.squadNumber, 27);

      final restored = CareerState.fromJson(c.state!.toJson());
      expect(restored.player.look.hair, HairStyle.curly);
      expect(restored.player.look.hairColor, 3);
    });

    test('見た目を持たせる前の保存データでも落ちない', () async {
      final c = controller(seed: 62);
      await c.startCareer(
        name: '古い保存',
        position: Position.cb,
        age: 22,
        agent: Agent.pool.first,
      );
      final json = c.state!.toJson();
      (json['player'] as Map<String, dynamic>).remove('look');
      final restored = CareerState.fromJson(json);
      expect(restored.player.look.hair, HairStyle.short);
      expect(restored.player.look.skin, 1);
    });

    test('範囲の外の番号が入っていても丸める', () {
      final look = PlayerLook.fromJson(const {
        'skin': 99,
        'hair': 'なにか',
        'hairColor': -3,
      });
      expect(look.skin, PlayerLook.skinTones.length - 1);
      expect(look.hairColor, 0);
      expect(look.hair, HairStyle.short);
    });

    test('出身国を選べる', () async {
      final c = controller(seed: 63);
      await c.startCareer(
        name: '国選び',
        position: Position.cm,
        age: 20,
        agent: Agent.pool.first,
        countryId: 'germania',
      );
      expect(c.state!.countryId, 'germania');
      expect(c.state!.club.countryId, 'germania');
    });
  });

  group('能力の割り振り', () {
    test('基準値は1か所から出ている', () {
      for (final position in Position.values) {
        final base = CareerEngine.startingBaseFor(position);
        expect(base[AttributeKey.pace], isNotNull, reason: position.name);
        // GK 能力を持つのは GK だけ。
        expect(
          base.containsKey(AttributeKey.goalkeeping),
          position == Position.gk,
          reason: position.name,
        );
      }
    });

    test('始まりの総合力は、ポジションで2より開かない', () {
      // **ポジションを選んだ時点で差が付いていた。** 基準値の総合力の差は
      // 2 しか無いが、そこから引くポテンシャル（`rollPotential` は総合力＋25）と
      // クラブの声がかりが乗るので、引退までにピークが 74.8〜78.4、
      // 代表キャップが 21.7〜41.8 に開いていた。
      //
      // **揃えたのは始まりではなくピークのほう。** 同じ1点でも、重みの
      // 集中したポジション（GK 0.59）と平らなポジション（AM 0.25）では
      // 総合力への返り方が違うので、始まりを揃えるとピークが揃わない
      // （実際に揃えたら SB のピークが 78.6 で突き抜けた）。
      // `test/position_sim.dart` でピークの幅 0.8・代表の幅 9.3 に合わせてある。
      // ここは「離れすぎていないか」だけを見る番人。
      final overalls = <Position, int>{};
      for (final position in Position.values) {
        final base = CareerEngine.startingBaseFor(position);
        overalls[position] = Attributes(
          pace: base[AttributeKey.pace]!,
          shooting: base[AttributeKey.shooting]!,
          passing: base[AttributeKey.passing]!,
          dribbling: base[AttributeKey.dribbling]!,
          defending: base[AttributeKey.defending]!,
          physical: base[AttributeKey.physical]!,
          goalkeeping:
              base[AttributeKey.goalkeeping] ?? Formulas.defaultGoalkeeping,
        ).overallFor(position);
      }
      final values = overalls.values.toList();
      expect(
        values.reduce((a, b) => a > b ? a : b) -
            values.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(2),
        reason: '始まりの総合力がポジションで開きすぎている: $overalls',
      );
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
      expect(
        tuned.player.attributes[AttributeKey.shooting],
        plain.player.attributes[AttributeKey.shooting] + 6,
      );
      expect(
        tuned.player.attributes[AttributeKey.defending],
        plain.player.attributes[AttributeKey.defending] - 6,
      );
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
