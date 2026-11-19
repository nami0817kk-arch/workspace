import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/models/club_look.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/theme/club_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('決めた見た目がエンブレムとユニフォームの色の出どころに入る', () async {
    final gs = GameState();
    await gs.startNewGame('見た目FC');
    final s = gs.save!;
    final look = gs.currentClubLook.copyWith(
        hue: 225, accentHue: 52, shape: 2, motif: 3, initial: 'MF');
    expect(gs.clubLookChangeCosts, isFalse, reason: '最初の季は無料');
    final conf = s.confidence;
    expect(await gs.setClubLook(look), isTrue);
    expect(s.confidence, conf);
    expect(ClubLookRegistry.lookFor(s.userTeamId)!.initial, 'MF');
    expect(ClubPalette.of(s.userTeamId).hue, 225);
    expect(ClubPalette.of(s.userTeamId).accentHue, 52);
    // 他のクラブは自動のまま。
    final other = s.league.teams.firstWhere((t) => t.id != s.userTeamId);
    expect(ClubLookRegistry.lookFor(other.id), isNull);

    expect(await gs.setClubLook(look.copyWith(initial: '')), isFalse);
    expect(await gs.setClubLook(look.copyWith(initial: 'ABC')), isFalse);

    final back = SaveGame.fromJson(s.toJson());
    expect(back.clubLook!.shape, 2);
    expect(back.clubLook!.hue, 225);
  });
}
