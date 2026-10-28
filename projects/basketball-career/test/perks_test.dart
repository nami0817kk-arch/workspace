import 'dart:math';

import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/mastery.dart';
import 'package:basketball_career/game/money.dart';
import 'package:basketball_career/game/perks.dart';
import 'package:basketball_career/game/player.dart';
import 'package:basketball_career/game/rival.dart';
import 'package:flutter_test/flutter_test.dart';

Game _game({Track track = Track.school, int age = 15, int cash = 0, int salary = 0}) => Game(
      eventsEnabled: false,
      player: Player(name: 'x', age: age, potential: 60, heightCm: 185, heightGenes: 0.5,
          abilities: {for (final a in Ability.values) a: 50}),
      rng: Random(4),
      track: track,
      cash: cash,
      salary: salary,
    );

void main() {
  test('頼みごとは条件を満たしたときだけ。使えない理由が分かる', () {
    final g = _game();
    g.coachBond = 20;
    g.teamwork = 40;
    expect(g.favorBlock(Favor.lesson), contains('コーチとの信頼'));
    expect(g.favorBlock(Favor.extra), contains('チームワーク'));
    expect(g.favorBlock(Favor.talk), isNull);
    expect(g.favorBlock(Favor.rival), contains('出会っていない'));
    expect(g.favorBlock(Favor.letter), contains('コーチとの信頼'));
    g.condition = g.condition.copyWith(morale: 90);
    expect(g.favorBlock(Favor.talk), contains('十分'));
  });

  test('個別指導: 信頼を使って熟練度と次のターンの伸びを得る。1ターンに1つまで、次のターンでまた頼める', () {
    final g = _game();
    g.coachBond = lessonBond + 5;
    g.teamwork = 80;
    final lines = g.useFavor(Favor.lesson, focus: Ability.pass);
    expect(lines.first, contains('パス'));
    expect(g.coachBond, lessonBond + 5 - lessonCost);
    expect(g.mastery[Ability.pass], 2);
    expect(g.nextGrowthBoost, lessonGrowth);
    expect(g.favorBlock(Favor.extra), contains('1ターンに1つ'));
    expect(() => g.useFavor(Favor.extra), throwsStateError);
    g.choose(Action.practice, Ability.pass);
    expect(g.nextGrowthBoost, 1.0, reason: '伸びの上乗せは1ターンで使い切る');
    expect(g.favorBlock(Favor.extra), isNull);
  });

  test('ライバルとの合同練習は1年に1回。ライバルも伸びる', () {
    final g = _game();
    g.rivalMet = true;
    final age = Rival.meetAge;
    g.player = g.player.copyWith(age: age);
    final before = g.rival.potential;
    g.useFavor(Favor.rival, focus: Ability.dribble);
    expect(g.mastery[Ability.dribble], 2);
    expect(g.rival.potential, before + 2);
    g.choose(Action.rest, Ability.dribble);
    expect(g.favorBlock(Favor.rival), contains('今年はもう'));
  });

  test('推薦状は進路の評価点を上げ、進路を選ぶと使い切る', () {
    final g = _game();
    g.coachBond = letterBond;
    final before = g.offerNow;
    g.useFavor(Favor.letter);
    expect(g.offerNow, closeTo(before + letterAchievement * 0.3, 1e-9));
    expect(g.favorBlock(Favor.letter), isNotNull);
    final pro = _game(track: Track.pro);
    pro.coachBond = 90;
    expect(pro.favorBlock(Favor.letter), contains('プロ'));
  });

  test('お金はプロの季節ごとに年俸の4分の1ずつ入り、足りないと使えない', () {
    final g = _game(track: Track.pro, age: 25, salary: 1000);
    expect(g.spendBlock(Spend.treat), contains('お金が足りない'));
    g.choose(Action.rest, Ability.pass);
    expect(g.cash, 250);
    final school = _game();
    school.choose(Action.rest, Ability.pass);
    expect(school.cash, 0, reason: 'プロでなければ入らない');
  });

  test('買い物: 使った分が減り、回数の決まりを守る', () {
    final g = _game(track: Track.pro, age: 25, cash: 20000);
    g.teamwork = 40;
    g.spend(Spend.treat);
    expect(g.teamwork, 55);
    expect(g.cash, 20000 - Spend.treat.price);
    expect(g.spendBlock(Spend.treat), contains('このターン'));
    g.spend(Spend.trainer);
    expect(g.trainerTerms, perkTerms);
    expect(g.spendBlock(Spend.trainer), contains('契約中'));
    g.spend(Spend.camp, focus: Ability.rebound);
    expect(g.mastery[Ability.rebound], 3);
    expect(g.spendBlock(Spend.camp), contains('今年'));
    g.spend(Spend.parents);
    expect(g.spendBlock(Spend.parents), contains('もう'));
    expect(g.spent, Spend.treat.price + Spend.trainer.price + Spend.camp.price + Spend.parents.price);
    g.choose(Action.rest, Ability.pass);
    expect(g.trainerTerms, perkTerms - 1);
    expect(g.spendBlock(Spend.treat), isNull, reason: '次のターンはまたおごれる');
  });

  test('熟練の段が上がれば、買い物でもごほうびが入る', () {
    final g = _game(track: Track.pro, age: 25, cash: 5000);
    g.mastery[Ability.pass] = masteryThresholds[0] - 1;
    final lines = g.spend(Spend.camp, focus: Ability.pass);
    expect(g.masteryOf(Ability.pass), 1);
    expect(lines.any((l) => l.startsWith('熟練アップ!')), isTrue);
  });

  test('コートを寄付すると、スポンサー契約の人気が上がる', () {
    int s(bool charity) => sponsorOf(
        overall: 70, honorsLastYear: 0, champion: false, star: false,
        draftPick: 0, caps: 0, abroad: false, charity: charity);
    expect(s(true), s(false) + 900);
  });

  test('保存して読み直しても残る。古いセーブ・壊れた値でも落ちない', () {
    final g = _game(track: Track.pro, age: 25, cash: 20000);
    g.spend(Spend.nutrition);
    g.spend(Spend.court);
    final back = Game.fromJson(g.toJson());
    expect(back.cash, g.cash);
    expect(back.spent, g.spent);
    expect(back.nutritionTerms, perkTerms);
    expect(back.usedEver, containsAll(['nutrition', 'court']));
    expect(back.spendBlock(Spend.court), contains('もう'));
    final j = g.toJson();
    for (final k in ['cash', 'spent', 'usedTerm', 'usedYear', 'usedEver', 'trainerTerms',
        'nutritionTerms', 'nextGrowthBoost', 'recommendBonus']) {
      j.remove(k);
    }
    final old = Game.fromJson(j);
    expect(old.cash, 0);
    expect(old.usedEver, isEmpty);
    final bad = Game.fromJson(g.toJson()..['usedEver'] = 'こわれた');
    expect(bad.usedEver, isEmpty);
  });
}
