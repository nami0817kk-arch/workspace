import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 他のクラブの経営(資金・破綻・身売り)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ふつうの1年では、破綻するクラブはほとんど出ない', () async {
    final gs = GameState();
    await gs.startNewGame('経営FC');
    final collapsed = gs.debugSettleAiClubFinances();
    final total = gs.save!.clubCash.length + collapsed.length;
    // ignore: avoid_print
    print('破綻 ${collapsed.length} / $total');
    expect(collapsed.length, lessThan(total * 0.1),
        reason: '1年目から1割を超えて破綻するのは釣り合いがおかしい');
  });

  test('赤字が積み重なったクラブは破綻し、主力を放出して投げ売りになる', () async {
    final gs = GameState();
    await gs.startNewGame('経営FC');
    final s = gs.save!;
    final victim =
        s.league.teams.firstWhere((t) => t.id != s.userTeamId);
    s.clubCash[victim.id] = -999999999;
    final before = victim.players.length;
    final fa = s.freeAgents.length;
    final collapsed = gs.debugSettleAiClubFinances();
    expect(collapsed, contains(victim.id));
    expect(gs.isDistressedClub(victim.id), isTrue);
    expect(victim.players.length, lessThan(before));
    expect(s.freeAgents.length, greaterThan(fa));
    expect(s.clubCash[victim.id], 0, reason: '身売りで借金は引き取られる');
    // 投げ売り中の選手は言い値が下がる。
    final p = victim.players.first;
    final distressed = gs.askingPriceFor(p);
    s.distressedClubIds.clear();
    expect(distressed, lessThan(gs.askingPriceFor(p)));
  });

  test('資金と投げ売りの印は保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('経営FC');
    gs.save!.clubCash['x'] = 123;
    gs.save!.distressedClubIds.add('y');
    final c = SaveGame.fromJson(gs.save!.toJson());
    expect(c.clubCash['x'], 123);
    expect(c.distressedClubIds, ['y']);
  });
}
