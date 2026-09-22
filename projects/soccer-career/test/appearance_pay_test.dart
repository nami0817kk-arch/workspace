/// 出場給。出た試合数で年俸の一部が動く。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/reputation.dart';

void main() {
  test('基準ちょうどなら 0。世界の金額は動かない', () {
    expect(
      Formulas.appearanceBonus(
        salary: 10000,
        appearances: Formulas.appearanceBaseline,
      ),
      0,
    );
  });

  test('出るほど増え、欠けるほど減る', () {
    final many = Formulas.appearanceBonus(salary: 10000, appearances: 38);
    final few = Formulas.appearanceBonus(salary: 10000, appearances: 10);
    expect(many, greaterThan(0));
    expect(few, lessThan(0));
    // 1試合も出なければ、上限いっぱい引かれる。
    expect(
      Formulas.appearanceBonus(salary: 10000, appearances: 0),
      (-10000 * Formulas.appearanceBonusRate).round(),
    );
  });

  test('見込みと実際が同じ式から出る', () {
    // 片方だけ出場数を見ると、画面の数字とシーズン末の結果がずれる。
    const finances = Finances(savings: 1000);
    final budget = finances.budgetFor(
      salary: 8000,
      agentFeePercent: 5,
      appearances: 12,
    );
    final after = finances.afterSeason(
      salary: 8000,
      agentFeePercent: 5,
      appearances: 12,
    );
    expect(after.savings, finances.savings + budget.net);
    expect(budget.appearanceBonus, lessThan(0));
  });
}
