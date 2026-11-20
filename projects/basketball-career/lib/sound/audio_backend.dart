import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'sound.dart';

/// audioplayers で効果音を鳴らす(アプリ本体だけがつなぐ。テストではつながない)。
class AudioplayersBackend implements SoundBackend {
  AudioplayersBackend() {
    // 効果音は、ほかのアプリの音(音楽など)を止めない
    AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
  }

  final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  Future<void> playWav(Uint8List wav) async {
    await _player.stop();
    await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
  }
}
