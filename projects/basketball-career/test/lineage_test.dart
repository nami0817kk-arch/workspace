import 'dart:math';

import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/lineage.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:basketball_career/game/traits.dart';
import 'package:basketball_career/ui/controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 引退した親(プロで優勝あり・背の高い素質・前向きの特性)。
Game _parent() {
  final g = Game(
    eventsEnabled: false,
    player: Player(name: 'ミナト', age: 36, potential: 70, heightCm: 200, heightGenes: 0.9,
        traits: {Trait.sunny},
        abilities: {for (final a in Ability.values) a: a == Ability.threePoint ? 88 : 70}),
    rng: Random(1),
    track: Track.pro,
  );
  g.records.add(YearRecord(age: 28, league: League.proDomestic, wins: 9, games: 12, ppg: 20, rpg: 5, apg: 4, champion: true, achievement: 90));
  g.retire();
  return g;
}

void main() {
  test('子ども: 身長の素質は親と運の間、特性を1つ受け継ぐ。親の栄誉で素質が上がる', () {
    final h = heirOf(_parent(), HeirKind.child, Random(3), title: '常勝の司令塔', legend: false);
    expect(h.generation, 2);
    expect(h.parentName, 'ミナト');
    expect(h.heightGenes, greaterThanOrEqualTo(0.45));
    expect(h.trait, Trait.sunny);
    expect(h.taughtAbility, isNull);
    expect(h.potentialBonus, 4, reason: 'プロ +2・プロで優勝 +2');
    expect(h.summary.join(), contains('前向き'));
  });

  test('教え子: いちばん得意だった能力を教わり、コーチとの信頼が高い', () {
    final h = heirOf(_parent(), HeirKind.pupil, Random(3), title: 't', legend: true);
    expect(h.taughtAbility, Ability.threePoint);
    expect(h.potentialBonus, 6);
    final g = Game.start('ソラ', rng: Random(9), heir: h);
    final plain = Game.start('ソラ', rng: Random(9));
    expect(g.player.of(Ability.threePoint), plain.player.of(Ability.threePoint) + taughtBonus);
    expect(g.coachBond, pupilCoachBond);
    expect(g.player.potential, (plain.player.potential + 6).clamp(30, 100));
    expect(g.generation, 2);
  });

  test('受け継がなければ、今までと同じ選手になる(乱数の並びが変わらない)', () {
    final a = Game.start('x', rng: Random(42));
    final b = Game.start('x', rng: Random(42), heir: null);
    expect(b.player.toJson(), a.player.toJson());
    expect(a.generation, 1);
    expect(a.parentName, isNull);
  });

  test('子どもとして始めると特性と身長の素質が入り、保存・エンディング・共有文に残る', () {
    final h = heirOf(_parent(), HeirKind.child, Random(3), title: '常勝の司令塔', legend: false);
    final g = Game.start('ソラ', rng: Random(5), heir: h, traits: const {});
    expect(g.player.traits, contains(Trait.sunny));
    expect(g.player.heightGenes, h.heightGenes);
    final back = Game.fromJson(g.toJson());
    expect(back.generation, 2);
    expect(back.parentName, 'ミナト');
    expect(back.heirKind, HeirKind.child);
    expect(Game.fromJson(g.toJson()..remove('generation')).generation, 1);
    g.track = Track.pro;
    g.retire();
    expect(epilogueLines(g).first, contains('2代目'));
    expect(epilogueLines(g).first, contains('ミナトの子ども'));
    expect(shareText(g), contains('2代目'));
  });

  test('両立しない特性は受け継がない', () {
    final h = Heir(kind: HeirKind.child, parentName: 'a', parentTitle: '', generation: 2, trait: Trait.lateBloomer);
    expect(withInherited({Trait.earlyBloomer}, h), {Trait.earlyBloomer});
    expect(withInherited(const {}, h), {Trait.lateBloomer});
    expect(withInherited({Trait.lateBloomer}, null), {Trait.lateBloomer});
  });

  test('保存した受け継ぎ: 壊れていれば null', () {
    final h = heirOf(_parent(), HeirKind.child, Random(3), title: 't', legend: false);
    final back = Heir.fromJson(h.toJson())!;
    expect(back.trait, h.trait);
    expect(back.heightGenes, h.heightGenes);
    expect(Heir.fromJson('x'), isNull);
    expect(Heir.fromJson({'kind': 'nope'}), isNull);
    expect(Heir.fromJson({'kind': 'pupil', 'potentialBonus': 99})!.potentialBonus, maxHeirPotentialBonus);
  });

  test('画面の流れ: 引退後に「子どもとして育てる」→ はじめの画面 → 始めると使い切る', () async {
    final c = GameController(store: _NullStore(), rng: Random(1), events: false);
    c.game = _parent();
    await c.startNextGeneration(HeirKind.child);
    expect(c.game, isNull);
    expect(c.nextHeir!.generation, 2);
    c.newGame('ソラ');
    expect(c.game!.generation, 2);
    expect(c.nextHeir, isNull);
    c.game = _parent();
    await c.startNextGeneration(HeirKind.pupil);
    c.dropHeir();
    c.newGame('ハル');
    expect(c.game!.generation, 1);
  });
}

class _NullStore extends SaveStore {
  @override
  Future<void> save(Map<String, dynamic> json) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, dynamic>?> load() async => null;
}
