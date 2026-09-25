/// 自分が出る試合は、そのぶんクラブが強い（持ち上げ）。
/// 使われていない選手には、契約が残っていても話が来る。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_brief.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

Attributes _flat(int value) =>
    Attributes.fromDetails({for (final d in Detail.values) d: value});

Player _who(int value) => Player(
  name: 'P',
  age: 26,
  position: Position.cm,
  attributes: _flat(value),
  potential: 99,
);

Club _club(String id, int strength) =>
    Club(id: id, name: id, strength: strength, tier: 1, countryId: 'yamato');

CareerState _career({int seed = 3, int age = 20}) =>
    CareerEngine(random: Random(seed)).startCareer(
      name: 'T',
      position: Position.cm,
      age: age,
      agent: Agent.pool.first,
    );

void main() {
  group('持ち上げ', () {
    test('力の差に比例して、上限で止まる。下には落とさない', () {
      double lift(int overall, int strength) => MatchEngine.starLift(
        overall: overall,
        clubStrength: strength,
        appearance: Appearance.start,
      );
      expect(lift(45, 35), closeTo(10 * Formulas.starLift, 1e-9));
      expect(lift(99, 35), Formulas.starLiftCap);
      expect(lift(30, 35), Formulas.starLiftFloor);
      expect(lift(35, 35), 0);
    });

    test('途中出場は半分、出なければゼロ', () {
      double at(Appearance a) =>
          MatchEngine.starLift(overall: 55, clubStrength: 35, appearance: a);
      expect(at(Appearance.sub), at(Appearance.start) * Formulas.subLiftShare);
      expect(at(Appearance.benched), 0);
      expect(at(Appearance.injured), 0);
      expect(at(Appearance.suspended), 0);
    });

    test('強い選手が出る試合は、味方の得点の見込みが上がる', () {
      // 同じクラブ・同じ相手で、選手の総合力だけを変える。
      double expected(int overall) {
        final engine = MatchEngine(random: Random(1));
        final match = engine.start(
          matchday: 1,
          player: _who(overall),
          club: _club('home', 35),
          opponent: _club('away', 35),
          home: true,
          appearance: Appearance.start,
        );
        return match.expectedTeammateGoals;
      }

      expect(expected(70), greaterThan(expected(35)));
    });

    test('今日の意味に、持ち上げの行が出る（差が無ければ出ない）', () {
      final state = _career();
      // 開始時の選手は自分のクラブより上。
      expect(state.player.overall - state.club.strength, greaterThan(2));
      final lines = MatchBrief.of(state);
      final team = lines.where((l) => l.label == 'チーム');
      expect(team, isNotEmpty);
      expect(team.first.text, contains('${state.club.strength} →'));

      // 差が無ければ行ごと消える。
      state.club = Club(
        id: state.club.id,
        name: state.club.name,
        strength: state.player.overall + 5,
        tier: state.club.tier,
        countryId: state.club.countryId,
      );
      expect(MatchBrief.of(state).where((l) => l.label == 'チーム'), isEmpty);
    });
  });

  group('使われていない選手', () {
    test('登録外なら、契約が残っていても移籍の話が来る', () {
      final engine = CareerEngine(random: Random(9));
      final state = _career(age: 28);
      state.contractYears = 3;
      expect(engine.offersFor(state).where((o) => !o.loan), isEmpty);

      state.squadStatus = SquadStatus.outOfSquad;
      final offers = engine.offersFor(state);
      expect(offers.where((o) => !o.loan), isNotEmpty);
      // 28歳でもローンの話が来る（若手だけの制限が外れる）。
      expect(offers.where((o) => o.loan), isNotEmpty);
    });

    test('構想外も同じ', () {
      final engine = CareerEngine(random: Random(9));
      final state = _career(age: 30);
      state.contractYears = 2;
      state.relations = const Relations(manager: Formulas.frozenOutTrust - 1);
      expect(state.frozenOut, isTrue);
      expect(engine.offersFor(state).where((o) => !o.loan), isNotEmpty);
    });
  });

  group('在籍が長いほど、クラブを引き上げられる', () {
    // **移籍を全部断る遊び方は、20人中19人が無冠で終わっていた。**
    // 総合力74の選手が強さ38.6のクラブに居て、その国の首位は72.9
    // ——力の差 35 に傾き 0.5 を掛けても 17.4 で、構造的に届かない。
    // 1つのクラブを引き上げるのはキャリアものの筋のひとつなので、
    // 在籍が長いほど傾きが立つ形にした。
    int liftAt(int seasons) => MatchEngine.starLift(
      overall: 74,
      clubStrength: 40,
      appearance: Appearance.start,
      seasonsAtClub: seasons,
    ).round();

    test('年を重ねるほど持ち上げが大きくなり、どこかで止まる', () {
      expect(liftAt(1), lessThan(liftAt(4)));
      expect(liftAt(4), lessThan(liftAt(8)));
      // 止まらないと、居続けるだけで世界が壊れる。
      expect(liftAt(12), liftAt(20));
    });

    test('出ていない試合には効かない', () {
      expect(
        MatchEngine.starLift(
          overall: 74,
          clubStrength: 40,
          appearance: Appearance.benched,
          seasonsAtClub: 15,
        ),
        0,
      );
    });

    test('在籍年数は履歴から数える（保存に項目を足していない）', () async {
      final state = _career(age: 24);
      expect(CareerEngine.seasonsAtClub(state), 1);
      state.history.add(
        SeasonRecord(
          year: 2026,
          clubName: state.club.name,
          tier: state.club.tier,
          leaguePosition: 5,
          stats: const SeasonStats(
            appearances: 0,
            goals: 0,
            assists: 0,
            averageRating: 0,
          ),
          salary: 1000,
          caps: 0,
          objectiveMet: false,
          countryId: state.countryId,
        ),
      );
      expect(CareerEngine.seasonsAtClub(state), 2);
      state.history.add(
        SeasonRecord(
          year: 2027,
          clubName: 'よそのクラブ',
          tier: state.club.tier,
          leaguePosition: 5,
          stats: const SeasonStats(
            appearances: 0,
            goals: 0,
            assists: 0,
            averageRating: 0,
          ),
          salary: 1000,
          caps: 0,
          objectiveMet: false,
          countryId: state.countryId,
        ),
      );
      // 直近が別のクラブなら、そこで途切れる。
      expect(CareerEngine.seasonsAtClub(state), 1);
    });
  });
}
