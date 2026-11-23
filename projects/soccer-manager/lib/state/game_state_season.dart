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
    final current = leagueThemeFromName(save.leagueName) ?? LeagueTheme.england;
    for (var i = 0; i < save.otherDivisionLeagues.length; i++) {
      final l = save.otherDivisionLeagues[i];
      if (l == null) continue;
      _ensureSquadsForActiveTier(l.teams, wageCountryFactor(current, i + 1));
    }
    save.foreignLeagues.remove(current.name);
    final rng = Random();
    for (final theme in LeagueTheme.values) {
      if (theme == current) continue;
      final existing = save.foreignLeagues[theme.name];
      if (existing != null) {
        _ensureSquadsForActiveTier(existing.teams, wageCountryFactor(theme, 1));
        continue;
      }
      final count = theme.teamsInTier(1);
      final names = NamePool.themedClubNames(theme, count);
      // その国の選手はその国の名前で作る。
      NamePool.homeTheme = theme;
      // 年俸はその国の1部の水準(wageCountryFactor)。
      final teams = withWageLevel(
        wageCountryFactor(theme, 1),
        () => [
          for (var i = 0; i < count; i++)
            PlayerGenerator.generateSquad(
              id: 'f_${theme.name}_$i',
              name: names[i],
              // 1部の上から下まで(強豪から残留争いまで)の幅を持たせる。
              strengthTier: rollDivisionStrength(1, rng),
            ),
        ],
      );
      for (final t in teams) {
        LineupUtils.autoFill(t);
      }
      save.foreignLeagues[theme.name] = League(
        teams: teams,
        fixtures: const [],
        season: save.league.season,
      );
    }
    NamePool.homeTheme = current;
    _ensureForeignFixtures(save);
    // 選手の名前を国籍に合わせる(旧セーブの日本の姓名もここで直る)。
    _localizeNames();
  }

  void _ensureSquadsForActiveTier(List<Team> teams, [double? wageLevel]) {
    for (final t in teams) {
      if (t.players.isNotEmpty) continue;
      // 保持していた強度に合うスカッドを作る。strengthTier にそのまま
      // 渡すと出来上がりが1〜2割弱く、再起動のたびに昇降格で入ってくる
      // クラブが弱くなっていた。壊れたセーブで欠けていた場合に0の
      // スカッドを作らないよう、移行時と同じ範囲に収める。
      // 年俸はそのクラブのいる国・部の水準([wageLevel])。
      final generated = withWageLevel(
        wageLevel ?? currentWageLevel,
        () => PlayerGenerator.generateSquadWithOverall(
          id: t.id,
          name: t.name,
          targetOverall: (t.retainedOverall ?? 50).clamp(15, 90),
        ),
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
  /// イングランドの3部は代表ウィークにも節を置く。
  SeasonCalendar get seasonCalendar => SeasonCalendar.build(
        season: _save!.league.season,
        theme: currentLeagueTheme,
        totalMatchdays: _totalMatchdaysThisSeason,
        playsInInternationalWindows:
            SeasonCalendar.playsThroughInternationalWindows(
                currentLeagueTheme, currentDivisionTier),
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
    if (!d.isAfter(before)) {
      _save!.today = d;
      return;
    }
    // 怪我の回復・疲れの抜け(日数)と、またいだ週の数だけの週の処理。
    // 終わると今日は d になっている。
    _advanceDaysAndWeeks(before, d);
    // 完成の日が来た施設の工事を終える(スタジアムは次の季の7月1日)。
    _completeFacilityConstruction();
    // 仮契約の解禁(1月1日)・延長オプションの期限(3月31日)。
    _onContractDatesAdvanced(before, d);
    // 給与の月末・放映権の入金日。
    _settleMoneyDates(before, d);
    // サポーターの期待の月末のまとめ(結果・チケット・地域活動)と内訳。
    _settleSupporterMonths(before, d);
    // 誕生日とオーナーの本業の収入は、前に済ませた日より後の分だけ
    // (季の途中で別の国のクラブを買い直すと今日が戻る。二重に入れない)。
    final through = _save!.personalDatesThrough;
    final personalFrom =
        through != null && through.isAfter(before) ? through : before;
    // 誕生日が来た選手は1つ歳を取る。
    if (d.isAfter(personalFrom)) _ageByBirthdays(personalFrom, d);
    // 夏の大会に出た選手の合流。
    _endTournamentLeaveIfDue(before, d);
    // スカウトを送った地域・注目の選手が見えてくる。
    _advanceScouting(before, d);
    // 移籍の交渉の返事・期限、窓が閉じたら流す。
    _advanceTransferTalks(before, d);
    // スタッフの引き抜きの話・候補の月ごとの入れ替え。
    _advanceStaffMoves(before, d);
    // 選手の私生活の出来事(月ごと)。
    _rollLifeEvents(before, d);
    // オーナーの本業の収入と、貸付の利息(月ごと)。
    _advanceOwnerMoney(before, d, incomeFrom: personalFrom);
    if (d.isAfter(personalFrom)) _save!.personalDatesThrough = d;
    final theme = currentLeagueTheme;
    // 窓が開いたら、名簿の外だった選手もまた登録できる。
    if (TransferWindowCalendar.openedBetween(before, d, theme)) {
      // 他のオーナーが補強に動く。
      _rivalOwnersInvest();
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
    final excluded = SquadRegistration.plannedExclusions(team,
        rules: registrationRules, nationOf: nationalityOf);
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
  List<Player> get plannedRegistrationExclusions =>
      _save == null
          ? const []
          : SquadRegistration.plannedExclusions(userTeam,
              rules: registrationRules, nationOf: nationalityOf);

  /// 日付で終わるローンを片付ける(借りている選手は戻し、貸している選手は
  /// 呼び戻す)。シーズンの切り替わり(7月1日)でも呼ぶ。
  void _settleLoansByDate() {
    final t = today;
    final team = userTeam;
    final ended = team.players
        .where((p) =>
            p.isLoan && p.loanEndDate != null && !t.isBefore(p.loanEndDate!))
        .toList();
    // 買取義務付きのローンは、満了で完全移籍に切り替わって残る。
    ended.removeWhere(_completeObligationIfAny);
    for (final p in ended) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
      _clearPlayerRoleReferences(team, p.id);
      _returnLoanToParent(p);
    }
    if (ended.isNotEmpty) {
      // 契約満了の退団とは分けて控える(「契約満了で退団」と出していた)。
      lastLoanEndings = [
        ...lastLoanEndings,
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
          p.loanEndDate =
              DateTime(t.year, t.month, t.day + 7 * p.loanWeeksRemaining);
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
    save.transferMarketPlayers.removeWhere((p) =>
        p.age < 18 && (p.originLeague == null || p.originLeague != home));
  }

  /// いま消化するカップ戦の日付へ今日を進める。リーグ戦の途中なら次の
  /// 節の前の平日、リーグ戦を終えた後(オフ)なら今日の次の平日。
  void _advanceTodayForCup({required bool continental}) {
    _advanceTodayTo(_cupDate(continental: continental));
  }

  /// 次のカップの試合の日([_advanceTodayForCup]が進める先)。試合の前に
  /// 天候の季節を決めるのに使う(日付は試合のあとに進めるため)。
  DateTime _cupDate({required bool continental}) {
    if (_save!.league.nextUnplayedFixture == null) {
      return SeasonCalendar.nextCupWeekdayAfter(today,
          continental: continental);
    }
    return seasonCalendar.cupDateBefore(_currentLeagueMatchdayMarker,
        continental: continental);
  }

  Cup? get domesticCup => _save == null ? null : _cupOfType(CupType.domestic);

  /// 自クラブが出ている大陸大会(チャンピオンズカップかヨーロッパカップ)。
  /// 出ていない季は null。大会そのものは自クラブが出なくても行われる
  /// ([continentalCups])。
  ContinentalCup? get continentalCup => _userContinentalCup;

  /// 今季、自クラブが大陸大会に出ているか。
  bool get qualifiedForContinentalCup => _userContinentalCup != null;

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
  ///
  /// 新しい形のカップ(1〜3部の全クラブ)は、回戦ごとに決まった節に
  /// なれば消化できる(回戦はまとめて同じ週に行う)。
  bool get canPlayNextDomesticCupMatch {
    final cup = domesticCup;
    final next = cup?.nextUnplayedMatch;
    if (cup == null || next == null) return false;
    if (cup.plannedRounds != null) {
      return _cupDue(cup.dueMatchdayForMatch(next));
    }
    return _canAdvanceCup(cup.lastPlayedAtMatchday);
  }

  Future<MatchResult?> playNextCupMatch() async {
    if (_save == null) return null;
    final cup = domesticCup;
    if (cup == null || cup.nextUnplayedMatch == null) return null;
    if (!canPlayNextDomesticCupMatch) return null;
    if (cup.plannedRounds != null) {
      // 同じ週の他のクラブの試合を先に決める。自クラブの試合が無い回戦
      // なら、それで回戦が終わる。
      _playCpuCupRound(cup);
      final m = cup.nextUnplayedMatch;
      if (m == null ||
          !_isUserMatch(m) ||
          !_cupDue(cup.dueMatchdayForMatch(m))) {
        _notify();
        await _persistNow();
        return null;
      }
    }

    final match = cup.nextUnplayedMatch!;
    if (!match.isBye) {
      final home = allTeamsForCups.firstWhere((t) => t.id == match.nextHomeId);
      final away = allTeamsForCups.firstWhere((t) => t.id == match.nextAwayId);
      _ensureSquadsForActiveTier([home, away]);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    // 警告と出場停止は国内のカップ戦の決まりで数える。
    final result = CardRules.run(
        _cupCardRules,
        () => CupEngine.playNextMatch(cup, allTeamsForCups,
            month: _cupDate(continental: false).month));
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
  /// 新しい形の大会は、段階ごとに決まった節になれば消化できる。
  bool get canPlayNextContinentalMatch {
    final cup = _userContinentalCup;
    if (cup == null || !_continentalHasNextMatch(cup)) return false;
    if (cup.stepDue != null) {
      return _cupDue(ContinentalCupEngine.currentStepDue(cup));
    }
    return _canAdvanceCup(cup.lastPlayedAtMatchday);
  }

  /// 新しい形の大陸大会で、同じ週の他のクラブの試合を先に決め、次の試合が
  /// 自クラブの試合で、もう戦えるか。古い形の大会は常に true。
  bool _prepareUserContinentalMatch(ContinentalCup cup) {
    if (cup.stepDue == null) return true;
    _playCpuContinental(cup);
    if (!_continentalHasNextMatch(cup)) return false;
    if (!_cupDue(ContinentalCupEngine.currentStepDue(cup))) return false;
    final u = _save!.userTeamId;
    if (!cup.isGroupStageComplete) {
      final m = ContinentalCupEngine.nextGroupMatch(cup);
      return m != null && (m.homeTeamId == u || m.awayTeamId == u);
    }
    final leg = ContinentalCupEngine.nextKnockoutLeg(cup);
    return leg != null && (leg.homeId == u || leg.awayId == u);
  }

  /// 大陸カップのグループステージ次の1試合を消化する。全組が終わると
  /// 自動的に決勝トーナメントの組み合わせが決定される。
  Future<MatchResult?> playNextContinentalGroupMatch() async {
    if (_save == null || _userContinentalCup == null) return null;
    final cup = _userContinentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!canPlayNextContinentalMatch) return null;
    if (!_prepareUserContinentalMatch(cup) || cup.isGroupStageComplete) {
      _notify();
      await _persistNow();
      return null;
    }
    final match = ContinentalCupEngine.nextGroupMatch(cup);
    if (match != null) {
      final home = allTeamsForCups.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeamsForCups.firstWhere((t) => t.id == match.awayTeamId);
      _ensureSquadsForActiveTier([home, away]);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = CardRules.run(
      const CardRules.continental(),
      () => ContinentalCupEngine.playNextGroupMatch(
        cup,
        allTeamsForCups,
        month: _cupDate(continental: true).month,
      ),
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
    if (_save == null || _userContinentalCup == null) return null;
    final cup = _userContinentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!canPlayNextContinentalMatch) return null;
    if (!_prepareUserContinentalMatch(cup) || !cup.isGroupStageComplete) {
      _notify();
      await _persistNow();
      return null;
    }
    final leg = ContinentalCupEngine.nextKnockoutLeg(cup);
    if (leg != null) {
      final home = allTeamsForCups.firstWhere((t) => t.id == leg.homeId);
      final away = allTeamsForCups.firstWhere((t) => t.id == leg.awayId);
      _ensureSquadsForActiveTier([home, away]);
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    }
    final result = CardRules.run(
      const CardRules.continental(),
      () => ContinentalCupEngine.playNextKnockoutLeg(
        cup,
        allTeamsForCups,
        month: _cupDate(continental: true).month,
      ),
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
    // スーパーカップは中立の会場。警告は国内のカップ戦の決まりで数える。
    final result = CardRules.run(
      _cupCardRules,
      () => MatchEngine.simulate(
        home: home,
        away: away,
        matchday: 0,
        weather: WeatherEngine.roll(month: today.month),
        homeAdvantageFactor: MatchEngine.neutralHomeAdvantageFactor,
      ),
    );
    match.result = result;
    if (result.homeGoals == result.awayGoals) {
      match.penaltyWinnerId =
          CupEngine.decidePenaltyWinner(home, away, result: result);
    }
    _applyUserCupPostMatchEffects(result);
    _afterSuperCupApplied(match);
    _notify();
    await _persistNow();
    return result;
  }

  /// 4クラブのスーパーカップ(スペイン・イタリア)の自クラブの次の試合を、
  /// 自動で戦う。同じ週のほかの試合は先に裏で決める。延長は無く、
  /// 並べばPK戦。戦えないときは null。
  Future<MatchResult?> playNextFourClubSuperCupMatch() async {
    if (_save == null || !canPlayNextFourClubSuperCupMatch) return null;
    final cup = fourClubSuperCup!;
    _playCpuCupRound(cup);
    if (!canPlayNextFourClubSuperCupMatch) {
      _notify();
      await _persistNow();
      return null;
    }
    final match = userFourClubSuperCupMatch!;
    final home = teamById(match.homeTeamId);
    final away = teamById(match.awayTeamId);
    if (home == null || away == null) return null;
    _ensureSquadsForActiveTier([home, away]);
    CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
    // 中立の会場。警告は国内のカップ戦の決まりで数える。
    final result = CardRules.run(
      _cupCardRules,
      () => MatchEngine.simulate(
        home: home,
        away: away,
        matchday: 0,
        weather: WeatherEngine.roll(month: _cupDate(continental: false).month),
        homeAdvantageFactor: MatchEngine.neutralHomeAdvantageFactor,
      ),
    );
    CupEngine.applyMatchResult(
        cup, [...allTeamsForCups, home, away], match, result);
    _advanceTodayForCup(continental: false);
    _applyUserCupPostMatchEffects(match.result!);
    _afterFourClubSuperCupMatchApplied(match);
    _notify();
    await _persistNow();
    return match.result;
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
    final cup = _userContinentalCup!;
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
        // 同じ週の他のクラブの試合を先に決める(自クラブの試合は回戦の
        // 先頭にあるので、そのまま次の試合になる)。
        _playCpuCupRound(domesticCup!);
        if (!canPlayNextDomesticCupMatchLive) return false;
        cupMatch = domesticCup!.nextUnplayedMatch;
        // 2試合制の第1戦は相手のホーム。
        home = teamById(cupMatch!.nextHomeId);
        away = teamById(cupMatch.nextAwayId);
      case LiveCupKind.continentalGroup:
      case LiveCupKind.continentalKnockout:
        if (!canPlayNextContinentalMatchLive) return false;
        final cup = _userContinentalCup!;
        if (!_prepareUserContinentalMatch(cup)) return false;
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
        // 開幕前の1試合(英・独・仏)か、4クラブのスーパーカップ(西・伊)。
        if (canPlaySuperCupLive) {
          cupMatch = _save!.pendingSuperCup;
        } else if (canPlayNextFourClubSuperCupMatchLive) {
          _playCpuCupRound(fourClubSuperCup!);
          if (!canPlayNextFourClubSuperCupMatchLive) return false;
          cupMatch = userFourClubSuperCupMatch;
        } else {
          return false;
        }
        home = teamById(cupMatch!.homeTeamId);
        away = teamById(cupMatch.awayTeamId);
    }
    if (home == null || away == null) return false;
    // スーパーカップの相手は別ディビジョンのことがあり、そのクラブは
    // 再起動後に選手を持っていない(保存しないため)。0人では試合にならない。
    _ensureSquadsForActiveTier([home, away]);
    // 天候は試合の日の季節に合わせる(日付は試合のあとに進めるので、
    // 国内・大陸カップは進める先の日の月を見る)。
    final matchDay = resolvedKind == LiveCupKind.superCup &&
            cupMatch == _save!.pendingSuperCup
        ? today
        : _cupDate(
            continental: resolvedKind == LiveCupKind.continentalGroup ||
                resolvedKind == LiveCupKind.continentalKnockout);
    final weather = WeatherEngine.roll(month: matchDay.month);
    _liveCupKind = resolvedKind;
    _liveCupHome = home;
    _liveCupAway = away;
    _liveCupWeather = weather;
    _liveCupMatch = cupMatch;
    _liveCupTie = tie;
    // この大会の出場停止で出られる選手を決める(試合の終わりで戻す)。
    CardRules.current = _liveCardRules;
    _liveSubstitutionsUsed = 0;
    _liveSubWindowsUsed = 0;
    _liveSubWindowKey = null;
    _liveHalfTimeSubEvents = [];
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
  MatchResult _applyLiveCupResult(MatchResult merged) {
    final kind = _liveCupKind;
    if (kind == null || _save == null) return merged;
    switch (kind) {
      case LiveCupKind.domestic:
        final cup = domesticCup;
        final match = _liveCupMatch;
        if (cup == null || match == null) return merged;
        // 2試合制の第1戦は延長もPK戦も無い(第2戦の後に合計で見る)。
        if (!match.awaitingFirstLeg && match.levelAfter(merged)) {
          // 90分で並べば延長戦(30分)。それでも並べばPK戦。延長の得点は
          // 試合後の共通処理の後に足されるので、選手の通算得点にここで足す
          // (画面には出るのに成績に入っていなかった。2026-11-22)。
          final before = merged;
          merged = CupEngine.extraTime(merged, _liveCupHome!, _liveCupAway!);
          CupEngine.creditExtraTimeGoals(
              before, merged, [_liveCupHome!, _liveCupAway!]);
          match.extraTime = true;
          if (match.levelAfter(merged)) {
            match.penaltyWinnerId = _runLiveShootout(merged).winnerId;
          }
        }
        CupEngine.applyMatchResult(cup, allTeamsForCups, match, merged);
        _advanceTodayForCup(continental: false);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterDomesticCupMatchApplied(match);
      case LiveCupKind.continentalGroup:
        final cup = _userContinentalCup;
        final match = _liveCupMatch;
        if (cup == null || match == null) return merged;
        ContinentalCupEngine.applyGroupMatchResult(
            cup, allTeamsForCups, match, merged);
        _advanceTodayForCup(continental: true);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterContinentalGroupMatchApplied(match);
      case LiveCupKind.continentalKnockout:
        final cup = _userContinentalCup;
        final tie = _liveCupTie;
        if (cup == null || tie == null) return merged;
        // このレグでタイが完了し、合計スコアが同点になる場合は延長戦、
        // それでも並べばPK戦。
        if (tie.legs.length + 1 >= tie.totalLegs) {
          bool level(MatchResult r) {
            final a = r.homeTeamId == tie.teamAId ? r.homeGoals : r.awayGoals;
            final b = r.homeTeamId == tie.teamBId ? r.homeGoals : r.awayGoals;
            return tie.goalsFor(tie.teamAId) + a ==
                tie.goalsFor(tie.teamBId) + b;
          }

          if (level(merged)) {
            final before = merged;
            merged = CupEngine.extraTime(merged, _liveCupHome!, _liveCupAway!);
            CupEngine.creditExtraTimeGoals(
                before, merged, [_liveCupHome!, _liveCupAway!]);
            tie.extraTime = true;
            if (level(merged)) {
              tie.penaltyWinnerId = _runLiveShootout(merged).winnerId;
            }
          }
        }
        ContinentalCupEngine.applyKnockoutLegResult(
            cup, allTeamsForCups, tie, merged);
        _advanceTodayForCup(continental: true);
        cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
        _afterContinentalKnockoutLegApplied(tie);
      case LiveCupKind.superCup:
        final match = _liveCupMatch;
        if (match == null) return merged;
        if (_isFourClubSuperCupMatch(match)) {
          // 4クラブのスーパーカップ: 延長は無く、並べばPK戦(1本ずつ)。
          if (merged.homeGoals == merged.awayGoals) {
            match.penaltyWinnerId = _runLiveShootout(merged).winnerId;
          }
          CupEngine.applyMatchResult(
              fourClubSuperCup!,
              [...allTeamsForCups, _liveCupHome!, _liveCupAway!],
              match,
              merged);
          _advanceTodayForCup(continental: false);
          _afterFourClubSuperCupMatchApplied(match);
          break;
        }
        match.result = merged;
        if (merged.homeGoals == merged.awayGoals) {
          match.penaltyWinnerId = _runLiveShootout(merged).winnerId;
        }
        _afterSuperCupApplied(match);
    }
    _payCupAppearanceFees(merged);
    // 過密日程の判定(前の試合との日付の間隔)。
    _noteUserMatchDay();
    _evaluateAchievements();
    return merged;
  }

  /// カップ戦・大陸大会の試合[r]の出場手当を払う(先発は満額、途中出場は
  /// 半額)。リーグ戦と違って試合の前には払っていないので、先発の分もここで。
  void _payCupAppearanceFees(MatchResult r) {
    final userId = _save!.userTeamId;
    if (r.homeTeamId != userId && r.awayTeamId != userId) return;
    final fees = AppearanceFeeEngine.feesFor(userTeam, r);
    if (fees > 0) _book(LedgerCategory.appearanceFees, -fees);
  }

  /// ライブ観戦のカップ戦がPK戦にもつれた際、1本ずつのシュートアウトを
  /// 実施して勝者を決める。記録は[_lastShootout]に保持し、フルタイム画面が
  /// 1本ごとの成否を演出表示する。自クラブが勝てばPK戦勝利数も記録する。
  PenaltyShootoutResult _runLiveShootout(MatchResult played) {
    final shootout = CupEngine.simulateShootout(_liveCupHome!, _liveCupAway!,
        result: played);
    if (shootout.winnerId == _save!.userTeamId) {
      _save!.pkShootoutWins++;
    }
    return shootout;
  }

  /// 自クラブが関わるカップ試合の、自動消化の経路の後の処理(過密日程の
  /// 判定)。疲労・負傷・警告累積・通算出場/得点などの試合後効果は、
  /// MatchEngine.simulate の中で1回だけ入る(2026-11-23 まではここでも
  /// もう一度入れていて、警告・疲労・出場数が2倍に数えられていた)。
  void _applyUserCupPostMatchEffects(MatchResult result) {
    if (_save == null) return;
    final userId = _save!.userTeamId;
    if (result.homeTeamId != userId && result.awayTeamId != userId) return;
    _payCupAppearanceFees(result);
    // 過密日程の判定(前の試合との日付の間隔)。
    _noteUserMatchDay();
  }

  /// 国内カップのブラケット全ラウンド数(1回戦から決勝まで)。
  int _domesticCupTotalRounds(Cup cup) => cup.totalRounds;

  /// 理事会が期待する国内カップの到達ラウンドを、リーグ内の戦力順位から
  /// 見積もる(国内カップが未生成なら0=期待なし)。
  ///
  /// 1〜3部の全クラブが出るカップでは、出る全クラブの中の戦力順位で見る
  /// (3部のクラブに1部のクラブと同じ深さを求めない)。下位なら、入った
  /// 回戦で1つ勝つこと。
  int _estimateDomesticCupTarget() {
    final cup = domesticCup;
    if (cup == null || _save == null) return 0;
    final userId = _save!.userTeamId;
    final field = cup.tiers.isEmpty
        ? [..._save!.league.teams]
        : allTeamsForCups.where((t) => cup.tiers.containsKey(t.id)).toList();
    field.sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final rank = field.indexWhere((t) => t.id == userId) + 1;
    if (rank <= 0) return 0;
    final total = _domesticCupTotalRounds(cup);
    if (cup.tiers.isNotEmpty && rank / field.length > 0.6) {
      var entry = 1;
      for (final e in cup.entrants.entries) {
        if (e.value.contains(userId)) entry = e.key;
      }
      return min(total, entry + 1);
    }
    return BoardEngine.estimateCupTargetRound(
      strengthRank: rank,
      teamCount: field.length,
      totalRounds: total,
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
    // 入場収入(両クラブで折半。決勝などの中立の会場も折半)。
    if (userInvolved) _bookDomesticCupGate(cup, match);
    // 2試合制の第1戦の後は、勝ち負けはまだ決まらない(同じ週の残りの
    // 第1戦だけ決める)。
    if (userInvolved && match.result == null) {
      _playCpuCupRound(cup);
      return;
    }
    if (userInvolved) {
      if (match.winnerId == userId) {
        final prize =
            scaledMoney(GameState.domesticCupWinPrizeFor(match.round));
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
          _changeSupporters(2, SupporterReason.results);
          _logNews(
              Tr.pick('国内カップは理事会の期待($label進出)に応えた。敗退したが評価は上々だ',
                  "You met the board's expectation in the domestic cup (reaching ${CupEngine.roundInSentence(label!)}). You are out, but they are pleased"),
              context: Tr.pick('カップ戦', 'Cup'));
        } else if (target > 0 && target - reached >= 2) {
          _changeSupporters(-3, SupporterReason.results);
          _logNews(
              Tr.pick('国内カップで早期敗退。理事会の期待($label進出)を大きく裏切った',
                  "An early exit from the domestic cup, well short of the board's expectation of ${CupEngine.roundInSentence(label!)}"),
              context: Tr.pick('カップ戦', 'Cup'));
        } else {
          _changeSupporters(-1, SupporterReason.results);
        }
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final reward = scaledMoney(GameState.domesticCupChampionPrize);
      _book(LedgerCategory.prize, reward);
      _save!.careerCupPrize += reward;
      _changeSupporters(10, SupporterReason.results,
          note: Tr.pick('${cup.name}で優勝', 'Won the ${cup.name}'));
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${_save!.league.season}: ${cup.name} 優勝',
          'Season ${_save!.league.season}: ${cup.name} winners'));
    }
    // 同じ週の残りの試合(自クラブの出ない試合)を決め、回戦を締める。
    if (userInvolved) _playCpuCupRound(cup);
  }

  /// 大陸カップのグループステージ1試合が適用された後の共通処理。
  void _afterContinentalGroupMatchApplied(CupMatch match) {
    final cup = _userContinentalCup;
    if (cup == null) return;
    final userId = _save!.userTeamId;
    final userInvolved =
        match.homeTeamId == userId || match.awayTeamId == userId;
    if (!userInvolved) return;
    final r = match.result;
    // 入場収入はホームの試合だけ(リーグ戦より高い単価)。
    _bookCupGate(r,
        neutral: false,
        split: false,
        priceMultiplier: GameStateCupDays.continentalGateMultiplier(cup.level));
    final userWon = r != null &&
        ((r.homeTeamId == userId && r.homeGoals > r.awayGoals) ||
            (r.awayTeamId == userId && r.awayGoals > r.homeGoals));
    final drew = r != null && r.homeGoals == r.awayGoals;
    final newFormat = cup.stepDue != null;
    if (userWon || (newFormat && drew)) {
      // 新しい形の大会は実額(勝ち2.8億・引き分け9,000万。EL は3分の1)。
      final prize = newFormat
          ? continentalPrize(cup.level,
              userWon ? championsCupGroupWinPrize : championsCupGroupDrawPrize)
          : scaledMoney(GameState.continentalGroupWinPrize);
      _book(LedgerCategory.prize, prize);
      _save!.careerCupPrize += prize;
      lastCupPrizeNote = userWon
          ? Tr.pick('勝利賞金として${formatMoney(prize)}を獲得!',
              'You collected ${formatMoney(prize)} in prize money!')
          : Tr.pick('引き分けの賞金として${formatMoney(prize)}を獲得。',
              'You collected ${formatMoney(prize)} for the draw.');
      _logNews(lastCupPrizeNote!, context: Tr.pick('カップ戦', 'Cup'));
    }
    if (newFormat) {
      _playCpuContinental(cup);
      _settleContinentalPrizes(cup);
    }
    if (cup.isEliminated(userId)) {
      _changeSupporters(-3, SupporterReason.results);
    }
  }

  /// 大陸カップの決勝トーナメント1レグが適用された後の共通処理。
  void _afterContinentalKnockoutLegApplied(CupTie tie) {
    final cup = _userContinentalCup ??
        [_save?.continentalCup, _save?.secondContinentalCup]
            .whereType<ContinentalCup>()
            .where((c) => c.knockoutRounds.any((r) => r.contains(tie)))
            .firstOrNull;
    if (cup == null) return;
    final userId = _save!.userTeamId;
    final userInTie = tie.teamAId == userId || tie.teamBId == userId;
    // 入場収入: ホームのレグだけ(高い単価)。1試合制の決勝は中立の会場で折半。
    if (userInTie && tie.legs.isNotEmpty) {
      _bookCupGate(tie.legs.last,
          neutral: tie.singleLeg,
          split: false,
          priceMultiplier:
              GameStateCupDays.continentalGateMultiplier(cup.level));
    }
    if (cup.stepDue != null) {
      // 新しい形: 回戦に進んだ賞金・優勝は _settleContinentalPrizes が払う。
      if (userInTie) _playCpuContinental(cup);
      _settleContinentalPrizes(cup);
      if (userInTie && cup.isEliminated(userId)) {
        _changeSupporters(-3, SupporterReason.results);
      }
      return;
    }
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
        _changeSupporters(-3, SupporterReason.results);
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final reward = scaledMoney(GameState.continentalChampionPrize);
      _book(LedgerCategory.prize, reward);
      _save!.careerCupPrize += reward;
      _changeSupporters(20, SupporterReason.results,
          note: Tr.pick('${cup.name}で優勝', 'Won the ${cup.name}'));
      _save!.trophyHistory.add(Tr.pick(
          'シーズン${_save!.league.season}: ${cup.name} 優勝',
          'Season ${_save!.league.season}: ${cup.name} winners'));
    }
  }

  /// スーパーカップの結果が確定した後の共通処理。
  void _afterSuperCupApplied(CupMatch match) {
    if (_save == null) return;
    _advanceTodayTo(seasonCalendar.superCupDate);
    // 中立の会場。入場収入は折半。
    _bookCupGate(match.result, neutral: true, split: true);
    if (match.winnerId == _save!.userTeamId) {
      _save!.trophyHistory.add(Tr.pick('シーズン${_save!.league.season} スーパーカップ優勝',
          'Season ${_save!.league.season} Super Cup winners'));
    }
    _save!.pendingSuperCup = null;
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
    // 季を締める前の2つの期待。季末の増減を引く前の値で、新しい季の底上げを
    // 決める(引いた後の値で決めると、期待20で季末の -20 を受けたクラブが
    // 0 のまま、第2季の1試合目より前に手放すことになった。2026-11-23)。
    // 季を越えて手放すのは、季の途中で0になっていた場合だけ。
    final supporterBefore = _save!.confidence;
    // 最後通告の期限を過ぎて手放すことが決まっていれば、底上げしない。
    final supportersGone = supporterUltimatumExpired;
    final shareholderBefore = _save!.shareholderExpectation;
    final previousTargetRank = _save!.boardTargetRank;
    final wagesBefore = _save!.ledgerFor(league.season).wageCost;
    // 会計年度の終わり(6月30日)まで日を進める。5・6月の給与は、この季の
    // 年度の記録に入る(7月1日からが次の年度)。
    _advanceTodayTo(MoneyCalendar.fiscalYearEnd(league.season));
    // 切り替えでまとめて引かれた給与。説明なしに資金が減って見えたので、
    // シーズン開始レポートに1行で出す。
    final rolloverWages =
        _save!.ledgerFor(league.season).wageCost - wagesBefore;
    final standings = league.sortedStandings;
    final finalRank =
        standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final playedOrder = standings
        .map((r) => league.teams.firstWhere((t) => t.id == r.teamId))
        .toList();
    final playedTier = _save!.currentDivisionTier;
    // 持っているほかのクラブの損益(他国の1部の今季の順位で)。
    _settleGroupClubs();
    // 他国の1部の上位を控え(大陸大会の相手)、国の係数に今季を足す。
    _rememberForeignTop();
    _updateCountryCoefficients();
    // 他国の1部も季を締め、優勝を伝えて、次の季の日程を作る。
    _finishForeignSeasons();
    // 新しく入った選手(ユース・他国の新顔)の名前を国籍に合わせる。
    _localizeNames();
    // 手放したクラブのその後を記録する(順位が決まったこの時点で)。
    _recordFormerClubs(playedTier);
    // 他のクラブの経営: お金を動かし、赤字が続いたクラブは破綻する。
    final collapsedClubs = _settleAiClubFinances();
    // 監督の経歴に今季を足し、目標を果たしたら立場を上げる。
    _closeManagerSeason(
        finalRank: finalRank, teams: league.teams.length, tier: playedTier);

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
    // 警告の累積は季ごと(全大会)。出場停止の残りは次の季へ持ち越す。
    _resetSeasonCards();

    // 監督としての通算成績を更新する。
    final userRow = standings.firstWhere((r) => r.teamId == _save!.userTeamId);
    _save!.careerWins += userRow.won;
    _save!.careerDraws += userRow.draw;
    _save!.careerLosses += userRow.lost;
    _save!.careerSeasons += 1;
    if (finalRank == 1) {
      final divisionLabel = currentLeagueTheme.divisionName(playedTier);
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
      lastSeasonManagerAwardName = currentManager?.name;
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
    _changeSupporters(confidenceDelta, SupporterReason.results,
        note: Tr.pick(
            '季末の順位(第${league.season}季 $finalRank位・目標${_save!.boardTargetRank}位)',
            'Season-end finish (season ${league.season}: ${Tr.ordinal(finalRank)}, target: ${Tr.topTarget(_save!.boardTargetRank)})'));
    // 期待への慣れ。勝ち続けるうちにサポーターの目は肥え、満点に張り付いた
    // ままだと緊張が無くなる(放置3シーズンの実測で94〜97に張り付いた)。
    _setSupportersTo(BoardEngine.afterAdaptation(_save!.confidence),
        SupporterReason.results);

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
        _changeSupporters(visionDelta, SupporterReason.events,
            note: Tr.pick('理事会の路線「${_save!.clubVision.label}」の評価',
                'Board direction "${_save!.clubVision.label}"'));
      }
      _logNews(
        visionDelta > 0
            ? Tr.pick('理事会: 今季は「${_save!.clubVision.label}」の路線に沿っていたと評価されました。',
                'The board is satisfied you followed the "${_save!.clubVision.label}" direction.')
            : Tr.pick(
                '理事会: 今季は「${_save!.clubVision.label}」の路線に沿えていなかったと見られています。',
                'The board feels you did not follow the "${_save!.clubVision.label}" direction.'),
        context: Tr.pick('理事会', 'Board'),
      );
    }

    // 株主の期待: 黒字でシーズンを終えれば上がり、赤字なら下がる。
    // 順位と目標の差も3割混ぜる(黒字なら最下位が続いても満点に張り
    // 付いていた。2026-11-23)。
    _save!.shareholderExpectation = ShareholderEngine.applied(
      _save!.shareholderExpectation,
      ShareholderEngine.mixedWithResults(
            financial: ShareholderEngine.deltaForSeasonEnd(
              budget: _save!.budget,
              profit: _save!.ledgerFor(_save!.league.season).profit,
              operatingIncome:
                  _save!.ledgerFor(_save!.league.season).operatingIncome,
              wageRatio: _save!.ledgerFor(_save!.league.season).wageRatio,
            ),
            results: confidenceDelta,
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

    // 年に1回の分割払いを払い、移籍金の1年分を費用にする(償却)。規則の
    // 判定は償却したあとの損益で行う。
    _payAnnualInstallments();
    _amortizeTransferFees();

    // 国の財務規則(収支規則・ライセンス)の判定。違反なら罰を科す。
    _enforceLeagueRules();
    _holdShareholdersMeeting();
    _reviewFiveYearPlan();
    _expireBuyBacks();
    _resetRivalOwners();
    _resolveSeasonRisks();
    _tickProjects();
    _settleAdvisors();
    _save!.declinedProposalIds.clear();
    _recordClubValue();
    _scoreClubPolicy(finalRank: finalRank);
    _advanceEconomy();

    // オーナーは雇われる立場ではないので、理事会との契約(満了で解任)は
    // 持たない(2026-11-23)。任期の知らせは、雇っている監督の契約について
    // 出す(下のスタッフの契約消化のところ)。
    lastManagerContractNote = null;

    // ここから先は新しいシーズン(7月1日)として契約を数える。引退の補充で
    // 作る選手の満了の年も、新しいシーズンから数える。
    Player.contractClockYear = Player.seasonEndYearOf(league.season + 1);

    // 自クラブの部の外(他の部・他国)の選手は練習で育たないので、年に1度
    // 年齢に合わせて伸ばし、衰えさせる。歳は誕生日に1つずつ取る
    // (_ageByBirthdays)ので、ここでは足さない。
    final activeIds = _save!.league.teams.map((t) => t.id).toSet();
    final offscreenRng = Random();
    for (final l in _save!.foreignLeagues.values) {
      for (final t in l.teams) {
        for (final p in t.players) {
          OffscreenDevelopment.apply(p, offscreenRng, tier: 1);
        }
        _generatingFor(
            t,
            () => RetirementEngine.resolveAndReplaceForCpu(t,
                tier: 1));
      }
    }
    for (final t in _save!.allTeams) {
      if (!activeIds.contains(t.id)) {
        final tier = _cpuTierOf(t);
        for (final p in t.players) {
          OffscreenDevelopment.apply(p, offscreenRng, tier: tier);
        }
      }
      // CPUクラブは自クラブ(userTeam、下でRetirementEngine.resolveRetirements
      // を個別に呼ぶ)と違って移籍市場で世代交代しないため、ここで代わりに
      // 引退+若手補充を行う。行わないと選手が永遠に加齢し続けてしまう。
      if (t.id != _save!.userTeamId) {
        // 補充の若手の年俸は、そのクラブのいる部の水準。
        _generatingFor(
            t,
            () => RetirementEngine.resolveAndReplaceForCpu(t,
                tier: _cpuTierOf(t)));
      }
    }
    final infra = _save!.infrastructure;
    // ユースインテーク: 複数候補を一括生成し、選抜はユーザーに委ねる。
    // アカデミーの等級と育成の方針で、入ってくる子の数と質が変わる。
    final category = academyCategory;
    final policy = youthPolicy;
    final intakeCount = 3 +
        Random().nextInt(3) +
        AcademyEngine.extraIntake(category) +
        AcademyEngine.policyExtraIntake(policy);
    // 育成予算の効き。蓄積は毎季末にいまの配分へ近づき、受け入れの質に返る。
    _save!.youthMomentum = YouthInvestmentEngine.nextMomentum(
      momentum: _save!.youthMomentum,
      ratio: BudgetEngine.ratio(_save!.budgetPlan, BudgetCategory.youth),
    );
    final investmentBonus =
        YouthInvestmentEngine.qualityBonus(_save!.youthMomentum) +
            AcademyEngine.qualityBonus(category) +
            AcademyEngine.policyQualityBonus(policy);
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
        tier: _save!.currentDivisionTier,
      ),
    );
    for (final p in _save!.pendingYouthIntake) {
      AcademyEngine.applyPolicy(p, policy);
    }

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
    // この季に降格したクラブ(全部の境界。降格の条項で年俸を下げる)。
    // 降格する前の部と組にする(条項で下げる幅は部の水準で決まる)。
    final relegatedAll = <(Team, int)>[];
    var relevantPlayoffMatches = const <PromotionPlayoffMatch>[];
    // スタジアムの猶予の季が終わる。届いていなければ降格処分(下の
    // adminRelegation の扱い)になる。
    final graceFailed = _settleStadiumGrace();
    // 昇格を決めたのに、上の部のライセンスが下りなかった部(無ければ null)。
    int? licenseDeniedTier;
    var licenseUnmet = const <String>[];
    // スタジアムの段だけが足りずに、猶予つきで上がる部(無ければ null)。
    int? graceTier;
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
        // 下の部の勝ち点(イタリアの2部は、3位が4位を14点以上離せば
        // プレーオフを行わない)。
        tier2Points: {
          for (final r in (lowerTier == playedTier
              ? standings
              : _save!.otherDivisionLeagues[lowerTier - 1]!.sortedStandings))
            r.teamId: r.points,
        },
        // 上の部の勝ち点(イタリアの2部は、16位と17位の差が4点以上なら
        // プレーアウトを行わずに17位が落ちる)。
        tier1Points: {
          for (final r in (upperTier == playedTier
              ? standings
              : _save!.otherDivisionLeagues[upperTier - 1]!.sortedStandings))
            r.teamId: r.points,
        },
      );
      final upperIds = upperOrder.map((t) => t.id).toSet();
      final lowerIds = lowerOrder.map((t) => t.id).toSet();
      final promoted =
          result.tier1.where((t) => !upperIds.contains(t.id)).toList();
      // 自クラブが上がる権利を得ても、ライセンスが下りなければ上がれない。
      // 権利は、まだ上がっていないうちで一番上の順位のクラブに移る。
      final userIdx = promoted.indexWhere((t) => t.id == _save!.userTeamId);
      if (userIdx >= 0) {
        // スタジアムの段だけが足りないなら、1年の猶予つきで上がれる
        // (2026-11-23)。資金など、ほかの条件は今までどおり。
        final unmet = clubLicenseUnmetExceptStadium(upperTier);
        if (unmet.isEmpty && !stadiumMeetsLicense(upperTier)) {
          graceTier = upperTier;
        }
        if (unmet.isNotEmpty) {
          final promotedIds = {for (final t in promoted) t.id};
          final next = lowerOrder.where((t) => !promotedIds.contains(t.id));
          if (next.isNotEmpty) {
            promoted[userIdx] = next.first;
            licenseDeniedTier = upperTier;
            licenseUnmet = unmet;
          }
        }
      }
      final relegated =
          result.tier2.where((t) => !lowerIds.contains(t.id)).toList();
      // フランス式の降格処分: 自クラブを1つ下の部へ落とし、下の部で
      // まだ上がっていないうちの一番上のクラブを代わりに上げる。
      if (_save!.adminRelegation && upperTier == playedTier) {
        final user =
            upperOrder.where((t) => t.id == _save!.userTeamId).firstOrNull;
        if (user != null && !relegated.any((t) => t.id == user.id)) {
          final promotedIds = {for (final t in promoted) t.id};
          final next = lowerOrder.where((t) => !promotedIds.contains(t.id));
          if (next.isNotEmpty) {
            relegated.add(user);
            promoted.add(next.first);
          }
        }
      }
      if (_save!.adminRelegation && lowerTier == playedTier) {
        // 上がる権利を得ていても、降格処分のクラブは上がれない。
        final userIdx = promoted.indexWhere((t) => t.id == _save!.userTeamId);
        if (userIdx >= 0) {
          final promotedIds = {for (final t in promoted) t.id};
          final next = lowerOrder.where((t) => !promotedIds.contains(t.id));
          if (next.isNotEmpty) promoted[userIdx] = next.first;
        }
      }

      outgoingIds[upperTier]!.addAll(relegated.map((t) => t.id));
      outgoingIds[lowerTier]!.addAll(promoted.map((t) => t.id));
      incomingTeams[upperTier]!.addAll(promoted);
      incomingTeams[lowerTier]!.addAll(relegated);
      relegatedAll.addAll([for (final t in relegated) (t, upperTier)]);

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
        final t = withWageLevel(
          wageCountryFactor(theme, tier),
          () => PlayerGenerator.generateSquad(
            id: 's${league.season + 1}_div${tier}_$i',
            name: newClubNames[nameCursor++ % newClubNames.length],
            strengthTier: rollDivisionStrength(tier, resizeRng),
          ),
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
    // 降格処分は、この季の昇格・降格で使い切る。
    _save!.adminRelegation = false;
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
      lastDivisionChangeMessage = graceFailed
          ? Tr.pick('スタジアムがクラブライセンスの条件に届かず、降格になりました。来シーズンは$newTier部リーグでの再出発です。',
              'Your stadium fell short of the club licence, and you are relegated. Next season starts again in Tier $newTier.')
          : Tr.pick('降格が決まりました。来シーズンは$newTier部リーグでの再出発です。',
              'You are relegated. Next season starts again in Tier $newTier.');
    } else if (newTier < playedTier) {
      // 昇格ボーナス: 理事会からの補強予算。放映権の増加は、来季の最初の
      // 入金(8月)から上の部の額で入るので、ここは夏の補強の手付けぶん
      // だけ(BoardEngine.promotionBonusWeeks。2026-11-23 に6週→2週)。
      final promotionBonus =
          BoardEngine.promotionBonusFor(newTier, currentLeagueTheme);
      _book(LedgerCategory.prize, promotionBonus);
      lastPromotionBonus = promotionBonus;
      lastDivisionChangeMessage = userInPromotionPlayoff
          ? Tr.pick(
              '昇格プレーオフを勝ち抜き、来シーズンは$newTier部リーグに昇格します！理事会から補強予算${formatMoney(promotionBonus)}が支給されました。',
              'You came through the play-offs and go up to Tier $newTier next season. The board has given you ${formatMoney(promotionBonus)} to strengthen.')
          : Tr.pick(
              '昇格達成！来シーズンは$newTier部リーグに昇格します。理事会から補強予算${formatMoney(promotionBonus)}が支給されました。',
              'Promoted. You go up to Tier $newTier next season, and the board has given you ${formatMoney(promotionBonus)} to strengthen.');
      // スタジアムが足りないまま上がるなら、来季が猶予の季になる。
      if (graceTier == newTier) {
        final need = ClubLicenseEngine.stadiumLevelFor(newTier);
        final deadline = TransferWindowCalendar.formatYearMonth(
            MoneyCalendar.fiscalYearEnd(league.season + 1));
        _save!.licenseGraceTier = newTier;
        _save!.licenseGraceSeason = league.season + 1;
        final note = Tr.pick(
            'スタジアムは$newTier部のライセンスの条件(Lv$need)に届いていませんが、1年の猶予が付きました。$deadlineまでにLv$needにしないと(来季の開幕までに完成する工事中でも可)、1つ下の部へ降格になります。',
            'Your stadium is below the Tier $newTier licence requirement (level $need), but you have a year\'s grace. Reach level $need by $deadline (work due to finish before the next season counts), or you will be relegated one tier.');
        lastDivisionChangeMessage = '${lastDivisionChangeMessage!}\n$note';
        _logNews(note, context: Tr.pick('クラブライセンス', 'Club licence'));
      }
    } else if (licenseDeniedTier != null) {
      lastDivisionChangeMessage = Tr.pick(
          '昇格の権利を得ましたが、$licenseDeniedTier部のクラブライセンスが下りず、来シーズンも$playedTier部で戦います。足りなかった条件: ${licenseUnmet.join('、')}。',
          'You earned promotion, but were refused a Tier $licenseDeniedTier licence and stay in Tier $playedTier. Missing: ${licenseUnmet.join('; ')}.');
      _logNews(lastDivisionChangeMessage!,
          context: Tr.pick('クラブライセンス', 'Club licence'));
    } else if (userInPromotionPlayoff) {
      lastDivisionChangeMessage = Tr.pick(
          '昇格プレーオフで敗れ、来シーズンも$playedTier部リーグで戦います。',
          'You lost in the play-offs, and stay in Tier $playedTier next season.');
    } else {
      lastDivisionChangeMessage = null;
    }
    lastSeasonFinale = finalRank == 1
        ? SeasonFinale.champion
        : (newTier < playedTier ? SeasonFinale.promoted : SeasonFinale.none);
    _save!.currentDivisionTier = newTier;
    // 降格の条項(年俸を下げる。自クラブも CPU も)と、スポンサー・命名権の
    // 昇格・降格の条項。ファンの需要も成績・昇格・降格で動かす。
    _applyRelegationWageClause(relegatedAll);
    _applySponsorDivisionClause(playedTier, newTier);
    _advanceFanDemand(
        playedTier: playedTier,
        newTier: newTier,
        finalRank: finalRank,
        teamCount: league.teams.length);
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
    // 作り直したリーグ(自国の全部・他国の1部)にも、国ごとの順位の決め方
    // (勝ち点で並んだとき得失点差が先か)を入れる。以前は開始時と読み込み時
    // だけで、季の切り替えで既定に戻っていた(2026-11-23)。
    _applyTieBreakRules();
    // ここから新しいシーズン。契約の残り年数もこのシーズンから数える。
    _syncContractClock();
    // 破綻したクラブの勝ち点の剥奪も、来季の順位表に入れる。
    _applyCollapsePenalties(collapsedClubs);
    // 規則違反の勝ち点剥奪は、来季の順位表に反映する。
    if (_save!.pendingPointsDeduction > 0) {
      _save!.league.pointsAdjustments[_save!.userTeamId] =
          -_save!.pendingPointsDeduction;
      _save!.pendingPointsDeduction = 0;
    }
    _save!.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(_save!.league, _save!.userTeamId,
          relegationZone: ownRelegationZone),
    );
    // 新しい季を迎えたら、最低限の期待を戻す。判断は季末の増減を引く
    // 前に行う(上の supportersGone)。最後通告の期限を過ぎて手放すことが
    // 決まっている場合だけ、そのままにしてその流れを壊さない。底上げで
    // 10以上に戻れば、最後通告も取り下げられる。
    //
    // ただし季末に最後通告の線([GameStateSupporters.ultimatumLine])を
    // 割っていたら底上げしない。新しい季の初日に最後通告を出す
    // (以前は季を終えると最後通告が出ず、新しい季に40へ戻ったので、
    // 何もしないオーナーが毎季最下位でも10季生き残った。2026-11-23)。
    final supporterAfterSeason = _save!.confidence;
    final belowUltimatumLine =
        supporterAfterSeason < GameStateSupporters.ultimatumLine;
    if (!supportersGone &&
        !belowUltimatumLine &&
        _save!.confidence < BoardEngine.newSeasonConfidenceFloor) {
      _setSupportersTo(
          BoardEngine.newSeasonConfidenceFloor, SupporterReason.events,
          note: Tr.pick('新しい季の底上げ', 'New-season floor'));
    }
    // 期待の推移は季ごとに数え直す。始まりの値を1つ置いておく。
    _save!.supporterTrail
      ..clear()
      ..add(_save!.confidence);
    lastSeasonResultLines = _seasonResultLines(
      season: league.season,
      finalRank: finalRank,
      teamCount: league.teams.length,
      targetRank: previousTargetRank,
      playedTier: playedTier,
      newTier: _save!.currentDivisionTier,
      supporterBefore: supporterBefore,
      supporterAfter: supporterAfterSeason,
      supporterNow: _save!.confidence,
      shareholderBefore: shareholderBefore,
      cashChange: _save!.ledgerFor(league.season).cashChange,
      rolloverWages: rolloverWages,
    );
    _save!.wageBudget = BoardEngine.wageBudgetFor(
      tier: _save!.currentDivisionTier,
      currentWeeklyWageBill: weeklyWageBill,
      weeklyIncome: weeklyIncomeFor(_save!.userTeamId),
      theme: currentLeagueTheme,
    );
    transferMarket = [];
    _refreshScoutCandidates();
    // 所属なしの選手も、クラブの選手と同じように歳で引退する(話を進めて
    // いる選手は残す)。
    RetirementEngine.retireFreeAgents(_save!.freeAgents, keep: {
      for (final t in _save!.transferTalks)
        if (t.freeAgent) t.playerId,
    });
    // 夏は契約の切れた選手が数十人単位で所属なしになる。
    FreeAgentEngine.topUp(_save!.freeAgents);

    _rollNamingRights();
    // 時代が変わったら知らせる。
    _announceEra(_save!.league.season);
    // 分析部門の年会費。
    _rollAnalytics();
    // 段階昇給の契約の選手は、季が変わるたびに週給が上がる。
    _applySteppedRaises();
    // 系列クラブの年会費。
    _rollAffiliate();
    // 袖・背中・練習着のスポンサーも1年進め、空いた枠に提示を出す。
    _rollSlotSponsors();
    // スポンサー契約(年単位)はシーズン境界で1年分消化する。
    if (_save!.sponsorDeal != null) {
      _save!.sponsorDeal!.yearsRemaining -= 1;
      if (_save!.sponsorDeal!.yearsRemaining <= 0) {
        _save!.sponsorDeal = null;
      }
    }
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers =
          _economyAdjusted(SponsorEngine.generateOffers(
        userTeam.overallRating,
        tier: _save!.currentDivisionTier,
        managerReputation: _save!.managerReputation,
        stadiumLevel: _save!.infrastructure.facilityLevel(FacilityType.stadium),
      ));
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
      // 雇っている監督の任期。最後の年に入ったら知らせる(延長は引き抜きの
      // 話に昇給で応えたときだけ。切れたら空席になる)。
      if (role == StaffRole.manager) {
        if (s.contractYears <= 0) {
          lastManagerContractNote = Tr.pick(
              '監督の${s.name}は契約が満了し、クラブを去りました。新しい監督を雇ってください。',
              'Your manager ${s.name} has left at the end of his contract. Hire a new one.');
        } else if (s.contractYears == 1) {
          lastManagerContractNote = Tr.pick('監督の${s.name}の契約は残り1年です(今季かぎり)。',
              'Your manager ${s.name} is into the last year of his contract.');
        }
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
      final signing = FreeAgentEngine.generateEmergencySigning(
          squadMedian: _squadMedianOverall);
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings.add(signing.name);
    }
    if (lastEmergencySignings.isNotEmpty) LineupUtils.fillVacancies(userTeam);
    // 引退・満了の補充で作った選手(他のクラブ)にも、国籍と国内育成の印を
    // 決めて名前を国籍に合わせる。以前は読み込み時にだけ直していて、
    // 再起動すると名前・国籍・登録の枠の数が変わっていた(2026-11-23)。
    _localizeNames();

    _save!.lastSeasonRank = finalRank;

    final cupsWonThisSeason = [
      ..._save!.cups
          .where((c) => c.championId == _save!.userTeamId)
          .map((c) => c.name),
      for (final c in continentalCups)
        if (c.championId == _save!.userTeamId) c.name,
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
        wonDomesticCup: _save!.cups.any((c) =>
            c.type == CupType.domestic && c.championId == _save!.userTeamId),
      ),
    );
    _closeRivalSeason();
    if (finalRank == 1) {
      _addTimeline(
          Tr.pick('$playedTier部リーグで優勝', 'Won the Tier $playedTier league'));
    }
    if (newTier < playedTier) {
      _addTimeline(Tr.pick('$newTier部へ昇格', 'Promoted to Tier $newTier'));
    }
    if (newTier > playedTier) {
      _addTimeline(Tr.pick('$newTier部へ降格', 'Relegated to Tier $newTier'));
    }
    _updateParachute(playedTier: playedTier, newTier: newTier);
    for (final cup in cupsWonThisSeason) {
      _addTimeline(Tr.pick('$cupで優勝', 'Won $cup'));
    }
    _evaluateAchievements(season: league.season);
    _evaluateOwnerGoal(season: league.season);

    // スーパーカップ: 1部の王者と国内カップの王者(同じクラブなら、カップの
    // 準優勝クラブ)。2部・3部にはスーパーカップは無い(実在の形。それまでは
    // 自クラブのいる部の優勝クラブで組んでいた)。国内カップは1〜3部の
    // 全クラブが出るので、カップの王者は下の部のクラブのこともある。
    // スペイン・イタリアは4クラブで1月ごろ(下の _newFourClubSuperCup)。
    // カップが未消化のままシーズンが終わった場合は開催しない。
    lastSuperCupNews = null;
    Cup? previousDomesticCup;
    for (final c in _save!.cups) {
      if (c.type == CupType.domestic) {
        previousDomesticCup = c;
        break;
      }
    }
    final tier1FinalOrder = tierOrder[1]!;
    final tier1Ids = tier1FinalOrder.map((t) => t.id).toList();
    if (previousDomesticCup != null &&
        !currentLeagueTheme.fourClubSuperCup &&
        tier1Ids.isNotEmpty) {
      final pairing = SuperCupEngine.pairing(
        leagueChampionId: tier1Ids.first,
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
          // 自クラブの出ない試合は、裏の試合と同じ軽い計算で決める。
          final result = BackgroundMatchEngine.simulate(
            home: champion,
            away: opponent,
            matchday: 0,
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

    // 国内カップは1〜3部の全クラブ、リーグカップはイングランドだけ。
    _save!.cups = _newSeasonCups();
    final fourClub = _newFourClubSuperCup(tier1Ids, previousDomesticCup);
    if (fourClub != null) _save!.cups.add(fourClub);
    _save!.boardCupTargetRound = _estimateDomesticCupTarget();
    // 大陸大会: 自国の1部の上位(CL 5/4/3枠、その下と国内カップの優勝が
    // EL)と、他国の1部の上位。自クラブが出ない季も大会は行われる。
    _save!.continentalCup = null;
    _save!.secondContinentalCup = null;
    _setUpContinentalCups(
      tier1Order: tier1FinalOrder,
      domesticCupWinnerId: previousDomesticCup?.championId,
    );
    _save!.friendlies = _generateFriendlies(newActiveTeams, _save!.userTeamId);
    // 新しいシーズンはオフ(7月1日)から始まる。夏の窓が開くので名簿の外
    // だった選手も戻り、シーズン末までのローンはここで終わる。
    // 週の処理の時計は、新しい季の最初の節で起こし直す(オフには回さない)。
    _save!.lastWeeklyTickDate = null;
    _setToday(SeasonCalendar.preseasonDate(_save!.league.season));
    // 季末に最後通告の線を割っていたら、新しい季の初日に最後通告を出す。
    if (!supportersGone && belowUltimatumLine) _checkSupporterUltimatum();
    _settleLoansByDate();
    _startSummerTournament();
    // 切り替えの途中で組み直した CPU の先発は、その時にケガ・代表で抜けて
    // いた選手を外して11人に満たないことがある。夏の大会の休みを決めた後に、
    // 欠けた先発を埋める(試合の前の安全網と同じ)。
    _topUpCpuLineups();
    _pruneScoutKnowledge();
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
      // プレイヤーはオーナーで、賞を受けるのは雇っている監督(2026-11-23)。
      final name = lastSeasonManagerAwardName;
      _logNews(
          Tr.pick(
              name == null
                  ? 'クラブの監督が年間最優秀監督賞を受賞しました！'
                  : '監督の$nameが年間最優秀監督賞を受賞しました！',
              '${name ?? 'Your manager'} won Manager of the Year!'),
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
    if (lastLoanEndings.isNotEmpty) {
      _logNews(
          Tr.pick('ローン期間満了で貸し元へ復帰: ${lastLoanEndings.join('、')}',
              "Loan spells ended, returned to their parent clubs: ${lastLoanEndings.join(', ')}"),
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

  /// [before]の翌日から[after]までに誕生日が来た選手に、1つ歳を足す。
  /// 殿堂入りした選手は引退したときの歳のまま。
  ///
  /// 日を送るたびに呼ばれる(1日ずつのことが多い)。同じ年の中なら、誕生日が
  /// 月日の範囲に入る選手だけを整数で比べて選ぶ([Player.birthdaysBetween]
  /// と同じ結果)。範囲に誰の誕生日も無ければ何もしない。
  void _ageByBirthdays(DateTime before, DateTime after) {
    if (!after.isAfter(before)) return;
    final s = _save!;
    final legends = Set<Player>.identity()..addAll(s.retiredLegends);
    if (before.year == after.year) {
      final from = Player.monthDayKey(before);
      final to = Player.monthDayKey(after);
      if (from >= to) return;
      for (final p in s.allPlayers) {
        final k = p.birthdayKey;
        if (k <= from || k > to) continue;
        if (legends.contains(p)) continue;
        p.age += 1;
      }
      return;
    }
    for (final p in s.allPlayers) {
      if (legends.contains(p)) continue;
      final n = p.birthdaysBetween(before, after);
      if (n > 0) p.age += n;
    }
  }

  /// 今年の夏の大会。無い年は null。
  SummerTournament? get summerTournament =>
      _save == null ? null : SummerTournament.of(today.year);

  /// 大会に出た選手がまだ合流していなければ、その合流の日。
  DateTime? get tournamentReturnDate {
    final t = summerTournament;
    if (t == null || !today.isBefore(t.returnDate)) return null;
    return t.returnDate;
  }

  /// 7月1日、前の夏の大会の評判を消し、今年の大会に出た選手を決める。
  /// 出た選手は合流の日まで休み、活躍した選手は市場価値が上がる。
  void _startSummerTournament() {
    for (final t in _worldTeams) {
      for (final p in t.players) {
        p.tournamentBoostPct = 0;
        p.onTournamentLeave = false;
      }
    }
    final tournament = summerTournament;
    if (tournament == null) return;
    final back = tournament.returnDate;
    final away = today.isBefore(back);
    final mine = <Player>[];
    for (final t in _worldTeams) {
      for (final p in t.players) {
        if (!tournament.plays(p)) continue;
        p.tournamentBoostPct = tournament.boostPctFor(p);
        if (away) {
          p.onTournamentLeave = true;
          if (t.id == _save!.userTeamId) mine.add(p);
        }
      }
    }
    if (mine.isEmpty) return;
    LineupUtils.autoFill(userTeam);
    final names = mine.map((p) => p.name).join(Tr.pick('、', ', '));
    _logNews(
      Tr.pick(
        '${tournament.name}に出た$namesは、大会のあとの休みを取って${TransferWindowCalendar.formatMonthDay(back)}に合流します。それまでは試合に出せません。',
        '$names played at the ${tournament.name} and rejoin on ${TransferWindowCalendar.formatMonthDay(back)} after their break. They cannot play until then.',
      ),
      context: Tr.pick('代表', 'International'),
    );
  }

  /// 合流の日を越えたら、休んでいた選手を戻す。休み明けは体が仕上がって
  /// いないので、疲れが少し残った状態で戻る。
  void _endTournamentLeaveIfDue(DateTime before, DateTime after) {
    final tournament = SummerTournament.of(after.year);
    if (tournament == null) return;
    final back = tournament.returnDate;
    if (!before.isBefore(back) || after.isBefore(back)) return;
    final mine = <Player>[];
    for (final t in _worldTeams) {
      for (final p in t.players) {
        if (!p.onTournamentLeave) continue;
        p.onTournamentLeave = false;
        if (p.fatigue < tournamentReturnFatigue) {
          p.fatigue = tournamentReturnFatigue;
        }
        if (t.id == _save!.userTeamId) mine.add(p);
      }
    }
    if (mine.isEmpty) return;
    _logNews(
      Tr.pick(
        // 先発は監督が決める(オーナーは選ばない)。2026-11-23 に監督型の
        // 「編成の画面で決めてください」から改めた。
        '${mine.map((p) => p.name).join('、')}が${tournament.name}のあとの休みを終えて合流しました。先発に戻すかは監督が決めます。',
        '${mine.map((p) => p.name).join(', ')} rejoined after the ${tournament.name} break. The manager will decide when they go back in the side.',
      ),
      context: Tr.pick('代表', 'International'),
    );
  }
}

/// 夏の大会の休みから戻った選手の疲れ(これより低ければここまで上げる)。
const int tournamentReturnFatigue = 30;
