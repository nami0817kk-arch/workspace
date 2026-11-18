import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/transfer_window.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 獲得の相手は作り物の市場ではなく、他のクラブにいる本物の選手。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameState> start() async {
    final gs = GameState();
    await gs.startNewGame('市場FC');
    gs.save!.budget = 1 << 40;
    return gs;
  }

  /// 同じ部の他のクラブの、いちばん安い18歳以上の選手。
  (Player, Team) cheapest(GameState gs) {
    final targets = gs.transferTargets.map((p) => p.id).toSet();
    Player? best;
    Team? club;
    for (final t in gs.save!.league.teams) {
      if (t.id == gs.save!.userTeamId) continue;
      for (final p in t.players) {
        if (p.age < 18 || !targets.contains(p.id)) continue;
        if (best == null || p.marketValue < best.marketValue) {
          best = p;
          club = t;
        }
      }
    }
    return (best!, club!);
  }

  test('新しいゲームに作り物の市場は無く、相手は他のクラブの選手', () async {
    final gs = await start();
    expect(gs.transferMarket, isEmpty);
    final targets = gs.transferTargets;
    expect(targets.length, greaterThan(500));
    final mine = gs.userTeam.players.map((p) => p.id).toSet();
    expect(targets.any((p) => mine.contains(p.id)), isFalse);
    expect(targets.any((p) => p.isLoan || p.isLoanedOut), isFalse);
    // 他の国の18歳未満は出さない。
    final foreignIds = {
      for (final l in gs.save!.foreignLeagues.values)
        for (final t in l.teams)
          for (final p in t.players) p.id,
    };
    expect(
        targets.any((p) => p.age < 18 && foreignIds.contains(p.id)), isFalse);
  });

  test('買うと元のクラブから抜け、自クラブに入る', () async {
    final gs = await start();
    final (p, club) = cheapest(gs);
    final before = club.players.length;
    final ok = await gs.buyPlayer(p.id);
    expect(ok, isTrue, reason: gs.lastSigningBlockReason);
    expect(club.players.length, before - 1);
    expect(club.players.contains(p), isFalse);
    expect(club.startingXI.contains(p.id), isFalse);
    expect(gs.userTeam.players.contains(p), isTrue);
    expect(gs.transferTargets.contains(p), isFalse);
  });

  test('人数が少ないクラブは売らない', () async {
    final gs = await start();
    final (p, club) = cheapest(gs);
    final keep = [
      p,
      ...club.players.where((q) => q != p),
    ].take(GameStateTransfer.minSquadToSell).toList();
    club.players
      ..clear()
      ..addAll(keep);
    club.startingXI.removeWhere((id) => !keep.any((q) => q.id == id));
    expect(club.players.length, GameStateTransfer.minSquadToSell);
    expect(gs.transferTargets.contains(p), isFalse);
    expect(await gs.buyPlayer(p.id), isFalse);
    expect(club.players.contains(p), isTrue);
  });

  test('借りた選手は、ローンの終わりに元のクラブへ戻る', () async {
    final gs = await start();
    final (p, club) = cheapest(gs);
    final wage = p.wage;
    final ok = await gs.signLoanPlayer(p.id, length: LoanLength.half);
    expect(ok, isTrue, reason: gs.lastSigningBlockReason);
    expect(p.loanFromClubId, club.id);
    expect(club.players.contains(p), isFalse);
    expect(p.wage, lessThan(wage));

    gs.debugAdvanceTodayTo(p.loanEndDate!);
    // ローンの片付けは試合の日・シーズンの切り替わりで行う。
    gs.debugSettleLoansByDate();
    expect(gs.userTeam.players.contains(p), isFalse);
    expect(club.players.contains(p), isTrue);
    expect(p.isLoan, isFalse);
    expect(p.loanFromClubId, isNull);
    expect(p.wage, wage);
  });

  test('先発の選手は安くは手放さず、満了が近い選手は売りたがる', () async {
    final gs = await start();
    final club = gs.save!.league.teams
        .firstWhere((t) => t.id != gs.save!.userTeamId);
    final starter =
        club.players.firstWhere((p) => club.startingXI.contains(p.id));
    final bench =
        club.players.firstWhere((p) => !club.startingXI.contains(p.id));
    starter.contractYearsRemaining = 3;
    bench.contractYearsRemaining = 3;
    final s = gs.transferOfferAcceptChance(1000, 800, player: starter);
    final b = gs.transferOfferAcceptChance(1000, 800, player: bench);
    expect(s, lessThan(b));
    bench.contractYearsRemaining = 1;
    expect(gs.transferOfferAcceptChance(1000, 800, player: bench),
        greaterThan(b));
    // 満額なら、先発でも必ず受ける。
    expect(gs.transferOfferAcceptChance(1000, 1000, player: starter), 1.0);
  });

  test('注目リストに入れる・外す', () async {
    final gs = await start();
    final (p, _) = cheapest(gs);
    expect(gs.isWatched(p.id), isFalse);
    await gs.toggleWatched(p.id);
    expect(gs.isWatched(p.id), isTrue);
    await gs.toggleWatched(p.id);
    expect(gs.isWatched(p.id), isFalse);
  });
}
