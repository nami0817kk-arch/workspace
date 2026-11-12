import 'package:flutter_test/flutter_test.dart';

import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';

void main() {
  test('いま出せる年俸の上限は、上限の空きか例外枠の大きいほう。シーズン中は最低年俸', () {
    final c = Career.start(seed: 4);
    final (amt, from) = c.maxOfferNow;
    final room = salaryCap - c.me.payroll;
    expect(amt, greaterThanOrEqualTo(minSalary));
    expect(amt, greaterThanOrEqualTo(room));
    expect(from, isNotEmpty);
    c.ownerMeeting(2);
    c.startSeason();
    expect(c.maxOfferNow.$1, minSalary);
  });
}
