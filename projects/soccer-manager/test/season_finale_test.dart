import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';

/// 節目の演出（昇格・優勝の絵）を出す判定の検査。
///
/// 絵は `lastSeasonFinale` だけを見て出す。ここがずれると、昇格して
/// いないのに昇格の絵が出る／優勝したのに何も出ない、という形で壊れる。
/// **どちらも例外を出さない**ので、機械で見ておく。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> playOutSeason(GameState game) async {
    while (!game.save!.league.isSeasonComplete) {
      await game.playNextMatchday();
      if (game.isHalfTime) await game.playSecondHalf();
      if (game.pendingBoardReviewMessage != null) {
        await game.dismissBoardReview();
      }
    }
  }

  test('初期状態では演出を出さない', () async {
    final game = GameState();
    await game.startNewGame('節目FC');
    expect(game.lastSeasonFinale, SeasonFinale.none);
  });

  test('シーズンを終えると、順位とディビジョンの動きに一致する', () async {
    // 優勝するかどうかは乱数次第なので、結果は決め打ちできない。
    // 「出た結果と、出そうとしている絵が食い違っていないこと」を見る。
    final game = GameState();
    await game.startNewGame('節目FC');
    await playOutSeason(game);

    final finalRank = game.save!.league.sortedStandings
            .indexWhere((r) => r.teamId == game.save!.userTeamId) +
        1;
    final tierBefore = game.save!.currentDivisionTier;

    await game.startNextSeason();

    final tierAfter = game.save!.currentDivisionTier;
    final expected = finalRank == 1
        ? SeasonFinale.champion
        : (tierAfter < tierBefore ? SeasonFinale.promoted : SeasonFinale.none);
    expect(game.lastSeasonFinale, expected,
        reason: '最終$finalRank位 / $tierBefore部→$tierAfter部 と、'
            '出そうとしている絵が食い違っている');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('優勝の判定が昇格より先に来ている', () {
    // 優勝すればたいてい昇格もしている。両方に当てはまるときに見せたいのは
    // 優勝のほうで、昇格の絵を出すと格落ちして見える。順序を固定する。
    final source =
        File('lib/state/game_state_season.dart').readAsStringSync();
    final at = source.indexOf('lastSeasonFinale =');
    expect(at, greaterThan(0), reason: 'lastSeasonFinale を決めている場所が無い');
    final decision = source.substring(at, at + 220);
    final champion = decision.indexOf('SeasonFinale.champion');
    final promoted = decision.indexOf('SeasonFinale.promoted');
    expect(champion, greaterThan(0));
    expect(promoted, greaterThan(0));
    expect(champion, lessThan(promoted), reason: '昇格の判定が優勝より先に来ている');
  });

  test('出す絵のファイルが実際にある', () {
    // パスを打ち間違えても、Image.asset は画面に赤い枠を出すだけで
    // テストは落ちない。節目でそれが出ると台無しなので、ここで見る。
    for (final name in const ['promotion.jpg', 'championship.jpg']) {
      expect(File('assets/art/$name').existsSync(), isTrue,
          reason: 'assets/art/$name が無い');
    }
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    for (final name in const ['promotion.jpg', 'championship.jpg']) {
      expect(home, contains('assets/art/$name'),
          reason: '$name を出す側のコードが無い');
    }
    // タイトル画面の絵も同じ理由で見ておく。
    expect(File('assets/art/title_bg.jpg').existsSync(), isTrue);
    expect(File('lib/screens/start_screen.dart').readAsStringSync(),
        contains('assets/art/title_bg.jpg'));
    // pubspec に登録していないと、実機でだけ出なくなる。
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/art/'));
  });
}
