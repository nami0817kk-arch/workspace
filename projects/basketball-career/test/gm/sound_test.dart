import 'dart:typed_data';

import 'package:basketball_career/sound/sound.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements SoundBackend {
  final played = <Uint8List>[];
  @override
  Future<void> playWav(Uint8List wav) async => played.add(wav);
}

void main() {
  test('効果音の波形は WAV の形で、範囲内で、無音ではない', () {
    for (final e in SoundEffect.values) {
      final wav = buildWav(samplesOf(e));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final bd = ByteData.sublistView(wav);
      final dataLen = bd.getUint32(40, Endian.little);
      expect(dataLen, wav.length - 44);
      var peak = 0;
      for (var i = 44; i + 1 < wav.length; i += 2) {
        peak = peak > bd.getInt16(i, Endian.little).abs() ? peak : bd.getInt16(i, Endian.little).abs();
      }
      expect(peak, greaterThan(1000), reason: e.name);
      expect(peak, lessThanOrEqualTo(32000), reason: e.name);
      expect(wav.length, lessThan(100 * 1024), reason: '${e.name} は短い');
    }
  });

  test('音は、設定がオンでつないであるときだけ鳴る。切ると鳴らない', () async {
    final fake = _Fake();
    Sfx.backend = fake;
    Sfx.enabled = true;
    await Sfx.play(SoundEffect.chime);
    expect(fake.played, hasLength(1));
    Sfx.enabled = false;
    await Sfx.play(SoundEffect.buzzer);
    expect(fake.played, hasLength(1));
    Sfx.enabled = true;
    Sfx.backend = null;
    await Sfx.play(SoundEffect.tick); // つないでいなければ何もしない(例外も出さない)
    expect(fake.played, hasLength(1));
  });
}
