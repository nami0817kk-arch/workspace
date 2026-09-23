/// **強くなる金と、残す金は同じ財布。**
///
/// 実測（16キャリアずつ）で、スタッフを雇わない選手は引退時に
/// 中央6.7億円・最小でも3.5億円を余らせていた。金は使い道の無い点数で、
/// 雇う側はピーク +0.9・出場 +13 をただで手にしていた。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/models/support.dart';

void main() {
  group('スタッフの値段', () {
    test('3人を最高で揃えると、稼ぎの余りを超える', () {
      const all = StaffTeam(coach: 3, trainer: 3, nutritionist: 3);
      // 引退までの余りは、雇わない遊び方で1シーズンあたり3,600万円ほど
      // （中央6.7億円 ÷ 18.5シーズン）。全員最高は、そこを大きく超える。
      expect(all.costPerSeason, greaterThan(3600 * 2));
    });

    test('段が上がるほど跳ね上がる', () {
      for (var level = 1; level < StaffTeam.costPerLevel.length; level++) {
        expect(
          StaffTeam.costPerLevel[level],
          greaterThan(StaffTeam.costPerLevel[level - 1] * 2),
        );
      }
    });

    test('1人だけなら、無理なく続けられる', () {
      const one = StaffTeam(coach: 3);
      expect(one.costPerSeason, lessThan(3600));
    });
  });

  group('残す金', () {
    test('実業家の線は、全員最高の人件費より重い', () {
      // ここが軽いと「雇いながら残す」ができてしまい、取り合いにならない。
      const all = StaffTeam(coach: 3, trainer: 3, nutritionist: 3);
      expect(
        Formulas.entrepreneurSavings,
        greaterThan(all.costPerSeason * 2),
      );
    });
  });
}
