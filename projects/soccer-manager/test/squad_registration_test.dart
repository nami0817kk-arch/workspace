import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/squad_registration_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';

Player _p(String id, {required int age, bool homegrown = false}) {
  final p = PlayerGenerator.generate(
      position: Position.mc, strengthTier: 60, ageOverride: age);
  return Player.fromJson({...p.toJson(), 'id': id, 'homegrown': homegrown});
}

Team _team(List<Player> players) =>
    Team(id: 't', name: 'T', players: players);

void main() {
  test('22歳以上が25人いると、22歳以上はもう入らないが21歳以下は入る', () {
    final team = _team([
      for (var i = 0; i < 25; i++) _p('s$i', age: 25, homegrown: true),
    ]);
    expect(SquadRegistration.canAdd(team, _p('x', age: 26, homegrown: true)),
        isFalse);
    expect(SquadRegistration.canAdd(team, _p('y', age: 20)), isTrue);
  });

  test('国外で育った22歳以上は17人まで。国内育成ならまだ入る', () {
    final team = _team([
      for (var i = 0; i < 17; i++) _p('f$i', age: 27),
    ]);
    expect(SquadRegistration.canAdd(team, _p('x', age: 27)), isFalse);
    expect(SquadRegistration.blockReason(team, _p('x', age: 27)),
        contains('${SquadRegistration.nonHomegrownLimit}'));
    expect(SquadRegistration.canAdd(team, _p('h', age: 27, homegrown: true)),
        isTrue);
  });

  test('ユース出身は国内育成として数える', () {
    final p = _p('a', age: 23)..academyGraduate = true;
    expect(p.isHomegrown, isTrue);
  });

  test('在籍の総数が上限なら、21歳以下でも入らない', () {
    final team = _team([
      for (var i = 0; i < SquadRegistration.totalLimit; i++)
        _p('u$i', age: 19),
    ]);
    expect(SquadRegistration.canAdd(team, _p('y', age: 18)), isFalse);
  });

  test('旧セーブの選手は、読み込むたびに同じ国内育成の印になる', () {
    final json = _p('old_1', age: 24).toJson()..remove('homegrown');
    final a = Player.fromJson(json).homegrown;
    final b = Player.fromJson(json).homegrown;
    expect(a, b);
    expect(a, Player.homegrownFromId('old_1'));
  });

  test('強いクラブほど人数を多く抱える(25人・GK3人 / 22人)', () {
    final big = PlayerGenerator.generateSquad(
        id: 'b', name: 'B', strengthTier: 80);
    final small = PlayerGenerator.generateSquad(
        id: 's', name: 'S', strengthTier: 40);
    expect(big.players.length, 25);
    expect(big.players.where((p) => p.position == Position.gk).length, 3);
    expect(small.players.length, 22);
  });

  test('生成した選手の半分前後が国内育成になる', () {
    final players = [
      for (var i = 0; i < 400; i++)
        PlayerGenerator.generate(position: Position.st, strengthTier: 60),
    ];
    final share = players.where((p) => p.homegrown).length / players.length;
    expect(share, inInclusiveRange(0.45, 0.75));
  });
}
