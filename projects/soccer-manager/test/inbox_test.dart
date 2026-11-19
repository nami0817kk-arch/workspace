import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/agm_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 受信箱(未読の数・既読・対応が要るもの)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('お知らせが積まれると未読が増え、読むと0になる', () async {
    final gs = GameState();
    await gs.startNewGame('受信箱FC');
    await gs.markInboxRead();
    expect(gs.unreadNewsCount, 0);
    gs.addInboxNote('テストのお知らせ1');
    gs.addInboxNote('テストのお知らせ2');
    expect(gs.unreadNewsCount, 2);
    expect(gs.save!.newsLog.first.text, 'テストのお知らせ2');
    await gs.markInboxRead();
    expect(gs.unreadNewsCount, 0);
  });

  test('未読の数は、残っているお知らせの数を超えない', () async {
    final gs = GameState();
    await gs.startNewGame('受信箱FC');
    gs.save!.newsTotal = 99999;
    gs.save!.newsSeenTotal = 0;
    expect(gs.unreadNewsCount, gs.save!.newsLog.length);
  });

  test('答えを待っているものが「対応が要るもの」に出る', () async {
    final gs = GameState();
    await gs.startNewGame('受信箱FC');
    final s = gs.save!..pendingSponsorOffers = [];
    s.agmDemand = null;
    s.pendingOwnerEvent = null;
    final before = gs.inboxActions.length;
    s.agmDemand = AgmDemand.payout.name;
    expect(gs.inboxActions.length, before + 1);
  });

  test('未読の印は保存して読み戻せる', () async {
    final gs = GameState();
    await gs.startNewGame('受信箱FC');
    gs.addInboxNote('a');
    final c = SaveGame.fromJson(gs.save!.toJson());
    expect(c.newsTotal, gs.save!.newsTotal);
    expect(c.newsSeenTotal, gs.save!.newsSeenTotal);
  });
}
