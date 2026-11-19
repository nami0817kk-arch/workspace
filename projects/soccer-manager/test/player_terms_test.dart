import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_terms_engine.dart';
import 'package:soccer_manager/logic/transfer_talk_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 移籍する選手(代理人)との、年俸・年数・サイン料の交渉の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('望む額と返事の決まり', () {
    int demand({int? from = 3, int to = 3, bool was = false, bool would = true}) =>
        PlayerTermsEngine.demand(
            currentWage: 100,
            marketValue: 0,
            fromTier: from,
            toTier: to,
            wasStarter: was,
            wouldStart: would);

    test('移籍なら1割上乗せ、下の部へは2割ずつ増し、控えになるなら2割増し', () {
      expect(demand(), 110);
      expect(demand(to: 4), 132);
      expect(demand(to: 2), 105);
      expect(demand(was: true, would: false), 132);
      expect(demand(from: null), 100, reason: 'フリーエージェントは今のまま');
    });

    test('30歳までは3部以上下へは行かない', () {
      expect(PlayerTermsEngine.refusal(fromTier: 1, toTier: 4, age: 25),
          isNotNull);
      expect(PlayerTermsEngine.refusal(fromTier: 1, toTier: 4, age: 32),
          isNull);
      expect(PlayerTermsEngine.refusal(fromTier: 2, toTier: 4, age: 25),
          isNull);
    });

    test('サイン料は年数でならして足す。足りれば受け、遠すぎれば席を立つ', () {
      expect(
          PlayerTermsEngine.effectiveWeekly(
              weeklyWage: 100, years: 2, signingBonus: 5200),
          150);
      expect(PlayerTermsEngine.judge(effective: 100, demand: 100, round: 1),
          TermsReplyKind.accept);
      expect(PlayerTermsEngine.judge(effective: 90, demand: 100, round: 1),
          TermsReplyKind.counter);
      expect(PlayerTermsEngine.judge(effective: 60, demand: 100, round: 1),
          TermsReplyKind.walkAway);
      expect(
          PlayerTermsEngine.judge(
              effective: 90, demand: 100, round: PlayerTermsEngine.maxRounds),
          TermsReplyKind.walkAway);
    });
  });

  group('ゲームの中', () {
    /// クラブと合意まで済ませる(同じ部の選手なので、部の差では断られない)。
    Future<(GameState, Player)> agreed() async {
      final gs = GameState();
      await gs.startNewGame('条件FC');
      gs.rivalsEnabled = false; // 競合は rival_test で見る
      gs.save!.budget = 99999999;
      gs.save!.wageBudget = 99999999;
      final same = gs.sameLeaguePlayerIds();
      for (final p in gs.transferTargets.where((p) => same.contains(p.id))) {
        if (await gs.openTransferTalk(p.id, gs.askingPriceFor(p) * 2)) {
          gs.debugAdvanceTodayTo(gs.today
              .add(const Duration(days: TransferTalkEngine.replyDays)));
          expect(gs.talkFor(p.id)!.stage, TransferTalkStage.agreed);
          return (gs, p);
        }
      }
      fail('申し込める選手がいない');
    }

    test('少し足りなければ望む額を返され、のめば加入する', () async {
      final (gs, p) = await agreed();
      final end = Player.contractClockYear + 2;
      expect(await gs.offerPersonalTerms(p.id, weeklyWage: p.wage, endYear: end),
          TermsOutcome.counter);
      final want = gs.talkFor(p.id)!.demandWage;
      expect(want, greaterThan(p.wage));
      final before = gs.save!.budget;
      expect(await gs.offerPersonalTerms(p.id, weeklyWage: want, endYear: end),
          TermsOutcome.signed);
      expect(gs.userTeam.players.contains(p), isTrue);
      expect(p.wage, want);
      expect(p.contractEndYear, end);
      expect(gs.talkFor(p.id), isNull);
      expect(gs.save!.budget, lessThan(before));
    });

    test('サイン料で年俸の不足を埋められ、サイン料は資金から出る', () async {
      final (gs, p) = await agreed();
      final end = Player.contractClockYear + 1; // 2年
      await gs.offerPersonalTerms(p.id, weeklyWage: p.wage, endYear: end);
      final want = gs.talkFor(p.id)!.demandWage;
      final bonus = (want - p.wage) * 52 * 2 + 104;
      final before = gs.save!.budget;
      final fee = gs.talkFor(p.id)!.fee;
      expect(
          await gs.offerPersonalTerms(p.id,
              weeklyWage: p.wage, endYear: end, signingBonus: bonus),
          TermsOutcome.signed);
      expect(before - gs.save!.budget, greaterThanOrEqualTo(fee + bonus));
    });

    test('遠すぎる額だと席を立ち、クラブとの合意も流れる', () async {
      final (gs, p) = await agreed();
      expect(
          await gs.offerPersonalTerms(p.id,
              weeklyWage: 1, endYear: Player.contractClockYear + 2),
          TermsOutcome.refused);
      expect(gs.talkFor(p.id)!.stage, TransferTalkStage.collapsed);
      expect(gs.userTeam.players.contains(p), isFalse);
    });

    test('クラブと合意する前は、選手に条件を出せない', () async {
      final gs = GameState();
      await gs.startNewGame('条件FC');
      final p = gs.transferTargets.first;
      expect(
          await gs.offerPersonalTerms(p.id,
              weeklyWage: p.wage * 10, endYear: Player.contractClockYear + 2),
          TermsOutcome.blocked);
    });

    test('フリーエージェントとは、いつでも本人と話して決める', () async {
      final gs = GameState();
      await gs.startNewGame('条件FC');
      gs.save!.wageBudget = 99999999;
      final fa = gs.freeAgents.first;
      final end = Player.contractClockYear + 1;
      expect(
          await gs.offerPersonalTerms(fa.id,
              weeklyWage: (fa.wage * 0.85).round(), endYear: end),
          TermsOutcome.counter);
      expect(gs.talkFor(fa.id)!.freeAgent, isTrue);
      expect(
          await gs.offerPersonalTerms(fa.id, weeklyWage: fa.wage, endYear: end),
          TermsOutcome.signed);
      expect(gs.userTeam.players.contains(fa), isTrue);
      expect(gs.freeAgents.contains(fa), isFalse);
    });
  });
}
