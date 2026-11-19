part of 'game_state.dart';

/// クラブライセンス(昇格の条件)。
extension GameStateLicense on GameState {
  /// [tier]部のライセンスで、自クラブが満たしていない条件(満たしていれば空)。
  List<String> clubLicenseUnmet(int tier) {
    final s = _save;
    if (s == null) return const [];
    return ClubLicenseEngine.unmet(
      tier,
      stadiumLevel: s.infrastructure.facilityLevel(FacilityType.stadium),
      budget: s.budget,
    );
  }

  /// 1つ上の部(今が1部なら null)。
  int? get nextTierUp {
    final t = _save?.currentDivisionTier;
    return t == null || t <= 1 ? null : t - 1;
  }
}
