part of 'game_state.dart';

/// 大きな怪我の手術の判断(手術か保存療法か)。
extension GameStateInjury on GameState {
  /// 手術か保存療法かを選ぶのを待っている選手。
  List<Player> get playersAwaitingSurgeryDecision {
    final s = _save;
    if (s == null) return const [];
    return [
      for (final p in userTeam.players)
        if (s.injuryPlans[p.id] == 'pending') p,
    ];
  }

  /// 手術の費用(今の部の物差し)。
  int get surgeryCost => scaledMoney(InjuryCare.surgeryCostTier5);

  /// 節ごと: 新しく大きな怪我(長い靭帯の怪我・骨折・前十字靭帯・
  /// アキレス腱)をした選手を、判断待ちにする。
  void _reviewInjuries() {
    final s = _save!;
    for (final p in userTeam.players) {
      if (InjuryCare.needsDecision(p) && !s.injuryPlans.containsKey(p.id)) {
        s.injuryPlans[p.id] = 'pending';
        _logNews(
            Tr.pick('${p.name}は${InjuryCare.describe(p)}(${p.injuryWeeks}週)。手術か保存療法かを決めてください。',
                '${p.name} has ${InjuryCare.describe(p)} (${p.injuryWeeks} weeks). Decide between surgery and rest.'),
            context: Tr.pick('医療', 'Medical'));
      }
    }
  }

  /// 手術する(費用がかかり、離脱は延びるが、再発しない)か、保存療法に
  /// する(離脱は縮むが、治ったときに再発することがある)。
  Future<bool> decideSurgery(String playerId, {required bool surgery}) async {
    final s = _save;
    if (s == null || s.injuryPlans[playerId] != 'pending') return false;
    final p = userTeam.players.where((x) => x.id == playerId).firstOrNull;
    if (p == null) return false;
    if (surgery) {
      _book(LedgerCategory.other, -surgeryCost);
      p.injuryWeeks += InjuryCare.surgeryExtraWeeks;
      s.injuryPlans[playerId] = 'surgery';
      _logNews(
          Tr.pick('${p.name}の手術を決めた(${formatMoney(surgeryCost)})。復帰まで${p.injuryWeeks}週。',
              'Surgery for ${p.name} (${formatMoney(surgeryCost)}). Back in ${p.injuryWeeks} weeks.'),
          context: Tr.pick('医療', 'Medical'));
    } else {
      p.injuryWeeks = max(1, p.injuryWeeks - InjuryCare.restSavedWeeks);
      s.injuryPlans[playerId] = 'rest';
      _logNews(
          Tr.pick('${p.name}は保存療法にした。復帰まで${p.injuryWeeks}週(再発することがある)。',
              '${p.name} will rest the injury. Back in ${p.injuryWeeks} weeks, though it may flare up again.'),
          context: Tr.pick('医療', 'Medical'));
    }
    _notify();
    await _persist();
    return true;
  }

  /// 怪我が治ったとき: 保存療法なら再発を振る。判断の記録を片付ける。
  /// 返すのは「再発した」か。
  bool _onUserInjuryHealed(Player p, double roll) {
    final s = _save!;
    final plan = s.injuryPlans.remove(p.id);
    if (plan == 'rest' && roll < InjuryCare.setbackChance) {
      p.injuryWeeks = InjuryCare.setbackWeeks;
      // 再発は元の怪我と同じ種類(種類が消えていたら靭帯損傷)。
      p.injuryType ??= InjuryType.ligament;
      s.injuryPlans[p.id] = 'surgery'; // 再発の後は、もう選ばせない
      _logNews(
          Tr.pick('${p.name}の怪我が再発した。あと${InjuryCare.setbackWeeks}週休む。',
              '${p.name}\'s injury has flared up again: out for another ${InjuryCare.setbackWeeks} weeks.'),
          context: Tr.pick('医療', 'Medical'));
      return true;
    }
    return false;
  }

  /// テスト用: 節ごとの怪我の点検を走らせる。
  @visibleForTesting
  void debugReviewInjuries() => _reviewInjuries();

  /// テスト用: 治ったときの処理を、乱数を決めて走らせる。
  @visibleForTesting
  bool debugHeal(Player p, double roll) => _onUserInjuryHealed(p, roll);
}
