import 'package:flutter_test/flutter_test.dart';
import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/rng.dart';

/// 生まれる性別を選べる（2026-11-23 ユーザー「男か女は選べるように」）。
void main() {
  test('性別を選ぶとその性別で生まれ、ほかの籤は運に任せたときと同じ', () {
    for (var i = 0; i < 300; i++) {
      final free = rollBirth(Rng(800 + i));
      for (final f in [true, false]) {
        final b = rollBirth(Rng(800 + i), asFemale: f);
        expect(b.female, f);
        // 乱数の流れは変えない（身分・国・年・生まれ順は同じ）。
        expect(b.cls.id, free.cls.id);
        expect(b.region.n, free.region.n);
        expect(b.startYear, free.startYear);
        expect(b.order, free.order);
        // 選んだ性別は稀少度に数えない（同じ性別なら、運に任せたときより珍しくはならない）。
        if (f == free.female) {
          expect(b.rarity, lessThanOrEqualTo(free.rarity * 1.0001));
        }
      }
    }
  });

  test('運に任せると男女どちらも出る', () {
    var f = 0;
    for (var i = 0; i < 400; i++) {
      if (rollBirth(Rng(5000 + i)).female) f++;
    }
    expect(f, inInclusiveRange(150, 250));
  });
}
