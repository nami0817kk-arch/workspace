part of 'game_state.dart';

/// 過密日程・経済の波・締切日の演出。
extension GameStateCongestion on GameState {
  /// 前の試合から間を空けずに(3日以内に)戦う試合ごとに、先発へ足す疲れ。
  /// 判定は試合の日付の間隔で行う([GameStateWeek._noteUserMatchDay])。
  static const int congestionFatigue = 6;

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
            'The window shuts before the next match. ${Tr.plural(open, 'deal')} in progress, ${Tr.plural(offers, 'offer')} waiting. Now or never.'));
  }
}
