import 'dart:convert';

import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/promise.dart';
import 'package:flutter_test/flutter_test.dart';

/// オフの契約の手前(ドラフト)まで進め、契約が続く選手2人の気持ちを下げてから契約の時期に入る。
(Career, List<int>) _withUnhappy(int seed) {
  final c = careerAt(seed, 12);
  var guard = 0;
  while (c.phase != Phase.draft) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('ドラフトに着かない');
  }
  final keep = [for (final p in c.me.roster) if (p.years > 0) p].take(2).toList();
  for (final p in c.me.roster) {
    p.morale = 70;
  }
  keep[0].morale = 15;
  keep[1].morale = 35;
  while (c.phase == Phase.draft) {
    botStep(c);
  }
  expect(c.phase, Phase.contracts);
  return (c, [for (final p in keep) p.id]);
}

List<Message> _talks(Career c) => [for (final m in c.inbox) if (m.kind == MsgKind.offTalk) m];

void main() {
  test('面談: 気持ちの低い選手が2人まで話をしに来て、気持ちの低い順に並ぶ。気持ちが高い選手は来ない', () {
    final (c, ids) = _withUnhappy(1);
    final talks = _talks(c);
    expect(talks.length, 2);
    expect({for (final m in talks) m.player}, ids.toSet());
    expect(talks.every((m) => m.needsAnswer && m.choices.length == 3), isTrue);
    // 保存して読み戻しても、返事待ちのまま残る
    final copy = Career.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(_talks(copy).where((m) => m.needsAnswer).length, 2);
  });

  test('面談: 先発の約束は来季の約束になり、気持ちが上がる。トレードの約束も来季の締め切りまで', () {
    final (c, ids) = _withUnhappy(2);
    final a = c.me.roster.firstWhere((p) => p.id == ids[0]);
    final b = c.me.roster.firstWhere((p) => p.id == ids[1]);
    final (ma, mb) = (a.morale, b.morale);
    c.answer(_talks(c).firstWhere((m) => m.player == a.id).id, 0);
    c.answer(_talks(c).firstWhere((m) => m.player == b.id).id, 1);
    expect(a.morale, greaterThan(ma));
    expect(b.morale, greaterThan(mb));
    final starter = c.openPromises.firstWhere((x) => x.kind == PromiseKind.starter && x.player == a.id);
    expect(starter.due, (c.season + 1) * blocksPerSeason + 2);
    final trade = c.openPromises.firstWhere((x) => x.kind == PromiseKind.trade && x.player == b.id);
    expect(trade.due, (c.season + 1) * blocksPerSeason + tradeDeadlineBlock);
  });

  test('面談: 説明は言葉の重みで効き目が変わる。答えないままオフを終えると、説明したことになる(効き目は無し)', () {
    final (c, ids) = _withUnhappy(3);
    final p = c.me.roster.firstWhere((p) => p.id == ids[0]);
    c.word = 20;
    final before = p.morale;
    c.answer(_talks(c).firstWhere((m) => m.player == p.id).id, 2);
    expect(p.morale, lessThan(before));

    final (d, ids2) = _withUnhappy(3);
    final q = d.me.roster.firstWhere((p) => p.id == ids2[1]);
    d.word = 70;
    final qb = q.morale;
    d.answer(_talks(d).firstWhere((m) => m.player == q.id).id, 2);
    expect(q.morale, greaterThan(qb));

    final (e, _) = _withUnhappy(4);
    e.finishContracts();
    expect(_talks(e).every((m) => !m.needsAnswer), isTrue);
    expect(e.openPromises.where((x) => x.kind != PromiseKind.playoffs), isEmpty);
  });
}
