import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts(int seed) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (c.phase != Phase.contracts) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('契約の場面に着かない');
  }
  return c;
}

void main() {
  test('電話: 契約の時期に2件まで届く。相手は別々で、同じ選手を重ねない。保存で残る', () {
    var seen = 0;
    for (final seed in [1, 2, 3, 4, 5]) {
      final c = _atContracts(seed);
      expect(c.calls.length, lessThanOrEqualTo(2));
      if (c.calls.isEmpty) continue;
      seen++;
      expect(c.calls.map((o) => o.partner).toSet().length, c.calls.length);
      expect(c.calls.every(c.callValid), isTrue);
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(jsonEncode([for (final o in copy.calls) o.toJson()]), jsonEncode([for (final o in c.calls) o.toJson()]));
    }
    expect(seen, greaterThan(0));
  });

  test('電話: 受けると成立して選手が入れ替わる。断ると消える。オフを終えると残りも消える', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final c = _atContracts(seed);
      if (c.calls.isEmpty) continue;
      final o = c.calls.first;
      final before = c.tradesDone;
      expect(c.acceptCall(0), isTrue);
      expect(c.tradesDone, before + 1);
      expect(o.give.every((id) => c.teams[o.partner].roster.any((p) => p.id == id)), isTrue);
      expect(o.get.every((id) => c.me.roster.any((p) => p.id == id)), isTrue);
      expect(c.calls.contains(o), isFalse);
      if (c.calls.isNotEmpty) {
        c.declineCall(0);
        expect(c.calls, isEmpty);
      }
      final d = _atContracts(seed);
      d.finishContracts();
      expect(d.calls, isEmpty);
      return;
    }
    fail('電話が来ない');
  });

  test('電話は受けなければ何も変えない(リーグの乱数を使わない)', () {
    final a = _atContracts(6);
    final b = _atContracts(6);
    expect(a.rng.next(), b.rng.next());
  });
}
