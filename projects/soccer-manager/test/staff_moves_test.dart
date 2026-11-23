import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/ledger.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/staff_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

/// スタッフの行き来(引き抜き・候補の月ごとの入れ替え・元選手を雇う)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  StaffMember coach() => StaffMember(
        id: 'coach-test',
        name: 'テストコーチ',
        age: 45,
        role: StaffRole.headCoach,
        attributes: {for (final a in StaffAttribute.values) a: 18},
        wage: 20,
        contractYears: 2,
      );

  Future<(GameState, StaffOffer)> withOffer() async {
    final gs = GameState();
    await gs.startNewGame('行き来FC');
    gs.save!.wageBudget = 99999999;
    gs.save!.infrastructure.staff[StaffRole.headCoach] = coach();
    final o = StaffOffer(
      id: 'offer-x',
      role: StaffRole.headCoach,
      staffId: 'coach-test',
      staffName: 'テストコーチ',
      clubId: 'club-x',
      clubName: '大きいFC',
      compensation: 1000,
      raisePercent: 30,
      expiresOn: gs.today.add(const Duration(days: 14)),
    );
    gs.save!.staffOffers.add(o);
    return (gs, o);
  }

  test('良いスタッフほど狙われる(水準3以下は狙われない)', () {
    expect(GameStateStaffMoves.poachChance(3), 0);
    // 2026-11-23 に 8%+2%/段 から 2%+1%/段 へ下げた(引き抜きが多すぎた)。
    expect(GameStateStaffMoves.poachChance(4), closeTo(0.02, 1e-9));
    expect(GameStateStaffMoves.poachChance(8), closeTo(0.06, 1e-9));
  });

  test('昇給して残すと、週俸が上がり契約が1年延びる', () async {
    final (gs, o) = await withOffer();
    expect(await gs.keepStaffWithRaise(o.id), isTrue);
    final st = gs.staffFor(StaffRole.headCoach)!;
    expect(st.wage, 26);
    expect(st.contractYears, 3);
    expect(gs.staffOffers, isEmpty);
  });

  test('手放すと補償金が入り、役職は空席になる', () async {
    final (gs, o) = await withOffer();
    final before = gs.currentLedger.of(LedgerCategory.other);
    expect(await gs.releaseStaffToOffer(o.id), isTrue);
    expect(gs.staffFor(StaffRole.headCoach), isNull);
    expect(gs.currentLedger.of(LedgerCategory.other) - before,
        gs.scaledMoney(1000));
  });

  test('返事をしないまま期限が来ると、スタッフは移っていく', () async {
    final (gs, _) = await withOffer();
    gs.debugAdvanceTodayTo(gs.today.add(const Duration(days: 15)));
    expect(gs.staffFor(StaffRole.headCoach), isNull);
    expect(gs.staffOffers, isEmpty);
  });

  test('候補は月が替わると入れ替わる', () async {
    final gs = GameState();
    await gs.startNewGame('行き来FC');
    final ids = {for (final c in gs.save!.staffCandidates) c.id};
    final d = gs.today;
    gs.debugAdvanceTodayTo(DateTime(d.year, d.month + 1, 2));
    final now = {for (final c in gs.save!.staffCandidates) c.id};
    expect(now.intersection(ids), isEmpty);
  });

  test('引退した自クラブの選手が、安くスタッフの候補に出る(雇えば再び出ない)',
      () async {
    final gs = GameState();
    await gs.startNewGame('行き来FC');
    gs.save!.wageBudget = 99999999;
    // 元選手の候補になるのは総合力55以上。いちばん上の選手を引退させる。
    final legend = gs.userTeam.players
        .reduce((a, b) => a.overall >= b.overall ? a : b);
    expect(legend.overall, greaterThanOrEqualTo(55), reason: '前提');
    gs.userTeam.players.remove(legend);
    gs.userTeam.startingXI.remove(legend.id);
    gs.save!.retiredLegends.add(legend);
    final d = gs.today;
    gs.debugAdvanceTodayTo(DateTime(d.year, d.month + 1, 2));
    final c = gs.save!.staffCandidates
        .firstWhere((c) => c.formerPlayerId == legend.id);
    expect(c.name, legend.name);
    expect(c.wage, lessThan(StaffMember.askingWage(c.roleAbility)));
    expect(await gs.hireStaff(c.id), isTrue);
    gs.debugAdvanceTodayTo(DateTime(d.year, d.month + 2, 2));
    expect(
        gs.save!.staffCandidates.any((x) => x.formerPlayerId == legend.id),
        isFalse);
  });

  test('引き抜きの話と元選手の印は保存して読み戻せる', () async {
    final (gs, o) = await withOffer();
    gs.save!.infrastructure.staff[StaffRole.scout] = StaffMember(
        id: 's',
        name: 'x',
        age: 40,
        role: StaffRole.scout,
        attributes: const {},
        wage: 5,
        formerPlayerId: 'p1');
    final copy = SaveGame.fromJson(gs.save!.toJson());
    expect(copy.staffOffers.single.clubName, o.clubName);
    expect(copy.staffOffers.single.expiresOn, o.expiresOn);
    expect(copy.infrastructure.staffFor(StaffRole.scout)!.formerPlayerId, 'p1');
  });
}
