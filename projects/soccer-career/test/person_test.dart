import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

CareerState career({int seed = 1, String countryId = 'yamato', int age = 22}) =>
    CareerEngine(random: Random(seed)).startCareer(
      name: 'P',
      position: Position.st,
      age: age,
      agent: Agent.pool.first,
      countryId: countryId,
    );

MatchResult played(double rating, {int goals = 0, int matchday = 1}) =>
    MatchResult(
      matchday: matchday,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: rating,
      goals: goals,
      assists: 0,
    );

void fillSeason(CareerState s, double rating, {int goals = 0, int count = 20}) {
  for (var i = 0; i < count; i++) {
    s.results.add(played(rating, goals: goals, matchday: i + 1));
  }
}

void main() {
  group('性格', () {
    test('4軸を持ち、範囲に収まる', () {
      for (var seed = 0; seed < 100; seed++) {
        final p = Personality.roll(Random(seed));
        for (final axis in PersonalityAxis.values) {
          expect(p[axis], inInclusiveRange(Personality.min, Personality.max));
        }
      }
    });

    test('bump は指定した軸だけ動かし、上下限で丸める', () {
      const p = Personality(
          confidence: 10, ambition: 10, professionalism: 10, temper: 10);
      final up = p.bump(PersonalityAxis.confidence, 3);
      expect(up.confidence, 13);
      expect(up.ambition, 10);

      const high = Personality(
          confidence: 20, ambition: 1, professionalism: 10, temper: 10);
      expect(high.bump(PersonalityAxis.confidence, 5).confidence, 20);
      expect(high.bump(PersonalityAxis.ambition, -5).ambition, 1);
    });

    test('自信は成功率に小さく効く', () {
      const low = Personality(
          confidence: 1, ambition: 10, professionalism: 10, temper: 10);
      const high = Personality(
          confidence: 20, ambition: 10, professionalism: 10, temper: 10);
      expect(high.chanceModifier, greaterThan(low.chanceModifier));
      // 効きすぎない。能力を伸ばす意味が消えない範囲に。
      expect(high.chanceModifier.abs(), lessThan(0.05));
      expect(low.chanceModifier.abs(), lessThan(0.05));
    });

    test('プロ意識は練習の効果と衰えの遅さに効く', () {
      const lazy = Personality(
          confidence: 10, ambition: 10, professionalism: 3, temper: 10);
      const pro = Personality(
          confidence: 10, ambition: 10, professionalism: 18, temper: 10);
      expect(pro.trainingFactor, greaterThan(lazy.trainingFactor));
      expect(pro.declineAgeOffset, greaterThan(lazy.declineAgeOffset));
    });

    test('気性は交渉の通りやすさに効く', () {
      const calm = Personality(
          confidence: 10, ambition: 10, professionalism: 10, temper: 3);
      const fiery = Personality(
          confidence: 10, ambition: 10, professionalism: 10, temper: 18);
      expect(fiery.negotiationModifier, greaterThan(calm.negotiationModifier));
    });

    test('一番高い軸で呼び名が決まる', () {
      const ambitious = Personality(
          confidence: 8, ambition: 18, professionalism: 8, temper: 8);
      expect(ambitious.label, '野心家');
      const flat = Personality(
          confidence: 10, ambition: 10, professionalism: 10, temper: 10);
      expect(flat.label, 'つかみどころがない');
    });

    test('保存を往復でき、無ければ平均で読む', () {
      const p = Personality(
          confidence: 15, ambition: 5, professionalism: 12, temper: 8);
      final r = Personality.fromJson(p.toJson());
      expect(r.confidence, 15);
      expect(r.temper, 8);
      expect(Personality.fromJson(null).confidence, 10);
    });

    test('自信は試合の成功率に反映される', () {
      final engine = CareerEngine(random: Random(2));
      final base = engine.startCareer(
          name: 'A', position: Position.st, age: 22, agent: Agent.pool.first,
          countryId: 'yamato');
      final confident = base.player.copyWith(
        personality: const Personality(
            confidence: 20, ambition: 10, professionalism: 10, temper: 10),
      );
      final timid = base.player.copyWith(
        personality: const Personality(
            confidence: 1, ambition: 10, professionalism: 10, temper: 10),
      );
      final m1 = MatchEngine(random: Random(3)).start(
        matchday: 1, player: confident, club: base.club,
        opponent: base.league.first, home: true, appearance: Appearance.start);
      final m2 = MatchEngine(random: Random(3)).start(
        matchday: 1, player: timid, club: base.club,
        opponent: base.league.first, home: true, appearance: Appearance.start);
      final option = m1.current.options.first;
      expect(m1.chanceFor(option), greaterThan(m2.chanceFor(option)));
    });

    test('経験で性格が変わる', () {
      final person = Person(random: Random(4));
      final s = career(seed: 4);
      fillSeason(s, 7.5);
      final grown = person.evolve(s);
      expect(grown.confidence, greaterThan(s.player.personality.confidence));

      final benched = career(seed: 5);
      benched.results.add(played(6.0));
      final shrunk = Person(random: Random(5)).evolve(benched);
      expect(shrunk.confidence, lessThan(benched.player.personality.confidence));
    });
  });

  group('市場価値と評判', () {
    final person = Person(random: Random(6));

    test('実力が高いほど価値も高い', () {
      int value(int overall) {
        final s = career(seed: 6);
        s.player = s.player.copyWith(
          attributes: Attributes(
              pace: overall, shooting: overall, passing: overall,
              dribbling: overall, defending: overall, physical: overall),
        );
        return person.marketValueFor(s);
      }

      expect(value(80), greaterThan(value(60)));
    });

    test('若いほど価値が高く、30を過ぎると落ちる', () {
      int value(int age) {
        final s = career(seed: 7, age: 22);
        s.player = s.player.copyWith(age: age);
        return person.marketValueFor(s);
      }

      expect(value(21), greaterThan(value(29)));
      expect(value(29), greaterThan(value(34)));
    });

    test('格の高いリーグにいるほど価値が高い', () {
      int value(String countryId) {
        final s = career(seed: 8, countryId: countryId);
        return person.marketValueFor(s);
      }

      expect(value('albion'), greaterThan(value('norden')));
    });

    test('契約が短いと価値が下がる', () {
      final s = career(seed: 9);
      s.contractYears = 4;
      final long = person.marketValueFor(s);
      s.contractYears = 1;
      expect(person.marketValueFor(s), lessThan(long));
    });

    test('活躍すると知名度が上がり、何もしないと落ちる', () {
      final active = career(seed: 10);
      fillSeason(active, 7.5, goals: 1);
      active.caps = 0;
      expect(person.fameFor(active),
          greaterThan(active.reputation.fame));

      final idle = career(seed: 11);
      idle.reputation = const Reputation(fame: 50);
      idle.club = idle.league.last;
      expect(person.fameFor(idle), lessThan(50));
    });

    test('節目で称号を得る', () {
      final s = career(seed: 12);
      fillSeason(s, 7.0, goals: 1, count: 25);
      final awards = person.awardsFor(s, promoted: false);
      expect(awards, contains(Award.debut));
      expect(awards, contains(Award.firstGoal));
      expect(awards, contains(Award.topScorer));
    });

    test('昇格と大陸カップ優勝も称号になる', () {
      final s = career(seed: 13);
      fillSeason(s, 7.0);
      s.continentalStage = ContinentalStage.winner;
      final awards = person.awardsFor(s, promoted: true);
      expect(awards, contains(Award.promotion));
      expect(awards, contains(Award.continentalTitle));
    });

    test('同じ称号は二重に付かない', () {
      var r = const Reputation();
      r = r.earn(Award.debut);
      r = r.earn(Award.debut);
      expect(r.awards.where((a) => a == Award.debut).length, 1);
    });

    test('保存を往復でき、無ければ既定で読む', () {
      const r = Reputation(
          marketValue: 5000, fame: 42, awards: [Award.debut, Award.topScorer]);
      final back = Reputation.fromJson(r.toJson());
      expect(back.marketValue, 5000);
      expect(back.fame, 42);
      expect(back.awards, [Award.debut, Award.topScorer]);
      expect(Reputation.fromJson(null).marketValue, 300);
    });
  });

  group('監督とチームメイトの関係', () {
    test('好成績と目標達成で信頼が上がる', () {
      final person = Person(random: Random(14));
      final s = career(seed: 14);
      fillSeason(s, 7.6);
      final after = person.updateRelations(s);
      expect(after.manager, greaterThan(s.relations.manager));
    });

    test('出場ゼロだと信頼が落ちる', () {
      final person = Person(random: Random(15));
      final s = career(seed: 15);
      final after = person.updateRelations(s);
      expect(after.manager, lessThan(s.relations.manager));
    });

    test('気性が荒いと信頼が伸びにくい', () {
      int manager(int temper) {
        final person = Person(random: Random(16));
        final s = career(seed: 16);
        s.player = s.player.copyWith(
          personality: Personality(
              confidence: 10, ambition: 10, professionalism: 10, temper: temper),
        );
        fillSeason(s, 7.2);
        return person.updateRelations(s).manager;
      }

      expect(manager(18), lessThan(manager(8)));
    });

    test('信頼が出場機会に効く', () {
      const trusted = Relations(manager: 90);
      const outcast = Relations(manager: 10);
      expect(Person.appearanceBonusFrom(trusted), greaterThan(0));
      expect(Person.appearanceBonusFrom(outcast), lessThan(0));

      // 同じ評価点でも、信頼の有無で出場の仕方が変わりうる。
      final recent = [for (var i = 0; i < 5; i++) played(6.1)];
      expect(
        MatchEngine.decideAppearance(recent,
            bonus: Person.appearanceBonusFrom(trusted)),
        Appearance.start,
      );
      expect(
        MatchEngine.decideAppearance(recent,
            bonus: Person.appearanceBonusFrom(outcast)),
        Appearance.sub,
      );
    });

    test('信頼の言い換えが範囲で変わる', () {
      expect(const Relations(manager: 90).managerLabel, '厚い信頼');
      expect(const Relations(manager: 10).managerLabel, '構想外');
      expect(const Relations(teammates: 90).teammatesLabel, '中心人物');
    });

    test('保存を往復でき、無ければ中庸で読む', () {
      const r = Relations(manager: 72, teammates: 33);
      final back = Relations.fromJson(r.toJson());
      expect(back.manager, 72);
      expect(back.teammates, 33);
      expect(Relations.fromJson(null).manager, 50);
    });
  });

  group('お金', () {
    test('年俸が高いほど税率が上がる', () {
      expect(Finances.taxRateFor(30000),
          greaterThan(Finances.taxRateFor(1000)));
    });

    test('手取りが貯蓄に積み上がる', () {
      const f = Finances();
      final after = f.afterSeason(salary: 10000, agentFeePercent: 10);
      expect(after.savings, greaterThan(0));
      expect(after.savings, lessThan(10000), reason: '税と手数料が引かれていない');
    });

    test('生活水準が高いほど残らない', () {
      const modest = Finances(lifestyle: 0);
      const lavish = Finances(lifestyle: 3);
      final a = modest.afterSeason(salary: 10000, agentFeePercent: 10);
      final b = lavish.afterSeason(salary: 10000, agentFeePercent: 10);
      expect(a.savings, greaterThan(b.savings));
    });

    test('手数料の高い代理人ほど手取りが減る', () {
      const f = Finances();
      final cheap = f.afterSeason(salary: 10000, agentFeePercent: 3);
      final pricey = f.afterSeason(salary: 10000, agentFeePercent: 12);
      expect(cheap.savings, greaterThan(pricey.savings));
    });

    test('保存を往復でき、無ければ既定で読む', () {
      const f = Finances(savings: 12345, lifestyle: 2);
      final back = Finances.fromJson(f.toJson());
      expect(back.savings, 12345);
      expect(back.lifestyle, 2);
      expect(Finances.fromJson(null).savings, 0);
    });
  });

  group('シーズンを跨いだ更新', () {
    test('称号・知名度・市場価値・貯蓄・関係がまとめて更新される', () {
      final engine = CareerEngine(random: Random(17));
      final s = career(seed: 17);
      fillSeason(s, 7.4, goals: 1, count: 22);

      final next = engine.advanceSeason(s, accepted: engine.renewalOffer(s));
      expect(next.reputation.awards, contains(Award.debut));
      expect(next.reputation.marketValue, isNot(s.reputation.marketValue));
      expect(next.finances.savings, greaterThan(0));
      // 監督が代わった年は信頼が白紙に戻る。どちらかが動いていればよい。
      final managerChanged = next.manager!.name != s.manager!.name;
      expect(managerChanged || next.relations.manager != s.relations.manager,
          isTrue);
      // 性格も動く。
      expect(next.player.personality.confidence,
          greaterThanOrEqualTo(s.player.personality.confidence));
    });

    test('新規キャリアには性格が付く', () {
      final s = career(seed: 18);
      final p = s.player.personality;
      final allTen = PersonalityAxis.values.every((a) => p[a] == 10);
      expect(allTen, isFalse, reason: '性格が引かれていない');
    });

    test('人物まわりの項目が無い保存データも読める', () {
      final s = career(seed: 19);
      final json = s.toJson();
      json.remove('reputation');
      json.remove('relations');
      json.remove('finances');
      (json['player'] as Map<String, dynamic>).remove('personality');

      final r = CareerState.fromJson(json);
      expect(r.reputation.marketValue, 300);
      expect(r.relations.manager, 50);
      expect(r.finances.savings, 0);
      expect(r.player.personality.confidence, 10);
    });

    test('保存を往復しても人物が残る', () {
      final s = career(seed: 20);
      s.reputation = const Reputation(
          marketValue: 9000, fame: 60, awards: [Award.seasonBest]);
      s.relations = const Relations(manager: 80, teammates: 40);
      s.finances = const Finances(savings: 5000, lifestyle: 2);

      final r = CareerState.fromJson(s.toJson());
      expect(r.reputation.marketValue, 9000);
      expect(r.reputation.awards, [Award.seasonBest]);
      expect(r.relations.manager, 80);
      expect(r.finances.savings, 5000);
      expect(r.player.personality.confidence,
          s.player.personality.confidence);
    });
  });
}
