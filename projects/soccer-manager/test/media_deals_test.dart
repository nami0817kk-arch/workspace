import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/media_deals_engine.dart';
import 'package:soccer_manager/logic/money_calendar.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  // 2026-11-23: 放映権は国ごとのリーグの配分式(均等割+順位+中継回数)に
  // 一本化した。クラブが受け取り方を選んだり、前払いを受けたりはしない。
  group('放映権の配分式', () {
    test('国ごとの割合は合計1で、プレミアは均等50%・順位25%・中継25%', () {
      for (final t in LeagueTheme.values) {
        final s = MediaDealsEngine.sharesFor(t);
        expect(s.equal + s.merit + s.facility, closeTo(1, 1e-9),
            reason: t.name);
        expect(s.equal, greaterThanOrEqualTo(0.4), reason: t.name);
      }
      final en = MediaDealsEngine.sharesFor(LeagueTheme.england);
      expect(en.equal, 0.5);
      expect(en.merit, 0.25);
      expect(en.facility, 0.25);
    });

    test('順位と中継の倍率は、平均が1で上位ほど大きい', () {
      for (final n in [18, 20]) {
        var merit = 0.0, facility = 0.0;
        for (var r = 1; r <= n; r++) {
          merit += MediaDealsEngine.meritFactor(r, n);
          facility += MediaDealsEngine.facilityFactor(r, n);
        }
        expect(merit / n, closeTo(1, 1e-9));
        expect(facility / n, closeTo(1, 1e-9));
      }
      // プレミアと同じく、1位は最下位の20倍の口数。
      expect(MediaDealsEngine.meritFactor(1, 20),
          closeTo(MediaDealsEngine.meritFactor(20, 20) * 20, 1e-9));
    });

    test('上位ほど多く、1位と最下位の差は2倍前後(均等割があるので開きすぎない)', () {
      int total(int rank, [LeagueTheme t = LeagueTheme.england]) =>
          MediaDealsEngine.seasonTotal(
              tier: 1, rank: rank, teamCount: 20, theme: t);
      for (var r = 1; r < 20; r++) {
        expect(total(r), greaterThan(total(r + 1)), reason: '$r位');
      }
      expect(total(1) / total(20), inInclusiveRange(1.5, 2.6));
      for (final t in LeagueTheme.values) {
        expect(total(1, t) / total(20, t), inInclusiveRange(1.5, 2.6),
            reason: t.name);
      }
    });

    test('1クラブの平均は、放映権の年額の1.25倍(旧来の受け取りの平均と同じ)', () {
      for (final t in LeagueTheme.values) {
        var sum = 0;
        for (var r = 1; r <= 20; r++) {
          sum += MediaDealsEngine.seasonTotal(
              tier: 1, rank: r, teamCount: 20, theme: t);
        }
        expect(sum / 20, closeTo(annualBroadcast(1, t) * 1.25, 20 * 1.0),
            reason: t.name);
      }
    });

    test('4回の入金(最下位でも受け取る額)と季末の上乗せの合計が、その順位の総額', () {
      final g = MediaDealsEngine.guaranteedAnnual(tier: 1, teamCount: 20);
      expect(g, greaterThan(0));
      for (final r in [1, 10, 20]) {
        expect(
            g +
                MediaDealsEngine.seasonEndPayout(
                    tier: 1, rank: r, teamCount: 20),
            MediaDealsEngine.seasonTotal(tier: 1, rank: r, teamCount: 20));
      }
      expect(
          MediaDealsEngine.seasonEndPayout(tier: 1, rank: 20, teamCount: 20),
          0);
    });
  });

  group('命名権', () {
    test('候補は5・7・10年の3件で、長いほど年額がわずかに大きい', () {
      final o = MediaDealsEngine.namingOffers(
          stadiumLevel: 3, tier: 3, managerReputation: 50);
      expect(o.map((d) => d.yearsRemaining), [5, 7, 10]);
      expect(o[1].weeklyIncome, greaterThan(o[0].weeklyIncome));
      expect(o[2].weeklyIncome, greaterThan(o[1].weeklyIncome));
      // わずか: 10年でも5年の1.1倍。
      expect(o[2].weeklyIncome / o[0].weeklyIncome, closeTo(1.1, 0.02));
    });
  });

  group('ゲームの中', () {
    test('命名権を結ぶと週収入が増える', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      final save = gs.save!;
      save.pendingNamingOffers = MediaDealsEngine.namingOffers(
          stadiumLevel: 1, tier: 5, managerReputation: 50);
      final before = gs.weeklyIncomeFor(save.userTeamId);
      expect(await gs.chooseNamingRights(0), isTrue);
      expect(gs.weeklyIncomeFor(save.userTeamId), greaterThan(before));
      expect(save.pendingNamingOffers, isEmpty);
      final p = gs.weeklyIncomeParts(save.userTeamId);
      expect(p.gate + p.sponsor + p.merchandise + p.broadcast,
          gs.weeklyIncomeFor(save.userTeamId));
    });

    test('季末の上乗せは順位で決まり、放映権の記録に入る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      var guard = 0;
      while (gs.save!.league.nextUnplayedFixture != null && guard++ < 200) {
        await gs.playNextMatchdayQuickSim();
      }
      final s = gs.save!;
      final season = s.league.season;
      // 5月1日の4回目の入金まで済ませてから見る。
      gs.debugAdvanceTodayTo(MoneyCalendar.fiscalYearEnd(season));
      final rank = s.league.sortedStandings
              .indexWhere((r) => r.teamId == s.userTeamId) +
          1;
      final teamCount = s.league.teams.length;
      final tier = s.currentDivisionTier;
      final theme = gs.currentLeagueTheme;
      final before = s.ledgerFor(season).of(LedgerCategory.broadcast);
      await gs.startNextSeason();
      final after = s.ledgerFor(season).of(LedgerCategory.broadcast);
      expect(
          after - before,
          MediaDealsEngine.seasonEndPayout(
              tier: tier, rank: rank, teamCount: teamCount, theme: theme));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('旧セーブの受け取り方(tvDeal)は読まず、前払いの精算だけ残る', () async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      gs.save!.tvHolidaySeasons = 1;
      final json = gs.save!.toJson()..['tvDeal'] = 'performance';
      final back = SaveGame.fromJson(json);
      expect(back.tvHolidaySeasons, 1);
      expect(back.toJson().containsKey('tvDeal'), isFalse);
      json
        ..remove('namingDeal')
        ..remove('pendingNamingOffers');
      final old = SaveGame.fromJson(json);
      expect(old.namingDeal, isNull);
      expect(old.pendingNamingOffers, isEmpty);
    });
  });
}
