part of 'game_state.dart';

/// 週の処理は日付で回す(2026-11-22)。
///
/// 以前は練習・不満・ユース・ローンなどの「週ごと」の処理を、リーグの節を
/// 1つ消化するたびに1回走らせていた。そのため代表ウィークやドイツの冬休み
/// (約3.5週)が1週扱いになり、イングランドの年末の3連戦(数日おき)が
/// 3週扱いになって、怪我が3週分治っていた。
///
/// いまは:
/// - 週の処理([_runWeeklyTick])は、最後に週の処理をした日
///   ([SaveGame.lastWeeklyTickDate])から7日たつごとに1回走る。日付を
///   進めたとき([GameState._setToday])に、またいだ週の数だけ回す。
///   季の初め(と、その日を持たない旧セーブ)は、その季で最初に節を消化する
///   日に1回行い、その日を起点にする。リーグ戦を全部終えたら止まる。
/// - 怪我の回復と疲れの抜けは日数で進める([_recoverByDays])。
/// - 過密日程は、自クラブの試合の日付の間隔で判定する([_noteUserMatchDay])。
/// - 試合ごとに起きるもの(試合の疲れ・出場・毎節の収入・出場手当など)は
///   試合ごとのまま([GameStateMatch.playNextMatchday])。
extension GameStateWeek on GameState {
  /// 疲れが1日に抜ける量。以前の「節ごとに14」を7日で割ったもの。
  static const int fatigueRecoveryPerDay = 2;

  /// 前の試合からこの日数以内に次の試合があれば、過密日程とみなす。
  static const int congestionMaxDays = 3;

  /// 2つの日付のあいだの日数(夏時間の切り替えでずれないよう UTC で数える)。
  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// 今季、週の処理がおよそ何回走るか(第1節の日から最終節の日まで)。
  int get weeklyTicksThisSeason {
    final cal = seasonCalendar;
    if (cal.totalMatchdays == 0) return 0;
    return _daysBetween(cal.firstMatchDate, cal.lastMatchDate) ~/ 7 + 1;
  }

  /// 1季の成長・衰えの総量を、節ごとに回していた頃に揃える倍率
  /// (節の数 ÷ 週の数)。週の数は国や節の数によらずおよそ40〜44で、
  /// 節の数(34〜46)と一致しないため、そのままだと国によって1季の成長が
  /// 1〜2割変わる。
  double get _weeklyGrowthScale {
    final ticks = weeklyTicksThisSeason;
    final total = _totalMatchdaysThisSeason;
    if (ticks <= 0 || total <= 0) return 1.0;
    return (total / ticks).clamp(0.5, 1.5);
  }

  /// [anchor]を起点に、週の処理の時計が動いているか。今季の日付で、
  /// リーグ戦が残っている間だけ動く(オフには練習もユースの試合もない)。
  bool _weeklyClockRunning(DateTime anchor) {
    final s = _save!;
    if (s.league.nextUnplayedFixture == null) return false;
    return !anchor.isBefore(SeasonCalendar.preseasonDate(s.league.season));
  }

  /// 今日が[before]から[d]へ進むあいだの、日数で進む処理と週の処理。
  /// 週の処理の日には今日をその日にしてから回す。最後に今日は[d]になる。
  void _advanceDaysAndWeeks(DateTime before, DateTime d) {
    final s = _save!;
    var cursor = before;
    while (true) {
      final anchor = s.lastWeeklyTickDate;
      if (anchor == null || !_weeklyClockRunning(anchor)) break;
      final tickDay = DateTime(anchor.year, anchor.month, anchor.day + 7);
      if (tickDay.isAfter(d)) break;
      if (tickDay.isAfter(cursor)) {
        _recoverByDays(_daysBetween(cursor, tickDay));
        cursor = tickDay;
      }
      s.today = tickDay;
      s.lastWeeklyTickDate = tickDay;
      _runWeeklyTick();
    }
    if (d.isAfter(cursor)) _recoverByDays(_daysBetween(cursor, d));
    s.today = d;
    // オフの6月の代表ウィークが始まっていれば呼ぶ(週の処理は止まっている)。
    _callUpForJuneWindow(before, d);
    // 代表ウィークが終わっていれば、代表の選手はクラブに戻る。
    _releaseInternationalDuty();
  }

  /// その季で最初に節を消化するとき(と、最後に週の処理をした日を持たない
  /// 旧セーブ)は、ここで週の処理を1回行い、今日を起点にする。
  void _startWeeklyClockIfNeeded() {
    final s = _save!;
    final anchor = s.lastWeeklyTickDate;
    if (anchor != null && _weeklyClockRunning(anchor)) return;
    s.lastWeeklyTickDate = today;
    _runWeeklyTick();
  }

  /// [days]日ぶんの怪我の回復と疲れの抜け(リーグの全クラブ)。
  /// 離脱「◯週」は7日×週で治る。休養日ぶんの疲れの抜けは、練習の方針と
  /// 別に全員へかける(CPUクラブは練習を選べず、これが無いと試合の疲れ
  /// だけが積もる)。治った直後は試合勘が鈍っている。
  void _recoverByDays(int days) {
    if (days <= 0) return;
    final s = _save!;
    for (final t in s.league.teams) {
      final mine = t.id == s.userTeamId;
      for (final p in t.players) {
        if (p.injuryWeeks > 0) {
          p.injuryDays += days;
          while (p.injuryWeeks > 0 && p.injuryDays >= 7) {
            p.injuryDays -= 7;
            p.injuryWeeks -= 1;
            if (p.injuryWeeks > 0) continue;
            // 自クラブの選手が治ったら、保存療法の再発を振る。
            if (mine &&
                _onUserInjuryHealed(p, GameState._offerRng.nextDouble())) {
              p.injuryDays = 0;
              break;
            }
            p.matchSharpness = min(p.matchSharpness, 40);
            p.injuryType = null;
          }
          if (p.injuryWeeks == 0) p.injuryDays = 0;
        } else {
          p.injuryDays = 0;
        }
        p.fatigue = (p.fatigue - fatigueRecoveryPerDay * days).clamp(0, 100);
      }
    }
  }

  /// 週の処理を1回。今日はその週の日になっている。
  void _runWeeklyTick() {
    final s = _save!;
    final league = s.league;
    final md = league.nextUnplayedFixture?.matchday;
    final newsWeek = md == null
        ? Tr.pick('週の処理', 'Weekly')
        : Tr.pick('第$md節', 'Matchday $md');
    final weekScale = _weeklyGrowthScale;

    // 練習はコーチ陣の仕事。オーナーは触れないので、週ごとに必ず行う。
    s.trainingDoneThisWeek = false;
    _runTrainingSession();

    // ユーザークラブのみローン期間を処理する(CPUクラブは対象外)。
    // 選手契約自体は年単位で結ばれ、シーズン開始時にまとめて消化する
    // (startNextSeason参照)。
    final loanEnded = ContractEngine.advanceLoanWeek(userTeam, today: today);
    for (final p in loanEnded) {
      _clearPlayerRoleReferences(userTeam, p.id);
    }
    if (loanEnded.isNotEmpty) {
      lastContractExpirations = [
        ...lastContractExpirations,
        ...loanEnded.map((p) => p.name),
      ];
    }
    lastContractWarnings = [];
    // 所属なしの選手は、季が進むにつれて他のクラブと契約して減っていく
    // (話を進めている選手は残す)。
    FreeAgentEngine.weeklyDrift(s.freeAgents, today, keep: {
      for (final t in s.transferTalks)
        if (t.freeAgent) t.playerId,
    });
    // ローン満了により編成人数が最低人数を割り込んだ場合、フリーエージェントを
    // 緊急補強してスカッドが組めなくなる事態を防ぐ(安全網)。
    while (userTeam.players.length < minSquadSize) {
      final signing = FreeAgentEngine.generateEmergencySigning(
          squadMedian: _squadMedianOverall);
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings = [...lastEmergencySignings, signing.name];
    }
    // ローン満了でスタメンから外れた枠を埋める。埋めないと10人で戦う。
    if (loanEnded.isNotEmpty) {
      LineupUtils.fillVacancies(userTeam);
    }

    // 選手の不満度を更新する。
    final rank = league.sortedStandings.indexWhere(
          (r) => r.teamId == s.userTeamId,
        ) +
        1;
    HappinessEngine.applyWeekly(
      userTeam,
      leagueRank: rank,
      boardTargetRank: s.boardTargetRank,
    );
    // 監督の立場(目標の順位との比べ)と、若手を使う監督の効き目。
    _updateManagerWeekly(rank);
    // 先発に仲の良い選手・仲の悪い選手がいるか。
    RelationsEngine.applyWeekly(userTeam);
    if (userTeam.tacticalMeetingCooldownWeeks > 0) {
      userTeam.tacticalMeetingCooldownWeeks -= 1;
    }
    // CPUクラブにも同様に反映する(目標順位という概念がないため、自クラブの
    // 順位をそのまま目標として扱い、出場機会・待遇の要素のみ効かせる)。
    for (final t in league.teams) {
      if (t.id == s.userTeamId) continue;
      final r = league.sortedStandings.indexWhere((x) => x.teamId == t.id) + 1;
      HappinessEngine.applyWeekly(t, leagueRank: r, boardTargetRank: r);
    }

    // 分割払いの引き落とし・融資の返済・定期預金の経過(週単位)。
    // 年に1回払う分割払い(2026-11-22 から)は、季の締めに払う。
    for (final inst in List<Installment>.from(s.pendingInstallments)) {
      if (inst.annual) continue;
      _payInstallment(inst, inst.weeklyAmount);
      inst.weeksRemaining -= 1;
      if (inst.weeksRemaining <= 0) {
        s.pendingInstallments.remove(inst);
      }
    }
    for (final loan in List<BankLoan>.from(s.bankLoans)) {
      _repayLoanWeek(loan);
      loan.weeksRemaining -= 1;
      if (loan.weeksRemaining <= 0) {
        s.bankLoans.remove(loan);
      }
    }
    final matured = <FixedDeposit>[];
    for (final deposit in List<FixedDeposit>.from(s.fixedDeposits)) {
      deposit.weeksRemaining -= 1;
      if (deposit.weeksRemaining <= 0) {
        _settleDepositMaturity(deposit);
        s.fixedDeposits.remove(deposit);
        matured.add(deposit);
      }
    }
    lastMaturedDeposits = [...lastMaturedDeposits, ...matured];

    // 移籍オファーの週次処理(期限切れ削除・新規発生・リリース条項の自動成立)。
    final autoSold = _advanceIncomingOffers();
    lastReleaseClauseSales = [...lastReleaseClauseSales, ...autoSold];

    // 代表召集の週次処理(期間終了・新規招集抽選。スタメン欠員は自動で埋める)。
    final calledUp = _advanceInternationalDuty();
    lastInternationalCallUps = [...lastInternationalCallUps, ...calledUp];

    // CPUクラブ同士の移籍市場の週次処理(ユーザーは関与しない)。
    // 他のクラブも窓が開いている間しか移籍しない。窓の間は毎週、
    // 移籍金付きで何件も動く(_advanceAiTransfers)。返るのはニュースに
    // 出す主力の移籍。
    final aiNews =
        isTransferWindowOpen ? _advanceAiTransfers() : const <String>[];

    // CPUクラブの簡易的な週次成長(施設・スタッフの上乗せは無いが、
    // 何もしないとユーザーだけが伸び続けリーグ全体が停滞するため)。
    // あわせてセットプレー担当も自動更新し、移籍で放出入りした穴を埋める。
    for (final t in league.teams) {
      if (t.id == s.userTeamId) continue;
      TrainingEngine.applyPassiveCpuGrowth(t, weekScale: weekScale);
      LineupUtils.autoAssignSetPieceRoles(t);
    }

    // 昇格候補(有望株)はユース施設で育成され続ける。
    TrainingEngine.applyYouthAcademyGrowth(
      s.youthProspects,
      s.infrastructure.facilityLevel(FacilityType.youthFacility),
      coachSpecialty:
          s.infrastructure.staffFor(StaffRole.youthCoach)?.specialty ??
              StaffSpecialty.balanced,
      coachLevel: youthCoachCoachingLevel,
      weekScale: weekScale,
    );

    // 昇格の見込みが立たない有望株は、ユースを去る。
    final departures = YouthDepartureEngine.resolveWeekly(
      s.youthProspects,
      facilityLevel: s.infrastructure.facilityLevel(FacilityType.youthFacility),
    );
    lastYouthDepartures = [...lastYouthDepartures, ...departures];
    for (final d in departures) {
      _book(LedgerCategory.playerSales, d.compensation);
      _logNews(
        d.poached
            ? Tr.pick(
                'ユースの${d.player.name}が他クラブに引き抜かれました(育成補償金 ${formatMoney(d.compensation)})',
                'Academy player ${d.player.name} was poached by another club (compensation ${formatMoney(d.compensation)})')
            : Tr.pick(
                'ユースの${d.player.name}が出場機会を求めてクラブを去りました(育成補償金 ${formatMoney(d.compensation)})',
                'Academy player ${d.player.name} left in search of first-team football (compensation ${d.compensation})'),
        context: Tr.pick('ユース', 'Youth'),
      );
    }

    _playYouthWeek();

    // ローン放出の週次処理(期間終了で自動的にチームへ復帰する)。
    final returnsBefore = lastLoanReturns.length;
    for (final p in userTeam.players.where((p) => p.isLoanedOut).toList()) {
      // 武者修行: 貸出先で毎週実戦に出て成長する(若手ほど効果大)。
      TrainingEngine.applyLoanDevelopment(p, weekScale: weekScale);
      final until = p.loanedOutUntil;
      if (until != null) {
        // 日付で持つ貸し出しは、戻る日に届いたら戻す。
        if (!today.isBefore(until)) {
          _returnFromLoan(p);
        } else {
          final days = TransferWindowCalendar.daysBetween(today, until);
          p.loanedOutWeeksRemaining = max(1, (days / 7).ceil());
        }
        continue;
      }
      // 日付の無い貸し出し(旧セーブを読む前に作った選手など)は週数で数える。
      p.loanedOutWeeksRemaining -= 1;
      if (p.loanedOutWeeksRemaining <= 0) _returnFromLoan(p);
    }
    final loanReturns = lastLoanReturns.sublist(returnsBefore);

    // 成長推移の記録(自クラブの選手とユース昇格候補のみ)。
    for (final p in userTeam.players) {
      TrainingEngine.recordOverallHistory(p);
    }
    for (final p in s.youthProspects) {
      TrainingEngine.recordOverallHistory(p);
    }

    // 資金のマイナスが何週続いているか。
    if (s.budget < 0) {
      s.consecutiveNegativeBudgetWeeks += 1;
    } else {
      s.consecutiveNegativeBudgetWeeks = 0;
    }
    // 給料が払えない状態が続くと、選手は催告のうえ契約を解除できる。
    _checkUnpaidWages();
    final budgetConfidenceDelta = BoardEngine.negativeBudgetConfidenceDelta(
      s.consecutiveNegativeBudgetWeeks,
    );
    String? crisis;
    if (budgetConfidenceDelta != 0) {
      // 資金のマイナスは、成績に由来する信頼度ではなく株主の期待を下げる。
      s.shareholderExpectation = ShareholderEngine.applied(
        s.shareholderExpectation,
        budgetConfidenceDelta,
      );
      crisis = Tr.pick(
          '資金マイナスが${s.consecutiveNegativeBudgetWeeks}週続いています。株主の期待が低下しました。借金が${formatMoney(-fundsExhaustedLine)}を超えると、クラブを手放すことになります。',
          "You have been in the red for ${Tr.plural(s.consecutiveNegativeBudgetWeeks, 'week')}. The shareholders' confidence has slipped. If the debt passes ${formatMoney(-fundsExhaustedLine)}, you will have to sell the club.");
      lastBudgetCrisisWarning = crisis;
    }

    transferOffersRejectedThisWeek.clear();

    // この週に起きたことをクラブニュースにも残す。
    if (autoSold.isNotEmpty) {
      _logNews(
          Tr.pick('リリース条項が発動し移籍が成立: ${autoSold.join('、')}',
              "Release clauses triggered, transfers completed: ${autoSold.join(', ')}"),
          context: newsWeek);
    }
    if (calledUp.isNotEmpty) {
      _logNews(
          Tr.pick('代表召集: ${calledUp.join('、')}',
              "Called up for international duty: ${calledUp.join(', ')}"),
          context: newsWeek);
    }
    if (loanReturns.isNotEmpty) {
      _logNews(
          Tr.pick('ローン放出から復帰: ${loanReturns.join('、')}',
              "Back from loan: ${loanReturns.join(', ')}"),
          context: newsWeek);
    }
    if (matured.isNotEmpty) {
      final maturedTotal = matured.fold<int>(0, (t, d) => t + d.maturityValue);
      _logNews(
          Tr.pick('定期預金が満期を迎え、${formatMoney(maturedTotal)}が払い戻されました',
              'Your deposit matured and ${formatMoney(maturedTotal)} was paid back'),
          context: newsWeek);
    }
    for (final n in aiNews) {
      _logNews(Tr.pick('移籍市場: $n', 'Transfer market: $n'), context: newsWeek);
    }
    if (crisis != null) {
      _logNews(crisis, context: newsWeek);
    }
  }

  /// ユースの週: 練習試合を年間の順位表にまとめる。勝敗が何にも残らないと、
  /// ユースで勝たせて育てるという選び方ができない。候補が居ない年は作らない。
  void _playYouthWeek() {
    final s = _save!;
    if (s.youthProspects.isNotEmpty) {
      s.youthLeague ??= YouthLeagueEngine.create(
        prospectAverage: YouthLeagueEngine.prospectAverage(s.youthProspects),
      );
    }
    final youthLeague = s.youthLeague;
    final leagueOpponent = youthLeague == null || youthLeague.isComplete
        ? null
        : YouthLeagueEngine.opponentStrengthFor(youthLeague);

    // ユース練習試合: 昇格候補たちが毎週実戦を経験し、出場数・得点・評点を
    // 積み重ねる。大活躍(複数得点・高評点)はクラブニュースに届く。
    lastYouthMatchReport = YouthMatchEngine.playWeekly(
      s.youthProspects,
      opponentStrength: leagueOpponent,
    );

    // リーグ戦として記録する。全節終わったら、その年の結果を知らせる。
    if (youthLeague != null &&
        !youthLeague.isComplete &&
        lastYouthMatchReport != null) {
      final md = YouthLeagueEngine.recordUserResult(
        youthLeague,
        goalsFor: lastYouthMatchReport!.teamGoals,
        goalsAgainst: lastYouthMatchReport!.opponentGoals,
      );
      if (md != null && youthLeague.isComplete) {
        final rank = youthLeague.userRank;
        _logNews(
          rank == 1
              ? Tr.pick('ユースリーグ優勝! 全${YouthLeague.matchdayCount}節を終えて1位',
                  'Your academy won the youth league, top after ${YouthLeague.matchdayCount} rounds')
              : Tr.pick(
                  'ユースリーグが終了。$rank位(勝点${youthLeague.userStanding.points})',
                  'The youth league finished. You came $rank (${youthLeague.userStanding.points} pts)'),
          context: Tr.pick('ユース', 'Youth'),
        );
        final scorer = YouthLeagueEngine.topScorer(s.youthProspects);
        if (scorer != null) {
          _logNews(
            Tr.pick('ユースの得点王は${scorer.name}(${scorer.youthMatchGoals}得点)',
                'Academy top scorer: ${scorer.name} (${scorer.youthMatchGoals} goals)'),
            context: Tr.pick('ユース', 'Youth'),
          );
        }
      }
    }
    final youthReport = lastYouthMatchReport;
    if (youthReport != null) {
      for (final perf in youthReport.performances) {
        if (perf.goals >= 2) {
          _logNews(
            Tr.pick(
                'ユースの${perf.player.name}が練習試合で${perf.goals}得点の大活躍(評点${perf.rating.toStringAsFixed(1)})',
                'Academy player ${perf.player.name} scored ${perf.goals} in the youth match (rated ${perf.rating.toStringAsFixed(1)})'),
            context: Tr.pick('ユース', 'Youth'),
          );
        } else if (perf.rating >= 8.5) {
          _logNews(
            Tr.pick(
                'ユースの${perf.player.name}が練習試合で圧巻のプレー(評点${perf.rating.toStringAsFixed(1)})',
                'Academy player ${perf.player.name} was outstanding in the youth match (rated ${perf.rating.toStringAsFixed(1)})'),
            context: Tr.pick('ユース', 'Youth'),
          );
        }
      }
    }
  }

  /// 自クラブの公式戦の日(今日)を記録し、前の試合から[congestionMaxDays]日
  /// 以内なら過密日程として先発に疲れを足す。リーグ戦は試合の前に、
  /// カップ戦は結果を入れたときに呼ぶ。
  void _noteUserMatchDay() {
    final s = _save!;
    final day = today;
    final last = s.lastUserMatchDate;
    if (last != null && !day.isAfter(last)) return; // 同じ日の二度呼び
    s.lastUserMatchDate = day;
    final gap = last == null ? null : _daysBetween(last, day);
    s.lastWeekCongested = gap != null && gap <= congestionMaxDays;
    if (!s.lastWeekCongested) return;
    for (final p in userTeam.players) {
      if (!userTeam.startingXI.contains(p.id)) continue;
      p.fatigue =
          (p.fatigue + GameStateCongestion.congestionFatigue).clamp(0, 100);
    }
    _logNews(
        Tr.pick('過密日程: 前の試合から$gap日。先発の疲れが残っている。',
            'Fixture pile-up: only ${Tr.plural(gap!, 'day')} since the last match. The starters are tired.'),
        context: Tr.pick('日程', 'Schedule'));
  }

  /// テスト用: 自クラブの試合の日を記録する(過密日程の判定)。
  @visibleForTesting
  void debugNoteUserMatchDay() => _noteUserMatchDay();

  /// テスト用: 日数で進む回復を走らせる。
  @visibleForTesting
  void debugRecoverByDays(int days) => _recoverByDays(days);
}
