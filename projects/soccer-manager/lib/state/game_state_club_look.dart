part of 'game_state.dart';

/// クラブの見た目(色・エンブレム)。最初の季は何度でも、2季目からは1季に
/// 1回まで変えられ、変えると古いサポーターが戸惑う。
extension GameStateClubLook on GameState {
  /// 2季目から見た目を変えたときの、サポーターの期待の下がり幅。
  static const int changePenalty = 3;

  /// 今のクラブで最初の季か(変えても期待が下がらない)。
  bool get _firstSeasonAtClub {
    final s = _save!;
    return !s.seasonHistory.any((r) => r.clubName == s.clubName);
  }

  /// 見た目を変えられるか。
  bool get canChangeClubLook {
    final s = _save;
    if (s == null) return false;
    return _firstSeasonAtClub ||
        s.clubLookChangedSeason != s.league.season;
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
      s.clubLookChangedSeason = s.league.season;
    }
    s.clubLook = look.copyWith(initial: initial);
    _addTimeline(Tr.pick('クラブの見た目を新しくした', 'Gave the club a new look'));
    _notify();
    await _persist();
    return true;
  }
}
