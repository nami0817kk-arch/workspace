import 'dart:math';

import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/veteran.dart';
import 'package:flutter_test/flutter_test.dart';

Game _pro({int age = 33, int ability = 70, int seed = 1}) => Game(
      eventsEnabled: false,
      player: Player(name: 'x', age: age, potential: 60, heightCm: 190, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: ability}),
      rng: Random(seed),
      track: Track.pro,
      salary: 3000,
    );

void main() {
  test('選べるのはプロの33歳から。選ばなければエースのまま', () {
    final young = _pro(age: 32);
    expect(young.canPickVeteranRole, isFalse);
    expect(young.activeRole, isNull);
    expect(() => young.setVeteranRole(VeteranRole.sixth), throwsStateError);
    final g = _pro();
    expect(g.canPickVeteranRole, isTrue);
    expect(g.activeRole, VeteranRole.ace);
    g.setVeteranRole(VeteranRole.mentor);
    expect(g.activeRole, VeteranRole.mentor);
  });

  test('6人目の切り札: 大会では総合によらず控えで出る', () {
    final g = _pro(ability: 85)..setVeteranRole(VeteranRole.sixth);
    g.slot = 1; // 夏の大会
    final r = g.choose(Action.rest, Ability.pass);
    expect(r.tournament, isNotNull);
    expect(r.tournament!.matches.every((m) => !m.starter), isTrue);
    final ace = _pro(ability: 85)..slot = 1;
    expect(ace.choose(Action.rest, Ability.pass).tournament!.matches.every((m) => m.starter), isTrue);
  });

  test('衰え: 切り札は小さく、指導役は少し大きい(同じ乱数で比べる)', () {
    int lost(VeteranRole r) {
      var total = 0;
      for (var seed = 0; seed < 30; seed++) {
        final g = _pro(age: 35, seed: seed)..setVeteranRole(r);
        g.slot = 0;
        final before = g.player.overall;
        g.choose(Action.rest, Ability.pass);
        total += ((before - g.player.overall) * 100).round();
      }
      return total;
    }

    final ace = lost(VeteranRole.ace);
    expect(lost(VeteranRole.sixth), lessThan(ace));
    expect(lost(VeteranRole.mentor), greaterThan(ace));
  });

  test('若手の指導役: チームワークが薄れず、コーチとの信頼が上がる', () {
    final g = _pro()..setVeteranRole(VeteranRole.mentor);
    g.teamwork = 60;
    g.coachBond = 40;
    g.slot = 0;
    g.choose(Action.rest, Ability.pass);
    expect(g.teamwork, 60);
    expect(g.coachBond, 43);
    final ace = _pro()..teamwork = 60;
    ace.slot = 0;
    ace.choose(Action.rest, Ability.pass);
    expect(ace.teamwork, lessThan(60));
  });

  test('33歳になった年の終わりに知らせが出る。選んだ役割はエンディングに残り、保存される', () {
    final g = _pro(age: 32);
    g.slot = 3;
    g.choose(Action.rest, Ability.pass);
    expect(g.player.age, 33);
    expect(g.lastVeteranNote, contains('役割を選べる'));
    g.setVeteranRole(VeteranRole.sixth);
    final back = Game.fromJson(g.toJson());
    expect(back.veteranRole, VeteranRole.sixth);
    expect(Game.fromJson(g.toJson()..remove('veteranRole')).veteranRole, isNull);
    expect(Game.fromJson(g.toJson()..['veteranRole'] = 'こわれた').veteranRole, isNull);
    g.player = g.player.copyWith(age: 36);
    g.retire();
    expect(epilogueLines(g).join(), contains('6人目の切り札'));
  });

  test('おすすめ: 控えの線より低ければ切り札', () {
    expect(suggestedVeteranRole(50, 56), VeteranRole.sixth);
    expect(suggestedVeteranRole(70, 56), VeteranRole.ace);
    expect(suggestedVeteranRole(40, null), VeteranRole.ace);
  });
}
