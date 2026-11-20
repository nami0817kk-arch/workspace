import 'package:audioplayers/audioplayers.dart';

/// 効果音(`assets/sfx/`、`tool/make_sfx.py` で波形から合成)。
enum Sfx {
  tap,
  gain,
  rankup,
  great,
  bad,
  event,
  injury,
  trait,
  achievement,
  title,
  draft,
  champion,
  stage,
  retire,
}

/// 鳴らす係。テストでは何もしない `NullSound` を使う(音の機能が無い環境でも落ちない)。
abstract class SoundPlayer {
  Future<void> play(Sfx s);
}

class NullSound implements SoundPlayer {
  const NullSound();
  @override
  Future<void> play(Sfx s) async {}
}

/// 実機・Web で鳴らす。失敗しても(音の機能が無い環境など)ゲームは止めない。
class AudioSound implements SoundPlayer {
  final Map<Sfx, AudioPool> _pools = {};

  @override
  Future<void> play(Sfx s) async {
    try {
      final pool = _pools[s] ??= await AudioPool.create(
        source: AssetSource('sfx/${s.name}.wav'),
        maxPlayers: 2,
      );
      await pool.start(volume: 0.8);
    } catch (_) {}
  }
}
