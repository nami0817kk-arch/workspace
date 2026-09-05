part of 'game_state.dart';

/// 試合: ライブ進行・交代・試合実行・マイルストーン/実績・クイックシム。
extension GameStateMatch on GameState {
  /// フィジオ・メディカルセンターのレベルに応じた負傷の発生率・療養期間の
  /// 軽減係数(1.0で軽減なし)。両方に投資するほど軽減幅が大きくなる。
  double get _userInjuryFactor =>
      ClubInfrastructure.injuryFactor(
        _save!.infrastructure.staffLevel(StaffRole.physio),
      ) *
      ClubInfrastructure.medicalCenterInjuryFactor(
        _save!.infrastructure.facilityLevel(FacilityType.medicalCenter),
      );

  double _injuryFactorFor(String teamId) =>
      teamId == _save!.userTeamId ? _userInjuryFactor : 1.0;

  /// ホームアドバンテージ係数。自クラブが主催する試合は実際の観客動員率
  /// (収容人数に対する割合)に応じて変動する(満員に近いほど大きい)。
  /// 他クラブの主催試合は観客動員を管理していないため既定値のまま。
  double _homeAdvantageFor(String homeTeamId) {
    if (_save == null || homeTeamId != _save!.userTeamId) {
      return MatchEngine.defaultHomeAdvantageFactor;
    }
    final capacity = stadiumCapacity;
    final ratio =
        capacity <= 0 ? 0.0 : (expectedAttendance / capacity).clamp(0.0, 1.0);
    // 満員ならCPU既定値を上回り、ガラガラなら下回る(中央値≒既定値)。
    return MatchEngine.defaultHomeAdvantageFactor - 0.04 + 0.08 * ratio;
  }

  /// ライブ観戦中のカップ試合の要約(なければnull)。LiveMatchScreenが
  /// リーグの[liveFixture]の代わりに参照する。
  ({
    String homeTeamId,
    String awayTeamId,
    Weather weather,
    String competitionLabel,
  })? get liveCupDescriptor {
    final kind = _liveCupKind;
    if (kind == null || _liveCupHome == null || _liveCupAway == null) {
      return null;
    }
    return (
      homeTeamId: _liveCupHome!.id,
      awayTeamId: _liveCupAway!.id,
      weather: _liveCupWeather ?? Weather.clear,
      competitionLabel: switch (kind) {
        LiveCupKind.domestic =>
          domesticCup?.name ?? Tr.pick('国内カップ', 'Domestic Cup'),
        LiveCupKind.continentalGroup ||
        LiveCupKind.continentalKnockout =>
          _save?.continentalCup?.name ?? Tr.pick('大陸カップ', 'Continental Cup'),
        LiveCupKind.superCup => Tr.pick('スーパーカップ', 'Super Cup'),
      },
    );
  }

  /// 進行中のライブ試合のホーム/アウェイ(リーグ・カップ共通)。
  Team? get _liveHomeTeam {
    if (_liveCupHome != null) return _liveCupHome;
    final f = _liveFixture;
    if (f == null || _save == null) return null;
    return _save!.league.teams.firstWhere((t) => t.id == f.homeTeamId);
  }

  Team? get _liveAwayTeam {
    if (_liveCupAway != null) return _liveCupAway;
    final f = _liveFixture;
    if (f == null || _save == null) return null;
    return _save!.league.teams.firstWhere((t) => t.id == f.awayTeamId);
  }

  Weather get _liveWeatherNow =>
      _liveCupWeather ?? _liveFixture?.weather ?? Weather.clear;

  /// IDからチームを探す(自リーグ+カップ参加チーム全体。見つからなければnull)。
  /// 大陸カップの外国クラブなど、リーグ順位表に存在しないチームの表示に使う。
  Team? teamById(String id) {
    if (_save == null) return null;
    for (final t in allTeamsForCups) {
      if (t.id == id) return t;
    }
    for (final t in _save!.allTeams) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 自クラブの試合が前半終了・ハーフタイム待ちの状態かどうか。
  bool get isHalfTime =>
      (_liveFixture != null || _liveCupKind != null) &&
      (_liveFirstHalfState?.isFinished ?? false) &&
      _liveSecondHalfState == null;

  Fixture? get liveFixture => _liveFixture;

  /// 前半が完了した場合のみ結果を返す(判断待ちの間はnull)。
  HalfResult? get liveFirstHalf =>
      (_liveFirstHalfState != null && _liveFirstHalfState!.isFinished)
          ? _liveFirstHalfState!.toHalfResult()
          : null;

  /// 前半でこれまでに確定したイベント一覧(判断待ちの間も参照できる)。
  List<MatchEvent> get liveFirstHalfEventsSoFar =>
      _liveFirstHalfState?.events ?? const [];

  /// 後半でこれまでに確定したイベント一覧(判断待ちの間も参照できる)。
  List<MatchEvent> get liveSecondHalfEventsSoFar =>
      _liveSecondHalfState?.events ?? const [];

  /// 現在進行中のハーフで、シュート/パスの判断待ちの決定機(なければnull)。
  PendingChanceDecision? get pendingChanceDecision =>
      _liveSecondHalfState?.pending ?? _liveFirstHalfState?.pending;

  /// 自クラブの試合中の現在の采配方針(既定は通常)。
  MatchInstruction get currentMatchInstruction =>
      (_liveSecondHalfState ?? _liveFirstHalfState)?.instruction ??
      MatchInstruction.balanced;

  /// ライブ観戦中の「試合の流れ」(モメンタム)。ホーム視点で-1.0〜+1.0に
  /// 正規化して返す(正の値はホームに、負の値はアウェイに流れがある)。
  /// 進行中のハーフがなければnull。エンジン内部のモメンタムは
  /// ±0.08にクランプされるため、その差(最大0.16)で正規化する。
  double? get liveMomentumForHome {
    final state = _liveSecondHalfState ?? _liveFirstHalfState;
    if (state == null) return null;
    final diff = state.homeMomentum - state.awayMomentum;
    return (diff / 0.16).clamp(-1.0, 1.0);
  }

  /// 自クラブの試合中の采配方針を変更する。試合中いつでも呼べ、以降に
  /// 生成される決定機の成功率へ反映される(ハーフタイム待ち・試合終了後は
  /// 進行中のハーフが存在しないため何もしない)。
  void setMatchInstruction(MatchInstruction instruction) {
    final state = _liveSecondHalfState ?? _liveFirstHalfState;
    if (state == null || state.isFinished) return;
    MatchEngine.setInstruction(state, instruction);
    _notify();
  }

  int get substitutionsUsed => _liveSubstitutionsUsed;

  bool get canMakeSubstitution =>
      _liveSubstitutionsUsed < GameState.maxSubstitutionsPerMatch;

  /// ハーフタイムの交代操作。通常のswapStartingPlayerに交代枠の消費を加える。
  bool makeHalfTimeSubstitution({
    required String outPlayerId,
    required String inPlayerId,
  }) {
    if (!canMakeSubstitution) return false;
    swapStartingPlayer(outPlayerId: outPlayerId, inPlayerId: inPlayerId);
    _liveSubstitutionsUsed++;
    _notify();
    return true;
  }

  /// ライブ観戦中(前半・後半の進行中)の交代操作。ハーフタイムを待たずに
  /// 交代枠を1つ消費して実施し、進行中ハーフの攻守力へ即座に反映される。
  /// 進行中のハーフが存在しない場合、交代枠を使い切っている場合、
  /// 目前の決定機に関与している選手を出入りさせようとした場合などは
  /// 何もせずfalseを返す。
  bool makeLiveSubstitution({
    required String outPlayerId,
    required String inPlayerId,
  }) {
    if (!canMakeSubstitution) return false;
    final state = _liveSecondHalfState ?? _liveFirstHalfState;
    if (state == null || state.isFinished) return false;
    final applied = MatchEngine.applyInteractiveSubstitution(
      state,
      teamId: userTeam.id,
      outPlayerId: outPlayerId,
      inPlayerId: inPlayerId,
    );
    if (!applied) return false;
    swapStartingPlayer(outPlayerId: outPlayerId, inPlayerId: inPlayerId);
    _liveSubstitutionsUsed++;
    _notify();
    return true;
  }

  /// 次の節を進行する。CPU同士の試合は即座に消化するが、自クラブの試合は
  /// 前半のみをシミュレートしてハーフタイム状態にする(交代・戦術変更後、
  /// [playSecondHalf]で後半を消化する)。前半の結果を返す。
  /// [interactive]がtrueの場合、自クラブのオープンプレーの決定機で
  /// シュート/パスの判断待ち([pendingChanceDecision])が発生しうる
  /// (LiveMatchScreenでのライブ観戦時のみtrueにする)。falseの場合は
  /// 常に「シュート」を選んだ場合と同じ結果になるよう即座に自動解決する
  /// (クイックシム・裏側の節送りなど、判断を仰げない場面向け)。
  Future<HalfResult?> playNextMatchday({bool interactive = false}) async {
    if (_save == null) return null;
    // 前半消化中(ハーフタイム)のまま二重に呼び出される(例: 画面を閉じて
    // 戻った際の再タップ)と、この節の他カード全試合の結果が新たな乱数で
    // 上書きされてしまうため、多重実行を防止する。simulateAheadMatchdays等
    // 既にisBusyな状態からの正当なネスト呼び出しはここでは弾かない
    // (isBusyは他の重い処理とも共有する汎用フラグのため)。
    // カップ戦のライブ観戦中も同様に、並行してリーグ戦を始めさせない。
    if (_liveFixture != null || _liveCupKind != null) return null;
    final league = _save!.league;
    final next = league.nextUnplayedFixture;
    if (next == null) return null;

    // 既に外側の処理(simulateAheadMatchdays等)がisBusyにしている場合は、
    // ここで自分がfalseに戻してしまわないようにする。
    final wasAlreadyBusy = isBusy;
    if (!wasAlreadyBusy) {
      isBusy = true;
      _notify();
    }

    _save!.trainingDoneThisWeek = false;

    // トレーニング自動化が有効な場合、この節の分をここで自動的に実施する。
    if (userTeam.autoTrainingEnabled) {
      await runWeeklyTraining();
    }

    // 週の経過による負傷回復と自然な疲労回復(休養日)。
    // 疲労回復は個別のトレーニング方針(休養特訓)とは別に、全チーム・
    // 全選手へ毎週一律で適用する。CPUクラブは練習メニューを設定できず、
    // これを怠ると試合の疲労蓄積だけが積み重なって疲労が上限に張り付き
    // 続けてしまうため。復帰直後は試合勘が鈍っているためマッチシャープ
    // ネスを大きく下げる。
    for (final t in league.teams) {
      for (final p in t.players) {
        if (p.injuryWeeks > 0) {
          p.injuryWeeks -= 1;
          if (p.injuryWeeks == 0) {
            p.matchSharpness = min(p.matchSharpness, 40);
            p.injuryType = null;
          }
        }
        p.fatigue = (p.fatigue - 14).clamp(0, 100);
      }
    }

    // ユーザークラブのみローン期間(週単位)を処理する（CPUクラブは対象外）。
    // 選手契約自体は年単位で結ばれ、シーズン開始時にまとめて消化する
    // (startNextSeason参照)。
    final loanEnded = ContractEngine.advanceLoanWeek(userTeam);
    for (final p in loanEnded) {
      _clearPlayerRoleReferences(userTeam, p.id);
    }
    lastContractExpirations = loanEnded.map((p) => p.name).toList();
    lastContractWarnings = [];
    // ローン満了により編成人数が最低人数を割り込んだ場合、フリーエージェントを
    // 緊急補強してスカッドが組めなくなる事態を防ぐ(安全網)。
    lastEmergencySignings = [];
    while (userTeam.players.length < minSquadSize) {
      final signing = FreeAgentEngine.generateEmergencySigning();
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings.add(signing.name);
    }

    // 選手の不満度を更新する。
    final preMatchRank = league.sortedStandings.indexWhere(
          (r) => r.teamId == _save!.userTeamId,
        ) +
        1;
    HappinessEngine.applyWeekly(
      userTeam,
      leagueRank: preMatchRank,
      boardTargetRank: _save!.boardTargetRank,
    );
    // 個別声かけ(モチベーショントーク)のクールダウンも週次で減らす。
    for (final p in userTeam.players) {
      if (p.talkCooldownWeeks > 0) p.talkCooldownWeeks -= 1;
    }
    if (userTeam.tacticalMeetingCooldownWeeks > 0) {
      userTeam.tacticalMeetingCooldownWeeks -= 1;
    }
    // CPUクラブにも同様に反映する(目標順位という概念がないため、自クラブの
    // 順位をそのまま目標として扱い、出場機会・待遇の要素のみ効かせる)。
    for (final t in league.teams) {
      if (t.id == _save!.userTeamId) continue;
      final rank =
          league.sortedStandings.indexWhere((r) => r.teamId == t.id) + 1;
      HappinessEngine.applyWeekly(t, leagueRank: rank, boardTargetRank: rank);
    }

    // シーズン折り返し地点で、理事会が一度だけ中間レビューを行う。
    if (!_save!.boardReviewDoneThisSeason) {
      final total = _totalMatchdaysThisSeason;
      final midMatchday = total ~/ 2;
      if (total > 0 && next.matchday == midMatchday) {
        final delta = BoardEngine.midSeasonReviewDelta(
          currentRank: preMatchRank,
          targetRank: _save!.boardTargetRank,
        );
        _save!.confidence = (_save!.confidence + delta).clamp(0, 100);
        _save!.pendingBoardReviewMessage = BoardEngine.midSeasonReviewMessage(
          currentRank: preMatchRank,
          targetRank: _save!.boardTargetRank,
        );
        _save!.boardReviewDoneThisSeason = true;
      }
    }

    // 理事会の路線。順位だけでなく、求められた戦い方を守れているかも
    // 節ごとに評価される。破り続けると信頼が落ちていく。
    _save!.confidence = (_save!.confidence +
            BoardEngine.confidenceDeltaForVision(
              vision: _save!.clubVision,
              team: userTeam,
              budget: _save!.budget,
            ))
        .clamp(0, 100);

    // スポンサー契約(年単位)の消化はシーズン開始時にまとめて処理する
    // (startNextSeason参照)。分割払いの引き落としは引き続き週次で行う。
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers = SponsorEngine.generateOffers(
        userTeam.overallRating,
        tier: _save!.currentDivisionTier,
        managerReputation: _save!.managerReputation,
        stadiumLevel:
            _save!.infrastructure.facilityLevel(FacilityType.stadium),
      );
    }
    for (final inst in List<Installment>.from(_save!.pendingInstallments)) {
      _save!.budget -= inst.weeklyAmount;
      inst.weeksRemaining -= 1;
      if (inst.weeksRemaining <= 0) {
        _save!.pendingInstallments.remove(inst);
      }
    }

    // 融資の週次返済。
    for (final loan in List<BankLoan>.from(_save!.bankLoans)) {
      _save!.budget -= loan.weeklyRepayment;
      loan.weeksRemaining -= 1;
      if (loan.weeksRemaining <= 0) {
        _save!.bankLoans.remove(loan);
      }
    }

    // 定期預金の週次経過。満期を迎えたものは利息込みで払い戻す。
    lastMaturedDeposits = [];
    for (final deposit in List<FixedDeposit>.from(_save!.fixedDeposits)) {
      deposit.weeksRemaining -= 1;
      if (deposit.weeksRemaining <= 0) {
        _save!.budget += deposit.maturityValue;
        _save!.fixedDeposits.remove(deposit);
        lastMaturedDeposits.add(deposit);
      }
    }

    // 移籍オファーの週次処理(期限切れ削除・新規発生・リリース条項の自動成立)。
    lastReleaseClauseSales = _advanceIncomingOffers();

    // 代表召集の週次処理(期間終了・新規招集抽選。スタメン欠員は自動で埋める)。
    lastInternationalCallUps = _advanceInternationalDuty();

    // CPUクラブ同士の移籍市場の週次処理(ユーザーは関与しない)。
    lastAiTransferNews = AiTransferEngine.maybeGenerate(
      league.teams,
      _save!.userTeamId,
      GameState._aiTransferRng,
    );

    // CPUクラブの簡易的な週次成長(ユーザーのように個別指導はできないが、
    // 何もしないとユーザーだけがドリル等で伸び続けリーグ全体が停滞するため)。
    // あわせてセットプレー担当も自動更新し、移籍で放出入りした穴を埋める。
    for (final t in league.teams) {
      if (t.id == _save!.userTeamId) continue;
      TrainingEngine.applyPassiveCpuGrowth(t);
      LineupUtils.autoAssignSetPieceRoles(t);
    }

    // 昇格候補(有望株)はユース施設で育成され続ける。施設レベルが高いほど
    // 伸びが早く、じっくり育ててから昇格させる判断に意味を持たせる。
    TrainingEngine.applyYouthAcademyGrowth(
      _save!.youthProspects,
      _save!.infrastructure.facilityLevel(FacilityType.youthFacility),
    );

    // ユース練習試合: 昇格候補たちが毎週実戦を経験し、出場数・得点・評点を
    // 積み重ねる。大活躍(複数得点・高評点)はクラブニュースに届く。
    lastYouthMatchReport = YouthMatchEngine.playWeekly(_save!.youthProspects);
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

    // ローン放出の週次処理(期間終了で自動的にチームへ復帰する)。
    lastLoanReturns = [];
    for (final p in userTeam.players.where((p) => p.isLoanedOut)) {
      // 武者修行: 貸出先で毎週実戦に出て成長する(若手ほど効果大)。
      TrainingEngine.applyLoanDevelopment(p);
      p.loanedOutWeeksRemaining -= 1;
      if (p.loanedOutWeeksRemaining <= 0) {
        final loanClub = p.loanedOutToClubName;
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
    }

    // 成長推移の記録(自クラブの選手とユース昇格候補のみ)。選手詳細の
    // 成長グラフと、ユースの昇格判断に使う。
    for (final p in userTeam.players) {
      TrainingEngine.recordOverallHistory(p);
    }
    for (final p in _save!.youthProspects) {
      TrainingEngine.recordOverallHistory(p);
    }

    final md = next.matchday;
    Fixture? userFixture;
    HalfResult? userFirstHalf;
    for (final f in league.fixturesForMatchday(md)) {
      if (f.result != null) continue;
      final home = _findTeam(league.teams, f.homeTeamId);
      final away = _findTeam(league.teams, f.awayTeamId);
      if (home == null || away == null) {
        // 何らかの理由でチームが見つからない不整合データ。この1試合だけ
        // 0-0扱いで確定させ、未消化のまま残ってnextUnplayedFixtureが
        // 恒久的にこの節で止まってしまう(=節送り自体が二度とできなくなる)
        // 事態を避ける。
        f.result = MatchResult(
          matchday: md,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: const [],
        );
        continue;
      }
      final weather = WeatherEngine.roll();
      f.weather = weather;
      // CPUクラブは対戦相手との力関係で試合ごとに姿勢を選ぶ
      // (ユーザーの設定には触れない)。
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
      final isUserFixture = f.homeTeamId == _save!.userTeamId ||
          f.awayTeamId == _save!.userTeamId;
      if (isUserFixture) {
        userFixture = f;
        _liveWasInteractive = interactive;
        lastShootout = null;
        final state = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: 1,
          endMinute: 45,
          interactiveTeamId: _save!.userTeamId,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
        );
        if (!interactive) {
          while (!state.isFinished) {
            MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          }
        }
        _liveFirstHalfState = state;
        userFirstHalf = state.toHalfResult();
        if (state.isFinished) {
          MatchEngine.applyHalfTimeFatigue(
            home: home,
            away: away,
            weather: weather,
          );
        }
      } else {
        f.result = MatchEngine.simulate(
          home: home,
          away: away,
          matchday: md,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
        );
      }
    }

    // ユーザーが所属していない他の全ディビジョンも同じ節番号の試合を裏で
    // 消化しておく。こうすることで昇格・降格に意味のある順位表を常時
    // 閲覧できるようにする。
    for (final otherLeague in _save!.otherDivisionLeagues) {
      if (otherLeague == null) continue;
      for (final f in otherLeague.fixturesForMatchday(md)) {
        if (f.result != null) continue;
        final home = _findTeam(otherLeague.teams, f.homeTeamId);
        final away = _findTeam(otherLeague.teams, f.awayTeamId);
        if (home == null || away == null) continue;
        f.result = BackgroundMatchEngine.simulate(
          home: home,
          away: away,
          matchday: md,
        );
      }
    }

    var income = weeklyIncomeFor(_save!.userTeamId);
    final isDerby = userFixture != null && isRivalFixture(userFixture);
    if (isDerby) {
      income = (income * GameState.derbyAttendanceMultiplier).round();
    }
    var attendance = expectedAttendance;
    if (isDerby) attendance = (attendance * GameState.derbyAttendanceMultiplier).round();
    lastMatchAttendance = attendance.clamp(0, stadiumCapacity);
    _save!.budget += income;
    _save!.budget -= weeklyWageBill;

    // リーグ公式戦にスタメン出場した選手には出場手当を支払う(親善試合・カップ戦は対象外)。
    if (userFixture != null) {
      lastAppearanceFeesPaid = userTeam.players
          .where((p) => userTeam.startingXI.contains(p.id))
          .fold<int>(0, (s, p) => s + p.appearanceFee);
      _save!.budget -= lastAppearanceFeesPaid;
    } else {
      lastAppearanceFeesPaid = 0;
    }

    if (_save!.budget < 0) {
      _save!.consecutiveNegativeBudgetWeeks += 1;
    } else {
      _save!.consecutiveNegativeBudgetWeeks = 0;
    }
    final budgetConfidenceDelta = BoardEngine.negativeBudgetConfidenceDelta(
      _save!.consecutiveNegativeBudgetWeeks,
    );
    if (budgetConfidenceDelta != 0) {
      _save!.confidence = (_save!.confidence + budgetConfidenceDelta).clamp(
        0,
        100,
      );
      lastBudgetCrisisWarning = Tr.pick(
          '資金マイナスが${_save!.consecutiveNegativeBudgetWeeks}週続いています。理事会の信頼度が低下しました。',
          "You have been in the red for ${Tr.plural(_save!.consecutiveNegativeBudgetWeeks, 'week')}. The board's confidence has slipped.");
    }

    // 移籍市場は全員を作り直さず、数人だけ入れ替える(持続的な市場)。
    transferMarket = TransferMarket.rotate(transferMarket);
    transferOffersRejectedThisWeek.clear();
    _refreshScoutCandidates();

    // 今節発生した一過性の通知をクラブニュース履歴にも記録する
    // (表示側のSnackBar/ダイアログは従来どおり別途フィールドをクリアする)。
    final newsWeek = Tr.pick('第$md節', 'Matchday $md');
    if (lastReleaseClauseSales.isNotEmpty) {
      _logNews(
          Tr.pick('リリース条項が発動し移籍が成立: ${lastReleaseClauseSales.join('、')}',
              "Release clauses triggered, transfers completed: ${lastReleaseClauseSales.join(', ')}"),
          context: newsWeek);
    }
    if (lastInternationalCallUps.isNotEmpty) {
      _logNews(
          Tr.pick('代表召集: ${lastInternationalCallUps.join('、')}',
              "Called up for international duty: ${lastInternationalCallUps.join(', ')}"),
          context: newsWeek);
    }
    if (lastLoanReturns.isNotEmpty) {
      _logNews(
          Tr.pick('ローン放出から復帰: ${lastLoanReturns.join('、')}',
              "Back from loan: ${lastLoanReturns.join(', ')}"),
          context: newsWeek);
    }
    if (lastMaturedDeposits.isNotEmpty) {
      final maturedTotal =
          lastMaturedDeposits.fold<int>(0, (s, d) => s + d.maturityValue);
      _logNews(
          Tr.pick('定期預金が満期を迎え、$maturedTotal万円が払い戻されました',
              'Your deposit matured and $maturedTotal was paid back'),
          context: newsWeek);
    }
    if (lastAiTransferNews != null) {
      _logNews(
          Tr.pick('移籍市場: $lastAiTransferNews',
              'Transfer market: $lastAiTransferNews'),
          context: newsWeek);
    }
    if (lastBudgetCrisisWarning != null) {
      _logNews(lastBudgetCrisisWarning!, context: newsWeek);
    }
    // ウォッチリストの選手が今節ゴールしたらニュースで知らせる
    // (スカウティングの追跡対象を見失わないようにするため)。
    if (_save!.watchlistPlayerIds.isNotEmpty) {
      final watched = _save!.watchlistPlayerIds.toSet();
      for (final f in league.fixturesForMatchday(md)) {
        final r = f.result;
        if (r == null) continue;
        for (final e in r.events) {
          if (e.type == MatchEventType.goal &&
              e.scorerId != null &&
              e.scorerName != null &&
              watched.contains(e.scorerId)) {
            _logNews(
                Tr.pick('ウォッチ中の${e.scorerName}が今節ゴールを決めた',
                    '${e.scorerName}, on your watchlist, scored this matchday'),
                context: newsWeek);
          }
        }
      }
    }

    if (userFixture != null) {
      _liveFixture = userFixture;
      _liveSubstitutionsUsed = 0;
    }

    if (!wasAlreadyBusy) {
      isBusy = false;
    }
    _notify();
    await _persistNow();
    return userFirstHalf;
  }

  /// ハーフタイムでの交代・戦術変更を反映して後半を消化し、試合を確定する。
  /// [interactive]の意味は[playNextMatchday]と同じ。falseの場合は後半も
  /// 即座に完了し、この呼び出しの戻り値だけで試合が確定する(従来通り)。
  /// trueの場合、後半にもオープンプレーの決定機があれば判断待ちになり、
  /// この呼び出しはnullを返す(その後[resolveChanceDecision]を繰り返して
  /// 最終的に試合が確定した際、その戻り値として[MatchResult]が得られる)。
  Future<MatchResult?> playSecondHalf({bool interactive = false}) async {
    if (_save == null ||
        (_liveFixture == null && _liveCupKind == null) ||
        _liveFirstHalfState == null ||
        !_liveFirstHalfState!.isFinished) {
      return null;
    }
    final home = _liveHomeTeam!;
    final away = _liveAwayTeam!;
    final weather = _liveWeatherNow;
    if (interactive) _liveWasInteractive = true;

    final state = MatchEngine.beginInteractiveHalf(
      home: home,
      away: away,
      startMinute: 46,
      endMinute: 90,
      interactiveTeamId: _save!.userTeamId,
      weather: weather,
      homeAdvantageFactor: _homeAdvantageFor(home.id),
    );
    if (!interactive) {
      while (!state.isFinished) {
        MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
      }
    }
    _liveSecondHalfState = state;

    if (state.isFinished) {
      return _finalizeSecondHalf(state.toHalfResult());
    }
    _notify();
    await _persistNow();
    return null;
  }

  /// 前半・後半のシュート/パスの判断待ち([pendingChanceDecision])を
  /// [decision]で解決し、次の決定機(または試合終了)まで進行を再開する。
  /// [merged]はこの呼び出しで試合(後半)がちょうど完了した場合のみ確定した
  /// [MatchResult]を返す(それ以外はnull)。[decisionEvent]はこの決定機の
  /// 結果として実際に発生したイベント(得点・惜しいチャンス・カード)で、
  /// 何も起きなかった場合はnull。UI側が選択直後に即時フィードバックを
  /// 表示するために使う。
  Future<({MatchResult? merged, MatchEvent? decisionEvent})>
      resolveChanceDecision(ChanceDecision decision) async {
    if (_save == null) return (merged: null, decisionEvent: null);
    final secondState = _liveSecondHalfState;
    if (secondState != null && !secondState.isFinished) {
      final event = MatchEngine.resolvePendingChance(secondState, decision);
      if (secondState.isFinished) {
        final merged = await _finalizeSecondHalf(secondState.toHalfResult());
        return (merged: merged, decisionEvent: event);
      }
      _notify();
      await _persistNow();
      return (merged: null, decisionEvent: event);
    }
    final firstState = _liveFirstHalfState;
    if (firstState != null && !firstState.isFinished) {
      final event = MatchEngine.resolvePendingChance(firstState, decision);
      if (firstState.isFinished) {
        final home = _liveHomeTeam;
        final away = _liveAwayTeam;
        if (home != null && away != null) {
          MatchEngine.applyHalfTimeFatigue(
              home: home, away: away, weather: _liveWeatherNow);
        }
      }
      _notify();
      await _persistNow();
      return (merged: null, decisionEvent: event);
    }
    return (merged: null, decisionEvent: null);
  }

  /// [playSecondHalf]/[resolveChanceDecision]から、後半がちょうど完了した
  /// 際に呼ばれる。試合の確定処理(採点・疲労・負傷判定・マイルストーン・
  /// 実績・理事会信頼度・記者会見)をまとめて行い、ライブ試合の一時状態を
  /// クリアする。
  Future<MatchResult> _finalizeSecondHalf(HalfResult second) async {
    final league = _save!.league;
    final f = _liveFixture;
    final home = _liveHomeTeam!;
    final away = _liveAwayTeam!;
    final weather = _liveWeatherNow;
    final firstHalf = _liveFirstHalfState!.toHalfResult();

    final allEvents = [...firstHalf.events, ...second.events];
    final homeGoals = firstHalf.homeGoals + second.homeGoals;
    final awayGoals = firstHalf.awayGoals + second.awayGoals;
    final homeShots = firstHalf.homeShots + second.homeShots;
    final awayShots = firstHalf.awayShots + second.awayShots;
    final homeShotsOnTarget =
        firstHalf.homeShotsOnTarget + second.homeShotsOnTarget;
    final awayShotsOnTarget =
        firstHalf.awayShotsOnTarget + second.awayShotsOnTarget;
    final totalChanceCount = firstHalf.chanceCount + second.chanceCount;
    final homePossession = totalChanceCount > 0
        ? ((firstHalf.possessionShareSum + second.possessionShareSum) /
                totalChanceCount *
                100)
            .round()
            .clamp(0, 100)
        : 50;
    final awayPossession = 100 - homePossession;
    // 採点は今節の出場停止・負傷が反映される前に算出する必要があるため、
    // applyPostMatchEffectsより先に計算する。
    final ratings = MatchEngine.computePlayerRatings(
      home: home,
      away: away,
      events: allEvents,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
    );
    final statsBefore = {
      for (final p in userTeam.players)
        p.id: (goals: p.careerGoals, apps: p.careerAppearances),
    };
    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: _injuryFactorFor(home.id),
      awayInjuryFactor: _injuryFactorFor(away.id),
      events: allEvents,
      weather: weather,
    );
    lastMilestones = _detectMilestones(userTeam, allEvents, statsBefore);
    for (final m in lastMilestones) {
      _save!.trophyHistory.add(
          Tr.pick('シーズン${league.season}: $m', 'Season ${league.season}: $m'));
    }
    // 決定機の判断ありのライブ観戦で勝った場合のみ、実績用の勝利数を刻む
    // (クイック消化と区別する)。
    final userId = _save!.userTeamId;
    final userWonMatch = (home.id == userId && homeGoals > awayGoals) ||
        (away.id == userId && awayGoals > homeGoals);
    if (_liveWasInteractive && userWonMatch) {
      _save!.liveWins++;
    }
    _evaluateAchievements();

    final merged = MatchResult(
      matchday: f?.matchday ?? 0,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: allEvents,
      playerRatings: ratings,
      weather: weather,
      homePossession: homePossession,
      awayPossession: awayPossession,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
    );
    if (f != null) {
      f.result = merged;

      // 4節ごとに月間最優秀監督賞を判定する(ユーザーが受賞した場合のみ通知・記録する)。
      if (f.matchday - _save!.lastManagerOfMonthCheckpoint >= 4) {
        final fromMatchday = _save!.lastManagerOfMonthCheckpoint + 1;
        final winnerName = AwardsEngine.computeManagerOfPeriod(
          league,
          fromMatchday: fromMatchday,
          toMatchday: f.matchday,
        );
        if (winnerName == userTeam.name) {
          final label = Tr.pick('第$fromMatchday-${f.matchday}節',
              'Matchdays $fromMatchday-${f.matchday}');
          _save!.trophyHistory.add(Tr.pick(
              'シーズン${league.season} 月間最優秀監督賞($label)',
              'Season ${league.season} Manager of the Month ($label)'));
          lastMonthlyManagerAward = label;
          _logNews(
              Tr.pick('月間最優秀監督賞を受賞($label)!',
                  'You won Manager of the Month ($label)!'),
              context: Tr.pick('表彰', 'Award'));
        }
        _save!.lastManagerOfMonthCheckpoint = f.matchday;
      }

      var delta =
          BoardEngine.confidenceDeltaForMatch(merged, _save!.userTeamId);
      if (isRivalFixture(f)) {
        delta = (delta * GameState.derbyConfidenceMultiplier).round();
      }
      _save!.confidence = (_save!.confidence + delta).clamp(0, 100);
    } else {
      // カップ戦のライブ観戦: 結果を該当大会のブラケット/グループへ適用する
      // (引き分け時のPK戦・敗退時の信頼度低下・賞金・優勝処理を含む)。
      _applyLiveCupResult(merged);
    }
    _save!.pendingPressConference = PressConferenceEngine.generateFor(
      result: merged,
      userTeamId: _save!.userTeamId,
    );

    _liveFixture = null;
    _liveCupKind = null;
    _liveCupHome = null;
    _liveCupAway = null;
    _liveCupWeather = null;
    _liveCupMatch = null;
    _liveCupTie = null;
    _liveFirstHalfState = null;
    _liveSecondHalfState = null;
    _liveSubstitutionsUsed = 0;
    _liveWasInteractive = false;

    _notify();
    await _persistNow();
    return merged;
  }

  /// 今節の試合で自クラブの選手が達成したハットトリック・通算記録の
  /// 節目を検出し、表示・記録用の説明文リストとして返す。
  List<String> _detectMilestones(
    Team team,
    List<MatchEvent> events,
    Map<String, ({int goals, int apps})> before,
  ) {
    final milestones = <String>[];
    final goalsThisMatch = <String, int>{};
    for (final e in events) {
      if (e.type == MatchEventType.goal && e.scorerId != null) {
        goalsThisMatch[e.scorerId!] = (goalsThisMatch[e.scorerId!] ?? 0) + 1;
      }
    }
    for (final p in team.players) {
      final scored = goalsThisMatch[p.id] ?? 0;
      if (scored >= 3) {
        milestones.add(Tr.pick('${p.name}がハットトリック達成($scored得点)',
            '${p.name} scored a hat-trick (${Tr.plural(scored, 'goal')})'));
      }
      final prev = before[p.id];
      if (prev == null) continue;
      for (final m in GameState._goalMilestones) {
        if (prev.goals < m && p.careerGoals >= m) {
          milestones.add(Tr.pick(
              '${p.name}が通算$m得点を達成', '${p.name} reached $m career goals'));
        }
      }
      for (final m in GameState._appearanceMilestones) {
        if (prev.apps < m && p.careerAppearances >= m) {
          milestones.add(Tr.pick('${p.name}が通算$m試合出場を達成',
              '${p.name} reached $m career appearances'));
        }
      }
    }
    return milestones;
  }

  /// 現在のセーブデータの状態から新たに解除された実績を判定し、
  /// 解除済みIDとして記録する(通知はlastUnlockedAchievementsへ追加し、
  /// 呼び出し側が表示後にクリアする想定)。
  void _evaluateAchievements({int? season}) {
    if (_save == null) return;
    final newly = AchievementEngine.evaluate(_save!, userTeam);
    if (newly.isEmpty) return;
    final recordedSeason = season ?? _save!.league.season;
    for (final a in newly) {
      _save!.unlockedAchievements[a.id] = recordedSeason;
      _logNews(Tr.pick('実績「${a.name}」を達成!', 'Achievement unlocked: ${a.name}'),
          context: Tr.pick('実績', 'Achievement'));
    }
    lastUnlockedAchievements = [...lastUnlockedAchievements, ...newly];
  }

  /// 実績画面向け: 全実績の定義一覧。
  List<Achievement> get allAchievements => AchievementEngine.all;

  bool isAchievementUnlocked(String id) =>
      _save?.unlockedAchievements.containsKey(id) ?? false;

  /// 実績を達成したシーズン番号(未達成の場合はnull)。
  int? achievementUnlockedSeason(String id) => _save?.unlockedAchievements[id];

  int get unlockedAchievementCount => _save?.unlockedAchievements.length ?? 0;

  /// ライブ観戦せず、前半・後半を一括で消化して確定結果のみを返す
  /// (クイックシム)。ユーザーの試合がない、またはシーズンが既に終了して
  /// いる場合はnull。
  Future<MatchResult?> playNextMatchdayQuickSim() async {
    final firstHalf = await playNextMatchday();
    if (firstHalf == null) return null;
    return playSecondHalf();
  }

  /// クイックシムを最大[matchdays]節分繰り返し、確定した結果を節の順で返す。
  /// シーズンが終了する、またはユーザーの試合がない節に達した時点で止まる。
  Future<List<MatchResult>> simulateAheadMatchdays(int matchdays) async {
    isBusy = true;
    _notify();
    final results = <MatchResult>[];
    try {
      for (int i = 0; i < matchdays; i++) {
        if (_save == null || _save!.league.isSeasonComplete) break;
        final result = await playNextMatchdayQuickSim();
        if (result == null) break;
        results.add(result);
        // 節を進めたらカップ戦も消化する。ここで進めないと、まとめて
        // シミュレーションした分だけカップが取り残され、シーズン終了時に
        // 優勝者が決まらないまま賞金も入らない(実際にそうなっていた)。
        // カップは「リーグが1節進むごとに1試合」の制約があるので、
        // 1節につき各カップ最大1試合で足りる。
        //
        // 戻り値には混ぜない。このメソッドは「リーグの結果を節の順で返す」
        // もので、呼び出し側(シミュレーション結果の一覧)もその前提で並べる。
        // カップの結果はカップ画面とニュースに出る。
        await _playAvailableCupMatches();
      }
    } finally {
      isBusy = false;
      _notify();
    }
    return results;
  }

  /// いま消化できるカップ戦を1試合ずつ進める。
  ///
  /// 判定と実行はカップ画面が使っているものと同じ。まとめてシミュレーション
  /// するときだけ別扱いにすると、進み方が画面ごとに食い違う。
  Future<void> _playAvailableCupMatches() async {
    if (canPlayNextDomesticCupMatch) {
      await playNextCupMatch();
    }

    if (canPlayNextContinentalMatch) {
      final cup = _save?.continentalCup;
      if (cup != null) {
        if (cup.isGroupStageComplete) {
          await playNextContinentalKnockoutLeg();
        } else {
          await playNextContinentalGroupMatch();
        }
      }
    }

    if (pendingSuperCup != null) {
      await playSuperCup();
    }
  }

  /// 現在の順位表を起点に、残り試合をチーム総合力ベースで簡易シミュレー
  /// ションし、シーズン最終順位の見込み(優勝/大陸カップ出場/降格の確率)
  /// を算出する。実際の試合結果には影響しない参考情報。
  List<TeamProjection> get seasonProjection => SeasonProjectionEngine.project(
        _save!.league,
        relegationCount: PromotionEngine.swapCount,
        // 大陸カップ出場枠は1部の上位2チームのみ(2部は対象外)。
        continentalQualifyCount: _save!.currentDivisionTier == 1 ? 2 : 0,
      );

  List<Team> get allTeamsForCups => [
        ..._save!.league.teams,
        ..._save!.continentalTeams,
      ];
}
