import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/background_match_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/models/card_rules.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// カップ戦の日を実際の欧州サッカーに寄せる(2026-11-23): カップ戦の入場
/// 収入、決勝は中立の会場、準決勝の2試合合計、警告の累積を大会と国ごとに、
/// イングランドの3部は代表ウィークにも試合。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    CardRules.current = CardRules.generic;
    MatchEngine.cardRng = Random();
  });

  Team squad(String id) {
    final t = PlayerGenerator.generateSquad(id: id, name: id, strengthTier: 70);
    LineupUtils.autoFill(t);
    return t;
  }

  MatchEvent card(Team t, Player p, MatchEventType type, {int minute = 30}) =>
      MatchEvent(
        minute: minute,
        teamId: t.id,
        scorerName: p.name,
        scorerId: p.id,
        type: type,
      );

  group('警告の累積は国と大会ごと', () {
    int bans(CardRules r, int upTo) => [
          for (var c = 1; c <= upTo; c++) r.banForYellow(c)
        ].fold(0, (a, b) => a + b);

    test('イングランド: 5枚で1試合(19節まで)・10枚で2試合(32節まで)・15枚で3試合', () {
      CardRules eng(int md) => CardRules.league(
          theme: LeagueTheme.england, matchday: md, totalMatchdays: 38);
      expect(eng(10).banForYellow(5), 1);
      expect(eng(19).banForYellow(5), 1);
      expect(eng(20).banForYellow(5), 0, reason: '20節からは5枚では止まらない');
      expect(eng(30).banForYellow(10), 2);
      expect(eng(33).banForYellow(10), 0);
      expect(eng(36).banForYellow(15), 3);
      expect(eng(10).banForYellow(4), 0);
      // 46節の部は季の割合で(23節まで・39節まで)。
      final l1 = CardRules.league(
          theme: LeagueTheme.england, matchday: 23, totalMatchdays: 46);
      expect(l1.banForYellow(5), 1);
    });

    test('ドイツ・スペインは5枚ごと、イタリアは5枚目のあと4枚ごと、フランスは3枚ごと', () {
      const ger = CardRules.league(theme: LeagueTheme.germany);
      const spa = CardRules.league(theme: LeagueTheme.spain);
      const ita = CardRules.league(theme: LeagueTheme.italy);
      const fra = CardRules.league(theme: LeagueTheme.france);
      for (final r in [ger, spa]) {
        expect([5, 10, 15].map(r.banForYellow), [1, 1, 1]);
        expect(r.banForYellow(4), 0);
      }
      expect([5, 9, 13, 17].map(ita.banForYellow), [1, 1, 1, 1]);
      expect([6, 8, 10].map(ita.banForYellow), [0, 0, 0]);
      expect([3, 6, 9].map(fra.banForYellow), [1, 1, 1]);
      expect(fra.banForYellow(4), 0);
      expect(bans(fra, 12), 4);
    });

    test('大陸大会は3枚目・5枚目・7枚目、国内カップはイングランド5枚・他は2枚ごと', () {
      const cont = CardRules.continental();
      expect([2, 3, 4, 5, 6, 7].map(cont.banForYellow), [0, 1, 0, 1, 0, 1]);
      expect(
          const CardRules.cup(theme: LeagueTheme.england).banForYellow(5), 1);
      expect(
          const CardRules.cup(theme: LeagueTheme.england).banForYellow(2), 0);
      expect(const CardRules.cup(theme: LeagueTheme.spain).banForYellow(2), 1);
      // 画面の「あと◯枚」。
      expect(const CardRules.league(theme: LeagueTheme.italy).nextBanAt(5), 9);
      expect(cont.nextBanAt(0), 3);
    });

    test('カップ戦の警告と出場停止はカップ戦だけで数え、リーグ戦には出られる', () {
      final home = squad('h');
      final away = squad('a');
      final p = MatchEngine.lineupOf(home).first;
      p.cupYellowCards = 1;
      CardRules.run(
        const CardRules.cup(theme: LeagueTheme.spain),
        () => MatchEngine.applyPostMatchEffects(
          home: home,
          away: away,
          events: [card(home, p, MatchEventType.yellowCard)],
        ),
      );
      expect(p.cupYellowCards, 2);
      expect(p.yellowCards, 0, reason: 'リーグ戦の警告に入った');
      expect(p.cupSuspendedMatches, 1, reason: 'スペインの国内カップは2枚で1試合');
      expect(p.suspendedMatches, 0);
      // リーグ戦(既定)では出られる。カップ戦では出られない。試合後の
      // 処理はまれに怪我・疲れを付けて先発から外すので、それは消して見る。
      p
        ..injuryWeeks = 0
        ..injuryType = null
        ..fatigue = 0;
      expect(p.isSuspended, isFalse);
      expect(MatchEngine.lineupOf(home).any((x) => x.id == p.id), isTrue);
      CardRules.run(const CardRules.cup(), () {
        expect(p.isSuspended, isTrue);
        expect(MatchEngine.lineupOf(home).any((x) => x.id == p.id), isFalse);
      });
      // リーグ戦を1試合こなしても、カップ戦の出場停止は減らない。
      MatchEngine.applyPostMatchEffects(home: home, away: away);
      expect(p.cupSuspendedMatches, 1);
      // カップ戦を1試合(出ずに)こなすと消化する。
      CardRules.run(const CardRules.cup(),
          () => MatchEngine.applyPostMatchEffects(home: home, away: away));
      expect(p.cupSuspendedMatches, 0);
    });

    test('2枚目の警告の退場は1試合で、その試合の警告は累積に数えない', () {
      final home = squad('h');
      final away = squad('a');
      final p = MatchEngine.lineupOf(home).first;
      p.yellowCards = 4;
      MatchEngine.applyPostMatchEffects(
        home: home,
        away: away,
        events: [
          card(home, p, MatchEventType.yellowCard, minute: 20),
          card(home, p, MatchEventType.redCard, minute: 70),
        ],
      );
      expect(p.yellowCards, 4, reason: '退場した試合の警告で5枚目にしない');
      expect(p.suspendedMatches, 1);
    });

    test('一発退場の一部(3割前後)は暴力行為で3試合', () {
      final home = squad('h');
      final away = squad('a');
      MatchEngine.cardRng = Random(7);
      var three = 0;
      const n = 400;
      for (var i = 0; i < n; i++) {
        final p = home.players.first..suspendedMatches = 0;
        MatchEngine.applyPostMatchEffects(
          home: home,
          away: away,
          events: [card(home, p, MatchEventType.redCard)],
        );
        expect(p.suspendedMatches, anyOf(1, 3));
        if (p.suspendedMatches == 3) three++;
      }
      expect(three / n, inInclusiveRange(0.3, 0.6));
    });

    test('裏の試合も同じ決まりで、国の段階で出場停止になる', () {
      final rng = Random(11);
      for (var i = 0; i < 300; i++) {
        final home = squad('h$i');
        final away = squad('a$i');
        for (final p in MatchEngine.lineupOf(home)) {
          p.yellowCards = 2;
        }
        CardRules.run(
            const CardRules.league(theme: LeagueTheme.france),
            () => BackgroundMatchEngine.applyPlayerEffects(
                home: home, away: away, random: rng));
        final hit = home.players.where((p) => p.yellowCards == 3).toList();
        if (hit.isEmpty) continue;
        for (final p in hit) {
          expect(p.suspendedMatches, greaterThanOrEqualTo(1),
              reason: 'フランスは3枚で1試合');
        }
        return;
      }
      fail('3枚目の警告が一度も出なかった');
    });

    test('季末に全大会の警告の数が0に戻り、出場停止は持ち越す', () async {
      final gs = GameState();
      await gs.startNewGame('札FC');
      final p = gs.userTeam.players.first
        ..yellowCards = 4
        ..cupYellowCards = 1
        ..continentalYellowCards = 2
        ..suspendedMatches = 1;
      gs.debugResetSeasonCards();
      expect(p.yellowCards, 0);
      expect(p.cupYellowCards, 0);
      expect(p.continentalYellowCards, 0);
      expect(p.suspendedMatches, 1);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('古いセーブ(大会ごとの欄が無い)も読めて、保存して読み戻せる', () {
      final p = squad('h').players.first
        ..yellowCards = 3
        ..cupSuspendedMatches = 2
        ..continentalYellowCards = 1;
      final json = p.toJson();
      final back = Player.fromJson(json);
      expect(back.yellowCards, 3);
      expect(back.cupSuspendedMatches, 2);
      expect(back.continentalYellowCards, 1);
      final old = Map<String, dynamic>.from(json)
        ..remove('cupSuspendedMatches')
        ..remove('continentalYellowCards');
      final fromOld = Player.fromJson(old);
      expect(fromOld.cupSuspendedMatches, 0);
      expect(fromOld.continentalYellowCards, 0);
    });
  });

  group('中立の会場と2試合合計', () {
    List<Team> plain(List<String> ids) => [
          for (final id in ids)
            Team(id: id, name: id, players: [], retainedOverall: 70),
        ];

    test('決勝は中立。FA カップは準決勝も中立。スーパーカップは全部中立', () {
      final ids = [for (var i = 0; i < 8; i++) 't$i'];
      final cup = CupEngine.createTiered(
          type: CupType.domestic, name: 'c', byTier: {3: ids});
      expect(cup.plannedRounds, 3);
      final r1 = CupMatch(round: 1, homeTeamId: 'a', awayTeamId: 'b');
      final semi = CupMatch(round: 2, homeTeamId: 'a', awayTeamId: 'b');
      final fin = CupMatch(round: 3, homeTeamId: 'a', awayTeamId: 'b');
      expect([r1, semi, fin].map(cup.isNeutral), [false, false, true]);
      final fa = CupEngine.createTiered(
          type: CupType.domestic,
          name: 'fa',
          byTier: {3: ids},
          neutralSemiFinal: true);
      expect([r1, semi, fin].map(fa.isNeutral), [false, true, true]);
      final sc = Cup(type: CupType.superCup, name: 's', rounds: []);
      expect(sc.isNeutral(r1), isTrue);
      // 古いセーブ(欄が無い)も決勝は中立。
      final old = Cup.fromJson(cup.toJson()..remove('neutralFromRound'));
      expect(old.isNeutral(fin), isTrue);
      expect(old.isNeutral(r1), isFalse);
      expect(CupEngine.homeAdvantageFor(cup, fin),
          MatchEngine.neutralHomeAdvantageFactor);
      expect(CupEngine.homeAdvantageFor(cup, r1),
          MatchEngine.defaultHomeAdvantageFactor);
    });

    test('中立の会場の裏の試合は、同じ強さならホームとアウェイの得点が同じくらい', () {
      final a = plain(['a']).single;
      final b = plain(['b']).single;
      final rng = Random(3);
      var home = 0, away = 0, nh = 0, na = 0;
      for (var i = 0; i < 4000; i++) {
        final r = BackgroundMatchEngine.simulate(
            home: a, away: b, matchday: 0, random: rng);
        home += r.homeGoals;
        away += r.awayGoals;
        final n = BackgroundMatchEngine.simulate(
            home: a, away: b, matchday: 0, neutral: true, random: rng);
        nh += n.homeGoals;
        na += n.awayGoals;
      }
      expect(home / away, greaterThan(1.2), reason: 'ふつうはホームの利がある');
      expect(nh / na, inInclusiveRange(0.9, 1.1), reason: '中立では差が無い');
    });

    test('準決勝の2試合合計: 第1戦は相手のホーム、合計で勝ち抜け、決勝は1試合', () {
      for (var seed = 0; seed < 20; seed++) {
        final ids = ['a', 'b', 'c', 'd'];
        final cup = CupEngine.createTiered(
            type: CupType.domestic,
            name: 'copa',
            byTier: {3: ids},
            twoLeggedSemiFinal: true,
            random: Random(seed));
        final teams = plain(ids);
        expect(cup.plannedRounds, 2);
        expect(cup.twoLeggedRounds, [1]);
        final semi = cup.rounds.first.first;
        expect(semi.twoLegged, isTrue);
        expect(semi.awaitingFirstLeg, isTrue);
        expect(semi.nextHomeId, semi.awayTeamId, reason: '第1戦は相手のホーム');
        CupEngine.playInBackground(cup, teams, semi);
        expect(semi.firstLeg, isNotNull);
        expect(semi.firstLeg!.homeTeamId, semi.awayTeamId);
        expect(semi.result, isNull);
        expect(semi.winnerId, isNull, reason: '第1戦では決まらない');
        expect(cup.nextUnplayedMatch, same(semi), reason: '第2戦が残っている');
        expect(cup.rounds.length, 1, reason: '第1戦だけで次の回戦を組まない');
        CupEngine.playInBackground(cup, teams, semi);
        expect(semi.result!.homeTeamId, semi.homeTeamId);
        final w = semi.winnerId!;
        final l = w == semi.homeTeamId ? semi.awayTeamId : semi.homeTeamId;
        if (semi.penaltyWinnerId == null) {
          expect(semi.goalsFor(w), greaterThan(semi.goalsFor(l)),
              reason: '合計で多い方が勝ち抜ける');
        } else {
          expect(semi.goalsFor(w), semi.goalsFor(l));
        }
        // 残りを決めると、決勝は1試合で中立。
        var guard = 0;
        while (!cup.isComplete && guard++ < 10) {
          CupEngine.playInBackground(cup, teams, cup.nextUnplayedMatch!);
        }
        expect(cup.isComplete, isTrue);
        final fin = cup.rounds.last.single;
        expect(fin.twoLegged, isFalse);
        expect(cup.isNeutral(fin), isTrue);
        // 保存して読み戻せる。
        final back = Cup.fromJson(cup.toJson());
        expect(back.twoLeggedRounds, [1]);
        expect(back.rounds.first.first.firstLeg?.homeGoals,
            cup.rounds.first.first.firstLeg?.homeGoals);
        expect(back.championId, cup.championId);
      }
    });

    test('合計で並べば第2戦の後に延長・PK戦で決まる', () {
      final teams = plain(['a', 'b']);
      final m =
          CupMatch(round: 1, homeTeamId: 'a', awayTeamId: 'b', twoLegged: true);
      final cup = Cup(
          type: CupType.domestic,
          name: 'c',
          rounds: [
            [m]
          ],
          plannedRounds: 1);
      MatchResult res(String h, String a, int hg, int ag) => MatchResult(
          matchday: 0,
          homeTeamId: h,
          awayTeamId: a,
          homeGoals: hg,
          awayGoals: ag,
          events: const []);
      // 第1戦 b 2-1 a、第2戦 a 1-0 b → 合計 2-2。
      CupEngine.applyMatchResult(cup, teams, m, res('b', 'a', 2, 1));
      expect(m.extraTime, isFalse, reason: '第1戦に延長は無い');
      CupEngine.applyMatchResult(cup, teams, m, res('a', 'b', 1, 0));
      expect(m.extraTime, isTrue);
      expect(m.winnerId, isNotNull);
      expect(cup.isComplete, isTrue);
      // 第2戦で合計が決まれば延長は無い(2-1 で a が合計 3-2)。
      final m2 =
          CupMatch(round: 1, homeTeamId: 'a', awayTeamId: 'b', twoLegged: true);
      final cup2 = Cup(
          type: CupType.domestic,
          name: 'c',
          rounds: [
            [m2]
          ],
          plannedRounds: 1);
      CupEngine.applyMatchResult(cup2, teams, m2, res('b', 'a', 2, 1));
      CupEngine.applyMatchResult(cup2, teams, m2, res('a', 'b', 2, 0));
      expect(m2.extraTime, isFalse);
      expect(m2.winnerId, 'a');
    });

    test('スペイン・イタリアの国内カップとイングランドのリーグカップは準決勝が2試合合計', () async {
      for (final (theme, twoLegs, neutralSemi) in [
        (LeagueTheme.spain, true, false),
        (LeagueTheme.italy, true, false),
        (LeagueTheme.england, false, true),
        (LeagueTheme.germany, false, false),
      ]) {
        final gs = GameState();
        await gs.startNewGame('杯FC', theme: theme);
        final cup = gs.domesticCup!;
        final semi = cup.plannedRounds! - 1;
        expect(cup.twoLeggedRounds.contains(semi), twoLegs, reason: theme.name);
        expect(cup.neutralFromRound, neutralSemi ? semi : semi + 1,
            reason: theme.name);
        if (theme == LeagueTheme.england) {
          expect(gs.leagueCup!.twoLeggedRounds,
              [gs.leagueCup!.plannedRounds! - 1]);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  });

  group('カップ戦の入場収入', () {
    test('国内のカップ戦は折半、大陸大会はホームだけで高い単価、中立は総額を折半', () async {
      final gs = GameState();
      await gs.startNewGame('入場FC');
      final gate = gs.cupHomeMatchGate;
      expect(gate, greaterThan(0));
      expect(gs.cupGateIncome(userHome: true, neutral: false, split: true),
          (gate / 2).round());
      expect(gs.cupGateIncome(userHome: false, neutral: false, split: true),
          (gate / 2).round(),
          reason: 'アウェイでも半分入る');
      expect(
          gs.cupGateIncome(
              userHome: true,
              neutral: false,
              split: false,
              priceMultiplier: 1.6),
          (gate * 1.6).round());
      expect(
          gs.cupGateIncome(userHome: false, neutral: false, split: false), 0);
      expect(gs.cupGateIncome(userHome: false, neutral: true, split: true),
          (gate * 2.0 / 2).round());
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('自クラブの国内カップの試合で、入場収入が入る(ホームでもアウェイでも)', () async {
      final gs = GameState();
      await gs.startNewGame('入場FC');
      final s = gs.save!;
      final u = s.userTeamId;
      final others = s.league.teams.where((t) => t.id != u).take(3).toList();
      s.cups.removeWhere((c) => c.type == CupType.domestic);
      final cup = CupEngine.createTiered(
        type: CupType.domestic,
        name: 'cup',
        byTier: {
          3: [u, ...others.map((t) => t.id)]
        },
        focusTeamId: u,
      );
      s.cups.add(cup);
      final match = cup.nextUnplayedMatch!;
      expect(cup.isNeutral(match), isFalse);
      final expected = gs.cupGateIncome(
          userHome: match.homeTeamId == u, neutral: false, split: true);
      final before = gs.currentLedger.of(LedgerCategory.gate);
      final r = await gs.playNextCupMatch();
      expect(r, isNotNull);
      expect(gs.currentLedger.of(LedgerCategory.gate) - before, expected);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('イングランドの3部は代表ウィークにも試合', () {
    test('暦: 3部は代表ウィークの土曜にも節があり、ほかの部・国には無い', () {
      for (final season in [1, 2, 3]) {
        final window = SeasonCalendar.internationalWindowDays(season);
        final l1 = SeasonCalendar.build(
            season: season,
            theme: LeagueTheme.england,
            totalMatchdays: 46,
            playsInInternationalWindows: true);
        final champ = SeasonCalendar.build(
            season: season, theme: LeagueTheme.england, totalMatchdays: 46);
        expect(l1.matchdayDates.where(window.contains), isNotEmpty);
        expect(champ.matchdayDates.where(window.contains), isEmpty);
        expect(l1.matchdayDates.length, 46);
        expect(
            l1.lastMatchDate
                .isAfter(DateTime(l1.matchdayDates.first.year + 1, 5, 31)),
            isFalse);
      }
      expect(
          SeasonCalendar.playsThroughInternationalWindows(
              LeagueTheme.england, 3),
          isTrue);
      expect(
          SeasonCalendar.playsThroughInternationalWindows(
              LeagueTheme.england, 2),
          isFalse);
      expect(
          SeasonCalendar.playsThroughInternationalWindows(LeagueTheme.spain, 3),
          isFalse);
    });

    test('ゲーム: イングランドの3部のクラブの暦は代表ウィークにも節を置く', () async {
      final gs = GameState();
      await gs.startNewGame('三部FC');
      expect(gs.currentDivisionTier, 3, reason: '3部から始まる');
      final cal = gs.seasonCalendar;
      expect(cal.playsInInternationalWindows, isTrue);
      final window =
          SeasonCalendar.internationalWindowDays(gs.save!.league.season);
      expect(cal.matchdayDates.where(window.contains), isNotEmpty);
      gs.save!.currentDivisionTier = 2;
      expect(gs.seasonCalendar.playsInInternationalWindows, isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
