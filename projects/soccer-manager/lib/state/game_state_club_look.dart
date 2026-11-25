part of 'game_state.dart';

/// クラブの見た目(色・エンブレム)。変えられるのはオフシーズン(季の終わり〜
/// 開幕前。2026-11-25)だけ。最初の季は何度でも、2季目からはオフシーズン
/// 1回につき1回まで変えられ、変えると古いサポーターが戸惑う。
extension GameStateClubLook on GameState {
  /// 2季目から見た目を変えたときの、サポーターの期待の下がり幅。
  static const int changePenalty = 3;

  /// 今のクラブで最初の季か(変えても期待が下がらない)。
  bool get _firstSeasonAtClub {
    final s = _save!;
    return !s.seasonHistory.any((r) => r.clubName == s.clubName);
  }

  /// いまのオフシーズンを数える季。季の終わりは次の季の分として数える
  /// (季の終わりと次の開幕前で、2回変えられないように)。
  int get _clubLookSeasonKey {
    final s = _save!;
    return isPreseason ? s.league.season : s.league.season + 1;
  }

  /// 見た目を変えられるか(オフシーズンだけ)。
  bool get canChangeClubLook {
    final s = _save;
    if (s == null || !isOffseason) return false;
    return _firstSeasonAtClub || s.clubLookChangedSeason != _clubLookSeasonKey;
  }

  /// このオフシーズンにもう変えたか(シーズン中は false)。
  bool get clubLookChangedThisOffseason {
    final s = _save;
    if (s == null || !isOffseason || _firstSeasonAtClub) return false;
    return s.clubLookChangedSeason == _clubLookSeasonKey;
  }

  /// 変えたらサポーターの期待が下がるか。
  bool get clubLookChangeCosts => _save != null && !_firstSeasonAtClub;

  /// 今の見た目(決めていなければ、クラブから決まる画像のエンブレム)。
  ClubLook get currentClubLook {
    final s = _save!;
    return s.clubLook ?? defaultClubLook(s.userTeamId, s.clubName);
  }

  /// 決めていない自クラブに付ける見た目。自クラブ用の25枚のうち、クラブの
  /// id と名前から決まる1枚(2026-11-25。盾＋頭文字の描画は初期にしない)。
  /// 形・模様・頭文字は「描いたエンブレムに戻す」ときの下書き。
  static ClubLook defaultClubLook(String teamId, String clubName) {
    final seed = teamId.hashCode.abs();
    final name = clubName.trim();
    return ClubLook(
      hue: 0,
      accentHue: 0,
      shape: seed % 6,
      motif: (seed ~/ 6) % 6,
      initial: name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
    ).withCrest(ClubLook.defaultCrestFor(teamId, clubName));
  }

  /// 見た目を決めていない自クラブに、画像のエンブレムを1つ付ける。
  ///
  /// 新しく始めたとき・古いセーブを開いたとき・クラブを替えたときに呼ぶ。
  /// 表にある名前のクラブ(買い直したクラブ)は、そのクラブの元の画像を
  /// 出すので付けない。すでに決めた見た目(描いたエンブレムも)は変えない
  /// (オーナーが選んだもの。画像は見た目を変える画面で勧める)。
  static void ensureOwnCrest(SaveGame s) {
    if (s.clubLook != null) return;
    if (ClubNames.crestIndexOf(s.clubName) != null) return;
    s.clubLook = defaultClubLook(s.userTeamId, s.clubName);
  }

  /// 見た目を決める。変えられなければ false。
  Future<bool> setClubLook(ClubLook look) async {
    final s = _save;
    if (s == null || !canChangeClubLook) return false;
    var initial = look.initial.trim();
    if (initial.isEmpty || initial.runes.length > 2) {
      // 画像のエンブレムなら頭文字は出ない。今の頭文字を残して決める。
      if (look.crest == null) return false;
      initial = currentClubLook.initial;
    }
    if (clubLookChangeCosts) {
      _changeSupporters(-changePenalty, SupporterReason.events);
      s.clubLookChangedSeason = _clubLookSeasonKey;
    }
    s.clubLook = look.copyWith(initial: initial);
    _addTimeline(Tr.pick('クラブの見た目を新しくした', 'Gave the club a new look'));
    _notify();
    await _persist();
    return true;
  }
}
