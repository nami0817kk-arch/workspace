import 'dart:math' as math;
import 'dart:typed_data';

/// 効果音の種類。
enum SoundEffect {
  /// 区切りの終わりのブザー。
  buzzer,

  /// 契約・トレードの成立。
  chime,

  /// ドラフトの指名・くじ。
  tick,

  /// 歓声(優勝・大きな出来事)。
  cheer,

  /// 優勝のファンファーレ。
  fanfare,
}

const _rate = 22050;

/// 16bit モノラルの WAV を作る([samples] は -1〜1)。
Uint8List buildWav(List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void str(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // モノラル
  data.setUint32(24, _rate, Endian.little);
  data.setUint32(28, _rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

List<double> _tone(double hz, double sec, {double decay = 3, double square = 0}) {
  final n = (sec * _rate).round();
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = i / _rate;
        final s = math.sin(2 * math.pi * hz * t);
        final w = square > 0 ? (s * (1 - square) + (s >= 0 ? 1 : -1) * square) : s;
        // 立ち上がりの短い音量変化(プチッと鳴らない)と、指数の減衰
        final attack = math.min(1.0, i / (_rate * 0.005));
        return w * attack * math.exp(-decay * t / sec);
      }(),
  ];
}

List<double> _mix(List<List<double>> parts) {
  final n = parts.fold(0, (m, p) => math.max(m, p.length));
  return [for (var i = 0; i < n; i++) parts.fold(0.0, (s, p) => s + (i < p.length ? p[i] : 0)) / parts.length * 1.4];
}

List<double> _seq(List<List<double>> parts) => [for (final p in parts) ...p];

/// 効果音の波形。どれも短く、コードで作る(素材の権利が要らない)。
List<double> samplesOf(SoundEffect e) {
  switch (e) {
    case SoundEffect.buzzer:
      return _mix([_tone(196, 0.7, decay: 1.2, square: 0.7), _tone(207, 0.7, decay: 1.2, square: 0.7)]);
    case SoundEffect.chime:
      return _seq([_tone(660, 0.16, decay: 2), _tone(880, 0.5, decay: 3.5)]);
    case SoundEffect.tick:
      return _tone(1500, 0.045, decay: 5);
    case SoundEffect.cheer:
      // 歓声は、ざわざわした雑音(平均で丸めて低めに)に、ゆっくり大きくなる音量を付ける
      final n = (1.3 * _rate).round();
      final r = math.Random(7);
      final raw = [for (var i = 0; i < n; i++) r.nextDouble() * 2 - 1];
      final out = <double>[];
      for (var i = 0; i < n; i++) {
        var sum = 0.0;
        for (var k = 0; k < 6; k++) {
          sum += raw[(i + k) % n];
        }
        final t = i / n;
        final env = math.sin(math.pi * math.min(1.0, t * 1.15)) * (1 - 0.3 * t);
        out.add(sum / 6 * env * 0.9);
      }
      return out;
    case SoundEffect.fanfare:
      return _seq([_tone(523, 0.18, decay: 2), _tone(659, 0.18, decay: 2), _tone(784, 0.18, decay: 2), _tone(1047, 0.7, decay: 3)]);
  }
}

/// 音を鳴らす側(アプリが本物をつなぐ。テストでは何もつながない)。
abstract class SoundBackend {
  Future<void> playWav(Uint8List wav);
}

/// 効果音。設定で切れる。バックエンドが無ければ何もしない。
class Sfx {
  static SoundBackend? backend;
  static bool enabled = true;
  static final _cache = <SoundEffect, Uint8List>{};

  static Future<void> play(SoundEffect e) async {
    final b = backend;
    if (!enabled || b == null) return;
    try {
      await b.playWav(_cache.putIfAbsent(e, () => buildWav(samplesOf(e))));
    } catch (_) {
      // 鳴らせなくても、遊びは止めない
    }
  }
}
