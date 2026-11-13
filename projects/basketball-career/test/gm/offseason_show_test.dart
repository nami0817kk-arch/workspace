import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/offseason_show.dart';
import 'package:flutter_test/flutter_test.dart';

Career _toContracts(int strength, int seed) {
  final c = careerAt(strength, seed);
  var guard = 0;
  while (c.phase != Phase.contracts && guard++ < 600) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
  }
  return c;
}

void main() {
  test('自由契約の1日: 申し込んだ選手の結果と、その日の契約が出る', () {
    final c = _toContracts(28, 5);
    expect(c.phase, Phase.contracts);
    expect(c.offStartIds, isNotEmpty);
    // 大物に申し込んでおく(取れる選手を上から)
    final target = c.freeAgents.where((p) => c.isBigFa(p) && c.bidProblem(p) == null).firstOrNull;
    if (target != null) expect(c.bid(target.id, 2, 1.1), isTrue);
    var seen = false;
    while (c.faDay < faDays) {
      final snap = faSnapshot(c);
      c.nextFaDay();
      final r = faDayReport(c, snap);
      expect(r.day, snap.day + 1);
      expect(r.daysLeft, faDays - c.faDay);
      for (final m in r.signed) {
        expect(m.day, snap.day);
      }
      if (target != null && snap.mine.containsKey(target.id)) {
        expect(r.mine.map((b) => b.name), contains(target.name));
        final b = r.mine.firstWhere((b) => b.name == target.name);
        if (b.outcome == BidOutcome.signed) expect(c.me.roster.any((p) => p.id == target.id), isTrue);
        if (b.outcome == BidOutcome.lost) expect(b.move!.team, isNot(c.mine));
        seen = true;
      }
      if (c.sheet != null) c.declineSheet();
    }
    if (target != null) expect(seen, isTrue);
    // 保存して読み直しても同じ
    final back = Career.fromJson(c.toJson());
    expect(back.faMoves.length, c.faMoves.length);
    expect(back.offStartIds, c.offStartIds);
    expect(back.offStartRank, c.offStartRank);
  });

  test('オフのまとめ: 入った選手は今の登録に、出た選手は登録の外にいる', () {
    final c = _toContracts(15, 9);
    c.finishContracts();
    expect(c.phase, Phase.preseason);
    final s = offSummary(c);
    final ids = {for (final p in c.me.roster) p.id};
    expect(s.arrived.every((x) => ids.contains(x.p.id)), isTrue);
    expect(s.left.every((x) => !ids.contains(x.p.id)), isTrue);
    // ドラフトの新人は「ドラフト」で入る
    expect(s.arrived.where((x) => x.how == 'ドラフト').every((x) => c.draftedIds.contains(x.p.id)), isTrue);
    expect(s.rankBefore, inInclusiveRange(0, c.teams.length - 1));
    expect(s.rankAfter, inInclusiveRange(0, c.teams.length - 1));
    expect(s.bigMoves.length, lessThanOrEqualTo(6));
    for (var i = 1; i < s.bigMoves.length; i++) {
      expect(s.bigMoves[i - 1].ovr, greaterThanOrEqualTo(s.bigMoves[i].ovr));
    }
  });
}
