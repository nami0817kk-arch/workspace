import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/skills.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('技能の点は格が上がるごとに1点。点が無いと上げられず、3段階まで', () {
    final c = careerAt(6, 12);
    expect(c.gmLevel, 1);
    expect(c.skillPoints, 0);
    expect(c.skillProblem(Skill.negotiation), isNotNull);
    c.learnSkill(Skill.negotiation);
    expect(c.skillOf(Skill.negotiation), 0);
    c.gmPoints = 100000; // 最高の格(技能の点が十分)
    expect(c.skillPoints, greaterThan(3));
    for (var i = 0; i < 5; i++) {
      c.learnSkill(Skill.negotiation);
    }
    expect(c.skillOf(Skill.negotiation), skillMax);
    expect(c.skillProblem(Skill.negotiation), isNotNull);
    expect(c.skillPoints, c.gmLevel - 1 - skillMax);
  });

  test('交渉は値切りに応じてもらいやすく(3段階で往復が1回増える)、人脈でトレードが通りやすい', () {
    final c = careerAt(6, 12);
    final p = c.me.roster.first..morale = 60;
    final base = c.discountChance(p, freeAgent: false);
    expect(c.haggleLimit, 3);
    c.gmPoints = 100000;
    c.learnSkill(Skill.negotiation);
    expect(c.discountChance(p, freeAgent: false), greaterThan(base));
    c.learnSkill(Skill.negotiation);
    c.learnSkill(Skill.negotiation);
    expect(c.haggleLimit, 4);
  });

  test('目利きでドラフトのスカウトが増え、技能は保存して読み直しても残る', () {
    final c = careerAt(6, 12);
    c.gmPoints = 100000;
    c.learnSkill(Skill.eye);
    c.learnSkill(Skill.eye);
    c.learnSkill(Skill.network);
    final back = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.skills, c.skills);
    expect(back.skillOf(Skill.eye), 2);
    botStep(c);
  });
}
