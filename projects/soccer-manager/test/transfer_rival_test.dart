import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/player_terms_engine.dart';
import 'package:soccer_manager/logic/transfer_talk_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/transfer_talk.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 交渉中の選手を、他のクラブも狙ってくる(競合)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('格が上のクラブには、選手は少し安くても行く', () {
    expect(
        PlayerTermsEngine.rivalPull(rivalWage: 100, rivalTier: 2, toTier: 2),
        100);
    expect(
        PlayerTermsEngine.rivalPull(rivalWage: 100, rivalTier: 1, toTier: 3),
        120,
        reason: 'こちらが2部下なら2割多く出さないと来ない');
    expect(
        PlayerTermsEngine.rivalPull(rivalWage: 100, rivalTier: 3, toTier: 2),
        95);
  });

  Future<(GameState, Player)> agreedWithRival() async {
    final gs = GameState();
    await gs.startNewGame('競合FC');
    gs.rivalsEnabled = false;
    gs.save!.budget = 99999999;
    gs.save!.wageBudget = 99999999;
    final same = gs.sameLeaguePlayerIds();
    for (final p in gs.transferTargets.where((p) => same.contains(p.id))) {
      if (await gs.openTransferTalk(p.id, gs.askingPriceFor(p) * 2)) {
        gs.debugAdvanceTodayTo(
            gs.today.add(const Duration(days: TransferTalkEngine.replyDays)));
        gs.debugStartRival(p.id);
        expect(gs.talkFor(p.id)!.hasRival, isTrue);
        return (gs, p);
      }
    }
    fail('申し込める選手がいない');
  }

  test('他のクラブが動くと、選手が望む額はその額以上になる', () async {
    final (gs, p) = await agreedWithRival();
    final t = gs.talkFor(p.id)!;
    expect(t.rivalClubName, isNotNull);
    expect(t.rivalDecidesOn, isNotNull);
    expect(gs.save!.newsLog.first.text, contains(t.rivalClubName!));
    final out = await gs.offerPersonalTerms(p.id,
        weeklyWage: (t.rivalWage * 0.9).round(),
        endYear: Player.contractClockYear + 2);
    expect(out, isNot(TermsOutcome.signed));
  });

  test('期限までに契約すれば取れる', () async {
    final (gs, p) = await agreedWithRival();
    final t = gs.talkFor(p.id)!;
    expect(
        await gs.offerPersonalTerms(p.id,
            weeklyWage: t.rivalWage * 3,
            endYear: Player.contractClockYear + 2),
        TermsOutcome.signed);
    expect(gs.userTeam.players.contains(p), isTrue);
  });

  test('期限を過ぎると、選手は他のクラブへ行く(クラブと合意していても)', () async {
    final (gs, p) = await agreedWithRival();
    final rivalId = gs.talkFor(p.id)!.rivalClubId!;
    gs.debugAdvanceTodayTo(gs.today
        .add(const Duration(days: PlayerTermsEngine.rivalDecisionDays + 1)));
    expect(gs.talkFor(p.id), isNull);
    expect(gs.userTeam.players.contains(p), isFalse);
    final rival = gs.save!.allTeams
        .followedBy(gs.save!.foreignLeagues.values.expand((l) => l.teams))
        .firstWhere((t) => t.id == rivalId);
    expect(rival.players.contains(p), isTrue);
  });

  test('競合は保存して読み戻せる', () async {
    final (gs, p) = await agreedWithRival();
    final t = SaveGame.fromJson(gs.save!.toJson()).transferTalks.single;
    expect(t.rivalClubId, gs.talkFor(p.id)!.rivalClubId);
    expect(t.rivalWage, gs.talkFor(p.id)!.rivalWage);
    expect(t.rivalDecidesOn, gs.talkFor(p.id)!.rivalDecidesOn);
  });

  test('放っておけば、いずれ他のクラブが動き出す', () async {
    Tr.language = AppLanguage.japanese;
    addTearDown(() => Tr.language = AppLanguage.system);
    final gs = GameState();
    await gs.startNewGame('競合FC');
    gs.save!.budget = 99999999;
    gs.save!.wageBudget = 99999999;
    var opened = 0;
    for (final p in gs.transferTargets) {
      if (await gs.openTransferTalk(p.id, gs.askingPriceFor(p) * 2)) opened++;
      if (opened >= 20) break;
    }
    // 12日で、1人あたり 31〜52% ほどで他のクラブが動く。20人いれば
    // 誰にも来ない見込みは 0.1% 未満。
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 2)));
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 10)));
    expect(
        gs.save!.newsLog.any((n) => n.text.contains('獲得に動いている')) ||
            gs.transferTalks.any((t) => t.hasRival),
        isTrue);
  });
}
