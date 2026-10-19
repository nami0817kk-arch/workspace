import 'dart:math';

import 'package:baseball_manager/game/career.dart';
import 'package:baseball_manager/game/marks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tournamentTests();
  nameTests();
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

void tournamentTests() {
  test('次の大会までの残り。過ぎていれば来年まで出さない', () {
    final u = untilTournament(Stage.pro, 4)!;
    expect(u.left, 2);
    expect(u.name, 'シーズン終了');
    expect(u.unit, 'か月');
    expect(untilTournament(Stage.highSchool, 3)!.left, 0);
    expect(untilTournament(Stage.highSchool, 5), isNull);
    expect(untilTournament(Stage.youth, 0)!.unit, '季節');
    expect(untilTournament(Stage.retired, 0), isNull);
  });
}

void nameTests() {
  test('おまかせの名前は空でなく、10文字以内', () {
    for (var i = 0; i < 30; i++) {
      final n = randomNameOf(Random(i));
      expect(n, isNotEmpty);
      expect(n.length, lessThanOrEqualTo(10));
    }
  });
}
