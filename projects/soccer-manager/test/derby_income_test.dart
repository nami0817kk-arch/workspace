import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/state/game_state.dart';

/// ダービーの収入が、実際に入れた人数で決まるかの検査。
///
/// 観客数だけを収容人数で頭打ちにして、収入には倍率をそのまま掛けていた。
/// 画面に「満員」と出ているのに、収入はその1.5倍で計算されていたことになる。
/// 入れる人数以上からは入場料を取れない。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const capacity = 12000;

  group('収入は実際に入った人数で決まる', () {
    test('空席があれば、増えたぶんだけ収入も増える', () {
      // 8000人 → ダービーで12000人。収容人数に収まるので満額伸びる。
      final income = GameState.derbyAdjustedIncome(
        1000,
        baseAttendance: 8000,
        actualAttendance: 12000,
      );
      expect(income, 1500);
    });

    test('満員で頭打ちなら、収入も頭打ちになる', () {
      // 既に満員(12000)。ダービーでも入れる人数は変わらない。
      final income = GameState.derbyAdjustedIncome(
        1000,
        baseAttendance: capacity,
        actualAttendance: capacity,
      );
      expect(income, 1000, reason: '満員なのにダービーだからと収入だけ増えている');
    });

    test('途中で頭打ちになる場合は、その分だけ伸びる', () {
      // 10000人 → 15000人ぶんの需要があるが、入れるのは12000人まで。
      final income = GameState.derbyAdjustedIncome(
        1000,
        baseAttendance: 10000,
        actualAttendance: capacity,
      );
      expect(income, 1200);
      expect(income, lessThan(1500), reason: '収容人数を超えて収入が増えている');
    });

    test('観客が0なら、割り算をせずそのまま返す', () {
      expect(
        GameState.derbyAdjustedIncome(1000,
            baseAttendance: 0, actualAttendance: 0),
        1000,
      );
    });
  });

  test('試合を消化しても、観客数は収容人数を超えない', () async {
    final game = GameState();
    await game.startNewGame('上限FC');
    game.save!.confidence = 100;
    game.save!.currentDivisionTier = 1;

    // 次節の相手をライバルにして、ダービーとして消化する。
    final next = game.save!.league.nextUnplayedFixture!;
    game.save!.rivalTeamId = next.homeTeamId == game.save!.userTeamId
        ? next.awayTeamId
        : next.homeTeamId;
    await game.playNextMatchday();
    if (game.isHalfTime) await game.playSecondHalf();

    expect(game.lastMatchAttendance, lessThanOrEqualTo(game.stadiumCapacity));
  });
}
