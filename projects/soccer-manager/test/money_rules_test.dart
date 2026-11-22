import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// お金の決まり(パラシュート・連帯貢献金・簿価)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('パラシュート', () {
    // 2026-11-22 に国ごとの形へ直した(以前はどの国も2季で、半分→4分の1)。
    // イングランドは3季で 55% → 45% → 20%。国ごとの表は real_money_test。
    test('イングランドは降格すると3季、差の55%→45%→20%。昇格で止まる', () async {
      final gs = GameState();
      await gs.startNewGame('降格FC');
      final s = gs.save!;
      final tier = s.currentDivisionTier;
      expect(gs.parachuteAnnual, 0);
      // 1つ上の部から落ちてきた形にする。
      s.parachuteFromTier = tier - 1;
      s.parachuteSeasonsLeft = 3;
      final diff = annualBroadcast(tier - 1) - annualBroadcast(tier);
      expect(gs.parachuteAnnual, (diff * 0.55).round());
      s.parachuteSeasonsLeft = 2;
      expect(gs.parachuteAnnual, (diff * 0.45).round());
      s.parachuteSeasonsLeft = 1;
      expect(gs.parachuteAnnual, (diff * 0.2).round());
      s.parachuteSeasonsLeft = 0;
      s.parachuteFromTier = 0;
      expect(gs.parachuteAnnual, 0);
    });

    test('放映権の入金に、パラシュートが上乗せされる', () async {
      final gs = GameState();
      await gs.startNewGame('降格FC');
      final s = gs.save!;
      final day = DateTime(gs.today.year, 8, 1);
      final without = gs.broadcastInstallmentOn(day);
      s.parachuteFromTier = s.currentDivisionTier - 1;
      s.parachuteSeasonsLeft = 2;
      final withP = gs.broadcastInstallmentOn(day);
      if (without > 0) expect(withP, greaterThan(without));
    });
  });

  group('連帯貢献金', () {
    test('来たオファーで売ると5%を引く。アカデミー出身は引かない', () async {
      final gs = GameState();
      await gs.startNewGame('売却FC');
      final s = gs.save!;
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan)
        ..academyGraduate = false;
      expect(gs.solidarityFor(p, 1000), 50);
      p.academyGraduate = true;
      expect(gs.solidarityFor(p, 1000), 0);
      p.academyGraduate = false;
      s.budget = 0;
      s.incomingOffers.add(IncomingOffer(
          id: 'x',
          playerId: p.id,
          playerName: p.name,
          buyerClubName: s.league.teams
              .firstWhere((t) => t.id != s.userTeamId)
              .name,
          amount: 1000));
      expect(await gs.acceptIncomingOffer('x'), isTrue);
      expect(s.budget, 950);
    });
  });

  group('簿価', () {
    test('移籍金を契約の年数で償却し、売ると簿価との差を伝える', () async {
      final gs = GameState();
      await gs.startNewGame('簿価FC');
      final s = gs.save!;
      final p = gs.userTeam.players.firstWhere((p) => !p.isLoan);
      s.playerBook[p.id] = [4000, Player.contractClockYear, 4];
      expect(gs.bookValueOf(p.id), 4000);
      expect(gs.annualAmortizationOf(p.id), 1000);
      s.playerBook[p.id] = [4000, Player.contractClockYear - 1, 4];
      expect(gs.bookValueOf(p.id), 3000, reason: '1年たてば4分の3');
      s.incomingOffers.add(IncomingOffer(
          id: 'y',
          playerId: p.id,
          playerName: p.name,
          buyerClubName: s.league.teams
              .firstWhere((t) => t.id != s.userTeamId)
              .name,
          amount: 5000));
      await gs.acceptIncomingOffer('y');
      expect(s.playerBook.containsKey(p.id), isFalse);
      expect(s.newsLog.any((n) => n.text.contains('3,000') || n.text.contains('30m')),
          isTrue);
    });

    test('保存して読み戻せる', () async {
      final gs = GameState();
      await gs.startNewGame('簿価FC');
      final s = gs.save!
        ..playerBook['p1'] = [100, 2027, 3]
        ..parachuteFromTier = 2
        ..parachuteSeasonsLeft = 1;
      final c = SaveGame.fromJson(s.toJson());
      expect(c.playerBook['p1'], [100, 2027, 3]);
      expect(c.parachuteFromTier, 2);
      expect(c.parachuteSeasonsLeft, 1);
    });
  });
}
