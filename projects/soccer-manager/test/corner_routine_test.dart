import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/corner_routine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

/// コーナーキックの狙い。
///
/// 狙いに順位は無い。狙いごとに「合わせる選手に求められる能力」が変わるので、
/// 手持ちの選手に合うものを選べているかが結果に出る。長身がいないのに
/// ファーで競っても形だけになる。
void main() {
  Player make(
    String id, {
    required Position position,
    int heading = 50,
    int anticipation = 50,
    int longShots = 50,
    int technique = 50,
  }) {
    final p = Player(
      id: id,
      name: id,
      age: 26,
      position: position,
      potential: 80,
      matchSharpness: 80,
    );
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    p.setAttributeValue(AttributeKeys.heading, heading);
    p.setAttributeValue(AttributeKeys.anticipation, anticipation);
    p.setAttributeValue(AttributeKeys.longShots, longShots);
    p.setAttributeValue(AttributeKeys.technique, technique);
    return p;
  }

  /// 4-4-2 相当の11人。ある能力を GK 以外の全員へ与える。
  ///
  /// 「1人だけ突出させる」形は使わない。ファーで競る狙いの合わせ手は
  /// 重み付き抽選で選ばれるため、その1人が選ばれるとは限らず、テストが
  /// 引き次第で落ちる。全員に与えれば誰が選ばれても条件が成り立つ。
  List<Player> lineup({
    String attribute = AttributeKeys.heading,
    int value = 50,
  }) {
    final players = <Player>[
      make('gk', position: Position.gk),
      for (final p in [Position.dr, Position.dc, Position.dc, Position.dl])
        make('d${p.name}${identityHashCode(p)}', position: p),
      for (final p in [Position.mr, Position.mc, Position.mc, Position.ml])
        make('m${p.name}${identityHashCode(p)}', position: p),
      make('st1', position: Position.st),
      make('st2', position: Position.st),
    ];
    for (final p in players) {
      if (p.position != Position.gk) p.setAttributeValue(attribute, value);
    }
    return players;
  }

  Team team(List<Player> players, CornerRoutine routine) => Team(
        id: 't',
        name: 'T',
        players: players,
        cornerRoutine: routine,
      );

  double probFor({
    required CornerRoutine routine,
    required String attribute,
    required int value,
  }) {
    final attackers = lineup(attribute: attribute, value: value);
    final defenders = lineup();
    final result = MatchEngine.resolveCorner(
      attackingTeam: team(attackers, routine),
      attackingLineup: attackers,
      defendingTeam: team(defenders, CornerRoutine.farPost),
      defendingLineup: defenders,
      baseProb: 0.2,
    );
    return result.scoreProb;
  }

  group('狙いに合った選手がいると決定率が上がる', () {
    test('ファーで競る: 空中戦に強い選手がいると上がる', () {
      final without = probFor(
          routine: CornerRoutine.farPost,
          attribute: AttributeKeys.heading,
          value: 30);
      final with_ = probFor(
          routine: CornerRoutine.farPost,
          attribute: AttributeKeys.heading,
          value: 95);
      expect(with_, greaterThan(without));
    });

    test('こぼれ球を狙う: ミドルの上手い選手がいると上がる', () {
      final without = probFor(
          routine: CornerRoutine.edgeOfBox,
          attribute: AttributeKeys.longShots,
          value: 30);
      final with_ = probFor(
          routine: CornerRoutine.edgeOfBox,
          attribute: AttributeKeys.longShots,
          value: 95);
      expect(with_, greaterThan(without));
    });
  });

  group('狙いが手持ちと噛み合っているか', () {
    test('長身しかいないなら、こぼれ球狙いよりファーの方が良い', () {
      final aerial = probFor(
          routine: CornerRoutine.farPost,
          attribute: AttributeKeys.heading,
          value: 95);
      final mistaken = probFor(
          routine: CornerRoutine.edgeOfBox,
          attribute: AttributeKeys.heading,
          value: 95);
      expect(aerial, greaterThan(mistaken),
          reason: '空中戦要員しかいないのにミドル狙いは活きないはず');
    });

    test('ミドルの上手い選手しかいないなら、ファーよりこぼれ球狙いが良い', () {
      final shooting = probFor(
          routine: CornerRoutine.edgeOfBox,
          attribute: AttributeKeys.longShots,
          value: 95);
      final mistaken = probFor(
          routine: CornerRoutine.farPost,
          attribute: AttributeKeys.longShots,
          value: 95);
      expect(shooting, greaterThan(mistaken));
    });
  });

  group('狙いによる形の違い', () {
    test('足元の形(こぼれ球・ショート)では中盤の選手も合わせ手になる', () {
      final attackers = lineup();
      // 中盤の1人だけミドルが突出している状態を作る。
      final mid = attackers.firstWhere((p) => p.position == Position.mc);
      mid.setAttributeValue(AttributeKeys.longShots, 95);
      final defenders = lineup();

      final r = MatchEngine.resolveCorner(
        attackingTeam: team(attackers, CornerRoutine.edgeOfBox),
        attackingLineup: attackers,
        defendingTeam: team(defenders, CornerRoutine.farPost),
        defendingLineup: defenders,
        baseProb: 0.2,
      );

      expect(r.scorer?.id, mid.id,
          reason: 'エリア手前を狙う形で前線しか見ないのは実態に合わない');
    });

    test('蹴る人はターゲットに選ばれない', () {
      final attackers = lineup();
      final taker = attackers.firstWhere((p) => p.id == 'st1');
      final defenders = lineup();
      final t = team(attackers, CornerRoutine.farPost)
        ..cornerTakerId = taker.id;

      final r = MatchEngine.resolveCorner(
        attackingTeam: t,
        attackingLineup: attackers,
        defendingTeam: team(defenders, CornerRoutine.farPost),
        defendingLineup: defenders,
        baseProb: 0.2,
      );

      expect(r.taker?.id, taker.id);
      expect(r.scorer?.id, isNot(taker.id));
    });
  });

  test('旧セーブは従来の挙動(ファーで競る)のまま読む', () {
    final json = Team(id: 't', name: 'T', players: const []).toJson();
    json.remove('cornerRoutine');
    expect(Team.fromJson(json).cornerRoutine, CornerRoutine.farPost);
  });
}
