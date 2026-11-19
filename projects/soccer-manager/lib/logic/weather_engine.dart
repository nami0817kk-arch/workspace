import 'dart:math';

import '../models/weather.dart';

class WeatherEngine {
  static final Random _rng = Random();

  /// 試合ごとの天候を決める。[month](1〜12)を渡すと季節に合わせる:
  /// 雪は12〜2月だけ、猛暑は6〜8月だけ、雨と風は秋冬に多い。月が分からない
  /// ときは1年をならした割合(晴れが最も多く、荒天ほど稀)。
  static Weather roll({int? month, double? r}) {
    final x = r ?? _rng.nextDouble();
    final w = weights(month);
    var acc = 0.0;
    for (final e in w.entries) {
      acc += e.value;
      if (x < acc) return e.key;
    }
    return Weather.clear;
  }

  /// 月ごとの天候の割合(合計1)。
  static Map<Weather, double> weights(int? month) {
    if (month == null) {
      return const {
        Weather.clear: 0.55,
        Weather.rain: 0.20,
        Weather.wind: 0.12,
        Weather.heatwave: 0.09,
        Weather.snow: 0.04,
      };
    }
    return switch (month) {
      12 || 1 || 2 => const {
          Weather.clear: 0.45,
          Weather.rain: 0.22,
          Weather.wind: 0.18,
          Weather.snow: 0.15,
        },
      6 || 7 || 8 => const {
          Weather.clear: 0.60,
          Weather.rain: 0.12,
          Weather.wind: 0.06,
          Weather.heatwave: 0.22,
        },
      9 || 10 || 11 => const {
          Weather.clear: 0.50,
          Weather.rain: 0.30,
          Weather.wind: 0.20,
        },
      _ => const {
          Weather.clear: 0.60,
          Weather.rain: 0.25,
          Weather.wind: 0.15,
        },
    };
  }
}
