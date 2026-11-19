import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/promise.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts(int seed) {
  final c = careerAt(seed, 3);
  var guard = 0;
  while (!(c.phase == Phase.contracts && c.freeAgents.where(c.isBigFa).length >= 3)) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('契約の場面に着かない');
  }
  return c;
}

void main() {
  test('勧誘: 1オフに2人まで。合って本当らしい話ほど関心が上がり、口だけだと下がる', () {
    final c = _atContracts(1);
    final big = c.freeAgents.where(c.isBigFa).toList();
    final before = {for (final p in big) p.id: c.interest(p, c.mine)};
    for (final p in big.take(2)) {
      expect(c.pitchProblem(p), isNull);
      // 合う話を探す(合う話が無い選手は優勝の話)
      final kind = [0, 1, 2].firstWhere((k) => c.pitchFits(p, k), orElse: () => 0);
      c.pitch(p.id, kind);
      expect(c.pitches[p.id], kind);
      final b = c.pitchBonus(p);
      expect(b, c.pitchFits(p, kind) && c.pitchCredible(p, kind) ? 14 : c.pitchFits(p, kind) ? 4 : c.pitchCredible(p, kind) ? 5 : -3);
      expect(c.interest(p, c.mine), (before[p.id]! + b).clamp(0, 100));
      expect(c.pitchReaction(p), isNotEmpty);
    }
    expect(c.pitchProblem(big[2]), contains('2人まで'));
    expect(c.pitchProblem(big[0]), 'もう会った');
    final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(copy.pitches, c.pitches);
    // ほかのチームから見た関心は変わらない
    final other = (c.mine + 1) % c.teams.length;
    final d = _atContracts(1);
    for (final p in big.take(2)) {
      final q = d.freeAgents.firstWhere((x) => x.id == p.id);
      expect(c.interest(p, other), d.interest(q, other));
    }
  });

  test('「主役として使う」と言って取ると、来季の先発の約束になる', () {
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final c = _atContracts(seed);
      Player? got;
      for (final p in c.freeAgents.where(c.isBigFa).toList()) {
        if (c.bidProblem(p, factor: 1.3) != null) continue;
        c.pitch(p.id, 1);
        c.bid(p.id, 2, 1.3);
        got = p;
        break;
      }
      if (got == null) continue;
      while (c.faDay < faDays && !c.me.roster.contains(got)) {
        c.nextFaDay();
      }
      if (!c.me.roster.contains(got)) continue;
      final x = c.openPromises.firstWhere((x) => x.kind == PromiseKind.starter && x.player == got!.id);
      expect(x.due, (c.season + 1) * blocksPerSeason + 2);
      return;
    }
    fail('主役と言って取れる場面が来ない');
  });
}
