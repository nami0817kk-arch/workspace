import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/famous_ties.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/history_lines.dart';
import 'package:ranse/engine/rng.dart';

import 'people_house_helpers.dart';

/// 有名人との縁を続ける（2026-11-25）。出会った有名人と、節目・敵として・最期に再会する筋。没年と世界線を見る。

void _noDigits(Prompt p, String where) {
  for (final c in p.choices) {
    expect(c.hint, isNotNull, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.label), isFalse, reason: '$where: ${c.label}');
    expect(kDigits.hasMatch(c.hint!), isFalse, reason: '$where: ${c.hint}');
  }
}

/// 有名人それぞれと親しく会った、という歩んだ道の文。
const _closeLines = {
  'nobunaga': '尾張の若殿・吉法師と野で遊んだ',
  'hideyoshi': 'のちの豊臣秀吉、木下藤吉郎と親しくなった',
  'ieyasu': '人質の少年・竹千代（のちの徳川家康）と言葉を交わした',
  'kenshin': '越後の寺に預けられた少年と言葉を交わした',
  'shingen': '川中島の戦いで、信玄と謙信の一騎打ちを間近に見た',
  'masamune': '独眼竜・伊達政宗の軍に加わった',
};

String _keyOf(String id) => id.split('_')[1];

void main() {
  test('縁の深さは、縁のある人の名と歩んだ道の文から読む', () {
    final g = firstGrown(3);
    g.choose(0);
    for (final k in kFamousKeys) {
      expect(ftMet(g, k), 0, reason: k);
    }
    g.l.path.add('15歳　尾張の若殿を、遠くから見た');
    expect(ftMet(g, 'nobunaga'), 1);
    g.l.path.add('16歳　尾張の若殿・吉法師と野で遊んだ');
    expect(ftMet(g, 'nobunaga'), 2);
    g.meet('藤吉郎', '木下藤吉郎', 50);
    expect(ftMet(g, 'hideyoshi'), 2);
    g.l.path.add('20歳　川中島の戦いで、信玄と謙信の一騎打ちを間近に見た');
    expect(ftMet(g, 'shingen'), 1);
    expect(ftMet(g, 'kenshin'), 1);
  });

  test('没年は世界線で変わり、その世で描かない人は出さない', () {
    final g = firstGrown(4);
    g.choose(0);
    expect(ftDeathYear(g, 'nobunaga'), 1582);
    expect(ftDeathYear(g, 'hideyoshi'), 1598);
    expect(ftDeathYear(g, 'ieyasu'), 1616);
    expect(ftDeathYear(g, 'kenshin'), 1578);
    expect(ftDeathYear(g, 'shingen'), 1573);
    expect(ftDeathYear(g, 'masamune'), 1636);
    g.setFlag('history_honnoji');
    expect(worldLine(g), 'nobunaga');
    expect(ftDeathYear(g, 'nobunaga'), 1598);
    expect(ftDeathYear(g, 'hideyoshi'), isNull);
    g.l.flags.remove('history_honnoji');
    g.setFlag('history_okehazama');
    for (final k in ['nobunaga', 'kenshin', 'shingen', 'hideyoshi', 'ieyasu']) {
      expect(ftDeathYear(g, k), isNull, reason: k);
    }
    g.l.flags.remove('history_okehazama');
    g.setFlag('history_kawanakajima');
    expect(ftDeathYear(g, 'shingen'), isNull);
    // `personDied` の表と、名と没年が食い違わない（史実どおりの世）。
    g.l.flags.remove('history_kawanakajima');
    for (final k in ['nobunaga', 'hideyoshi', 'ieyasu', 'kenshin', 'masamune']) {
      final d = ftDeathYear(g, k)!;
      g.l.t = (d - g.l.startYear) * 2;
      expect(personDied(g, famousName(k)), isFalse, reason: '$k $d');
      g.l.t = (d + 1 - g.l.startYear) * 2;
      expect(personDied(g, famousName(k)), isTrue, reason: '$k ${d + 1}');
    }
  });

  test('出会った人とは、史実の年代に節目・敵・最期で再会する。没したあとには節目も敵も出ない', () {
    final seen = <String, int>{};
    var lives = 0;
    for (var s = 0; s < 900; s++) {
      final g = grownUp(s + 20000, female: false, from: 1535, to: 1575);
      if (g == null) continue;
      lives++;
      // 皆と出会ったことにする（歩んだ道の文）。半分は武家に、残りは身分なしで。
      for (final t in _closeLines.values) {
        g.l.path.add('15歳　$t');
      }
      if (s.isEven) serveAt(g, s % 4 == 0 ? 5 : 3);
      g.choose(0);
      playWatch(
        g,
        Rng(s),
        prefix: 'ft_',
        ambitious: s % 3 == 0,
        atScene: (id, p) {
          seen[id] = (seen[id] ?? 0) + 1;
          _noDigits(p, id);
          final k = _keyOf(id);
          final d = ftDeathYear(g, k);
          expect(d, isNotNull, reason: '$id が、描かない世（${worldLine(g)}）に出た');
          if (id.endsWith('_saigo')) {
            expect(g.year, inInclusiveRange(d!, d + 1), reason: '$id ${g.year}');
            expect(ftMet(g, k), greaterThanOrEqualTo(1), reason: id);
          } else {
            expect(g.year, lessThan(d!), reason: '$id が没年（$d）のあとに出た（${g.year}）');
            expect(personDied(g, famousName(k)), isFalse, reason: id);
          }
          if (id.endsWith('_teki')) {
            expect(g.l.lord, isNotNull, reason: id);
            expect(g.l.rank, inInclusiveRange(1, 7), reason: id);
            expect(ftServing(g, k), isFalse, reason: id);
          }
        },
      );
    }
    // ignore: avoid_print
    print('出た岐路: $seen');
    expect(lives, greaterThan(200));
    // 信玄の節目は武田に仕える侍大将からなので稀。家康の節目（一六〇三年〜）と最期（一六一六年）・政宗の最期（一六三六年）まで
    // 生きる人も稀なので、下の別のテストで年を見る（乱数の流れしだいで、この流し方では出ないことがある）。
    const rare = {'ft_shingen_fushime', 'ft_ieyasu_fushime', 'ft_ieyasu_saigo', 'ft_masamune_saigo'};
    for (final id in kFamousSceneIds) {
      if (rare.contains(id)) continue;
      expect(seen[id] ?? 0, greaterThan(0), reason: '$id が一度も出ない（$seen）');
    }
  });

  test('稀な筋（家康の節目・政宗の最期・信玄の節目）も、決まった年にだけ出る', () {
    final g = firstGrown(12, female: false, from: 1545, to: 1560);
    g.choose(0);
    for (final t in _closeLines.values) {
      g.l.path.add('15歳　$t');
    }
    bool at(String id, int y) {
      g.l.t = (y - g.l.startYear) * 2;
      return g.adultScenes.firstWhere((x) => x.id == id).cond(g);
    }

    // 家康の節目: 縁があれば一六〇三〜〇五年に（仕えていなくても祝いに出向ける）。
    expect(at('ft_ieyasu_fushime', 1602), isFalse);
    expect(at('ft_ieyasu_fushime', 1603), isTrue);
    expect(at('ft_ieyasu_fushime', 1605), isTrue);
    expect(at('ft_ieyasu_fushime', 1606), isFalse);
    // 政宗の最期: 一六三六年と翌年。
    expect(at('ft_masamune_saigo', 1635), isFalse);
    expect(at('ft_masamune_saigo', 1636), isTrue);
    expect(at('ft_masamune_saigo', 1637), isTrue);
    // 信玄の節目: 武田に仕える侍大将からだけ、一五七一〜七二年に。
    expect(at('ft_shingen_fushime', 1571), isFalse);
    serveAt(g, 5);
    g.l.lord = '武田';
    g.fa['武田']!.alive = true;
    expect(at('ft_shingen_fushime', 1571), isTrue);
    expect(at('ft_shingen_fushime', 1573), isFalse);
  });

  test('家康の最期は一六一六年と翌年に、史実どおりの世でだけ出る', () {
    final g = firstGrown(6, from: 1550, to: 1565);
    g.choose(0);
    g.l.path.add('15歳　人質の少年・竹千代（のちの徳川家康）と言葉を交わした');
    final s = g.adultScenes.firstWhere((x) => x.id == 'ft_ieyasu_saigo');
    for (final (y, ok) in [(1615, false), (1616, true), (1617, true), (1618, false)]) {
      g.l.t = (y - g.l.startYear) * 2;
      expect(s.cond(g), ok, reason: '$y');
    }
    g.l.t = (1616 - g.l.startYear) * 2;
    g.setFlag('history_sekigahara');
    expect(s.cond(g), isFalse);
  });

  test('同じ出来事を描く史実の岐路を見た人には、最期の岐路を出さない', () {
    final g = firstGrown(5, from: 1540, to: 1560);
    g.choose(0);
    g.l.path.add('15歳　のちの豊臣秀吉、木下藤吉郎と親しくなった');
    g.l.t = (1598 - g.l.startYear) * 2;
    final s = g.adultScenes.firstWhere((x) => x.id == 'ft_hideyoshi_saigo');
    expect(s.cond(g), isTrue);
    g.setFlag('scene:h_hideyoshi_death');
    expect(s.cond(g), isFalse);
  });

  test('有名人の岐路の id はすべて一度ずつ登録されている', () {
    final ids = Game(rng: Rng(1)).adultScenes.map((s) => s.id).toList();
    expect(kFamousSceneIds.length, 17);
    for (final id in kFamousSceneIds) {
      expect(ids.where((x) => x == id).length, 1, reason: id);
    }
  });
}
