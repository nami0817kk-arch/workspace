import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> withRumor() async {
    final gs = GameState();
    await gs.startNewGame('噂FC');
    gs.debugRaiseRumor();
    expect(gs.save!.pendingRumor, isNotNull);
    expect(gs.inboxActions.any((a) => a.contains(gs.save!.pendingRumor![1])),
        isTrue);
    return gs;
  }

  test('売らないと言うと本人は落ち着き、同じ季に売るとサポーターが怒る', () async {
    final gs = await withRumor();
    final s = gs.save!;
    final id = s.pendingRumor![0];
    final p = gs.userTeam.players.firstWhere((x) => x.id == id);
    p.happiness = 50;
    final conf = s.confidence;
    expect(await gs.answerRumor(RumorAnswer.deny), isTrue);
    expect(p.happiness, 60);
    expect(s.confidence, conf + 2);
    expect(s.pendingRumor, isNull);
    expect(s.rumorDenied[id], s.league.season);

    // 保存して読み戻せる。
    expect(SaveGame.fromJson(s.toJson()).rumorDenied[id], s.league.season);
  });

  test('条件しだいと話すと、そのクラブからオファーが来る', () async {
    final gs = await withRumor();
    final s = gs.save!;
    final r = [...s.pendingRumor!];
    expect(await gs.answerRumor(RumorAnswer.open), isTrue);
    final o = s.incomingOffers.where((o) => o.playerId == r[0]).toList();
    expect(o, isNotEmpty);
    expect(o.first.buyerClubName, r[2]);
  });
}
