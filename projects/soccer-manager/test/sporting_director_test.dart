import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/state/game_state.dart';

/// SD(スポーツディレクター)の検査。補強の交渉を任せられ、見極めが
/// 高いほど言い値を安くまとめる。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// SD を雇ったゲーム(見極めを[judging]にする)。
  Future<GameState> withSd({int judging = 15}) async {
    final gs = GameState();
    await gs.startNewGame('SD FC');
    gs.rivalsEnabled = false;
    gs.save!.budget = 99999999;
    gs.save!.wageBudget = 99999999;
    gs.save!.infrastructure.staff[StaffRole.sportingDirector] = StaffMember(
      id: 'sd-test',
      name: 'テストSD',
      age: 50,
      role: StaffRole.sportingDirector,
      attributes: {
        for (final a in StaffAttribute.values) a: judging,
      },
      wage: 10,
      contractYears: 3,
    );
    return gs;
  }

  test('SDの候補が出る', () async {
    final gs = GameState();
    await gs.startNewGame('SD FC');
    expect(gs.staffCandidatesFor(StaffRole.sportingDirector), isNotEmpty);
  });

  test('見極めが高いSDほど、相手の言い値が下がる', () async {
    final gs = GameState();
    await gs.startNewGame('SD FC');
    final p = gs.transferTargets.first;
    final without = gs.askingPriceFor(p);
    gs.save!.infrastructure.staff[StaffRole.sportingDirector] = StaffMember(
      id: 'sd',
      name: 'x',
      age: 50,
      role: StaffRole.sportingDirector,
      attributes: {for (final a in StaffAttribute.values) a: 20},
      wage: 10,
    );
    expect(gs.sdPriceFactor, lessThan(0.92));
    expect(gs.askingPriceFor(p), lessThan(without));
  });

  test('任せると、SDがクラブとも選手とも交渉して取ってくる', () async {
    final gs = await withSd();
    final before = {for (final p in gs.userTeam.players) p.id};
    await gs.updateSdBrief(active: true, maxFee: 99999999, maxSignings: 1);
    expect(gs.sdShortlist, isNotEmpty, reason: '狙える選手がいる前提');
    for (var i = 0; i < 12 && gs.save!.sdSignedThisWindow == 0; i++) {
      gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 2)));
    }
    expect(gs.save!.sdSignedThisWindow, 1);
    final added =
        gs.userTeam.players.where((p) => !before.contains(p.id)).toList();
    expect(added, hasLength(1));
    // 決めた人数を取ったら、それ以上は動かない。
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 6)));
    expect(gs.transferTalks.where((t) => t.bySd && t.isOpen), isEmpty);
  });

  test('任せていなければ、SDは動かない', () async {
    final gs = await withSd();
    await gs.updateSdBrief(active: false, maxFee: 99999999);
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 10)));
    expect(gs.transferTalks, isEmpty);
  });

  test('方針(位置・年齢・上限)に合う選手だけを狙う', () async {
    final gs = await withSd();
    await gs.updateSdBrief(
        active: true,
        maxFee: 99999999,
        groups: {PositionGroup.def},
        maxAge: 25);
    for (final p in gs.sdShortlist) {
      expect(p.position.group, PositionGroup.def);
      expect(p.age, lessThanOrEqualTo(25));
    }
    await gs.updateSdBrief(maxFee: 1);
    expect(gs.sdShortlist, isEmpty, reason: '上限が低すぎれば誰も狙わない');
  });

  test('方針は保存して読み戻せる', () async {
    final gs = await withSd();
    await gs.updateSdBrief(
        active: true,
        maxFee: 12345,
        groups: {PositionGroup.mid, PositionGroup.att},
        maxAge: 27,
        maxSignings: 2);
    final b = SaveGame.fromJson(gs.save!.toJson()).sdBrief;
    expect(b.active, isTrue);
    expect(b.maxFee, 12345);
    expect(b.groups, {PositionGroup.mid, PositionGroup.att});
    expect(b.maxAge, 27);
    expect(b.maxSignings, 2);
  });

  test('窓が閉じると、この窓で取った人数は0に戻る', () async {
    final gs = await withSd();
    gs.save!.sdSignedThisWindow = 2;
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 120)));
    expect(gs.isTransferWindowOpen, isFalse);
    expect(gs.save!.sdSignedThisWindow, 0);
  });
}
