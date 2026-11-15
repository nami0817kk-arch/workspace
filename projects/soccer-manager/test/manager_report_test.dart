import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/manager_report_engine.dart';

/// 監督の週次報告。2つの期待と資金から、一言と数字の行を作る。
void main() {
  ManagerReport build({
    int supporter = 50,
    int shareholder = 50,
    int budget = 1000,
    String? lastResult,
  }) =>
      ManagerReportEngine.build(
        rank: 3,
        teamCount: 20,
        tier: 1,
        supporter: supporter,
        shareholder: shareholder,
        budget: budget,
        weeklyNet: 20,
        lastResult: lastResult,
      );

  test('順位・週の収支の行が出て、直近の結果は渡したときだけ出る', () {
    final without = build();
    expect(without.lines.length, 2);
    final withLast = build(lastResult: '勝ち 2-0');
    expect(withLast.lines.length, 3);
    expect(withLast.lines.any((l) => l.contains('勝ち 2-0')), isTrue);
  });

  test('期待が両方高ければ順調、片方が低ければそちらを名指しする', () {
    final good = build(supporter: 80, shareholder: 80);
    final fans = build(supporter: 20, shareholder: 80);
    final holders = build(supporter: 80, shareholder: 20);
    expect(good.headline, isNot(equals(fans.headline)));
    expect(fans.headline, isNot(equals(holders.headline)));
    expect(good.headline, isNot(equals(holders.headline)));
  });

  test('両方が危ういときは、最優先の一言になる', () {
    final both = build(supporter: 10, shareholder: 10, budget: -500);
    final fansOnly = build(supporter: 10, shareholder: 80);
    expect(both.headline, isNot(equals(fansOnly.headline)));
  });

  test('資金がマイナスなら、期待が普通でもそれを指摘する', () {
    final red = build(budget: -1);
    final ok = build(budget: 1);
    expect(red.headline, isNot(equals(ok.headline)));
  });
}
