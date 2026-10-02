import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// BGM と台詞の声を鳴らす（ゲーム本体から `{"type":"bgm"}` / `{"type":"voice"}` で頼まれる）。
///
/// ファイルは assets/audio/ にある（tool/make_bgm.py・tool/make_voice.py が作る）。
/// iPhone の消音スイッチが入っていれば鳴らさない（respectSilence）。ほかのアプリの音は止めない。
class GameAudio {
  final AudioPlayer _bgm = AudioPlayer(playerId: 'bgm');
  final AudioPlayer _voice = AudioPlayer(playerId: 'voice');
  String? _cur;
  double _vol = .33;
  bool _hidden = false;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(respectSilence: true).build());
      await _bgm.setReleaseMode(ReleaseMode.loop);
      _voice.onPlayerComplete.listen((_) => unawaited(_bgm.setVolume(_vol)));
    } catch (_) {}
  }

  /// 場面の曲に替える。[key] が null なら止める。同じ曲なら音量だけ合わせる
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

  /// 台詞を1つ鳴らす（前の台詞は止める）。鳴っている間は BGM を小さくする
  Future<void> voice(String file) async {
    await _init();
    if (_hidden) return;
    try {
      await _voice.stop();
      if (_cur != null) await _bgm.setVolume(_vol * .35);
      await _voice.play(AssetSource('audio/voice/$file.mp3'));
    } catch (_) {
      unawaited(_bgm.setVolume(_vol));
    }
  }

  /// アプリが裏に回ったら止め、戻ったら続きから
  Future<void> setHidden(bool hidden) async {
    _hidden = hidden;
    try {
      if (hidden) {
        await _bgm.pause();
        await _voice.stop();
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
    _voice.dispose();
  }
}
