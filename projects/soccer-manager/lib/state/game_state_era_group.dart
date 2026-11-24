part of 'game_state.dart';

/// 時代の変化。
///
/// 以前はここで、オーナーの私財で他国の1部のクラブを買う(複数のクラブを
/// 持つ)こともできた。利用者と決めて外した(2026-11-25「他クラブを買うのは
/// なし」)。古いセーブで持っていたクラブは、読むときに買値で私財へ戻す
/// (SaveGame.fromJson)。クラブを手放したあとに別のクラブを買い直す流れ
/// (buyClubInCountry)は別のもので、残っている。
extension GameStateEraGroup on GameState {
  /// 今の時代。
  Era get currentEra => EraEngine.eraOf(_save?.league.season ?? 1);

  /// 季の切り替え: 時代が変わったら知らせる。
  void _announceEra(int newSeason) {
    final before = EraEngine.eraOf(newSeason - 1);
    final after = EraEngine.eraOf(newSeason);
    if (before == after) return;
    _logNews(
        Tr.pick('時代が変わった: 「${after.label}」。${after.summary}',
            'A new era: "${after.label}". ${after.summary}'),
        context: Tr.pick('時代', 'Era'));
  }
}
