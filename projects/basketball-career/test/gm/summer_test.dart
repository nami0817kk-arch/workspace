import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/summer.dart';
import 'package:flutter_test/flutter_test.dart';

/// オフの契約の場面まで進めた経歴(解任されないようにする)。
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
  test('サマーリーグ: 若手が出て、成績と出来が残り、性格が分かる。1オフに1回だけ', () {
    for (final seed in [1, 2, 3]) {
      final c = _atContracts(seed);
      expect(c.summerProblem, isNull);
      final players = c.summerPlayers;
      expect(players, isNotEmpty);
      expect(players.length, lessThanOrEqualTo(summerMaxPlayers));
      expect(players.every(summerEligible), isTrue);
      final before = {for (final p in players) p.id: (p.ovr, p.morale)};
      c.playSummerLeague();
      expect(c.summerDone, isTrue);
      expect(c.summer.length, players.length);
      expect(c.summerWins, inInclusiveRange(0, summerGames));
      for (final p in players) {
        final x = c.summer.firstWhere((x) => x.id == p.id);
        expect(p.traitsKnown, isTrue);
        expect(p.ovr - before[p.id]!.$1, x.delta);
        expect(x.delta, inInclusiveRange(0, 1));
        expect(['A', 'B', 'C', 'D'], contains(x.grade));
        if (x.delta > 0) expect(x.grade == 'A' || x.grade == 'B', isTrue);
      }
      expect(c.inbox.first.title, startsWith('サマーリーグを終えた'));
      // 2回目は開けない
      expect(c.summerProblem, isNotNull);
      final again = jsonEncode(c.summer.map((x) => x.toJson()).toList());
      c.playSummerLeague();
      expect(jsonEncode(c.summer.map((x) => x.toJson()).toList()), again);
      // 保存して読み戻しても残る
      final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(copy.summerDone, isTrue);
      expect(copy.summerWins, c.summerWins);
      expect(jsonEncode(copy.summer.map((x) => x.toJson()).toList()), again);
    }
  });

  test('サマーリーグは契約の時期だけ。押さなければリーグは何も変わらない', () {
    final c = careerAt(4, 12);
    expect(c.phase, isNot(Phase.contracts));
    expect(c.summerProblem, isNotNull);
    final a = _atContracts(5);
    final b = _atContracts(5);
    a.playSummerLeague();
    // サマーリーグはリーグの乱数を使わない: 開いたあとも、同じ種の経歴と次の乱数がそろう
    expect(a.rng.next(), b.rng.next());
  });
}
