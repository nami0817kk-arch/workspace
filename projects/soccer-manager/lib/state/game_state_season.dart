part of 'game_state.dart';

/// カップ戦(国内/大陸/スーパーカップ)と昇降格・シーズン遷移。
extension GameStateSeason on GameState {
  /// ユーザーの所属ディビジョンに入るチームに、選手がいなければ用意する。
  ///
  /// 他ディビジョンのチームはセーブ容量のために選手データを持たない
  /// (`SaveGame.otherDivisionLeagues`を参照)。順位表と昇降格には強度だけで
  /// 足りるが、ユーザーと同じディビジョンでは`MatchEngine.simulate`が選手
  /// ごとに試合を進めるため、この時点でスカッドが要る。
  ///
  /// 生成されるのは「昇格を勝ち取った実際のスカッド」ではなく、保持していた
  /// 強度に見合う新しい選手たちになる。他ディビジョンの選手を見る画面は
  /// 無いので利用者からは分からないが、内部的には別物になる。
  /// 全クラブに選手を持たせる(自国の全部と、他の4か国の1部)。
  ///
  /// 以前は他の部のクラブを強さの数字だけで保存していた。そういうセーブを
  /// 読んだときは、その強さに合う選手をここで作る。他国の1部が無ければ作り、
  /// 今の国と同じものがあれば外す(別の国のクラブを買い直したとき)。
  void _ensureWorldSquads(SaveGame save) {
    for (final l in save.otherDivisionLeagues) {
      if (l == null) continue;
      _ensureSquadsForActiveTier(l.teams);
    }
    final current = LeagueTheme.values.firstWhere(
      (t) => t.label == save.leagueName,
      orElse: () => LeagueTheme.england,
    );
    save.foreignLeagues.remove(current.name);
    final rng = Random();
    for (final theme in LeagueTheme.values) {
      if (theme == current) continue;
      final existing = save.foreignLeagues[theme.name];
      if (existing != null) {
        _ensureSquadsForActiveTier(existing.teams);
        continue;
      }
      final count = theme.teamsInTier(1);
      final names = NamePool.themedClubNames(theme, count);
      final teams = [
        for (var i = 0; i < count; i++)
          PlayerGenerator.generateSquad(
            id: 'f_${theme.name}_$i',
            name: names[i],
            // 1部の上から下まで(強豪から残留争いまで)の幅を持たせる。
            strengthTier: rollDivisionStrength(1, rng),
          ),
      ];
      for (final t in teams) {
        LineupUtils.autoFill(t);
      }
      save.foreignLeagues[theme.name] = League(
        teams: teams,
        fixtures: const [],
        season: save.league.season,
      );
    }
  }

  void _ensureSquadsForActiveTier(List<Team> teams) {
    for (final t in teams) {
      if (t.players.isNotEmpty) continue;
      // 保持していた強度に合うスカッドを作る。strengthTier にそのまま
      // 渡すと出来上がりが1〜2割弱く、再起動のたびに昇降格で入ってくる
      // クラブが弱くなっていた。壊れたセーブで欠けていた場合に0の
      // スカッドを作らないよう、移行時と同じ範囲に収める。
      final generated = PlayerGenerator.generateSquadWithOverall(
        id: t.id,
        name: t.name,
        targetOverall: (t.retainedOverall ?? 50).clamp(15, 90),
      );
      t.players = generated.players;
      t.retainedOverall = null;
      LineupUtils.autoFill(t);
    }
  }

  Cup? _cupOfType(CupType type) {
    for (final c in _save!.cups) {
      if (c.type == type) return c;
    }
    return null;
  }

  /// 今シーズンの暦(国・シーズン・節数から決まる。保存しない)。
  SeasonCalendar get seasonCalendar => SeasonCalendar.build(
        season: _save!.league.season,
        theme: currentLeagueTheme,
        totalMatchdays: _totalMatchdaysThisSeason,
      );

  /// ゲームの中の今日。試合を消化するとその試合の日に進む。シーズンの
  /// 切り替わりで次のシーズンの7月1日になる。
  DateTime get today => _save!.today ?? _rebuiltToday();

  /// 今日の日付を持たないセーブの今日。最後に消化した節の日、まだ1節も
  /// 消化していなければ、そのシーズンのオフ(7月1日)。
  DateTime _rebuiltToday() {
    final league = _save!.league;
    var lastPlayed = 0;
    for (final f in league.fixtures) {
      if (f.result != null && f.matchday > lastPlayed) lastPlayed = f.matchday;
    }
    if (lastPlayed == 0) return SeasonCalendar.preseasonDate(league.season);
    return seasonCalendar.dateForMatchday(lastPlayed);
  }

  /// 第[matchday]節の日付。
  DateTime dateOfMatchday(int matchday) =>
      seasonCalendar.dateForMatchday(matchday);

  /// 次に消化するリーグ戦の日付。リーグ戦を終えていれば null。
  DateTime? get nextMatchDate {
    final next = _save!.league.nextUnplayedFixture;
    return next == null ? null : dateOfMatchday(next.matchday);
  }

  /// 今日を[day]へ進める。戻すことはしない(同じ日・前の日なら何もしない)。
  void _advanceTodayTo(DateTime day) {
    final d = SeasonCalendar.dateOnly(day);
    if (d.isAfter(today)) _setToday(d);
  }

  /// 今日を[day]にする。進んだあいだに窓が開いた・締切を過ぎたら、
  /// 登録の名簿をそれに合わせる。
  void _setToday(DateTime day) {
    final before = today;
    final d = SeasonCalendar.dateOnly(day);
    _save!.today = d;
    if (!d.isAfter(before)) return;
    // 仮契約の解禁(1月1日)・延長オプションの期限(3月31日)。
    _onContractDatesAdvanced(before, d);
    // 給与の月末・放映権の入金日。
    _settleMoneyDates(before, d);
    final theme = currentLeagueTheme;
    // 窓が開いたら、名簿の外だった選手もまた登録できる。
    if (TransferWindowCalendar.openedBetween(before, d, theme)) {
      _reopenRegistration();
    }
    // 締切を過ぎて今は閉じていれば、名簿を締める。
    if (TransferWindowCalendar.deadlinePassedBetween(before, d, theme) &&
        !TransferWindowCalendar.isOpen(d, theme)) {
      _closeRegistration();
    }
  }

  /// 締切で登録の名簿を締める。枠を超えていなければ何もしない。
  /// 外れた選手は次の窓が開くまで公式戦に出られない。
  void _closeRegistration() {
    final team = userTeam;
    final excluded = SquadRegistration.plannedExclusions(team);
    if (excluded.isEmpty) return;
    for (final p in excluded) {
      p.notRegistered = true;
      team.startingXI.remove(p.id);
    }
    LineupUtils.fillVacancies(team);
    _logNews(
      Tr.pick(
          '移籍の締切で登録の名簿を締めました。次の窓まで公式戦に出られない選手: ${excluded.map((p) => p.name).join('、')}',
          'The squad list was locked at the deadline. Not eligible until the next window: ${excluded.map((p) => p.name).join(', ')}'),
      context: Tr.pick('選手登録', 'Registration'),
    );
  }

  /// 窓が開いたので、名簿の外だった選手を戻す。
  void _reopenRegistration() {
    for (final p in userTeam.players) {
      p.notRegistered = false;
      p.leaveOffRegistration = false;
    }
  }

  /// 締切の名簿から外すかを切り替える(枠を超えているときだけ効く)。
  Future<void> setLeaveOffRegistration(String playerId, bool leaveOff) async {
    if (_save == null) return;
    final p = userTeam.players.where((p) => p.id == playerId).firstOrNull;
    if (p == null) return;
    p.leaveOffRegistration = leaveOff;
    _notify();
    await _persist();
  }

  /// 締切で名簿から外れる予定の選手(枠を超えていなければ空)。
  List<Player> get plannedRegistrationExclusions => _save == null
      ? const []
      : SquadRegistration.plannedExclusions(userTeam);

  /// 日付で終わるローンを片付ける(借りている選手は戻し、貸している選手は
  /// 呼び戻す)。シーズンの切り替わり(7月1日)でも呼ぶ。
  void _settleLoansByDate() {
    final t = today;
    final team = userTeam;
    final ended = team.players
        .where((p) => p.isLoan && p.loanEndDate != null && !t.isBefore(p.loanEndDate!))
        .toList();
    for (final p in ended) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
      _clearPlayerRoleReferences(team, p.id);
    }
    if (ended.isNotEmpty) {
      lastContractExpirations = [
        ...lastContractExpirations,
        ...ended.map((p) => p.name),
      ];
      LineupUtils.fillVacancies(team);
    }
    for (final p in team.players) {
      final until = p.loanedOutUntil;
      if (!p.isLoanedOut || until == null) continue;
      if (!t.isBefore(until)) {
        _returnFromLoan(p);
      } else {
        // 表示用の残り週数を日付に合わせておく。
        final days = TransferWindowCalendar.daysBetween(t, until);
        p.loanedOutWeeksRemaining = max(1, (days / 7).ceil());
      }
    }
  }

  /// 貸していた選手が戻る。
  void _returnFromLoan(Player p) {
    final loanClub = p.loanedOutToClubName;
    p.loanedOutWeeksRemaining = 0;
    p.loanedOutUntil = null;
    p.loanRecallClause = false;
    p.loanedOutToClubName = null;
    lastLoanReturns.add(p.name);
    if (p.loanStartOverall > 0) {
      final delta = p.overall - p.loanStartOverall;
      _logNews(
        Tr.pick(
            '${p.name}が武者修行(${loanClub ?? 'ローン先'})から復帰。総合 ${p.loanStartOverall}→${p.overall}${delta > 0 ? '(+$delta成長)' : ''}',
            "${p.name} is back from his loan at ${loanClub ?? 'his loan club'}. Overall ${p.loanStartOverall}→${p.overall}${delta > 0 ? ' (+$delta)' : ''}"),
        context: Tr.pick('ローン復帰', 'Loan return'),
      );
      p.loanStartOverall = 0;
    }
  }

  /// 旧セーブの週数のローンを日付に直す(今日から週数×7日後)。
  void _migrateLoanDates(SaveGame save) {
    final t = save.today ?? today;
    for (final team in save.league.teams) {
      for (final p in team.players) {
        if (p.isLoan && p.loanEndDate == null && p.loanWeeksRemaining > 0) {
          p.loanEndDate = DateTime(t.year, t.month, t.day + 7 * p.loanWeeksRemaining);
        }
        if (p.isLoanedOut && p.loanedOutUntil == null) {
          p.loanedOutUntil =
              DateTime(t.year, t.month, t.day + 7 * p.loanedOutWeeksRemaining);
        }
      }
    }
  }

  /// 移籍市場から、他の国の18歳未満を外す(国をまたいで移れない)。
  /// どの国から来たかを持たない旧セーブの18歳未満も外す。
  void _dropInternationalMinorsFromMarket(SaveGame save) {
    final home = currentLeagueTheme.name;
    save.transferMarketPlayers.removeWhere(
        (p) => p.age < 18 && (p.originLeague == null || p.originLeague != home));
  }

  /// いま消化するカップ戦の日付へ今日を進める。リーグ戦の途中なら次の
  /// 節の前の平日、リーグ戦を終えた後(オフ)なら今日の次の平日。
  void _advanceTodayForCup({required bool continental}) {
    if (_save!.league.nextUnplayedFixture == null) {
      _advanceTodayTo(
          SeasonCalendar.nextCupWeekdayAfter(today, continental: continental));
      return;
    }
    _advanceTodayTo(seasonCalendar.cupDateBefore(
        _currentLeagueMatchdayMarker,
        continental: continental));
  }

  Cup? get domesticCup => _save == null ? null : _cupOfType(CupType.domestic);

  /// 大陸カップ(グループステージ+決勝トーナメント)。出場資格がない間はnull。
  ContinentalCup? get continentalCup => _save?.continentalCup;

  /// 前シーズンの最終順位に基づき、来季の大陸カップ出場資格があるか。
  bool get qualifiedForContinentalCup => (_save?.lastSeasonRank ?? 99) <= 2;

  /// 国内カップ戦で、ブラケット全体の中で次に消化されるべき試合が自クラブの
  /// 試合であるかどうか。日程画面・ホーム画面から「カップ戦の順番が来ている」
  /// ことに気づけるようにするためのフラグ。
  bool get isUserDomesticCupMatchUpNext {
    final match = domesticCup?.nextUnplayedMatch;
    if (match == null || _save == null) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// リーグの現在の節番号(シーズン終了後は最終節+1)。カップ戦の消化間隔
  /// (現実の試合間隔の再現)を判定する基準として使う。
  int get _currentLeagueMatchdayMarker {
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    return nextMd ?? (_totalMatchdaysThisSeason + 1);
  }

  bool _canAdvanceCup(int? lastPlayedAtMatchday) {
    if (_save == null) return false;
    // リーグ戦が全節消化済み(オフシーズン)の間は、もう間隔を置く相手がいない
    // ため無制限に消化できる。そうしないと、リーグ完了後に残ったカップ戦は
    // 節数が二度と進まず永久に足止めされてしまう。
    if (_save!.league.nextUnplayedFixture == null) return true;
    return lastPlayedAtMatchday == null ||
        _currentLeagueMatchdayMarker > lastPlayedAtMatchday;
  }

  /// 国内カップ戦の次の試合を消化できるか。直前の消化からリーグが1節も
  /// 進んでいない場合は、現実の試合間隔を再現するためfalseになる。
  bool get canPlayNextDomesticCupMatch =>
      domesticCup?.nextUnplayedMatch != null &&
      _canAdvanceCup(domesticCup!.lastPlayedAtMatchday);

  Future<MatchResult?> playNextCupMatch() async {
    if (_save == null) return null;
    final cup = domesticCup;
    if (cup == null || cup.nextUnplayedMatch == null) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;

    final match = cup.nextUnplayedMatch!;
    if (!match.isBye) {
      final home = allTeamsForCups.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeamsForCups.firstWhere((t) => t.id == match.awayTeamId);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = CupEngine.playNextMatch(cup, allTeamsForCups);
    _advanceTodayForCup(continental: false);
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null) {
      _applyUserCupPostMatchEffects(result);
      _afterDomesticCupMatchApplied(match);
    }
    _notify();
    await _persistNow();
    return result;
  }

  /// 大陸カップに次に消化すべき試合(グループステージ、または決勝
  /// トーナメント)が残っているか。
  bool _continentalHasNextMatch(ContinentalCup cup) {
    if (!cup.isGroupStageComplete) {
      return ContinentalCupEngine.nextGroupMatch(cup) != null;
    }
    return cup.knockoutRounds.isNotEmpty &&
        cup.knockoutRounds.last.any((t) => !t.isComplete);
  }

  /// 大陸カップの次の試合を消化できるか。直前の消化からリーグが1節も
  /// 進んでいない場合は、現実の試合間隔を再現するためfalseになる。
  bool get canPlayNextContinentalMatch {
    final cup = _save?.continentalCup;
    if (cup == null || !_continentalHasNextMatch(cup)) return false;
    return _canAdvanceCup(cup.lastPlayedAtMatchday);
  }

  /// 大陸カップのグループステージ次の1試合を消化する。全組が終わると
  /// 自動的に決勝トーナメントの組み合わせが決定される。
  Future<MatchResult?> playNextContinentalGroupMatch() async {
    if (_save == null || _save!.continentalCup == null) return null;
    final cup = _save!.continentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final match = ContinentalCupEngine.nextGroupMatch(cup);
    if (match != null) {
      final home = allTeamsForCups.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeamsForCups.firstWhere((t) => t.id == match.awayTeamId);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = ContinentalCupEngine.playNextGroupMatch(
      cup,
      allTeamsForCups,
    );
    _advanceTodayForCup(continental: true);
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null && match != null) {
      _applyUserCupPostMatchEffects(result);
      _afterContinentalGroupMatchApplied(match);
    }
    _notify();
    await _persistNow();
    return result;
  }

  /// 大陸カップの決勝トーナメント次の1レグを消化する。
  Future<MatchResult?> playNextContinentalKnockoutLeg() async {
    if (_save == null || _save!.continentalCup == null) return null;
    final cup = _save!.continentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final leg = ContinentalCupEngine.nextKnockoutLeg(cup);
    if (leg != null) {
      final home = allTeamsForCups.firstWhere((t) => t.id == leg.homeId);
      final away = allTeamsForCups.firstWhere((t) => t.id == leg.awayId);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = ContinentalCupEngine.playNextKnockoutLeg(
      cup,
      allTeamsForCups,
    );
    _advanceTodayForCup(continental: true);
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null && leg != null) {
      _applyUserCupPostMatchEffects(result);
      _afterContinentalKnockoutLegApplied(leg.tie);
    }
    _notify();
    await _persistNow();
    return result;
  }

  /// 新シーズン開幕前のスーパーカップ(ユーザークラブが出場する場合のみ保留される)。
  CupMatch? get pendingSuperCup => _save?.pendingSuperCup;

  /// 保留中のスーパーカップを消化する。ユーザークラブが出場する場合のみ有効。
  Future<MatchResult?> playSuperCup() async {
    if (_save == null || _save!.pendingSuperCup == null) return null;
    final match = _save!.pendingSuperCup!;
    final teams = _save!.allTeams;
    final home = teams.firstWhere((t) => t.id == match.homeTeamId);
    final away = teams.firstWhere((t) => t.id == match.awayTeamId);
    // 相手が別ディビジョンのクラブだと、再起動後は選手を持っていない。
    _ensureSquadsForActiveTier([home, away]);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: 0,
      weather: WeatherEngine.roll(),
    );
    match.result = result;
    if (result.homeGoals == result.awayGoals) {
      match.penaltyWinnerId = CupEngine.decidePenaltyWinner(home, away);
    }
    _applyUserCupPostMatchEffects(result);
    _afterSuperCupApplied(match);
    _notify();
    await _persistNow();
    return result;
  }

  bool get _isLiveMatchInProgress =>
      _liveFixture != null || _liveCupKind != null;

  /// 次の国内カップ未消化試合が自クラブの試合で、今すぐライブ観戦で
  /// 戦えるか(消化間隔・他のライブ試合との競合も考慮)。
  bool get canPlayNextDomesticCupMatchLive {
    if (_save == null || _isLiveMatchInProgress) return false;
    if (!canPlayNextDomesticCupMatch) return false;
    final match = domesticCup?.nextUnplayedMatch;
    if (match == null || match.isBye) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// 次の大陸カップの試合(グループまたは決勝トーナメント)が自クラブの
  /// 試合で、今すぐライブ観戦で戦えるか。
  bool get canPlayNextContinentalMatchLive {
    if (_save == null || _isLiveMatchInProgress) return false;
    if (!canPlayNextContinentalMatch) return false;
    final cup = _save!.continentalCup!;
    final userId = _save!.userTeamId;
    if (!cup.isGroupStageComplete) {
      final match = ContinentalCupEngine.nextGroupMatch(cup);
      return match != null &&
          (match.homeTeamId == userId || match.awayTeamId == userId);
    }
    final leg = ContinentalCupEngine.nextKnockoutLeg(cup);
    return leg != null && (leg.homeId == userId || leg.awayId == userId);
  }

  /// 保留中のスーパーカップをライブ観戦で戦えるか。
  bool get canPlaySuperCupLive {
    if (_save == null || _isLiveMatchInProgress) return false;
    final match = _save!.pendingSuperCup;
    if (match == null) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// 自クラブのカップ試合をライブ観戦で開始する。開始できた場合、以降は
  /// リーグ戦のライブ観戦と同じAPI([pendingChanceDecision] /
  /// [resolveChanceDecision] / [playSecondHalf] / [makeLiveSubstitution] /
  /// [setMatchInstruction]等)で進行し、後半完了時に結果が該当大会へ
  /// 適用される(引き分け時のPK戦・賞金・敗退時の信頼度低下を含む)。
  /// [kind]に大陸カップを渡した場合は、現在の進行状況に応じてグループ/
  /// 決勝トーナメントを自動で選び分ける。開始できない場合はfalse。
  Future<bool> startCupMatchLive(LiveCupKind kind) async {
    if (_save == null || _isLiveMatchInProgress) return false;
    final userId = _save!.userTeamId;
    Team? home;
    Team? away;
    CupMatch? cupMatch;
    CupTie? tie;
    var resolvedKind = kind;
    switch (kind) {
      case LiveCupKind.domestic:
        if (!canPlayNextDomesticCupMatchLive) return false;
        cupMatch = domesticCup!.nextUnplayedMatch;
        home = teamById(cupMatch!.homeTeamId);
        away = teamById(cupMatch.awayTeamId);
      case LiveCupKind.continentalGroup:
      case LiveCupKind.continentalKnockout:
        if (!canPlayNextContinentalMatchLive) return false;
        final cup = _save!.continentalCup!;
        if (!cup.isGroupStageComplete) {
          resolvedKind = LiveCupKind.continentalGroup;
          cupMatch = ContinentalCupEngine.nextGroupMatch(cup);
          home = teamById(cupMatch!.homeTeamId);
          away = teamById(cupMatch.awayTeamId);
        } else {
          resolvedKind = LiveCupKind.continentalKnockout;
          final leg = ContinentalCupEngine.nextKnockoutLeg(cup)!;
          tie = leg.tie;
          home = teamById(leg.homeId);
          away = teamById(leg.awayId);
        }
      case LiveCupKind.superCup:
        if (!canPlaySuperCupLive) return false;
        cupMatch = _save!.pendingSuperCup;
        home = teamById(cupMatch!.homeTeamId);
        away = teamById(cupMatch.awayTeamId);
    }
    if (home == null || away == null) return false;
    // スーパーカップの相手は別ディビジョンのことがあり、そのクラブは
    // 再起動後に選手を持っていない(保存しないため)。0人では試合にならない。
    _ensureSquadsForActiveTier([home, away]);
    final weather = WeatherEngine.roll();
    _liveCupKind = resolvedKind;
    _liveCupHome = home;
    _liveCupAway = away;
    _liveCupWeather = weather;
    _liveCupMatch = cupMatch;
    _liveCupTie = tie;
    _liveSubstitutionsUsed = 0;
    lastCupPrizeNote = null;
    _liveWasInteractive = true; // カップのライブ観戦は常に決定機の判断あり
    _liveFirstHalfState = MatchEngine.beginInteractiveHalf(
      home: home,
      away: away,
      startMinute: 1,
      endMinute: 45,
      interactiveTeamId: userId,
      weather: weather,
      homeAdvantageFactor: _homeAdvantageFor(home.id),
    );
    _notify();
    await _persistNow();
    return true;
  }

  /// ライブ観戦で確定したカップ試合の結果を、該当大会へ適用する
  /// (試合後効果は_finalizeSecondHalfの共通処理で適用済みのため行わない)。
  void _applyLiveCupResult(MatchResult merged) {
    final kind = _liveCupKind;
    if (kind == null || _save == null) return;
    switch (kind) {
      case LiveCupKind.domestic:
        final cup = domesticCup;
        final match = _liveCupMatch;
        if (cup == null || match == null) return;
        if (merged.homeGoals == merged.awayGoals) {
          match.penaltyWinnerId = _runLiveShootout().winnerId;
        }
        CupEngine.applyMatchResult(cup, allTeamsForCups, match, merged);
        _advanceTodayForCup(continental: false);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterDomesticCupMatchApplied(match);
      case LiveCupKind.continentalGroup:
        final cup = _save!.continentalCup;
        final match = _liveCupMatch;
        if (cup == null || match == null) return;
        ContinentalCupEngine.applyGroupMatchResult(
            cup, allTeamsForCups, match, merged);
        _advanceTodayForCup(continental: true);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterContinentalGroupMatchApplied(match);
      case LiveCupKind.continentalKnockout:
        final cup = _save!.continentalCup;
        final tie = _liveCupTie;
        if (cup == null || tie == null) return;
        // このレグでタイが完了し、合計スコアが同点になる場合のみPK戦。
        if (tie.legs.length + 1 >= tie.totalLegs) {
          final mergedForA = merged.homeTeamId == tie.teamAId
              ? merged.homeGoals
              : merged.awayGoals;
          final mergedForB = merged.homeTeamId == tie.teamBId
              ? merged.homeGoals
              : merged.awayGoals;
          if (tie.goalsFor(tie.teamAId) + mergedForA ==
              tie.goalsFor(tie.teamBId) + mergedForB) {
            tie.penaltyWinnerId = _runLiveShootout().winnerId;
          }
        }
        ContinentalCupEngine.applyKnockoutLegResult(
            cup, allTeamsForCups, tie, merged);
        _advanceTodayForCup(continental: true);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterContinentalKnockoutLegApplied(tie);
      case LiveCupKind.superCup:
        final match = _liveCupMatch;
        if (match == null) return;
        match.result = merged;
        if (merged.homeGoals == merged.awayGoals) {
          match.penaltyWinnerId = _runLiveShootout().winnerId;
        }
        _afterSuperCupApplied(match);
    }
    _evaluateAchievements();
  }

  /// ライブ観戦のカップ戦がPK戦にもつれた際、1本ずつのシュートアウトを
  /// 実施して勝者を決める。記録は[_lastShootout]に保持し、フルタイム画面が
  /// 1本ごとの成否を演出表示する。自クラブが勝てばPK戦勝利数も記録する。
  PenaltyShootoutResult _runLiveShootout() {
    final shootout = CupEngine.simulateShootout(_liveCupHome!, _liveCupAway!);
    if (shootout.winnerId == _save!.userTeamId) {
      _save!.pkShootoutWins++;
    }
    return shootout;
  }

  /// 自クラブが関わるカップ試合に、リーグ戦と同じ試合後効果(疲労・負傷・
  /// 警告累積・通算出場/得点の記録など)を適用する。カップ戦でも
  /// ローテーションが意味を持つようにするための共通処理で、自動消化の
  /// 経路から呼ぶ(ライブ観戦の経路では確定処理側で適用済み)。
  void _applyUserCupPostMatchEffects(MatchResult result) {
    if (_save == null) return;
    final userId = _save!.userTeamId;
    if (result.homeTeamId != userId && result.awayTeamId != userId) return;
    final home = teamById(result.homeTeamId);
    final away = teamById(result.awayTeamId);
    if (home == null || away == null) return;
    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: _injuryFactorFor(home.id),
      awayInjuryFactor: _injuryFactorFor(away.id),
      events: result.events,
      weather: result.weather,
    );
  }

  /// 国内カップのブラケット全ラウンド数(1回戦から決勝まで)。
  int _domesticCupTotalRounds(Cup cup) {
    final firstRoundMatches = cup.rounds.first.length;
    if (firstRoundMatches <= 0) return 0;
    return (log(firstRoundMatches * 2) / ln2).round();
  }

  /// 理事会が期待する国内カップの到達ラウンドを、リーグ内の戦力順位から
  /// 見積もる(国内カップが未生成なら0=期待なし)。
  int _estimateDomesticCupTarget() {
    final cup = domesticCup;
    if (cup == null || _save == null) return 0;
    final teams = [..._save!.league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final rank = teams.indexWhere((t) => t.id == _save!.userTeamId) + 1;
    if (rank <= 0) return 0;
    return BoardEngine.estimateCupTargetRound(
      strengthRank: rank,
      teamCount: teams.length,
      totalRounds: _domesticCupTotalRounds(cup),
    );
  }

  /// 理事会のカップ目標の表示ラベル(例: 「準決勝」)。未設定ならnull。
  String? get boardCupTargetLabel {
    final cup = domesticCup;
    final target = _save?.boardCupTargetRound ?? 0;
    if (cup == null || target <= 0) return null;
    return CupEngine.roundLabel(target, _domesticCupTotalRounds(cup));
  }

  /// 国内カップの1試合が大会へ適用された後の共通処理(自動消化・ライブ
  /// 共通)。自クラブの勝利賞金・敗退時の信頼度低下・優勝報酬を扱う。
  void _afterDomesticCupMatchApplied(CupMatch match) {
    final cup = domesticCup;
    if (cup == null || _save == null) return;
    final userId = _save!.userTeamId;
    final userInvolved =
        match.homeTeamId == userId || match.awayTeamId == userId;
    if (userInvolved) {
      if (match.winnerId == userId) {
        final prize = scaledMoney(GameState.domesticCupWinPrizeFor(match.round));
        _book(LedgerCategory.prize, prize);
        _save!.careerCupPrize += prize;
        lastCupPrizeNote = Tr.pick('勝利賞金として${formatMoney(prize)}を獲得!',
            'You collected ${formatMoney(prize)} in prize money!');
        _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
      } else if (cup.isEliminated(userId)) {
        // 理事会のカップ目標(到達ラウンド)と実際の成績を突き合わせる。
        final reached = match.round;
        final target = _save!.boardCupTargetRound;
        final label = boardCupTargetLabel;
        if (target > 0 && reached >= target) {
          _save!.confidence = (_save!.confidence + 2).clamp(0, 100);
          _logNews(
              Tr.pick('国内カップは理事会の期待($label進出)に応えた。敗退したが評価は上々だ',
                  "You met the board's expectation in the domestic cup (reaching the $label). You are out, but they are pleased"),
              context: Tr.pick('カップ戦', 'Cup'));
        } else if (target > 0 && target - reached >= 2) {
          _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
          _logNews(
              Tr.pick('国内カップで早期敗退。理事会の期待($label進出)を大きく裏切った',
                  "An early exit from the domestic cup, well short of the board's expectation of the $label"),
              context: Tr.pick('カップ戦', 'Cup'));
        } else {
          _save!.confidence = (_save!.confidence - 1).clamp(0, 100);
        }
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final reward = scaledMoney(GameState.domesticCupChampionPrize);
      _book(LedgerCategory.prize, reward);
      _save!.careerCupPrize += reward;
      _save!.confidence = (_save!.confidence + 10).clamp(0, 100);
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${_save!.league.season}: ${cup.name} 優勝',
          'Season ${_save!.league.season}: ${cup.name} winners'));
    }
  }

  /// 大陸カップのグループステージ1試合が適用された後の共通処理。
  void _afterContinentalGroupMatchApplied(CupMatch match) {
    final cup = _save?.continentalCup;
    if (cup == null) return;
    final userId = _save!.userTeamId;
    final userInvolved =
        match.homeTeamId == userId || match.awayTeamId == userId;
    if (!userInvolved) return;
    final r = match.result;
    final userWon = r != null &&
        ((r.homeTeamId == userId && r.homeGoals > r.awayGoals) ||
            (r.awayTeamId == userId && r.awayGoals > r.homeGoals));
    if (userWon) {
      final prize = scaledMoney(GameState.continentalGroupWinPrize);
      _book(LedgerCategory.prize, prize);
      _save!.careerCupPrize += prize;
      lastCupPrizeNote = Tr.pick('勝利賞金として${formatMoney(prize)}を獲得!',
          'You collected ${formatMoney(prize)} in prize money!');
      _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
    }
    if (cup.isEliminated(userId)) {
      _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
    }
  }

  /// 大陸カップの決勝トーナメント1レグが適用された後の共通処理。
  void _afterContinentalKnockoutLegApplied(CupTie tie) {
    final cup = _save?.continentalCup;
    if (cup == null) return;
    final userId = _save!.userTeamId;
    final userInTie = tie.teamAId == userId || tie.teamBId == userId;
    if (userInTie) {
      if (tie.isComplete && tie.winnerId == userId) {
        final prize = scaledMoney(GameState.continentalTieWinPrize);
        _book(LedgerCategory.prize, prize);
        _save!.careerCupPrize += prize;
        lastCupPrizeNote = Tr.pick('勝ち上がり賞金として${formatMoney(prize)}を獲得!',
            'You collected ${formatMoney(prize)} for going through!');
        _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
      }
      if (cup.isEliminated(userId)) {
        _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final reward = scaledMoney(GameState.continentalChampionPrize);
      _book(LedgerCategory.prize, reward);
      _save!.careerCupPrize += reward;
      _save!.confidence = (_save!.confidence + 20).clamp(0, 100);
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${_save!.league.season}: ${cup.name} 優勝',
          'Season ${_save!.league.season}: ${cup.name} winners'));
    }
  }

  /// スーパーカップの結果が確定した後の共通処理。
  void _afterSuperCupApplied(CupMatch match) {
    if (_save == null) return;
    _advanceTodayTo(seasonCalendar.superCupDate);
    if (match.winnerId == _save!.userTeamId) {
      _save!.trophyHistory.add(Tr.pick('シーズン${_save!.league.season} スーパーカップ優勝',
          'Season ${_save!.league.season} Super Cup winners'));
    }
    _save!.pendingSuperCup = null;
  }

  /// 大陸カップに参加する海外クラブ名を生成する。5つの国風テーマから
  /// バランスよく取り混ぜることで、実際の大陸カップのように様々な国風の
  /// クラブが顔をそろえるようにする(自国リーグと同じ命名規則を流用しつつ、
  /// テーマを散らして「他国のクラブ」らしさを出す)。
  List<Team> _generateContinentalTeams() {
    final rng = Random();
    const totalTeams = 7;
    final themes = List<LeagueTheme>.from(LeagueTheme.values)..shuffle(rng);
    final names = <String>[];
    var remaining = totalTeams;
    for (int i = 0; i < themes.length && remaining > 0; i++) {
      final take = (remaining / (themes.length - i)).ceil();
      names.addAll(NamePool.themedClubNames(themes[i], take));
      remaining -= take;
    }
    final teams = <Team>[];
    for (int i = 0; i < totalTeams; i++) {
      final t = PlayerGenerator.generateSquad(
        id: 'continental$i',
        name: names[i],
        strengthTier: 65 + rng.nextInt(20),
      );
      LineupUtils.autoFill(t);
      teams.add(t);
    }
    return teams;
  }

  /// シーズンの振り返りを見せ終えたことを覚える。閉じたら二度と出さない。
  void markSeasonReviewSeen() {
    if (_save == null || _save!.seasonHistory.isEmpty) return;
    _save!.lastReviewedSeason = _save!.seasonHistory.last.season;
    _notify();
    _persist();
  }

  Future<void> startNextSeason() async {
    if (_save == null) return;
    // 二重に呼ばれると、賞金・理事会の報奨金・昇格ボーナスがもう一度
    // 支払われ、シーズンも2つ進む。ボタンは isBusy の覆いで塞がるが、
    // 覆いが描かれるのは次のフレームなので、その前の連打は素通りする。
    // playNextMatchday には同じ理由の防止が入っている。
    if (isBusy) return;
    isBusy = true;
    _notify();
    try {
      await _rollSeasonOver();
    } catch (_) {
      // 途中で落ちたら覆いを外しておく。外さないと上の多重実行の防止に
      // 引っかかり続け、二度と次のシーズンへ進めなくなる。
      isBusy = false;
      _notify();
      rethrow;
    }
  }

  Future<void> _rollSeasonOver() async {
    // ローディング表示を1フレーム描画させてから、裏ディビジョンの1シーズン分の
    // シミュレーションなど重い処理に入る。
    await Future<void>.delayed(Duration.zero);
    final league = _save!.league;
    // 会計年度の終わり(6月30日)まで日を進める。5・6月の給与は、この季の
    // 年度の記録に入る(7月1日からが次の年度)。
    _advanceTodayTo(MoneyCalendar.fiscalYearEnd(league.season));
    final standings = league.sortedStandings;
    final finalRank =
        standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final playedOrder = standings
        .map((r) => league.teams.firstWhere((t) => t.id == r.teamId))
        .toList();
    final playedTier = _save!.currentDivisionTier;

    // シーズン開始時点の総合力からの成長を選手ごとに算出し、シーズン終了時に
    // 一覧表示できるようにする。
    final previousOverallSnapshot = _save!.seasonStartOverallByPlayerId;
    lastSeasonGrowthSummary = [
      for (final p in userTeam.players)
        if (previousOverallSnapshot.containsKey(p.id))
          PlayerGrowthSummary(
            playerId: p.id,
            playerName: p.name,
            overallBefore: previousOverallSnapshot[p.id]!,
            overallAfter: p.overall,
            attributeDeltas: const {},
          ),
    ];

    _save!.seasonAwards.add(AwardsEngine.computeAwards(league, league.season));
    _save!.bestElevenHistory.add(
      BestElevenEngine.compute(league, league.season),
    );

    // 監督としての通算成績を更新する。
    final userRow = standings.firstWhere((r) => r.teamId == _save!.userTeamId);
    _save!.careerWins += userRow.won;
    _save!.careerDraws += userRow.draw;
    _save!.careerLosses += userRow.lost;
    _save!.careerSeasons += 1;
    if (finalRank == 1) {
      final divisionLabel = playedTier == 1
          ? _save!.leagueName
          : Tr.pick('${_save!.leagueName}($playedTier部)',
              '${_save!.leagueName} (tier $playedTier)');
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${league.season}: $divisionLabel 優勝',
          'Season ${league.season}: $divisionLabel champions'));
    }

    // 年間最優秀監督賞: 総合力から見た期待順位を最も上回ったクラブに贈られる。
    lastSeasonManagerAwardWon = false;
    if (AwardsEngine.computeManagerOfSeason(league) == userTeam.name) {
      _save!.trophyHistory.add(Tr.pick('シーズン${league.season} 年間最優秀監督賞',
          'Season ${league.season} Manager of the Year'));
      lastSeasonManagerAwardWon = true;
    }

    // 下位ディビジョンほど観客動員・賞金が少ない(ティアごとに段階的に低下する)。
    var prizeMoney = BoardEngine.seasonPrizeMoney(
      finalRank: finalRank,
      teamCount: league.teams.length,
    );
    // 5部の額(1部の額の0.6^4)を、戦った部の規模に直す。
    prizeMoney = scaledMoneyFor(playedTier, (prizeMoney * pow(0.6, 4)).round());
    _book(LedgerCategory.prize, prizeMoney);
    _bookTvRights(finalRank: finalRank, teamCount: league.teams.length);
    final confidenceDelta = BoardEngine.confidenceDeltaForSeasonEnd(
      finalRank: finalRank,
      targetRank: _save!.boardTargetRank,
    );
    _save!.confidence = (_save!.confidence + confidenceDelta).clamp(0, 100);
    // 期待への慣れ。勝ち続けるうちにサポーターの目は肥え、満点に張り付いた
    // ままだと緊張が無くなる(放置3シーズンの実測で94〜97に張り付いた)。
    _save!.confidence = BoardEngine.afterAdaptation(_save!.confidence);

    // 理事会の路線。1年を通して守れていたかを、ここで一度だけ評価する。
    final visionDelta = BoardEngine.confidenceDeltaForVisionSeason(
      vision: _save!.clubVision,
      compliedMatchdays: _save!.visionCompliedMatchdays,
      checkedMatchdays: _save!.visionCheckedMatchdays,
    );
    if (visionDelta != 0) {
      // 「堅実な経営」の路線は収支の評価なので株主の期待へ、それ以外は信頼度へ。
      if (_save!.clubVision == ClubVision.financialProudence) {
        _save!.shareholderExpectation = ShareholderEngine.applied(
            _save!.shareholderExpectation, visionDelta);
      } else {
        _save!.confidence = (_save!.confidence + visionDelta).clamp(0, 100);
      }
      _logNews(
        visionDelta > 0
            ? Tr.pick('理事会: 今季は「${_save!.clubVision.label}」の路線に沿っていたと評価されました。',
                'The board is satisfied you followed the "${_save!.clubVision.label}" direction.')
            : Tr.pick('理事会: 今季は「${_save!.clubVision.label}」の路線に沿えていなかったと見られています。',
                'The board feels you did not follow the "${_save!.clubVision.label}" direction.'),
        context: Tr.pick('理事会', 'Board'),
      );
    }

    // 株主の期待: 黒字でシーズンを終えれば上がり、赤字なら下がる。
    _save!.shareholderExpectation = ShareholderEngine.applied(
      _save!.shareholderExpectation,
      ShareholderEngine.deltaForSeasonEnd(
            budget: _save!.budget,
            profit: _save!.ledgerFor(_save!.league.season).profit,
            operatingIncome:
                _save!.ledgerFor(_save!.league.season).operatingIncome,
            wageRatio: _save!.ledgerFor(_save!.league.season).wageRatio,
          ) +
          BudgetEngine.dividendExpectationDelta(_save!.budgetPlan),
    );

    // 理事会の目標達成報奨金: シーズン目標順位を達成すると、リーグ賞金と
    // 同じティア係数で減衰する報奨金が理事会から支給される。目標を大きく
    // 上回った場合(3つ以上)は1.5倍に増額し、快挙をしっかり報いる。
    lastBoardBonusNote = null;
    if (finalRank <= _save!.boardTargetRank) {
      var bonus = scaledMoneyFor(playedTier, (300 * pow(0.6, 4)).round());
      final exceeded = _save!.boardTargetRank - finalRank >= 3;
      if (exceeded) bonus = (bonus * 1.5).round();
      _book(LedgerCategory.prize, bonus);
      lastBoardBonusNote = exceeded
          ? Tr.pick('理事会目標を大きく上回り、報奨金${formatMoney(bonus)}が支給されました!',
              "You beat the board's target comfortably, and they have paid you a ${formatMoney(bonus)} bonus!")
          : Tr.pick('理事会目標を達成し、報奨金${formatMoney(bonus)}が支給されました!',
              "You met the board's target, and they have paid you a ${formatMoney(bonus)} bonus!");
    }

    _settlePartnerClub();

    // 国の財務規則(収支規則・ライセンス)の判定。違反なら罰を科す。
    _enforceLeagueRules();
    _holdShareholdersMeeting();
    _resolveSeasonRisks();
    _tickProjects();
    _settleAdvisors();
    _save!.declinedProposalIds.clear();
    _recordClubValue();
    _scoreClubPolicy(finalRank: finalRank);
    _advanceEconomy();

    // 監督契約(任期)の更新。旧セーブ(0=未導入)はまず2年契約を結ぶ。
    lastManagerContractNote = null;
    if (_save!.managerContractYears <= 0) {
      _save!.managerContractYears = 2;
      lastManagerContractNote = Tr.pick(
          '理事会と2年の監督契約を結んだ', 'You signed a two-year contract with the board');
    } else {
      final outcome = BoardEngine.managerContractAfterSeason(
        yearsRemaining: _save!.managerContractYears,
        targetMet: finalRank <= _save!.boardTargetRank,
        confidence: _save!.confidence,
      );
      _save!.managerContractYears = outcome.years;
      switch (outcome.event) {
        case ManagerContractEvent.extended:
          lastManagerContractNote = Tr.pick('目標達成が評価され、監督契約が3年に延長された!',
              'They liked what they saw, and your contract has been extended to three years!');
        case ManagerContractEvent.renewedOneYear:
          lastManagerContractNote = Tr.pick('契約満了。理事会は単年契約での続投を提示し、受け入れた',
              'Your contract expired. The board offered a one-year extension, and you took it');
        case ManagerContractEvent.finalYearWarning:
          lastManagerContractNote = Tr.pick('監督契約は残り1年。今シーズンの成績が去就を左右する',
              'One year left on your contract. This season decides your future');
        case ManagerContractEvent.dismissed:
          // 契約非更新=解任。既存の解任フロー(信頼度0)に合流させる。
          _save!.confidence = 0;
          lastManagerContractNote = Tr.pick('成績不振により契約は更新されなかった(解任)',
              'Results were not good enough, and your contract was not renewed (sacked)');
        case ManagerContractEvent.none:
          break;
      }
    }

    // ここから先は新しいシーズン(7月1日)として契約を数える。引退の補充で
    // 作る選手の満了の年も、新しいシーズンから数える。
    Player.contractClockYear = Player.seasonEndYearOf(league.season + 1);

    // 自クラブの部の外(他の部・他国)の選手は練習で育たないので、年に1度
    // 年齢に合わせて伸ばし、衰えさせる。
    final activeIds = _save!.league.teams.map((t) => t.id).toSet();
    final offscreenRng = Random();
    for (final l in _save!.foreignLeagues.values) {
      for (final t in l.teams) {
        for (final p in t.players) {
          p.age += 1;
          OffscreenDevelopment.apply(p, offscreenRng);
        }
        RetirementEngine.resolveAndReplaceForCpu(t);
      }
    }
    for (final t in _save!.allTeams) {
      for (final p in t.players) {
        p.age += 1;
        if (!activeIds.contains(t.id)) {
          OffscreenDevelopment.apply(p, offscreenRng);
        }
      }
      // CPUクラブは自クラブ(userTeam、下でRetirementEngine.resolveRetirements
      // を個別に呼ぶ)と違って移籍市場で世代交代しないため、ここで代わりに
      // 引退+若手補充を行う。行わないと選手が永遠に加齢し続けてしまう。
      if (t.id != _save!.userTeamId) {
        RetirementEngine.resolveAndReplaceForCpu(t);
      }
    }
    final infra = _save!.infrastructure;
    // ユースインテーク: 複数候補を一括生成し、選抜はユーザーに委ねる。
    final intakeCount = 3 + Random().nextInt(3);
    // 育成予算の効き。蓄積は毎季末にいまの配分へ近づき、受け入れの質に返る。
    _save!.youthMomentum = YouthInvestmentEngine.nextMomentum(
      momentum: _save!.youthMomentum,
      ratio: BudgetEngine.ratio(_save!.budgetPlan, BudgetCategory.youth),
    );
    final investmentBonus =
        YouthInvestmentEngine.qualityBonus(_save!.youthMomentum);
    // 施設予算の効きも同じ仕組みで、もっとゆっくり蓄積する。
    _save!.facilityMomentum = FacilityInvestmentEngine.nextMomentum(
      momentum: _save!.facilityMomentum,
      ratio: BudgetEngine.ratio(_save!.budgetPlan, BudgetCategory.facilities),
    );
    _save!.pendingYouthIntake = List.generate(
      intakeCount,
      (_) => ScoutingEngine.generateAcademyGraduate(
        // 有望な子を見つけてこられるかは見極めの仕事。
        youthCoachLevel: infra.staffAttributeLevel(
            StaffRole.youthCoach, StaffAttribute.judging),
        investmentBonus: investmentBonus,
      ),
    );

    // ユースリーグも年度が替わる。前年の順位表を残したままにすると、
    // 何節まで進んだのかも勝点も前の年のものになる。相手の強さも引き直す
    // (こちらが育つのに相手が据え置きだと、年を追うごとに楽になる)。
    _save!.youthLeague = _save!.youthProspects.isEmpty
        ? null
        : YouthLeagueEngine.create(
            prospectAverage:
                YouthLeagueEngine.prospectAverage(_save!.youthProspects),
          );
    // 年間の得点記録も年度ごとに数え直す。
    for (final p in _save!.youthProspects) {
      p.youthMatchApps = 0;
      p.youthMatchGoals = 0;
    }

    // 監督としての世間の評価を更新する(目標達成なら上昇、大きく未達なら下降)。
    if (finalRank <= _save!.boardTargetRank) {
      _save!.managerReputation = (_save!.managerReputation + 8).clamp(0, 100);
    } else if (finalRank > _save!.boardTargetRank + 2) {
      _save!.managerReputation = (_save!.managerReputation - 5).clamp(0, 100);
    }
    // 監督としての就任オファーは出さない(オーナーは別のクラブの監督にならない)。

    // 昇格・降格を解決する。ユーザーの現在ティア以外は節ごとに並行して
    // 消化してきたため、その最終順位順をそのまま使う(改めてシミュレート
    // し直さない)。各境界(1部/2部、2部/3部、…)は隣接ティアの実際の最終
    // 順位のみを根拠に独立して解決する。前の境界の解決結果を次の境界に
    // 連鎖させると、降格してきたばかりのチームがその配列内の並び順の都合で
    // さらに1段降格してしまう(1シーズンで複数ティア移動する)バグになるため、
    // 各ティアの「移動元(outgoing)」「移動先(incoming)」だけを集計し、
    // 最後にまとめて新編成を組み立てる。
    List<Team> orderedTeamsForTier(int tier) {
      if (tier == playedTier) return playedOrder;
      final other = _save!.otherDivisionLeagues[tier - 1]!;
      final otherStandings = other.sortedStandings;
      return otherStandings
          .map((r) => other.teams.firstWhere((t) => t.id == r.teamId))
          .toList();
    }

    final tierOrder = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        tier: orderedTeamsForTier(tier),
    };
    final outgoingIds = <int, Set<String>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++) tier: <String>{},
    };
    final incomingTeams = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++) tier: <Team>[],
    };
    var relevantPlayoffMatches = const <PromotionPlayoffMatch>[];
    for (int upperTier = 1; upperTier < totalDivisionTiers; upperTier++) {
      final lowerTier = upperTier + 1;
      final upperOrder = tierOrder[upperTier]!;
      final lowerOrder = tierOrder[lowerTier]!;
      final result = PromotionEngine.resolve(
        tier1Teams: upperOrder,
        tier2Teams: lowerOrder,
        tier1PlayedOrder: upperOrder,
        tier2PlayedOrder: lowerOrder,
        rules: currentLeagueTheme.rulesBelow(upperTier),
      );
      final upperIds = upperOrder.map((t) => t.id).toSet();
      final lowerIds = lowerOrder.map((t) => t.id).toSet();
      final promoted =
          result.tier1.where((t) => !upperIds.contains(t.id)).toList();
      final relegated =
          result.tier2.where((t) => !lowerIds.contains(t.id)).toList();

      outgoingIds[upperTier]!.addAll(relegated.map((t) => t.id));
      outgoingIds[lowerTier]!.addAll(promoted.map((t) => t.id));
      incomingTeams[upperTier]!.addAll(promoted);
      incomingTeams[lowerTier]!.addAll(relegated);

      // 自クラブが出た試合(昇格プレーオフか入れ替え戦)があれば、それを見せる。
      // 無ければ、下の部として戦った側のプレーオフを見せる。
      final userId = _save!.userTeamId;
      if (result.promotionPlayoff
          .any((m) => m.homeId == userId || m.awayId == userId)) {
        relevantPlayoffMatches = result.promotionPlayoff;
      } else if (lowerTier == playedTier &&
          !relevantPlayoffMatches
              .any((m) => m.homeId == userId || m.awayId == userId)) {
        relevantPlayoffMatches = result.promotionPlayoff;
      }
    }

    final mergedByTier = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        tier: [
          ...tierOrder[tier]!.where((t) => !outgoingIds[tier]!.contains(t.id)),
          ...incomingTeams[tier]!,
        ],
    };
    // 国ごとの部の大きさに合わせる(旧セーブは全部20クラブだったので、
    // 次のシーズンからこの形になる)。
    final theme = currentLeagueTheme;
    final resizeRng = Random();
    // 新しく作るクラブの名前は、いまあるクラブと重ならないものから取る。
    final usedNames = {
      for (final teams in mergedByTier.values)
        for (final t in teams) t.name,
    };
    final newClubNames = NamePool.themedClubNames(theme, 300)
        .where((n) => !usedNames.contains(n))
        .toList();
    var nameCursor = 0;
    final newTeamsByTier = PromotionEngine.resize(
      mergedByTier,
      theme.teamsByTier,
      protectedId: _save!.userTeamId,
      create: (tier, i) {
        final t = PlayerGenerator.generateSquad(
          id: 's${league.season + 1}_div${tier}_$i',
          name: newClubNames[nameCursor++ % newClubNames.length],
          strengthTier: rollDivisionStrength(tier, resizeRng),
        );
        LineupUtils.autoFill(t);
        return t;
      },
    );

    var newTier = playedTier;
    for (final entry in newTeamsByTier.entries) {
      if (entry.value.any((t) => t.id == _save!.userTeamId)) {
        newTier = entry.key;
        break;
      }
    }
    final newActiveTeams = newTeamsByTier[newTier]!;
    _ensureSquadsForActiveTier(newActiveTeams);

    final userInPromotionPlayoff = relevantPlayoffMatches.any(
      (m) => m.homeId == _save!.userTeamId || m.awayId == _save!.userTeamId,
    );
    lastPromotionPlayoffResults = relevantPlayoffMatches
        .map(
          (m) => Tr.pick(
              '${m.roundLabel}: ${m.homeName} ${m.homeGoals}-${m.awayGoals} ${m.awayName}${m.decidedByPenalties ? '(PK: ${m.winnerName}が勝利)' : ''}',
              "${m.roundLabel}: ${m.homeName} ${m.homeGoals}-${m.awayGoals} ${m.awayName}${m.decidedByPenalties ? ' (pens: ${m.winnerName})' : ''}"),
        )
        .toList();
    userInvolvedInLastPromotionPlayoff = userInPromotionPlayoff;
    lastPromotionBonus = 0;
    if (newTier > playedTier) {
      lastDivisionChangeMessage = Tr.pick(
          '降格が決まりました。来シーズンは$newTier部リーグでの再出発です。',
          'You are relegated. Next season starts again in tier $newTier.');
    } else if (newTier < playedTier) {
      // 昇格ボーナス: 上のディビジョンで戦うための補強予算が理事会から
      // 支給される(放映権料・スポンサー収入の増加分)。これがないと
      // 戦力差を埋める資金がなく、昇格と降格を往復し続けることになる。
      final promotionBonus = BoardEngine.promotionBonusFor(newTier);
      _book(LedgerCategory.prize, promotionBonus);
      lastPromotionBonus = promotionBonus;
      lastDivisionChangeMessage = userInPromotionPlayoff
          ? Tr.pick(
              '昇格プレーオフを勝ち抜き、来シーズンは$newTier部リーグに昇格します！理事会から補強予算${formatMoney(promotionBonus)}が支給されました。',
              'You came through the play-offs and go up to tier $newTier next season. The board has given you ${formatMoney(promotionBonus)} to strengthen.')
          : Tr.pick(
              '昇格達成！来シーズンは$newTier部リーグに昇格します。理事会から補強予算${formatMoney(promotionBonus)}が支給されました。',
              'Promoted. You go up to tier $newTier next season, and the board has given you ${formatMoney(promotionBonus)} to strengthen.');
    } else if (userInPromotionPlayoff) {
      lastDivisionChangeMessage = Tr.pick(
          '昇格プレーオフで敗れ、来シーズンも$playedTier部リーグで戦います。',
          'You lost in the play-offs, and stay in tier $playedTier next season.');
    } else {
      lastDivisionChangeMessage = null;
    }
    lastSeasonFinale = finalRank == 1
        ? SeasonFinale.champion
        : (newTier < playedTier ? SeasonFinale.promoted : SeasonFinale.none);
    _save!.currentDivisionTier = newTier;
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == newTier) {
        _save!.otherDivisionLeagues[tier - 1] = null;
        continue;
      }
      final tierTeams = newTeamsByTier[tier]!;
      _save!.otherDivisionLeagues[tier - 1] = League(
        teams: tierTeams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(tierTeams),
        season: league.season + 1,
      );
    }

    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(
      newActiveTeams,
    );
    _save!.league = League(
      teams: newActiveTeams,
      fixtures: newFixtures,
      season: league.season + 1,
    );
    // ここから新しいシーズン。契約の残り年数もこのシーズンから数える。
    _syncContractClock();
    // 規則違反の勝ち点剥奪は、来季の順位表に反映する。
    if (_save!.pendingPointsDeduction > 0) {
      _save!.league.pointsAdjustments[_save!.userTeamId] =
          -_save!.pendingPointsDeduction;
      _save!.pendingPointsDeduction = 0;
    }
    _save!.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(_save!.league, _save!.userTeamId),
    );
    // 続投が決まった監督には、新シーズン開幕時に最低限の信頼度を戻す
    // (解任が確定している場合は信頼度0のままにして解任フローを壊さない)。
    if (_save!.confidence > 0 && _save!.managerContractYears > 0) {
      _save!.confidence =
          max(_save!.confidence, BoardEngine.newSeasonConfidenceFloor);
    }
    _save!.wageBudget = BoardEngine.wageBudgetFor(
      tier: _save!.currentDivisionTier,
      currentWeeklyWageBill: weeklyWageBill,
      weeklyIncome: weeklyIncomeFor(_save!.userTeamId),
    );
    transferMarket = TransferMarket.generate(home: currentLeagueTheme);
    _refreshScoutCandidates();
    FreeAgentEngine.topUp(_save!.freeAgents);

    _rollNamingRights();
    // スポンサー契約(年単位)はシーズン境界で1年分消化する。
    if (_save!.sponsorDeal != null) {
      _save!.sponsorDeal!.yearsRemaining -= 1;
      if (_save!.sponsorDeal!.yearsRemaining <= 0) {
        _save!.sponsorDeal = null;
      }
    }
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers = SponsorEngine.generateOffers(
        userTeam.overallRating,
        tier: _save!.currentDivisionTier,
        managerReputation: _save!.managerReputation,
        stadiumLevel:
            _save!.infrastructure.facilityLevel(FacilityType.stadium),
      );
    }

    // スタッフの契約消化と、候補の入れ替え。良いスタッフはクラブの規模を
    // 見て来るかどうかを決めるので、昇格するほど顔ぶれが良くなる。
    for (final role in StaffRole.values) {
      final s = _save!.infrastructure.staffFor(role);
      if (s == null) continue;
      s.contractYears -= 1;
      if (s.contractYears <= 0) {
        _save!.infrastructure.staff[role] = null;
        _logNews(
          Tr.pick('${s.name}との契約が満了し、${role.label}が空席になりました。',
              "${s.name}'s contract has expired, leaving the ${role.label} post vacant."),
          context: Tr.pick('スタッフ', 'Staff'),
        );
      }
    }
    _refreshStaffCandidates();
    // 理事会の路線。シーズンごとに変わる。半分は「特になし」で、
    // 毎年何かを課され続けると窮屈になる。
    //
    // **達成しえない路線は課さない。** 23歳以下がスカッドに足りないのに
    // 「若手の育成」を求められると、どうやっても評価が下がり続ける。
    final feasible = ClubVision.values.where((v) {
      if (v == ClubVision.none) return true;
      if (v != ClubVision.developYouth) return true;
      return userTeam.players.where((p) => p.age <= 23).length >=
          ClubVisionInfo.youthStartersRequired;
    }).toList();
    _save!.clubVision = Random().nextBool()
        ? ClubVision.none
        : feasible[Random().nextInt(feasible.length)];
    _save!.visionCompliedMatchdays = 0;
    _save!.visionCheckedMatchdays = 0;

    // 開幕前のキャンプ。方針を選ぶか見送るまでホームで促す。
    _save!.preseasonCampPending = true;

    // 高齢選手の引退判定(ユースプロスペクトは対象外)。
    final retirees = RetirementEngine.resolveRetirements(userTeam);
    for (final p in retirees) {
      _clearPlayerRoleReferences(userTeam, p.id);
    }
    _save!.retiredLegends.addAll(retirees);
    lastRetirements = retirees.map((p) => p.name).toList();

    // 7月1日: 満了日(6月30日)を過ぎた契約を自クラブも他のクラブも
    // 終わらせ、仮契約の選手を移す。引退判定より後に行うことで、緊急補強の
    // 安全網が最終的なスカッド人数を保証できるようにする。
    _settleContractsAtSeasonStart();
    // 契約満了・引退により編成人数が最低人数を割り込んだ場合の緊急補強(安全網)。
    lastEmergencySignings = [];
    while (userTeam.players.length < seasonStartSquadSize) {
      final signing = FreeAgentEngine.generateEmergencySigning();
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings.add(signing.name);
    }

    _save!.lastSeasonRank = finalRank;

    final cupsWonThisSeason = [
      ..._save!.cups
          .where((c) => c.championId == _save!.userTeamId)
          .map((c) => c.name),
      if (_save!.continentalCup?.championId == _save!.userTeamId)
        _save!.continentalCup!.name,
    ];
    _save!.seasonHistory.add(
      SeasonRecord(
        season: league.season,
        clubName: _save!.clubName,
        leagueName: _save!.leagueName,
        divisionTier: playedTier,
        finalRank: finalRank,
        teamCount: league.teams.length,
        played: userRow.played,
        won: userRow.won,
        draw: userRow.draw,
        lost: userRow.lost,
        goalsFor: userRow.goalsFor,
        goalsAgainst: userRow.goalsAgainst,
        wonLeague: finalRank == 1,
        promoted: newTier < playedTier,
        relegated: newTier > playedTier,
        cupsWon: cupsWonThisSeason,
      ),
    );
    _closeRivalSeason();
    if (finalRank == 1) {
      _addTimeline(Tr.pick('$playedTier部リーグで優勝', 'Won the tier $playedTier league'));
    }
    if (newTier < playedTier) {
      _addTimeline(Tr.pick('$newTier部へ昇格', 'Promoted to tier $newTier'));
    }
    if (newTier > playedTier) {
      _addTimeline(Tr.pick('$newTier部へ降格', 'Relegated to tier $newTier'));
    }
    for (final cup in cupsWonThisSeason) {
      _addTimeline(Tr.pick('$cupで優勝', 'Won $cup'));
    }
    _evaluateAchievements(season: league.season);
    _evaluateOwnerGoal(season: league.season);

    // スーパーカップ: 前シーズンのリーグ王者と国内カップ王者(同一クラブが両方
    // 制した場合はカップ準優勝クラブ)が新シーズン開幕前に対戦する。カップが
    // 未消化のままシーズンが終わった場合は開催しない。
    lastSuperCupNews = null;
    Cup? previousDomesticCup;
    for (final c in _save!.cups) {
      if (c.type == CupType.domestic) {
        previousDomesticCup = c;
        break;
      }
    }
    if (previousDomesticCup != null) {
      final pairing = SuperCupEngine.pairing(
        leagueChampionId: standings.first.teamId,
        domesticCup: previousDomesticCup,
      );
      final teamsThisSeason = newTeamsByTier.values.expand((t) => t).toList();
      Team? findTeam(String id) {
        for (final t in teamsThisSeason) {
          if (t.id == id) return t;
        }
        return null;
      }

      final champion = pairing == null ? null : findTeam(pairing.$1);
      final opponent = pairing == null ? null : findTeam(pairing.$2);
      if (champion != null && opponent != null && champion.id != opponent.id) {
        final superCup = CupMatch(
          round: 1,
          homeTeamId: champion.id,
          awayTeamId: opponent.id,
        );
        if (champion.id == _save!.userTeamId ||
            opponent.id == _save!.userTeamId) {
          _save!.pendingSuperCup = superCup;
        } else {
          final result = MatchEngine.simulate(
            home: champion,
            away: opponent,
            matchday: 0,
            weather: WeatherEngine.roll(),
          );
          superCup.result = result;
          if (result.homeGoals == result.awayGoals) {
            superCup.penaltyWinnerId = CupEngine.decidePenaltyWinner(
              champion,
              opponent,
            );
          }
          final winnerName =
              superCup.winnerId == champion.id ? champion.name : opponent.name;
          lastSuperCupNews = Tr.pick(
              '$winnerNameがスーパーカップを制した。', '$winnerName won the Super Cup.');
        }
      }
    }

    _save!.cups = [
      CupEngine.createKnockout(
        type: CupType.domestic,
        name: currentLeagueTheme.domesticCupName,
        teamIds: newActiveTeams.map((t) => t.id).toList(),
      ),
    ];
    _save!.boardCupTargetRound = _estimateDomesticCupTarget();
    if (playedTier == 1 && finalRank <= 2) {
      final continentalTeams = _generateContinentalTeams();
      _save!.continentalTeams = continentalTeams;
      _save!.continentalCup = ContinentalCupEngine.create(
        name: Tr.pick('大陸チャンピオンズカップ', 'Continental Champions Cup'),
        teamIds: [_save!.userTeamId, ...continentalTeams.map((t) => t.id)],
      );
    } else {
      _save!.continentalTeams = [];
      _save!.continentalCup = null;
    }
    _save!.friendlies = _generateFriendlies(newActiveTeams, _save!.userTeamId);
    // 新しいシーズンはオフ(7月1日)から始まる。夏の窓が開くので名簿の外
    // だった選手も戻り、シーズン末までのローンはここで終わる。
    _setToday(SeasonCalendar.preseasonDate(_save!.league.season));
    _settleLoansByDate();
    _save!.boardReviewDoneThisSeason = false;
    _save!.pendingBoardReviewMessage = null;
    _save!.lastManagerOfMonthCheckpoint = 0;
    // シーズン最終週に自動実施等でトレーニング済みのまま次シーズンへ入ると、
    // プレシーズン中ずっとrunWeeklyTrainingが「実施済み」扱いでブロックされて
    // しまうため、週次フラグも明示的にリセットする。
    _save!.trainingDoneThisWeek = false;

    // 次シーズン終了時の成長算出のため、開始時点の総合力を記録しておく。
    _save!.seasonStartOverallByPlayerId = {
      for (final p in userTeam.players) p.id: p.overall,
    };

    // シーズン開始レポートに載る通知をクラブニュース履歴にも記録する。
    final newsCtx = Tr.pick('シーズン開始', 'Season start');
    if (lastDivisionChangeMessage != null) {
      _logNews(lastDivisionChangeMessage!, context: newsCtx);
    }
    if (lastBoardBonusNote != null) {
      _logNews(lastBoardBonusNote!, context: newsCtx);
    }
    if (lastManagerContractNote != null) {
      _logNews(lastManagerContractNote!, context: newsCtx);
    }
    if (lastSeasonManagerAwardWon) {
      _logNews(Tr.pick('年間最優秀監督賞を受賞しました！', 'You won Manager of the Year!'),
          context: newsCtx);
    }
    if (lastSuperCupNews != null) {
      _logNews(lastSuperCupNews!, context: newsCtx);
    }
    if (lastRetirements.isNotEmpty) {
      _logNews(
          Tr.pick('引退: ${lastRetirements.join('、')}',
              "Retired: ${lastRetirements.join(', ')}"),
          context: newsCtx);
    }
    if (lastContractExpirations.isNotEmpty) {
      _logNews(
          Tr.pick('契約満了で退団: ${lastContractExpirations.join('、')}',
              "Left on a free: ${lastContractExpirations.join(', ')}"),
          context: newsCtx);
    }
    if (lastContractWarnings.isNotEmpty) {
      _logNews(
          Tr.pick('契約最終年に突入: ${lastContractWarnings.join('、')}',
              "Into the final year of their contract: ${lastContractWarnings.join(', ')}"),
          context: newsCtx);
    }
    if (lastRenewalRefusals.isNotEmpty) {
      _logNews(
          Tr.pick(
              '契約を延長しないと言い出した: ${lastRenewalRefusals.join('、')}。売るか、来年6月30日の満了でただで手放すことになります。',
              "Refusing to sign a new deal: ${lastRenewalRefusals.join(', ')}. Sell them, or lose them for nothing when their deals run out on 30 Jun."),
          context: newsCtx);
    }
    if (lastPreContractArrivals.isNotEmpty) {
      _logNews(
          Tr.pick('仮契約で加入: ${lastPreContractArrivals.join('、')}',
              "Joined on pre-contracts: ${lastPreContractArrivals.join(', ')}"),
          context: newsCtx);
    }
    if (lastEmergencySignings.isNotEmpty) {
      _logNews(
          Tr.pick('緊急補強: ${lastEmergencySignings.join('、')}',
              "Emergency signings: ${lastEmergencySignings.join(', ')}"),
          context: newsCtx);
    }

    isBusy = false;
    _notify();
    await _persistNow();
    // シーズンの切り替わりは区切りになる。ここで控えを取り直しておくと、
    // セーブが壊れても失うのは1シーズン以内で済む。
    await refreshSaveBackup();
  }
}
