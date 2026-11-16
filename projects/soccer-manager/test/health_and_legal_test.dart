import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/advisor_engine.dart';
import 'package:soccer_manager/logic/club_health_engine.dart';

/// 経営診断(A〜E)と、法務顧問(罰金が軽くなる)。
void main() {
  group('経営診断', () {
    test('すべて良好なら満点でA、すべて悪ければ0でE', () {
      final best = ClubHealthEngine.assess(
          supporter: 100, shareholder: 100, wageRatio: 0.4, budget: 5000);
      expect(best.score, 100);
      expect(best.grade, 'A');
      final worst = ClubHealthEngine.assess(
          supporter: 0, shareholder: 0, wageRatio: 0.95, budget: -100);
      expect(worst.score, 0);
      expect(worst.grade, 'E');
    });

    test('評価の境目は 80/65/50/35', () {
      expect(ClubHealthEngine.gradeFor(80), 'A');
      expect(ClubHealthEngine.gradeFor(79), 'B');
      expect(ClubHealthEngine.gradeFor(65), 'B');
      expect(ClubHealthEngine.gradeFor(64), 'C');
      expect(ClubHealthEngine.gradeFor(50), 'C');
      expect(ClubHealthEngine.gradeFor(49), 'D');
      expect(ClubHealthEngine.gradeFor(35), 'D');
      expect(ClubHealthEngine.gradeFor(34), 'E');
    });

    test('人件費率が重いほど、資金が少ないほど点が下がる', () {
      int score({double wage = 0.6, int budget = 2000}) =>
          ClubHealthEngine.assess(
                  supporter: 60, shareholder: 60, wageRatio: wage, budget: budget)
              .score;
      expect(score(wage: 0.5), greaterThan(score(wage: 0.7)));
      expect(score(wage: 0.7), greaterThan(score(wage: 0.9)));
      expect(score(budget: 3000), greaterThan(score(budget: 1000)));
      expect(score(budget: 1000), greaterThan(score(budget: -500)));
    });

    test('点数は0〜100に収まる', () {
      final s = ClubHealthEngine.assess(
          supporter: 500, shareholder: 500, wageRatio: -3, budget: 999999);
      expect(s.score, inInclusiveRange(0, 100));
    });
  });

  group('法務顧問', () {
    test('レベルが高いほど罰金が軽くなり、0にはなっても負にはならない', () {
      expect(AdvisorEngine.fineMultiplier(0), 1.0);
      expect(AdvisorEngine.fineMultiplier(1), closeTo(0.85, 1e-9));
      expect(AdvisorEngine.fineMultiplier(3), closeTo(0.55, 1e-9));
      expect(AdvisorEngine.fineMultiplier(99), 0.0);
    });

    test('顧問は4人になり、法務の報酬も合計に入る', () {
      expect(Advisor.values.contains(Advisor.legal), isTrue);
      final withLegal = AdvisorEngine.totalSalary({Advisor.legal.name: 2});
      expect(withLegal, AdvisorEngine.salary(2));
      expect(Advisor.legal.label, isNotEmpty);
      expect(Advisor.legal.effect(2), isNotEmpty);
    });
  });
}
