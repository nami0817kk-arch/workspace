import 'package:flutter_test/flutter_test.dart';

import 'package:soccer_manager/logic/weather_engine.dart';
import 'package:soccer_manager/models/weather.dart';

/// 天気が季節に合っているかの検査。
void main() {
  test('どの月も割合の合計は1', () {
    for (final m in [null, ...List.generate(12, (i) => i + 1)]) {
      final sum =
          WeatherEngine.weights(m).values.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(1, 1e-9), reason: '$m月');
    }
  });

  test('雪は冬だけ、猛暑は夏だけ', () {
    for (var m = 1; m <= 12; m++) {
      final w = WeatherEngine.weights(m);
      final winter = m == 12 || m <= 2;
      final summer = m >= 6 && m <= 8;
      expect(w.containsKey(Weather.snow), winter, reason: '$m月の雪');
      expect(w.containsKey(Weather.heatwave), summer, reason: '$m月の猛暑');
    }
  });

  test('乱数の端でも、その月に起こりうる天気だけが出る', () {
    for (var m = 1; m <= 12; m++) {
      for (final r in [0.0, 0.3, 0.6, 0.9, 0.999999]) {
        final w = WeatherEngine.roll(month: m, r: r);
        expect(WeatherEngine.weights(m).containsKey(w), isTrue,
            reason: '$m月 r=$r → $w');
      }
    }
  });
}
