import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/advisor_engine.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/staff_member.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });
  tearDown(() => Tr.language = AppLanguage.system);

  test('報酬はレベルに比例し、効果も段階的に増える', () {
    expect(AdvisorEngine.salary(0), 0);
    expect(AdvisorEngine.salary(2), 2 * AdvisorEngine.salary(1));
    expect(AdvisorEngine.incomeMultiplier(3), greaterThan(AdvisorEngine.incomeMultiplier(1)));
    expect(AdvisorEngine.facilityCostMultiplier(3), lessThan(1));
    expect(AdvisorEngine.totalSalary({'finance': 1, 'pr': 2}),
        AdvisorEngine.salary(1) + AdvisorEngine.salary(2));
  });

  test('財務顧問を雇うと週収入が増える', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final id = gs.save!.userTeamId;
    final before = gs.weeklyIncomeFor(id);
    expect(await gs.setAdvisorLevel(Advisor.finance, 3), isTrue);
    expect(gs.weeklyIncomeFor(id), greaterThan(before));
    expect(await gs.setAdvisorLevel(Advisor.finance, 4), isFalse);
  });

  test('強化顧問を雇うと施設の増築費が下がる', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    final before = gs.facilityUpgradeCostFor(FacilityType.stadium);
    await gs.setAdvisorLevel(Advisor.scouting, 3);
    expect(gs.facilityUpgradeCostFor(FacilityType.stadium), lessThan(before));
  });

  test('保存して読み戻せ、無い旧セーブは空', () async {
    final gs = GameState();
    await gs.startNewGame('テストFC');
    await gs.setAdvisorLevel(Advisor.pr, 2);
    final json = gs.save!.toJson();
    expect(SaveGame.fromJson(json).advisors, {'pr': 2});
    json.remove('advisors');
    expect(SaveGame.fromJson(json).advisors, isEmpty);
  });

  test('解任の違約金は、残りの契約があるときだけ掛かり、監督は重い', () {
    StaffMember s(StaffRole r, int years) => StaffMember(
          id: 'x',
          name: 'x',
          age: 40,
          role: r,
          attributes: const {},
          wage: 10,
          contractYears: years,
        );
    expect(s(StaffRole.scout, 0).severance, 0);
    expect(s(StaffRole.manager, 2).severance,
        greaterThan(s(StaffRole.scout, 2).severance));
  });
}
