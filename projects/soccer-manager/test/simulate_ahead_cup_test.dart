import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';

/// まとめてシミュレーションしたときに、カップ戦も一緒に進むことを固定する。
///
/// simulateAheadMatchdays はリーグの節を送るだけで、カップ戦を進める呼び出しが
/// 無かった。画面には「N節分をシミュレーションしています」と出るのに、
/// 実際に進むのはリーグ戦だけ。シーズンを丸ごとシミュレーションすると、
/// カップは1試合も行われないまま優勝者が決まらず、賞金も入らなかった。
///
/// カップは「リーグが1節進むごとに1試合」の制約があるので、進みすぎない
/// ことも確かめる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('節を送るとカップ戦も消化される', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    int playedRounds() =>
        game.domesticCup?.rounds
            .where((r) => r.every((m) => m.winnerId != null))
            .length ??
        0;

    expect(playedRounds(), 0, reason: '開始時は未消化のはず');

    await game.simulateAheadMatchdays(10);

    expect(playedRounds(), greaterThan(0),
        reason: '10節進めてもカップ戦が1試合も消化されていない');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('シーズンを走り切るとカップの優勝者が決まり、賞金が入る', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    await game.simulateAheadMatchdays(60);

    expect(game.save!.league.isSeasonComplete, isTrue,
        reason: 'シーズンが終わっていない');
    expect(game.domesticCup?.isComplete, isTrue,
        reason: 'シーズンが終わったのにカップが未完了');
    expect(game.domesticCup?.championId, isNotNull,
        reason: 'カップの優勝者が決まっていない');
    // 賞金額は自クラブの勝敗に依存する(1回戦敗退なら0)ので、条件にしない。
    // 代わりに「自クラブのカップ戦が実際に消化されたか」を見る。これは
    // 勝敗によらず決まる。修正前はここが未消化のまま残っていた。
    final me = game.userTeam.id;
    final myFirstRound = game.domesticCup!.rounds.first
        .where((m) => m.homeTeamId == me || m.awayTeamId == me);
    expect(myFirstRound, isNotEmpty, reason: '自クラブがカップに参加していない');
    expect(myFirstRound.first.winnerId, isNotNull,
        reason: '自クラブのカップ戦が消化されていない');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('カップが一気に進みすぎない（1節につき1試合まで）', () async {
    final game = GameState();
    await game.startNewGame('テストFC');

    await game.simulateAheadMatchdays(1);
    final afterOne = game.domesticCup?.lastPlayedAtMatchday;

    expect(afterOne, isNotNull, reason: '1節でカップが消化されていない');
    // 直後は次の試合を消化できない(リーグが進むまで待つ)。
    expect(game.canPlayNextDomesticCupMatch, isFalse,
        reason: 'リーグが進んでいないのにカップを続けて消化できてしまう');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
