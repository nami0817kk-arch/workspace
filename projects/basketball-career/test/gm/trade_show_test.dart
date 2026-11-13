import 'package:basketball_career/gm/block_report.dart';
import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/trade_show.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('トレードの成立: 出した選手は外へ、受け取った選手は登録に入り、評価が付く', () {
    var done = 0;
    for (final seed in [3, 7, 11, 19]) {
      final c = careerAt(10, seed)..startSeason();
      while (c.phase == Phase.season && (c.incoming == null || !c.canTrade)) {
        c.playBlock();
      }
      final o = c.incoming;
      if (o == null) continue;
      final s = tradeSnap(c, o);
      final before = c.tradesDone;
      c.acceptIncoming();
      if (c.tradesDone == before) continue;
      final r = tradeResult(c, s);
      final ids = {for (final p in c.me.roster) p.id};
      expect(s.give.every((p) => !ids.contains(p.id)), isTrue);
      expect(s.get.every((p) => ids.contains(p.id)), isTrue);
      expect(['A', 'B', 'C', 'D'], contains(r.grade));
      expect(r.rankAfter, inInclusiveRange(0, c.teams.length - 1));
      expect(r.payrollAfter, c.me.payroll);
      done++;
    }
    expect(done, greaterThan(0));
  });

  test('締め切りを過ぎた区切りの報告に、今季のトレードが古い順に並ぶ', () {
    final c = careerAt(10, 5)..startSeason();
    while (c.block < tradeDeadlineBlock - 1) {
      c.declineIncoming();
      c.playBlock();
    }
    final snap = BlockSnapshot.of(c);
    c.playBlock();
    final r = BlockReport.make(c, snap);
    expect(r.deadlinePassed, isTrue);
    final logged = c.log.where((l) => l.startsWith('${c.season}年目 トレード: ')).length;
    expect(r.deadlineTrades.length, logged);
    expect(r.deadlineTrades.every((t) => !t.startsWith('トレード')), isTrue);
  });
}
