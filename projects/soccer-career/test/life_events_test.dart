import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/competitions.dart';
import 'package:soccer_career/game/life_events.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/personality.dart';
import 'package:soccer_career/models/life.dart';
import 'package:soccer_career/models/life_event.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

CareerState career({int seed = 3, int age = 20}) =>
    CareerEngine(random: Random(seed)).startCareer(
        name: 'T', position: Position.cm, age: age, agent: Agent.pool.first);

void fillSeason(CareerState state, {double rating = 7.2, int matches = 20}) {
  for (var i = 0; i < matches; i++) {
    state.results.add(MatchResult(
      matchday: i + 1,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: rating,
      goals: 1,
      assists: 0,
    ));
  }
}

LifeContext context({
  int age = 25,
  int fame = 40,
  int savings = 0,
  bool abroad = false,
  bool afterInjury = false,
  bool sponsorOffered = false,
  bool captaincyOffered = false,
  bool lowMorale = false,
}) =>
    LifeContext(
      age: age,
      fame: fame,
      savings: savings,
      abroad: abroad,
      afterInjury: afterInjury,
      sponsorOffered: sponsorOffered,
      captaincyOffered: captaincyOffered,
      lowMorale: lowMorale,
    );

void main() {
  group('気持ちと疲労', () {
    test('気持ちは成功率と練習の効きに小さく効く', () {
      const low = Morale(value: 10);
      const high = Morale(value: 95);
      expect(high.chanceModifier, greaterThan(low.chanceModifier));
      expect(high.chanceModifier.abs(), lessThan(0.05));
      expect(high.growthFactor, greaterThan(low.growthFactor));
      expect(low.needsCare, isTrue);
      expect(high.needsCare, isFalse);
    });

    test('疲労は溜まる一方で、オフで抜ける', () {
      var f = const Fatigue();
      for (var i = 0; i < 20; i++) {
        f = f.add(3);
      }
      expect(f.value, 60);
      expect(f.injuryFactor, greaterThan(1.0));
      expect(f.recoveryFactor, lessThan(1.0));

      // 若いほうがよく抜ける。
      expect(f.afterOffseason(22).value, lessThan(f.afterOffseason(33).value));
      expect(f.afterOffseason(22).value, 0);
    });
  });

  group('好不調の波', () {
    test('良い試合が続くとゾーンに入ることがある', () {
      var sawZone = false;
      for (var seed = 0; seed < 40 && !sawZone; seed++) {
        final form = Form.roll(Random(seed), recent: [7.8, 7.5, 7.9]);
        sawZone = form.state == FormState.zone;
      }
      expect(sawZone, isTrue);
    });

    test('悪い試合が続くとスランプに落ちることがある', () {
      var sawSlump = false;
      for (var seed = 0; seed < 40 && !sawSlump; seed++) {
        final form = Form.roll(Random(seed), recent: [5.4, 5.6, 5.5]);
        sawSlump = form.state == FormState.slump;
      }
      expect(sawSlump, isTrue);
    });

    test('試合数が足りないうちは波に入らない', () {
      expect(Form.roll(Random(1), recent: [8.0, 8.0]).isActive, isFalse);
    });

    test('波は試合ごとに明ける', () {
      var form = const Form(state: FormState.zone, matches: 2);
      expect(form.chanceModifier, greaterThan(0));
      form = form.tick();
      expect(form.isActive, isTrue);
      form = form.tick();
      expect(form.isActive, isFalse);
      expect(form.chanceModifier, 0);
    });
  });

  group('ピッチ外の出来事', () {
    test('条件を満たさない出来事は選ばれない', () {
      final events = LifeEvents(random: Random(1));
      // 無名で貧しい若手には、有名税も財団の話も来ない。
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        final e = events.pick(context(age: 19, fame: 5, savings: 0));
        if (e != null) ids.add(e.id);
      }
      expect(ids, isNot(contains('fame')));
      expect(ids, isNot(contains('charity')));
      expect(ids, isNot(contains('chant')));
    });

    test('国外に居るときだけ適応の話が来る', () {
      final events = LifeEvents(random: Random(2));
      final home = <String>{};
      for (var i = 0; i < 100; i++) {
        final e = events.pick(context(abroad: false));
        if (e != null) home.add(e.id);
      }
      expect(home, isNot(contains('abroad')));

      var sawAbroad = false;
      for (var i = 0; i < 200 && !sawAbroad; i++) {
        sawAbroad = events.pick(context(abroad: true))?.id == 'abroad';
      }
      expect(sawAbroad, isTrue);
    });

    test('一度きりの出来事は繰り返さない', () {
      final events = LifeEvents(random: Random(3));
      for (var i = 0; i < 100; i++) {
        final e = events.pick(context(age: 26, fame: 60, savings: 50000),
            seen: {'charity'});
        expect(e?.id, isNot('charity'));
      }
    });

    test('どの選択肢にも必ず結果の一文がある', () {
      for (final event in LifeEvents.catalogue) {
        expect(event.choices, isNotEmpty);
        for (final choice in event.choices) {
          expect(choice.label, isNotEmpty);
          expect(choice.outcome, isNotEmpty);
        }
      }
    });

    test('効きはすべて小さく、1回で人生が決まらない', () {
      for (final event in LifeEvents.catalogue) {
        for (final choice in event.choices) {
          expect(choice.effect.morale.abs(), lessThanOrEqualTo(20));
          expect(choice.effect.fame.abs(), lessThanOrEqualTo(10));
          expect(choice.effect.manager.abs(), lessThanOrEqualTo(10));
          expect(choice.effect.teammates.abs(), lessThanOrEqualTo(10));
          expect(choice.effect.confidence.abs(), lessThanOrEqualTo(1));
          expect(choice.effect.temper.abs(), lessThanOrEqualTo(1));
        }
      }
    });
  });

  group('スポンサー', () {
    test('無名の選手には話が来ない', () {
      expect(Sponsor.offerFor(fame: 10, random: Random(1)), isNull);
      expect(Sponsor.offerFor(fame: 70, random: Random(1)), isNotNull);
    });

    test('知名度が高いほど条件が良い', () {
      final small = Sponsor.offerFor(fame: 40, random: Random(1))!;
      final big = Sponsor.offerFor(fame: 90, random: Random(1))!;
      expect(big.annual, greaterThan(small.annual));
    });

    test('契約は年々減っていき、切れる', () {
      var sponsor = const Sponsor(name: 'X', annual: 500, years: 1);
      sponsor = sponsor.aged();
      expect(sponsor.expired, isTrue);
    });
  });

  group('キャプテン', () {
    test('信頼と立場の両方が要る', () {
      final engine = CareerEngine(random: Random(4));
      final state = career(age: 26);
      state.relations = const Relations(manager: 90, teammates: 90);
      expect(engine.offersCaptaincy(state), isTrue);

      state.relations = const Relations(manager: 90, teammates: 30);
      expect(engine.offersCaptaincy(state), isFalse);

      final young = career(age: 20);
      young.relations = const Relations(manager: 90, teammates: 90);
      expect(engine.offersCaptaincy(young), isFalse);
    });

    test('移籍すれば腕章は外れる', () {
      final engine = CareerEngine(random: Random(6));
      final state = career(age: 26);
      fillSeason(state);
      state.captain = true;

      final moved = engine.advanceSeason(
        state,
        accepted: TransferOffer(
          club: state.league.first,
          reason: 'x',
          salary: state.salary,
          role: '主力',
          years: 3,
        ),
      );
      expect(moved.captain, isFalse);
    });
  });

  group('キャリアの段階と背番号', () {
    test('年齢で見え方が変わる', () {
      expect(CareerStage.of(17), CareerStage.youth);
      expect(CareerStage.of(21), CareerStage.prospect);
      expect(CareerStage.of(28), CareerStage.peak);
      expect(CareerStage.of(36), CareerStage.twilight);
    });

    test('背番号はポジションらしいものが付く', () {
      final number = CareerEngine.squadNumberFor(Position.st, Random(1),
          senior: true);
      expect(number, 9);
      expect(CareerEngine.squadNumberFor(Position.gk, Random(1), senior: true),
          1);
    });

    test('育成年代から始めると一番下の部から', () {
      final youth = career(age: 16);
      // 国によって部の数が違うので、一番下かどうかで見る。
      expect(youth.club.tier, World.byId(youth.countryId).tiers);
      expect(youth.stage, CareerStage.youth);
    });
  });

  group('引退後', () {
    test('やってきたことが次の道の見立てになる', () {
      final engine = CareerEngine(random: Random(9));
      final rich = career(age: 30);
      rich.finances = const Finances(savings: 50000);
      rich.player = rich.player.copyWith(
        personality: const Personality(
            confidence: 10, ambition: 18, professionalism: 10, temper: 10),
      );
      expect(engine.secondCareerFor(rich), SecondCareer.entrepreneur);

      final famous = career(age: 33);
      famous.reputation = const Reputation(fame: 80);
      expect(engine.secondCareerFor(famous), SecondCareer.pundit);
    });

    test('引退しても人生の側は記録に残る', () {
      final engine = CareerEngine(random: Random(11));
      final state = career(age: 36);
      fillSeason(state);
      state.captain = true;
      state.charity = true;
      state.nickname = '司令塔';

      final retired = engine.retire(state);
      expect(retired.retired, isTrue);
      expect(retired.captain, isTrue);
      expect(retired.charity, isTrue);
      expect(retired.nickname, '司令塔');
      expect(retired.secondCareer, isNotNull);
    });
  });

  group('代表の選択', () {
    test('複数の国籍があれば、選んだ国で戦う', () {
      final state = career();
      final other = state.player.nationality.primary == 'yamato'
          ? 'albion'
          : 'yamato';
      state.player = state.player.copyWith(
          nationality: state.player.nationality.naturalize(other));
      expect(state.nationalTeam, state.player.nationality.primary);

      state.nationalTeamId = other;
      expect(state.nationalTeam, other);

      // 選んだ国でワールドカップを戦う。
      final competitions = Competitions(random: Random(2));
      expect(competitions.runWorldCup(state, calledUp: true).participated,
          isTrue);
    });
  });

  test('人生の側は保存を往復しても残り、無い保存データも読める', () {
    final state = career();
    state.morale = const Morale(value: 88);
    state.fatigue = const Fatigue(value: 33);
    state.form = const Form(state: FormState.zone, matches: 2);
    state.preseason = PreseasonPlan.tour;
    state.captain = true;
    state.squadNumber = 10;
    state.nickname = '司令塔';
    state.sponsor = const Sponsor(name: 'アストレア', annual: 800, years: 2);
    state.charity = true;
    state.seenEvents = ['charity', 'chant'];

    final r = CareerState.fromJson(state.toJson());
    expect(r.morale.value, 88);
    expect(r.fatigue.value, 33);
    expect(r.form.state, FormState.zone);
    expect(r.preseason, PreseasonPlan.tour);
    expect(r.captain, isTrue);
    expect(r.squadNumber, 10);
    expect(r.nickname, '司令塔');
    expect(r.sponsor!.annual, 800);
    expect(r.charity, isTrue);
    expect(r.seenEvents, ['charity', 'chant']);

    final legacy = CareerState.fromJson(state.toJson()
      ..remove('morale')
      ..remove('fatigue')
      ..remove('form')
      ..remove('preseason')
      ..remove('captain')
      ..remove('squadNumber')
      ..remove('nickname')
      ..remove('sponsor')
      ..remove('charity')
      ..remove('seenEvents'));
    expect(legacy.morale.value, 60);
    expect(legacy.fatigue.value, 0);
    expect(legacy.form.isActive, isFalse);
    expect(legacy.captain, isFalse);
    expect(legacy.seenEvents, isEmpty);
  });
}
