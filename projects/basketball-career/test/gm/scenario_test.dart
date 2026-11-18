import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('シナリオのチームは、いちばん弱い・強い・年俸が高いチーム', () {
    final c = Career.start(seed: 11);
    final weak = scenarioTeam(c, Scenario.rebuild), strong = scenarioTeam(c, Scenario.dynasty), rich = scenarioTeam(c, Scenario.taxHell);
    expect(c.strengthRank(weak), c.teams.length - 1);
    expect(c.strengthRank(strong), 0);
    expect(c.teams[rich].payroll, c.teams.map((t) => t.payroll).reduce((a, b) => a > b ? a : b));
  });

  test('期限までに果たせなければ失敗、果たせば達成。保存される', () {
    final seed = 13;
    final weak = Career.start(seed: seed, team: scenarioTeam(Career.start(seed: seed), Scenario.dynasty))..startScenario(Scenario.dynasty);
    expect(weak.scenarioOf, Scenario.dynasty);
    var guard = 0;
    while (weak.scenarioResult == 0 && guard++ < 8000) {
      if (weak.phase == Phase.seasonEnd) weak.fired = false;
      botStep(weak);
    }
    expect(weak.scenarioResult, isNot(0), reason: '期限の2年目が終われば、どちらかに決まる');
    expect(weak.season, lessThanOrEqualTo(Scenario.dynasty.years + 1));
    final back = Career.fromJson(weak.toJson());
    expect(back.scenarioOf, Scenario.dynasty);
    expect(back.scenarioResult, weak.scenarioResult);
    expect(back.scenarioTeamId, weak.scenarioTeamId);
  });

  test('年俸の山: ぜいたく税の線より下で勝ち越せば達成', () {
    final c = Career.start(seed: 5);
    expect(scenarioDone(c, Scenario.taxHell, rank: 1, result: 0), c.me.payroll < taxLine && c.me.wins > c.me.losses);
    // ふつうに始めたらシナリオは無い
    expect(Career.fromJson(c.toJson()).scenarioOf, isNull);
  });
}
