import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/happiness_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/screens/matchday_notices.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 2026-11-23: 買い直し・週の処理・知らせ・約束・引退・ローンの9件を
/// 直した挙動を固定する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  Future<GameState> start() async {
    final gs = GameState();
    await gs.startNewGame('修正FC');
    return gs;
  }

  LeagueTheme otherTheme(GameState gs) =>
      LeagueTheme.values.firstWhere((t) => t != gs.currentLeagueTheme);

  int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  group('1〜3. 季の途中で別の国のクラブを買い直す', () {
    test('前のクラブの週の処理・節の処理の記録を片付ける', () async {
      final gs = await start();
      expect((await gs.simulateAheadMatchdays(6)).length, 6);
      final s0 = gs.save!;
      expect(s0.weekProcessedMatchday, 6);
      expect(s0.lastWeeklyTickDate, isNotNull);
      final reached = gs.today;

      s0
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      expect(await gs.buyClubInCountry(otherTheme(gs)), isTrue);
      final s = gs.save!;
      expect(gs.today.isBefore(reached), isTrue, reason: '新しい国は開幕前から');
      expect(s.lastWeeklyTickDate, isNull);
      expect(s.lastUserMatchDate, isNull);
      expect(s.weekProcessedSeason, 0);
      expect(s.weekProcessedMatchday, 0);
      expect(s.liveMatchProgress, isNull);
      expect(s.lastManagerOfMonthCheckpoint, 0);
      expect(s.personalDatesThrough, reached);
    });

    test('1. 戻した期間も週の処理が7日ごとに回り、過密の判定も新しい試合の日から', () async {
      final gs = await start();
      expect((await gs.simulateAheadMatchdays(6)).length, 6);
      final reached = gs.today;
      gs.save!
        ..confidence = 0
        // 最後通告の期限を過ぎた(手放す)ことにする。
        ..supporterUltimatumUntil = DateTime(2000);
      expect(await gs.buyClubInCountry(otherTheme(gs)), isTrue);
      final s = gs.save!;

      // 前のクラブで進めた日より前の節を3つ。
      expect((await gs.simulateAheadMatchdays(3)).length, 3);
      expect(gs.today.isBefore(reached), isTrue);
      final tick = s.lastWeeklyTickDate;
      expect(tick, isNotNull);
      expect(tick!.isAfter(gs.today), isFalse,
          reason: '前のクラブの季の途中の日付のまま、週の処理が止まっている');
      expect(daysBetween(tick, gs.today), lessThan(7));
      expect(s.lastUserMatchDate, gs.today, reason: '自クラブの最後の試合の日が前のクラブのまま');
    });

    test('2. 前のクラブで処理した節番号の節を「途中で終わった試合」と取り違えない', () async {
      // 第1節を終えた直後に手放すと、新しい国の第1節が同じ番号になる。
      final gs = await start();
      expect((await gs.simulateAheadMatchdays(1)).length, 1);
      expect(gs.save!.weekProcessedMatchday, 1);
      gs.save!
        ..confidence = 0
        // 最後通告の期限を過ぎた(手放す)ことにする。
        ..supporterUltimatumUntil = DateTime(2000);
      expect(await gs.buyClubInCountry(otherTheme(gs)), isTrue);
      final s = gs.save!;

      expect((await gs.simulateAheadMatchdays(1)).length, 1);
      expect(s.lastWeeklyTickDate, isNotNull, reason: '週の処理の時計が起きていない');
      for (final l in s.otherDivisionLeagues) {
        if (l == null) continue;
        for (final f in l.fixtures.where((f) => f.matchday == 1)) {
          expect(f.result, isNotNull, reason: '他の部の第1節が飛ばされた');
        }
      }
    });

    test('オーナーの本業の収入と誕生日は、戻した期間ぶん二重に入らない', () async {
      final gs = await start();
      final year = gs.today.year;
      // 始めたときの額を決めておく(部が変わると始めの額が変わる)。
      expect(gs.ownerWealth, greaterThan(0));
      gs.debugAdvanceTodayTo(DateTime(year, 11, 15));
      final reached = gs.today;

      gs.save!
        ..confidence = 0
        // 最後通告の期限を過ぎた(手放す)ことにする。
        ..supporterUltimatumUntil = DateTime(2000);
      expect(await gs.buyClubInCountry(otherTheme(gs)), isTrue);
      expect(gs.today.isBefore(reached), isTrue);
      final wealth = gs.ownerWealth;
      final ages = {for (final p in gs.save!.allPlayers) p: p.age};

      // 戻した期間(7月1日→11月15日)を進め直しても、何も入らない。
      gs.debugAdvanceTodayTo(reached);
      expect(gs.ownerWealth, wealth, reason: '本業の収入が二重に入った');
      for (final e in ages.entries) {
        expect(e.key.age, e.value, reason: '${e.key.name}の誕生日が二重に来た');
      }

      // 済ませた日より先は、ふつうに月ごとに入る。
      gs.debugAdvanceTodayTo(DateTime(year, 12, 2));
      expect(gs.ownerWealth, wealth + GameStateOwner.monthlyIncome);
    });

    test('済ませた日はセーブに残り、無い旧セーブは null で読む', () async {
      final gs = await start();
      Map<String, dynamic> roundTrip(SaveGame s) =>
          (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, dynamic>();
      final old = roundTrip(gs.save!)..remove('personalDatesThrough');
      final save = SaveGame.fromJson(old);
      expect(save.personalDatesThrough, isNull);
      save.personalDatesThrough = DateTime(2026, 11, 15);
      final back = SaveGame.fromJson(roundTrip(save));
      expect(back.personalDatesThrough, DateTime(2026, 11, 15));
    });

    test('同じ国の買い直し(buyClub)は日付を戻さず、週の処理も続く', () async {
      final gs = await start();
      await gs.simulateAheadMatchdays(3);
      final s = gs.save!;
      final day = gs.today;
      final tick = s.lastWeeklyTickDate;
      s
        ..confidence = 0
        ..supporterUltimatumUntil = DateTime(2000);
      final target = gs.buyoutCandidates.first;
      expect(await gs.buyClub(target.id), isTrue);
      expect(gs.today, day);
      expect(s.lastWeeklyTickDate, tick);
      final more = await gs.simulateAheadMatchdays(2);
      expect(more.length, 2);
      expect(daysBetween(s.lastWeeklyTickDate!, gs.today), lessThan(7));
    });
  });

  group('4. 自分の部の外のクラブの選手も、怪我と疲れが治る', () {
    test('他の部・他国・大陸大会のクラブの選手が日数で治る(同じ選手は1回だけ)', () async {
      final gs = await start();
      final s = gs.save!;
      final other = s.otherDivisionLeagues.firstWhere((l) => l != null)!;
      final otherPlayer = other.teams.first.players.first;
      expect(s.foreignLeagues, isNotEmpty);
      final foreignPlayer =
          s.foreignLeagues.values.first.teams.first.players.first;
      final contOnly =
          PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
      // 大陸大会のクラブが、他国のリーグの選手そのものを持っている場合。
      final cont = PlayerGenerator.generateSquad(
          id: 'cont_test', name: 'Cont', strengthTier: 60)
        ..players = [foreignPlayer, contOnly];
      s.continentalTeams = [cont];
      for (final p in [otherPlayer, foreignPlayer, contOnly]) {
        p
          ..injuryWeeks = 5
          ..injuryDays = 0
          ..fatigue = 80;
      }

      gs.debugRecoverByDays(14);

      for (final p in [otherPlayer, foreignPlayer, contOnly]) {
        expect(p.injuryWeeks, 3, reason: '${p.name}: 14日で2週ぶん治る');
        expect(p.fatigue, 80 - 14 * 2);
      }
    });
  });

  group('5. 週の処理が書いた知らせを、画面の側で受信箱に積み直さない', () {
    test('リリース条項・代表・ローン復帰・満期・移籍市場は積まず、他は1通積む', () async {
      final gs = await start();
      final before = gs.save!.newsLog.length;
      gs.lastReleaseClauseSales = ['条項太郎'];
      gs.lastInternationalCallUps = ['代表太郎'];
      gs.lastLoanReturns = ['復帰太郎'];
      gs.lastAiTransferNews = '移籍の知らせ';
      gs.lastAppearanceFeesPaid = 120;
      gs.lastLoanEndings = ['借用太郎'];

      final shown = routeMatchdayNotices(gs);

      expect(shown, isEmpty, reason: '注意でないものは画面に出さない');
      final added = gs.save!.newsLog.take(gs.save!.newsLog.length - before);
      final texts = added.map((n) => n.text).toList();
      for (final name in ['条項太郎', '代表太郎', '復帰太郎', '移籍の知らせ']) {
        expect(texts.any((t) => t.contains(name)), isFalse,
            reason: '$name は週の処理が積んでいる');
      }
      expect(texts.where((t) => t.contains('借用太郎')).length, 1);
      expect(texts.where((t) => t.contains('出場給')).length, 1);
      // 読んだものは空にする。
      expect(gs.lastInternationalCallUps, isEmpty);
      expect(gs.lastLoanEndings, isEmpty);
    });
  });

  group('6. 登録の名簿の外の選手は、約束破り・ベンチの不満に数えない', () {
    test('約束の点検: 名簿の外なら外れ続けても数えない', () async {
      final gs = await start();
      final p = gs.userTeam.players
          .firstWhere((p) => !gs.userTeam.startingXI.contains(p.id))
        ..promisedStatus = SquadStatus.keyPlayer
        ..notRegistered = true;
      for (var i = 0; i < 20; i++) {
        gs.debugCheckPromises();
      }
      expect(p.promiseMisses, 0);
      expect(p.promiseBroken, isFalse);
      // 名簿に戻れば、また数える。
      p.notRegistered = false;
      gs.debugCheckPromises();
      expect(p.promiseMisses, 1);
    });

    test('不満: 名簿の外の選手には、控えの不満をかけない', () {
      final team =
          PlayerGenerator.generateSquad(id: 't', name: 'T', strengthTier: 60);
      for (final p in team.players) {
        p.happiness = 60;
      }
      final p = team.players.firstWhere((p) => !team.startingXI.contains(p.id))
        ..notRegistered = true
        ..wage = 1;
      HappinessEngine.applyWeekly(team, leagueRank: 15, boardTargetRank: 2);
      expect(p.happiness, 60);
    });
  });

  group('7. 借りている選手は、借りた先で引退しない', () {
    test('高齢でも、ローンの選手は引退の判定から外す(数回振る)', () {
      var retiredOwn = 0;
      for (var seed = 0; seed < 20; seed++) {
        final team = Team(id: 't', name: 'T', players: []);
        final loanee = PlayerGenerator.generate(
            position: Position.st, strengthTier: 30, ageOverride: 40)
          ..isLoan = true;
        final own = PlayerGenerator.generate(
            position: Position.st, strengthTier: 30, ageOverride: 40);
        team.players.addAll([loanee, own]);
        final gone =
            RetirementEngine.resolveRetirements(team, rng: Random(seed));
        expect(gone, isNot(contains(loanee)), reason: 'seed $seed');
        expect(team.players, contains(loanee));
        if (gone.contains(own)) retiredOwn++;
      }
      expect(retiredOwn, greaterThan(10), reason: '自分の選手はふつうに引退する');
    });
  });

  group('8. フリーエージェントも引退する', () {
    test('高齢の所属なしは外れ、若い選手と話を進めている選手は残る', () {
      for (var seed = 0; seed < 5; seed++) {
        final old = [
          for (var i = 0; i < 20; i++)
            PlayerGenerator.generate(
                position: Position.mc, strengthTier: 30, ageOverride: 39),
        ];
        final young = [
          for (var i = 0; i < 10; i++)
            PlayerGenerator.generate(
                position: Position.mc, strengthTier: 50, ageOverride: 24),
        ];
        final kept = old.first;
        final pool = [...old, ...young];
        final gone = RetirementEngine.retireFreeAgents(pool,
            rng: Random(seed), keep: {kept.id});
        expect(gone, isNotEmpty, reason: 'seed $seed');
        expect(gone.every((p) => p.age >= 32), isTrue);
        expect(pool, containsAll(young));
        expect(pool, contains(kept));
        for (final p in gone) {
          expect(pool, isNot(contains(p)));
        }
      }
    });
  });

  group('7・8・9. 季の切り替え', () {
    test(
        '借りている高齢の選手は殿堂に入らず「ローン期間満了で貸し元へ復帰」と出る。'
        '高齢の所属なしは引退する', () async {
      for (var round = 0; round < 2; round++) {
        final gs = await start();
        final s = gs.save!;
        final parent = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
        final clock = Player.contractClockYear;
        final loanee = PlayerGenerator.generate(
            position: Position.st, strengthTier: 30, ageOverride: 40)
          ..isLoan = true
          ..loanFromClubId = parent.id
          ..loanEndDate = DateTime(clock, 6, 30)
          ..contractEndYear = clock + 2;
        gs.userTeam.players.add(loanee);
        final oldFree = [
          for (var i = 0; i < 10; i++)
            PlayerGenerator.generate(
                position: Position.mc, strengthTier: 30, ageOverride: 40),
        ];
        s.freeAgents.addAll(oldFree);
        s.today = DateTime(clock, 5, 31);
        s.preContractOpenedSeason = s.league.season;
        s.optionDeadlineSeason = s.league.season;

        await gs.startNextSeason();

        expect(s.retiredLegends, isNot(contains(loanee)));
        expect(gs.lastRetirements, isNot(contains(loanee.name)));
        expect(gs.userTeam.players, isNot(contains(loanee)));
        expect(gs.lastLoanEndings, contains(loanee.name));
        expect(gs.lastContractExpirations, isNot(contains(loanee.name)));
        final news = s.newsLog.map((n) => n.text).toList();
        expect(
            news.any((t) =>
                t.startsWith('ローン期間満了で貸し元へ復帰') && t.contains(loanee.name)),
            isTrue);
        expect(
            news.any((t) => t.startsWith('契約満了で退団') && t.contains(loanee.name)),
            isFalse);
        final left = oldFree.where(s.freeAgents.contains).length;
        expect(left, lessThanOrEqualTo(6), reason: '高齢の所属なしが引退していない');
      }
    });

    test('ローンを日付で片付けると、契約満了ではなくローンの一覧に入る', () async {
      final gs = await start();
      final parent =
          gs.save!.league.teams.firstWhere((t) => t.id != gs.save!.userTeamId);
      final p = PlayerGenerator.generate(
          position: Position.mc, strengthTier: 50, ageOverride: 25)
        ..isLoan = true
        ..loanFromClubId = parent.id
        ..loanEndDate = gs.today
        ..contractEndYear = Player.contractClockYear + 2;
      gs.userTeam.players.add(p);
      gs.debugSettleLoansByDate();
      expect(gs.userTeam.players, isNot(contains(p)));
      expect(gs.lastLoanEndings, [p.name]);
      expect(gs.lastContractExpirations, isEmpty);
      final shown = takeMatchdayNotices(gs);
      expect(shown.single.text, startsWith('ローン期間満了で貸し元へ復帰'));
    });
  });
}
