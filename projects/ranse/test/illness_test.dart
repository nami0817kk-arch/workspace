import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/illness.dart';
import 'package:ranse/engine/rng.dart';

/// 病（2026-11-24、ユーザー「健康なのに、争い以外で死ぬのはなぜ？」→「両方入れる」）。
void main() {
  test('健康が高いほど、病にかかりにくい', () {
    // 1倍になる芯は、2026-11-25 に七十から下げた（ふだんの暮らしで健康が上下するようにしたため。[kHealthPivot]）。
    expect(healthMortFactor(kHealthPivot), 1.0);
    expect(healthMortFactor(100), lessThan(.5));
    expect(healthMortFactor(kHealthPivot - 40), greaterThan(1.5));
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
    print(
      '【病】成人${a.adult}・病に伏した${a.sick}・病死${a.deaths}（養うを選べた${a.warned}・前の年の初めに健康70以上${a.healthyBefore}）',
    );
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

  test('ふだんの暮らしで健康が上下する（2026-11-25）: 年の初めの健康が七十を下回る大人の年が、ほどほどにある', () {
    // 戻り方は歳で細り、上限は四十から下がる。
    expect(healthRegen(20), greaterThan(healthRegen(50)));
    expect(healthCap(100, 30), 100);
    expect(healthCap(100, 60), lessThan(healthCap(100, 45)));
    expect(healthCap(100, 200), 50);
    var starts = 0, low = 0, ail = 0, adults = 0;
    for (var s = 0; s < 800; s++) {
      final r = Rng(s + 33000);
      final g = Game(rng: r)..start(rollBirth(r));
      final pick = Rng(s + 34000);
      var n = 0;
      while (!g.finished && n++ < 4000) {
        final p = g.prompt!;
        if (p.title == 'この年の心がけ' && !g.isChild) {
          starts++;
          if (g.l.hp < 70) low++;
        }
        final y = p.choices.indexWhere((c) => c.label == '病を養う');
        g.choose(y >= 0 ? y : pick.range(0, p.choices.length - 1));
      }
      if (g.age >= 15) adults++;
      ail += g.l.log.where((e) => _ailment.hasMatch(e.txt)).length;
    }
    // ignore: avoid_print
    print(
      '【健康】大人の年の初め$starts・七十未満$low（${(low / starts * 100).toStringAsFixed(1)}%）・季節の病$ail（成人$adults）',
    );
    expect(low / starts, inInclusiveRange(.15, .45));
    expect(ail, greaterThan(adults));
  });
}

final _ailment = RegExp('風邪をこじらせ|腹を下し|熱を出し、床に就いた|咳が長引き|暑気あたり');
