part of 'game_state.dart';

/// 株主総会の議案(株主の要求)と、決算の法人税。
extension GameStateAgm on GameState {
  /// 株主総会で出され、まだ答えていない要求。
  AgmDemand? get agmDemand {
    final n = _save?.agmDemand;
    if (n == null) return null;
    return AgmDemand.values.where((d) => d.name == n).firstOrNull;
  }

  /// 決算: 今季の利益に法人税を掛ける(繰越欠損を先に引く)。
  void _settleCorporateTax() {
    final s = _save!;
    final profit = currentLedger.profit;
    final (tax, carry) =
        AgmEngine.tax(profit: profit, carry: s.taxLossCarry);
    s.taxLossCarry = carry;
    if (tax > 0) _book(LedgerCategory.other, -tax);
    _logNews(
        tax > 0
            ? Tr.pick('決算: 今季の利益${formatMoney(profit)}に法人税${formatMoney(tax)}(${AgmEngine.taxRatePercent}%)を払った。',
                'Year-end accounts: ${formatMoney(tax)} corporation tax (${AgmEngine.taxRatePercent}%) on a profit of ${formatMoney(profit)}.')
            : Tr.pick('決算: 今季の損益は${formatMoney(profit)}。法人税はかからない(繰越欠損 ${formatMoney(carry)})。',
                'Year-end accounts: result ${formatMoney(profit)}. No corporation tax (losses carried forward: ${formatMoney(carry)}).'),
        context: Tr.pick('決算', 'Accounts'));
  }

  /// 総会で: 去年の約束を確かめ、今年の要求を出す。
  void _raiseAgmDemand() {
    final s = _save!;
    final ledger = currentLedger;
    final ratio = ledger.wageRatio;
    final pledge = s.agmWageRatioPledge;
    if (pledge > 0) {
      if (ratio > pledge) {
        s.shareholderExpectation = (s.shareholderExpectation - 10).clamp(0, 100);
        _logNews(
            Tr.pick('株主総会: 人件費を下げる約束を守らなかった(人件費率${(ratio * 100).round()}%)と、株主が反発している。',
                'Shareholders\' meeting: you broke your promise to cut wages (wage ratio ${(ratio * 100).round()}%), and they are angry.'),
            context: Tr.pick('株主総会', 'Shareholders\' meeting'));
      }
      s.agmWageRatioPledge = 0;
    }
    final outside = 100 - s.ownerShare;
    final d = AgmEngine.pick(
      wageRatio: ratio,
      profit: ledger.profit,
      outsideShare: outside,
      managerStanding: s.managerStanding,
      hasManager: currentManager != null,
    );
    s.agmDemand = d?.name;
    s.agmPayout = d == AgmDemand.payout
        ? AgmEngine.extraPayout(profit: ledger.profit, outsideShare: outside)
        : 0;
    s.agmWageRatio = ratio;
    if (d != null) {
      _logNews(Tr.pick('株主総会: ${d.title}。', 'Shareholders\' meeting: ${d.title}.'),
          context: Tr.pick('株主総会', 'Shareholders\' meeting'));
    }
  }

  /// 株主の要求に答える。
  Future<bool> answerAgmDemand({required bool accept}) async {
    final s = _save;
    final d = agmDemand;
    if (s == null || d == null) return false;
    if (accept) {
      switch (d) {
        case AgmDemand.wageCut:
          s.agmWageRatioPledge =
              max(0.01, s.agmWageRatio - AgmEngine.wageCutPoints);
        case AgmDemand.payout:
          if (s.agmPayout > 0) _book(LedgerCategory.financing, -s.agmPayout);
        case AgmDemand.manager:
          if (currentManager != null) {
            s.agmDemand = null;
            await dismissStaff(StaffRole.manager);
          }
      }
    }
    s.shareholderExpectation =
        (s.shareholderExpectation + (accept ? d.acceptDelta : d.rejectDelta))
            .clamp(0, 100);
    _logNews(
        accept
            ? Tr.pick('株主の要求をのんだ: ${d.acceptLabel}。',
                'You gave the shareholders what they asked: ${d.acceptLabel}.')
            : Tr.pick('株主の要求を断った。', 'You turned the shareholders down.'),
        context: Tr.pick('株主総会', 'Shareholders\' meeting'));
    s.agmDemand = null;
    s.agmPayout = 0;
    _notify();
    await _persist();
    return true;
  }
}
