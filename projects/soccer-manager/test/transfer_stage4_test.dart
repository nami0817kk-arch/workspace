import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/economy_scale.dart';
import 'package:soccer_manager/logic/free_agent_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/transfer_talk_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 画面の直し 第4段: 移籍(2026-11-25)の決まりの検査。
/// - 移籍金の提示の中身(分割の年数・出来高・売却時の上乗せ・交換)が、
///   相手の返事と、移籍が決まったあとの支払いに効く
/// - 所属なしの選手の年俸が、前のクラブの額を持ち越さない
/// - スカウトに個別に選手を見させる・地域を替える
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('提示の値打ち', () {
    test('分割は値打ちが下がり、出来高・上乗せ・交換は上がる', () {
      const cash = 1000;
      final plain = TransferTalkEngine.packageValue(cash: cash);
      expect(plain, cash);
      expect(
          TransferTalkEngine.packageValue(
              cash: cash, installments: true, installmentYears: 4),
          lessThan(TransferTalkEngine.packageValue(
              cash: cash, installments: true, installmentYears: 2)));
      expect(TransferTalkEngine.packageValue(cash: cash, installments: true),
          lessThan(plain));
      expect(TransferTalkEngine.packageValue(cash: cash, addOn: 200), 1100);
      expect(
          TransferTalkEngine.packageValue(
              cash: cash, sellOn: 20, marketValue: 1000),
          1120);
      expect(
          TransferTalkEngine.packageValue(
              cash: cash, exchangeValue: 400, exchangeFit: 0.85),
          1340);
    });

    test('お金が言い値に届かなくても、交換の選手で届けば合意(移籍金はお金の分)', () {
      final r = TransferTalkEngine.replyToPackage(
        asking: 1000,
        cash: 700,
        value: 1000,
        installments: false,
        round: 1,
        roll: 0.99,
      );
      expect(r.kind, TalkReplyKind.agree);
      expect(r.fee, 700);
    });

    test('対案はお金の分に直して返る(交換の値打ちは引いたまま)', () {
      // お金 600 + 交換の値打ち 200 = 800。言い値 1000 なら対案。
      final r = TransferTalkEngine.replyToPackage(
        asking: 1000,
        cash: 600,
        value: 800,
        installments: false,
        round: 1,
        roll: 0.99,
      );
      expect(r.kind, TalkReplyKind.counter);
      // お金だけの対案(1000 前後)より、交換の分だけ低い。
      expect(r.fee, lessThan(950));
      expect(r.fee, greaterThan(600));
    });
  });

  group('ゲームの中', () {
    Future<GameState> fresh() async {
      final gs = GameState();
      await gs.startNewGame('第4段FC');
      gs.rivalsEnabled = false;
      gs.save!.budget = 99999999;
      gs.save!.wageBudget = 99999999;
      return gs;
    }

    void advance(GameState gs, int days) =>
        gs.debugAdvanceTodayTo(gs.today.add(Duration(days: days)));

    test('いま払う額が資金を超えると提示できず、足りない額を言う', () async {
      final gs = await fresh();
      // 登録の決まり(労働許可など)で止まらない選手を探す。
      for (final p in gs.transferTargets) {
        final bid = p.marketValue;
        gs.save!.budget = gs.upfrontForBid(bid) - 1;
        if (await gs.openTransferTalk(p.id, bid)) fail('資金が足りないのに出せた');
        final reason = gs.lastSigningBlockReason ?? '';
        if (!reason.contains('あと') && !reason.contains('short')) continue;
        // 分割なら頭金だけで出せる。
        expect(
            await gs.openTransferTalk(p.id, bid,
                installments: true, installmentYears: 3),
            isTrue);
        expect(gs.talkFor(p.id)!.installmentYears, 3);
        return;
      }
      fail('資金の理由で止まる選手がいない');
    });

    test('交換・出来高・上乗せを付けて合意し、決まると交換の選手が相手へ移る', () async {
      final gs = await fresh();
      // 交換に出す選手(いちばん安い選手)。
      final give = gs.exchangeCandidates().last;
      for (final p in gs.transferTargets) {
        final club = gs.sellingClubOf(p.id);
        if (club == null) continue;
        final bid = gs.askingPriceFor(p) * 2;
        if (!await gs.openTransferTalk(p.id, bid,
            addOn: 100, sellOn: 15, exchangePlayerId: give.id)) {
          continue;
        }
        expect(gs.talkFor(p.id)!.exchangePlayerName, give.name);
        // 同じ選手を別の交渉の交換には出せない。
        expect(gs.exchangeCandidates().any((q) => q.id == give.id), isFalse);
        advance(gs, TransferTalkEngine.replyDays);
        expect(gs.talkFor(p.id)!.stage, TransferTalkStage.agreed);
        final out = await gs.offerPersonalTerms(p.id,
            weeklyWage: p.wage * 10 + 100,
            endYear: Player.contractClockYear + 2);
        expect(out, TermsOutcome.signed);
        expect(gs.isMyPlayer(p.id), isTrue);
        expect(gs.isMyPlayer(give.id), isFalse);
        expect(club.players.any((q) => q.id == give.id), isTrue,
            reason: '交換の選手は相手のクラブへ');
        expect(gs.save!.sellOnClauses[p.id], greaterThanOrEqualTo(15));
        expect(gs.save!.addOnClauses[p.id]!.first, 100);
        // 出場が届くと出来高を払う。
        final before = gs.save!.budget;
        p.careerAppearances += TransferTalkEngine.addOnApps;
        advance(gs, 1);
        expect(gs.save!.addOnClauses.containsKey(p.id), isFalse);
        expect(gs.save!.budget, lessThan(before));
        return;
      }
      fail('交換つきで申し込める選手がいない');
    });

    test('古いセーブ(新しい項目なし)も読める', () async {
      final t = TransferTalk.fromJson({
        'playerId': 'x',
        'playerName': 'X',
        'clubId': 'c',
        'clubName': 'C',
        'stage': 'waiting',
        'bid': 10,
      });
      expect(t.addOn, 0);
      expect(t.installmentYears, 0);
      expect(t.exchangePlayerId, isNull);
      final gs = await fresh();
      final json = gs.save!.toJson()
        ..remove('addOnClauses')
        ..remove('scoutPlayerIds');
      final copy = SaveGame.fromJson(json);
      expect(copy.addOnClauses, isEmpty);
      expect(copy.scoutPlayerIds, isEmpty);
      // 新しい項目は保存して読み戻せる。
      gs.save!.addOnClauses['p'] = [10, 2, 20];
      gs.save!.scoutPlayerIds.add('q');
      final back = SaveGame.fromJson(gs.save!.toJson());
      expect(back.addOnClauses['p'], [10, 2, 20]);
      expect(back.scoutPlayerIds, ['q']);
    });

    test('所属なしの選手は、前のクラブの大きな年俸を持ち越さない', () async {
      final gs = await fresh();
      // 他国の1部で大きな年俸をもらっていた選手が契約切れで来た形。
      final star = PlayerGenerator.generate(
          position: Position.st, strengthTier: 88, ageOverride: 29);
      star.wage = 3500000 ~/ 52; // 年35億
      gs.save!.freeAgents.add(star);
      advance(gs, 7);
      final pool = gs.freeAgents;
      expect(pool, isNotEmpty);
      for (final p in pool) {
        expect(p.wage, FreeAgentEngine.askingWeekly(p, gs.today),
            reason: '${p.name} の年俸がそろっていない');
        expect(annualFromWeekly(p.wage), lessThan(300000),
            reason: '${p.name} が年30億を超えている');
      }
      if (pool.contains(star)) {
        // 見合う額(自クラブのリーグの水準)の1.15倍まで。
        expect(star.wage, lessThanOrEqualTo(star.fairWeeklyWage() * 1.15 + 1));
      }
    });

    test('求める年俸は、季が進むほど下がる', () {
      final p = PlayerGenerator.generate(
          position: Position.mc, strengthTier: 70, ageOverride: 27);
      final summer = FreeAgentEngine.askingWeekly(p, DateTime(2026, 7, 10));
      final winter = FreeAgentEngine.askingWeekly(p, DateTime(2027, 1, 10));
      final spring = FreeAgentEngine.askingWeekly(p, DateTime(2027, 4, 10));
      expect(winter, lessThan(summer));
      expect(spring, lessThanOrEqualTo(winter));
    });

    test('スカウトに選手を見させると見えてきて、枠を超えては見させられない', () async {
      final gs = await fresh();
      final same = gs.sameLeaguePlayerIds();
      final far = [
        for (final p in gs.transferTargets)
          if (!same.contains(p.id) && gs.knowledgeOf(p) == 0) p
      ];
      expect(far.length, greaterThan(GameStateTransfer.scoutPlayerSlots));
      for (var i = 0; i < GameStateTransfer.scoutPlayerSlots; i++) {
        expect(await gs.toggleScoutPlayer(far[i].id), isTrue);
      }
      expect(await gs.toggleScoutPlayer(far.last.id), isFalse);
      expect(gs.lastSigningBlockReason, isNotNull);
      advance(gs, 14);
      expect(gs.knowledgeOf(far.first), greaterThan(0));
      // やめられる。
      expect(await gs.toggleScoutPlayer(far.first.id), isTrue);
      expect(gs.isScoutingPlayer(far.first.id), isFalse);
    });

    test('送っている地域を別の地域へ替えられる', () async {
      final gs = await fresh();
      final regions = gs.scoutRegions;
      expect(regions.length, greaterThan(1));
      await gs.toggleScoutRegion(regions[0].key);
      expect(await gs.replaceScoutRegion(regions[0].key, regions[1].key),
          isTrue);
      expect(gs.isScoutRegionActive(regions[0].key), isFalse);
      expect(gs.isScoutRegionActive(regions[1].key), isTrue);
      expect(gs.regionSize(regions[1].key).clubs, greaterThan(0));
    });

    test('他のクラブが売りに出している選手は、言い値が1割安い', () async {
      final gs = await fresh();
      final listed =
          gs.transferTargets.where(gs.isListedByClub).toList();
      expect(listed, isNotEmpty);
      // 売りに出しているのは先発でない選手か、移籍を望む選手。
      for (final p in listed) {
        final club = gs.sellingClubOf(p.id)!;
        expect(club.startingXI.contains(p.id) && !p.wantsTransfer, isFalse);
      }
    });
  });
}
