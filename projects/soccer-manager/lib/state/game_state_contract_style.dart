part of 'game_state.dart';

/// 契約の中身(出来高・段階昇給)。
extension GameStateContractStyle on GameState {
  /// [p]の今の契約の型。
  ContractStyle contractStyleOf(Player p) => p.goalBonus > 0
      ? ContractStyle.goalBonus
      : p.raisePct > 0
          ? ContractStyle.stepped
          : ContractStyle.fixed;

  /// 契約の型を組み替えられるか(固定の契約で、気持ちが落ち着いている選手)。
  bool canChangeContractStyle(Player p) =>
      _save != null &&
      userTeam.players.contains(p) &&
      !p.isLoan &&
      contractStyleOf(p) == ContractStyle.fixed &&
      p.happiness >= 40;

  /// 契約の型を組み替える(固定から出来高・段階昇給へ)。
  Future<bool> changeContractStyle(String playerId, ContractStyle style) async {
    final p = userTeam.players.where((x) => x.id == playerId).firstOrNull;
    if (p == null || style == ContractStyle.fixed) return false;
    if (!canChangeContractStyle(p)) return false;
    final (wage, bonus, raise) = style.apply(p.wage);
    p.wage = wage;
    p.goalBonus = bonus;
    p.raisePct = raise;
    _logNews(
        Tr.pick('${p.name}の契約を「${style.label}」に組み替えた。',
            'Restructured ${p.name}\'s contract: ${style.label}.'),
        context: Tr.pick('契約', 'Contracts'));
    _notify();
    await _persist();
    return true;
  }

  /// 試合のあと: 自クラブの選手のリーグ戦の得点に出来高を払う。
  void _payGoalBonuses(MatchResult r) {
    final mine = {for (final p in userTeam.players) p.id: p};
    var total = 0;
    for (final e in r.events) {
      if (e.type != MatchEventType.goal) continue;
      final p = mine[e.scorerId];
      if (p == null || p.goalBonus <= 0) continue;
      total += p.goalBonus;
    }
    if (total > 0) _book(LedgerCategory.appearanceFees, -total);
  }

  /// 季の切り替え: 段階昇給の選手の週給を上げる(契約の切れた選手は対象外)。
  void _applySteppedRaises() {
    for (final p in userTeam.players) {
      if (p.raisePct <= 0 || p.isLoan) continue;
      p.wage = (p.wage * (100 + p.raisePct) / 100).round();
    }
  }

  @visibleForTesting
  void debugPayGoalBonuses(MatchResult r) => _payGoalBonuses(r);
  @visibleForTesting
  void debugApplySteppedRaises() => _applySteppedRaises();
}
