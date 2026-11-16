import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/shareholder_engine.dart';

/// 株主の期待は、資金が黒字かどうかだけでなく、利益率と人件費率でも動く。
void main() {
  int delta({
    int budget = 1000,
    int? profit,
    int? income,
    double wage = 0,
  }) =>
      ShareholderEngine.deltaForSeasonEnd(
        budget: budget,
        profit: profit,
        operatingIncome: income,
        wageRatio: wage,
      );

  test('利益率の情報が無ければ、旧来の黒字/赤字の評価だけ', () {
    expect(delta(), ShareholderEngine.blackSeasonBonus);
    expect(delta(budget: -1), -ShareholderEngine.redSeasonPenalty);
  });

  test('利益率が高いと加点、薄いと減点、赤字だと大きく減点', () {
    final good = delta(profit: 200, income: 1000);
    final ok = delta(profit: 100, income: 1000);
    final thin = delta(profit: 20, income: 1000);
    final loss = delta(profit: -50, income: 1000);
    expect(good, greaterThan(ok));
    expect(ok, greaterThan(thin));
    expect(thin, greaterThan(loss));
  });

  test('黒字の資金でも、利益が薄く人件費が重ければ、加点が消える', () {
    final heavy = delta(profit: 20, income: 1000, wage: 0.9);
    expect(heavy, lessThan(ShareholderEngine.blackSeasonBonus));
  });

  test('人件費率は注意・危険の2段階で減点が重くなる', () {
    final safe = delta(profit: 100, income: 1000, wage: 0.5);
    final warn = delta(profit: 100, income: 1000, wage: 0.75);
    final danger = delta(profit: 100, income: 1000, wage: 0.9);
    expect(warn, lessThan(safe));
    expect(danger, lessThan(warn));
  });

  test('営業収入が0なら利益率は見ない', () {
    expect(delta(profit: -100, income: 0), ShareholderEngine.blackSeasonBonus);
  });
}
