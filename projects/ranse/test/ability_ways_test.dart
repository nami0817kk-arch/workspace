import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/ability_ways.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 政・魅・運で身を立てる道（`ability_ways.dart`、2026-11-25）。
void main() {
  final digits = RegExp(r'[0-9０-９%％]');
  const offers = ['代官の口', '勘定頭の推挙', '士分の誘い', '主君のお側', '奥方さまのお側', '巡り合わせ', '一か八か', '調略'];
  const titles = {...offers, '年貢の割り付け', '蔵の疑い', '側近の行く末'};

  int pickFor(String mode, Game g, Prompt p, Rng pick) {
    var i = pickAmbitious(g, p, pick);
    int f(String lab) => p.choices.indexWhere((c) => c.label == lab);
    if (p.title == 'この年の心がけ' && !g.isChild) {
      var j = -1;
      if (g.l.rank == 0) {
        j = f(g.l.female ? '奉公先を探す' : '仕官の口を探す');
      } else if (mode == 'sei') {
        j = f('所領の仕置きをする');
      } else if (mode == 'mi') {
        final need = g.l.rank < 7 ? kPromo[g.l.rank + 1]!.troops : 0;
        if (g.l.troops < need) j = f('人を集める');
        if (j < 0) j = f('敵方の将を調略する');
      } else {
        j = f('運を天に任せる');
      }
      if (j < 0) j = f(g.l.female ? '奥向きに尽くす' : '主君に尽くす');
      if (j >= 0) i = j;
    }
    if (offers.contains(p.title)) i = 0;
    return i;
  }

  test('勘定頭は兵の代わりに政の目安で上がれ、位の呼び名が変わる', () {
    final r = Rng(3);
    final g = Game(rng: r)..start(rollBirth(r, asFemale: false));
    g.l.sei = 70;
    expect(msPromoOk(g, 5), isFalse);
    g.setFlag('ms_kanjo');
    expect(msPromoOk(g, 5), isTrue);
    expect(msPromoOk(g, 7), isFalse);
    expect(abilityRankName(g, 3), '代官');
    expect(abilityRankName(g, 5), g.rk[5]);
    expect(abilityBattleGain(g), lessThan(1));
  });

  for (final mode in ['sei', 'mi', 'un']) {
    test('$mode の道: 男が城主に届き、能力の高い人ほど届きやすく、出た岐路は条件どおり', () {
      var men = 0, menC = 0, hiA = 0, hiC = 0, loA = 0, loC = 0, adults = 0, newDead = 0;
      final seen = <String>{};
      for (var s = 0; s < 700; s++) {
        final r = Rng(830000 + s);
        final g = Game(rng: r)..start(rollBirth(r));
        final pick = Rng(840000 + s);
        int? st;
        var k = 0;
        while (!g.finished && k++ < 6000) {
          final p = g.prompt!;
          if (st == null && g.age >= 15) {
            st = switch (mode) { 'sei' => g.l.sei, 'mi' => g.l.mi, _ => g.l.un };
          }
          if (titles.contains(p.title)) {
            seen.add(p.title);
            for (final c in p.choices) {
              expect(c.hint, isNotNull, reason: c.label);
              expect(c.label.contains(digits), isFalse, reason: c.label);
              expect(c.hint!.contains(digits), isFalse, reason: c.hint);
            }
          }
          switch (p.title) {
            case '勘定頭の推挙':
              expect(g.l.sei, greaterThanOrEqualTo(55));
              expect(g.canFight, isTrue);
            case '代官の口' || '士分の誘い':
              expect(g.l.rank, 0);
              expect(g.l.sei, greaterThanOrEqualTo(65));
            case '主君のお側' || '奥方さまのお側':
              expect(g.l.mi, greaterThanOrEqualTo(60));
            case '調略':
              expect(g.l.mi, greaterThanOrEqualTo(55));
            case '巡り合わせ':
              expect(g.l.un, greaterThanOrEqualTo(75));
          }
          g.choose(pickFor(mode, g, p, pick));
        }
        if (g.age < 15) continue;
        adults++;
        final d = g.l.dead ?? '';
        if (d.contains('調略に赴き') || d.contains('抜け駆けして') || d.contains('蔵の米を')) newDead++;
        if (g.l.female) continue;
        final c = g.l.maxRank >= 5;
        men++;
        if (c) menC++;
        if ((st ?? 0) >= 60) {
          hiA++;
          if (c) hiC++;
        } else if ((st ?? 0) < 45) {
          loA++;
          if (c) loC++;
        }
      }
      // ignore: avoid_print
      print('【$mode の道】男$men 城主以上${(menC / men * 100).toStringAsFixed(1)}% '
          '高い ${hiA == 0 ? '-' : (hiC / hiA * 100).toStringAsFixed(1)}% 低い ${(loC / loA * 100).toStringAsFixed(1)}% '
          '新しい死$newDead/$adults 出た$seen');
      expect(menC / men, greaterThan(mode == 'un' ? .03 : .12));
      if (hiA >= 15) expect(hiC / hiA, greaterThan(loC / loA));
      expect(newDead / adults, lessThan(.12));
    });
  }
}
