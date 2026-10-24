// 特殊能力(経験点で取る・コツで安くなる)と、行動ごとの役割の違い(2026-10-24)。
import 'dart:math';

import 'package:baseball_manager/game/exp.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:baseball_manager/game/skills.dart';
import 'package:baseball_manager/game/traits.dart';
import 'package:flutter_test/flutter_test.dart';

Game _game({Role role = Role.batter, int seed = 3}) =>
    Game.newGame(name: 't', role: role, rng: Random(seed), potential: 60);

/// 季節の段階で、出来事を片付けてから行動する。
void _act(Game g, Plan p, [Ability? f]) {
  while (g.phase == Phase.event) {
    g.resolveEvent(0);
  }
  g.choose(p, f);
}

void main() {
  group('特殊能力', () {
    test('打者・投手で取れるものが分かれ、二刀流は両方', () {
      final bat = skillsFor(Role.batter).toSet();
      final pit = skillsFor(Role.pitcher).toSet();
      expect(bat, contains(Skill.chance));
      expect(bat, isNot(contains(Skill.strikeout)));
      expect(pit, contains(Skill.strikeout));
      expect(pit, isNot(contains(Skill.stealer)));
      expect(skillsFor(Role.twoWay).toSet(), {...bat, ...pit});
      // 打者・投手とも、基本が6つ以上・金特が2つ
      expect(bat.where((s) => !s.gold).length, greaterThanOrEqualTo(6));
      expect(bat.where((s) => s.gold).length, 2);
      expect(pit.where((s) => s.gold).length, 2);
      for (final s in Skill.values.where((s) => s.gold)) {
        expect(s.requires, isNotNull, reason: s.name);
        expect(s.requires!.gold, isFalse);
        expect(s.requires!.category, s.category);
      }
    });

    test('コツ1つで10%安く、5つ(上限)で半額', () {
      expect(skillCost(Skill.powerHitter, 0), 40);
      expect(skillCost(Skill.powerHitter, 1), 36);
      expect(skillCost(Skill.powerHitter, 5), 20);
      expect(skillCost(Skill.powerHitter, 9), 20); // 上限で止まる
    });

    test('経験点で取る。足りない・役割違い・金特のもとが無いと取れない', () {
      final g = _game();
      expect(g.buySkill(Skill.powerHitter), '経験点が足りない');
      g.adminAddExp(200);
      expect(g.buySkill(Skill.strikeout), 'この役割では取れない');
      expect(g.buySkill(Skill.artist), contains('パワーヒッター'));
      final before = g.exp.of(Category.batting);
      expect(g.buySkill(Skill.powerHitter), isNull);
      expect(g.player.skills, contains(Skill.powerHitter));
      expect(g.exp.of(Category.batting), before - 40);
      expect(g.buySkill(Skill.powerHitter), '取得済み');
      // もとを取ったので金特が取れる(値段は高い)
      g.adminAddExp(200);
      expect(g.buySkill(Skill.artist), isNull);
      expect(g.player.skills, contains(Skill.artist));
      expect(g.log.any((l) => l.contains('特殊能力「アーチスト」を取得')), isTrue);
    });

    test('コツが貯まっていれば、その分だけ安く取れる。取るとコツは消える', () {
      final g = _game();
      g.skillTips[Skill.chance] = 5;
      g.adminAddExp(15);
      expect(g.skillPrice(Skill.chance), 15);
      expect(g.buySkill(Skill.chance), isNull);
      expect(g.skillTips.containsKey(Skill.chance), isFalse);
    });

    test('試合の間だけ能力が上がり、大会の勝負どころに効くものもある', () {
      final p = Player(
          name: 't',
          role: Role.batter,
          age: 20,
          potential: 50,
          abilities: {for (final a in batterAbilities) a: 50},
          skills: {Skill.averageHitter, Skill.chance});
      expect(traitAdjusted(p).of(Ability.contact), 56);
      expect(p.of(Ability.contact), 50); // 元の能力は変えない(総合評価・ドラフトには入らない)
      expect(matchBonus(p), 6);
      expect(matchBonus(p.copyWith(traits: {Trait.clutch})), 16);
    });

    test('保存して読み直せる。昔の特性(長距離砲など)は特殊能力に読み替える', () {
      final g = _game();
      g.adminAddExp(100);
      g.buySkill(Skill.stealer);
      g.skillTips[Skill.chance] = 3;
      g.setStudyTarget(Skill.chance);
      final back = Game.fromJson(g.toJson(), Random(1));
      expect(back.player.skills, {Skill.stealer});
      expect(back.skillTips[Skill.chance], 3);
      expect(back.studyTarget, Skill.chance);
      // 古いセーブ: 項目が無い / 昔の特性の名前
      final j = g.toJson();
      (j['player'] as Map)['skills'] = null;
      (j['player'] as Map)['traits'] = ['slugger', 'genius', 'fireballer'];
      j.remove('skillTips');
      j.remove('studyTarget');
      final old = Game.fromJson(j, Random(1));
      expect(old.player.skills, {Skill.powerHitter, Skill.strikeout});
      expect(old.player.traits, {Trait.genius});
      expect(old.skillTips, isEmpty);
      expect(old.studyTarget, isNull);
    });
  });

  group('行動ごとの役割', () {
    test('研究: 経験点はわずかで、選んだ特殊能力のコツが+2(研究熱心は+3)', () {
      final g = _game();
      g.setStudyTarget(Skill.wideAngle);
      _act(g, Plan.study, Ability.contact);
      expect(g.skillTips[Skill.wideAngle], 2);
      expect(g.log.any((l) => l.contains('研究で「広角打法」のコツ +2')), isTrue);
      final s = _game(seed: 4);
      s.player = s.player.copyWith(traits: {Trait.studious});
      s.setStudyTarget(Skill.wideAngle);
      _act(s, Plan.study, Ability.contact);
      expect(s.skillTips[Skill.wideAngle], 3);
    });

    test('研究の対象を選ばなければ、重点の種類でコツの多いものに貯まる', () {
      final g = _game();
      g.skillTips[Skill.fieldMaster] = 2;
      _act(g, Plan.study, Ability.fielding);
      expect(g.skillTips[Skill.fieldMaster], 4);
      expect(() => g.setStudyTarget(Skill.strikeout), throwsArgumentError);
    });

    test('研究は練習より経験点がずっと少なく、練習はコツが貯まらない', () {
      int expOf(Plan p) {
        final g = _game(seed: 9);
        _act(g, p, Ability.contact);
        return g.lastGain.values.fold(0, (a, b) => a + b);
      }

      expect(expOf(Plan.study), lessThan(expOf(Plan.train) / 3));
      final t = _game(seed: 9);
      _act(t, Plan.train, Ability.contact);
      expect(t.skillTips, isEmpty);
    });

    test('練習試合は勝負どころの特殊能力に、交流は仲間の得意な種類にコツが貯まる', () {
      final m = _game();
      _act(m, Plan.match);
      expect(m.skillTips.keys.where((s) => s.forMatches), isNotEmpty);
      final s = _game(seed: 5);
      _act(s, Plan.social);
      final kinds = {
        for (final mate in s.cast.teammates) categoryOf(mate.specialty!)
      };
      expect(s.skillTips, isNotEmpty);
      for (final k in s.skillTips.keys) {
        expect(kinds, contains(k.category));
      }
    });

    test('特訓は、好調・大成功の回だけ重点の種類にコツが貯まる', () {
      var tipped = 0, good = 0;
      for (var seed = 0; seed < 60; seed++) {
        final g = _game(seed: seed);
        while (g.phase == Phase.event) {
          g.resolveEvent(0);
        }
        if (g.condition.injured) continue;
        g.choose(Plan.special, Ability.speed);
        final o = g.lastOutcome;
        final got = g.skillTips.keys
            .where((k) => k.category == Category.running)
            .isNotEmpty;
        if (o == Outcome.good || o == Outcome.great) {
          good++;
          if (got) tipped++;
        } else {
          expect(got, isFalse, reason: 'seed=$seed $o');
        }
      }
      expect(good, greaterThan(0));
      expect(tipped, good);
    });
  });

  test('特性は体質と性格だけになった(試合の能力を足す特性は無い)', () {
    expect(Trait.values.length, lessThanOrEqualTo(26));
    expect(rareTraits.length, 5);
    for (final t in Trait.values) {
      expect(t.appliesTo(Role.batter) && t.appliesTo(Role.pitcher), isTrue,
          reason: t.name);
    }
  });
}
