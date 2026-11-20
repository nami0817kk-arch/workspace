import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/summer_tournament.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_stub.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 誕生日で歳を取る・夏の代表の大会(合流の遅れ・価値の上昇)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('誕生日', () {
    test('誕生日は id から決まり、2月29日は無い', () {
      final ids = [for (var i = 0; i < 2000; i++) 'p$i'];
      final months = <int>{};
      for (final id in ids) {
        final a = PlayerGenerator.generate(position: Position.mc, strengthTier: 60)
          ..age = 20;
        final p = Player.fromJson(a.toJson()..['id'] = id);
        final q = Player.fromJson(a.toJson()..['id'] = id);
        expect((p.birthMonth, p.birthDay), (q.birthMonth, q.birthDay));
        expect(p.birthMonth == 2 && p.birthDay == 29, isFalse);
        months.add(p.birthMonth);
      }
      expect(months, hasLength(12), reason: '誕生日は1年じゅうに散らばる');
    });

    test('前の日を含まず、その日を含んで数える', () {
      final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
      final b = p.birthdayIn(2026);
      final dayBefore = DateTime(b.year, b.month, b.day - 1);
      expect(p.birthdaysBetween(dayBefore, b), 1);
      expect(p.birthdaysBetween(b, DateTime(b.year, b.month, b.day + 1)), 0);
      expect(p.birthdaysBetween(DateTime(2026, 7, 1), DateTime(2027, 7, 1)), 1);
      expect(p.birthdaysBetween(b, b), 0);
    });

    test('誕生日の前の日まで同じ歳で、誕生日に1つ増える', () async {
      final gs = GameState();
      await gs.startNewGame('誕生日FC');
      // 今日(7月1日)より後に今年の誕生日が来る選手。
      final p = gs.userTeam.players
          .firstWhere((p) => p.birthdayIn(2026).isAfter(gs.today));
      final age = p.age;
      final b = p.birthdayIn(2026);
      gs.debugAdvanceTodayTo(DateTime(b.year, b.month, b.day - 1));
      expect(p.age, age);
      gs.debugAdvanceTodayTo(b);
      expect(p.age, age + 1);
    });

    test('1シーズン回すと、どの選手もちょうど1つ歳を取る', () async {
      final gs = GameState();
      await gs.startNewGame('誕生日FC');
      final ages = {for (final p in gs.userTeam.players) p.id: p.age};
      final start = gs.today;
      final foreign = gs.save!.foreignLeagues.values.first.teams.first.players.first;
      final foreignAge = foreign.age;
      while (gs.save!.league.nextUnplayedFixture != null) {
        await gs.playNextMatchdayQuickSim();
      }
      await gs.startNextSeason();
      for (final p in gs.userTeam.players) {
        final before = ages[p.id];
        if (before == null) continue; // 新しく入った選手
        // 季の始まりの日は年によって1日ずれる。その隙間に誕生日がある選手は
        // この季には歳を取らず、次の季に取る。実際に通った誕生日の数だけ
        // 歳を取る(ほとんどの選手は1つ)。
        expect(p.age, before + p.birthdaysBetween(start, gs.today),
            reason: p.name);
        expect(p.birthdaysBetween(start, gs.today), lessThanOrEqualTo(1));
      }
      // 他の国の選手も、通った誕生日の数だけ歳を取る。
      expect(foreign.age, foreignAge + foreign.birthdaysBetween(start, gs.today));
    });
  });

  group('夏の大会', () {
    test('偶数年だけ大会があり、4年ごとにワールドカップ', () {
      expect(SummerTournament.of(2026)!.kind, SummerTournamentKind.worldCup);
      expect(SummerTournament.of(2027), isNull);
      expect(SummerTournament.of(2028)!.kind, SummerTournamentKind.continental);
      expect(SummerTournament.of(2030)!.kind, SummerTournamentKind.worldCup);
      final t = SummerTournament.of(2026)!;
      expect(t.returnDate,
          DateTime(2026, 7, 19 + SummerTournament.restDays));
    });

    test('出るのは代表の水準の選手だけで、結果は何度見ても同じ', () {
      final t = SummerTournament.of(2026)!;
      var played = 0;
      for (var i = 0; i < 300; i++) {
        final p = PlayerGenerator.generate(
            position: Position.st, strengthTier: 70 + i % 25);
        expect(t.plays(p), t.plays(p));
        if (p.overall < SummerTournament.minOverall) {
          expect(t.plays(p), isFalse);
          expect(t.boostPctFor(p), 0);
        }
        if (t.plays(p)) played++;
      }
      expect(played, greaterThan(0));
    });

    test('大会に出た自クラブの選手は合流の日まで出られず、その日に戻る',
        () async {
      final gs = GameState();
      await gs.startNewGame('大会FC');
      final t = SummerTournament.of(2026)!;
      // 下の部から始めると自クラブに代表の選手はいないので、上の部の
      // クラブで見る(合流は全クラブ同じ日)。
      final p = [
        for (final team in gs.save!.allTeams)
          for (final q in team.players)
            if (q.onTournamentLeave) q
      ].first;
      expect(t.plays(p), isTrue);
      expect(p.isOnInternationalDuty, isTrue);
      expect(gs.tournamentReturnDate, t.returnDate);

      final back = t.returnDate;
      gs.debugAdvanceTodayTo(DateTime(back.year, back.month, back.day - 1));
      expect(p.onTournamentLeave, isTrue);
      gs.debugAdvanceTodayTo(back);
      expect(p.onTournamentLeave, isFalse);
      expect(p.fatigue, greaterThanOrEqualTo(tournamentReturnFatigue));
      expect(gs.tournamentReturnDate, isNull);
    });

    test('活躍した選手は市場価値が上がり、次のシーズンの始まりで消える',
        () async {
      final gs = GameState();
      await gs.startNewGame('大会FC');
      final boosted = [
        for (final t in gs.save!.allTeams)
          for (final p in t.players)
            if (p.tournamentBoostPct > 0) p
      ];
      expect(boosted, isNotEmpty, reason: '上の部には大会で活躍した選手がいる');
      final p = boosted.first;
      final pct = p.tournamentBoostPct;
      final value = p.marketValue;
      p.tournamentBoostPct = 0;
      expect(value, greaterThan(p.marketValue));
      p.tournamentBoostPct = pct;

      while (gs.save!.league.nextUnplayedFixture != null) {
        await gs.playNextMatchdayQuickSim();
      }
      await gs.startNextSeason();
      // 2027年の夏は大会が無い。
      for (final t in gs.save!.allTeams) {
        for (final q in t.players) {
          expect(q.tournamentBoostPct, 0);
          expect(q.onTournamentLeave, isFalse);
        }
      }
    });

    test('大会の印は保存して読み戻せる(軽い形の保存でも)', () {
      final p = PlayerGenerator.generate(position: Position.dc, strengthTier: 80)
        ..tournamentBoostPct = 25
        ..onTournamentLeave = true;
      final q = Player.fromJson(p.toJson());
      expect(q.tournamentBoostPct, 25);
      expect(q.onTournamentLeave, isTrue);
      final r = PlayerStub.decode(PlayerStub.encode(p));
      expect(r.tournamentBoostPct, 25);
      expect(r.onTournamentLeave, isTrue);
      // 前の形(15項目)の軽い保存は、印なしで読む。
      final old = PlayerStub.decode(PlayerStub.encode(p).sublist(0, 15));
      expect(old.tournamentBoostPct, 0);
      expect(old.onTournamentLeave, isFalse);
    });
  });
}
