import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 自動で何年も回して、数値が壊れていないかを測る(オーナー型の数値バランス)。
///
/// 何もしない(放置)オーナーでも、資金や期待が無限に増えたり、一瞬で
/// 尽きたりしないこと。結果の数字はログに出す(CI の出力で傾向を追える)。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> playSeason(GameState game) async {
    var guard = 0;
    while (!game.save!.league.isSeasonComplete && guard++ < 200) {
      if (game.saleReason != null) return;
      if (game.pendingOwnerEvent != null) await game.resolveOwnerEvent(0);
      if (game.pendingBoardReviewMessage != null) {
        await game.dismissBoardReview();
      }
      await game.playNextMatchdayQuickSim();
    }
  }

  test('放置で3シーズン回しても、資金と2つの期待が範囲内に収まる', () async {
    final game = GameState();
    await game.startNewGame('長期FC');
    final log = <String>[];
    for (var season = 1; season <= 3; season++) {
      await playSeason(game);
      final s = game.save!;
      log.add('S$season budget=${s.budget} fans=${s.confidence} '
          'share=${s.shareholderExpectation} sale=${game.saleReason}');
      expect(s.confidence, inInclusiveRange(0, 100), reason: log.join('\n'));
      expect(s.shareholderExpectation, inInclusiveRange(0, 100),
          reason: log.join('\n'));
      // 現実的な桁。放置で何億にも増えない・何十億の赤字にもならない。
      expect(s.budget, inInclusiveRange(-200000, 500000), reason: log.join('\n'));
      if (game.saleReason != null) break;
      await game.startNextSeason();
    }
    // ignore: avoid_print
    print('長期シミュレーション\n${log.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
