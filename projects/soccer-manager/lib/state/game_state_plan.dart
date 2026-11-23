part of 'game_state.dart';

/// 5か年計画と、オーナーの経歴・順位。
extension GameStatePlan on GameState {
  /// いま進めている5か年計画が始まった季(0 は計画なし)。
  int get planStartSeason => _save?.planStartSeason ?? 0;

  bool get hasFiveYearPlan => planStartSeason > 0;

  /// 計画の残りの季数。
  int get planSeasonsLeft => !hasFiveYearPlan
      ? 0
      : OwnerHistoryEngine.planSeasons -
          (_save!.league.season - planStartSeason);

  /// 5か年計画を立てる(計画が無いときだけ)。目標は今から[a]の分だけ上。
  Future<bool> startFiveYearPlan(PlanAmbition a) async {
    final s = _save;
    if (s == null || hasFiveYearPlan) return false;
    s.planStartSeason = s.league.season;
    s.planTargetTier = max(1, s.currentDivisionTier - a.tiersUp);
    s.planTargetValue = (clubValue.total * a.valueMultiple).round();
    s.planTargetStadium = min(ClubInfrastructure.maxLevel,
        s.infrastructure.facilityLevel(FacilityType.stadium) + a.stadiumUp);
    _addTimeline(Tr.pick('5か年計画(${a.label})を立てた',
        'Set out a five-year plan (${a.label})'));
    _logNews(
        Tr.pick(
            '5か年計画(${a.label}): ${s.planTargetTier}部・クラブ価値${formatMoney(s.planTargetValue)}・スタジアム水準${s.planTargetStadium}。株主に約束した。',
            'Five-year plan (${a.label}): Tier ${s.planTargetTier}, club value ${formatMoney(s.planTargetValue)}, stadium level ${s.planTargetStadium}. The shareholders have your word.'),
        context: Tr.pick('オーナー', 'Owner'));
    _notify();
    await _persist();
    return true;
  }

  /// 計画の目標のうち、いま果たしているもの(部・価値・スタジアム)。
  (bool, bool, bool) get planProgress {
    final s = _save;
    if (s == null || !hasFiveYearPlan) return (false, false, false);
    return (
      s.currentDivisionTier <= s.planTargetTier,
      clubValue.total >= s.planTargetValue,
      s.infrastructure.facilityLevel(FacilityType.stadium) >=
          s.planTargetStadium,
    );
  }

  /// 季の終わり: 計画が5季たったら採点する(3季目には途中経過を伝える)。
  void _reviewFiveYearPlan() {
    final s = _save!;
    if (!hasFiveYearPlan) return;
    final elapsed = s.league.season - s.planStartSeason + 1;
    final (a, b, c) = planProgress;
    final met = [a, b, c].where((x) => x).length;
    if (elapsed == 3) {
      _logNews(
          Tr.pick('5か年計画の折り返し: 目標3つのうち$met つを果たしている。',
              'Five-year plan halfway: $met of 3 targets met so far.'),
          context: Tr.pick('オーナー', 'Owner'));
    }
    if (elapsed < OwnerHistoryEngine.planSeasons) return;
    final delta = OwnerHistoryEngine.planResultDelta(met);
    s.shareholderExpectation =
        (s.shareholderExpectation + delta).clamp(0, 100);
    s.planStartSeason = 0;
    _addTimeline(Tr.pick('5か年計画を終えた(目標3つのうち$met つ)',
        'Five-year plan finished ($met of 3 targets)'));
    _logNews(
        Tr.pick('5か年計画が終わった: 目標3つのうち$met つを果たした。株主の期待${delta >= 0 ? '+' : ''}$delta。',
            'Five-year plan over: $met of 3 targets met. Shareholder expectation ${delta >= 0 ? '+' : ''}$delta.'),
        context: Tr.pick('オーナー', 'Owner'));
  }

  /// これまでのオーナーとしての経歴(手放したクラブと、今のクラブ)。
  List<OwnerLegacy> get ownerCareer {
    final s = _save;
    if (s == null) return const [];
    return [
      ...s.ownerLegacies,
      _legacyOfCurrentClub(SaleReason.supporters),
    ];
  }

  /// あなたのオーナーとしての点(経歴の合計)。
  int get ownerScore => ownerCareer.fold<int>(
      0, (t, l) => t + OwnerHistoryEngine.score(l));
}
