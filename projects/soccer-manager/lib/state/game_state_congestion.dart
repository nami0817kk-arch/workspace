part of 'game_state.dart';

/// 過密日程・経済の波・締切日の演出。
extension GameStateCongestion on GameState {
  /// 1週に2試合以上あったとき、余分の1試合ごとに先発へ足す疲れ。
  static const int congestionFatigue = 6;

  /// 自クラブがこれまでに戦った公式戦の数(リーグ・国内のカップ・大陸大会)。
  int get _userMatchesPlayed {
    final s = _save!;
    final me = s.userTeamId;
    bool mine(String a, String b) => a == me || b == me;
    var n = s.league.fixtures
        .where((f) => f.result != null && mine(f.homeTeamId, f.awayTeamId))
        .length;
    for (final cup in s.cups) {
      for (final round in cup.rounds) {
        n += round
            .where((m) => m.result != null && mine(m.homeTeamId, m.awayTeamId))
            .length;
      }
    }
    final c = s.continentalCup;
    if (c != null) {
      n += c.groupMatches
          .where((m) => m.result != null && mine(m.homeTeamId, m.awayTeamId))
          .length;
      for (final round in c.knockoutRounds) {
        for (final tie in round) {
          if (mine(tie.teamAId, tie.teamBId)) n += tie.legs.length;
        }
      }
    }
    return n;
  }

  /// 毎週: 前の週に2試合以上戦っていたら、先発に疲れを足す(過密日程)。
  void _applyCongestion() {
    final s = _save!;
    final now = _userMatchesPlayed;
    // 季が変わって数が減ったときは、数え直すだけ。
    final played = now >= s.userMatchesCounted ? now - s.userMatchesCounted : 0;
    s.userMatchesCounted = now;
    // 1週で4試合以上は数え直し(旧セーブで初めて数えたときなど)。
    s.lastWeekCongested = played >= 2 && played <= 3;
    if (!s.lastWeekCongested) return;
    final extra = congestionFatigue * (played - 1);
    for (final p in userTeam.players) {
      if (!userTeam.startingXI.contains(p.id)) continue;
      p.fatigue = (p.fatigue + extra).clamp(0, 100);
    }
    _logNews(
        Tr.pick('過密日程: この週は$played試合。先発の疲れが残っている。',
            'Fixture pile-up: $played matches this week. The starters are tired.'),
        context: Tr.pick('日程', 'Schedule'));
  }

  /// 景気に合わせて、スポンサーの提示の額を動かす(好況+15%・不況-15%)。
  List<SponsorDeal> _economyAdjusted(List<SponsorDeal> offers) {
    final f = switch (economyPhase) {
      EconomyPhase.boom => 1.15,
      EconomyPhase.normal => 1.0,
      EconomyPhase.slump => 0.85,
    };
    if (f == 1.0) return offers;
    return [
      for (final o in offers)
        SponsorDeal(
            name: o.name,
            weeklyIncome: (o.weeklyIncome * f).round(),
            yearsRemaining: o.yearsRemaining),
    ];
  }

  /// 移籍の締切日なら、画面いっぱいの1枚で知らせる(1つの窓に1回)。
  void _checkDeadlineMoment() {
    final s = _save!;
    if (!isTransferDeadlineDay) return;
    final closes = transferDeadline;
    if (closes == null) return;
    final open = s.transferTalks.where((t) => t.isOpen).length;
    final offers = s.incomingOffers.length;
    _queueMoment(
        BigMomentKind.deadlineDay,
        'deadline:${closes.toIso8601String()}',
        Tr.pick('${closes.month}月${closes.day}日に閉まる',
            'Closes ${closes.day}/${closes.month}'),
        Tr.pick('移籍の窓は、次の試合の前に閉まる。交渉中$open件・届いているオファー$offers件。決めるなら今だ。',
            'The window shuts before the next match. $open deal(s) in progress, $offers offer(s) waiting. Now or never.'));
  }

  @visibleForTesting
  void debugApplyCongestion() => _applyCongestion();
}
