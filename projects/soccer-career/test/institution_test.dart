import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/competitions.dart';
import 'package:soccer_career/game/person.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/competition.dart';
import 'package:soccer_career/models/reputation.dart';
import 'package:soccer_career/models/season.dart';

CareerState career({
  int seed = 3,
  int age = 20,
  Position position = Position.cm,
}) =>
    CareerEngine(random: Random(seed)).startCareer(
        name: 'T', position: position, age: age, agent: Agent.pool.first);

/// そのシーズンを「出場して活躍した」ことにする。
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

void main() {
  group('国内カップ', () {
    test('毎シーズン、順位に関係なく戦う', () {
      final engine = CareerEngine(random: Random(5));
      final state = career();
      engine.resolveSeasonEnd(state);
      expect(state.cupStage.participated, isTrue);
    });

    test('一発勝負なので、格下でも勝ち上がることがある', () {
      final stages = <CupStage>{};
      for (var seed = 0; seed < 40; seed++) {
        final engine = CareerEngine(random: Random(seed));
        final state = career(seed: seed);
        engine.resolveSeasonEnd(state);
        stages.add(state.cupStage);
      }
      expect(stages.length, greaterThan(2));
    });

    test('優勝すれば翌季の大陸カップに出られる', () {
      final engine = CareerEngine(random: Random(7));
      final state = career();
      state.history.add(SeasonRecord(
        year: state.year - 1,
        clubName: state.club.name,
        tier: state.club.tier,
        leaguePosition: 14,
        stats: const SeasonStats(
            appearances: 30, goals: 5, assists: 4, averageRating: 6.9),
        cupStage: CupStage.winner,
      ));
      // 14位でも、前年のカップ優勝で出場権がある。
      expect(engine.inContinental(state), isTrue);
    });
  });

  group('ワールドカップ', () {
    test('4年に1度だけ', () {
      expect(Competitions.isWorldCupYear(2028), isTrue);
      expect(Competitions.isWorldCupYear(2029), isFalse);
    });

    test('招集されていなければ出られない', () {
      final competitions = Competitions(random: Random(2));
      final state = career();
      expect(competitions.runWorldCup(state, calledUp: false),
          WorldCupStage.none);
      expect(competitions.runWorldCup(state, calledUp: true).participated,
          isTrue);
    });

    test('本大会に出るとキャップが積み上がる', () {
      final engine = CareerEngine(random: Random(3));
      final state = career();
      state.year = 2028;
      state.calledUp = true;
      final before = state.caps;
      engine.resolveSeasonEnd(state);
      expect(state.worldCupStage.participated, isTrue);
      expect(state.caps, greaterThan(before));
    });

    test('出場と優勝は称号になり、知名度に大きく効く', () {
      final person = Person(random: Random(1));
      final state = career();
      fillSeason(state);
      state.worldCupStage = WorldCupStage.winner;
      final awards = person.awardsFor(state, promoted: false);
      expect(awards, contains(Award.worldCup));
      expect(awards, contains(Award.worldCupTitle));

      final withCup = person.fameFor(state);
      state.worldCupStage = WorldCupStage.none;
      expect(withCup, greaterThan(person.fameFor(state)));
    });
  });

  group('ローン', () {
    test('出番の無い若手には期限付きの話が来る', () {
      final engine = CareerEngine(random: Random(9));
      final state = career(age: 19);
      final loans = engine.offersFor(state).where((o) => o.loan);
      expect(loans, isNotEmpty);
      expect(loans.first.years, 1);
    });

    test('歳を取った選手には来ない', () {
      final engine = CareerEngine(random: Random(9));
      final state = career(age: 28);
      expect(engine.offersFor(state).where((o) => o.loan), isEmpty);
    });

    test('ローンに出ると保有元が残り、契約は減らない', () {
      final engine = CareerEngine(random: Random(9));
      final state = career(age: 19);
      final loan = engine.offersFor(state).firstWhere((o) => o.loan);
      final years = state.contractYears;
      final parent = state.club.name;

      final next = engine.advanceSeason(state, accepted: loan);
      expect(next.onLoan, isTrue);
      expect(next.parentClub!.name, parent);
      expect(next.club.name, loan.club.name);
      expect(next.contractYears, years);
    });

    test('ローンが明けたら戻る契約が出る', () {
      final engine = CareerEngine(random: Random(9));
      final state = career(age: 19);
      final loan = engine.offersFor(state).firstWhere((o) => o.loan);
      final onLoan = engine.advanceSeason(state, accepted: loan);

      final back = engine.renewalOffer(onLoan);
      expect(back.returning, isTrue);
      expect(back.club.name, onLoan.parentClub!.name);

      final returned = engine.advanceSeason(onLoan, accepted: back);
      expect(returned.onLoan, isFalse);
      expect(returned.club.name, onLoan.parentClub!.name);
    });

    test('買い取りは、オプション付きで結果を出したときだけ', () {
      final engine = CareerEngine(random: Random(9));
      final state = career(age: 19);
      final loan = engine.offersFor(state).firstWhere((o) => o.loan);
      final onLoan = engine.advanceSeason(state, accepted: loan);

      // 出ていなければ話は無い。
      expect(engine.offersFor(onLoan), isEmpty);

      fillSeason(onLoan, rating: 7.0, matches: 20);
      onLoan.loanBuyOption = 5000;
      final buy = engine.offersFor(onLoan);
      expect(buy, isNotEmpty);
      expect(buy.first.fee, 5000);
      expect(buy.first.club.name, onLoan.club.name);
    });
  });

  group('移籍金と違約金', () {
    test('契約更改には違約金が付き、移籍には移籍金が動く', () {
      final engine = CareerEngine(random: Random(11));
      final state = career(age: 24);
      fillSeason(state);
      state.contractYears = 1;

      final renewal = engine.renewalOffer(state);
      expect(renewal.releaseClause, isNotNull);
      expect(renewal.fee, 0);

      final transfers = engine.offersFor(state).where((o) => !o.loan);
      if (transfers.isNotEmpty) {
        expect(transfers.first.fee, greaterThan(0));
        expect(transfers.first.releaseClause, isNotNull);
      }
    });

    test('違約金を追い越すと、契約が残っていても話が動く', () {
      final engine = CareerEngine(random: Random(13));
      final state = career(age: 24);
      fillSeason(state);
      state.contractYears = 3;
      state.releaseClause = 1000;

      // 追い越す前は動けない。
      state.reputation = const Reputation(marketValue: 500);
      expect(engine.clauseTriggered(state), isFalse);
      expect(engine.offersFor(state).where((o) => !o.loan), isEmpty);

      state.reputation = const Reputation(marketValue: 20000);
      expect(engine.clauseTriggered(state), isTrue);
    });

    test('高く買われた選手は、監督の信頼を最初から持って入る', () {
      final engine = CareerEngine(random: Random(15));
      final state = career(age: 24);
      fillSeason(state);
      state.contractYears = 1;
      state.reputation = const Reputation(marketValue: 1000);
      final before = state.relations.manager;

      final renewal = engine.renewalOffer(state);
      final cheap = engine.advanceSeason(state, accepted: renewal);
      final expensive = engine.advanceSeason(
        state,
        accepted: TransferOffer(
          club: state.club,
          reason: 'x',
          salary: state.salary,
          role: '主力',
          years: 3,
          fee: 5000,
        ),
      );
      expect(expensive.relations.manager,
          greaterThan(cheap.relations.manager));
      expect(before, isNotNull);
    });
  });

  group('代理人への売り込み', () {
    test('前金が払えなければ動かない', () {
      final engine = CareerEngine(random: Random(17));
      final state = career(age: 24);
      expect(state.finances.savings, 0);
      final (found, offers) = engine.solicitOffers(state);
      expect(found, isFalse);
      expect(offers, isEmpty);
    });

    test('前金は貯蓄から引かれる', () {
      final engine = CareerEngine(random: Random(19));
      final state = career(age: 24);
      fillSeason(state);
      state.contractYears = 1;
      state.finances = const Finances(savings: 100000);
      final cost = engine.solicitCostFor(state);

      engine.solicitOffers(state);
      expect(state.finances.savings, 100000 - cost);
    });

    test('取れた話は、待っていれば来た条件より少し落ちる', () {
      // 同じ状態から、市場のオファーと売り込みで取れたオファーを比べる。
      var compared = false;
      for (var seed = 0; seed < 30 && !compared; seed++) {
        final engine = CareerEngine(random: Random(seed));
        final state = career(seed: seed, age: 24);
        fillSeason(state);
        state.contractYears = 1;
        state.finances = const Finances(savings: 100000);
        final market = engine.offersFor(state).where((o) => !o.loan).toList();
        final (found, solicited) = engine.solicitOffers(state);
        if (!found || market.isEmpty) continue;
        expect(solicited.first.salary, lessThan(market.first.salary));
        compared = true;
      }
      expect(compared, isTrue);
    });
  });

  test('大会とローンは保存を往復しても残る', () {
    final state = career();
    state.cupStage = CupStage.semi;
    state.worldCupStage = WorldCupStage.runnerUp;
    state.releaseClause = 12000;
    state.loanBuyOption = 3000;
    state.parentClub = state.league.last;

    final r = CareerState.fromJson(state.toJson());
    expect(r.cupStage, CupStage.semi);
    expect(r.worldCupStage, WorldCupStage.runnerUp);
    expect(r.releaseClause, 12000);
    expect(r.loanBuyOption, 3000);
    expect(r.parentClub!.name, state.parentClub!.name);
    expect(r.onLoan, isTrue);

    final legacy = CareerState.fromJson(state.toJson()
      ..remove('cupStage')
      ..remove('worldCupStage')
      ..remove('parentClub')
      ..remove('releaseClause')
      ..remove('loanBuyOption'));
    expect(legacy.cupStage, CupStage.none);
    expect(legacy.onLoan, isFalse);
    expect(legacy.releaseClause, isNull);
  });
}
