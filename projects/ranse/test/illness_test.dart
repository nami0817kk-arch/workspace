import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/illness.dart';
import 'package:ranse/engine/rng.dart';

/// 病（2026-11-24、ユーザー「健康なのに、争い以外で死ぬのはなぜ？」→「両方入れる」）。
void main() {
  test('健康が高いほど、病にかかりにくい', () {
    expect(healthMortFactor(70), 1.0);
    expect(healthMortFactor(100), lessThan(.5));
    expect(healthMortFactor(30), greaterThan(1.5));
    for (var hp = 0; hp < 130; hp++) {
      expect(
        healthMortFactor(hp + 1),
        lessThanOrEqualTo(healthMortFactor(hp)),
        reason: '$hp',
      );
    }
  });

  /// 病に伏したら「病を養う」を選ぶか（[rest]）、選ばずに無作為に選ぶ。
  ({int deaths, int sick, int adult, int warned, int healthyBefore}) play(
    int seeds,
    bool rest,
  ) {
    var deaths = 0, sick = 0, adult = 0, warned = 0, healthyBefore = 0;
    for (var s = 0; s < seeds; s++) {
      final r = Rng(s);
      final g = Game(rng: r)..start(rollBirth(r));
      final pick = Rng(60000 + s);
      var sawYojo = false;
      var lastHp = g.l.hp;
      var n = 0;
      while (!g.finished && n++ < 4000) {
        final p = g.prompt!;
        if (p.title == 'この年の心がけ') lastHp = g.l.hp;
        final y = p.choices.indexWhere((c) => c.label == '病を養う');
        if (y >= 0) {
          sawYojo = true;
          // 病に伏しているときだけ出て、年の初めの文にも病の一言がある。
          expect(isSick(g), isTrue);
          expect(p.text, contains('病の床にある'));
        }
        var i = pick.range(0, p.choices.length - 1);
        if (y >= 0) i = rest ? y : (i == y ? (y + 1) % p.choices.length : i);
        g.choose(i);
      }
      sick += g.l.log.where((e) => e.txt.startsWith('重い病に伏した')).length;
      if (g.age < 15) continue;
      adult++;
      if (g.l.dead == '病に倒れた') {
        deaths++;
        // 病で亡くなる人は、必ずその前に病に伏し、「病を養う」を選ぶ機会があった。
        expect(g.l.log.any((e) => e.txt.startsWith('重い病に伏した')), isTrue);
        if (sawYojo) warned++;
        if (lastHp >= 70) healthyBefore++;
      }
    }
    return (
      deaths: deaths,
      sick: sick,
      adult: adult,
      warned: warned,
      healthyBefore: healthyBefore,
    );
  }

  test('病で亡くなる前には必ず病に伏し、「病を養う」を選べる。健康なまま突然は亡くならない', () {
    final a = play(1500, true);
    // ignore: avoid_print
    print('【病】成人${a.adult}・病に伏した${a.sick}・病死${a.deaths}（養うを選べた${a.warned}・前の年の初めに健康70以上${a.healthyBefore}）');
    expect(a.sick, greaterThan(200));
    expect(a.deaths, greaterThan(50));
    expect(a.warned, a.deaths);
    expect(a.healthyBefore, 0);
  });

  test('病を養えば、押して務めるより助かる', () {
    final rest = play(1500, true);
    final work = play(1500, false);
    expect(rest.deaths / rest.sick, lessThan(work.deaths / work.sick));
  });
}
