import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 年俸の合計を [target] に近づける(いちばん上の選手の年俸で調整する)。
Team _teamAt(int target) {
  final t = careerAt(3, 10).me;
  t.roster.first.salary += target - t.payroll;
  return t;
}

void main() {
  group('お金と壁(2026-27 の公式の値)', () {
    test('上限・ぜいたく税・2つの壁の金額と並び順', () {
      // 単位は10万ドル。NBA の発表: 1億6,496万ドル・2億43万ドル・2億901万ドル・2億2,168万ドル
      expect(salaryCap, 1650);
      expect(taxLine, 2004);
      expect(firstApron, 2090);
      expect(secondApron, 2217);
      expect(salaryCap, lessThan(taxLine));
      expect(taxLine, lessThan(firstApron));
      expect(firstApron, lessThan(secondApron));
      expect(money(salaryCap), '1.65億ドル');
    });

    test('1人の年俸の上限は在籍年数で変わる(上限額の25%・30%・35%)', () {
      expect(maxSalaryFor(0), 412);
      expect(maxSalaryFor(6), 412);
      expect(maxSalaryFor(7), 495);
      expect(maxSalaryFor(9), 495);
      expect(maxSalaryFor(10), 577);
      expect(maxSalaryFor(20), maxSalary);
      expect((salaryCap * 0.25).round(), closeTo(maxSalaryFor(0), 1));
      expect((salaryCap * 0.30).round(), closeTo(maxSalaryFor(7), 1));
      expect((salaryCap * 0.35).round(), closeTo(maxSalaryFor(10), 1));
      // 力の高い若手でも、在籍年数の上限を超える年俸にはならない
      expect(fairSalary(99, 24), lessThanOrEqualTo(maxSalary));
    });

    test('第2の壁を超えるチームは、複数の選手を合わせて受け取る年俸に当てられない', () {
      final t = _teamAt(secondApron + 50);
      expect(t.payroll, greaterThan(secondApron));
      // 100 を1人で出して 100 を受け取る: 当てずに済む
      expect(salaryRuleProblem(t, 100, 100, maxSingleOut: 100), isNull);
      // 60+60 を出して 100 を受け取る(合わせて当てる): 受けられない
      expect(salaryRuleProblem(t, 100, 120, maxSingleOut: 60), contains('第2の壁'));
      // 100 を出して 105 を受け取る: 出す年俸より増える
      expect(salaryRuleProblem(t, 105, 100, maxSingleOut: 100), contains('第2の壁'));
    });

    test('第1の壁を超えるチームは、受け取る年俸を出す年俸の110%まで', () {
      final t = _teamAt((firstApron + secondApron) ~/ 2);
      expect(t.payroll, inExclusiveRange(firstApron, secondApron));
      expect(salaryRuleProblem(t, 110, 100, maxSingleOut: 100), isNull);
      expect(salaryRuleProblem(t, 115, 100, maxSingleOut: 100), contains('第1の壁'));
    });

    test('上限を超え第1の壁の下のチームは、125%＋100万ドルまで(今までどおり)', () {
      final t = _teamAt((salaryCap + firstApron) ~/ 2);
      expect(salaryRuleProblem(t, 135, 100, maxSingleOut: 100), isNull);
      expect(salaryRuleProblem(t, 136, 100, maxSingleOut: 100), isNotNull);
    });

    test('固い上限は無い: 壁を超えても、トレードの決まりに当たらなければ受けられる', () {
      final t = _teamAt(secondApron + 400);
      expect(salaryRuleProblem(t, 50, 100, maxSingleOut: 100), isNull, reason: '年俸が減るトレードは、合計がどれだけ高くても通る');
    });
  });
}
