import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ホームとアウェイは長く続かず、ホームの数はほぼ半分', () {
    final s = seasonSchedule(30);
    for (var t = 0; t < 30; t++) {
      var home = 0, run = 0, best = 0;
      int? last;
      for (final round in s) {
        for (final (a, b) in round) {
          if (a != t && b != t) continue;
          final h = a == t ? 1 : 0;
          home += h;
          run = h == last ? run + 1 : 1;
          last = h;
          if (run > best) best = run;
        }
      }
      expect(best, lessThanOrEqualTo(3), reason: 'チーム$t の連続');
      expect(home, inInclusiveRange(39, 43), reason: 'チーム$t のホーム数');
    }
  });
}
