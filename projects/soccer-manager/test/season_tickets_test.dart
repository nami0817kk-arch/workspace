import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/season_tickets.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('年間シートの売上は 1節の入場収入 × 節 × 割合 × 85%', () {
    expect(
        SeasonTicketEngine.upfront(
            weeklyGate: 100, matchdays: 30, sharePercent: 50),
        1275);
    expect(SeasonTicketEngine.remainingGate(100, 30), 70);
    expect(SeasonTicketEngine.remainingGate(100, 0), 100);
  });

  test('開幕前に1回だけ売れて、すぐ入り、節ごとの入場収入はその分減る', () async {
    final gs = GameState();
    await gs.startNewGame('年間FC');
    final s = gs.save!;
    expect(gs.canSellSeasonTickets, isTrue);
    expect(gs.seasonTicketShareNow, 0);
    final expected = gs.seasonTicketUpfront(50);
    expect(expected, greaterThan(0));
    final before = s.budget;
    final gateBefore = s.ledgerFor(s.league.season).of(LedgerCategory.gate);

    expect(await gs.sellSeasonTickets(25), isFalse, reason: '選べない割合');
    expect(await gs.sellSeasonTickets(50), isTrue);
    expect(s.budget - before, expected);
    expect(s.ledgerFor(s.league.season).of(LedgerCategory.gate) - gateBefore,
        expected);
    expect(gs.seasonTicketShareNow, 50);
    expect(gs.canSellSeasonTickets, isFalse);
    expect(await gs.sellSeasonTickets(30), isFalse, reason: '1季に1回');

    // 保存して読み戻せる。
    final back = SaveGame.fromJson(s.toJson());
    expect(back.seasonTicketShare, 50);
    expect(back.seasonTicketSeason, s.league.season);
  });

  test('売っていない季は割合0(前の季に売った分は持ち越さない)', () async {
    final gs = GameState();
    await gs.startNewGame('翌季FC');
    final s = gs.save!;
    s.seasonTicketShare = 70;
    s.seasonTicketSeason = s.league.season - 1;
    expect(gs.seasonTicketShareNow, 0);
    expect(gs.canSellSeasonTickets, isTrue);
  });
}
