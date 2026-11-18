import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('止まる場面ははじめ申し込みとけがで、切り替えると保存される', () {
    final c = careerAt(3, 15);
    expect(c.stopsOn(SimStop.offer), isTrue);
    expect(c.stopsOn(SimStop.injury), isTrue);
    expect(c.stopsOn(SimStop.mail), isFalse);
    c.toggleSimStop(SimStop.mail);
    c.toggleSimStop(SimStop.offer);
    expect(c.stopsOn(SimStop.mail), isTrue);
    expect(c.stopsOn(SimStop.offer), isFalse);
    final back = Career.fromJson(c.toJson());
    expect(back.simStops, c.simStops);
    // 前の版の保存(項目なし)は、はじめの設定になる
    final old = c.toJson()..remove('so');
    expect(Career.fromJson(old).simStops, [SimStop.offer.index, SimStop.injury.index]);
    while (c.phase != Phase.season) {
      botStep(c);
    }
  });
}
