import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/dependencies.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/physique.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';
import 'package:soccer_career/models/support.dart';
import 'package:soccer_career/models/training.dart';

final flat = Attributes(
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
  Attributes? attributes,
  Physique? physique,
  SetPieceSkills setPieces = const SetPieceSkills(),
  int condition = 100,
}) =>
    Player(
      name: 'P',
      age: age,
      position: position,
      attributes: attributes ?? flat,
      potential: potential,
      physique: physique ??
          const Physique(
              heightCm: Physique.baseHeight, weightKg: Physique.baseWeight),
      setPieces: setPieces,
      condition: condition,
    );

Club club(String id) =>
    Club(id: id, name: id, strength: 60, tier: 1, countryId: 'yamato');

void main() {
  group('身体データ', () {
    test('高い選手は競り合いに強く、細かい動きで劣る', () {
      const tall = Physique(heightCm: 194, weightKg: 88);
      expect(tall.bonusFor(Detail.heading), greaterThan(0));
      expect(tall.bonusFor(Detail.jumping), greaterThan(0));
      expect(tall.bonusFor(Detail.agility), lessThan(0));
      expect(tall.bonusFor(Detail.acceleration), lessThan(0));
    });

    test('小さく軽い選手はキレで勝る', () {
      const small = Physique(heightCm: 168, weightKg: 62);
      expect(small.bonusFor(Detail.agility), greaterThan(0));
      expect(small.bonusFor(Detail.acceleration), greaterThan(0));
      expect(small.bonusFor(Detail.heading), lessThan(0));
      expect(small.bonusFor(Detail.strength), lessThan(0));
    });

    test('補正は上限で頭打ちになる。身体だけで能力は決まらない', () {
      const extreme = Physique(heightCm: 210, weightKg: 110);
      for (final d in Detail.values) {
        expect(extreme.bonusFor(d).abs(), lessThanOrEqualTo(Physique.maxBonus));
      }
    });

    test('能力値そのものは書き換わらない', () {
      final p = player(physique: const Physique(heightCm: 195, weightKg: 90));
      expect(p.attributes.detail(Detail.heading), 50);
      expect(p.effective(Detail.heading), greaterThan(50));
    });

    test('ポジションなりの体格を引く', () {
      final random = Random(3);
      var keeperTotal = 0;
      var wingerTotal = 0;
      for (var i = 0; i < 40; i++) {
        keeperTotal += Physique.roll(random, Position.gk).heightCm;
        wingerTotal += Physique.roll(random, Position.wg).heightCm;
      }
      expect(keeperTotal, greaterThan(wingerTotal));
    });

    test('保存を往復しても残り、無い保存データは標準体型で読む', () {
      const p = Physique(
          heightCm: 183, weightKg: 79, foot: Foot.left, weakFoot: 4);
      final r = Physique.fromJson(p.toJson());
      expect(r.heightCm, 183);
      expect(r.weightKg, 79);
      expect(r.foot, Foot.left);
      expect(r.weakFoot, 4);

      final missing = Physique.fromJson(null);
      expect(missing.heightCm, Physique.baseHeight);
      expect(missing.bonusFor(Detail.heading), 0);
    });
  });

  group('能力の依存関係', () {
    test('土台から離れすぎた能力は伸びない', () {
      final lopsided = Attributes.fromDetails({
        for (final d in Detail.values) d: 40,
        Detail.sprintSpeed: 80,
      });
      expect(Dependencies.blocked(Detail.sprintSpeed, lopsided), isTrue);
      expect(Dependencies.blocked(Detail.strength, lopsided), isFalse);
    });

    test('頭打ちのときは、一番低い土台のほうが伸びる', () {
      final attrs = Attributes.fromDetails({
        for (final d in Detail.values) d: 40,
        Detail.sprintSpeed: 80,
        Detail.stamina: 30,
      });
      expect(Dependencies.resolve(Detail.sprintSpeed, attrs), Detail.stamina);
    });

    test('土台そのものは常に伸ばせる', () {
      expect(Dependencies.capFor(Detail.strength, flat), Formulas.maxAttribute);
      expect(Dependencies.resolve(Detail.strength, flat), Detail.strength);
    });

    test('練習でも土台を超えては積み上がらない', () {
      final engine = MatchEngine(random: Random(4));
      var attrs = Attributes.fromDetails({
        for (final d in Detail.values) d: 30,
        Detail.shortPassing: 30,
      });
      for (var i = 0; i < 400; i++) {
        final week = engine.applyWeek(player(attributes: attrs),
            menu: TrainingMenu.passingWork, played: false);
        attrs = week.attributes;
      }
      // 視野は「ショートパス + 余地」までしか伸びない。
      expect(
        attrs.detail(Detail.vision),
        lessThanOrEqualTo(
            attrs.detail(Detail.shortPassing) + Dependencies.headroom),
      );
    });
  });

  group('練習メニュー', () {
    test('複合メニューは2カテゴリに触れ、そのぶん疲れる', () {
      expect(TrainingMenu.athletic.isCompound, isTrue);
      expect(TrainingMenu.athletic.conditionCost,
          greaterThan(TrainingMenu.sprint.conditionCost));

      final engine = MatchEngine(random: Random(9));
      final touched = <AttributeKey>{};
      var attrs = flat;
      for (var i = 0; i < 300; i++) {
        final week = engine.applyWeek(player(attributes: attrs),
            menu: TrainingMenu.athletic, played: false);
        if (week.trained != null && !week.redirected) {
          touched.add(week.trained!.category);
        }
        attrs = week.attributes;
      }
      expect(touched, containsAll([AttributeKey.pace, AttributeKey.physical]));
    });

    test('GK専門は GK にしか出さない', () {
      expect(TrainingMenu.keeperWork.availableFor(Position.gk), isTrue);
      expect(TrainingMenu.keeperWork.availableFor(Position.st), isFalse);
    });

    test('カテゴリを持っていた頃の保存データを読める', () {
      final ce = CareerEngine(random: Random(21));
      final s = ce.startCareer(
          name: 'O', position: Position.cm, age: 20, agent: Agent.pool[1]);
      final json = s.toJson();
      json.remove('menu');
      json['training'] = AttributeKey.defending.name;
      expect(CareerState.fromJson(json).menu, TrainingMenu.defenceWork);
    });
  });

  group('居残りとセットプレー', () {
    test('居残りで精度が上がり、余分に疲れる', () {
      final engine = MatchEngine(random: Random(11));
      final week = engine.applyWeek(player(condition: 60),
          menu: TrainingMenu.rest, drill: SetPiece.freeKick, played: false);
      expect(week.condition,
          60 + TrainingMenu.rest.recovery - Formulas.drillConditionCost);

      var skills = const SetPieceSkills();
      for (var i = 0; i < 200; i++) {
        final w = engine.applyWeek(player(setPieces: skills),
            drill: SetPiece.freeKick, played: false);
        skills = w.setPieces;
      }
      expect(skills.freeKick, greaterThan(40));
      expect(skills.corner, 20);
    });

    test('キッカーを任される水準に届くまで、試合に出てこない', () {
      const novice = SetPieceSkills();
      expect(novice.isTaker, isFalse);
      const expert = SetPieceSkills(freeKick: 80);
      expect(expert.isTaker, isTrue);
      expect(expert.best, SetPiece.freeKick);
    });

    test('キッカーはセットプレーから得点が増える', () {
      int goalsOver(SetPieceSkills skills) {
        final engine = MatchEngine(random: Random(5));
        var goals = 0;
        for (var i = 0; i < 200; i++) {
          final match = engine.start(
            matchday: 1,
            player: player(setPieces: skills),
            club: club('a'),
            opponent: club('b'),
            home: true,
            appearance: Appearance.start,
          );
          match.autoPlay(SimStyle.safe);
          goals += match.finish().goals;
        }
        return goals;
      }

      expect(goalsOver(const SetPieceSkills(penalty: 95)),
          greaterThan(goalsOver(const SetPieceSkills())));
    });

    test('居残りの成果は保存を往復しても残る', () {
      final p = player(setPieces: const SetPieceSkills(freeKick: 70));
      final r = Player.fromJson(p.toJson());
      expect(r.setPieces.freeKick, 70);
      expect(Player.fromJson(p.toJson()..remove('setPieces')).setPieces.freeKick,
          20);
    });
  });

  group('専属スタッフと生活習慣', () {
    test('雇うほど練習が効き、怪我が減り、金がかかる', () {
      const none = StaffTeam();
      const full = StaffTeam(coach: 3, trainer: 3, nutritionist: 3);
      expect(full.growthFactor, greaterThan(none.growthFactor));
      expect(full.injuryFactor, lessThan(none.injuryFactor));
      expect(full.costPerSeason, greaterThan(0));
      expect(full.declineAgeOffset, greaterThan(0));
    });

    test('人件費は手取りから引かれる', () {
      const f = Finances(savings: 0);
      final plain = f.afterSeason(salary: 5000, agentFeePercent: 5);
      final withStaff =
          f.afterSeason(salary: 5000, agentFeePercent: 5, staffCost: 1500);
      expect(withStaff.savings, plain.savings - 1500);
    });

    test('貯蓄が足りなければ雇えない', () {
      final state = CareerEngine(random: Random(2)).startCareer(
          name: 'S', position: Position.st, age: 18, agent: Agent.pool.first);
      expect(state.finances.savings, 0);
      expect(state.staff.isEmpty, isTrue);
    });

    test('生活習慣は回復と怪我のしやすさを変える', () {
      const careless = Habits(sleep: 0, diet: 0);
      const strict = Habits(sleep: 2, diet: 2);
      expect(strict.recoveryBonus, greaterThan(careless.recoveryBonus));
      expect(strict.injuryFactor, lessThan(careless.injuryFactor));
      expect(strict.disciplined, isTrue);
      expect(careless.reckless, isTrue);

      final engine = MatchEngine(random: Random(6));
      final poor = engine.applyWeek(player(condition: 40),
          habits: careless, played: false);
      final good = engine.applyWeek(player(condition: 40),
          habits: strict, played: false);
      expect(good.condition, greaterThan(poor.condition));
    });

    test('こだわった食事は生活費が増える', () {
      const f = Finances(savings: 0);
      final plain = f.afterSeason(salary: 5000, agentFeePercent: 5);
      final fed = f.afterSeason(
          salary: 5000,
          agentFeePercent: 5,
          extraLivingRate: const Habits(diet: 2).livingCostExtra);
      expect(fed.savings, lessThan(plain.savings));
    });

    test('保存を往復しても残る', () {
      final ce = CareerEngine(random: Random(22));
      final s = ce.startCareer(
          name: 'O', position: Position.cb, age: 19, agent: Agent.pool[1]);
      s.staff = const StaffTeam(coach: 2, trainer: 1);
      s.habits = const Habits(sleep: 2, diet: 0);
      final r = CareerState.fromJson(s.toJson());
      expect(r.staff.coach, 2);
      expect(r.staff.trainer, 1);
      expect(r.habits.sleep, 2);
      expect(r.habits.diet, 0);

      final legacy = CareerState.fromJson(s.toJson()
        ..remove('staff')
        ..remove('habits'));
      expect(legacy.staff.isEmpty, isTrue);
      expect(legacy.habits.sleep, 1);
    });
  });

  group('オフの肉体改造', () {
    test('増量すれば重くなり、減量すれば軽くなる', () {
      const base = Physique(heightCm: 180, weightKg: 75);
      expect(base.afterOffseason(BodyPlan.bulk).weightKg, 78);
      expect(base.afterOffseason(BodyPlan.cut).weightKg, 72);
      expect(base.afterOffseason(BodyPlan.maintain).weightKg, 75);
    });

    test('増量は当たりに強く、キレが落ちる', () {
      final ce = CareerEngine(random: Random(31));
      final state = ce.startCareer(
          name: 'B', position: Position.st, age: 20, agent: Agent.pool.first);
      final before = state.player;
      final offer = TransferOffer(
        club: state.club,
        reason: '残留',
        salary: state.salary,
        role: '主力',
        years: 3,
        isRenewal: true,
      );
      final bulked = ce.advanceSeason(state, accepted: offer, bodyPlan: BodyPlan.bulk);
      expect(bulked.player.physique.weightKg,
          before.physique.weightKg + 3);
      expect(bulked.player.attributes.detail(Detail.strength),
          before.attributes.detail(Detail.strength) + 2);
      expect(bulked.player.effective(Detail.acceleration),
          lessThanOrEqualTo(before.effective(Detail.acceleration)));
    });
  });
}
