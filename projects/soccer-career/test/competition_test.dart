import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/competitions.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/nationality.dart';
import 'package:soccer_career/models/season.dart';

CareerState career({int seed = 1, String countryId = 'yamato'}) =>
    CareerEngine(random: Random(seed)).startCareer(
      name: 'C',
      position: Position.st,
      age: 20,
      agent: Agent.pool.first,
      countryId: countryId,
    );

MatchResult played({int matchday = 1}) => MatchResult(
      matchday: matchday,
      opponentName: 'X',
      home: true,
      scored: 1,
      conceded: 0,
      appearance: Appearance.start,
      rating: 7.0,
      goals: 0,
      assists: 0,
    );

/// 自分のクラブを指定順位に置いた状態を作る。
void placeAt(CareerState state, int position) {
  final rows = state.table;
  for (var i = 0; i < rows.length; i++) {
    rows[i].won = rows.length - i;
  }
  final mine = rows.firstWhere((r) => r.clubId == state.club.id);
  // 目的の順位になるよう勝点を調整する。
  mine.won = rows.length - (position - 1);
  var rank = 1;
  for (final row in rows) {
    if (row.clubId == mine.clubId) continue;
    if (rank == position) rank++;
    row.won = rows.length - (rank - 1);
    rank++;
  }
}

void main() {
  group('登録メンバーの線が、届く範囲にある', () {
    test('オファーで来る強さの差の範囲に、線が入っている', () {
      // 線を -18 に置いていた頃、この制度は**一度も起きなかった**。
      // オファーはクラブの強さが「総合力 -14」までしか来ないので、
      // 加入した時点の差は -14 より下にならず、その後も基本は縮む。
      // 実測でキャリア中の最悪が -11、下位1割が -8 だった。
      expect(Formulas.squadRegistrationGap, greaterThan(-14),
          reason: 'オファーの範囲より下だと、制度が死ぬ');
      expect(Formulas.squadRegistrationGap, lessThan(0),
          reason: '格上のクラブに移れなくなる');
    });

    test('大きく劣ると登録外、見合っていれば登録される', () {
      final state = career();
      final competitions = Competitions(random: Random(1));

      // クラブの強さぴったりなら入れる。
      state.player = state.player.copyWith(
        attributes: Attributes.fromDetails({
          for (final d in Detail.values) d: state.club.strength,
        }),
      );
      expect(competitions.registrationFor(state), SquadStatus.registered);

      // 線を割ると外れる。
      state.player = state.player.copyWith(
        attributes: Attributes.fromDetails({
          for (final d in Detail.values)
            d: state.club.strength + Formulas.squadRegistrationGap - 6,
        }),
      );
      expect(competitions.registrationFor(state), SquadStatus.outOfSquad);
    });
  });

  group('大陸カップ', () {
    test('出場していなければ不出場のまま', () {
      final c = Competitions(random: Random(1));
      final s = career();
      expect(c.runContinental(s, qualified: false), ContinentalStage.none);
    });

    test('出場すれば必ずどこかの段階に達する', () {
      final c = Competitions(random: Random(2));
      final s = career();
      for (var i = 0; i < 20; i++) {
        final stage = c.runContinental(s, qualified: true);
        expect(stage.participated, isTrue);
      }
    });

    test('強いクラブほど勝ち上がる', () {
      int totalPoints(int strength) {
        final c = Competitions(random: Random(3));
        final s = career();
        s.club = Club(
            id: 'x', name: 'X', strength: strength, tier: 1, countryId: 'yamato');
        var sum = 0;
        for (var i = 0; i < 60; i++) {
          sum += c.runContinental(s, qualified: true).points;
        }
        return sum;
      }

      expect(totalPoints(88), greaterThan(totalPoints(50)));
    });

    test('上位に入れば出場圏、下位なら圏外', () {
      final engine = CareerEngine(random: Random(4));
      final s = career(countryId: 'albion');
      s.club = World.buildLeague('albion', 1).first;
      s.league = World.buildLeague('albion', 1);
      s.table = [
        for (final c in s.league) TableRow(clubId: c.id, clubName: c.name)
      ];
      placeAt(s, 1);
      expect(engine.inContinental(s), isTrue);
      placeAt(s, 12);
      expect(engine.inContinental(s), isFalse);
    });

    test('2部にいる限り大陸カップには出られない', () {
      final engine = CareerEngine(random: Random(5));
      final s = career(countryId: 'yamato');
      expect(s.club.tier, 2);
      placeAt(s, 1);
      expect(engine.inContinental(s), isFalse);
    });

    test('成績は記録に残り、保存を往復しても消えない', () {
      final s = career(seed: 6);
      s.continentalStage = ContinentalStage.semi;
      final r = CareerState.fromJson(s.toJson());
      expect(r.continentalStage, ContinentalStage.semi);
    });

    test('大陸カップに出た経験は労働許可の材料になる', () {
      final engine = CareerEngine(random: Random(7));
      final s = career(seed: 7, countryId: 'albion');
      s.club = World.buildLeague('albion', 1).first;
      s.league = World.buildLeague('albion', 1);
      s.table = [
        for (final c in s.league) TableRow(clubId: c.id, clubName: c.name)
      ];
      placeAt(s, 1);
      expect(s.continentalExperience, isFalse);
      engine.resolveSeasonEnd(s);
      expect(s.continentalStage.participated, isTrue);
      expect(s.continentalExperience, isTrue);
    });

    test('優勝ほど国の格への貢献が大きい', () {
      final c = Competitions(random: Random(8));
      expect(c.coefficientGain(ContinentalStage.winner),
          greaterThan(c.coefficientGain(ContinentalStage.semi)));
      expect(c.coefficientGain(ContinentalStage.group), 0);
    });
  });

  group('昇格プレーオフ', () {
    test('3〜6位がプレーオフの対象', () {
      final engine = CareerEngine(random: Random(9));
      final s = career(countryId: 'yamato');
      placeAt(s, 2);
      expect(engine.inPromotionPlayoff(s), isFalse, reason: '2位は自動昇格');
      placeAt(s, 3);
      expect(engine.inPromotionPlayoff(s), isTrue);
      placeAt(s, 6);
      expect(engine.inPromotionPlayoff(s), isTrue);
      placeAt(s, 7);
      expect(engine.inPromotionPlayoff(s), isFalse);
    });

    test('1部にいるときはプレーオフが無い', () {
      final engine = CareerEngine(random: Random(10));
      final s = career(countryId: 'yamato');
      s.club = World.buildLeague('yamato', 1).first;
      s.league = World.buildLeague('yamato', 1);
      s.table = [
        for (final c in s.league) TableRow(clubId: c.id, clubName: c.name)
      ];
      placeAt(s, 4);
      expect(engine.inPromotionPlayoff(s), isFalse);
    });

    test('順位が上ほど勝ち上がりやすい', () {
      int wins(int position) {
        var n = 0;
        for (var seed = 0; seed < 300; seed++) {
          if (Competitions(random: Random(seed))
              .winsPromotionPlayoff(position)) {
            n++;
          }
        }
        return n;
      }

      expect(wins(3), greaterThan(wins(6)));
      expect(wins(6), greaterThan(0), reason: '6位でも可能性は残す');
    });
  });

  group('移籍市場の窓', () {
    final c = Competitions(random: Random(11));

    test('シーズンが終われば夏の窓', () {
      final s = career();
      for (var i = 0; i < s.fixtures.length; i++) {
        s.results.add(played(matchday: i + 1));
      }
      expect(s.seasonFinished, isTrue);
      expect(c.windowAt(s), TransferWindow.summer);
    });

    test('序盤は閉じている', () {
      final s = career();
      expect(c.windowAt(s), TransferWindow.closed);
    });

    test('シーズン半ばに冬の窓が開く', () {
      final s = career();
      final winter = (s.fixtures.length * 0.45).round();
      for (var i = 0; i < winter - 1; i++) {
        s.results.add(played(matchday: i + 1));
      }
      expect(s.matchday, winter);
      expect(c.windowAt(s), TransferWindow.winter);
    });

    test('冬は夏より条件が悪い', () {
      expect(TransferWindow.winter.strength,
          lessThan(TransferWindow.summer.strength));
      expect(TransferWindow.closed.isOpen, isFalse);
      expect(TransferWindow.summer.isOpen, isTrue);
    });
  });

  group('登録メンバー', () {
    final c = Competitions(random: Random(12));

    test('自国の主力は登録される', () {
      final s = career(countryId: 'yamato');
      s.player = s.player.copyWith(
        attributes: Attributes(
            pace: 70, shooting: 70, passing: 70, dribbling: 70,
            defending: 70, physical: 70),
      );
      expect(c.registrationFor(s), SquadStatus.registered);
    });

    test('クラブに対して力が足りないと登録外', () {
      final s = career(countryId: 'yamato');
      s.club = Club(
          id: 'x', name: 'X', strength: 90, tier: 1, countryId: 'yamato');
      s.player = s.player.copyWith(
        attributes: Attributes(
            pace: 40, shooting: 40, passing: 40, dribbling: 40,
            defending: 40, physical: 40),
      );
      expect(c.registrationFor(s), SquadStatus.outOfSquad);
    });

    test('外国人枠が埋まっているクラブでは登録外になる', () {
      final s = career(countryId: 'yamato');
      // スペインは登録枠3。強豪クラブは埋まっている。
      final club = World.buildLeague('iberica', 1).first;
      s.club = club;
      s.player = s.player.copyWith(
        nationality: const Nationality(primary: 'serena'),
        attributes: Attributes(
            pace: 80, shooting: 80, passing: 80, dribbling: 80,
            defending: 80, physical: 80),
      );
      final country = World.byId('iberica');
      expect(country.foreignRule.squadLimit, 3);
      // ブラジルは南米。スペインでは外国人。
      expect(c.registrationFor(s), SquadStatus.outOfSquad);
    });

    test('登録外だと試合に出られない扱いになる', () {
      final s = career();
      s.squadStatus = SquadStatus.outOfSquad;
      expect(s.squadStatus.canPlay, isFalse);
      expect(SquadStatus.registered.canPlay, isTrue);
    });

    test('登録状況は保存を往復しても残る', () {
      final s = career(seed: 13);
      s.squadStatus = SquadStatus.outOfSquad;
      expect(CareerState.fromJson(s.toJson()).squadStatus,
          SquadStatus.outOfSquad);
    });

    test('登録の項目が無い保存データは登録済みとして読む', () {
      final s = career(seed: 14);
      final json = s.toJson();
      json.remove('squadStatus');
      json.remove('continentalStage');
      final r = CareerState.fromJson(json);
      expect(r.squadStatus, SquadStatus.registered);
      expect(r.continentalStage, ContinentalStage.none);
    });
  });

  group('大陸カップと年俸', () {
    test('出場したシーズンは契約更改の年俸が上がる', () {
      int salary({required bool continental}) {
        final engine = CareerEngine(random: Random(15));
        final s = career(seed: 15);
        for (var i = 0; i < 20; i++) {
          s.results.add(played(matchday: i + 1));
        }
        if (continental) s.continentalStage = ContinentalStage.quarter;
        // 契約が残っているうちは条件が動かない。更改の年で見る。
        s.contractYears = 1;
        return engine.renewalOffer(s).salary;
      }

      expect(salary(continental: true), greaterThan(salary(continental: false)));
      expect(Formulas.continentalSalaryBonus, greaterThan(1.0));
    });
  });
}
