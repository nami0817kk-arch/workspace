import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('probe: 一括シミュレーション中に取り逃す判断', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    final seenOffers = <String, int>{};   // id -> 金額
    final expired = <String, int>{};
    int sponsorWindows = 0;
    int boardMsgs = 0;

    for (int i = 0; i < 20; i++) {
      if (game.save == null || game.save!.league.isSeasonComplete) break;
      final r = await game.playNextMatchdayQuickSim();
      if (r == null) break;
      final now = {for (final o in game.save!.incomingOffers) o.id: o.amount};
      for (final e in now.entries) { seenOffers[e.key] = e.value; }
      for (final id in seenOffers.keys) {
        if (!now.containsKey(id) && !expired.containsKey(id)) {
          expired[id] = seenOffers[id]!;
        }
      }
      if (game.save!.pendingSponsorOffers.isNotEmpty) sponsorWindows++;
      if (game.save!.pendingBoardReviewMessage != null) boardMsgs++;
    }

    print('PROBE 届いた移籍オファー: ${seenOffers.length}件');
    print('PROBE 見ないまま消えた  : ${expired.length}件  総額 ${expired.values.fold(0,(a,b)=>a+b)}');
    for (final e in expired.entries) { print('PROBE   期限切れ ${e.key} 金額${e.value}'); }
    print('PROBE スポンサー提示が出ていた節数: $sponsorWindows');
    print('PROBE 理事会メッセージ保留の節数  : $boardMsgs');
    print('PROBE ニュース件数: ${game.save!.newsLog.length}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
