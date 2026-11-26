import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';
import 'package:ranse/engine/spending.dart';

/// 銭と功の使い道の「見せる一覧」（2026-11-26、ユーザー「仕官していないと見られない」）。
/// 足りないもの・仕えていないと使えないものも、薄くして訳つきで並べる。買える条件そのものは変えない。

/// 三十歳の [cls] の家に生まれた人（身分なし・銭も功もなし）。
Game _person(String cls, {int seed = 0}) {
  for (var s = seed; ; s++) {
    final rng = Rng(s + 900);
    final x = Game(rng: rng);
    final b = rollBirth(rng);
    if (b.female || b.startYear > 1550 || b.cls.id != cls) continue;
    x.start(b);
    if (x.finished) continue;
    x.prompt = null;
    x.l.t = 30 * 2;
    x.l
      ..rank = 0
      ..maxRank = 0
      ..lord = null
      ..married = false
      ..gold = 0
      ..merit = 0
      ..troops = 0;
    for (final f in ['priesthood', 'retired', 'way_merchant', 'way_outlaw']) {
      x.l.flags.remove(f);
    }
    x.l.flags.removeWhere((f) => f.startsWith('sp_'));
    return x;
  }
}

void main() {
  test('仕官していない百姓でも、銭と功の使い道が訳つきで並ぶ（使えるものは無い）', () {
    final g = _person('farmer');
    expect(spendingMenu(g), isEmpty, reason: '買える条件は前と同じ（銭も功も無い）');
    final v = spendingCatalog(g);
    final gold = v.where((x) => !x.item.merit).toList();
    final merit = v.where((x) => x.item.merit).toList();
    expect(gold, isNotEmpty, reason: '銭が足りなくても、身分に合う使い道は見える');
    expect(gold.every((x) => !x.usable && x.lack!.startsWith('あと')), isTrue);
    expect(merit, isNotEmpty, reason: '仕官していなくても、功の使い道は見える');
    expect(
      merit.every((x) => !x.usable && x.lack!.startsWith('主家に仕えると')),
      isTrue,
    );
  });

  test('銭が足りれば使える行になり、足りない分だけが「あとn貫」になる', () {
    final g = _person('farmer');
    final all = spendingCatalog(g).where((x) => !x.item.merit).toList();
    final cheapest = all
        .map((x) => x.item.cost)
        .reduce((a, b) => a < b ? a : b);
    g.l.gold = cheapest;
    for (final x in spendingCatalog(g).where((x) => !x.item.merit)) {
      if (x.item.cost <= cheapest) {
        expect(x.usable, isTrue);
      } else {
        expect(x.lack, 'あと${x.item.cost - cheapest}貫');
      }
    }
  });

  test('使える行は、買える一覧（spendingMenu）とそろう', () {
    for (var s = 0; s < 40; s++) {
      final rng = Rng(5000 + s);
      final g = Game(rng: rng)..start(rollBirth(rng));
      final pick = Rng(6000 + s);
      var n = 0;
      while (!g.finished && n++ < 600) {
        if (g.atYearStart && g.age >= 20) {
          g.l.gold += 300;
          final usable = spendingCatalog(g)
              .where((x) => x.usable)
              .map((x) => x.item.id)
              .toSet();
          final menu = spendingMenu(g).map((x) => x.id).toSet();
          expect(
            usable,
            menu,
            reason: '使える行と、買える一覧が食い違う（${g.l.name} ${g.age}歳）',
          );
        }
        g.choose(pick.range(0, g.prompt!.choices.length - 1));
      }
    }
  });

  test('子どもには何も並ばない', () {
    final rng = Rng(77);
    final c = Game(rng: rng)..start(rollBirth(rng));
    if (c.isChild && !c.finished) expect(spendingCatalog(c), isEmpty);
  });
}
