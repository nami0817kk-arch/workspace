import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/manager_hr_engine.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/manager_profile.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 監督の人事(考え方・目標と立場・解任の違約金・引き抜き・経歴)の検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('決まり', () {
    test('目標どおりなら立場は上がり、下回るほど大きく下がる', () {
      expect(ManagerHrEngine.standingDelta(rank: 5, target: 5), 2);
      expect(ManagerHrEngine.standingDelta(rank: 1, target: 5), 3);
      expect(ManagerHrEngine.standingDelta(rank: 6, target: 5), -2);
      expect(ManagerHrEngine.standingDelta(rank: 9, target: 5), -6);
      expect(ManagerHrEngine.standingDelta(rank: 18, target: 1), -6);
    });

    test('考え方で構えが一段ずれる(端では止まる)', () {
      expect(ManagerStyle.attacking.shift(TeamMentality.balanced),
          TeamMentality.attacking);
      expect(ManagerStyle.defensive.shift(TeamMentality.balanced),
          TeamMentality.defensive);
      expect(ManagerStyle.pragmatic.shift(TeamMentality.defensive),
          TeamMentality.defensive);
      expect(ManagerStyle.attacking.shift(TeamMentality.veryAttacking),
          TeamMentality.veryAttacking);
    });

    test('監督の解任は残りの契約の年俸を全額、他の役職は2割', () {
      StaffMember s(StaffRole r) => StaffMember(
          id: r.name,
          name: 'x',
          age: 50,
          role: r,
          attributes: const {},
          wage: 10,
          contractYears: 2);
      // 季の始め(7月1日)に解任すると、残りは2季ぶん(翌々年の6月30日まで
      // 730日 = 105週、切り上げ)。
      final july1 = DateTime(2026, 7, 1);
      expect(s(StaffRole.manager).severanceOn(july1, 2027), 10 * 105);
      expect(s(StaffRole.scout).severanceOn(july1, 2027),
          (10 * 105 * 0.2).round());
      expect(s(StaffRole.manager).severanceRate,
          ManagerHrEngine.managerSeveranceRate);
      expect(ManagerHrEngine.compensation(weeklyWage: 10, contractYears: 2),
          520);
    });
  });

  group('ゲームの中', () {
    test('監督の候補には考え方と経歴があり、他のクラブで指揮している人もいる',
        () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      final cands = gs.staffCandidatesFor(StaffRole.manager);
      expect(cands.every((c) => c.manager != null), isTrue);
      final employed =
          cands.where((c) => c.manager!.employerClubName != null).toList();
      expect(employed, isNotEmpty);
      expect(employed.every((c) => c.manager!.compensation > 0), isTrue);
      expect(employed.every((c) => c.manager!.career.isNotEmpty), isTrue);
    });

    test('引き抜くと補償金を払い、好みの布陣に変わり、立場は新しくなる', () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      gs.save!.budget = 99999999;
      gs.save!.wageBudget = 99999999;
      gs.save!.managerStanding = 5;
      final c = gs
          .staffCandidatesFor(StaffRole.manager)
          .firstWhere((c) => c.manager!.employerClubName != null);
      final comp = gs.scaledMoney(c.manager!.compensation);
      final before = gs.save!.budget;
      expect(await gs.hireStaff(c.id), isTrue);
      expect(before - gs.save!.budget, greaterThanOrEqualTo(comp));
      expect(gs.currentManager!.id, c.id);
      expect(gs.currentManager!.manager!.employerClubName, isNull);
      expect(gs.userTeam.formation, c.manager!.formation);
      expect(gs.managerStanding, ManagerHrEngine.startingStanding);
    });

    test('補償金が払えなければ雇えず、理由が残る', () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      gs.save!.budget = 0;
      gs.save!.wageBudget = 99999999;
      final c = gs
          .staffCandidatesFor(StaffRole.manager)
          .firstWhere((c) => c.manager!.employerClubName != null);
      expect(await gs.hireStaff(c.id), isFalse);
      expect(gs.lastSigningBlockReason, isNotNull);
    });

    test('目標は伝えた順位になり、リーグの外には出ない', () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      expect(gs.managerTarget, gs.suggestedManagerTarget);
      await gs.setManagerTarget(1);
      expect(gs.managerTarget, 1);
      await gs.setManagerTarget(999);
      expect(gs.managerTarget, gs.save!.league.teams.length);
    });

    test('季が終わると、監督の経歴に今季が残る', () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      gs.save!.wageBudget = 99999999;
      if (gs.currentManager == null) {
        await gs.hireStaff(gs.staffCandidatesFor(StaffRole.manager).first.id);
      }
      final m = gs.currentManager!;
      final before = m.manager!.career.length;
      await gs.simulateAheadMatchdays(60);
      await gs.startNextSeason();
      final after = gs.save!.infrastructure.staffFor(StaffRole.manager);
      // 契約が満了して去ることもある。残っていれば経歴が1つ増えている。
      if (after != null && after.id == m.id) {
        expect(after.manager!.career.length, before + 1);
        expect(after.manager!.career.last.club, gs.save!.clubName);
      }
      expect(gs.save!.managerTargetRank, 0, reason: '新しい季の目標は戦力どおりに戻る');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('監督の考え方・経歴・目標・立場は保存して読み戻せる', () async {
      final gs = GameState();
      await gs.startNewGame('人事FC');
      gs.save!.wageBudget = 99999999;
      await gs.hireStaff(gs.staffCandidatesFor(StaffRole.manager).first.id);
      await gs.setManagerTarget(3);
      gs.save!.managerStanding = 42;
      final copy = SaveGame.fromJson(gs.save!.toJson());
      final m = copy.infrastructure.staffFor(StaffRole.manager)!;
      expect(m.manager!.style, gs.currentManager!.manager!.style);
      expect(m.manager!.formation, gs.currentManager!.manager!.formation);
      expect(m.manager!.career.length,
          gs.currentManager!.manager!.career.length);
      expect(copy.managerTargetRank, 3);
      expect(copy.managerStanding, 42);
    });
  });
}
