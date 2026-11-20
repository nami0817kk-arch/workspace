import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_terms_engine.dart';
import 'package:soccer_manager/logic/transfer_talk_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/player_traits.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 選手の人柄(6つの軸)と、加入のときの序列の約束の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('人柄の6つの軸', () {
    test('同じ選手なら毎回同じ値で、どの軸も1〜20', () {
      for (final id in ['a', 'pl1', 'pl999', 'xyz-12']) {
        for (final per in PlayerPersonality.values) {
          final t = PlayerTraits.of(id, per);
          expect(t.values, PlayerTraits.of(id, per).values);
          for (final a in TraitAxis.values) {
            expect(t[a], inInclusiveRange(1, 20));
          }
        }
      }
    });

    test('性格が軸に出る(忠誠型は忠誠が、野心家は野心が高い)', () {
      double avg(PlayerPersonality per, TraitAxis a) {
        var sum = 0;
        for (var i = 0; i < 200; i++) {
          sum += PlayerTraits.of('p$i', per)[a];
        }
        return sum / 200;
      }

      expect(avg(PlayerPersonality.loyal, TraitAxis.loyalty),
          greaterThan(avg(PlayerPersonality.ambitious, TraitAxis.loyalty) + 4));
      expect(avg(PlayerPersonality.ambitious, TraitAxis.ambition),
          greaterThan(avg(PlayerPersonality.loyal, TraitAxis.ambition) + 4));
    });

    test('軸の効き目の幅', () {
      const low = PlayerTraits({
        TraitAxis.drive: 1,
        TraitAxis.temperament: 1,
        TraitAxis.professionalism: 1,
        TraitAxis.adaptability: 1,
        TraitAxis.ambition: 1,
        TraitAxis.loyalty: 20,
      });
      const high = PlayerTraits({
        TraitAxis.drive: 20,
        TraitAxis.temperament: 20,
        TraitAxis.professionalism: 20,
        TraitAxis.adaptability: 20,
        TraitAxis.ambition: 20,
        TraitAxis.loyalty: 1,
      });
      expect(high.growthFactor, greaterThan(low.growthFactor));
      expect(high.benchFactor, greaterThan(low.benchFactor));
      expect(high.gloomFactor, lessThan(low.gloomFactor));
      expect(high.arrivalHappiness, greaterThan(low.arrivalHappiness));
      expect(high.transferLineShift, greaterThan(0));
      expect(low.transferLineShift, lessThan(0));
    });
  });

  group('序列の約束', () {
    test('出番を約束するほど、望む年俸は下がる', () {
      int d(SquadStatus s) => PlayerTermsEngine.demand(
          currentWage: 100,
          marketValue: 0,
          fromTier: 3,
          toTier: 3,
          wasStarter: false,
          wouldStart: true,
          promise: s);
      expect(d(SquadStatus.keyPlayer), lessThan(d(SquadStatus.regular)));
      expect(d(SquadStatus.rotation), greaterThan(d(SquadStatus.regular)));
      expect(d(SquadStatus.prospect), greaterThan(d(SquadStatus.rotation)));
    });

    /// クラブと合意し、キープレイヤーを約束して取る。
    Future<(GameState, Player)> signedWithPromise() async {
      final gs = GameState();
      await gs.startNewGame('約束FC');
      gs.rivalsEnabled = false;
      gs.save!.budget = 99999999;
      gs.save!.wageBudget = 99999999;
      final same = gs.sameLeaguePlayerIds();
      for (final p in gs.transferTargets.where((p) => same.contains(p.id))) {
        if (!await gs.openTransferTalk(p.id, gs.askingPriceFor(p) * 2)) continue;
        gs.debugAdvanceTodayTo(gs.today
            .add(const Duration(days: TransferTalkEngine.replyDays)));
        expect(gs.talkFor(p.id)!.stage, TransferTalkStage.agreed);
        final out = await gs.offerPersonalTerms(p.id,
            weeklyWage: p.wage * 10 + 100,
            endYear: Player.contractClockYear + 2,
            promise: SquadStatus.keyPlayer);
        expect(out, TermsOutcome.signed);
        return (gs, p);
      }
      fail('申し込める選手がいない');
    }

    test('約束した序列で加わり、機嫌は順応で決まる', () async {
      final (_, p) = await signedWithPromise();
      expect(p.squadStatus, SquadStatus.keyPlayer);
      expect(p.promisedStatus, SquadStatus.keyPlayer);
      expect(p.happiness, p.traits.arrivalHappiness);
      expect(p.promiseBroken, isFalse);
    });

    test('序列を下げると約束を破ったことになり、移籍を願い出る', () async {
      final (gs, p) = await signedWithPromise();
      gs.setSquadStatus(p.id, SquadStatus.rotation);
      expect(p.promiseBroken, isTrue);
      expect(p.wantsTransfer, isTrue);
      expect(p.isTransferListed, isTrue);
    });

    test('出られるのに先発から外し続けると、約束を破ったことになる', () async {
      final (gs, p) = await signedWithPromise();
      gs.userTeam.startingXI.remove(p.id);
      p.injuryWeeks = 0;
      for (var i = 0;
          i < PlayerTermsEngine.promiseTolerance(SquadStatus.keyPlayer) - 1;
          i++) {
        gs.debugCheckPromises();
      }
      expect(p.promiseBroken, isFalse, reason: 'まだ我慢している');
      gs.debugCheckPromises();
      expect(p.promiseBroken, isTrue);
    });

    test('先発に戻せば、数え直しになる', () async {
      final (gs, p) = await signedWithPromise();
      gs.userTeam.startingXI.remove(p.id);
      gs.debugCheckPromises();
      gs.debugCheckPromises();
      gs.userTeam.startingXI.add(p.id);
      gs.debugCheckPromises();
      expect(p.promiseMisses, 0);
    });

    test('約束は保存して読み戻せる', () async {
      final (_, p) = await signedWithPromise();
      p.promiseMisses = 2;
      final copy = Player.fromJson(p.toJson());
      expect(copy.promisedStatus, SquadStatus.keyPlayer);
      expect(copy.promiseMisses, 2);
      expect(copy.promiseBroken, isFalse);
      expect(copy.traits.values, p.traits.values);
    });
  });
}
