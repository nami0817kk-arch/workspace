import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/season_review_engine.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/season_award.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/state/game_state.dart';

/// シーズンの振り返りの検査。
///
/// 成績はシーズン成績の画面に積まれるが、終わった瞬間に「今年はどうだったか」
/// を突きつける場所が無かった。順位ごとに言うことが変わること、閉じたら
/// 二度と出ないことを見る。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  SeasonRecord record({
    required int rank,
    int teamCount = 20,
    bool wonLeague = false,
    bool promoted = false,
    bool relegated = false,
    List<String> cups = const [],
  }) =>
      SeasonRecord(
        season: 1,
        clubName: '振り返りFC',
        leagueName: 'テストリーグ',
        divisionTier: 5,
        finalRank: rank,
        teamCount: teamCount,
        played: 38,
        won: 15,
        draw: 10,
        lost: 13,
        goalsFor: 50,
        goalsAgainst: 45,
        wonLeague: wonLeague,
        promoted: promoted,
        relegated: relegated,
        cupsWon: cups,
      );

  SaveGame emptySave() => SaveGame(
        clubName: '振り返りFC',
        userTeamId: 't0',
        league: League(teams: [], fixtures: []),
      );

  SaveGame saveWith(SeasonRecord r, {List<SeasonAward> awards = const []}) {
    final save = emptySave();
    save.seasonHistory.add(r);
    save.seasonAwards.addAll(awards);
    return save;
  }

  test('記録が無ければ振り返りは出ない', () {
    expect(SeasonReviewEngine.buildFor(emptySave()), isNull);
  });

  test('順位によって総括の言葉が変わる', () {
    final top = SeasonReviewEngine.buildFor(saveWith(record(rank: 3)))!;
    final mid = SeasonReviewEngine.buildFor(saveWith(record(rank: 10)))!;
    final bottom = SeasonReviewEngine.buildFor(saveWith(record(rank: 19)))!;

    expect({top.verdict, mid.verdict, bottom.verdict}.length, 3,
        reason: 'どの順位でも同じことを言っている');
  });

  test('優勝・昇格・降格は見出しとして立つ', () {
    expect(
        SeasonReviewEngine.buildFor(saveWith(record(rank: 1, wonLeague: true)))!
            .headline,
        isNotNull);
    expect(
        SeasonReviewEngine.buildFor(saveWith(record(rank: 2, promoted: true)))!
            .headline,
        isNotNull);
    expect(
        SeasonReviewEngine.buildFor(saveWith(record(rank: 19, relegated: true)))!
            .headline,
        isNotNull);
    // 何も無い年は見出しを作らない(無理に付けると意味が薄れる)。
    expect(SeasonReviewEngine.buildFor(saveWith(record(rank: 10)))!.headline,
        isNull);
  });

  test('成績と得点王が行として出る', () {
    final review = SeasonReviewEngine.buildFor(saveWith(
      record(rank: 4),
      awards: [
        SeasonAward(
          season: 1,
          topScorerName: '得点 太郎',
          topScorerGoals: 22,
        ),
      ],
    ))!;

    expect(review.lines.any((l) => l.contains('15勝')), isTrue);
    expect(review.lines.any((l) => l.contains('得点 太郎')), isTrue);
  });

  test('閉じると、そのシーズンの振り返りは二度と出ない', () async {
    final game = GameState();
    await game.startNewGame('閉じるFC');
    game.save!.seasonHistory.add(record(rank: 8));

    expect(game.save!.lastReviewedSeason, lessThan(1));
    game.markSeasonReviewSeen();
    expect(game.save!.lastReviewedSeason, 1);
  });
}
