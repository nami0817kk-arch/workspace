import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/projection_engine.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 5年の収支の見込みの検査。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('収入は年3%、人件費は年5%伸び、資金は損益と税で動く', () {
    final rows = ProjectionEngine.project(
        income: 1000, wages: 600, otherCosts: 200, budget: 500);
    expect(rows, hasLength(5));
    expect(rows.first.income, 1030);
    expect(rows.first.wages, 630);
    final pre = 1030 - 630 - 200;
    expect(rows.first.tax, (pre * 0.3).round());
    expect(rows.first.budget, 500 + pre - rows.first.tax);
    // 人件費の伸びが速いので、損益は年々細る。
    expect(rows.last.profit, lessThan(rows.first.profit));
  });

  test('赤字の年は税がかからず、繰越欠損が翌年の税を減らす', () {
    final rows = ProjectionEngine.project(
        income: 1000, wages: 1100, otherCosts: 0, budget: 0);
    expect(rows.every((r) => r.tax == 0), isTrue);
    expect(rows.last.budget, lessThan(0));
  });

  test('季の途中の数字は1年分に引き延ばす(始まったばかりはそのまま)', () {
    expect(ProjectionEngine.annualize(500, 0.5), 1000);
    expect(ProjectionEngine.annualize(500, 0.05), 500);
  });

  test('始めたばかりでも、見込みが出る(収入は1節から見積もる)', () async {
    final gs = GameState();
    await gs.startNewGame('見込みFC');
    final rows = gs.fiveYearProjection;
    expect(rows, hasLength(5));
    expect(rows.first.income, greaterThan(0));
    expect(rows.first.wages, greaterThan(0));
  });
}
