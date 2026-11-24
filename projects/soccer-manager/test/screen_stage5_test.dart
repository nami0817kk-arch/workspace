import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/league_stats.dart';
import 'package:soccer_manager/logic/season_analysis_engine.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/screens/reference_screens.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/cup_bracket.dart';
import 'package:soccer_manager/widgets/match_digest_dialog.dart';

/// 画面の直し 第5段(リーグ・試合のあと・お知らせ・資料)の中身の検査
/// (2026-11-25)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> played(int matchdays) async {
    final gs = GameState();
    await gs.startNewGame('第5段FC');
    for (var i = 0; i < matchdays; i++) {
      await gs.playNextMatchday();
      if (gs.isHalfTime) await gs.playSecondHalf();
    }
    return gs;
  }

  test('個人成績: 得点とアシストの合計は試合の出来事と一致し、採点は1〜10', () async {
    final gs = await played(5);
    final league = gs.save!.league;
    final stats = LeagueStats.compute(league);
    var goals = 0, assists = 0;
    for (final f in league.fixtures) {
      for (final e in f.result?.events ?? const <MatchEvent>[]) {
        if (e.type != MatchEventType.goal) continue;
        if (e.scorerId != null) goals++;
        if (e.assistId != null) assists++;
      }
    }
    expect(stats.lines.values.fold(0, (s, l) => s + l.goals), goals);
    expect(stats.lines.values.fold(0, (s, l) => s + l.assists), assists);
    for (final l in stats.lines.values.where((l) => l.apps > 0)) {
      expect(l.avgRating, inInclusiveRange(1.0, 10.0), reason: l.name);
    }
    // 得点の順位は多い順。
    final top = stats.top((l) => l.goals);
    for (var i = 1; i < top.length; i++) {
      expect(top[i - 1].goals, greaterThanOrEqualTo(top[i].goals));
    }
    // 自クラブの選手の成績表に、出場した選手が並ぶ。
    expect(stats.ofTeam(gs.userTeam.id), isNotEmpty);
  });

  test('シーズン分析: 得点と失点の形・相手の順位別は、通算と数が合う', () async {
    final gs = await played(6);
    final league = gs.save!.league;
    final id = gs.userTeam.id;
    final all = SeasonAnalysisEngine.record(league, id);
    final shapes = SeasonAnalysisEngine.goalShapes(league, id);
    // 得点者が分からない得点は形に入らないので、通算以下。
    expect(shapes.values.fold(0, (s, v) => s + v.$1),
        lessThanOrEqualTo(all.gf));
    expect(shapes.values.fold(0, (s, v) => s + v.$2),
        lessThanOrEqualTo(all.ga));
    final bands = SeasonAnalysisEngine.recordByOpponentRank(league, id);
    expect(bands.values.fold(0, (s, r) => s + r.played), all.played);
    expect(bands.values.fold(0, (s, r) => s + r.won), all.won);
  });

  test('パス成功率は同じ試合なら同じ値で、58〜93%に収まる', () async {
    final gs = await played(1);
    final f = gs.save!.league.fixtures.firstWhere((f) => f.result != null);
    final home =
        gs.save!.league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final a = passAccuracyOf(f.result!, home: true, team: home);
    expect(passAccuracyOf(f.result!, home: true, team: home), a);
    expect(a, inInclusiveRange(58, 93));
  });

  test('月ごとの資金と実績の日付は保存して読み戻せ、古いセーブは空で読める', () async {
    final gs = await played(0);
    final s = gs.save!
      ..fundsMonthEnds.add([2026 * 12 + 7, 12345])
      ..achievementDates['first_win'] = '2026-08-16';
    final back = SaveGame.fromJson(s.toJson());
    expect(back.fundsMonthEnds, [
      [2026 * 12 + 7, 12345]
    ]);
    expect(back.achievementDates['first_win'], '2026-08-16');
    final json = s.toJson()
      ..remove('fundsMonthEnds')
      ..remove('achievementDates');
    final old = SaveGame.fromJson(json);
    expect(old.fundsMonthEnds, isEmpty);
    expect(old.achievementDates, isEmpty);
  });

  test('収支の詳しい表は、試合がないうちは「まだ試合がありません」', () async {
    final gs = await played(0);
    expect(FinanceReportScreen.noMatchesYet(gs), isTrue);
    await gs.playNextMatchday();
    if (gs.isHalfTime) await gs.playSecondHalf();
    expect(FinanceReportScreen.noMatchesYet(gs), isFalse);
  });

  test('トーナメント表: まだ組まれていない回戦は半分ずつ「未定」で埋まる', () {
    final rounds = CupBracket.withPlaceholders([
      [for (var i = 0; i < 8; i++) const BracketTie(teamA: 'a', teamB: 'b')],
    ], 4);
    expect([for (final r in rounds) r.length], [8, 4, 2, 1]);
    expect(rounds.last.single.teamA, isNull);
  });
}
