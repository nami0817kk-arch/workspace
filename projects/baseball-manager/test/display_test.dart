import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/marks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('今日のヒントは日付で決まり、同じ日は同じ。種類が12ある', () {
    final d = DateTime(2026, 10, 19);
    expect(tipOf(d), tipOf(d));
    expect(tipCount, 12);
    final seen = {
      for (var i = 0; i < 40; i++) tipOf(DateTime(2026, 10, 1 + i % 28, 0))
    };
    expect(seen.length, greaterThan(3));
  });
  test('今年の予定は段階ごとにあり、引退後は空', () {
    for (final s in Stage.values) {
      final plan = yearPlanOf(s, 25);
      if (s == Stage.retired) {
        expect(plan, isEmpty);
      } else {
        expect(plan, isNotEmpty, reason: s.name);
      }
    }
    expect(yearPlanOf(Stage.pro, 26).any((e) => e.contains('世界大会')), isTrue);
    expect(yearPlanOf(Stage.pro, 27).any((e) => e.contains('世界大会')), isFalse);
  });
}
