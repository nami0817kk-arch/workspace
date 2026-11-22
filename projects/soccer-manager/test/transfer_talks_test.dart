import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/transfer_talk_engine.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// クラブ同士の移籍金の交渉(提示→返事→対案・合意・決裂)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('言い値と返事の決まり', () {
    int ask({bool key = false, bool starter = false, int years = 3,
            int age = 27, int gap = 0}) =>
        TransferTalkEngine.askingPrice(
            marketValue: 1000,
            keyPlayer: key,
            starter: starter,
            contractYearsLeft: years,
            age: age,
            potentialGap: gap);

    test('主力・先発・有望株は高く、契約の残りが短いと安い', () {
      expect(ask(), 1000);
      expect(ask(key: true), 1300);
      expect(ask(starter: true), 1150);
      expect(ask(years: 1), 800);
      expect(ask(years: 2), 950);
      expect(ask(age: 19, gap: 10), 1150);
    });

    TalkReply reply(int bid, {int round = 1, bool inst = false}) =>
        TransferTalkEngine.reply(
            asking: 1000, bid: bid, installments: inst, round: round, roll: 0.99);

    test('言い値以上なら合意、6割を切れば打ち切り', () {
      expect(reply(1000).kind, TalkReplyKind.agree);
      expect(reply(1200).fee, 1200);
      expect(reply(590).kind, TalkReplyKind.collapse);
    });

    test('間なら対案。大きく値切ると売却条項を求め、分割は認めない', () {
      final r = reply(750, inst: true);
      expect(r.kind, TalkReplyKind.counter);
      expect(r.fee, greaterThan(750));
      expect(r.sellOnPercent, 10);
      expect(r.installmentsOk, isFalse);
      final near = reply(920, inst: true);
      expect(near.sellOnPercent, 0);
      expect(near.installmentsOk, isTrue);
    });

    test('回を重ねると対案は下がり、3回目で届かなければ決裂', () {
      expect(reply(900, round: 2).fee, lessThan(reply(900).fee));
      expect(reply(900, round: TransferTalkEngine.maxRounds).kind,
          TalkReplyKind.collapse);
    });

    test('言い値に近い額は、そのまま受けることもある', () {
      final r = TransferTalkEngine.reply(
          asking: 1000, bid: 980, installments: false, round: 1, roll: 0.1);
      expect(r.kind, TalkReplyKind.agree);
    });
  });

  group('ゲームの中', () {
    /// 申し込める選手を1人選んで交渉を始める。
    Future<(GameState, Player)> start(double ratio) async {
      final gs = GameState();
      await gs.startNewGame('交渉FC');
      gs.rivalsEnabled = false; // 競合は rival_test で見る
      expect(gs.isTransferWindowOpen, isTrue, reason: '始めた日は窓が開いている前提');
      gs.save!.budget = 99999999;
      gs.save!.wageBudget = 99999999;
      for (final p in gs.transferTargets) {
        final bid = (gs.askingPriceFor(p) * ratio).round();
        if (await gs.openTransferTalk(p.id, bid)) return (gs, p);
      }
      fail('申し込める選手がいない');
    }

    void advance(GameState gs, int days) =>
        gs.debugAdvanceTodayTo(gs.today.add(Duration(days: days)));

    test('言い値で提示すると、2日後に合意し、決めれば加入する', () async {
      final (gs, p) = await start(1.0);
      expect(gs.talkFor(p.id)!.stage, TransferTalkStage.waiting);
      expect(gs.userTeam.players.contains(p), isFalse);
      advance(gs, TransferTalkEngine.replyDays);
      final t = gs.talkFor(p.id)!;
      expect(t.stage, TransferTalkStage.agreed);
      final before = gs.save!.budget;
      // 選手が望むより十分高い年俸を出せば、その場で加入する。
      expect(
          await gs.offerPersonalTerms(p.id,
              weeklyWage: p.wage * 10 + 100,
              endYear: Player.contractClockYear + 2),
          TermsOutcome.signed);
      expect(gs.userTeam.players.contains(p), isTrue);
      expect(gs.talkFor(p.id), isNull);
      expect(before - gs.save!.budget, greaterThanOrEqualTo(t.fee));
    });

    test('値切ると対案が来て、のめば合意する', () async {
      // 返事は2日後の言い値で決まる。そのあいだに誕生日が来ると、年齢で
      // 価値と言い値が下がり、8割の提示がそのまま通ることがあった(CI で
      // たまに落ちていた。2026-11-22)。7割なら、言い値が2割以上下がらない
      // 限り対案になる(打ち切りの6割よりは上)。
      final (gs, p) = await start(0.7);
      advance(gs, TransferTalkEngine.replyDays);
      final t = gs.talkFor(p.id)!;
      expect(t.stage, TransferTalkStage.countered);
      expect(t.fee, greaterThan(t.bid));
      // 前より低い額では出し直せない。
      expect(await gs.openTransferTalk(p.id, t.bid), isFalse);
      expect(await gs.acceptTalkCounter(p.id), isTrue);
      expect(gs.talkFor(p.id)!.stage, TransferTalkStage.agreed);
    });

    test('安すぎると打ち切られ、この窓のあいだは申し込めない', () async {
      final (gs, p) = await start(0.5);
      advance(gs, TransferTalkEngine.replyDays);
      expect(gs.talkFor(p.id)!.stage, TransferTalkStage.collapsed);
      expect(await gs.openTransferTalk(p.id, p.marketValue * 3), isFalse);
      expect(gs.lastSigningBlockReason, isNotNull);
    });

    test('合意しても期限までに決めなければ流れる', () async {
      final (gs, p) = await start(1.0);
      advance(gs, TransferTalkEngine.replyDays);
      expect(gs.talkFor(p.id)!.stage, TransferTalkStage.agreed);
      advance(gs, TransferTalkEngine.agreementDays + 1);
      expect(gs.talkFor(p.id), isNull);
    });

    test('窓が閉じると、交渉は全部流れる', () async {
      final (gs, p) = await start(0.8);
      advance(gs, 120);
      expect(gs.isTransferWindowOpen, isFalse);
      expect(gs.transferTalks, isEmpty);
      expect(gs.userTeam.players.contains(p), isFalse);
    });

    test('交渉は保存して読み戻せる', () async {
      final (gs, p) = await start(0.8);
      advance(gs, TransferTalkEngine.replyDays);
      final copy = SaveGame.fromJson(gs.save!.toJson());
      final t = copy.transferTalks.single;
      expect(t.playerId, p.id);
      expect(t.stage, gs.talkFor(p.id)!.stage);
      expect(t.fee, gs.talkFor(p.id)!.fee);
    });
  });

  group('来たオファーに対案を返す', () {
    Future<(GameState, IncomingOffer)> withOffer() async {
      final gs = GameState();
      await gs.startNewGame('売り手FC');
      final p = gs.userTeam.players.first;
      final o = IncomingOffer(
          id: 'offer-test',
          playerId: p.id,
          playerName: p.name,
          buyerClubName: '買い手FC',
          amount: 10000);
      gs.save!.incomingOffers.add(o);
      return (gs, o);
    }

    test('上限の内なら、求めた額に上がる(それ以上は返せない)', () async {
      final (gs, o) = await withOffer();
      expect(gs.canCounterIncomingOffer(o), isTrue);
      expect(await gs.counterIncomingOffer(o.id, 10500), isTrue);
      expect(gs.canCounterIncomingOffer(o), isFalse);
      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 2)));
      expect(o.amount, 10500);
      expect(o.isFinal, isTrue);
    });

    test('求めすぎると打ち切られ、少し超えたら上限の額が返る', () async {
      var (gs, o) = await withOffer();
      await gs.counterIncomingOffer(o.id, 30000);
      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 2)));
      expect(gs.incomingOffers.contains(o), isFalse);

      (gs, o) = await withOffer();
      final limit = TransferTalkEngine.buyerLimit(o.id, o.amount);
      await gs.counterIncomingOffer(o.id, limit + 100);
      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 2)));
      expect(o.amount, limit);
    });
  });
}
