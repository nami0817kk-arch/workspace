import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('決めることが出るか、上限の節で止まる', () async {
    final gs = GameState();
    await gs.startNewGame('進むFC');
    // 始めはスポンサーを選んでいないので、1節も進まずに止まる。
    expect(gs.inboxActions, isNotEmpty);
    expect(await gs.advanceToNextDecision(), isEmpty);

    if (gs.pendingSponsorOffers.isNotEmpty) await gs.chooseSponsor(1);
    if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
    gs.save!.incomingOffers.clear();
    final before = gs.save!.league.fixtures.where((f) => f.result != null).length;
    final played = await gs.advanceToNextDecision();
    expect(played.length, lessThanOrEqualTo(GameStateRivals.advanceLimit));
    final after = gs.save!.league.fixtures.where((f) => f.result != null).length;
    expect(after, greaterThanOrEqualTo(before + played.length));
    // 止まったのは、決めることが出たか、上限まで進んだか、季が終わったか。
    expect(
        gs.inboxActions.isNotEmpty ||
            played.length == GameStateRivals.advanceLimit ||
            gs.save!.league.isSeasonComplete ||
            gs.save!.pendingBoardReviewMessage != null,
        isTrue);
  });
}
