import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/background_match_engine.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/player_terms_engine.dart';
import 'package:soccer_manager/logic/pre_contract_engine.dart';
import 'package:soccer_manager/logic/season_calendar.dart';
import 'package:soccer_manager/logic/transfer_terms_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/match_widgets.dart';

import 'support/legacy_market.dart';

/// 試合とお金の残り(2026-11-22)の挙動を固定する。
/// 1. 年俸の国差  2. 代理人手数料を簿価に入れる  3. 他の部・他国の試合の
/// 警告・退場・交代  4. 代表から戻ったときの疲れと怪我  5. 交代を試合経過に出す
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // 年俸の水準は国・部の全体の設定なので、テストごとに戻す。
  tearDown(() => setHomeWageLevel(LeagueTheme.england, 1));

  Team squad(String id, {int tier = 60}) {
    final t =
        PlayerGenerator.generateSquad(id: id, name: id, strengthTier: tier);
    LineupUtils.autoFill(t);
    return t;
  }

  bool canPlay(Player p) =>
      !p.isInjured &&
      !p.isSuspended &&
      !p.isOnInternationalDuty &&
      !p.isLoanedOut &&
      !p.notRegistered;

  group('1. 年俸の国差', () {
    test('どの部でもイングランドが一番高く、1部はフランスが一番低い。放映権の差よりゆるめ', () {
      for (var tier = 1; tier <= 3; tier++) {
        for (final t in LeagueTheme.values) {
          expect(wageCountryFactor(t, tier),
              lessThanOrEqualTo(wageCountryFactor(LeagueTheme.england, tier)),
              reason: '${t.name} $tier部');
          // イングランドとの差は、放映権の差より小さい(イングランドの2部は
          // 0.9 なので、他国は比で見る)。
          expect(
              wageCountryFactor(t, tier) /
                  wageCountryFactor(LeagueTheme.england, tier),
              greaterThanOrEqualTo(broadcastCountryFactor(t, tier)),
              reason: '${t.name} $tier部: 放映権の差より大きい');
        }
      }
      final tier1 = [
        for (final t in LeagueTheme.values) wageCountryFactor(t, 1)
      ];
      expect(wageCountryFactor(LeagueTheme.france, 1), tier1.reduce(min));
      expect(wageCountryFactor(LeagueTheme.england, 1), 1.0);
    });

    test('年俸の式に国・部の水準を掛ける(既定は自クラブのいる国・部)', () {
      setHomeWageLevel(LeagueTheme.england, 1);
      final en = annualWageForValue(100000);
      expect(annualWageForValue(100000, 0.45), closeTo(en * 0.45, 2));
      setHomeWageLevel(LeagueTheme.france, 1);
      expect(currentWageLevel, wageCountryFactor(LeagueTheme.france, 1));
      expect(annualWageForValue(100000), closeTo(en * 0.45, 2));
      expect(weeklyWageForValue(100), minWeeklyWage);
      // 他の国・部の選手を作る間だけ差し替え、戻す。
      final inner = withWageLevel(0.62, () => currentWageLevel);
      expect(inner, 0.62);
      expect(currentWageLevel, wageCountryFactor(LeagueTheme.france, 1));
    });

    test('市場価値は国で変えない(同じ選手は同じ価値で、年俸だけが下がる)', () {
      Player make(double level) => withWageLevel(
          level,
          () => PlayerGenerator.withSeed(
              7,
              () => PlayerGenerator.generate(
                  position: Position.mc, strengthTier: 80)));
      final en = make(1.0);
      final fr = make(wageCountryFactor(LeagueTheme.france, 1));
      expect(fr.marketValue, en.marketValue);
      expect(fr.wage / en.wage, closeTo(0.45, 0.02));
    });

    // 年俸の合計 ÷ 能力と経験に見合う年俸(イングランドの水準)の合計。作った
    // あとで価値が少し動く選手がいるので、イングランドの1部との比で見る。
    double level(Iterable<Team> teams) {
      var wages = 0, base = 0;
      for (final t in teams) {
        for (final p in t.players) {
          wages += p.wage;
          base += p.fairWeeklyWage(1.0);
        }
      }
      return wages / base;
    }

    test('新しいゲームのクラブの年俸は、そのクラブのいる国・部の水準', () async {
      final game = GameState();
      await game.startNewGame('年俸FC');
      final s = game.save!;
      final en = level(s.otherDivisionLeagues[0]!.teams);
      expect(en, closeTo(1.0, 0.08), reason: 'イングランドの1部');
      for (final theme in [
        LeagueTheme.spain,
        LeagueTheme.germany,
        LeagueTheme.italy,
        LeagueTheme.france,
      ]) {
        expect(level(s.foreignLeagues[theme.name]!.teams) / en,
            closeTo(wageCountryFactor(theme, 1), 0.04),
            reason: '${theme.name}の1部');
      }
    });

    test('フランスで始めると、2部・3部もフランスのその部の水準', () async {
      final game = GameState();
      await game.startNewGame('年俸FC', theme: LeagueTheme.france);
      final s = game.save!;
      expect(currentWageLevel, wageCountryFactor(LeagueTheme.france, 3));
      final en = level(s.foreignLeagues['england']!.teams);
      for (var tier = 1; tier <= 3; tier++) {
        final teams = tier == s.currentDivisionTier
            ? s.league.teams
            : s.otherDivisionLeagues[tier - 1]!.teams;
        expect(level(teams) / en,
            closeTo(wageCountryFactor(LeagueTheme.france, tier), 0.05),
            reason: '$tier部');
      }
    });

    test('国をまたいで移るときは、行き先の国の水準で求める', () {
      setHomeWageLevel(LeagueTheme.spain, 1);
      final scale = wageScaleToHome('france');
      expect(scale, closeTo(0.7 / 0.45, 1e-9));
      expect(wageScaleToHome('spain'), 1.0);
      expect(wageScaleToHome(null), 1.0);
      // 今の週俸(フランスの水準)を、行き先(スペイン)の水準に直して求める。
      final plain = PlayerTermsEngine.demand(
        currentWage: 1000,
        fairWage: 5,
        fromTier: 1,
        toTier: 1,
        wasStarter: false,
        wouldStart: true,
      );
      final converted = PlayerTermsEngine.demand(
        currentWage: 1000,
        fairWage: 5,
        fromTier: 1,
        toTier: 1,
        wasStarter: false,
        wouldStart: true,
        currentWageScale: scale,
      );
      expect(converted, closeTo(plain * scale, 2));
    });

    test('他国のクラブから買うと、週俸がこちらの国の水準に直る', () async {
      final game = GameState();
      await game.startNewGame('年俸FC', theme: LeagueTheme.spain);
      final s = game.save!
        ..budget = 99999999
        ..wageBudget = 99999999;
      // 18歳未満・EU の外の選手は登録の決まりで弾かれることがあるので、
      // 買えるまで探す。
      final french = s.foreignLeagues['france']!.teams;
      final scale = wageScaleToHome('france');
      for (final t in french) {
        final ps = [...t.players]..sort((a, b) => b.age.compareTo(a.age));
        for (final p in ps) {
          if (p.age < 20 || p.isLoan) continue;
          final before = p.wage;
          if (!await game.buyPlayer(p.id)) continue;
          expect(p.wage, (before * scale).round(), reason: 'フランスの水準のまま来た');
          return;
        }
      }
      fail('買える選手がいない: ${game.lastSigningBlockReason}');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('仮契約の要求も、他国の選手は今の週俸をこちらの水準に直して求める', () async {
      final game = GameState();
      await game.startNewGame('年俸FC', theme: LeagueTheme.france);
      final p = game.save!.foreignLeagues['england']!.teams.first.players
          .firstWhere((p) => p.wage > p.fairWeeklyWage() + 5);
      // イングランドの1部からフランスの3部へ: 今の週俸は水準の比の倍に直る。
      final scale = wageCountryFactor(LeagueTheme.france, 3) /
          wageCountryFactor(LeagueTheme.england, 1);
      expect(game.preContractWageDemand(p),
          PreContractEngine.wageDemand(p, currentWageScale: scale));
      expect(game.preContractWageDemand(p),
          lessThan(PreContractEngine.wageDemand(p)));
    });
  });

  group('2. 代理人手数料を移籍の資産(簿価)に入れる', () {
    Future<GameState> newGame() async {
      final gs = GameState();
      await gs.startNewGame('簿価FC');
      gs.save!
        ..budget = 10000000
        ..wageBudget = 99999999;
      return gs;
    }

    test('買うと、移籍金と代理人手数料の合計が簿価になり、その季の費用にはならない', () async {
      final gs = await newGame();
      final p = legacyMarket(gs).first;
      final fee = p.marketValue;
      final agent = TransferTermsEngine.agentFee(fee);
      expect(await gs.buyPlayer(p.id), isTrue,
          reason: '${gs.lastSigningBlockReason}');
      final l = gs.currentLedger;
      expect(gs.bookValueOf(p.id), fee + agent);
      expect(l.of(LedgerCategory.transferFees), -(fee + agent));
      expect(l.of(LedgerCategory.transfers), 0, reason: '代理人手数料を費用にした');
      expect(l.of(LedgerCategory.amortization), 0);
    });

    test('契約の年数で、代理人手数料も含めてちょうど全額を償却する', () async {
      final gs = await newGame();
      final p = legacyMarket(gs).first;
      final cost = p.marketValue + TransferTermsEngine.agentFee(p.marketValue);
      expect(await gs.buyPlayer(p.id), isTrue);
      final bought = gs.userTeam.players.firstWhere((x) => x.id == p.id);
      final years = bought.contractEndYear - Player.contractClockYear + 1;
      final start = Player.contractClockYear;
      var total = 0;
      for (var y = 0; y < years; y++) {
        final before = gs.currentLedger.of(LedgerCategory.amortization);
        gs.debugAmortizeTransferFees();
        total += before - gs.currentLedger.of(LedgerCategory.amortization);
        Player.contractClockYear += 1;
      }
      Player.contractClockYear = start;
      expect(total, cost);
    });

    test('分割払いでも、移籍金の総額と代理人手数料が簿価になる', () async {
      final gs = await newGame();
      final p = legacyMarket(gs).first;
      final fee = p.marketValue;
      expect(await gs.buyPlayerOnInstallments(p.id), isTrue);
      expect(gs.bookValueOf(p.id), fee + TransferTermsEngine.agentFee(fee));
    });

    test('所属なしの選手: 代理人手数料は簿価に、サイン料は費用のまま', () async {
      final gs = await newGame();
      final fa = gs.save!.freeAgents.first;
      final bonus = gs.freeAgentSigningFeeFor(fa);
      final agent = gs.freeAgentAgentFeeFor(fa, fa.wage);
      expect(await gs.signFreeAgent(fa.id), isTrue,
          reason: '${gs.lastSigningBlockReason}');
      final l = gs.currentLedger;
      expect(gs.bookValueOf(fa.id), agent);
      expect(l.of(LedgerCategory.transfers), -bonus, reason: 'サイン料は費用');
      expect(l.of(LedgerCategory.transferFees), -agent);
    });
  });

  group('3. 他の部・他国の試合にも警告・退場・交代', () {
    test('1試合の警告は平均 3.5〜5枚、退場は 0.05〜0.35', () {
      const n = 400;
      var cards = 0, suspensions = 0;
      final rng = Random(3);
      for (var i = 0; i < n; i++) {
        final home = squad('h$i');
        final away = squad('a$i');
        BackgroundMatchEngine.applyPlayerEffects(
            home: home, away: away, random: rng);
        for (final p in [...home.players, ...away.players]) {
          cards += p.yellowCards + p.suspendedMatches;
          suspensions += p.suspendedMatches;
        }
      }
      // 警告(退場になった2枚目・一発退場も1枚と数える)。
      expect(cards / n, inInclusiveRange(3.5, 5.0));
      expect(suspensions / n, inInclusiveRange(0.05, 0.35));
    });

    test('先発11人と控えの3〜5人に出場が付き、出場停止は試合に出ずに1つ消化する', () {
      final rng = Random(5);
      for (var i = 0; i < 30; i++) {
        final home = squad('h$i');
        final away = squad('a$i');
        final banned = MatchEngine.lineupOf(home).first..suspendedMatches = 1;
        final starters = MatchEngine.lineupOf(home).length;
        final before = {
          for (final p in home.players) p.id: p.careerAppearances
        };
        BackgroundMatchEngine.applyPlayerEffects(
            home: home, away: away, random: rng);
        expect(banned.careerAppearances, before[banned.id],
            reason: '出場停止の選手が出た');
        expect(banned.suspendedMatches, 0, reason: '出場停止を消化していない');
        final played = home.players
            .where((p) => p.careerAppearances > before[p.id]!)
            .length;
        expect(played - starters, inInclusiveRange(3, 5), reason: '控えの出場');
      }
    });

    test('警告が5枚たまると、次の試合は出場停止', () {
      final rng = Random(11);
      for (var i = 0; i < 200; i++) {
        final home = squad('h$i');
        final away = squad('a$i');
        final lineup = MatchEngine.lineupOf(home);
        for (final p in lineup) {
          p.yellowCards = 4;
        }
        BackgroundMatchEngine.applyPlayerEffects(
            home: home, away: away, random: rng);
        // 警告は今季の枚数として数え続ける(5枚目で出場停止。2026-11-23)。
        final hit = lineup.where((p) => p.yellowCards == 5).toList();
        if (hit.isEmpty) continue;
        for (final p in hit) {
          expect(p.suspendedMatches, greaterThanOrEqualTo(1));
        }
        return;
      }
      fail('5枚目の警告が一度も出なかった');
    });

    test('ゲームを進めると、他の部・他国の選手にも出場と警告が付く', () async {
      final game = GameState();
      await game.startNewGame('裏FC');
      for (var i = 0; i < 3; i++) {
        await game.playNextMatchdayQuickSim();
      }
      final s = game.save!;
      final others = [
        for (final l in s.otherDivisionLeagues)
          if (l != null) ...l.teams,
      ];
      final foreign = [for (final l in s.foreignLeagues.values) ...l.teams];
      for (final (label, teams) in [('他の部', others), ('他国', foreign)]) {
        final players = [for (final t in teams) ...t.players];
        expect(players.where((p) => p.careerAppearances > 0), isNotEmpty,
            reason: '$labelの選手に出場が付かない');
        expect(
            players.where((p) => p.yellowCards > 0 || p.suspendedMatches > 0),
            isNotEmpty,
            reason: '$labelの選手に警告が付かない');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('4. 代表から戻ったときの疲れと怪我', () {
    tearDown(() => GameStateTransfer.internationalReturnRng = Random());

    Future<GameState> gameOutsideWindow() async {
      final game = GameState();
      await game.startNewGame('代表FC');
      final sat =
          SeasonCalendar.internationalSaturdays(game.save!.league.season).first;
      game.save!.today = DateTime(sat.year, sat.month, sat.day + 10);
      expect(game.seasonCalendar.isInternationalWindow(game.today), isFalse);
      return game;
    }

    test('戻った選手は疲れが8〜15増え、呼ばれていない選手は変わらない', () async {
      final game = await gameOutsideWindow();
      final team = game.userTeam;
      final called = team.players.first
        ..internationalDutyWeeksRemaining = 1
        ..fatigue = 10;
      final stayed = team.players.last..fatigue = 10;
      game.debugReleaseInternationalDuty();
      expect(called.isOnInternationalDuty, isFalse);
      expect(called.fatigue, inInclusiveRange(18, 25));
      expect(stayed.fatigue, 10);
      // もう一度呼んでも二重に足さない。
      final f = called.fatigue;
      game.debugReleaseInternationalDuty();
      expect(called.fatigue, f);
    });

    test('代表ウィークの途中の週の処理で戻る選手にも、疲れを足す', () async {
      final game = GameState();
      await game.startNewGame('代表FC');
      final sat =
          SeasonCalendar.internationalSaturdays(game.save!.league.season).first;
      // 代表ウィークの2週目(新しくは呼ばない)。
      game.save!.today = DateTime(sat.year, sat.month, sat.day + 3);
      final p = game.userTeam.players.first
        ..internationalDutyWeeksRemaining = 1
        ..fatigue = 0;
      game.debugAdvanceInternationalDuty();
      expect(p.internationalDutyWeeksRemaining, 0);
      expect(p.fatigue, inInclusiveRange(8, 15));
    });

    test('呼ばれた選手の約2.5%が軽い怪我(打撲・肉離れ、1〜2週)で戻る', () async {
      GameStateTransfer.internationalReturnRng = Random(17);
      var called = 0, injured = 0;
      for (var g = 0; g < 2; g++) {
        final game = await gameOutsideWindow();
        for (final t in game.save!.league.teams) {
          for (final p in t.players) {
            p
              ..injuryWeeks = 0
              ..injuryType = null
              ..internationalDutyWeeksRemaining = 1;
          }
        }
        game.debugReleaseInternationalDuty();
        for (final t in game.save!.league.teams) {
          for (final p in t.players) {
            called++;
            if (!p.isInjured) continue;
            injured++;
            expect(p.injuryType, anyOf(InjuryType.bruise, InjuryType.muscle));
            expect(p.injuryWeeks, inInclusiveRange(1, 2));
          }
        }
      }
      expect(injured / called, inInclusiveRange(0.012, 0.04),
          reason: '$injured / $called');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('自クラブの選手が代表で怪我をすると、ニュースに出て先発から外れる', () async {
      GameStateTransfer.internationalReturnRng = _AlwaysLow();
      Tr.language = AppLanguage.japanese;
      addTearDown(() => Tr.language = AppLanguage.system);
      final game = await gameOutsideWindow();
      final team = game.userTeam;
      final p = team.players.firstWhere((x) => team.startingXI.contains(x.id))
        ..injuryWeeks = 0
        ..injuryType = null
        ..internationalDutyWeeksRemaining = 1;
      game.debugReleaseInternationalDuty();
      expect(p.isInjured, isTrue);
      expect(team.startingXI, isNot(contains(p.id)));
      expect(game.save!.newsLog.first.text, contains(p.name));
      expect(game.save!.newsLog.first.text, contains('代表'));
    });
  });

  group('5. 交代を試合経過に出す', () {
    test('CPU 同士の試合: 交代が「入った・下がった」の出来事になり、出場とつじつまが合う', () {
      var seen = 0;
      for (var i = 0; i < 40; i++) {
        final home = squad('h$i');
        final away = squad('a$i');
        for (final p in MatchEngine.lineupOf(home)) {
          p.fatigue = 90;
        }
        final starters = MatchEngine.lineupOf(home).map((p) => p.id).toSet();
        final r = MatchEngine.simulate(home: home, away: away, matchday: 1);
        final subs = r.events
            .where((e) =>
                e.type == MatchEventType.substitution && e.teamId == home.id)
            .toList();
        expect(subs.length, lessThanOrEqualTo(substitutionsPerMatch));
        for (final e in subs) {
          expect(starters.contains(e.assistId), isTrue, reason: '下がったのが先発でない');
          expect(starters.contains(e.scorerId), isFalse, reason: '入ったのが先発');
          expect(e.minute == 46 || (e.minute >= 60 && e.minute <= 75), isTrue,
              reason: '${e.minute}分');
        }
        // 分の順に並んでいる。
        for (var k = 1; k < r.events.length; k++) {
          expect(
              r.events[k].minute, greaterThanOrEqualTo(r.events[k - 1].minute));
        }
        seen += subs.length;
      }
      expect(seen, greaterThan(0));
    });

    test('交代は採点・得点の数に響かない', () {
      final home = squad('h');
      final away = squad('a');
      final lineup = MatchEngine.lineupOf(home);
      final sub = MatchEngine.substitutionEvent(
          minute: 60,
          teamId: home.id,
          out: lineup.last,
          incoming: home.players.firstWhere((p) => !lineup.contains(p)));
      final a = MatchEngine.computePlayerRatings(
          home: home, away: away, events: const [], homeGoals: 0, awayGoals: 0);
      final b = MatchEngine.computePlayerRatings(
          home: home, away: away, events: [sub], homeGoals: 0, awayGoals: 0);
      expect(b, a);
    });

    test('試合経過の文: 「交代: 下がった → 入った」', () {
      final e = MatchEvent(
        minute: 63,
        teamId: 't',
        type: MatchEventType.substitution,
        scorerName: 'B',
        scorerId: 'b',
        assistName: 'A',
        assistId: 'a',
      );
      Tr.language = AppLanguage.japanese;
      expect(matchCommentaryText(e, 'FC'), '交代: A → B');
      Tr.language = AppLanguage.english;
      expect(matchCommentaryText(e, 'FC'), 'Substitution: A → B');
      Tr.language = AppLanguage.system;
    });

    test('保存して読み直しても交代が残り、古いセーブの出来事はそのまま読める', () {
      final e = MatchEvent(
        minute: 70,
        teamId: 't',
        type: MatchEventType.substitution,
        scorerName: 'B',
        scorerId: 'b',
        assistName: 'A',
        assistId: 'a',
      );
      final back = MatchEvent.fromJson(
          jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
      expect(back.type, MatchEventType.substitution);
      expect(back.scorerId, 'b');
      expect(back.assistId, 'a');
      // 古いセーブの出来事(交代の無い頃の形)。
      for (final t in ['goal', 'chance', 'yellowCard', 'redCard']) {
        final old = MatchEvent.fromJson({
          'minute': 10,
          'teamId': 't',
          'scorerName': 'X',
          'scorerId': 'x',
          'type': t,
          'assistName': null,
          'assistId': null,
        });
        expect(old.type.name, t);
      }
    });

    test('結果だけ見る自クラブの試合: 自動の交代が結果の出来事に入る', () async {
      final game = GameState();
      await game.startNewGame('交代FC');
      await game.playNextMatchday();
      expect(game.isHalfTime, isTrue);
      final team = game.userTeam;
      final lineup = MatchEngine.lineupOf(team);
      final onPitch = lineup.map((p) => p.id).toSet();
      for (final p in team.players) {
        p.fatigue = 0;
      }
      final tired = lineup.firstWhere((p) => p.position != Position.gk)
        ..fatigue = 95;
      final bench =
          team.players.firstWhere((p) => !onPitch.contains(p.id) && canPlay(p))
            ..position = tired.position
            ..secondaryPositions = []
            ..attributes = {for (final k in AttributeKeys.all) k: 99};
      final result = await game.playSecondHalf();
      expect(result, isNotNull);
      final subs = result!.events
          .where((e) =>
              e.type == MatchEventType.substitution && e.teamId == team.id)
          .toList();
      expect(subs.any((e) => e.assistId == tired.id && e.scorerId == bench.id),
          isTrue,
          reason: '自動の交代が試合経過に出ていない');
      expect(subs.first.minute, 46);
    });

    test('ライブ観戦: ハーフタイムと試合中の手動の交代が試合経過に出る', () async {
      final game = GameState();
      await game.startNewGame('交代FC');
      await game.playNextMatchday(interactive: true);
      // 前半の判断の場面で1人替える。
      String? liveOut;
      if (game.pendingChanceDecision != null && !game.isHalfTime) {
        final team = game.userTeam;
        final lineup = MatchEngine.lineupOf(team);
        final onPitch = lineup.map((p) => p.id).toSet();
        outer:
        for (final out in lineup.where((p) => p.position != Position.gk)) {
          for (final incoming in team.players
              .where((p) => !onPitch.contains(p.id) && canPlay(p))) {
            if (game.makeLiveSubstitution(
                outPlayerId: out.id, inPlayerId: incoming.id)) {
              liveOut = out.id;
              break outer;
            }
          }
        }
        expect(
            game.liveFirstHalfEventsSoFar.where((e) =>
                e.type == MatchEventType.substitution && e.assistId == liveOut),
            isNotEmpty,
            reason: '試合中の交代が前半の試合経過に出ていない');
      }
      while (game.pendingChanceDecision != null && !game.isHalfTime) {
        await game.resolveChanceDecision(ChanceDecision.shoot);
      }
      expect(game.isHalfTime, isTrue);
      final team = game.userTeam;
      final lineup = MatchEngine.lineupOf(team);
      final onPitch = lineup.map((p) => p.id).toSet();
      final out = lineup.firstWhere((p) => p.position != Position.gk);
      final incoming =
          team.players.firstWhere((p) => !onPitch.contains(p.id) && canPlay(p));
      expect(
          game.makeHalfTimeSubstitution(
              outPlayerId: out.id, inPlayerId: incoming.id),
          isTrue);
      MatchResult? result = await game.playSecondHalf(interactive: true);
      while (result == null) {
        final r = await game.resolveChanceDecision(ChanceDecision.shoot);
        result = r.merged;
      }
      final subs = result.events
          .where((e) => e.type == MatchEventType.substitution)
          .toList();
      expect(
          subs.any((e) =>
              e.minute == 46 &&
              e.assistId == out.id &&
              e.scorerId == incoming.id),
          isTrue,
          reason: 'ハーフタイムの交代が試合経過に出ていない');
      if (liveOut != null) {
        expect(subs.any((e) => e.assistId == liveOut && e.minute <= 45), isTrue,
            reason: '前半の交代が結果に残っていない');
      }
      // 交代は今季の成績(得点・カード)に数えない。
      final stats = game.seasonStatsFor(incoming.id);
      expect(
          stats.goals,
          result.events
              .where((e) =>
                  e.type == MatchEventType.goal && e.scorerId == incoming.id)
              .length);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

/// いつも小さい値を返す乱数(代表の怪我を必ず起こす)。
class _AlwaysLow implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.0;
  @override
  int nextInt(int max) => 0;
}
