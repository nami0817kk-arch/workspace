import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

Career _started(int seed) {
  final c = careerAt(seed, 15);
  while (c.phase != Phase.season) {
    botStep(c);
  }
  return c;
}

void main() {
  test('契約最終年の主力の出来事が1区切り目のあとに届き、返事で気持ちと延長の額が変わる', () {
    for (final seed in [3, 5, 7, 9, 11]) {
      final c = _started(seed);
      final p = c.me.roster.where((p) => p.years == 1).firstOrNull;
      if (p == null) continue;
      p.ovr = 90; // 主力にする
      c.playBlock();
      final m = c.inbox.where((m) => m.kind == MsgKind.storyContract).firstOrNull;
      expect(m, isNotNull, reason: 'seed $seed');
      final target = c.me.roster.firstWhere((x) => x.id == m!.player);
      final before = c.extensionAsk(target).salary;
      c.answer(m!.id, 1);
      expect(c.hungry, contains(target.id));
      expect(c.extensionAsk(target).salary, lessThan(before));
      final back = Career.fromJson(c.toJson());
      expect(back.hungry, c.hungry);
      expect(back.storyIds, c.storyIds);
      return;
    }
    fail('契約最終年の選手がいる経歴が見つからない');
  });

  test('もう1年と頼んだベテランは、そのオフに引退しない', () {
    final c = _started(3);
    final vet = c.me.roster.first;
    vet.age = 40; // 必ず引退を考える年
    c.stayIds = [vet.id];
    var guard = 0;
    while (c.phase != Phase.contracts && guard++ < 2000) {
      if (c.phase == Phase.seasonEnd) c.fired = false;
      botStep(c);
    }
    expect(c.me.roster.any((p) => p.id == vet.id) || c.freeAgents.any((p) => p.id == vet.id) || c.teams.any((t) => t.roster.any((p) => p.id == vet.id)), isTrue,
        reason: '引退していない(契約が切れて自由契約にいることはある)');
  });

  test('返事をしなければ何も変わらない(自動で遊ぶ確かめは返事をしない)', () {
    final c = _started(5);
    c.playBlock();
    final m = c.inbox.where((m) => m.kind == MsgKind.storyContract).firstOrNull;
    if (m == null) return;
    expect(m.needsAnswer, isTrue);
    expect(c.hungry, isEmpty);
  });
}
