part of 'game_state.dart';

/// クラブライセンス(昇格の条件)。
extension GameStateLicense on GameState {
  /// [tier]部のライセンスで、自クラブが満たしていない条件(満たしていれば空)。
  List<String> clubLicenseUnmet(int tier) {
    final s = _save;
    if (s == null) return const [];
    return ClubLicenseEngine.unmet(
      tier,
      stadiumLevel: licensedStadiumLevel,
      budget: s.budget,
    );
  }

  /// ライセンスの判定で数えるスタジアムの段階。増築中で、次の季の開幕
  /// までに完成するなら、完成後の段階で数える(上の部で戦うのは完成後の
  /// スタジアムなので)。
  int get licensedStadiumLevel {
    final s = _save;
    if (s == null) return 1;
    final infra = s.infrastructure;
    final lvl = infra.facilityLevel(FacilityType.stadium);
    final ready = infra.constructionReadyOn(FacilityType.stadium);
    final nextStart = SeasonCalendar.preseasonDate(s.league.season + 1);
    return ready != null && !ready.isAfter(nextStart) ? lvl + 1 : lvl;
  }

  /// 1つ上の部(今が1部なら null)。
  int? get nextTierUp {
    final t = _save?.currentDivisionTier;
    return t == null || t <= 1 ? null : t - 1;
  }
}
