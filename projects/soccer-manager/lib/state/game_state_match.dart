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
  ///
  /// ライブ観戦中のカップ戦が中立の会場(決勝・スーパーカップ)なら、どちらの
  /// クラブにもホームの利は無い(ライブ観戦の間は、ほかの試合は進まない)。
  double _homeAdvantageFor(String homeTeamId) {
    if (_liveCupKind != null && _liveCupNeutral) {
      return MatchEngine.neutralHomeAdvantageFactor;
    }
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
          _userContinentalCup?.name ?? Tr.pick('大陸カップ', 'Continental Cup'),
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

  /// 残りの交代枠(人数)。
  int get substitutionsRemaining =>
      GameState.maxSubstitutionsPerMatch - _liveSubstitutionsUsed;

  /// 使った交代の回数(ハーフタイムは数えない)。
  int get substitutionWindowsUsed => _liveSubWindowsUsed;

  /// 残りの交代の回数(ハーフタイムは数えない)。
  int get substitutionWindowsRemaining =>
      GameState.maxSubstitutionWindowsPerMatch - _liveSubWindowsUsed;

  /// 「交代あと2人・あと1回」のような残りの表示。
  String get substitutionsLeftLabel => Tr.pick(
      '交代あと$substitutionsRemaining人(ハーフタイム以外はあと$substitutionWindowsRemaining回)',
      '${Tr.plural(substitutionsRemaining, 'sub')} left '
          '(${Tr.plural(substitutionWindowsRemaining, 'stoppage')} left outside half-time)');

  /// 交代枠(人数)が残っているか。試合中の交代は、これに加えて回数も
  /// 残っている(か、同じ止まった場面で続けて替える)必要がある。
  bool get canMakeSubstitution =>
      _liveSubstitutionsUsed < GameState.maxSubstitutionsPerMatch;

  /// いまの止まった場面([_liveSubWindowKey])で試合中の交代ができるか。
  /// 同じ場面で続けて替えるなら回数は増えない。
  bool get canMakeLiveSubstitution {
    if (!canMakeSubstitution) return false;
    final key = _currentLiveSubWindowKey;
    if (key == null) return false;
    return key == _liveSubWindowKey ||
        _liveSubWindowsUsed < GameState.maxSubstitutionWindowsPerMatch;
  }

  /// 試合中のいまの止まった場面を表す印(前半か後半かと、何番目の決定機か)。
  String? get _currentLiveSubWindowKey {
    final second = _liveSecondHalfState;
    if (second != null) return 'h2:${second.chanceIndex}';
    final first = _liveFirstHalfState;
    if (first != null) return 'h1:${first.chanceIndex}';
    return null;
  }

  /// ハーフタイムの交代操作。通常のswapStartingPlayerに交代枠の消費を加える。
  /// ハーフタイムの交代は回数に数えない(実際の決まりと同じ)。前半に退場した
  /// 選手を下げて控えを入れることはできない(11人に戻ってしまう)。
  bool makeHalfTimeSubstitution({
    required String outPlayerId,
    required String inPlayerId,
  }) {
    if (!canMakeSubstitution) return false;
    final first = _liveFirstHalfState;
    if (first != null &&
        MatchEngine.sentOffIds(first.events).contains(outPlayerId)) {
      return false;
    }
    final out = userTeam.players.where((p) => p.id == outPlayerId).firstOrNull;
    final incoming =
        userTeam.players.where((p) => p.id == inPlayerId).firstOrNull;
    swapStartingPlayer(outPlayerId: outPlayerId, inPlayerId: inPlayerId);
    _liveSubstitutionsUsed++;
    // 試合経過に「46分 交代: A → B」と出す(後半を始めるときに入れる)。
    if (out != null && incoming != null) {
      _liveHalfTimeSubEvents.add(MatchEngine.substitutionEvent(
          minute: 46, teamId: userTeam.id, out: out, incoming: incoming));
    }
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
    if (!canMakeLiveSubstitution) return false;
    final state = _liveSecondHalfState ?? _liveFirstHalfState;
    if (state == null || state.isFinished) return false;
    final key = _currentLiveSubWindowKey;
    final applied = MatchEngine.applyInteractiveSubstitution(
      state,
      teamId: userTeam.id,
      outPlayerId: outPlayerId,
      inPlayerId: inPlayerId,
    );
    if (!applied) return false;
    final out = userTeam.players.where((p) => p.id == outPlayerId).firstOrNull;
    final incoming =
        userTeam.players.where((p) => p.id == inPlayerId).firstOrNull;
    // 試合経過に「◯分 交代: A → B」と出す(このハーフの出来事に入れる)。
    if (out != null && incoming != null) {
      state.events.add(MatchEngine.substitutionEvent(
          minute: MatchEngine.currentMinuteOf(state),
          teamId: userTeam.id,
          out: out,
          incoming: incoming));
    }
    swapStartingPlayer(outPlayerId: outPlayerId, inPlayerId: inPlayerId);
    _liveSubstitutionsUsed++;
    // 同じ止まった場面で続けて替えるのは1回と数える(5人を3回まで)。
    if (key != _liveSubWindowKey) {
      _liveSubWindowsUsed++;
      _liveSubWindowKey = key;
    }
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
    // 今日をこの節の試合日へ進める。
    _advanceTodayTo(dateOfMatchday(next.matchday));

    // 既に外側の処理(simulateAheadMatchdays等)がisBusyにしている場合は、
    // ここで自分がfalseに戻してしまわないようにする。
    final wasAlreadyBusy = isBusy;
    if (!wasAlreadyBusy) {
      isBusy = true;
      _notify();
    }

    // この節の試合前の処理は済んでいる(試合の途中でアプリが終わった)。
    // 二度かけず、試合だけを途中から再開する。
    if (_save!.weekProcessedSeason == league.season &&
        _save!.weekProcessedMatchday == next.matchday) {
      return _resumeInterruptedMatchday(
        next,
        interactive: interactive,
        wasAlreadyBusy: wasAlreadyBusy,
      );
    }

    // 勝負の試合でなければ、先発と構えは監督が決める。
    _managerPreparesMatch(next);
    // 節の区切りで、オーナーの判断を迫る事件が起きる。
    _maybeRaiseOwnerEvent(next.matchday);
    // たまに、看板選手の移籍の噂が出る(記者会見で答える)。
    _maybeRaiseRumor();
    _refreshProposals();

    // 週の処理(練習・不満・ユース・ローン・分割払いなど)は日付で回る
    // (7日ごと。今日を進めたときに _setToday が回す)。その季で最初の節と、
    // 最後に週の処理をした日を持たない旧セーブは、ここで1回行って今日を
    // 起点にする(以前の練習と同じ位置: 監督が先発を決めた後)。
    _startWeeklyClockIfNeeded();

    // リーグカップ(イングランドだけ)と、日が来たカップ戦・大陸大会の
    // 自クラブの出ない試合を、この節の前の週にまとめて消化する。
    _playLeagueCupIfDue();
    _playDueCpuCupMatches();

    final preMatchRank = league.sortedStandings.indexWhere(
          (r) => r.teamId == _save!.userTeamId,
        ) +
        1;
    // 序列を約束した選手を、先発から外し続けていないか(節ごとに数える)。
    _checkPromisesWeekly();
    // 大きな怪我は、手術か保存療法かを選ばせる。
    _reviewInjuries();
    // 前の試合から間を空けずに戦うなら、先発に疲れが残る(過密日程)。
    // 判定は試合の日付の間隔で行う。
    final userPlaysToday = league.fixturesForMatchday(next.matchday).any((f) =>
        f.homeTeamId == _save!.userTeamId || f.awayTeamId == _save!.userTeamId);
    if (userPlaysToday) _noteUserMatchDay();
    // 先発に入っていない21歳以下は、U21 の試合に出る。
    _playU21Matchday();

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

    // 理事会の路線。節ごとに守れているかを数えるだけで、信頼度への反映は
    // シーズン終了時に一度だけ行う(startNextSeason)。節ごとに積むと
    // 試合結果より大きく効いてしまう。
    if (_save!.clubVision != ClubVision.none) {
      _save!.visionCheckedMatchdays++;
      if (BoardEngine.isVisionSatisfied(
        vision: _save!.clubVision,
        team: userTeam,
        budget: _save!.budget,
      )) {
        _save!.visionCompliedMatchdays++;
      }
    }

    // スポンサー契約(年単位)の消化はシーズン開始時にまとめて処理する
    // (startNextSeason参照)。分割払いの引き落としは週の処理で行う。
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers =
          _economyAdjusted(SponsorEngine.generateOffers(
        userTeam.overallRating,
        tier: _save!.currentDivisionTier,
        managerReputation: _save!.managerReputation,
        stadiumLevel: _save!.infrastructure.facilityLevel(FacilityType.stadium),
      ));
    }

    final md = next.matchday;
    Fixture? userFixture;
    HalfResult? userFirstHalf;
    // この節のリーグ戦の警告は、国と節の決まりで数える(他の部も同じ国)。
    CardRules.current = _leagueCardRules(md);
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
      // 天気は季節(今日の月)に合わせる。
      final weather = WeatherEngine.roll(month: today.month);
      f.weather = weather;
      // CPUクラブは対戦相手との力関係で試合ごとに姿勢を選ぶ
      // (ユーザーの設定には触れない)。
      CpuTacticsAI.applyPreMatch(home, away, _save!.userTeamId);
      final isUserFixture = f.homeTeamId == _save!.userTeamId ||
          f.awayTeamId == _save!.userTeamId;
      if (isUserFixture) {
        userFixture = f;
        _liveWasInteractive = interactive;
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
        // 警告・退場・交代の出場を選手に入れる(出場停止もここで消化)。
        BackgroundMatchEngine.applyPlayerEffects(home: home, away: away);
      }
    }

    // 他国の1部も同じ節を裏で進める。
    _playForeignMatchday(md);
    CardRules.current = CardRules.generic;

    // 試合の日に入るのは観客・スポンサー・グッズ。放映権は年4回の入金日に、
    // 給与は毎月末に払う(MoneyCalendar)。
    //
    // 観客収入はアウェイの節にも入る。これは「この試合の入場料」ではなく、
    // ホームの試合の入場料を1季ぶん均して、毎節「平均」として入れる作り
    // (節の数×この額で年額になるように、部ごとの年収の目安
    // typicalAnnualIncome と economy_scale_test で合わせてある)。ホームの節
    // だけに入れると年額が半分になり、経済の釣り合いが崩れるので、そのままに
    // する。ただし画面に出す「観客動員」は、ホームの試合の実際の人数だけを
    // 控える(アウェイの節に自分のスタジアムの人数を出さない)。
    final incomeParts = weeklyIncomeParts(_save!.userTeamId);
    final partsTotal =
        incomeParts.gate + incomeParts.sponsor + incomeParts.merchandise;
    var income = partsTotal;
    final isDerby = userFixture != null && isRivalFixture(userFixture);
    // 祝日の試合は客が増える(リーグ戦のみ)。
    final holiday = userFixture == null
        ? null
        : MoneyCalendar.holidayName(dateOfMatchday(md), currentLeagueTheme);

    // ダービーは客が増える。ただし**入れる人数以上からは入場料を取れない**。
    // 観客数だけを収容人数で頭打ちにして、収入には倍率をそのまま掛けていた
    // ため、「満員」と出ているのに収入はその1.5倍、という食い違いがあった。
    // 実際に入った人数の比で掛ける。空席があるダービーでは今まで通り伸び、
    // 既に満員に近いクラブでは伸びしろが小さくなる。
    final baseAttendance = expectedAttendance;
    var attendance = baseAttendance;
    if (isDerby) {
      attendance = (attendance * GameState.derbyAttendanceMultiplier).round();
    }
    if (holiday != null) {
      attendance =
          (attendance * MoneyCalendar.holidayAttendanceMultiplier).round();
    }
    final actualAttendance = attendance.clamp(0, stadiumCapacity);
    // 観客動員の表示は、自分のスタジアムで試合があった節(ホーム)だけ
    // 書き換える。アウェイの節は前のホームの試合の人数のまま。
    if (userFixture != null && userFixture.homeTeamId == _save!.userTeamId) {
      lastMatchAttendance = actualAttendance;
    }
    if (isDerby || holiday != null) {
      income = GameState.derbyAdjustedIncome(
        income,
        baseAttendance: baseAttendance,
        actualAttendance: actualAttendance,
      );
    }
    // 収入は内訳ごとに記録する。ダービー・祝日で増えた分は観客収入に入れる。
    // 年間シートで先に売った分は、節ごとの入場収入から除く(ダービー・祝日で
    // 増えた分は当日券なので、そのまま入る)。
    final gateNow = SeasonTicketEngine.remainingGate(
        incomeParts.gate, seasonTicketShareNow);
    _book(LedgerCategory.gate, gateNow + (income - partsTotal));
    _book(LedgerCategory.sponsor, incomeParts.sponsor);
    _book(LedgerCategory.merchandise, incomeParts.merchandise);
    // 営業ブーストは、収入が入った節で1つ使う。
    if (_save!.marketingBoostWeeks > 0) _save!.marketingBoostWeeks -= 1;
    // 試合日のイベントも、収入が入った節で使い切る。
    _consumeMatchdayPromo();

    // リーグ公式戦にスタメン出場した選手には出場手当を支払う(親善試合は
    // 対象外)。途中出場の半額は試合のあと、カップ戦は各試合のあとに払う
    // ([AppearanceFeeEngine])。
    if (userFixture != null) {
      lastAppearanceFeesPaid = userTeam.players
          .where((p) => userTeam.startingXI.contains(p.id))
          .fold<int>(0, (s, p) => s + p.appearanceFee);
      _book(LedgerCategory.appearanceFees, -(lastAppearanceFeesPaid));
    } else {
      lastAppearanceFeesPaid = 0;
    }

    _refreshScoutCandidates();

    final newsWeek = Tr.pick('第$md節', 'Matchday $md');
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
      _liveSubWindowsUsed = 0;
      _liveSubWindowKey = null;
      _liveHalfTimeSubEvents = [];
    }

    // 試合前の処理を済ませた印と、試合の途中経過を同じ保存に載せる。
    _save!.weekProcessedSeason = league.season;
    _save!.weekProcessedMatchday = md;
    _recordLiveProgress();

    if (!wasAlreadyBusy) {
      isBusy = false;
    }
    _notify();
    await _persistNow();
    return userFirstHalf;
  }

  /// 週の処理が済んだ節を、試合だけ再開する。
  ///
  /// 保存してある途中経過([SaveGame.liveMatchProgress])があれば、その続き
  /// から進める。前半で負けている試合を落としても、確定した得点は残る。
  Future<HalfResult?> _resumeInterruptedMatchday(
    Fixture next, {
    required bool interactive,
    required bool wasAlreadyBusy,
  }) async {
    final league = _save!.league;
    final md = next.matchday;
    final saved = _save!.liveMatchProgress;
    final progress =
        saved != null && saved.season == league.season && saved.matchday == md
            ? saved
            : null;
    final userId = _save!.userTeamId;
    Fixture? userFixture;
    HalfResult? userFirstHalf;
    _liveSecondHalfResume = null;
    CardRules.current = _leagueCardRules(md);
    for (final f in league.fixturesForMatchday(md)) {
      if (f.result != null) continue;
      final home = _findTeam(league.teams, f.homeTeamId);
      final away = _findTeam(league.teams, f.awayTeamId);
      if (home == null || away == null) {
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
      final weather = f.weather ?? WeatherEngine.roll(month: today.month);
      f.weather = weather;
      CpuTacticsAI.applyPreMatch(home, away, userId);
      final isUserFixture = f.homeTeamId == userId || f.awayTeamId == userId;
      if (!isUserFixture) {
        f.result = MatchEngine.simulate(
          home: home,
          away: away,
          matchday: md,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
        );
        continue;
      }
      userFixture = f;
      _liveWasInteractive = interactive;
      final secondHalf = progress?.secondHalf;
      if (progress != null && secondHalf != null) {
        // 前半は終わっていた。ハーフタイムから再開し、後半は続きから。
        _liveFirstHalfState = MatchEngine.finishedHalfFrom(
          home: home,
          away: away,
          interactiveTeamId: userId,
          carried: progress.firstHalf,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
        );
        _liveSecondHalfResume =
            (tally: secondHalf, resumeMinute: progress.resumeMinute);
      } else {
        final state = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: progress?.resumeMinute ?? 1,
          endMinute: 45,
          interactiveTeamId: userId,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
          carried: progress?.firstHalf,
        );
        if (!interactive) {
          while (!state.isFinished) {
            MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          }
        }
        _liveFirstHalfState = state;
        if (state.isFinished) {
          MatchEngine.applyHalfTimeFatigue(
            home: home,
            away: away,
            weather: weather,
          );
        }
      }
      userFirstHalf = _liveFirstHalfState!.toHalfResult();
    }
    CardRules.current = CardRules.generic;
    if (userFixture != null) {
      _liveFixture = userFixture;
      _liveSubstitutionsUsed = progress?.substitutionsUsed ?? 0;
      _liveSubWindowsUsed = progress?.substitutionWindowsUsed ?? 0;
      _liveSubWindowKey = null;
      _liveHalfTimeSubEvents = [];
    }
    _recordLiveProgress();

    if (!wasAlreadyBusy) {
      isBusy = false;
    }
    _notify();
    await _persistNow();
    return userFirstHalf;
  }

  /// 進行中のリーグ戦の途中経過をセーブに書く(保存の直前に呼ぶ)。
  /// カップ戦のライブ観戦は対象外(週の処理と結びついていない)。
  void _recordLiveProgress() {
    final save = _save;
    final f = _liveFixture;
    final first = _liveFirstHalfState;
    if (save == null) return;
    if (f == null || first == null) {
      save.liveMatchProgress = null;
      return;
    }
    final second = _liveSecondHalfState;
    final HalfTally firstTally;
    HalfTally? secondTally;
    final int resume;
    if (!first.isFinished) {
      resume = first.resumeMinute(45);
      firstTally = first.toTally(beforeMinute: resume);
    } else {
      firstTally = first.toTally(beforeMinute: 46);
      if (second == null) {
        final pendingResume = _liveSecondHalfResume;
        resume = pendingResume?.resumeMinute ?? 46;
        secondTally = pendingResume?.tally ?? const HalfTally();
      } else {
        resume = second.resumeMinute(90);
        secondTally = second.toTally(beforeMinute: resume);
      }
    }
    save.liveMatchProgress = LiveMatchProgress(
      season: save.league.season,
      matchday: f.matchday,
      resumeMinute: resume,
      substitutionsUsed: _liveSubstitutionsUsed,
      substitutionWindowsUsed: _liveSubWindowsUsed,
      firstHalf: firstTally,
      secondHalf: secondTally,
    );
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
    // カップ戦なら、その大会の出場停止で出られる選手を決める(試合が
    // 終わるまで。_finalizeSecondHalf で戻す)。
    CardRules.current = _liveCardRules;

    // 再起動前に後半の途中まで進んでいたら、その続きから。
    final resume = _liveSecondHalfResume;
    _liveSecondHalfResume = null;
    // 警告は1試合を通して数える。前半の警告を後半へ引き継ぐ(再起動の
    // あとでも、前半の途中経過から戻せるように毎回入れ直す)。
    final firstHalf = _liveFirstHalfState!;
    MatchEngine.markYellowCardsFromEvents(home, away, firstHalf.events);
    // 結果だけ見る試合(判断を仰がない)では、ハーフタイムと後半の途中
    // (60〜75分)の交代を監督が自動で行う。ライブ観戦の試合は利用者が
    // 交代するので触らない。
    _liveAutoSubPlans = [];
    final autoSubs = !interactive && !_liveWasInteractive && resume == null;
    final userId = _save!.userTeamId;
    // 自クラブがこの試合で使える残りの交代枠(人数)。
    int userSubsLeft() =>
        GameState.maxSubstitutionsPerMatch -
        _liveSubstitutionsUsed -
        [
          for (final plan in _liveAutoSubPlans)
            if (plan.team.id == userId) ...plan.swaps,
        ].length;
    // 自動の交代の出来事(試合経過に出す)。ハーフタイムと後半の途中。
    final halfTimeSubEvents = <MatchEvent>[];
    final lateSubEvents = <MatchEvent>[];
    void autoSubstitute({
      required int homeGoalDiff,
      required Set<String> excluded,
      required int tiredFatigue,
      required bool countsAsWindow,
      required int minute,
    }) {
      for (final team in [home, away]) {
        final isUser = team.id == userId;
        if (isUser &&
            countsAsWindow &&
            _liveSubWindowsUsed >= GameState.maxSubstitutionWindowsPerMatch) {
          continue;
        }
        final cpuUsed = [
          for (final plan in _liveAutoSubPlans)
            if (plan.team.id == team.id) ...plan.swaps,
        ].length;
        final plan = MatchEngine.applyHalfTimeSubstitutions(
          team,
          goalDiff: team.id == home.id ? homeGoalDiff : -homeGoalDiff,
          maxSubs: isUser
              ? userSubsLeft()
              : GameState.maxSubstitutionsPerMatch - cpuUsed,
          excludedIds: excluded,
          tiredFatigue: tiredFatigue,
        );
        if (plan.swaps.isEmpty) continue;
        _liveAutoSubPlans.add(plan);
        (countsAsWindow ? lateSubEvents : halfTimeSubEvents)
            .addAll(MatchEngine.substitutionEventsOf(plan, minute));
        if (isUser && countsAsWindow) _liveSubWindowsUsed++;
      }
    }

    if (autoSubs) {
      autoSubstitute(
        homeGoalDiff: firstHalf.homeGoals - firstHalf.awayGoals,
        excluded: MatchEngine.sentOffIds(firstHalf.events),
        tiredFatigue: MatchEngine.autoSubTiredFatigue,
        countsAsWindow: false,
        minute: 46,
      );
    }
    // 前半に退場した選手は後半に出さず、数的不利も後半まで続ける。
    final InteractiveHalfState state;
    if (autoSubs) {
      // 後半を60〜75分の交代の前後に分けて進める。
      final lateMinute = MatchEngine.rollLateSubMinute();
      final partA = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 46,
        endMinute: lateMinute,
        interactiveTeamId: userId,
        weather: weather,
        homeAdvantageFactor: _homeAdvantageFor(home.id),
        priorEvents: firstHalf.events,
      );
      while (!partA.isFinished) {
        MatchEngine.resolvePendingChance(partA, ChanceDecision.shoot);
      }
      final a = partA.toHalfResult();
      autoSubstitute(
        homeGoalDiff: firstHalf.homeGoals +
            a.homeGoals -
            firstHalf.awayGoals -
            a.awayGoals,
        excluded: {
          ...MatchEngine.sentOffIds([...firstHalf.events, ...a.events]),
          for (final plan in _liveAutoSubPlans)
            for (final sw in plan.swaps) sw.out.id,
        },
        tiredFatigue: MatchEngine.lateAutoSubTiredFatigue,
        countsAsWindow: true,
        minute: lateMinute,
      );
      state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: lateMinute + 1,
        endMinute: 90,
        interactiveTeamId: userId,
        weather: weather,
        homeAdvantageFactor: _homeAdvantageFor(home.id),
        priorEvents: firstHalf.events,
        carried: HalfTally(
          homeGoals: a.homeGoals,
          awayGoals: a.awayGoals,
          events: a.events,
          homeShots: a.homeShots,
          awayShots: a.awayShots,
          homeShotsOnTarget: a.homeShotsOnTarget,
          awayShotsOnTarget: a.awayShotsOnTarget,
          possessionShareSum: a.possessionShareSum,
          chanceCount: a.chanceCount,
        ),
      );
    } else {
      state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: resume?.resumeMinute ?? 46,
        endMinute: 90,
        interactiveTeamId: userId,
        weather: weather,
        homeAdvantageFactor: _homeAdvantageFor(home.id),
        carried: resume?.tally,
        priorEvents: firstHalf.events,
      );
    }
    // 交代の出来事を後半の出来事に入れる(画面は分の順に並べる)。ハーフ
    // タイムの交代は頭に、後半の途中の交代は、それまでの出来事(引き継いだ
    // 途中経過)のあとに。
    final halfTime = [..._liveHalfTimeSubEvents, ...halfTimeSubEvents];
    _liveHalfTimeSubEvents = [];
    final carriedCount = state.carried?.events.length ?? 0;
    state.events.insertAll(0, halfTime);
    state.events.insertAll(
        (halfTime.length + carriedCount).clamp(0, state.events.length),
        lateSubEvents);
    if (!interactive) {
      while (!state.isFinished) {
        MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
      }
    }
    _liveSecondHalfState = state;

    if (state.isFinished) {
      return _finalizeSecondHalf(state.toHalfResult());
    }
    _recordLiveProgress();
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
      _recordLiveProgress();
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
      _recordLiveProgress();
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
      subbedOff: [
        for (final plan in _liveAutoSubPlans) ...plan.subbedOff,
      ],
    );
    final statsBefore = {
      for (final p in userTeam.players)
        p.id: (goals: p.careerGoals, apps: p.careerAppearances),
    };
    // 警告と出場停止は、この試合の大会(リーグ戦は国と節)の決まりで数える。
    CardRules.run(
      _liveCardRules,
      () => MatchEngine.applyPostMatchEffects(
        home: home,
        away: away,
        homeInjuryFactor: _injuryFactorFor(home.id),
        awayInjuryFactor: _injuryFactorFor(away.id),
        events: allEvents,
        weather: weather,
      ),
    );
    // 後の交代から戻す(後半の途中の交代の「元」の先発は、ハーフタイムの
    // 交代のあとのもの。前から戻すとハーフタイムの交代が先発に残る)。
    for (final plan in _liveAutoSubPlans.reversed) {
      MatchEngine.finishHalfTimeSubstitutions(plan, events: allEvents);
    }
    _liveAutoSubPlans = [];
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

    var merged = MatchResult(
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
      _publishFrontPage(merged, f, lastMilestones);
      // 出来高の契約の選手の得点に、出来高を払う。
      _payGoalBonuses(merged);
      // 途中から出た選手に、出場手当の半額を払う(先発の分は試合の前)。
      final subFees = AppearanceFeeEngine.feesFor(userTeam, merged,
          includeStarters: false);
      if (subFees > 0) {
        _book(LedgerCategory.appearanceFees, -subFees);
        lastAppearanceFeesPaid += subFees;
      }
      // 優勝・昇格・降格が決まったか、カップの決勝を戦い終えたか。
      _checkClinchMoments(f.matchday);
      // 移籍の締切日なら知らせる。
      _checkDeadlineMoment();
      _checkCupFinalMoments();
      // クラブの文化に沿った試合なら、サポーターが喜ぶ。
      _applyCultureBonus(merged);
      // クラブの歴代記録(出場・得点・最大の勝ち試合)。
      _recordClubMatch(merged, f);

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
      // 延長戦の得点を含めた結果を、フルタイムの画面に返す。
      merged = _applyLiveCupResult(merged);
    }
    // 記者会見は出さない(オーナーの仕事ではない)。
    _liveFixture = null;
    _liveCupKind = null;
    _liveCupHome = null;
    _liveCupAway = null;
    _liveCupWeather = null;
    _liveCupMatch = null;
    _liveCupTie = null;
    _liveFirstHalfState = null;
    _liveSecondHalfState = null;
    _liveSecondHalfResume = null;
    _save!.liveMatchProgress = null;
    _liveSubstitutionsUsed = 0;
    _liveSubWindowsUsed = 0;
    _liveSubWindowKey = null;
    _liveHalfTimeSubEvents = [];
    _liveWasInteractive = false;
    CardRules.current = CardRules.generic;

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

    _playDueCpuCupMatches();
    if (canPlayNextContinentalMatch) {
      final cup = _userContinentalCup;
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
    // 4クラブのスーパーカップ(スペイン・イタリア)の自クラブの試合。
    if (canPlayNextFourClubSuperCupMatch) {
      await playNextFourClubSuperCupMatch();
    }
  }

  /// 現在の順位表を起点に、残り試合をチーム総合力ベースで簡易シミュレー
  /// ションし、シーズン最終順位の見込み(優勝/大陸カップ出場/降格の確率)
  /// を算出する。実際の試合結果には影響しない参考情報。
  List<TeamProjection> get seasonProjection => SeasonProjectionEngine.project(
        _save!.league,
        relegationCount: _save!.currentDivisionTier < totalDivisionTiers
            ? currentLeagueTheme
                .rulesBelow(_save!.currentDivisionTier)
                .relegationZone
            : 0,
        // 大陸カップ(チャンピオンズカップ)の出場枠は1部の上位のみ(2部は
        // 対象外)。枠の数は国の係数で3〜5に変わるので、季の締めの判定と
        // 同じ continentalSpots を使う。
        continentalQualifyCount:
            _save!.currentDivisionTier == 1 ? continentalSpots : 0,
      );

  /// カップ戦・大陸大会に出るクラブ(自国の1〜3部の全部と、大陸大会の
  /// 他国・その他の国のクラブ)。国内カップは1〜3部の全クラブが出る
  /// (2026-11-22)。
  List<Team> get allTeamsForCups => [
        ..._save!.league.teams,
        for (final l in _save!.otherDivisionLeagues)
          if (l != null) ...l.teams,
        ..._save!.continentalTeams,
      ];

  /// 新聞の一面と監督の試合後の一言を作る(自クラブのリーグ戦のあと)。
  void _publishFrontPage(MatchResult r, Fixture f, List<String> milestones) {
    final s = _save!;
    final userId = s.userTeamId;
    if (r.homeTeamId != userId && r.awayTeamId != userId) return;
    final home = r.homeTeamId == userId;
    final oppId = home ? r.awayTeamId : r.homeTeamId;
    final opp = s.league.teams.where((t) => t.id == oppId).firstOrNull;
    final gf = home ? r.homeGoals : r.awayGoals;
    final ga = home ? r.awayGoals : r.homeGoals;
    final rank =
        s.league.sortedStandings.indexWhere((x) => x.teamId == userId) + 1;
    s.frontPageHeadline = FrontPageEngine.headline(
      club: s.clubName,
      opponent: opp?.name ?? '-',
      goalsFor: gf,
      goalsAgainst: ga,
      derby: isRivalFixture(f),
      rank: rank,
      milestones: milestones,
    );
    final style =
        s.infrastructure.staffFor(StaffRole.manager)?.manager?.style ??
            ManagerStyle.pragmatic;
    s.frontPageQuote = FrontPageEngine.managerQuote(
        goalsFor: gf, goalsAgainst: ga, style: style);
  }

  /// クラブの文化。
  ClubCulture get clubCulture =>
      ClubCulture.values.firstWhere((c) => c.name == _save?.clubCulture,
          orElse: () => ClubCulture.none);

  /// 文化を変えられるか(1季に1回まで)。
  bool get canChangeClubCulture =>
      _save != null && _save!.clubCultureChangedSeason != _save!.league.season;

  /// クラブの文化を選ぶ。決めたものから変えると、古いサポーターが戸惑う。
  Future<bool> setClubCulture(ClubCulture c) async {
    final s = _save;
    if (s == null || !canChangeClubCulture || c == clubCulture) return false;
    if (clubCulture != ClubCulture.none) {
      s.confidence =
          (s.confidence - ClubCultureEngine.changePenalty).clamp(0, 100);
    }
    s.clubCulture = c.name;
    s.clubCultureChangedSeason = s.league.season;
    _addTimeline(Tr.pick(
        'クラブの文化を「${c.label}」にした', 'Set the club identity to "${c.label}"'));
    _notify();
    await _persist();
    return true;
  }

  void _applyCultureBonus(MatchResult r) {
    final s = _save!;
    final team = userTeam;
    final starters = [
      for (final p in team.players)
        if (team.startingXI.contains(p.id)) p,
    ];
    final bonus = ClubCultureEngine.matchBonus(
        culture: clubCulture, r: r, userId: s.userTeamId, starters: starters);
    if (bonus > 0) s.confidence = (s.confidence + bonus).clamp(0, 100);
  }
}
