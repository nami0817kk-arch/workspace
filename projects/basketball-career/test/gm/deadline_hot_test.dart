import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み T-5: 締め切りの競り合い。
void main() {
  test('締め切りの1区切り前に目玉が知らされ、締め切りまでに取らなければ、ほかのチームへ行く', () {
    var checked = 0, movedAll = 0;
    for (var seed = 1; seed <= 10 && movedAll == 0; seed++) {
      final c = careerAt(seed, 12)..startSeason();
      while (c.phase == Phase.season && c.block < tradeDeadlineBlock - 1) {
        c.playBlock();
      }
      if (c.hotTargets.isEmpty) continue;
      expect(c.inbox.where((m) => m.title.startsWith('締め切りの目玉')), isNotEmpty);
      final y = Career.fromJson(c.toJson());
      expect(y.hotTargets.keys, c.hotTargets.keys);
      final before = {for (final e in c.hotTargets.entries) e.key: e.value.$1};
      c.playBlock();
      expect(c.block, tradeDeadlineBlock);
      expect(c.hotTargets, isEmpty);
      var moved = 0;
      for (final e in before.entries) {
        if (!c.teams[e.value].roster.any((p) => p.id == e.key)) moved++;
      }
      movedAll += moved;
      checked++;
    }
    expect(checked, greaterThan(0));
    expect(movedAll, greaterThan(0), reason: '競り負けて、目玉がほかのチームへ行った年がある');
  });
}
