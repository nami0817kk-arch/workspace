// 特殊能力(経験点で取る・コツで安くなる)と、行動ごとの役割の違い(2026-10-24)。
import 'dart:math';

import 'package:baseball_manager/game/career.dart';
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
  test('研究の対象のコツが満タンなら、研究は別の特殊能力に回る(空振りしない)', () {
    final g = _game();
    g.setStudyTarget(Skill.stealer);
    expect(g.studyFocus(Ability.contact), Skill.stealer);
    g.skillTips[Skill.stealer] = maxSkillTips;
    final next = g.studyFocus(Ability.contact);
    expect(next, isNotNull);
    expect(next, isNot(Skill.stealer));
    // 研究すると、満タンでない別の特殊能力にコツが入る
    final before = Map.of(g.skillTips);
    _act(g, Plan.study, Ability.contact);
    final grew = [
      for (final s in g.skillTips.keys)
        if ((g.skillTips[s] ?? 0) > (before[s] ?? 0)) s
    ];
    expect(grew, isNotEmpty);
    expect(grew, isNot(contains(Skill.stealer)));
  });

  test('管理者: 特殊能力の付け外しとコツの書き換え', () {
    final g = _game();
    g.skillTips[Skill.chance] = 2;
    g.setStudyTarget(Skill.chance);
    g.adminSetSkills({Skill.chance, Skill.strikeoutProne});
    expect(g.player.skills, {Skill.chance, Skill.strikeoutProne});
    expect(g.skillTips[Skill.chance], isNull);
    expect(g.studyTarget, isNull);
    g.adminSetSkillTips(Skill.stealer, 9);
    expect(g.skillTips[Skill.stealer], maxSkillTips);
    g.adminSetSkillTips(Skill.chance, 3); // 持っているものは対象外
    expect(g.skillTips[Skill.chance], isNull);
    g.adminSetSkillTips(Skill.stealer, 0);
    expect(g.skillTips.containsKey(Skill.stealer), isFalse);
  });

  group('特殊能力', () {
    test('打者・投手で取れるものが分かれ、二刀流は両方', () {
      final bat = skillsFor(Role.batter).toSet();
      final pit = skillsFor(Role.pitcher).toSet();
      expect(bat, contains(Skill.chance));
      expect(bat, isNot(contains(Skill.strikeout)));
      expect(pit, contains(Skill.strikeout));
      expect(pit, isNot(contains(Skill.stealer)));
      expect(skillsFor(Role.twoWay).toSet(), {...bat, ...pit});
      // 2026-10-24「特殊能力の数を増やして」: 打者は基本17・金特6、投手は基本13・金特5(計41)
      expect(bat.where((s) => !s.gold).length, 17);
      expect(bat.where((s) => s.gold).length, 6);
      expect(pit.where((s) => !s.gold).length, 13);
      expect(pit.where((s) => s.gold).length, 5);
      expect(Skill.values.where((k) => !k.negative).length, 41);
      // 弱点(赤): 打者5・投手4
      expect(weaknessesFor(Role.batter).length, 5);
      expect(weaknessesFor(Role.pitcher).length, 4);
      // 金特は一覧の最後に並ぶ
      expect(skillsFor(Role.batter).skipWhile((s) => !s.gold).every((s) => s.gold),
          isTrue);
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
      // コツを1つもつかんでいなければ、経験点があっても取れない(何もしなくても取れてしまった)
      g.adminAddExp(200);
      expect(g.buySkill(Skill.powerHitter), contains('コツ'));
      g.skillTips[Skill.powerHitter] = 1;
      g.skillTips[Skill.artist] = 1;
      g.adminAddExp(-200);
      expect(g.buySkill(Skill.powerHitter), '経験点が足りない');
      g.adminAddExp(200);
      expect(g.buySkill(Skill.strikeout), 'この役割では取れない');
      expect(g.buySkill(Skill.artist), contains('パワーヒッター'));
      final before = g.exp.of(Category.batting);
      expect(g.buySkill(Skill.powerHitter), isNull);
      expect(g.player.skills, contains(Skill.powerHitter));
      // 6歳なので値段は半額(幼いほど安い)
      expect(g.exp.of(Category.batting), before - skillCost(Skill.powerHitter, 1, 6));
      expect(skillCost(Skill.powerHitter, 0, 6), 20);
      expect(g.buySkill(Skill.powerHitter), '取得済み');
      // もとを取ったので金特が取れる(値段は高い。金特は16歳から)
      g.player = g.player.copyWith(age: 16);
      g.adminAddExp(400);
      expect(g.buySkill(Skill.artist), isNull);
      expect(g.player.skills, contains(Skill.artist));
      expect(g.log.any((l) => l.contains('特殊能力「アーチスト」を取得')), isTrue);
    });

    test('コツが貯まっていれば、その分だけ安く取れる。取るとコツは消える', () {
      final g = _game();
      g.skillTips[Skill.chance] = 5;
      g.adminAddExp(15);
      expect(g.skillPrice(Skill.chance), skillCost(Skill.chance, 5, g.player.age));
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
      g.skillTips[Skill.stealer] = 1;
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

    test('研究は練習より経験点が少なく、練習はコツが貯まらない', () {
      int expOf(Plan p) {
        final g = _game(seed: 9);
        _act(g, p, Ability.contact);
        return g.lastGain.values.fold(0, (a, b) => a + b);
      }

      expect(expOf(Plan.study), lessThan(expOf(Plan.train) * 0.7));
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

  test('試合への影響の見込み: 上げる能力に結びつく数字だけが動き、大会向けは勝率で出る', () {
    final bat = Player(
        name: 't',
        role: Role.batter,
        age: 20,
        potential: 50,
        abilities: {for (final a in batterAbilities) a: 55});
    final pw = skillImpact(bat, Skill.powerHitter, Stage.pro).lines.join(' ');
    expect(pw, contains('本塁打 +'));
    expect(pw, isNot(contains('盗塁')));
    expect(skillImpact(bat, Skill.stealer, Stage.pro).lines.join(), contains('盗塁 +'));
    expect(skillImpact(bat, Skill.chance, Stage.pro).lines.join(), contains('大会の1試合の勝率 +1.2%'));
    final pit = Player(
        name: 't',
        role: Role.pitcher,
        age: 20,
        potential: 50,
        abilities: {for (final a in pitcherAbilities) a: 55});
    expect(skillImpact(pit, Skill.strikeout, Stage.pro).lines.join(' '), contains('奪三振 +'));
    // スタミナ+6 も投球回に効く(端数を確率で足すようにした)
    expect(skillImpact(pit, Skill.staminaPlus, Stage.pro).lines.join(' '), contains('投球回 +'));
    expect(effectText(Skill.wideAngle), '試合でミート+3・パワー+3');
    expect(effectText(Skill.gambler), '大会の勝負どころ+12');
  });

  group('年齢と弱点(2026-10-25)', () {
    test('値段は幼いほど安く、大人になるほど高い', () {
      final ages = [6, 12, 13, 15, 16, 18, 19, 24, 25, 29, 30, 40];
      final prices = [for (final a in ages) skillCost(Skill.powerHitter, 0, a)];
      for (var i = 1; i < prices.length; i++) {
        expect(prices[i], greaterThanOrEqualTo(prices[i - 1]), reason: '${ages[i]}歳');
      }
      expect(skillCost(Skill.powerHitter, 0, 10), 20); // 少年は半額
      expect(skillCost(Skill.powerHitter, 0, 20), 40); // 基準
      expect(skillCost(Skill.powerHitter, 0, 33), 60); // 30歳からは1.5倍
    });

    test('持つほど高くなる(1つごとに1.4倍、積み重なる)。弱点の克服は上がらない', () {
      expect(skillCost(Skill.chance, 0, 20, 0), 30);
      expect(skillCost(Skill.chance, 0, 20, 1), 42);
      expect(skillCost(Skill.chance, 0, 20, 2), 59);
      expect(skillCost(Skill.strikeoutProne, 0, 20, 5), 30);
    });

    test('金特は16歳(高校)から', () {
      final g = _game();
      g.player = g.player.copyWith(age: 12, skills: {Skill.averageHitter});
      g.skillTips[Skill.geniusBat] = 1;
      g.adminAddExp(2000);
      expect(g.buySkill(Skill.geniusBat), contains('16歳'));
      g.player = g.player.copyWith(age: 16);
      expect(g.buySkill(Skill.geniusBat), isNull);
    });

    test('生まれつきの弱点: 0〜2個、役割に合うもの。同じ種なら同じ。乱数の並びは変えない', () {
      var none = 0, two = 0;
      for (var s = 0; s < 400; s++) {
        final w = birthWeaknesses(Role.batter, s);
        expect(w.length, lessThanOrEqualTo(2));
        expect(w.every((k) => k.negative && k.appliesTo(Role.batter)), isTrue);
        expect(birthWeaknesses(Role.batter, s), w);
        if (w.isEmpty) none++;
        if (w.length == 2) two++;
      }
      expect(none / 400, closeTo(0.55, 0.08));
      expect(two / 400, closeTo(0.12, 0.05));
      for (final k in weaknessesFor(Role.pitcher)) {
        expect(k.appliesTo(Role.batter), isFalse, reason: k.name);
      }
    });

    test('弱点は試合で不利・総合評価も下がり、経験点で克服すると消える', () {
      final g = _game();
      g.player = g.player.copyWith(skills: {Skill.strikeoutProne, Skill.chanceBad});
      expect(traitAdjusted(g.player).of(Ability.contact), g.player.of(Ability.contact) - 3);
      expect(matchBonus(g.player), -6);
      expect(skillRating(g.player), lessThan(0));
      expect(effectText(Skill.strikeoutProne), '試合でミート-3');
      expect(effectText(Skill.chanceBad), '大会の勝負どころ-6');
      expect(g.buySkill(Skill.slowRunner), '持っていない');
      g.adminAddExp(100);
      final before = g.exp.of(Category.batting);
      expect(g.buySkill(Skill.strikeoutProne), isNull);
      expect(g.player.skills, isNot(contains(Skill.strikeoutProne)));
      expect(g.exp.of(Category.batting), before - skillCost(Skill.strikeoutProne, 0, g.player.age));
      expect(g.log.last, contains('克服'));
      // 弱点は取れる一覧・コツ・コーチの対象にならない
      expect(skillsFor(Role.batter).any((k) => k.negative), isFalse);
      // 克服の見込みは良くなる向き(+)で出る
      final imp = skillImpact(g.player, Skill.chanceBad, Stage.pro).lines.join();
      expect(imp, contains('勝率 +'));
    });
  });

  test('名前に、同梱フォントに無い記号(◯ U+25EF)を使わない(画面で□になる)', () {
    for (final s in Skill.values) {
      expect(s.label.contains('◯'), isFalse, reason: s.name);
      expect(s.description.contains('◯'), isFalse, reason: s.name);
    }
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
