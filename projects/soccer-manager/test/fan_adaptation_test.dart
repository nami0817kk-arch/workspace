import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/board_engine.dart';

/// サポーターの期待への慣れ。満点に張り付いたままにしない。
void main() {
  test('線以下は変わらない', () {
    expect(BoardEngine.afterAdaptation(60), 60);
    expect(BoardEngine.afterAdaptation(BoardEngine.adaptationLine),
        BoardEngine.adaptationLine);
  });

  test('線を超えた分の一部を失い、高いほど失う量が大きい', () {
    final at90 = BoardEngine.afterAdaptation(90);
    final at100 = BoardEngine.afterAdaptation(100);
    expect(at90, lessThan(90));
    expect(at100, lessThan(100));
    expect(100 - at100, greaterThan(90 - at90));
  });

  test('慣れで線を下回ることはなく、毎季繰り返すと満点から離れる', () {
    var c = 100;
    for (var i = 0; i < 10; i++) {
      c = BoardEngine.afterAdaptation(c);
      expect(c, greaterThanOrEqualTo(BoardEngine.adaptationLine));
    }
    expect(c, lessThan(85));
  });
}
