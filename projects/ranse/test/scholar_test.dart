import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/scholar.dart';

import 'bot.dart';

/// 知で身を立てる道（`scholar.dart`、2026-11-25）。
void main() {
  final digits = RegExp(r'[0-9０-９%％]');

  /// 学問で知を上げ、仕えたら献策し、知の道の誘いは受ける遊び方。
  int scholarPick(Game g, Prompt p, Rng pick) {
    var i = pickAmbitious(g, p, pick);
    if (p.title == 'この年の心がけ' && !g.isChild) {
      final k = p.choices.indexWhere(
        (c) => c.label == '献策する' || c.label == '奥の務めに知恵を絞る',
      );
      final s = p.choices.indexWhere((c) => c.label == '学問に励む');
      if (g.l.rank >= 1 && k >= 0) {
        i = k;
      } else if (s >= 0) {
        i = s;
      }
    }
    if (const ['祐筆の口', '奥の祐筆', '奉行の推挙', '采配の預かり'].contains(p.title)) i = 0;
    return i;
  }

  test('役方の人は、兵の代わりに知の目安で上がれる。軍師は武と知の高いほうで戦う', () {
    final r = Rng(1);
    final g = Game(rng: r)..start(rollBirth(r));
    g.l
      ..chi = 70
      ..bu = 30;
    expect(scholarPromoOk(g, 5), isFalse); // 役方でなければ知では上がれない
    g.setFlag('sc_bun');
    expect(scholarPromoOk(g, 5), isTrue);
    expect(scholarPromoOk(g, 7), isFalse); // 宿老には知が足りない
    expect(scholarBattleGain(g), lessThan(1));
    expect(scholarBattleBu(g), 30);
    g.setFlag('sc_gunshi');
    expect(scholarBattleBu(g), 70);
    expect(scholarBattleGain(g), greaterThan(1));
  });

  test('知の道を選べば、城主に届く。知の高い人ほど届きやすい。出た岐路は条件どおり', () {
    var adults = 0, castle = 0, hiA = 0, hiC = 0, loA = 0, loC = 0, senshi = 0;
    final seen = <String>{};
    for (var s = 0; s < 900; s++) {
      final r = Rng(810000 + s);
      final g = Game(rng: r)..start(rollBirth(r));
      final pick = Rng(820000 + s);
      int? chi15;
      var k = 0;
      while (!g.finished && k++ < 6000) {
        final p = g.prompt!;
        if (chi15 == null && g.age >= 15) chi15 = g.l.chi;
        switch (p.title) {
          case '祐筆の口' || '奥の祐筆':
            seen.add('yuhitsu');
            expect(g.l.rank, 0);
            expect(g.l.chi, greaterThanOrEqualTo(60));
          case '奉行の推挙':
            seen.add('bugyo');
            expect(scBun(g), isFalse);
            expect(g.l.chi, greaterThanOrEqualTo(58));
          case '采配の預かり':
            seen.add('gunshi');
            expect(g.canFight, isTrue);
            expect(g.l.chi, greaterThanOrEqualTo(75));
          case '役方への妬み':
            seen.add('slander');
            expect(scBun(g), isTrue);
            expect(g.l.rank, greaterThanOrEqualTo(6));
          case '評定' || '奥の相談':
            seen.add('council');
        }
        if (const {'祐筆の口', '奥の祐筆', '奉行の推挙', '采配の預かり', '役方への妬み', '評定', '奥の相談'}
            .contains(p.title)) {
          for (final c in p.choices) {
            if (c.hint != null) {
              expect(c.label.contains(digits), isFalse, reason: c.label);
              expect(c.hint!.contains(digits), isFalse, reason: c.hint);
            }
          }
        }
        g.choose(scholarPick(g, p, pick));
      }
      if (g.age < 15) continue;
      adults++;
      final c = g.l.maxRank >= 5;
      if (c) castle++;
      if (g.l.deathKind == 'senshi') senshi++;
      if ((chi15 ?? 0) >= 60) {
        hiA++;
        if (c) hiC++;
      } else if ((chi15 ?? 0) < 40) {
        loA++;
        if (c) loC++;
      }
      if (scBun(g) && !g.l.female && g.l.rank >= 1 && g.l.rank <= 4) {
        expect(g.rankName(), kBunRanksM[g.l.rank]);
      }
    }
    // ignore: avoid_print
    print('【知の道】成人$adults 城主以上${(castle / adults * 100).toStringAsFixed(1)}% '
        '知60以上 ${(hiC / hiA * 100).toStringAsFixed(1)}% 知40未満 ${(loC / loA * 100).toStringAsFixed(1)}% '
        '戦死${(senshi / adults * 100).toStringAsFixed(1)}% 出た$seen');
    expect(castle / adults, greaterThan(.3));
    expect(hiC / hiA, greaterThan(loC / loA));
    expect(senshi / adults, lessThan(.2));
    expect(seen, containsAll(['yuhitsu', 'bugyo', 'gunshi', 'slander', 'council']));
  });
}
