part of 'game_state.dart';

/// 地域貢献の活動(2026-11-25 の第6段)。
///
/// 以前は「地域貢献 Lv」を一度払って上げるだけだった。毎年の取り組みとして、
/// 季ごとに活動を選び、その季の費用を払う。選んだ活動は次の季にも続ける
/// (季の切り替えで次の季の費用を払う。払えなければ止まる)。
extension GameStateCommunity on GameState {
  /// 毎月のサポーターの期待への効き目(教室・訪問の合計。+2まで)。
  int get communityMonthlyDelta {
    final s = _save;
    if (s == null) return 0;
    return min(2, s.communityActivities.fold<int>(0, (t, a) => t + a.supporterMonthly));
  }

  /// [a] の今の部での1季の費用。
  int communityCostOf(CommunityActivity a) => scaledMoney(a.seasonCost);

  bool isCommunityActive(CommunityActivity a) =>
      _save?.communityActivities.contains(a) ?? false;

  /// 今季の地域活動の費用の合計(次の季も続けるときの額)。
  int get communitySeasonCost => [
        for (final a in _save?.communityActivities ?? const <CommunityActivity>[])
          communityCostOf(a),
      ].fold(0, (s, c) => s + c);

  /// [a] を今季の活動に加える。今季の費用をすぐ払う。
  Future<bool> startCommunityActivity(CommunityActivity a) async {
    final s = _save;
    if (s == null || s.communityActivities.contains(a)) return false;
    final cost = communityCostOf(a);
    if (cost > s.budget) return false;
    _book(LedgerCategory.other, -cost);
    s.communitySeasonSpent += cost;
    s.communityActivities = [...s.communityActivities, a];
    _bumpDemandForCommunity(a);
    _notify();
    await _persist();
    return true;
  }

  /// [a] を止める(払った今季の費用は戻らない)。
  Future<bool> stopCommunityActivity(CommunityActivity a) async {
    final s = _save;
    if (s == null || !s.communityActivities.contains(a)) return false;
    s.communityActivities = [
      for (final x in s.communityActivities)
        if (x != a) x,
    ];
    _notify();
    await _persist();
    return true;
  }

  void _bumpDemandForCommunity(CommunityActivity a) {
    final s = _save!;
    if (a.demandPercent <= 0) return;
    _ensureFanDemand(s);
    s.fanDemand = (s.fanDemand * (100 + a.demandPercent) / 100).round();
  }

  /// 季の切り替え: 前の季の結果を残し、続ける活動の次の季の費用を払う。
  void _rollCommunity() {
    final s = _save!;
    final acts = [...s.communityActivities];
    var backing = 0;
    for (final a in acts) {
      if (a.sponsorBackPercent <= 0) continue;
      backing += (communityCostOf(a) * a.sponsorBackPercent / 100).round();
    }
    if (backing > 0) _book(LedgerCategory.other, backing);
    if (acts.isNotEmpty || s.communitySeasonSpent > 0) {
      s.lastCommunityReport = CommunityReport(
        season: s.league.season,
        activities: acts,
        spent: s.communitySeasonSpent,
        supporterGain: s.communitySeasonGain,
        backing: backing,
      );
    }
    s.communitySeasonGain = 0;
    s.communitySeasonSpent = 0;
    final kept = <CommunityActivity>[];
    final dropped = <CommunityActivity>[];
    for (final a in acts) {
      final cost = communityCostOf(a);
      if (cost <= s.budget) {
        _book(LedgerCategory.other, -cost);
        s.communitySeasonSpent += cost;
        kept.add(a);
        _bumpDemandForCommunity(a);
      } else {
        dropped.add(a);
      }
    }
    s.communityActivities = kept;
    if (dropped.isNotEmpty) {
      _logNews(
          Tr.pick(
              '資金が足りず、地域活動(${dropped.map((a) => a.label).join('・')})を今季は止めた。',
              'Short of funds, we have paused our community work this season (${dropped.map((a) => a.label).join(', ')}).'),
          context: Tr.pick('地域', 'Community'));
    }
  }
}
