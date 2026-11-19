import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 効果音(assets/sfx)。音はマナーモードでは鳴らさない(iPhone の決まり)。
/// テストの中や、部品が使えない環境では何もしない。
enum Sfx {
  whistleStart('whistle_start.mp3'),
  whistleEnd('whistle_end.mp3'),
  goalCheer('goal_cheer.mp3'),
  concedeAway('concede_away.mp3'),
  deal('deal.mp3'),
  celebrate('celebrate.mp3');

  final String file;
  const Sfx(this.file);
}

class SfxService {
  static bool _configured = false;

  /// テスト(flutter test)では鳴らさない。部品が無く例外になるため。
  static bool get _inTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('Test');
  }

  static Future<void> play(Sfx s, {double volume = 0.8}) async {
    if (_inTest) return;
    try {
      if (!_configured && !kIsWeb) {
        _configured = true;
        await AudioPlayer.global.setAudioContext(AudioContextConfig(
          respectSilence: true,
          stayAwake: false,
        ).build());
      }
      final player = AudioPlayer();
      player.onPlayerComplete.first.then((_) => player.dispose());
      await player.play(AssetSource('sfx/${s.file}'), volume: volume);
    } catch (e) {
      debugPrint('効果音を鳴らせなかった: $e');
    }
  }
}
