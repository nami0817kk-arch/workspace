import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/eligibility.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/country.dart';
import 'package:soccer_career/models/nationality.dart';
import 'package:soccer_career/models/season.dart';

CareerState career({int seed = 1, String? countryId}) =>
    CareerEngine(random: Random(seed)).startCareer(
      name: 'W',
      position: Position.st,
      age: 19,
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

void main() {
  group('世界の構成', () {
    test('11の国が3連盟に分かれている', () {
      expect(World.countries.length, 11);
      for (final c in Confederation.values) {
        expect(World.inConfederation(c), isNotEmpty, reason: c.label);
      }
    });

    test('国のIDは重複しない', () {
      final ids = World.countries.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('リーグのクラブ数は国ごとに違い、試合数もそれに従う', () {
      final sizes = World.countries.map((c) => c.clubsInTier(1)).toSet();
      expect(sizes.length, greaterThan(1), reason: '全部同じクラブ数になっている');
      final yamato = World.byId('yamato');
      expect(yamato.matchesInTier(1), (yamato.clubsInTier(1) - 1) * 2);
      final norden = World.byId('norden');
      expect(norden.matchesInTier(1), 30);
    });

    test('クラブ名は国ごとに重複せず、命名の型に沿う', () {
      for (final country in World.countries) {
        for (var tier = 1; tier <= country.tiers; tier++) {
          final league = World.buildLeague(country.id, tier);
          expect(league.length, country.clubsInTier(tier), reason: country.name);
          final names = league.map((c) => c.name).toSet();
          expect(names.length, league.length,
              reason: '${country.name} $tier部で名前が重複');
          for (final club in league) {
            expect(club.countryId, country.id);
            expect(club.tier, tier);
          }
        }
      }
    });

    test('同じ国の1部と2部でクラブ名が被らない', () {
      for (final country in World.countries.where((c) => c.tiers >= 2)) {
        final first =
            World.buildLeague(country.id, 1).map((c) => c.name).toSet();
        final second =
            World.buildLeague(country.id, 2).map((c) => c.name).toSet();
        expect(first.intersection(second), isEmpty, reason: country.name);
      }
    });

    test('格が高い国ほどクラブが強い', () {
      double average(String id) {
        final league = World.buildLeague(id, 1);
        return league.fold<int>(0, (s, c) => s + c.strength) / league.length;
      }

      expect(average('albion'), greaterThan(average('norden')));
    });

    test('上位の部ほど強い', () {
      double average(String id, int tier) {
        final league = World.buildLeague(id, tier);
        return league.fold<int>(0, (s, c) => s + c.strength) / league.length;
      }

      expect(average('yamato', 1), greaterThan(average('yamato', 2)));
    });

    test('格が高い国ほど大陸カップの枠が多い', () {
      expect(World.byId('albion').continentalSlots,
          greaterThan(World.byId('norden').continentalSlots));
    });
  });

  group('国籍と外国人扱い', () {
    const yamatoPlayer = Nationality(primary: 'yamato');
    const albionPlayer = Nationality(primary: 'albion');
    const germaniaPlayer = Nationality(primary: 'germania');

    test('自国では外国人にならない', () {
      expect(
          Eligibility.isForeignIn(yamatoPlayer, World.byId('yamato')), isFalse);
    });

    test('連盟内自由の国では、同じ連盟の選手は外国人にならない', () {
      // ドイツは連盟内自由。イングランドも同じ欧州。
      expect(Eligibility.isForeignIn(albionPlayer, World.byId('germania')),
          isFalse);
      // 日本はアジア。ドイツでは外国人。
      expect(Eligibility.isForeignIn(yamatoPlayer, World.byId('germania')),
          isTrue);
    });

    test('連盟内自由でない国では、同じ連盟でも外国人', () {
      // イングランドは連盟内自由ではない。
      expect(Eligibility.isForeignIn(germaniaPlayer, World.byId('albion')),
          isTrue);
    });

    test('提携国の選手は外国人枠の外に置かれる', () {
      // 日本はサウジアラビアとアルゼンチンを提携国にしている。
      const pampa = Nationality(primary: 'pampa');
      expect(Eligibility.isForeignIn(pampa, World.byId('yamato')), isFalse);
      const serena = Nationality(primary: 'serena');
      expect(Eligibility.isForeignIn(serena, World.byId('yamato')), isTrue);
    });

    test('ルーツの国籍でも自国民として扱われる', () {
      const dual = Nationality(primary: 'pampa', roots: 'iberica');
      expect(Eligibility.isForeignIn(dual, World.byId('iberica')), isFalse);
    });

    test('帰化すると外国人ではなくなる', () {
      const before = Nationality(primary: 'pampa');
      expect(Eligibility.isForeignIn(before, World.byId('albion')), isTrue);
      final after = before.naturalize('albion');
      expect(Eligibility.isForeignIn(after, World.byId('albion')), isFalse);
      expect(after.all, contains('albion'));
    });

    test('国籍は保存を往復しても残る', () {
      const n = Nationality(
        primary: 'pampa',
        roots: 'iberica',
        naturalized: ['albion'],
        homegrownCountryId: 'pampa',
        homegrownClubName: 'CA ロサ',
      );
      final r = Nationality.fromJson(n.toJson(), 'yamato');
      expect(r.primary, 'pampa');
      expect(r.roots, 'iberica');
      expect(r.naturalized, ['albion']);
      expect(r.homegrownCountryId, 'pampa');
      expect(r.homegrownClubName, 'CA ロサ');
    });

    test('国籍を持たない保存データは既定の国で読む', () {
      final r = Nationality.fromJson(null, 'yamato');
      expect(r.primary, 'yamato');
      expect(r.all, ['yamato']);
    });
  });

  group('労働許可', () {
    const young = Nationality(primary: 'pampa');

    PermitCheck check({
      required String destination,
      required String origin,
      int caps = 0,
      int years = 1,
      int value = 300,
      bool continental = false,
    }) =>
        Eligibility.checkPermit(
          nationality: young,
          destination: World.byId(destination),
          origin: World.byId(origin),
          caps: caps,
          professionalYears: years,
          marketValue: value,
          continentalExperience: continental,
        );

    test('許可の要らない国では常に通る', () {
      final c = check(destination: 'germania', origin: 'pampa');
      expect(c.required, isFalse);
      expect(c.granted, isTrue);
    });

    test('無名の若手はイングランドに入れない', () {
      final c = check(destination: 'albion', origin: 'pampa');
      expect(c.required, isTrue);
      expect(c.granted, isFalse);
      expect(c.points, lessThan(c.needed));
    });

    test('代表と実績を積めば許可が下りる', () {
      final c = check(
        destination: 'albion',
        origin: 'pampa',
        caps: 20,
        years: 5,
        value: 12000,
        continental: true,
      );
      expect(c.granted, isTrue);
      expect(c.reasons, isNotEmpty);
    });

    test('格の低いリーグからは加点されない', () {
      final low = check(destination: 'albion', origin: 'norden', caps: 20, years: 5);
      final high = check(destination: 'albion', origin: 'pampa', caps: 20, years: 5);
      expect(high.points, greaterThan(low.points));
    });

    test('その国の国籍を持っていれば許可は要らない', () {
      final c = Eligibility.checkPermit(
        nationality: const Nationality(primary: 'albion'),
        destination: World.byId('albion'),
        origin: World.byId('pampa'),
        caps: 0,
        professionalYears: 1,
        marketValue: 100,
        continentalExperience: false,
      );
      expect(c.required, isFalse);
    });
  });

  group('外国人枠', () {
    test('強いクラブほど枠が埋まっている', () {
      final country = World.byId('yamato');
      final league = World.buildLeague('yamato', 1);
      final strong = Eligibility.usedSlots(league.first, country);
      final weak = Eligibility.usedSlots(league.last, country);
      expect(strong, greaterThan(weak));
      expect(strong, lessThanOrEqualTo(country.foreignRule.squadLimit!));
    });

    test('枠が無制限の国では使用数を数えない', () {
      final country = World.byId('batavia');
      final club = World.buildLeague('batavia', 1).first;
      expect(Eligibility.usedSlots(club, country), 0);
    });

    test('判定は枠と許可の両方を見る', () {
      final report = Eligibility.report(
        nationality: const Nationality(primary: 'pampa'),
        club: World.buildLeague('albion', 1).first,
        origin: World.byId('pampa'),
        caps: 0,
        professionalYears: 1,
        marketValue: 200,
        continentalExperience: false,
      );
      expect(report.foreign, isTrue);
      expect(report.canJoin, isFalse, reason: '許可が下りないのに加入できている');
      expect(report.slotSummary, contains('外国人枠'));
    });
  });

  group('キャリアと世界', () {
    test('新規キャリアは国を持ち、その国の2部から始まる', () {
      for (var seed = 0; seed < 20; seed++) {
        final s = career(seed: seed);
        final country = World.byId(s.club.countryId);
        expect(s.countryId, country.id);
        expect(s.club.tier, country.tiers >= 2 ? 2 : 1);
        expect(s.player.nationality.primary, country.id);
        expect(s.player.nationality.isHomegrownIn(country.id), isTrue);
        expect(s.league.length, country.clubsInTier(s.club.tier));
      }
    });

    test('国を指定して始められる', () {
      final s = career(countryId: 'albion');
      expect(s.club.countryId, 'albion');
      expect(s.player.nationality.primary, 'albion');
    });

    test('日程の長さはクラブ数で決まる', () {
      final norden = career(countryId: 'norden');
      expect(norden.fixtures.length,
          (World.byId('norden').clubsInTier(2) - 1) * 2);
      final yamato = career(countryId: 'yamato');
      expect(yamato.fixtures.length,
          (World.byId('yamato').clubsInTier(2) - 1) * 2);
    });

    test('格の高い国ほど同じ実力でも年俸が高い', () {
      final rich = CareerEngine.salaryFor(overall: 70, tier: 1, prestige: 5);
      final poor = CareerEngine.salaryFor(overall: 70, tier: 1, prestige: 2);
      expect(rich, greaterThan(poor));
    });

    test('同じ国に5年いると帰化する', () {
      final engine = CareerEngine(random: Random(3));
      var s = career(seed: 3, countryId: 'yamato');
      // 国籍を外国のものに差し替えて、帰化の経路を作る。
      s.player = s.player.copyWith(
          nationality: const Nationality(primary: 'serena'));
      expect(s.player.nationality.has('yamato'), isFalse);

      for (var year = 0; year < 5; year++) {
        for (var i = 0; i < s.fixtures.length; i++) {
          s.results.add(played(6.5, matchday: i + 1));
        }
        s = engine.advanceSeason(s, accepted: engine.renewalOffer(s));
      }
      expect(s.player.nationality.has('yamato'), isTrue,
          reason: '5年いても帰化していない');
    });

    test('降格は国のクラブ数に合わせて下から3クラブ', () {
      final engine = CareerEngine(random: Random(4));
      final s = career(seed: 4, countryId: 'norden');
      // スウェーデンは16クラブ。1部の14位以下が降格。
      final country = World.byId('norden');
      expect(country.clubsInTier(1), 16);
      final club = Club(
          id: 'x', name: 'X', strength: 50, tier: 1, countryId: 'norden');
      s.club = club;
      s.league = World.buildLeague('norden', 1);
      s.table = [
        for (final c in s.league) TableRow(clubId: c.id, clubName: c.name)
      ];
      // 自分を最下位にする。
      for (var i = 0; i < s.table.length; i++) {
        s.table[i].won = s.table.length - i;
      }
      s.club = s.league.last;
      expect(engine.fateOf(s), ClubFate.relegated);
    });

    test('保存を往復しても国とキャリア年数が残る', () {
      final s = career(seed: 5, countryId: 'albion');
      s.professionalYears = 4;
      s.continentalExperience = true;
      final r = CareerState.fromJson(s.toJson());
      expect(r.countryId, 'albion');
      expect(r.club.countryId, 'albion');
      expect(r.professionalYears, 4);
      expect(r.continentalExperience, isTrue);
      expect(r.player.nationality.primary, 'albion');
    });

    test('国を持たない保存データは既定の国として読める', () {
      final s = career(seed: 6, countryId: 'yamato');
      final json = s.toJson();
      json.remove('countryId');
      json.remove('professionalYears');
      json.remove('continentalExperience');
      (json['club'] as Map<String, dynamic>).remove('countryId');
      (json['player'] as Map<String, dynamic>).remove('nationality');

      final r = CareerState.fromJson(json);
      expect(r.countryId, 'yamato');
      expect(r.club.countryId, 'yamato');
      expect(r.player.nationality.primary, 'yamato');
      expect(r.professionalYears, 1);
    });
  });
}
