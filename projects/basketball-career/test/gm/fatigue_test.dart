import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

Career _started(int seed) {
  final c = careerAt(seed, 15);
  while (c.phase != Phase.season) {
    botStep(c);
  }
  return c;
}

void main() {
  test('疲れは自分の選手だけにたまり、長く出る選手ほど多い(ふつうの時間ではシュートは落ちない)', () {
    final c = _started(3);
    c.playBlock();
    c.playBlock();
    final order = c.me.order.where((p) => p.injured == 0).toList();
    final starters = order.take(5).map((p) => p.wear).toList();
    final bench = order.skip(9).map((p) => p.wear).toList();
    // ignore: avoid_print
    print('starters $starters bench $bench');
    for (final w in starters) {
      expect(w, inInclusiveRange(30, wearSlumpLine), reason: 'ふつうの出場時間では、シュートが落ちる線までは届かない');
    }
    expect(starters.reduce((a, b) => a + b) / 5, greaterThan(bench.fold(0, (a, b) => a + b) / (bench.isEmpty ? 1 : bench.length)));
    for (final t in c.teams) {
      if (t.index == c.mine) continue;
      expect(t.roster.every((p) => p.wear == 0), isTrue);
    }
  });

  test('疲れたら休ませる設定の選手は、ときどき休み、疲れが低く保たれる', () {
    final a = _started(5), b = _started(5);
    final star = a.me.order.first.id;
    b.toggleRest(star);
    expect(b.restIds, [star]);
    for (var k = 0; k < 3; k++) {
      a.playBlock();
      b.playBlock();
    }
    final pa = a.me.roster.firstWhere((p) => p.id == star), pb = b.me.roster.where((p) => p.id == star).firstOrNull;
    if (pb == null) return; // けがで外れた・動いた場合は見ない
    // ignore: avoid_print
    print('no rest wear ${pa.wear} gp ${pa.stats.gp} / rest wear ${pb.wear} rested ${pb.restGames} gp ${pb.stats.gp}');
    expect(pb.restGames, greaterThan(0));
    expect(pb.restGames, lessThan(15));
    expect(pb.injured == 0 || pb.injuryText.isNotEmpty, isTrue, reason: '休みは試合のあとに戻っている');
    expect(pb.wear, lessThanOrEqualTo(wearRestLine + 6));
    expect(pa.restGames, 0);
  });

  test('疲れと休ませる設定は保存され、次のシーズンの初めに疲れは0に戻る', () {
    final c = _started(7);
    c.toggleRest(c.me.order.first.id);
    c.playBlock();
    final wear = {for (final p in c.me.roster) p.id: p.wear};
    final back = Career.fromJson(c.toJson());
    expect(back.restIds, c.restIds);
    for (final p in back.me.roster) {
      expect(p.wear, wear[p.id]);
    }
    expect(wear.values.any((w) => w > 0), isTrue);
    var guard = 0;
    while (c.phase != Phase.season || c.season == back.season) {
      botStep(c);
      if (guard++ > 2000) fail('次のシーズンに着かない');
    }
    // 開幕した直後(まだ試合をしていない区切りの初め)なら0
    if (c.roundAt == 0) {
      expect(c.me.roster.every((p) => p.wear == 0), isTrue);
    }
  });

  test('休みでも、出られる選手が8人を切るなら休ませない', () {
    final c = _started(9);
    for (final p in c.me.roster) {
      c.toggleRest(p.id);
      p.wear = 90;
    }
    c.playWeek();
    // 1試合ごとに戻るので、終わったあとに休みの印(injured)が残っていない
    final healthy = c.me.roster.where((p) => p.injured == 0).length;
    expect(healthy, greaterThanOrEqualTo(c.me.roster.length - c.me.roster.where((p) => p.injuryText.isNotEmpty).length));
    // 1週間は3試合。1試合に休めるのは、出られる選手が8人を切らない分まで
    final rested = c.me.roster.fold(0, (n, p) => n + p.restGames);
    expect(rested, greaterThan(0));
    expect(rested, lessThanOrEqualTo((c.me.roster.length - 8) * Career.daysPerWeek));
  });
}
