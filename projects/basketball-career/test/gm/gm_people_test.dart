import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/gm_people.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('チームの GM は種とチームと代から決まり、同じなら同じ。5つの型にばらける', () {
    final styles = <GmStyle>{};
    for (var t = 0; t < 30; t++) {
      final a = gmOf(7, t), b = gmOf(7, t);
      expect(a.name, b.name);
      expect(a.style, b.style);
      expect(a.name, isNotEmpty);
      styles.add(a.style);
    }
    expect(styles.length, GmStyle.values.length);
    expect(gmOf(7, 3, era: 1).name, isNot(gmOf(7, 3, era: 0).name));
  });

  test('分析型の GM は釣り合いに厳しく、勝負師は甘い(トレードの受けにくさ)', () {
    expect(GmStyle.analytic.hardness, greaterThan(1));
    expect(GmStyle.gambler.hardness, lessThan(1));
    final c = Career.start(seed: 7, team: 3);
    expect(c.gmPerson(5).name, gmOf(7, 5).name);
  });
}
