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

  /// 今の見た目(決めていなければ、自動の見た目を数字にしたもの)。
  ClubLook get currentClubLook {
    final s = _save!;
    final own = s.clubLook;
    if (own != null) return own;
    final palette = ClubPalette.of(s.userTeamId, clubName: s.clubName);
    final seed = s.userTeamId.hashCode.abs();
    final name = s.clubName.trim();
    return ClubLook(
      hue: palette.hue,
      accentHue: (palette.hue + 40) % 360,
      shape: seed % 6,
      motif: (seed ~/ 6) % 6,
      initial: name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
    );
  }

  /// 見た目を決める。変えられなければ false。
  Future<bool> setClubLook(ClubLook look) async {
    final s = _save;
    if (s == null || !canChangeClubLook) return false;
    final initial = look.initial.trim();
    if (initial.isEmpty || initial.runes.length > 2) return false;
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
