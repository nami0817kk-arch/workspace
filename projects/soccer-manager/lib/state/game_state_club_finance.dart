part of 'game_state.dart';

/// 他のクラブの経営(自国のクラブだけ)。季の終わりにお金が動き、赤字が
/// 続いたクラブは破綻する(勝ち点の剥奪・主力の放出・身売り)。
extension GameStateClubFinance on GameState {
  /// 破綻の線: 資金が年収のこの割合ぶんマイナスになったら破綻。
  static const double collapseShare = 0.5;

  /// 破綻したクラブが次の季に引かれる勝ち点。
  static const int collapsePoints = 6;

  /// 破綻したクラブが放出する主力の数。
  static const int collapseSales = 2;

  /// 破綻したクラブの選手の言い値の割引(投げ売り)。
  static const double distressDiscount = 0.8;

  /// 他のクラブの1年の収入の見込み(万円)。その部の年俸の真ん中のクラブが
  /// 人件費率60%で回る額を基準に、順位が上ほど(観客・賞金で)多い。
  /// [rankFactor]は 1(首位)〜0(最下位)。部ごとの年俸の桁に自然に合う。
  static int aiAnnualIncome(int medianWageBill, double rankFactor) =>
      (medianWageBill / 0.6 * (0.7 + 0.6 * rankFactor)).round();

  /// 自国の各部のクラブ(自クラブを除く)と、その部。
  List<(Team, int, League)> get _homeClubs {
    final s = _save!;
    return [
      for (final t in s.league.teams)
        if (t.id != s.userTeamId) (t, s.currentDivisionTier, s.league),
      for (var i = 0; i < s.otherDivisionLeagues.length; i++)
        if (s.otherDivisionLeagues[i] != null)
          for (final t in s.otherDivisionLeagues[i]!.teams)
            (t, i + 1, s.otherDivisionLeagues[i]!),
    ];
  }

  /// [t]が今、破綻して投げ売りしているクラブか。
  bool isDistressedClub(String teamId) =>
      _save?.distressedClubIds.contains(teamId) ?? false;

  /// 季の終わり: 他のクラブのお金を動かし、破綻したクラブを片付ける。
  /// 返すのは「来季に勝ち点を引くクラブ」の id。
  List<String> _settleAiClubFinances() {
    final s = _save!;
    s.distressedClubIds.clear();
    final collapsed = <String>[];
    // 部ごとの年俸の真ん中(収入の基準)。
    final medians = <League, int>{};
    for (final (_, _, league) in _homeClubs) {
      medians.putIfAbsent(league, () {
        final w = [
          for (final t in league.teams) ContractEngine.weeklyWageBill(t) * 52
        ]..sort();
        return w.isEmpty ? 0 : w[w.length ~/ 2];
      });
    }
    for (final (t, _, league) in _homeClubs) {
      // 順位(まだ試合が無ければ、戦力の順)。
      final played = league.sortedStandings.any((r) => r.played > 0);
      final order = played
          ? [for (final r in league.sortedStandings) r.teamId]
          : [
              for (final x in ([...league.teams]
                ..sort((a, b) => b.overallRating.compareTo(a.overallRating))))
                x.id
            ];
      final idx = order.indexOf(t.id);
      final n = max(1, order.length - 1);
      final rankFactor = idx < 0 ? 0.5 : 1 - idx / n;
      final income = aiAnnualIncome(medians[league]!, rankFactor);
      final wages = ContractEngine.weeklyWageBill(t) * 52;
      final other = (income * 0.25).round();
      // 始めの蓄え(年収の半分)。1年の赤字ですぐには潰れない。
      final cash = (s.clubCash[t.id] ?? (income * 0.5).round()) +
          income -
          wages -
          other;
      if (cash < -income * collapseShare) {
        collapsed.add(t.id);
        s.distressedClubIds.add(t.id);
        _collapseClub(t);
        s.clubCash[t.id] = 0; // 身売りで新しい持ち主が借金を引き取る
      } else {
        s.clubCash[t.id] = cash;
      }
    }
    return collapsed;
  }

  /// 破綻したクラブ: 主力を放出し(自由契約へ)、身売りのニュースを出す。
  void _collapseClub(Team t) {
    final s = _save!;
    final sold = ([...t.players]
          ..sort((a, b) => b.marketValue.compareTo(a.marketValue)))
        .take(collapseSales)
        .toList();
    for (final p in sold) {
      if (t.players.length <= GameStateTransfer.minSquadToSell) break;
      t.players.remove(p);
      t.startingXI.remove(p.id);
      s.freeAgents.add(p);
    }
    LineupUtils.fillVacancies(t);
    _logNews(
        Tr.pick(
            '${t.name}が経営破綻し、身売りした。来季は勝ち点$collapsePoints点の剥奪。${sold.isEmpty ? '' : '${sold.map((p) => p.name).join('、')}は自由契約になった。'}今季は選手を投げ売りしている。',
            '${t.name} have gone bust and been sold. They start next season $collapsePoints points down.${sold.isEmpty ? '' : ' ${sold.map((p) => p.name).join(', ')} are now free agents.'} Their players are going cheap this season.'),
        context: Tr.pick('他のクラブ', 'Other clubs'));
  }

  /// 新しい季の順位表に、破綻したクラブの勝ち点の剥奪を入れる。
  void _applyCollapsePenalties(List<String> ids) {
    final s = _save!;
    final leagues = [
      s.league,
      for (final l in s.otherDivisionLeagues)
        if (l != null) l,
    ];
    for (final id in ids) {
      for (final l in leagues) {
        if (l.teams.any((t) => t.id == id)) {
          l.pointsAdjustments[id] = -collapsePoints;
          break;
        }
      }
    }
  }

  /// テスト用: 季の終わりの経営の処理だけを走らせる。
  @visibleForTesting
  List<String> debugSettleAiClubFinances() => _settleAiClubFinances();
}
