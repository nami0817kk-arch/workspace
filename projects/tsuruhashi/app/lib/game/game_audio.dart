import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// BGM を鳴らす（ゲーム本体から `{"type":"bgm"}` で頼まれる）。
///
/// ファイルは assets/audio/bgm/ にある（tool/make_bgm.py が作り、tool/build_app_web.py が写す）。
/// iPhone の消音スイッチが入っていれば鳴らさない（respectSilence）。ほかのアプリの音は止めない。
class GameAudio {
  final AudioPlayer _bgm = AudioPlayer(playerId: 'bgm');
  String? _cur;
  double _vol = .32;
  bool _hidden = false;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(respectSilence: true).build());
      await _bgm.setReleaseMode(ReleaseMode.loop);
    } catch (_) {}
  }

  /// 場面の曲に替える。[key] が null か音量0なら止める。同じ曲なら音量だけ合わせる
  Future<void> bgm(String? key, double vol) async {
    await _init();
    _vol = vol;
    try {
      if (key == null || vol <= 0) {
        _cur = null;
        await _bgm.stop();
        return;
      }
      if (key == _cur) {
        await _bgm.setVolume(vol);
        return;
      }
      _cur = key;
      await _bgm.stop();
      await _bgm.setVolume(vol);
      if (!_hidden) await _bgm.play(AssetSource('audio/bgm/$key.mp3'), volume: vol);
    } catch (_) {}
  }

  /// アプリが裏に回ったら止め、戻ったら続きから
  Future<void> setHidden(bool hidden) async {
    _hidden = hidden;
    try {
      if (hidden) {
        await _bgm.pause();
      } else if (_cur != null) {
        if (_bgm.state == PlayerState.paused) {
          await _bgm.resume();
        } else {
          await _bgm.play(AssetSource('audio/bgm/$_cur.mp3'), volume: _vol);
        }
      }
    } catch (_) {}
  }

  void dispose() {
    _bgm.dispose();
  }
}
