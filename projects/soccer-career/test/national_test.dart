/// **代表の線は、その国の格で動く。**
///
/// 以前は国に関係なく 77 で一定だった。複数の国籍を持つ選手にとって
/// **格の高い国を選ぶのが常に正解**で、選ぶ意味が無かった——
/// ワールドカップの勝ち上がりだけが国で変わり、選ばれやすさは同じだったから。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/world.dart';

void main() {
  test('小さい国ほど呼ばれやすい', () {
    expect(Formulas.callUpLineFor(1), lessThan(Formulas.callUpLineFor(5)));
    // 格3が基準。ここだけは前と同じ数字。
    expect(Formulas.callUpLineFor(3), Formulas.callUpOverall);
  });

  test('格が1つ違えば、線も決まった幅だけ動く', () {
    for (var p = 2; p <= 5; p++) {
      expect(
        Formulas.callUpLineFor(p) - Formulas.callUpLineFor(p - 1),
        Formulas.callUpPrestigeStep,
      );
    }
  });

  test('世界のどの国でも、線は届く範囲に収まる', () {
    // 上が高すぎると、その国の代表が構造的に消える
    // （`squadRegistrationGap` の −18 と同じ間違いをしない）。
    for (final country in World.countries) {
      final line = Formulas.callUpLineFor(country.prestige);
      expect(line, greaterThanOrEqualTo(65), reason: country.name);
      expect(line, lessThanOrEqualTo(85), reason: country.name);
    }
  });
}
