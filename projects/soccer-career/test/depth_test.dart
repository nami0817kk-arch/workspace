import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/names.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/traits.dart';

final flat50 = Attributes(
  pace: 50,
  shooting: 50,
  passing: 50,
  dribbling: 50,
  defending: 50,
  physical: 50,
  goalkeeping: 50,
);

Player player({
  Position position = Position.cm,
  int age = 20,
  int potential = 99,
  List<Trait> traits = const [],
  int condition = 100,
  Attributes? attributes,
}) =>
    Player(
      name: 'P',
      age: age,
      position: position,
      attributes: attributes ?? flat50,
      potential: potential,
      traits: traits,
      condition: condition,
    );

MatchResult played(double rating) => MatchResult(
      matchday: 1,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: rating,
      goals: 0,
      assists: 0,
    );

void main() {
  group('ポジション', () {
    test('8つ選べる', () {
      expect(Position.values.length, 8);
    });

    test('3ポジション時代の保存データを読める', () {
      expect(Position.parse('fw'), Position.st);
      expect(Position.parse('mf'), Position.cm);
      expect(Position.parse('df'), Position.cb);
      expect(Position.parse('gk'), Position.gk);
    });

    test('GK は GK 能力で総合力が決まる', () {
      final keeper = Attributes(
          pace: 40, shooting: 20, passing: 40, dribbling: 30,
          defending: 50, physical: 50, goalkeeping: 90);
      expect(keeper.overallFor(Position.gk), greaterThan(keeper.overallFor(Position.st)));
    });

    test('GK 能力が無い保存データは既定値で読む', () {
      final a = Attributes.fromJson({
        'pace': 50, 'shooting': 50, 'passing': 50,
        'dribbling': 50, 'defending': 50, 'physical': 50,
      });
      expect(a.goalkeeping, Formulas.defaultGoalkeeping);
    });

    test('GK には専用の局面が7つある', () {
      expect(ScenarioPool.forPosition(Position.gk).length, greaterThanOrEqualTo(7));
      expect(ScenarioPool.forPosition(Position.gk).every((s) => s.id.startsWith('gk-')), isTrue);
    });

    test('細かいポジションはファミリーの局面を使う', () {
      expect(ScenarioPool.forPosition(Position.sb), ScenarioPool.defence);
      expect(ScenarioPool.forPosition(Position.am), ScenarioPool.midfield);
      expect(ScenarioPool.forPosition(Position.wg), ScenarioPool.forward);
    });
  });

  group('特性', () {
    test('2つ引き、矛盾する組み合わせは出ない', () {
      for (var seed = 0; seed < 200; seed++) {
        final traits = Trait.roll(Random(seed), flawChance: 0);
        expect(traits.length, 2);
        expect(Trait.compatible(traits[0], traits[1]), isTrue, reason: 'seed $seed');
      }
    });

    test('クラッチは終盤だけ効く', () {
      double bonus(int minute) => Trait.clutch.chanceBonus(TraitContext(
          minute: minute, home: true, outcome: Outcome.play, afterFailure: false,
          afterSuccess: false, key: AttributeKey.passing, detail: null,
          scenarioId: 'x', international: false));
      expect(bonus(30), 0);
      expect(bonus(80), greaterThan(0));
    });

    test('負けず嫌いは失敗直後だけ効く', () {
      double bonus(bool after) => Trait.fighter.chanceBonus(TraitContext(
          minute: 10, home: true, outcome: Outcome.play, afterFailure: after,
          afterSuccess: false, key: AttributeKey.passing, detail: null,
          scenarioId: 'x', international: false));
      expect(bonus(false), 0);
      expect(bonus(true), greaterThan(0));
    });

    test('勝負師と職人は逆向き', () {
      double g(Outcome o) => Trait.gambler.chanceBonus(TraitContext(
          minute: 10, home: true, outcome: o, afterFailure: false,
          afterSuccess: false, key: AttributeKey.passing, detail: null,
          scenarioId: 'x', international: false));
      double c(Outcome o) => Trait.craftsman.chanceBonus(TraitContext(
          minute: 10, home: true, outcome: o, afterFailure: false,
          afterSuccess: false, key: AttributeKey.passing, detail: null,
          scenarioId: 'x', international: false));
      expect(g(Outcome.goal), greaterThan(0));
      expect(g(Outcome.play), lessThan(0));
      expect(c(Outcome.play), greaterThan(0));
      expect(c(Outcome.goal), lessThan(0));
    });

    test('特性は表示される成功率と判定の両方に効く', () {
      final league = Names.buildLeague(2);
      MatchInProgress start(List<Trait> traits) => MatchEngine(random: Random(1)).start(
            matchday: 1,
            player: player(position: Position.st, traits: traits),
            club: league.first,
            opponent: league.last,
            home: true,
            appearance: Appearance.start,
          );
      final plain = start(const []);
      final hero = start(const [Trait.homeHero]);
      // 同じ seed なので同じ局面が出る。
      final option = plain.current.options.first;
      expect(hero.chanceFor(option), greaterThan(plain.chanceFor(option)));
    });

    test('鉄人は衰え始めが遅い', () {
      expect(const [Trait.ironman].declineAgeOffset, 2);
      expect(const <Trait>[].declineAgeOffset, 0);
    });
  });

  group('ポテンシャル', () {
    test('必ず今の総合力より上で、範囲内に収まる', () {
      final engine = CareerEngine(random: Random(2));
      for (var i = 0; i < 100; i++) {
        final p = engine.rollPotential(55);
        expect(p, greaterThan(55));
        expect(p, inInclusiveRange(Formulas.potentialMin, Formulas.potentialMax));
      }
    });

    test('ポテンシャルに達したら試合で伸びない', () {
      final engine = MatchEngine(random: Random(3));
      final capped = player(potential: 50); // 総合力 50 で頭打ち
      var attrs = capped.attributes;
      for (var i = 0; i < 100; i++) {
        attrs = engine.grow(capped.copyWith(attributes: attrs), 9.0);
      }
      expect(attrs.overallFor(Position.cm), 50);
    });

    test('新規キャリアの選手にはポテンシャルと特性が付く', () {
      final s = CareerEngine(random: Random(4)).startCareer(
        name: 'N', position: Position.wg, age: 17, agent: Agent.pool.first);
      expect(s.player.potential, greaterThan(s.player.overall));
      expect(s.player.traits.length, 2);
    });

    test('帯の表示は数値を出さない', () {
      final p = player(potential: 90);
      expect(p.potentialBand, isNot(contains('90')));
    });
  });

  group('練習とコンディション', () {
    final engine = MatchEngine(random: Random(5));

    test('休養で戻り、練習で減る', () {
      final base = player(condition: 50);
      final rested = engine.applyWeek(base, training: null, played: false);
      expect(rested.condition, 50 + Formulas.restRecovery);

      final trained = engine.applyWeek(base, training: AttributeKey.passing, played: false);
      expect(trained.condition, 50 - Formulas.trainingConditionCost);
    });

    test('試合に出た週はその分も減り、0〜100 に収まる', () {
      final low = engine.applyWeek(player(condition: 5), training: AttributeKey.pace, played: true);
      expect(low.condition, 0);
      final high = engine.applyWeek(player(condition: 95), training: null, played: false);
      expect(high.condition, Formulas.conditionMax);
    });

    test('練習は指定した能力だけを伸ばす', () {
      var attrs = flat50;
      var grew = 0;
      for (var i = 0; i < 200; i++) {
        final week = engine.applyWeek(player(attributes: attrs), training: AttributeKey.shooting, played: false);
        if (week.trained != null) {
          grew++;
          expect(week.trained!.category, AttributeKey.shooting);
        }
        attrs = week.attributes;
      }
      expect(grew, greaterThan(0));
      // 伸びるのはシュートの詳細のどれか。他のカテゴリは動かない。
      final shootingTotal = AttributeKey.shooting.details
          .fold(0, (sum, d) => sum + attrs.detail(d));
      expect(shootingTotal, greaterThan(50 * AttributeKey.shooting.details.length));
      expect(attrs.pace, 50);
    });

    test('ポテンシャルに達していれば練習でも伸びない', () {
      final capped = player(potential: 50);
      for (var i = 0; i < 100; i++) {
        final week = engine.applyWeek(capped, training: AttributeKey.passing, played: false);
        expect(week.trained, isNull);
      }
    });

    test('コンディションが低いと成功率が下がる', () {
      expect(MatchInProgress.conditionModifier(100), greaterThan(0));
      expect(MatchInProgress.conditionModifier(Formulas.conditionBaseline), 0);
      expect(MatchInProgress.conditionModifier(10), lessThan(0));
    });

    test('新しいシーズンはコンディションが戻る', () {
      final ce = CareerEngine(random: Random(6));
      final s = ce.startCareer(name: 'C', position: Position.cb, age: 18, agent: Agent.pool.first);
      s.player = s.player.copyWith(condition: 20);
      final next = ce.advanceSeason(s, accepted: ce.renewalOffer(s));
      expect(next.player.condition, Formulas.conditionMax);
    });
  });

  group('代理人と契約', () {
    test('候補は3人で重複しない', () {
      final c = Agent.candidates(Random(7));
      expect(c.length, 3);
      expect(c.map((a) => a.name).toSet().length, 3);
    });

    test('名前で復元でき、知らない名前は先頭に倒す', () {
      expect(Agent.fromJson({'name': Agent.pool[2].name}), Agent.pool[2]);
      expect(Agent.fromJson({'name': '存在しない'}), Agent.pool.first);
      expect(Agent.fromJson(null), Agent.pool.first);
    });

    test('年俸は総合力とリーグで上がる', () {
      expect(CareerEngine.salaryFor(overall: 70, tier: 1),
          greaterThan(CareerEngine.salaryFor(overall: 60, tier: 1)));
      expect(CareerEngine.salaryFor(overall: 70, tier: 1),
          greaterThan(CareerEngine.salaryFor(overall: 70, tier: 2)));
      expect(CareerEngine.salaryFor(overall: 30, tier: 2), greaterThan(0));
    });

    test('契約更改は常に提示され、好成績なら上がる', () {
      final ce = CareerEngine(random: Random(8));
      final s = ce.startCareer(name: 'R', position: Position.st, age: 20, agent: Agent.pool.first);
      final poor = ce.renewalOffer(s);
      expect(poor.isRenewal, isTrue);

      for (var i = 0; i < 12; i++) {
        s.results.add(played(8.5));
      }
      final good = ce.renewalOffer(s);
      expect(good.salary, greaterThan(poor.salary));
    });

    test('上乗せ要求: 交渉力が高く好成績なら通る', () {
      final ce = CareerEngine(random: Random(9));
      final strong = Agent.pool.firstWhere((a) => a.negotiation == 5);
      final s = ce.startCareer(name: 'N', position: Position.st, age: 20, agent: strong);
      for (var i = 0; i < 12; i++) {
        s.results.add(played(8.5));
      }
      final offer = ce.renewalOffer(s);
      var raised = 0;
      for (var i = 0; i < 50; i++) {
        final (result, _) = ce.negotiate(s, offer);
        if (result == NegotiationResult.raised) raised++;
      }
      expect(raised, greaterThan(30));
    });

    test('上乗せに成功すると年俸が倍率分だけ上がり、二度目は要求できない', () {
      final ce = CareerEngine(random: Random(10));
      final strong = Agent.pool.firstWhere((a) => a.negotiation == 5);
      final s = ce.startCareer(name: 'N', position: Position.st, age: 20, agent: strong);
      for (var i = 0; i < 12; i++) {
        s.results.add(played(9.0));
      }
      final offer = ce.renewalOffer(s);
      TransferOffer? after;
      for (var i = 0; i < 20 && after == null; i++) {
        final (result, o) = ce.negotiate(s, offer);
        if (result == NegotiationResult.raised) after = o;
      }
      expect(after, isNotNull);
      expect(after!.salary, greaterThanOrEqualTo((offer.salary * Formulas.negotiationRaise).floor() - 10));
      expect(after.negotiated, isTrue);
      final (again, same) = ce.negotiate(s, after);
      expect(again, NegotiationResult.refused);
      expect(same!.salary, after.salary);
    });

    test('契約更改は失敗しても撤回されない', () {
      final ce = CareerEngine(random: Random(11));
      final weak = Agent.pool.firstWhere((a) => a.negotiation == 2);
      final s = ce.startCareer(name: 'W', position: Position.cb, age: 20, agent: weak);
      final offer = ce.renewalOffer(s);
      for (var i = 0; i < 50; i++) {
        final (result, o) = ce.negotiate(s, offer);
        expect(result, isNot(NegotiationResult.withdrawn));
        expect(o, isNotNull);
      }
    });

    test('移籍オファーは失敗すると撤回されることがある', () {
      final ce = CareerEngine(random: Random(12));
      final weak = Agent.pool.firstWhere((a) => a.negotiation == 2);
      final s = ce.startCareer(name: 'W', position: Position.st, age: 20, agent: weak);
      final offer = TransferOffer(
        club: Names.buildLeague(2).first,
        reason: '',
        salary: 500,
        role: '主力',
        years: 3);
      var withdrawn = 0;
      for (var i = 0; i < 100; i++) {
        final (result, _) = ce.negotiate(s, offer);
        if (result == NegotiationResult.withdrawn) withdrawn++;
      }
      expect(withdrawn, greaterThan(0));
    });

    test('人脈が広い代理人は、より強いクラブを引いてくる', () {
      CareerState build(Agent agent) {
        final ce = CareerEngine(random: Random(13));
        final s = ce.startCareer(name: 'A', position: Position.st, age: 22, agent: agent);
        s.contractYears = 1;
        for (var i = 0; i < 12; i++) {
          s.results.add(played(8.0));
        }
        return s;
      }
      final narrow = Agent.pool.firstWhere((a) => a.reach == 1);
      final wide = Agent.pool.firstWhere((a) => a.reach == 8);
      final ce = CareerEngine(random: Random(13));
      int best(CareerState s) =>
          ce.offersFor(s).map((o) => o.club.strength).fold(0, max);
      expect(best(build(wide)), greaterThanOrEqualTo(best(build(narrow))));
    });

    test('受けたオファーの年俸で次のシーズンが始まり、記録に残る', () {
      final ce = CareerEngine(random: Random(14));
      final s = ce.startCareer(name: 'S', position: Position.cm, age: 20, agent: Agent.pool.first);
      final before = s.salary;
      final next = ce.advanceSeason(
        s,
        accepted: TransferOffer(
            club: s.club, reason: '', salary: 1234, role: '主力', years: 3),
      );
      expect(next.salary, 1234);
      expect(next.history.last.salary, before);
      expect(next.totalEarnings, before);
    });

    test('手取りは手数料分だけ減る', () {
      final ce = CareerEngine(random: Random(15));
      final agent = Agent.pool.firstWhere((a) => a.feePercent == 10);
      final s = ce.startCareer(name: 'T', position: Position.cm, age: 20, agent: agent);
      expect(ce.takeHome(s, 1000), 900);
    });
  });

  group('保存の互換性', () {
    test('代理人・年俸・練習・ポテンシャルが無い保存データを読める', () {
      final ce = CareerEngine(random: Random(16));
      final s = ce.startCareer(name: 'O', position: Position.cm, age: 20, agent: Agent.pool[1]);
      final json = s.toJson();
      json.remove('agent');
      json.remove('salary');
      json.remove('training');
      json.remove('contractYears');
      json.remove('objective');
      json.remove('injury');
      json.remove('caps');
      json.remove('internationalGoals');
      (json['player'] as Map<String, dynamic>)
        ..remove('potential')
        ..remove('traits')
        ..remove('condition');
      (json['player'] as Map<String, dynamic>)['position'] = 'mf';

      final restored = CareerState.fromJson(json);
      expect(restored.agent, Agent.pool.first);
      expect(restored.salary, greaterThan(0));
      expect(restored.training, isNull);
      expect(restored.player.position, Position.cm);
      expect(restored.player.potential, greaterThan(restored.player.overall));
      expect(restored.player.traits, isEmpty);
      expect(restored.player.condition, Formulas.conditionMax);
      expect(restored.contractYears, greaterThan(0));
      expect(restored.objective, isNull);
      expect(restored.injury, isNull);
      expect(restored.caps, 0);
    });

    test('新しい項目は往復しても保たれる', () {
      final ce = CareerEngine(random: Random(17));
      final s = ce.startCareer(name: 'O', position: Position.gk, age: 19, agent: Agent.pool[2]);
      s.training = AttributeKey.goalkeeping;
      s.player = s.player.copyWith(condition: 42);
      final r = CareerState.fromJson(s.toJson());
      expect(r.agent, Agent.pool[2]);
      expect(r.salary, s.salary);
      expect(r.training, AttributeKey.goalkeeping);
      expect(r.player.potential, s.player.potential);
      expect(r.player.traits, s.player.traits);
      expect(r.player.condition, 42);
      expect(r.player.position, Position.gk);
      expect(r.player.attributes.goalkeeping, s.player.attributes.goalkeeping);
    });
  });
}
