part of 'game_state.dart';

/// 枠ごとのスポンサー(袖・背中・練習着)。胸のスポンサーと命名権とは別の
/// 会社と結ぶ。空いている枠には季の始めに提示が1件ずつ来る。
extension GameStateSponsorSlots on GameState {
  /// [slot]の今の契約(無ければ null)。
  SponsorDeal? slotSponsor(SponsorSlot slot) =>
      _save?.slotSponsors[slot.name];

  /// [slot]への提示(無ければ null)。
  SponsorDeal? slotSponsorOffer(SponsorSlot slot) =>
      _save?.slotSponsorOffers[slot.name];

  /// 枠ごとのスポンサーの週の収入の合計(商業の倍率を掛ける前)。
  int get slotSponsorWeeklyIncome => _save == null
      ? 0
      : _save!.slotSponsors.values
          .fold<int>(0, (s, d) => s + d.weeklyIncome);

  /// [slot]の提示を結ぶ。
  Future<bool> signSlotSponsor(SponsorSlot slot) async {
    final s = _save;
    final offer = s?.slotSponsorOffers[slot.name];
    if (s == null || offer == null || s.slotSponsors.containsKey(slot.name)) {
      return false;
    }
    s.slotSponsors[slot.name] = offer;
    s.slotSponsorOffers.remove(slot.name);
    _logNews(
        Tr.pick(
            '${slot.label}のスポンサーを${offer.name}と結んだ(年${formatMoney(offer.weeklyIncome * matchdaysPerSeason)}・${offer.yearsRemaining}年)。',
            'Signed ${offer.name} as ${slot.label.toLowerCase()} sponsor (${formatMoney(offer.weeklyIncome * matchdaysPerSeason)} a year for ${Tr.plural(offer.yearsRemaining, 'year')}).'),
        context: Tr.pick('スポンサー', 'Sponsors'));
    _notify();
    await _persist();
    return true;
  }

  /// [slot]の提示を見送る(次の季の始めにまた来る)。
  Future<bool> declineSlotSponsor(SponsorSlot slot) async {
    final s = _save;
    if (s == null || s.slotSponsorOffers.remove(slot.name) == null) {
      return false;
    }
    _notify();
    await _persist();
    return true;
  }

  /// 季の境目: 契約を1年進め、空いた枠に提示を出す。
  void _rollSlotSponsors() {
    final s = _save!;
    for (final k in [...s.slotSponsors.keys]) {
      final d = s.slotSponsors[k]!;
      d.yearsRemaining -= 1;
      if (d.yearsRemaining <= 0) s.slotSponsors.remove(k);
    }
    _offerEmptySlotSponsors();
  }

  /// 空いている枠に、まだ提示が無ければ1件ずつ出す。
  void _offerEmptySlotSponsors() {
    final s = _save!;
    for (final slot in SponsorSlot.values) {
      if (s.slotSponsors.containsKey(slot.name) ||
          s.slotSponsorOffers.containsKey(slot.name)) {
        continue;
      }
      s.slotSponsorOffers[slot.name] = SponsorSlotEngine.offerFor(
        slot,
        userTeam.overallRating,
        tier: s.currentDivisionTier,
        managerReputation: s.managerReputation,
        stadiumLevel: s.infrastructure.facilityLevel(FacilityType.stadium),
      );
    }
  }

  /// テスト用: 季の境目の処理だけを走らせる。
  @visibleForTesting
  void debugRollSlotSponsors() => _rollSlotSponsors();
}
