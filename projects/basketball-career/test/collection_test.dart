import 'dart:math';

import 'package:basketball_career/game/build.dart';
import 'package:basketball_career/game/collection.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/honors.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/season.dart';
import 'package:basketball_career/game/skills.dart';
import 'package:basketball_career/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

Game _game({Set<Trait> traits = const {}, Set<Skill> skills = const {}, int a = 40}) {
  final base = Game.start('x', rng: Random(1), events: false);
  return Game(
    eventsEnabled: false,
    player: base.player.copyWith(
      age: 30,
      heightCm: 190,
      abilities: {
        for (final x in Ability.values)
          x: (x == Ability.threePoint || x == Ability.midRange || x == Ability.freeThrow) ? 82 : a,
      },
      traits: traits,
      skills: skills,
    ),
    rng: Random(2),
  );
}

void main() {
  group('図鑑', () {
    test('空の図鑑: 0個で、全体の数は 表彰10・ビルド7・特性20・得意技10', () {
      const c = Collection.empty();
      expect(c.collected, 0);
      expect(Collection.honorTotal, Honor.all.length);
      expect(Collection.buildTotal, Build.values.length);
      expect(Collection.traitTotal, Trait.values.length);
      expect(Collection.skillTotal, Skill.values.length);
      expect(c.total, Honor.all.length + Build.values.length + Trait.values.length + Skill.values.length);
    });

    test('引退した選手の特性・得意技・ビルド・表彰が足される', () {
      final g = _game(traits: {Trait.lefty, Trait.captain}, skills: {Skill.stepBack});
      g.records.add(const YearRecord(
        age: 25, league: League.proDomestic, wins: 5, games: 8, ppg: 24, rpg: 5, apg: 3,
        champion: false, achievement: 70, honors: [Honor.scoringKing, Honor.allStar],
      ));
      final c = const Collection.empty().merge(g);
      expect(c.traits, {'lefty', 'captain'});
      expect(c.skills, {'stepBack'});
      expect(c.honors, {Honor.scoringKing, Honor.allStar});
      expect(c.builds.keys, contains('sharpshooter'));
      expect(c.builds['sharpshooter'], greaterThanOrEqualTo(2));
    });

    test('足し続けても減らない。ビルドは最高のティアが残る', () {
      final g1 = _game(traits: {Trait.lefty});
      g1.buildsSeen.add('sharpshooter:3');
      final g2 = _game(traits: {Trait.captain});
      final c = const Collection.empty().merge(g1).merge(g2);
      expect(c.traits, {'lefty', 'captain'});
      expect(c.builds['sharpshooter'], 3, reason: '前の人生の最高ティアが残る');
      final more = c.merge(_game());
      expect(more.collected, greaterThanOrEqualTo(c.collected));
    });

    test('途中で到達したビルドも覚える(Game.buildsSeen)。保存・復元で残る', () {
      final g = _game();
      g.choose(Action.rest, Ability.threePoint);
      expect(g.buildsSeen, isNotEmpty);
      final back = Game.fromJson(g.toJson());
      expect(back.buildsSeen, g.buildsSeen);
      final j = g.toJson()..remove('buildsSeen');
      expect(Game.fromJson(j).buildsSeen, isEmpty);
    });

    test('保存・復元で変わらず、壊れた値や知らない名前は捨てる', () {
      final c = Collection(
        honors: {Honor.rookie},
        traits: {Trait.gameSmart.name},
        skills: {Skill.dunk.name},
        builds: {Build.lockdown.name: 2},
      );
      final back = Collection.fromJson(c.toJson());
      expect(back.honors, c.honors);
      expect(back.traits, c.traits);
      expect(back.skills, c.skills);
      expect(back.builds, c.builds);
      final bad = Collection.fromJson({
        'honors': ['存在しない賞', Honor.scoringKing, 3],
        'traits': ['nothing', 'lefty'],
        'skills': 'x',
        'builds': {'nothing': 1, 'slasher': 99, 'playmaker': 'a'},
      });
      expect(bad.honors, {Honor.scoringKing});
      expect(bad.traits, {'lefty'});
      expect(bad.skills, isEmpty);
      expect(bad.builds, {'slasher': 3}, reason: 'ティアは範囲に収める');
      expect(Collection.fromJson(null).collected, 0);
    });
  });
}
