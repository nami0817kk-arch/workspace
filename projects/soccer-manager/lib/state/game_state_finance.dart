part of 'game_state.dart';

/// 評判・理事会・記者会見・ライバル・観客動員・財務(収入/週給予算/融資/定期預金)。
extension GameStateFinance on GameState {
  /// 監督としての世間の評価(0-100)。
  int get managerReputation => _save?.managerReputation ?? 50;

  /// ユーザークラブが現在所属するディビジョン(1が最上位、[totalDivisionTiers]が最下位)。
  int get currentDivisionTier => _save?.currentDivisionTier ?? 1;

  /// 画面表示用のリーグ名(いまの部の名前。2026-11-22 から部ごとに名前がある)。
  String get leagueDisplayName => _save == null
      ? Tr.pick('リーグ', 'League')
      : currentLeagueTheme.divisionName(currentDivisionTier);

  /// 保存されているリーグ名から国風テーマを逆引きする(テーマ自体は
  /// SaveGameに保持していないため、開幕時に確定した表示名から復元する)。
  LeagueTheme get currentLeagueTheme =>
      leagueThemeFromName(_save?.leagueName) ?? LeagueTheme.england;

  /// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴。新しい順。
  List<SeasonAward> get seasonAwards =>
      (_save?.seasonAwards ?? const <SeasonAward>[]).reversed.toList();

  List<SeasonRecord> get seasonHistory =>
      (_save?.seasonHistory ?? const <SeasonRecord>[]).reversed.toList();

  List<SeasonBestEleven> get bestElevenHistory =>
      (_save?.bestElevenHistory ?? const <SeasonBestEleven>[])
          .reversed
          .toList();

  /// 表示待ちのシーズン中盤理事会レビュー講評。ない場合はnull。
  String? get pendingBoardReviewMessage => _save?.pendingBoardReviewMessage;

  /// シーズン中盤理事会レビューの内容を確認済みにする。
  Future<void> dismissBoardReview() async {
    if (_save == null) return;
    _save!.pendingBoardReviewMessage = null;
    _notify();
    await _persist();
  }

  /// 回答待ちの記者会見の質問。ない場合はnull。
  ///
  /// 監督としての試合後の記者会見は、オーナー型への作り替え(#1009)で
  /// 質問を作る仕組みと画面ごと外した(試合後の会見はオーナーの仕事では
  /// ない)。いまは旧セーブの読み書きのために残してあり、新しく積まれる
  /// ことは無い。オーナーとして答える記者会見は、移籍の噂への答え
  /// (game_state_rumors.dart・ホーム画面の RumorCard)が受け持つ。
  PressQuestion? get pendingPressConference => _save?.pendingPressConference;

  /// 記者会見の質問に回答する。信頼度・選手全体の士気に選んだ選択肢の効果を反映する。
  Future<void> answerPressConference(int optionIndex) async {
    if (_save == null) return;
    final question = _save!.pendingPressConference;
    if (question == null ||
        optionIndex < 0 ||
        optionIndex >= question.options.length) {
      return;
    }
    final option = question.options[optionIndex];
    _changeSupporters(option.confidenceDelta, SupporterReason.events);
    for (final p in userTeam.players) {
      p.morale = (p.morale + option.moraleDelta).clamp(0, 100);
    }
    _save!.pendingPressConference = null;
    _notify();
    await _persist();
  }

  /// 他クラブから監督就任オファーが届いている場合、そのクラブ。
  ///
  /// **相手が今のリーグに居なければ、オファーを消して null を返す。**
  /// 保留中に相手が昇降格で別のリーグへ移ると、`firstWhere` が投げて
  /// ホーム画面が開くたびに落ち、セーブが詰んでいた。
  Team? get pendingJobOfferTeam {
    final save = _save;
    if (save == null) return null;
    final teamId = save.pendingJobOfferTeamId;
    if (teamId == null) return null;
    final team = _findTeam(save.league.teams, teamId);
    if (team == null) save.pendingJobOfferTeamId = null;
    return team;
  }

  Future<bool> acceptJobOffer() async {
    if (_save == null || _save!.pendingJobOfferTeamId == null) return false;
    final newTeamId = _save!.pendingJobOfferTeamId!;
    final newTeam = _findTeam(_save!.league.teams, newTeamId);
    if (newTeam == null) {
      // 相手が別のリーグへ移った。オファーは成り立たないので消すだけ。
      _save!.pendingJobOfferTeamId = null;
      _notify();
      await _persist();
      return false;
    }
    final newTeamName = newTeam.name;
    _save!.userTeamId = newTeamId;
    // 移籍金の簿価は前のクラブのもの。新しいクラブには持ち込まない。
    _save!.playerBook.clear();
    _save!.pendingJobOfferTeamId = null;
    _save!.confidence = 60;
    _resetSupporterRecords();
    _save!.shareholderExpectation = 60;
    _save!.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(_save!.league, newTeamId),
    );
    _save!.clubHistory.add(newTeamName);
    _resetFanDemand(_save!);
    _notify();
    await _persist();
    return true;
  }

  Future<void> declineJobOffer() async {
    if (_save == null) return;
    _save!.pendingJobOfferTeamId = null;
    _notify();
    await _persist();
  }

  /// 資金が尽きたとみなす線: 借金(資金のマイナス)がその部の年収の目安の
  /// この割合を超えたら。他のクラブが破綻する線
  /// ([GameStateClubFinance.collapseShare])と同じ。
  static const double fundsExhaustedShare = 0.5;

  /// これより資金が少なければ、資金が尽きている(万円。マイナスの額)。
  int get fundsExhaustedLine => _save == null
      ? 0
      : -(typicalAnnualIncome(currentDivisionTier, currentLeagueTheme) *
              fundsExhaustedShare)
          .round();

  /// 資金が尽きたか。借金が[fundsExhaustedLine]を超え、週の締めでも
  /// マイナスだった(移籍金などで一瞬だけ割り込んだのでは数えない)。
  bool get isFundsExhausted {
    final save = _save;
    if (save == null) return false;
    return save.budget <= fundsExhaustedLine &&
        save.consecutiveNegativeBudgetWeeks > 0;
  }

  /// クラブを手放すことになった理由。迫られていなければ null。
  ///
  /// 理由は2つだけ(2026-11-23): 資金が尽きたときと、サポーターの期待が
  /// 尽きたとき。オーナーは雇われる立場ではないので、理事会との契約の満了
  /// で辞めさせられることは無い。株主の期待が尽きても手放さない(株主総会
  /// の要求などで重くなるだけ)。両方のときはサポーターを先に見る。
  ///
  /// サポーターは、期待が10を割ると最後通告が出て、3か月のうちに10以上へ
  /// 戻せなかったときに手放す(2026-11-23。以前は0になった瞬間だった)。
  SaleReason? get saleReason {
    final save = _save;
    if (save == null) return null;
    if (supporterUltimatumExpired) return SaleReason.supporters;
    if (isFundsExhausted) return SaleReason.funds;
    return null;
  }

  /// いま追っているオーナーの目標。決めていなければ null。
  OwnerGoal? get ownerGoal => _save?.ownerGoal;

  /// 選べる目標。すでに1部にいるなら「1部へ昇格」は出さない。
  List<OwnerGoal> get selectableOwnerGoals => [
        for (final g in OwnerGoal.values)
          if (!(g == OwnerGoal.reachTopDivision && currentDivisionTier <= 1)) g,
      ];

  /// 達成した目標の記録(新しい順)。
  List<String> get achievedGoals =>
      (_save?.achievedGoals ?? const <String>[]).reversed.toList();

  /// 目標を決める。いまのシーズンから期限を数える。
  Future<void> setOwnerGoal(OwnerGoal goal) async {
    final save = _save;
    if (save == null || !selectableOwnerGoals.contains(goal)) return;
    save.ownerGoal = goal;
    save.ownerGoalStartSeason = save.league.season;
    save.ownerGoalStartValue = clubValue.total;
    _notify();
    await _persist();
  }

  /// 目標の期限までの残りシーズン数(今季を含む)。目標が無ければ 0。
  int get ownerGoalSeasonsLeft {
    final save = _save;
    final goal = save?.ownerGoal;
    if (save == null || goal == null) return 0;
    return (save.ownerGoalStartSeason +
            goal.deadlineSeasons -
            save.league.season)
        .clamp(0, goal.deadlineSeasons);
  }

  /// シーズン終了時に、目標の達成と期限切れを見る。達成は殿堂に残り、
  /// 2つの期待を少し持ち上げる。期限切れは目標が消えるだけで、罰は無い。
  void _evaluateOwnerGoal({required int season}) {
    final save = _save;
    final goal = save?.ownerGoal;
    if (save == null || goal == null) return;
    final recs =
        save.seasonHistory.where((r) => r.season >= save.ownerGoalStartSeason);
    final met = OwnerGoalRules.isMet(
      goal,
      wonTopLeague: recs.any((r) => r.wonLeague && r.divisionTier == 1),
      promotedOrTop: recs.any(
          (r) => r.divisionTier == 1 || (r.promoted && r.divisionTier == 2)),
      // 国内カップの優勝だけ(リーグカップ・大陸大会の優勝は数えない)。
      wonCup: recs.any((r) => r.wonDomesticCup),
      budget: save.budget,
      valueRatio: save.ownerGoalStartValue > 0
          ? clubValue.total / save.ownerGoalStartValue
          : 0,
      topFourCount:
          recs.where((r) => r.divisionTier == 1 && r.finalRank <= 4).length,
      unbeaten: recs.any((r) => r.played > 0 && r.lost == 0),
      stadiumLevel: save.infrastructure.facilityLevel(FacilityType.stadium),
      healthScore: ClubHealthEngine.assess(
        supporter: save.confidence,
        shareholder: save.shareholderExpectation,
        wageRatio: save.ledgerFor(season).wageRatio,
        budget: save.budget,
      ).score,
      supporter: save.confidence,
      shareholder: save.shareholderExpectation,
    );
    if (met) {
      save.achievedGoals.add(Tr.pick(
          '${save.clubName}: ${goal.label}(シーズン$season)',
          '${save.clubName}: ${goal.label} (season $season)'));
      save.ownerGoal = null;
      _changeSupporters(10, SupporterReason.events,
          note: Tr.pick('オーナーの目標「${goal.label}」を達成',
              'Owner goal achieved: ${goal.label}'));
      save.shareholderExpectation =
          (save.shareholderExpectation + 10).clamp(0, 100);
      _logNews(
        Tr.pick('オーナーの目標「${goal.label}」を達成しました。殿堂に残ります。',
            'Owner goal achieved: ${goal.label}. It joins your hall of fame.'),
        context: Tr.pick('オーナー', 'Owner'),
      );
    } else if (OwnerGoalRules.isExpired(goal,
        startSeason: save.ownerGoalStartSeason, season: season)) {
      save.ownerGoal = null;
      _logNews(
        Tr.pick('オーナーの目標「${goal.label}」は期限までに果たせませんでした。新しい目標を決められます。',
            'The owner goal "${goal.label}" was not reached in time. You can set a new one.'),
        context: Tr.pick('オーナー', 'Owner'),
      );
    }
  }

  /// 試合にオーナーは直接関わらない。先発と構えは、毎節かならず監督が決める。
  /// 穴(負傷・出場停止)を埋め、水準が高ければ相手との力関係から構えを、
  /// さらに高ければ最善の先発を選ぶ。プレッシング・ライン・幅・テンポ・
  /// 戦術スタイル・逃げ切りは、監督の考え方から毎節決める(ManagerTactics)。
  /// セットプレーの担当も毎節決める。
  /// キャプテンは季の初めの節と、務められなくなったときに指名し直す。
  void _managerPreparesMatch(Fixture next) {
    final save = _save;
    if (save == null) return;
    final user = userTeam;
    final oppId =
        next.homeTeamId == user.id ? next.awayTeamId : next.homeTeamId;
    final opp = _findTeam(save.league.teams, oppId);
    if (opp == null) return;
    final level = save.infrastructure.staffLevel(StaffRole.manager);
    // 監督の水準が高いほど任せられる。低い監督は穴埋めまで、中くらいは
    // 相手に合わせた構えまで、高い監督は最善の先発まで決める。
    if (level >= 4) {
      LineupUtils.autoFill(user);
    } else {
      LineupUtils.fillVacancies(user);
    }
    final style =
        save.infrastructure.staffFor(StaffRole.manager)?.manager?.style ??
            ManagerStyle.pragmatic;
    if (level >= 3) {
      // 相手に合わせた構えを、監督の考え方の分だけずらす。
      user.mentality = style.shift(CpuTacticsAI.mentalityFor(
        ownRating: user.overallRating,
        opponentRating: opp.overallRating,
      ));
    }
    ManagerTactics.apply(user, style: style, level: level, opponent: opp);
    // セットプレーの担当(PK・FK・CK・守備)も、CPU と同じ決め方で監督が
    // 毎節決める。以前はユーザーのクラブだけ決める所が無く、空のままだった。
    LineupUtils.autoAssignSetPieceRoles(user);
    if (next.matchday == 1 || ManagerTactics.needsNewCaptain(user)) {
      _managerAppointsCaptain();
    }
  }

  /// 判断待ちの事件。無ければ null。
  OwnerEventKind? get pendingOwnerEvent => _save?.pendingOwnerEvent;

  /// 事件が起きる節。1シーズンに3回(12節ごと、6・18・30節)。
  static bool isOwnerEventMatchday(int matchday) =>
      matchday > 0 && matchday % 12 == 6;

  /// その節に事件が起きるなら、判断待ちに積む。すでに待っている事件があれば
  /// 積まない(判断を溜めさせない)。
  ///
  /// 事件は、いまの状況で起こりうるものから選ぶ([ownerEventCanHappen])。
  /// 首位なのに「成績への不満でスポンサーが撤退」のような、本文と状況が
  /// 食い違う事件は起こさない。
  void _maybeRaiseOwnerEvent(int matchday) {
    final save = _save;
    if (save == null || save.pendingOwnerEvent != null) return;
    if (!GameStateFinance.isOwnerEventMatchday(matchday)) return;
    final kinds = OwnerEventKind.values.where(ownerEventCanHappen).toList();
    if (kinds.isEmpty) return;
    final kind = kinds[
        Random(save.league.season * 1000 + matchday).nextInt(kinds.length)];
    save.pendingOwnerEvent = kind;
    // 「主力が長期離脱します」は、答えを待つ前に起きている出来事。
    if (kind == OwnerEventKind.injuryCrisis) _injureKeyPlayerForEvent();
  }

  /// [kind] の事件が、いまの状況で起こりうるか(本文が言っていることと
  /// 状況が合うか)。
  bool ownerEventCanHappen(OwnerEventKind kind) {
    final save = _save;
    if (save == null) return false;
    switch (kind) {
      case OwnerEventKind.sponsorExit:
        // 「成績への不満から」なので、順位が下半分のときだけ。
        final rows = save.league.sortedStandings;
        final rank = rows.indexWhere((r) => r.teamId == save.userTeamId) + 1;
        return rank > 0 && rank > rows.length / 2;
      case OwnerEventKind.transferDemand:
        // 売れるエースがいて、売っても人数が足りるときだけ。
        return _ownerEventAce != null && userTeam.players.length > minSquadSize;
      case OwnerEventKind.injuryCrisis:
        return _ownerEventKeyPlayer != null;
      case OwnerEventKind.youthPoach:
        return save.youthProspects.isNotEmpty;
      case OwnerEventKind.managerPoach:
      case OwnerEventKind.managerClash:
        return save.infrastructure.staffFor(StaffRole.manager) != null;
      case OwnerEventKind.rivalProvocation:
        return rivalTeam != null;
      default:
        return true;
    }
  }

  /// 事件の「エース」: 自クラブで市場価値がいちばん高い選手(借りている・
  /// 貸し出している選手は除く)。
  Player? get _ownerEventAce {
    final list = [
      for (final p in userTeam.players)
        if (!p.isLoan && !p.isLoanedOut) p
    ]..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    return list.firstOrNull;
  }

  /// 事件の「主力」: いま出られる選手のうち、総合力がいちばん高い選手。
  Player? get _ownerEventKeyPlayer {
    final list = [
      for (final p in userTeam.players)
        if (!p.isLoanedOut && !p.isInjured) p
    ]..sort((a, b) => b.overall.compareTo(a.overall));
    return list.firstOrNull;
  }

  /// 事件の「ユースの逸材」: 伸びしろがいちばん大きいユースの選手。
  Player? get _ownerEventYouth {
    final list = [..._save!.youthProspects]
      ..sort((a, b) => b.potential.compareTo(a.potential));
    return list.firstOrNull;
  }

  /// 事件で長期離脱する週数(靭帯損傷のいちばん長い療養期間)。
  static int get ownerEventInjuryWeeks => InjuryType.ligament.durationRange.$2;

  /// 慰留したエースに約束する昇給の倍率。
  static const double ownerEventAceRaise = 1.2;

  /// 「主力が長期離脱」: 主力を実際に長期の怪我にする。
  void _injureKeyPlayerForEvent() {
    final p = _ownerEventKeyPlayer;
    if (p == null) return;
    final weeks = ownerEventInjuryWeeks;
    p.injuryWeeks = weeks;
    p.injuryType = InjuryType.ligament;
    p.injuryHistoryCounts[InjuryType.ligament.name] =
        (p.injuryHistoryCounts[InjuryType.ligament.name] ?? 0) + 1;
    final team = userTeam;
    if (team.startingXI.remove(p.id)) LineupUtils.fillVacancies(team);
    _logNews(
        Tr.pick('${p.name}が靭帯を痛め、約$weeks週離脱する。',
            '${p.name} has damaged a ligament and is out for about ${Tr.plural(weeks, 'week')}.'),
        context: Tr.pick('負傷', 'Injury'));
  }

  /// 事件の答えが、期待と資金のほかに起こすこと(画面に添える一文)。
  /// 無ければ null。
  String? ownerEventOptionEffect(OwnerEventKind kind, int optionIndex) {
    final save = _save;
    if (save == null) return null;
    final raisePct = ((ownerEventAceRaise - 1) * 100).round();
    switch ((kind, optionIndex)) {
      case (OwnerEventKind.transferDemand, 0):
        final ace = _ownerEventAce;
        if (ace == null) return null;
        return Tr.pick('${ace.name}の給与を$raisePct%上げる',
            'Wages for ${ace.name} go up $raisePct%');
      case (OwnerEventKind.transferDemand, 1):
        final ace = _ownerEventAce;
        if (ace == null) return null;
        return Tr.pick('${ace.name}が移籍(移籍金${formatMoney(ace.marketValue)})',
            '${ace.name} leaves (fee ${formatMoney(ace.marketValue)})');
      case (OwnerEventKind.youthPoach, 0):
        final y = _ownerEventYouth;
        if (y == null) return null;
        return Tr.pick('ユースの${y.name}が移る', 'Academy player ${y.name} leaves');
      case (OwnerEventKind.managerPoach, 1):
        final m = save.infrastructure.staffFor(StaffRole.manager);
        if (m == null) return null;
        return Tr.pick('${m.name}監督が去る', 'Manager ${m.name} leaves');
      default:
        return null;
    }
  }

  /// 事件の答えが言っていることを、実際に起こす(エースの売却・昇給、
  /// ユースの引き抜き、監督の退任)。
  void _applyOwnerEventOption(OwnerEventKind kind, int optionIndex) {
    final save = _save!;
    switch ((kind, optionIndex)) {
      case (OwnerEventKind.transferDemand, 0):
        final ace = _ownerEventAce;
        if (ace == null) return;
        ace.wage = (ace.wage * ownerEventAceRaise).round();
        _logNews(
            Tr.pick('${ace.name}を昇給で慰留した。',
                'You kept ${ace.name} with a pay rise.'),
            context: Tr.pick('オーナー', 'Owner'));
      case (OwnerEventKind.transferDemand, 1):
        final ace = _ownerEventAce;
        final team = userTeam;
        if (ace == null || team.players.length <= minSquadSize) return;
        final fee = ace.marketValue;
        team.players.removeWhere((p) => p.id == ace.id);
        final wasStarter = team.startingXI.remove(ace.id);
        _clearPlayerRoleReferences(team, ace.id);
        if (wasStarter) LineupUtils.autoFill(team);
        save.incomingOffers.removeWhere((o) => o.playerId == ace.id);
        // 買い手(他の部・他の国も)へ移す。見つからなければどこにも移さない。
        // 連帯貢献金の国際の判定に使うので、記帳より先に決める。
        final buyer = _buyerFor(ace, fee, GameState._offerRng);
        if (buyer != null) _movePlayerToBuyer(ace, buyer.name, fee: fee);
        _book(LedgerCategory.playerSales, fee);
        // オファーを受けた売却と同じ道を通す(連帯貢献金・クラブ史上最高額・
        // 簿価の償却・「売らない」と言った約束)。_onPlayerSold は売値を
        // 記帳しないので、上の playerSales と重ならない。
        _onPlayerSold(ace, fee, buyerClubName: buyer?.name);
        _paySellOn(ace, fee);
        _friendsMissPlayer(ace);
        _logNews(
            Tr.pick('移籍を求めた${ace.name}の売却を認めた。移籍金${formatMoney(fee)}が入った。',
                'You let ${ace.name} go as he asked. The ${formatMoney(fee)} fee is in.'),
            context: Tr.pick('移籍', 'Transfer'));
      case (OwnerEventKind.youthPoach, 0):
        final y = _ownerEventYouth;
        if (y == null) return;
        save.youthProspects.removeWhere((p) => p.id == y.id);
        _logNews(
            Tr.pick('ユースの${y.name}が、違約金を残して他クラブへ移った。',
                'Academy player ${y.name} has left for another club, with a release fee paid.'),
            context: Tr.pick('ユース', 'Youth'));
      case (OwnerEventKind.managerPoach, 1):
        final m = save.infrastructure.staffFor(StaffRole.manager);
        if (m == null) return;
        save.infrastructure.staff[StaffRole.manager] = null;
        _logNews(
            Tr.pick('${m.name}監督が、違約金を残して他クラブへ移った。後任を探す必要がある。',
                'Manager ${m.name} has left for another club, with compensation paid. You need a replacement.'),
            context: Tr.pick('スタッフ', 'Staff'));
      default:
        return;
    }
  }

  /// 事件に答える。選んだ答えの期待と資金の増減を反映し、答えが言っている
  /// こと(エースの売却など)を実際に起こす。
  Future<bool> resolveOwnerEvent(int optionIndex) async {
    final save = _save;
    final kind = save?.pendingOwnerEvent;
    if (save == null || kind == null) return false;
    final options = kind.options;
    if (optionIndex < 0 || optionIndex >= options.length) return false;
    final o = options[optionIndex];
    _changeSupporters(o.supportersDelta, SupporterReason.events);
    save.shareholderExpectation =
        (save.shareholderExpectation + o.shareholdersDelta).clamp(0, 100);
    if (o.fundsDelta != 0) {
      _book(LedgerCategory.other, scaledMoney(o.fundsDelta));
    }
    _applyOwnerEventOption(kind, optionIndex);
    save.pendingOwnerEvent = null;
    _notify();
    await _persist();
    return true;
  }

  /// オーナーの仕事を、いま打てるか。打ち止めになっている・資金が足りない
  /// ときは打てない。広報・ファンの手は、どれか1つを月に1回
  /// (2026-11-23。サポーターの期待をオーナーの手で動かせるように)。
  /// ほかの手は1シーズンに1回ずつ。
  bool canDoOwnerWork(OwnerWork work) {
    final save = _save;
    if (save == null) return false;
    if (ownerWorkDoneThisSeason(work)) return false;
    if (work.onlyInRed && save.budget >= 0) return false;
    // 支出が要らない手は、資金がマイナスでも打てる(危機の手がそう)。
    return work.cost == 0 || save.budget >= scaledMoney(work.cost);
  }

  /// 打ち止めになっている仕事か(広報・ファンの手は今月、ほかは今季)。
  bool ownerWorkDoneThisSeason(OwnerWork work) {
    final save = _save;
    if (save == null) return false;
    if (work.monthly) return fanWorkDoneThisMonth;
    return save.ownerWorkDoneSeason[work.id] == save.league.season;
  }

  /// [work]をいま打ったときのサポーターの期待の増減。資金0の会見
  /// ([OwnerWork.wearsOff])は、同じ季に打った回数だけ1ずつ減る(下限0)。
  int ownerWorkSupporters(OwnerWork work) {
    final save = _save;
    if (save == null || !work.wearsOff) return work.supporters;
    final uses =
        save.visionPressSeason == save.league.season ? save.visionPressUses : 0;
    return max(0, work.supporters - uses);
  }

  /// オーナーの仕事を打つ。資金と2つの期待に反映し、打ち止めにする。
  Future<bool> doOwnerWork(String id) async {
    final save = _save;
    if (save == null) return false;
    final work = ownerWorks.where((w) => w.id == id).firstOrNull;
    if (work == null || !canDoOwnerWork(work)) return false;
    final supporters = ownerWorkSupporters(work);
    if (work.wearsOff) {
      if (save.visionPressSeason != save.league.season) {
        save.visionPressSeason = save.league.season;
        save.visionPressUses = 0;
      }
      save.visionPressUses++;
    }
    _changeSupporters(
        supporters,
        switch (work.category) {
          OwnerWorkCategory.fans => SupporterReason.pr,
          OwnerWorkCategory.community => SupporterReason.community,
          _ => SupporterReason.events,
        });
    save.shareholderExpectation =
        (save.shareholderExpectation + work.shareholders).clamp(0, 100);
    _book(LedgerCategory.other, scaledMoney(work.funds));
    if (work.monthly) {
      save.fanWorkMonthKey = currentMonthKey;
    } else {
      save.ownerWorkDoneSeason[work.id] = save.league.season;
    }
    _notify();
    await _persist();
    return true;
  }

  /// 提携クラブ。いなければ null。
  Team? get partnerClub {
    final save = _save;
    final id = save?.partnerClubId;
    if (save == null || id == null) return null;
    return save.league.teams.where((t) => t.id == id).firstOrNull;
  }

  /// 提携できる相手(自クラブ以外)。
  List<Team> get partnerCandidates {
    final save = _save;
    if (save == null) return const [];
    return save.league.teams.where((t) => t.id != save.userTeamId).toList();
  }

  /// 他クラブと提携する。すでに提携していれば結び直す。自クラブや
  /// 存在しないクラブとは結べない。
  Future<bool> setPartnerClub(String teamId) async {
    final save = _save;
    if (save == null) return false;
    if (teamId == save.userTeamId) return false;
    final team = save.league.teams.where((t) => t.id == teamId).firstOrNull;
    if (team == null) return false;
    save.partnerClubId = teamId;
    _logNews(
        Tr.pick('${team.name}と提携した。毎季の提携費は${formatMoney(partnerSeasonCost)}。',
            'Partnered with ${team.name}. The fee is ${formatMoney(partnerSeasonCost)} per season.'),
        context: Tr.pick('提携', 'Partnership'));
    _notify();
    await _persist();
    return true;
  }

  /// 毎季の提携費(今の部の規模)。
  int get partnerSeasonCost => scaledMoney(PartnerClubEngine.seasonCost);

  /// 提携を解消する。
  Future<void> clearPartnerClub() async {
    final save = _save;
    if (save == null || save.partnerClubId == null) return;
    save.partnerClubId = null;
    _notify();
    await _persist();
  }

  /// シーズン終了時の提携の処理。提携費を払い、2つの期待を上げる。
  /// 払えなければ提携は解消される。
  void _settlePartnerClub() {
    final save = _save!;
    final team = partnerClub;
    if (team == null) {
      save.partnerClubId = null;
      return;
    }
    if (save.budget < partnerSeasonCost) {
      save.partnerClubId = null;
      _logNews(
          Tr.pick('資金が足りず、${team.name}との提携は解消された。',
              'The partnership with ${team.name} lapsed for lack of funds.'),
          context: Tr.pick('提携', 'Partnership'));
      return;
    }
    _book(LedgerCategory.other, -partnerSeasonCost);
    _changeSupporters(
        PartnerClubEngine.supportersBonus, SupporterReason.events);
    save.shareholderExpectation =
        (save.shareholderExpectation + PartnerClubEngine.shareholdersBonus)
            .clamp(0, 100);
    _logNews(
        Tr.pick('${team.name}との提携で、知名度が上がった。',
            'The partnership with ${team.name} raised our profile.'),
        context: Tr.pick('提携', 'Partnership'));
  }

  /// テスト用: 提携の季末の処理だけを走らせる。
  @visibleForTesting
  void debugSettlePartnerClub() => _settlePartnerClub();

  /// テスト用: 今日を [day] まで進める(あいだの給与日・入金日も処理する)。
  @visibleForTesting
  void debugAdvanceTodayTo(DateTime day) => _advanceTodayTo(day);

  /// 日付で終わるローンを今日の日付で片付ける(テスト用)。
  @visibleForTesting
  void debugSettleLoansByDate() => _settleLoansByDate();

  /// 次の節に打つと決めた試合日のイベント。無ければ null。
  MatchdayPromo? get activeMatchdayPromo {
    final id = _save?.matchdayPromoId;
    if (id == null) return null;
    return matchdayPromos.where((p) => p.id == id).firstOrNull;
  }

  /// 次の節の試合日のイベントを決める。費用を先に払う。すでに決めていれば
  /// 先に取り消さないと決められない。資金が足りなくても決められない。
  Future<bool> setMatchdayPromo(String id) async {
    final save = _save;
    if (save == null || save.matchdayPromoId != null) return false;
    final promo = matchdayPromos.where((p) => p.id == id).firstOrNull;
    if (promo == null) return false;
    final cost = scaledMoney(promo.cost);
    if (cost > 0 && save.budget < cost) return false;
    if (cost > 0) _book(LedgerCategory.other, -cost);
    save.matchdayPromoId = promo.id;
    _notify();
    await _persist();
    return true;
  }

  /// 決めた試合日のイベントを取り消す。節の前なので、費用は戻る。
  Future<bool> cancelMatchdayPromo() async {
    final save = _save;
    final promo = activeMatchdayPromo;
    if (save == null || promo == null) return false;
    final cost = scaledMoney(promo.cost);
    if (cost > 0) _book(LedgerCategory.other, cost);
    save.matchdayPromoId = null;
    _notify();
    await _persist();
    return true;
  }

  /// 節を終えたとき、試合日のイベントの効きを2つの期待に反映して使い切る。
  void _consumeMatchdayPromo() {
    final save = _save!;
    final promo = activeMatchdayPromo;
    if (promo == null) {
      save.matchdayPromoId = null;
      return;
    }
    _changeSupporters(promo.supporters, SupporterReason.pr);
    save.shareholderExpectation =
        (save.shareholderExpectation + promo.shareholders).clamp(0, 100);
    save.matchdayPromoId = null;
  }

  /// テスト用: 節を終えたときの試合日のイベントの処理だけを走らせる。
  @visibleForTesting
  void debugConsumeMatchdayPromo() => _consumeMatchdayPromo();

  /// テスト用: その節の事件の判定だけを走らせる。
  @visibleForTesting
  void debugRaiseOwnerEvent(int matchday) => _maybeRaiseOwnerEvent(matchday);

  /// テスト用: シーズン終了時の規則の判定だけを走らせる。
  @visibleForTesting
  void debugEnforceLeagueRules() => _enforceLeagueRules();

  /// テスト用: 季の締めの償却(移籍金の1年分を費用にする)だけを走らせる。
  @visibleForTesting
  void debugAmortizeTransferFees() => _amortizeTransferFees();

  /// テスト用: 季の締めの、年に1回の分割払いだけを走らせる。
  @visibleForTesting
  void debugPayAnnualInstallments() => _payAnnualInstallments();

  /// テスト用: 季の締めのパラシュートの更新だけを走らせる。
  @visibleForTesting
  void debugUpdateParachute({required int playedTier, required int newTier}) =>
      _updateParachute(playedTier: playedTier, newTier: newTier);

  /// テスト用: 週給の予算と補強禁止を見る判定だけを走らせる。
  @visibleForTesting
  bool debugAllowsSigning(int wage) => _wageBudgetAllowsSigning(wage);

  /// テスト用: 監督のふだんの試合の準備だけを走らせる。
  @visibleForTesting
  void debugManagerPreparesMatch(Fixture next) => _managerPreparesMatch(next);

  /// テスト用: シーズン終了時の目標の判定だけを走らせる。
  @visibleForTesting
  void debugEvaluateOwnerGoal({required int season}) =>
      _evaluateOwnerGoal(season: season);

  /// 資金かサポーターの期待が尽き、クラブを手放さなければならない状態か。
  bool get isSaleForced => saleReason != null;

  /// 手放したあとに買い直せるクラブの候補(最大3つ)。いまのリーグから、
  /// 総合力の下位・中位・上位に1つずつ。強いほど資金の立て直しが楽だが、
  /// 期待も重い。
  List<Team> get buyoutCandidates {
    final save = _save;
    if (save == null) return const [];
    final others = save.league.teams
        .where((t) => t.id != save.userTeamId)
        .toList()
      ..sort((a, b) => a.overallRating.compareTo(b.overallRating));
    if (others.length <= 3) return others;
    return [others.first, others[others.length ~/ 2], others.last];
  }

  /// 手放すクラブの実績(殿堂に残す1行)。
  OwnerLegacy _legacyOfCurrentClub(SaleReason reason) {
    final save = _save!;
    final mine =
        save.seasonHistory.where((r) => r.clubName == save.clubName).toList();
    final ranks = mine.map((r) => r.finalRank).where((r) => r > 0);
    return OwnerLegacy(
      clubName: save.clubName,
      seasons: mine.length,
      leagueTitles: mine.where((r) => r.wonLeague).length,
      cupTitles: mine.fold<int>(0, (t, r) => t + r.cupsWon.length),
      bestRank: ranks.isEmpty ? 0 : ranks.reduce((a, b) => a < b ? a : b),
      reason: reason,
    );
  }

  /// クラブを買い直したとき、前のクラブに付いていた収入・契約を外す
  /// (2026-11-23。以前は命名権・枠のスポンサー・パラシュートなどが
  /// 新しいクラブへ持ち越されていた)。
  void _clearPreviousClubDeals() {
    final save = _save!;
    save.sponsorDeal = null;
    save.namingDeal = null;
    save.pendingNamingOffers = [];
    save.slotSponsors = {};
    save.slotSponsorOffers = {};
    save.parachuteFromTier = 0;
    save.parachuteSeasonsLeft = 0;
    save.tvHolidaySeasons = 0;
    save.seasonTicketShare = 0;
    save.seasonTicketSeason = 0;
    // 前のクラブが結んだ支払い・条項は、そのクラブに残る。
    save.pendingInstallments = [];
    save.sellOnClauses = {};
    save.buyBacks = {};
    save.incomingOffers = [];
    save.stadiumSubsidyPct = 0;
  }

  /// 売却を迫られたクラブを手放し、[teamId] を買い直す。
  ///
  /// 実績は殿堂に残る。新しいクラブでは2つの期待が60に戻り、資金・施設・
  /// スタッフ・融資・スポンサーは初期の状態から始める(予算の配り方は引き継ぐ)。
  Future<bool> buyClub(String teamId) async {
    final save = _save;
    final reason = saleReason;
    if (save == null || reason == null) return false;
    final team = _findTeam(save.league.teams, teamId);
    if (team == null || team.id == save.userTeamId) return false;

    save.ownerLegacies.add(_legacyOfCurrentClub(reason));
    // 手放したクラブの貸し借りを清算する(自クラブを替える前に)。
    _settleLoansOfFormerClub(userTeam);
    // 手放したクラブを覚えておく(季の終わりにその後を知らせる)。
    save.formerClubs[save.userTeamId] = save.clubName;
    save.formerClubs.remove(team.id);
    save.formerClubStatus.remove(team.id);
    save.userTeamId = team.id;
    save.clubName = team.name;
    // 移籍金の簿価・規則の罰は前のクラブのもの。
    save.playerBook.clear();
    save.wageFreezeSeasons = 0;
    save.wageFreezeCap = 0;
    save.adminRelegation = false;
    save.licenseGraceTier = 0;
    save.pendingJobOfferTeamId = null;
    save.confidence = 60;
    _resetSupporterRecords();
    save.shareholderExpectation = 60;
    _settleOwnerLoanOnClubChange();
    save.ownerShare = 100;
    // 新しいクラブは、そのクラブの元の見た目から。
    save.clubLook = null;
    save.clubLookChangedSeason = 0;
    save.budget = (GameState.initialBudgetFor(
                save.currentDivisionTier, currentLeagueTheme) *
            save.difficultyOf(DifficultyItem.funds).initialBudgetFactor)
        .round();
    save.infrastructure = ClubInfrastructure();
    _clearPreviousClubDeals();
    save.pendingSponsorOffers = _economyAdjusted(SponsorEngine.generateOffers(
        team.overallRating,
        tier: save.currentDivisionTier));
    save.bankLoans = [];
    save.youthProspects = [];
    save.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(save.league, team.id),
    );
    save.wageBudget = BoardEngine.wageBudgetFor(
      tier: save.currentDivisionTier,
      currentWeeklyWageBill: weeklyWageBill,
      theme: currentLeagueTheme,
    );
    save.clubHistory.add(team.name);
    // ファンの需要も新しいクラブのもの。
    _resetFanDemand(save);
    // クラブ価値は新しいクラブのものとして数え直す。
    save.clubValueHistory.clear();
    // クラブの歴代記録も新しいクラブのものとして数え直す。
    _resetClubRecords();
    if (save.ownerGoal == OwnerGoal.clubValue) {
      save.ownerGoalStartValue = clubValue.total;
    }
    _refreshStaffCandidates();
    _assignRivalOwners();
    _notify();
    await _persist();
    return true;
  }

  /// 手放すクラブ[old]の貸し借りを終わらせる。ローンの清算は自クラブにしか
  /// 回らないため、以前は買い直しの後、手放したクラブの貸し出していた選手が
  /// 「貸し出し中」の印のまま試合に出られず、借りていた選手も貸し元へ
  /// 戻らなかった(2026-11-23)。
  ///
  /// - 貸し出していた選手: 手放すクラブへ戻る(印を消す)。
  /// - 借りていた選手: 貸し元へ戻る。貸し元の無い旧セーブの選手は、
  ///   そのまま手放すクラブの選手にする。
  void _settleLoansOfFormerClub(Team old) {
    var changed = false;
    for (final p in old.players) {
      if (!p.isLoanedOut) continue;
      _endLoanOutSilently(p);
      changed = true;
    }
    final borrowed = old.players.where((p) => p.isLoan).toList();
    for (final p in borrowed) {
      changed = true;
      p.loanObligation = false;
      if (p.loanFromClubId == null) {
        p.isLoan = false;
        p.loanEndDate = null;
        p.loanBuyOptionFee = null;
        if (p.loanBaseWage != null) p.wage = p.loanBaseWage!;
        p.loanBaseWage = null;
        continue;
      }
      old.players.remove(p);
      old.startingXI.remove(p.id);
      _clearPlayerRoleReferences(old, p.id);
      _returnLoanToParent(p);
    }
    if (changed) LineupUtils.autoFill(old);
  }

  /// 別の国のクラブを新しく立ち上げて、続きを遊ぶ。その国の規則に従い、
  /// 新しい国のピラミッドの最下部(3部)から始まる。実績は殿堂に残る。
  Future<bool> buyClubInCountry(LeagueTheme theme) async {
    final save = _save;
    final reason = saleReason;
    if (save == null || reason == null) return false;
    if (theme == currentLeagueTheme) return false;
    // 5部制のときは4部からだった。3部制では最下部の3部から(2026-11-22)。
    const startTier = totalDivisionTiers;
    final rng = Random();
    // クラブ名は実在の今季の顔ぶれに寄せて、部ごとに決まっている。
    final namesByTier = {
      for (var t = 1; t <= totalDivisionTiers; t++)
        t: NamePool.clubNamesForTier(theme, t, theme.teamsInTier(t) + 1),
    };
    final cursor = <int, int>{};
    String nextName([int tier = startTier]) {
      final i = cursor[tier] ?? 0;
      cursor[tier] = i + 1;
      return namesByTier[tier]![i];
    }

    int strengthForTier(int tier) => rollDivisionStrength(tier, rng);

    // 前のクラブで進めた今日(リーグを入れ替える前に控える)。
    final reachedDay = today;
    save.ownerLegacies.add(_legacyOfCurrentClub(reason));
    // 手放したクラブの貸し借りを清算する(借りていた選手は他国の貸し元へ戻る)。
    _settleLoansOfFormerClub(this.userTeam);

    // 年俸の水準は新しい国・部のもの(他の部のクラブはその部の水準)。
    setHomeWageLevel(theme, startTier);
    final userTeam = GameState.generateUserStartSquad(
        name: nextName(), tier: startTier, theme: theme);
    final others = List<League?>.filled(totalDivisionTiers, null);
    League? mine;
    final cpuInMine = <Team>[];
    for (var tier = 1; tier <= totalDivisionTiers; tier++) {
      final teams = <Team>[
        if (tier == startTier) userTeam,
        ...withWageLevel(
          wageCountryFactor(theme, tier),
          () => [
            for (var i = 0;
                i <
                    (tier == startTier
                        ? theme.teamsInTier(tier) - 1
                        : theme.teamsInTier(tier));
                i++)
              PlayerGenerator.generateSquad(
                id: tier == startTier ? 'cpu$i' : 'div${tier}_$i',
                name: nextName(tier),
                strengthTier: strengthForTier(tier),
              ),
          ],
        ),
      ];
      for (final t in teams) {
        LineupUtils.autoFill(t);
      }
      final league = League(
        teams: teams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(teams),
        season: save.league.season,
      );
      if (tier == startTier) {
        mine = league;
        cpuInMine.addAll(teams.where((t) => t.id != 'user'));
      } else {
        others[tier - 1] = league;
      }
    }

    save.userTeamId = 'user';
    save.clubName = userTeam.name;
    // 移籍金の簿価・規則の罰は前のクラブのもの。
    save.playerBook.clear();
    save.wageFreezeSeasons = 0;
    save.wageFreezeCap = 0;
    save.adminRelegation = false;
    save.licenseGraceTier = 0;
    save.leagueName = theme.label;
    save.ruleSet = RuleSet.forTheme(theme);
    save.league = mine!;
    save.otherDivisionLeagues = others;
    save.currentDivisionTier = startTier;
    _ensureWorldSquads(save);
    _applyTieBreakRules();
    // 国内カップは1〜3部の全クラブ、リーグカップはイングランドだけ。
    save.cups = _newSeasonCups();
    // 新しい国の大陸大会(自国の1部の強い順と、他国の1部の上位)。
    save.continentalCup = null;
    save.secondContinentalCup = null;
    save.continentalTeams = [];
    _rememberForeignTop();
    _setUpContinentalCups(
      tier1Order: [...?_teamsByTierNow()[1]]
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating)),
    );
    save.friendlies = _generateFriendlies(mine.teams, 'user');
    // 新しい国のリーグは開幕前から始まる。日付もそのシーズンのオフに戻す。
    //
    // 日付を戻さずに季の途中から入る形は取らない。新しいリーグ・カップ・
    // 大陸大会は第1節から組み直すので、日付を残すと過ぎた節がみな今日に
    // 詰まって消化され(休養日なし・毎試合が過密)、窓や入金日とも合わない。
    // 代わりに、戻した期間をもう一度進めても二重にならないよう、前の
    // クラブで進めた記録をここで片付ける(2026-11-23):
    // - オーナーの本業の収入と誕生日は、済ませた日を控えて、その日より後
    //   の分だけ入れる([SaveGame.personalDatesThrough])。
    // - 週の処理の時計・自クラブの最後の試合の日は、前のクラブの季の途中の
    //   日付のまま残ると、その日まで週の処理が止まる・過密の判定がずれる。
    // - 試合前の処理を済ませた節と試合の途中経過は前のリーグのもの。残すと
    //   同じ番号の節が「途中で終わった試合の再開」と取り違えられる。
    // - 月間最優秀監督の集計済みの節・中間レビューも前のリーグの節で数えた
    //   もの。
    final through = save.personalDatesThrough;
    if (through == null || reachedDay.isAfter(through)) {
      save.personalDatesThrough = reachedDay;
    }
    save.today = SeasonCalendar.preseasonDate(save.league.season);
    save.lastWeeklyTickDate = null;
    save.lastUserMatchDate = null;
    save.lastWeekCongested = false;
    save.weekProcessedSeason = 0;
    save.weekProcessedMatchday = 0;
    save.liveMatchProgress = null;
    save.lastManagerOfMonthCheckpoint = 0;
    save.boardReviewDoneThisSeason = false;
    save.pendingBoardReviewMessage = null;
    save.trainingDoneThisWeek = false;
    // 1月1日の仮契約の解禁と3月31日の延長オプションの締めも、前のクラブで
    // 済ませた印のままだと新しい国の季で走らない。
    save.preContractOpenedSeason = 0;
    save.optionDeadlineSeason = 0;
    final rival = cpuInMine[rng.nextInt(cpuInMine.length)];
    save.rivalTeamId = rival.id;
    save.rivalTeamName = rival.name;
    save.rivalPast = [0, 0, 0];
    save.pendingJobOfferTeamId = null;
    save.pendingOwnerEvent = null;
    save.pendingPressConference = null;
    save.pendingContractNegotiation = null;
    save.incomingOffers = [];
    save.proposals = [];
    save.declinedProposalIds = [];
    save.confidence = 60;
    _resetSupporterRecords();
    save.shareholderExpectation = 60;
    _settleOwnerLoanOnClubChange();
    save.ownerShare = 100;
    // 新しいクラブは、そのクラブの元の見た目から。
    save.clubLook = null;
    save.clubLookChangedSeason = 0;
    save.budget = (GameState.initialBudgetFor(startTier, theme) *
            save.difficultyOf(DifficultyItem.funds).initialBudgetFactor)
        .round();
    save.infrastructure = ClubInfrastructure();
    _clearPreviousClubDeals();
    save.pendingSponsorOffers = _economyAdjusted(
        SponsorEngine.generateOffers(userTeam.overallRating, tier: startTier));
    save.economyVersion = SaveGame.currentEconomyVersion;
    save.bankLoans = [];
    save.youthProspects = [];
    save.projects = {};
    save.advisors = {};
    save.communityLevel = 0;
    save.reserveFund = 0;
    save.insured = false;
    save.retiredLegends.clear();
    save.retiredNumberIds.clear();
    save.boardTargetRank = _difficultyAdjustedTarget(
      BoardEngine.estimateTargetRank(save.league, 'user'),
    );
    save.boardCupTargetRound = _estimateDomesticCupTarget();
    save.wageBudget = BoardEngine.wageBudgetFor(
      tier: startTier,
      currentWeeklyWageBill: weeklyWageBill,
      theme: theme,
    );
    save.clubHistory.add(userTeam.name);
    _resetFanDemand(save);
    save.clubValueHistory.clear();
    // クラブの歴代記録も新しいクラブのものとして数え直す(オーナーの経歴は残る)。
    _resetClubRecords();
    if (save.ownerGoal == OwnerGoal.clubValue) {
      save.ownerGoalStartValue = clubValue.total;
    }
    transferMarket = [];
    _refreshScoutCandidates();
    _refreshStaffCandidates();
    _assignRivalOwners();
    _addTimeline(Tr.pick(
        '${theme.label}(${theme.flavorLabel})で新しいクラブ${userTeam.name}を立ち上げた',
        'Founded ${userTeam.name} in the ${theme.label}'));
    _notify();
    await _persist();
    return true;
  }

  /// ライバルクラブ(開幕時に決定、以後固定)。未設定の場合はnull。
  Team? get rivalTeam {
    final id = _save?.rivalTeamId;
    if (id == null) return null;
    try {
      return _save!.league.teams.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 今シーズンの宿敵との戦績(終わった試合だけ)。
  ({int won, int draw, int lost}) get rivalRecordThisSeason {
    final save = _save;
    if (save == null) return (won: 0, draw: 0, lost: 0);
    var w = 0, d = 0, l = 0;
    for (final f in save.league.fixtures) {
      final r = f.result;
      if (r == null || !isRivalFixture(f)) continue;
      final mine = f.homeTeamId == save.userTeamId ? r.homeGoals : r.awayGoals;
      final theirs =
          f.homeTeamId == save.userTeamId ? r.awayGoals : r.homeGoals;
      if (mine > theirs) {
        w++;
      } else if (mine == theirs) {
        d++;
      } else {
        l++;
      }
    }
    return (won: w, draw: d, lost: l);
  }

  /// 宿敵との通算の戦績(過去のシーズン+今季)。
  ({int won, int draw, int lost}) get rivalRecord {
    final save = _save;
    if (save == null) return (won: 0, draw: 0, lost: 0);
    final now = rivalRecordThisSeason;
    final past = save.rivalPast;
    return (
      won: past[0] + now.won,
      draw: past[1] + now.draw,
      lost: past[2] + now.lost,
    );
  }

  /// シーズン末に、今季の宿敵との戦績を通算へ足す。
  void _closeRivalSeason() {
    final save = _save!;
    final now = rivalRecordThisSeason;
    if (now.won + now.draw + now.lost == 0) return;
    save.rivalPast[0] += now.won;
    save.rivalPast[1] += now.draw;
    save.rivalPast[2] += now.lost;
    if (now.won >= 2 && now.lost == 0) {
      _addTimeline(Tr.pick('宿敵に今季は負けなし(${now.won}勝${now.draw}分)',
          'Unbeaten against the rivals this season (${now.won}W ${now.draw}D)'));
    }
  }

  /// 指定した対戦カードが自クラブ対ライバルクラブの「ダービー」かどうか。
  bool isRivalFixture(Fixture f) {
    final rivalId = _save?.rivalTeamId;
    if (rivalId == null) return false;
    final userId = _save!.userTeamId;
    return (f.homeTeamId == userId && f.awayTeamId == rivalId) ||
        (f.homeTeamId == rivalId && f.awayTeamId == userId);
  }

  /// 入場収入の係数(0.0-1.0)。監督への信頼度と現在の順位に連動する。
  /// 収入の式(weeklyIncomeParts)の釣り合いはこの係数で合わせてある
  /// (test/economy_scale_test.dart)。観客の人数は [expectedAttendance]
  /// (ファンの需要×[userAttendanceRate])で数える。
  double get userAttendanceFactor {
    if (_save == null) return 0.0;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final teamCount = league.teams.length;
    var factor =
        (0.7 + _save!.confidence / 250 + (teamCount - rank) / teamCount * 0.3)
            .clamp(0.6, 1.4);
    // 下位ディビジョンほど観客動員が少ない(ティアごとに段階的に低下する)。
    factor *= pow(0.8, _save!.currentDivisionTier - 1).toDouble();
    factor *= _save!.ticketPricing.attendanceMultiplier;
    // ファンの層の満足(上下5%まで)。
    factor *= fanAttendanceModifier;
    return factor.clamp(0.0, 1.0);
  }

  /// 自クラブのスタジアム収容人数。
  int get stadiumCapacity => _save == null
      ? 0
      : ClubInfrastructure.stadiumCapacity(
          _save!.infrastructure.facilityLevel(FacilityType.stadium),
        );

  /// スタジアムに来たいファンの数(需要、人)。季末に成績・昇格・降格で
  /// 動く(FanDemandEngine)。
  int get fanDemand {
    final save = _save;
    if (save == null) return 0;
    if (save.fanDemand > 0) return save.fanDemand;
    return FanDemandEngine.initial(
        tier: save.currentDivisionTier,
        reputation: save.managerReputation,
        capacity: stadiumCapacity);
  }

  /// 需要を持たないセーブ(古いセーブ・新しいクラブ)に、部と規模から
  /// 需要を作って持たせる。
  void _ensureFanDemand(SaveGame save) {
    if (save.fanDemand > 0) return;
    save.fanDemand = FanDemandEngine.initial(
        tier: save.currentDivisionTier,
        reputation: save.managerReputation,
        capacity: ClubInfrastructure.stadiumCapacity(
            save.infrastructure.facilityLevel(FacilityType.stadium)));
  }

  /// 新しいクラブに移ったとき、そのクラブの需要を作り直す。
  void _resetFanDemand(SaveGame save) {
    save.fanDemand = 0;
    _ensureFanDemand(save);
  }

  /// 季末に需要を動かす(成績・昇格・降格)。
  void _advanceFanDemand(
      {required int playedTier,
      required int newTier,
      required int finalRank,
      required int teamCount}) {
    final save = _save!;
    save.fanDemand = FanDemandEngine.nextSeason(
      demand: fanDemand,
      playedTier: playedTier,
      newTier: newTier,
      finalRank: finalRank,
      teamCount: teamCount,
      reputation: save.managerReputation,
    );
  }

  /// 動員率(需要のうち、実際に来る割合)。ふだんは9割ほど。順位で上下
  /// 10%(年間シートが多いので大きくは動かない)、信頼度で上下5%、
  /// 入場料・ファンの層の満足で変わる。
  double get userAttendanceRate {
    final save = _save;
    if (save == null) return 0.0;
    final league = save.league;
    final rank = league.sortedStandings
            .indexWhere((r) => r.teamId == save.userTeamId) +
        1;
    final rate = (0.92 +
            FanDemandEngine.rankSwing(rank, league.teams.length) +
            (save.confidence - 50) / 1000) *
        save.ticketPricing.attendanceMultiplier *
        fanAttendanceModifier;
    return rate.clamp(0.3, 1.3);
  }

  /// 通常開催時に見込まれる観客動員数。需要×動員率と、収容人数の
  /// 小さいほう(席を増やしても、来たい人より多くは入らない)。
  int get expectedAttendance =>
      min((fanDemand * userAttendanceRate).round(), stadiumCapacity);

  /// 入場収入の式に入れるスタジアムの段(1〜)。席のうち、ファンの需要で
  /// 埋まるぶんだけを数える。需要が収容人数以上なら今のLvのまま。
  double get _filledStadiumLevel {
    final level =
        _save!.infrastructure.facilityLevel(FacilityType.stadium).toDouble();
    final usable = min(stadiumCapacity, fanDemand);
    final base = ClubInfrastructure.stadiumCapacity(1);
    final step =
        ClubInfrastructure.stadiumCapacity(2) - ClubInfrastructure.stadiumCapacity(1);
    return min(level, max(1.0, 1 + (usable - base) / step));
  }

  int weeklyIncomeFor(String teamId) {
    final p = weeklyIncomeParts(teamId);
    return p.gate + p.sponsor + p.merchandise + p.broadcast;
  }

  /// 5部の額 [base] を、今いる部の規模に直す。費用・賞金など「クラブの
  /// 規模で決まる額」は、記帳と画面の表示の両方がここを通る(片方だけ
  /// 直すと、表示と実際に動く額がずれる)。
  int scaledMoney(int base) => scaleMoneyForTier(currentDivisionTier, base);

  /// [tier] 部の規模に直した額。シーズン末の精算のように、部が変わる
  /// 前の部で数えたいときに使う。
  int scaledMoneyFor(int tier, int base) => scaleMoneyForTier(tier, base);

  /// 1シーズンの節の数(国によって部のクラブ数が違うので一定ではない)。
  int get matchdaysPerSeason {
    final save = _save;
    if (save == null) return 38;
    final n = save.league.fixtures
        .fold<int>(0, (m, f) => f.matchday > m ? f.matchday : m);
    return n > 0 ? n : 38;
  }

  /// 毎節入る放映権料(万円)。部で決まり、順位や施設では変わらない。
  int get weeklyBroadcastIncome => (weeklyBroadcast(currentDivisionTier,
              matchdays: matchdaysPerSeason, theme: currentLeagueTheme) *
          currentEra.tvFactor)
      .round();

  /// 選手の給与を毎節いくら払うか。表示の年俸(週俸×52)と1年に払う
  /// 総額が一致するよう、52週ぶんをその年の節の数で割る。
  int get matchdayPlayerWageCost => _save == null
      ? 0
      : perMatchdayFromWeekly(
          ContractEngine.weeklyWageBill(userTeam), matchdaysPerSeason);

  /// スタッフの給与を毎節いくら払うか(選手と同じく年額を節で割る)。
  int get matchdayStaffWageCost => _save == null
      ? 0
      : perMatchdayFromWeekly(
          scaledMoney(_save!.infrastructure.totalStaffWeeklyWage),
          matchdaysPerSeason);

  /// 選手の給与を毎月末にいくら払うか(年俸の12分の1)。
  int get monthlyPlayerWageCost => _save == null
      ? 0
      : MoneyCalendar.monthlyFromWeekly(
          ContractEngine.weeklyWageBill(userTeam));

  /// スタッフの給与を毎月末にいくら払うか。
  int get monthlyStaffWageCost => _save == null
      ? 0
      : MoneyCalendar.monthlyFromWeekly(
          scaledMoney(_save!.infrastructure.totalStaffWeeklyWage));

  /// 今日が [before] から [after] へ進んだあいだのお金の日(給与の月末・
  /// 放映権の入金日)を、日付の順に処理する。
  void _settleMoneyDates(DateTime before, DateTime after) {
    final events = <(DateTime, bool)>[
      for (final d in MoneyCalendar.monthEndsBetween(before, after)) (d, true),
      for (final d in MoneyCalendar.broadcastDatesBetween(before, after))
        (d, false),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (day, isWage) in events) {
      if (isWage) {
        _book(LedgerCategory.staffWages, -monthlyStaffWageCost);
        _book(LedgerCategory.playerWages, -monthlyPlayerWageCost);
        _book(LedgerCategory.operations, -monthlyRunningCost);
      } else {
        _book(LedgerCategory.broadcast, broadcastInstallmentOn(day));
      }
    }
  }

  /// [day] の放映権の入金額(入金日でなければ0)。最下位でも受け取る年額
  /// ([guaranteedBroadcastAnnual])の4分の1。順位と中継の上乗せは季末に入る。
  int broadcastInstallmentOn(DateTime day) {
    final i = MoneyCalendar.broadcastIndexOf(day);
    if (i == null) return 0;
    // 降格したクラブには、上の部との差の一部(パラシュート)が上乗せされる。
    // 時代で放映権の額が変わる(guaranteedBroadcastAnnual に入っている)。
    return MoneyCalendar.broadcastInstallment(
        guaranteedBroadcastAnnual + parachuteAnnual, i);
  }

  /// 第[matchday]節が祝日なら、その祝日の名前。
  String? holidayOfMatchday(int matchday) =>
      MoneyCalendar.holidayName(dateOfMatchday(matchday), currentLeagueTheme);

  /// 第[matchday]節の試合の日に入る見込みの収入(観客・スポンサー・グッズ。
  /// 祝日なら客が増える。放映権は入金日に別に入る)。
  ///
  /// 年間シートを売った季は、先に受け取ったぶん([seasonTicketShareNow]%)の
  /// 入場収入を除く。試合の日の実際の入金(game_state_match の節の処理)と
  /// 同じ計算: 祝日で増えた分は当日券なのでそのまま入る。
  int expectedMatchdayIncome(int matchday) {
    if (_save == null) return 0;
    final p = weeklyIncomeParts(_save!.userTeamId);
    final income = p.gate + p.sponsor + p.merchandise;
    final soldAhead =
        p.gate - SeasonTicketEngine.remainingGate(p.gate, seasonTicketShareNow);
    if (holidayOfMatchday(matchday) == null) return income - soldAhead;
    final base = expectedAttendance;
    return GameState.derbyAdjustedIncome(
          income,
          baseAttendance: base,
          actualAttendance:
              MoneyCalendar.holidayAttendance(base, stadiumCapacity),
        ) -
        soldAhead;
  }

  /// 今日より後のお金の予定(給与日・放映権の入金日・リーグ戦の日)を
  /// 日付の順に [count] 件。
  List<({DateTime date, String label, int amount})> upcomingMoneyDates(
      {int count = 8}) {
    final save = _save;
    if (save == null) return const [];
    final from = today;
    final horizon = DateTime(from.year + 1, from.month, from.day);
    final wages =
        monthlyPlayerWageCost + monthlyStaffWageCost + monthlyRunningCost;
    final out = <({DateTime date, String label, int amount})>[
      for (final d in MoneyCalendar.monthEndsBetween(from, horizon))
        (
          date: d,
          label: Tr.pick('給与(選手・スタッフ)と運営費の支払い',
              'Wages (players and staff) and running costs paid'),
          amount: -wages,
        ),
      for (final d in MoneyCalendar.broadcastDatesBetween(from, horizon))
        (
          date: d,
          label: Tr.pick(
              '放映権の入金(${MoneyCalendar.broadcastIndexOf(d)! + 1}/4回目)',
              'Broadcast payment (${MoneyCalendar.broadcastIndexOf(d)! + 1} of 4)'),
          amount: broadcastInstallmentOn(d),
        ),
    ];
    final seen = <int>{};
    for (final f in save.league.fixtures) {
      if (f.result != null) continue;
      if (f.homeTeamId != save.userTeamId && f.awayTeamId != save.userTeamId) {
        continue;
      }
      if (!seen.add(f.matchday)) continue;
      final d = dateOfMatchday(f.matchday);
      if (!d.isAfter(from) && d != from) continue;
      final holiday = holidayOfMatchday(f.matchday);
      out.add((
        date: d,
        label: holiday == null
            ? Tr.pick('第${f.matchday}節の試合の収入', 'Matchday ${f.matchday} income')
            : Tr.pick('第${f.matchday}節の試合の収入($holiday・客が増える)',
                'Matchday ${f.matchday} income ($holiday, bigger crowd)'),
        amount: expectedMatchdayIncome(f.matchday),
      ));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out.take(count).toList();
  }

  /// 資金が動く唯一の入口。資金を増減させ、同じ額をそのシーズンの収支の
  /// 記録に残す。ここを通さずに資金だけ動かすと、損益計算書の合計が実際の
  /// 資金とずれる。収入は正、支出は負で渡す。
  ///
  /// 移籍金の償却([LedgerCategory.isNonCash])だけは資金を動かさず、記録に
  /// だけ残す(払ったときに資金は減っている)。
  void _book(LedgerCategory category, int delta) {
    final save = _save!;
    if (!category.isNonCash) save.budget += delta;
    save.ledgerFor(save.league.season).add(category, delta);
  }

  /// 観客収入の順位の上乗せ(1つ上の順位ごと)と土台。
  static const int gateRankStep = 6;
  static const int gateBase = 280;

  /// 1節あたりの観客収入の上限(万円)。1年で「入る人数([expectedAttendance])
  /// × ホームの試合の数 × 1人の単価([gateRevenuePerFan])× 値段の倍率」に
  /// なるよう、節の数で均す(観客収入は毎節、平均として入れているため)。
  /// 試合日のイベントの上乗せは、この上限の外で掛ける。
  int get gateCapPerMatchday {
    final save = _save;
    if (save == null) return 0;
    final md = matchdaysPerSeason;
    if (md <= 0) return 0;
    final homeGames = save.league.fixtures
        .where((f) => f.homeTeamId == save.userTeamId)
        .length;
    final home = homeGames > 0 ? homeGames : md ~/ 2;
    return (expectedAttendance *
            home /
            md *
            gateRevenuePerFan(currentDivisionTier) *
            save.ticketPricing.revenueMultiplier)
        .round();
  }

  /// 週の収入の内訳(観客・スポンサー・グッズ・放映権)。合計は
  /// [weeklyIncomeFor] と必ず一致する(端数はグッズに寄せる)。他クラブは
  /// 観客収入と放映権だけを持つ。
  ///
  /// 観客とグッズは今いる部の規模([incomeScale])を掛ける。スポンサーと
  /// 命名権は、結んだときの部の規模で契約の額が決まっている(昇格・降格の
  /// 条項で額は動く: SponsorEngine.divisionChangeFactor)ので、ここでは
  /// 掛けない。
  ({int gate, int sponsor, int merchandise, int broadcast}) weeklyIncomeParts(
      String teamId) {
    if (_save == null) {
      return (gate: 0, sponsor: 0, merchandise: 0, broadcast: 0);
    }
    final scale = incomeScale(currentDivisionTier);
    final broadcast = weeklyBroadcastIncome;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == teamId) + 1;
    final teamCount = league.teams.length;
    // 順位の上乗せは1つにつき6(以前は20で、上位ほど観客収入が倍近く
    // なり、1部の上位が資金を雪だるま式に増やした)。真ん中のクラブの
    // 額が変わらないよう、土台を上げてある(2026-11-23)。
    final rankBonus = ((teamCount - rank) * gateRankStep).clamp(0, 999);
    final base = gateBase + rankBonus;
    if (teamId != _save!.userTeamId) {
      return (
        gate: (base * scale).round(),
        sponsor: 0,
        merchandise: 0,
        broadcast: broadcast,
      );
    }

    // スタジアムの段は、ファンの需要で埋まる席のぶんだけ数える(来たい人
    // より多い席は、建てても入場料を生まない)。
    final stadiumLevel = _filledStadiumLevel;
    final commercialMultiplier = ClubInfrastructure.commercialRevenueMultiplier(
      _save!.infrastructure.facilityLevel(FacilityType.commercialFacility),
    );
    var matchdayIncome = ((base + (stadiumLevel - 1) * 80) *
            userAttendanceFactor *
            _save!.ticketPricing.revenueMultiplier *
            FacilityInvestmentEngine.gateMultiplier(_save!.facilityMomentum) *
            commercialMultiplier *
            scale)
        .round();
    // 入る人数 × 1人の単価で頭打ちにする(席とファンの需要より多くは
    // 払われない)。試合日のイベントの上乗せは頭打ちの後に掛ける(お金を
    // 払った催しで場内の売上が伸びるぶんは、ふだんの単価の外にある。
    // 頭打ちの前に掛けると、上限に届いているクラブでは何も生まなかった)。
    matchdayIncome = (min(matchdayIncome, gateCapPerMatchday) *
            (activeMatchdayPromo?.gateMultiplier ?? 1.0))
        .round();
    // 2部リーグは1部より観客動員が少ない(userAttendanceFactorに反映済み)。
    final sponsorIncome = (((_save!.sponsorDeal?.weeklyIncome ?? 0) +
                (_save!.namingDeal?.weeklyIncome ?? 0) +
                slotSponsorWeeklyIncome) *
            commercialMultiplier)
        .round();
    // グッズ収入(マーチャンダイジング)。試合の有無に関わらず、監督の評価
    // (=クラブの知名度)が高いほど、商業施設が充実しているほど増える。
    // チケット・スポンサーだけに依存しない収入源として資金繰りを下支えする。
    // 人気の選手がいるほどグッズが売れる(上位3人の人気から)。
    final merchandiseIncome = ((40 +
                managerReputation +
                PlayerPopularityEngine.weeklyMerchBonus(
                    userTeam.players.where((p) => !p.isLoanedOut)) +
                ProjectEngine.weeklyMerchandiseBonus(
                    _save!.projects, managerReputation)) *
            commercialMultiplier *
            scale)
        .round();
    // 営業の配分を厚くすると収入が増え、削ると減る(初期の配分で1倍)。
    final boost = _save!.marketingBoostWeeks > 0
        ? GameStateSquad.marketingBoostMultiplier
        : 1.0;
    final factor = BudgetEngine.incomeMultiplier(_save!.budgetPlan) *
        PolicyEngine.incomeMultiplier(_save!.clubPolicy) *
        AdvisorEngine.incomeMultiplier(
            _save!.advisors[Advisor.finance.name] ?? 0) *
        _save!.economyPhase.incomeMultiplier *
        boost;
    final total =
        ((matchdayIncome + sponsorIncome + merchandiseIncome) * factor).round();
    final gate = (matchdayIncome * factor).round();
    final sponsor = (sponsorIncome * factor).round();
    return (
      gate: gate,
      sponsor: sponsor,
      merchandise: total - gate - sponsor,
      broadcast: broadcast,
    );
  }

  /// 年の予算の配分(補強・育成・施設・営業・配当)。
  BudgetPlan get budgetPlan => _save?.budgetPlan ?? BudgetPlan.balanced();

  /// 年の予算の総額(万円)。今の週収入が1シーズン続いた場合の見込み。
  int get annualBudgetPool => _save == null
      ? 0
      : BudgetEngine.annualPool(
          weeklyIncome: weeklyIncomeFor(_save!.userTeamId));

  /// [category] の配分を [share]% にする。残りの配り先は比率に応じて
  /// 分け直され、合計は100のまま。
  Future<void> setBudgetShare(BudgetCategory category, int share) async {
    if (_save == null) return;
    _save!.budgetPlan = _save!.budgetPlan.withShare(category, share);
    _notify();
    await _persist();
  }

  /// このクラブのいる国の財務規則。
  RuleSet get ruleSet => _save?.ruleSet ?? RuleSet.britain;

  /// 規則の今の状況。今シーズンを終えたらどの罰を受けるかも含む。
  RuleReport get ruleReport => _save == null
      ? const RuleReport(statuses: [])
      : RulesEngine.evaluate(
          ruleSet: ruleSet,
          tier: _save!.currentDivisionTier,
          lowestTier: totalDivisionTiers,
          ledgers: [
            for (final l in _save!.ledgers)
              if (l.season <= _save!.league.season) l,
          ],
          budget: _save!.budget,
          snapshot: financeSnapshot,
        );

  /// 規則違反の罰で補強が禁止されているか。
  bool get isTransferBanned => (_save?.transferBanSeasons ?? 0) > 0;

  /// シーズン終了時に規則を当て、違反なら罰を科す。
  void _enforceLeagueRules() {
    final save = _save!;
    // 前の罰の期間を1季進める。
    if (save.transferBanSeasons > 0) save.transferBanSeasons -= 1;
    if (save.wageFreezeSeasons > 0) save.wageFreezeSeasons -= 1;
    if (save.wageFreezeSeasons == 0) save.wageFreezeCap = 0;
    final penalty = ruleReport.penalty;
    if (penalty == null) return;
    if (save.league.season <= RulesEngine.graceSeasons) {
      _logNews(
        Tr.pick(
            '${ruleSet.label}の規則に違反する状態です(${penalty.reason})。最初のシーズンは猶予されますが、来季からは罰を受けます。',
            'You are in breach of the ${ruleSet.label} rules (${penalty.reason}). The first season is a grace period; from next season you will be penalised.'),
        context: Tr.pick('リーグの規則', 'League rules'),
      );
      return;
    }
    final fine = (penalty.fine *
            AdvisorEngine.fineMultiplier(
                save.advisors[Advisor.legal.name] ?? 0))
        .round();
    if (fine > 0) _book(LedgerCategory.other, -fine);
    _changeSupporters(-penalty.trustLoss, SupporterReason.events,
        note: Tr.pick('リーグの規則違反(${penalty.reason})',
            'League rules breach (${penalty.reason})'));
    save.transferBanSeasons = max(save.transferBanSeasons, penalty.banSeasons);
    save.pendingPointsDeduction += penalty.pointsDeduction;
    if (penalty.wageFreezeSeasons > 0) {
      // 人件費の上限: いまの選手の年俸の総額を超える補強はできない。
      save.wageFreezeSeasons =
          max(save.wageFreezeSeasons, penalty.wageFreezeSeasons);
      save.wageFreezeCap = ContractEngine.weeklyWageBill(userTeam);
    }
    if (penalty.adminRelegation) save.adminRelegation = true;
    final parts = <String>[
      if (fine > 0)
        Tr.pick('罰金${formatMoney(fine)}', 'fine of ${formatMoney(fine)}'),
      if (penalty.pointsDeduction > 0)
        Tr.pick('来季の勝ち点${penalty.pointsDeduction}剥奪',
            '${penalty.pointsDeduction} points docked next season'),
      if (penalty.banSeasons > 0)
        Tr.pick('補強禁止${penalty.banSeasons}季', 'signing ban'),
      if (penalty.wageFreezeSeasons > 0)
        Tr.pick('人件費の上限${penalty.wageFreezeSeasons}季',
            'wage cap for ${Tr.plural(penalty.wageFreezeSeasons, 'season')}'),
      if (penalty.adminRelegation)
        Tr.pick('1つ下の部へ降格処分', 'relegated one division'),
    ];
    _logNews(
      Tr.pick('${ruleSet.label}の規則違反: ${penalty.reason}。${parts.join('、')}。',
          '${ruleSet.label} breach: ${penalty.reason}. ${parts.join(', ')}.'),
      context: Tr.pick('リーグの規則', 'League rules'),
    );
  }

  /// 年表に1行足す。直近200行だけ残す。
  void _addTimeline(String text) {
    final save = _save!;
    save.timeline.add(TimelineEntry(season: save.league.season, text: text));
    while (save.timeline.length > 200) {
      save.timeline.removeAt(0);
    }
  }

  /// 新規開始のシナリオを、初期の資金・期待・施設に反映する。
  void _applyScenario(StartScenario scenario) {
    final save = _save!;
    switch (scenario) {
      case StartScenario.standard:
        break;
      case StartScenario.debt:
        save.budget = -(GameState.initialBudgetFor(
                save.currentDivisionTier, currentLeagueTheme) ~/
            4);
        save.shareholderExpectation = 45;
      case StartScenario.patron:
        save.budget = save.budget * 3;
        save.shareholderExpectation = 70;
        save.boardTargetRank = (save.boardTargetRank - 2).clamp(1, 99);
      case StartScenario.academy:
        save.budget = (save.budget * 0.7).round();
        save.infrastructure.facilityLevels[FacilityType.youthFacility] = 3;
        save.infrastructure.facilityLevels[FacilityType.trainingGround] = 2;
    }
    _addTimeline(Tr.pick('「${scenario.label}」でクラブの経営が始まった',
        'Began running the club: ${scenario.label}'));
  }

  /// 監督の提案を足す(上限まで)。節の進行ごとに呼ぶ。
  void _refreshProposals() {
    final save = _save;
    if (save == null) return;
    // 実際には存在しなくなった選手の提案は消す。
    save.proposals.removeWhere((p) => p.kind == ProposalKind.renew
        ? !userTeam.players.any((x) => x.id == p.playerId)
        : !save.youthProspects.any((x) => x.id == p.playerId));
    final fresh = ProposalEngine.generate(
      squad: userTeam.players,
      prospects: save.youthProspects,
      existing: save.proposals,
      declined: save.declinedProposalIds.toSet(),
      squadFull: userTeam.players.length >= maxSquadSize,
    );
    save.proposals.addAll(fresh);
  }

  /// テスト用: 提案の生成だけを走らせる。
  @visibleForTesting
  void debugRefreshProposals() => _refreshProposals();

  /// 提案を承認して実行する。実行できなかった(資金・枠が足りない)ときは
  /// 提案を取り下げ、false。
  Future<bool> approveProposal(String id) async {
    final save = _save;
    if (save == null) return false;
    final p = save.proposals.where((x) => x.id == id).firstOrNull;
    if (p == null) return false;
    final ok = switch (p.kind) {
      ProposalKind.renew => await renewContract(p.playerId),
      ProposalKind.promote => await promoteYouthProspect(p.playerId),
    };
    save.proposals.removeWhere((x) => x.id == id);
    if (!ok) save.declinedProposalIds.add(id);
    _notify();
    await _persist();
    return ok;
  }

  /// 提案を却下する。今シーズンは同じ提案が出ない。
  Future<void> declineProposal(String id) async {
    final save = _save;
    if (save == null) return;
    save.proposals.removeWhere((x) => x.id == id);
    save.declinedProposalIds.add(id);
    _notify();
    await _persist();
  }

  /// アドバイザーのレベルを変える(0〜3)。
  Future<bool> setAdvisorLevel(Advisor a, int level) async {
    final save = _save;
    if (save == null || level < 0 || level > AdvisorEngine.maxLevel) {
      return false;
    }
    if (level == 0) {
      save.advisors.remove(a.name);
    } else {
      save.advisors[a.name] = level;
    }
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末にアドバイザーへ報酬を払い、広報顧問の効果を与える。
  void _settleAdvisors() {
    final save = _save!;
    final fee = scaledMoney(AdvisorEngine.totalSalary(save.advisors));
    if (fee > 0) _book(LedgerCategory.staffWages, -fee);
    final pr = save.advisors[Advisor.pr.name] ?? 0;
    if (pr > 0) _changeSupporters(pr, SupporterReason.pr);
  }

  /// 投資案件に着手する。費用は着手時に払う。
  Future<bool> startProject(ClubProject p) async {
    final save = _save;
    if (save == null || ProjectEngine.started(save.projects, p)) return false;
    final cost = scaledMoney(p.cost);
    if (cost > save.budget) return false;
    _book(LedgerCategory.facilities, -cost);
    save.projects[p.name] = p.buildSeasons;
    _logNews(
      Tr.pick('${p.label}に着手しました(${formatMoney(cost)}・完成まで${p.buildSeasons}季)',
          'Started ${p.label} (${formatMoney(cost)}, ${Tr.plural(p.buildSeasons, 'season')} to build)'),
      context: Tr.pick('投資案件', 'Projects'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末に建設を進め、稼働中の提携クラブの効果を与える。
  void _tickProjects() {
    final save = _save!;
    final wasPartnerActive =
        ProjectEngine.isActive(save.projects, ClubProject.partnerClub);
    final done = ProjectEngine.tick(save.projects);
    for (final p in done) {
      _addTimeline(Tr.pick('${p.label}が完成', '${p.label} completed'));
      _logNews(
        Tr.pick('${p.label}が完成しました', '${p.label} is complete'),
        context: Tr.pick('投資案件', 'Projects'),
      );
    }
    // 完成した季からではなく、稼働している季の末から効く。
    if (wasPartnerActive) {
      save.managerReputation = (save.managerReputation + 2).clamp(0, 100);
      _changeSupporters(1, SupporterReason.events);
    }
  }

  /// 永久欠番にした選手か。
  bool isNumberRetired(String playerId) =>
      _save?.retiredNumberIds.contains(playerId) ?? false;

  /// 殿堂の選手を永久欠番にする。サポーターの期待が上がる。同じ選手は一度だけ。
  Future<bool> retireNumber(String playerId) async {
    final save = _save;
    if (save == null || save.retiredNumberIds.contains(playerId)) return false;
    final p = save.retiredLegends.where((l) => l.id == playerId).firstOrNull;
    if (p == null) return false;
    save.retiredNumberIds.add(playerId);
    _addTimeline(Tr.pick('${p.name}の背番号を永久欠番に', '${p.name}\'s number retired'));
    _changeSupporters(3, SupporterReason.pr);
    _logNews(
      Tr.pick('${p.name}の背番号を永久欠番にしました。サポーターが沸いています',
          '${p.name}\'s number is retired for good. Supporters are thrilled'),
      context: Tr.pick('殿堂', 'Hall of fame'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 保険に入る/やめる。
  Future<void> setInsured(bool value) async {
    if (_save == null) return;
    _save!.insured = value;
    _notify();
    await _persist();
  }

  /// 災害基金へ積む(正)/引き出す(負)。資金が足りない・基金が足りないときは false。
  Future<bool> depositReserveFund(int amount) async {
    final save = _save;
    if (save == null || amount == 0) return false;
    if (amount > 0 && amount > save.budget) return false;
    if (amount < 0 && -amount > save.reserveFund) return false;
    save.reserveFund += amount;
    _book(LedgerCategory.financing, -amount);
    _notify();
    await _persist();
    return true;
  }

  /// 地域貢献を1段上げる。
  Future<bool> upgradeCommunity() async {
    final save = _save;
    if (save == null || save.communityLevel >= RiskEngine.maxCommunityLevel) {
      return false;
    }
    final cost = scaledMoney(RiskEngine.communityCost(save.communityLevel + 1));
    if (cost > save.budget) return false;
    _book(LedgerCategory.other, -cost);
    save.communityLevel += 1;
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末: 保険料と突発の出来事。地域貢献のサポーターへの効き目は
  /// 毎月(_closeSupporterMonth)。
  void _resolveSeasonRisks(
      {double? chanceRoll, double? kindRoll, double? sizeRoll}) {
    final save = _save!;
    final tier = save.currentDivisionTier;
    if (save.insured) _book(LedgerCategory.other, -RiskEngine.premium(tier));
    final rng = Random();
    final incident = RiskEngine.roll(
      chanceRoll: chanceRoll ?? rng.nextDouble(),
      kindRoll: kindRoll ?? rng.nextDouble(),
      sizeRoll: sizeRoll ?? rng.nextDouble(),
      tier: tier,
      communityLevel:
          save.communityLevel + (save.advisors[Advisor.pr.name] ?? 0),
    );
    if (incident == null) return;
    final cover = RiskEngine.cover(
        loss: incident.loss, insured: save.insured, fund: save.reserveFund);
    save.reserveFund = cover.fundAfter;
    if (cover.byClub > 0) _book(LedgerCategory.other, -cover.byClub);
    _changeSupporters(-incident.trustLoss, SupporterReason.events,
        note: incident.kind.label);
    _logNews(
      Tr.pick(
          '${incident.kind.label}が起きました。損失${formatMoney(incident.loss)}(保険${formatMoney(cover.byInsurance)}・基金${formatMoney(cover.byFund)}・クラブ負担${formatMoney(cover.byClub)})',
          '${incident.kind.label}. Loss ${formatMoney(incident.loss)} (insurance ${formatMoney(cover.byInsurance)}, fund ${formatMoney(cover.byFund)}, club ${formatMoney(cover.byClub)})'),
      context: Tr.pick('突発の出来事', 'Incident'),
    );
  }

  /// テスト用: 突発の出来事の判定を、指定の乱数で進める。
  @visibleForTesting
  void debugResolveSeasonRisks(double chance, double kind, double size) =>
      _resolveSeasonRisks(chanceRoll: chance, kindRoll: kind, sizeRoll: size);

  /// 命名権の候補から1つ結ぶ。
  Future<bool> chooseNamingRights(int index) async {
    final save = _save;
    if (save == null || index < 0 || index >= save.pendingNamingOffers.length) {
      return false;
    }
    save.namingDeal = save.pendingNamingOffers[index];
    _addTimeline(Tr.pick('スタジアムの命名権を${save.namingDeal!.name}と契約',
        'Signed naming rights with ${save.namingDeal!.name}'));
    save.pendingNamingOffers = [];
    _logNews(
      Tr.pick(
          'スタジアムの命名権を結びました: ${save.namingDeal!.name}(1節${formatMoney(save.namingDeal!.weeklyIncome)}・${save.namingDeal!.yearsRemaining}年)',
          'Naming rights signed: ${save.namingDeal!.name} (${formatMoney(save.namingDeal!.weeklyIncome)} a match, ${save.namingDeal!.yearsRemaining} yr)'),
      context: Tr.pick('命名権', 'Naming rights'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 放映権の、最下位でも受け取る年額(季の間に4回に分けて入る)。
  /// 国の配分式(MediaDealsEngine)の均等割と、順位・中継の最低の分。
  int get guaranteedBroadcastAnnual => _save == null
      ? 0
      : MediaDealsEngine.guaranteedAnnual(
          tier: currentDivisionTier,
          teamCount: _save!.league.teams.length,
          theme: currentLeagueTheme,
          eraFactor: currentEra.tvFactor);

  /// 今の順位で季を終えたときの、放映権の年額の見込み(4回の入金+季末の
  /// 上乗せ。パラシュートは含めない)。
  int get projectedBroadcastTotal {
    final save = _save;
    if (save == null) return 0;
    final rank = save.league.sortedStandings
            .indexWhere((r) => r.teamId == save.userTeamId) +
        1;
    return MediaDealsEngine.seasonTotal(
        tier: currentDivisionTier,
        rank: rank <= 0 ? save.league.teams.length : rank,
        teamCount: save.league.teams.length,
        theme: currentLeagueTheme,
        eraFactor: currentEra.tvFactor);
  }

  /// シーズン末に、放映権の順位と中継の上乗せを受け取る(リーグの配分式)。
  /// 2026-11-23 より前のセーブで前払いを受けていた場合は、その精算の間だけ
  /// 上乗せが出ない。
  void _bookTvRights({required int finalRank, required int teamCount}) {
    final save = _save!;
    if (save.tvHolidaySeasons > 0) {
      save.tvHolidaySeasons -= 1;
      return;
    }
    final pay = MediaDealsEngine.seasonEndPayout(
      tier: save.currentDivisionTier,
      rank: finalRank,
      teamCount: teamCount,
      theme: currentLeagueTheme,
      eraFactor: currentEra.tvFactor,
    );
    if (pay <= 0) return;
    _book(LedgerCategory.broadcast, pay);
    _logNews(
      Tr.pick('放映権の順位と中継の配分${formatMoney(pay)}が入りました($finalRank位)',
          'TV merit and facility money of ${formatMoney(pay)} arrived (finished ${Tr.ordinal(finalRank)})'),
      context: Tr.pick('放映権', 'TV rights'),
    );
  }

  /// シーズン境界で命名権を1年消化し、無ければ候補を出す。
  void _rollNamingRights() {
    final save = _save!;
    if (save.namingDeal != null) {
      save.namingDeal!.yearsRemaining -= 1;
      if (save.namingDeal!.yearsRemaining <= 0) save.namingDeal = null;
    }
    if (save.namingDeal == null && save.pendingNamingOffers.isEmpty) {
      save.pendingNamingOffers = MediaDealsEngine.namingOffers(
        stadiumLevel: save.infrastructure.facilityLevel(FacilityType.stadium),
        tier: save.currentDivisionTier,
        managerReputation: save.managerReputation,
      );
    }
  }

  /// 自クラブの選手の契約に付いている、降格したときの年俸の倍率
  /// (RelegationClause。国と、今の部から1つ下の部の水準で違う)。
  double get relegationWageFactor => RelegationClause.wageFactorFor(
      currentLeagueTheme,
      fromTier: currentDivisionTier,
      toTier: min(currentDivisionTier + 1, totalDivisionTiers));

  /// 降格したクラブ([teams]。自クラブも CPU も。降格する前の部と組)の
  /// 選手の年俸を、降格の条項で下げる。下げ幅は新しい部の水準まで
  /// ([RelegationClause.wageFactorFor])。貸し出しで来ている選手は元の
  /// クラブとの契約なので除く。
  void _applyRelegationWageClause(Iterable<(Team, int)> teams) {
    final theme = currentLeagueTheme;
    for (final (t, fromTier) in teams) {
      final f = RelegationClause.wageFactorFor(theme,
          fromTier: fromTier, toTier: fromTier + 1);
      if (f >= 1.0) continue;
      for (final p in t.players) {
        if (p.isLoan) continue;
        p.wage = max(minWeeklyWage, (p.wage * f).round());
      }
      if (t.id == _save!.userTeamId) {
        _logNews(
          Tr.pick(
              '降格の条項で、選手の年俸が${((1 - f) * 100).round()}%下がりました',
              'Relegation clauses cut player salaries by ${((1 - f) * 100).round()}%'),
          context: Tr.pick('契約', 'Contracts'),
        );
      }
    }
  }

  /// 昇格・降格の条項で、結んでいるスポンサー・命名権(と提示中の候補)の
  /// 額を動かす(SponsorEngine.divisionChangeFactor)。
  void _applySponsorDivisionClause(int fromTier, int toTier) {
    if (fromTier == toTier) return;
    final save = _save!;
    final f = SponsorEngine.divisionChangeFactor(fromTier, toTier);
    final deals = [
      if (save.sponsorDeal != null) save.sponsorDeal!,
      if (save.namingDeal != null) save.namingDeal!,
      ...save.slotSponsors.values,
      ...save.pendingSponsorOffers,
      ...save.pendingNamingOffers,
      ...save.slotSponsorOffers.values,
    ];
    if (deals.isEmpty) return;
    for (final d in deals) {
      d.weeklyIncome = max(1, (d.weeklyIncome * f).round());
    }
    _logNews(
      toTier < fromTier
          ? Tr.pick('昇格の条項で、スポンサーと命名権の額が${((f - 1) * 100).round()}%上がりました',
              'Promotion clauses raise sponsorship and naming rights by ${((f - 1) * 100).round()}%')
          : Tr.pick('降格の条項で、スポンサーと命名権の額が${((1 - f) * 100).round()}%下がりました',
              'Relegation clauses cut sponsorship and naming rights by ${((1 - f) * 100).round()}%'),
      context: Tr.pick('スポンサー', 'Sponsors'),
    );
  }

  /// 1年の運営費(試合運営・遠征・事務・施設の維持)。部と施設のLvで決まる。
  int get annualRunningCost {
    final save = _save;
    if (save == null) return 0;
    return RunningCostEngine.annual(
      tier: save.currentDivisionTier,
      theme: currentLeagueTheme,
      facilityLevels: [
        for (final t in FacilityType.values) save.infrastructure.facilityLevel(t)
      ],
    );
  }

  /// 毎月末に払う運営費(1年の12分の1)。
  int get monthlyRunningCost => (annualRunningCost / 12).round();

  @visibleForTesting
  void debugApplyRelegationWageClause(Iterable<Team> teams,
          {int fromTier = 1}) =>
      _applyRelegationWageClause([for (final t in teams) (t, fromTier)]);
  @visibleForTesting
  void debugApplySponsorDivisionClause(int fromTier, int toTier) =>
      _applySponsorDivisionClause(fromTier, toTier);
  @visibleForTesting
  void debugAdvanceFanDemand(
          {required int playedTier,
          required int newTier,
          required int finalRank,
          required int teamCount}) =>
      _advanceFanDemand(
          playedTier: playedTier,
          newTier: newTier,
          finalRank: finalRank,
          teamCount: teamCount);

  /// 世界クラブ価値番付。自クラブは実際の価値、他クラブは見積もり。
  List<RankedClub> get worldClubRanking {
    final save = _save;
    if (save == null) return const [];
    final clubs = <RankedClub>[
      RankedClub(
        name: save.clubName,
        value: clubValue.total,
        tier: save.currentDivisionTier,
        isUser: true,
      ),
    ];
    void addLeague(League league, int tier) {
      for (final t in league.teams) {
        if (t.id == save.userTeamId) continue;
        clubs.add(RankedClub(
          name: t.name,
          value: ClubRankingEngine.estimate(
            playersValue: t.players.fold<int>(0, (s, p) => s + p.marketValue),
            tier: tier,
          ),
          tier: tier,
          isUser: false,
        ));
      }
    }

    addLeague(save.league, save.currentDivisionTier);
    for (var tier = 1; tier <= save.otherDivisionLeagues.length; tier++) {
      final l = save.otherDivisionLeagues[tier - 1];
      if (l != null) addLeague(l, tier);
    }
    return ClubRankingEngine.rank(clubs);
  }

  /// オーナーの持分(%)。
  int get ownerShare => _save?.ownerShare ?? 100;

  /// 持分の10%を外部の株主へ売る(増資)。売れないときは false。
  Future<bool> sellStake() async {
    final save = _save;
    if (save == null) return false;
    final pct = EquityEngine.sellable(save.ownerShare);
    if (pct == 0) return false;
    final price = EquityEngine.salePrice(clubValue.total, pct);
    save.ownerShare -= pct;
    _book(LedgerCategory.financing, price);
    _addTimeline(Tr.pick('持分$pct%を外部の株主に売却(残り${save.ownerShare}%)',
        'Sold a $pct% stake (${save.ownerShare}% left)'));
    _logNews(
      Tr.pick(
          '持分$pct%を外部の株主に売り、${formatMoney(price)}を調達しました(持分${save.ownerShare}%)',
          'Sold a $pct% stake for ${formatMoney(price)} (you now hold ${save.ownerShare}%)'),
      context: Tr.pick('株主', 'Shareholders'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 持分の10%を買い戻す。資金が足りないときは false。
  Future<bool> buyBackStake() async {
    final save = _save;
    if (save == null || save.ownerShare >= 100) return false;
    const pct = EquityEngine.step;
    final take = pct > 100 - save.ownerShare ? 100 - save.ownerShare : pct;
    final cost = EquityEngine.buybackCost(clubValue.total, take);
    if (cost > save.budget) return false;
    save.ownerShare += take;
    _book(LedgerCategory.financing, -cost);
    _logNews(
      Tr.pick('持分$take%を${formatMoney(cost)}で買い戻しました(持分${save.ownerShare}%)',
          'Bought back $take% for ${formatMoney(cost)} (you now hold ${save.ownerShare}%)'),
      context: Tr.pick('株主', 'Shareholders'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末の株主総会。外部の株主へ配当を払い、総会の様子をニュースに残す。
  void _holdShareholdersMeeting() {
    final save = _save!;
    // 決算(法人税)のあとに配当と議案。
    _settleCorporateTax();
    final dividend = EquityEngine.dividend(
        ownerShare: save.ownerShare, seasonProfit: currentLedger.profit);
    if (dividend > 0) _book(LedgerCategory.financing, -dividend);
    final outside = 100 - save.ownerShare;
    _logNews(
      Tr.pick(
          '株主総会: ${EquityEngine.mood(save.shareholderExpectation)}。${outside > 0 ? '外部の株主(持分$outside%)へ配当${formatMoney(dividend)}を払いました。' : '外部の株主はいません。'}',
          'Shareholders\' meeting: ${EquityEngine.mood(save.shareholderExpectation)}. ${outside > 0 ? 'Paid outside holders ($outside%) a dividend of ${formatMoney(dividend)}.' : 'There are no outside shareholders.'}'),
      context: Tr.pick('株主総会', 'Shareholders\' meeting'),
    );
    _raiseAgmDemand();
  }

  /// 今シーズンの景気。
  EconomyPhase get economyPhase => _save?.economyPhase ?? EconomyPhase.normal;

  /// 来シーズンの景気(予報)。
  EconomyPhase get economyNext => _save?.economyNext ?? EconomyPhase.normal;

  /// シーズン末に景気を1つ進める。来季の予報が今季になり、次の予報を引く。
  void _advanceEconomy({double? roll, double? marketRoll}) {
    final save = _save!;
    // 移籍の相場は、終えた季の景気に連れて動く。
    final before = save.marketIndex;
    save.marketIndex = MarketTrendEngine.next(
        before, save.economyPhase, marketRoll ?? Random().nextDouble());
    final diff = save.marketIndex - before;
    if (diff != 0) {
      _logNews(
          Tr.pick(
              '移籍の相場: ${diff > 0 ? '上がった' : '下がった'}(基準100に対して${save.marketIndex})。移籍金の言い値も、来るオファーの額も、これに連れて動きます。',
              'Transfer market: prices ${diff > 0 ? 'rose' : 'fell'} (now ${save.marketIndex} against a base of 100). Asking prices and the bids you receive move with it.'),
          context: Tr.pick('移籍の相場', 'Transfer market'));
    }
    save.economyPhase = save.economyNext;
    save.economyNext =
        EconomyEngine.next(save.economyPhase, roll ?? Random().nextDouble());
    _logNews(
      Tr.pick(
          '景気: 来季は「${save.economyPhase.label}」です。${save.economyPhase.summary}(再来季の予報: ${save.economyNext.label})',
          'Economy: next season is "${save.economyPhase.label}". ${save.economyPhase.summary} (Forecast after that: ${save.economyNext.label})'),
      context: Tr.pick('景気', 'Economy'),
    );
  }

  /// テスト用: 景気を1つ進める。
  @visibleForTesting
  void debugAdvanceEconomy(double roll, {double? marketRoll}) =>
      _advanceEconomy(roll: roll, marketRoll: marketRoll);

  /// 移籍市場の相場(100 が基準)。
  int get marketIndex => _save?.marketIndex ?? 100;

  /// オーナーが選んだクラブの方針。
  ClubPolicy get clubPolicy => _save?.clubPolicy ?? ClubPolicy.balanced;

  /// 方針を変えられるか。今シーズンの試合が1つも行われていない間だけ。
  /// 途中で変えられると、シーズン末の採点に合わせて直前に選べてしまう。
  bool get canChangeClubPolicy =>
      _save != null && _save!.league.fixtures.every((f) => f.result == null);

  /// 方針を選ぶ。変えられないときは何もせず false。
  Future<bool> setClubPolicy(ClubPolicy policy) async {
    if (_save == null || !canChangeClubPolicy) return false;
    _save!.clubPolicy = policy;
    _notify();
    await _persist();
    return true;
  }

  /// シーズン末に方針を採点し、2つの期待を動かす。
  void _scoreClubPolicy({required int finalRank}) {
    final save = _save!;
    final result = PolicyEngine.score(
      policy: save.clubPolicy,
      finalRank: finalRank,
      targetRank: save.boardTargetRank,
      youngCount:
          userTeam.players.where((p) => p.age <= PolicyEngine.youngAge).length,
      seasonProfit: currentLedger.profit,
    );
    if (result == null) return;
    _changeSupporters(result.supporters, SupporterReason.events);
    save.shareholderExpectation =
        (save.shareholderExpectation + result.shareholders).clamp(0, 100);
    _logNews(result.reason, context: Tr.pick('クラブの方針', 'Club policy'));
  }

  /// テスト用: 方針の採点だけを走らせる。
  @visibleForTesting
  void debugScoreClubPolicy({required int finalRank}) =>
      _scoreClubPolicy(finalRank: finalRank);

  /// いまのクラブ価値と内訳。
  ClubValue get clubValue {
    final save = _save;
    if (save == null) {
      return ClubValueEngine.compute(
        playersValue: 0,
        facilityLevels: const {},
        staffLevels: const [],
        leagueTitles: 0,
        cupTitles: 0,
        managerReputation: 0,
        annualOperatingIncome: 0,
        cash: 0,
        debt: 0,
      );
    }
    final mine = save.seasonHistory.where((r) => r.clubName == save.clubName);
    // 稼ぐ力は、直近に終えたシーズンの営業収入。まだ無ければ今の週収入から見積もる。
    final past = save.ledgers
        .where((l) => l.season < save.league.season && l.operatingIncome > 0)
        .toList();
    final matchdays = save.league.fixtures
        .fold<int>(0, (m, f) => f.matchday > m ? f.matchday : m);
    final annual = past.isNotEmpty
        ? past.last.operatingIncome
        : weeklyIncomeFor(save.userTeamId) * matchdays;
    return ClubValueEngine.compute(
      playersValue: userTeam.players.fold<int>(0, (s, p) => s + p.marketValue),
      facilityLevels: {
        for (final f in FacilityType.values)
          f: save.infrastructure.facilityLevel(f),
      },
      staffLevels: [
        for (final r in StaffRole.values)
          save.infrastructure.staffFor(r)?.effectiveLevel ?? 0,
      ],
      leagueTitles: mine.where((r) => r.wonLeague).length,
      cupTitles: mine.fold<int>(0, (t, r) => t + r.cupsWon.length),
      managerReputation: save.managerReputation,
      annualOperatingIncome: annual,
      cash: save.budget,
      debt: outstandingLoanDebt,
      scale: moneyScale(save.currentDivisionTier),
    );
  }

  /// 過去のシーズン末のクラブ価値(シーズン順)。
  List<(int, int)> get clubValueHistory => [
        for (final e
            in (_save?.clubValueHistory.entries.toList() ?? [])
              ..sort((a, b) => a.key.compareTo(b.key)))
          (e.key, e.value),
      ];

  /// 今シーズンの終わりのクラブ価値を記録する。
  void _recordClubValue() {
    final save = _save!;
    save.clubValueHistory[save.league.season] = clubValue.total;
    while (save.clubValueHistory.length > SaveGame.maxLedgerSeasons) {
      save.clubValueHistory.remove(save.clubValueHistory.keys.reduce(min));
    }
  }

  /// テスト用: シーズン末のクラブ価値の記録だけを走らせる。
  @visibleForTesting
  void debugRecordClubValue() => _recordClubValue();

  /// 今シーズンの収支の記録。
  SeasonLedger get currentLedger =>
      _save == null ? SeasonLedger(1) : _save!.ledgerFor(_save!.league.season);

  /// 過去シーズンの収支の記録(シーズン順。今季は含めない)。
  List<SeasonLedger> get pastLedgers => _save == null
      ? const []
      : _save!.ledgers.where((l) => l.season < _save!.league.season).toList();

  /// 1節あたりの放映権の見込み。記帳と同じく、国の配分式
  /// ([projectedBroadcastTotal]。今の順位で季を終えたときの4回の入金+季末の
  /// 上乗せ)とパラシュートを、季の節の数で割る。前払いの精算が残る季は
  /// 季末の上乗せが出ないので、最下位でも受け取る分だけにする。
  /// ([weeklyIncomeParts] の broadcast は部だけで決まる古い式の額で、
  /// 実際の入金とは合わない)。
  int get projectedMatchdayBroadcast {
    final save = _save;
    if (save == null) return 0;
    final season = save.tvHolidaySeasons > 0
        ? guaranteedBroadcastAnnual
        : projectedBroadcastTotal;
    return ((season + parachuteAnnual) / matchdaysPerSeason).round();
  }

  /// 1節あたりの運営費(記帳は月末に年額の12分の1。見込みでは年額を
  /// 季の節の数で割る)。
  int get matchdayRunningCost =>
      _save == null ? 0 : (annualRunningCost / matchdaysPerSeason).round();

  /// 1節あたりの収入の見込み(観客・スポンサー・グッズと、放映権は
  /// [projectedMatchdayBroadcast])。収支の見込みはこれで数える。
  int get projectedMatchdayIncome {
    final save = _save;
    if (save == null) return 0;
    final p = weeklyIncomeParts(save.userTeamId);
    return p.gate + p.sponsor + p.merchandise + projectedMatchdayBroadcast;
  }

  /// 1節あたりの収支(収入 − 人件費 − 運営費 − 分割払い − 融資返済)。
  /// 2026-11-23 から運営費を引き、放映権は今の配分式の見込みで数える
  /// (以前は運営費が入っておらず、放映権も古い式で、実際より甘く出ていた)。
  int get weeklyNet {
    if (_save == null) return 0;
    return LedgerEngine.weeklyNet(
      income: projectedMatchdayIncome,
      wageBill: matchdayPlayerWageCost +
          matchdayStaffWageCost +
          matchdayRunningCost,
      installments:
          // 年に1回払う分割払い(2026-11-22 から)は、毎節の収支に入れない。
          _save!.pendingInstallments
              .where((i) => !i.annual)
              .fold<int>(0, (s, i) => s + i.weeklyAmount),
      loanRepayment: bankLoans.fold<int>(0, (s, l) => s + l.weeklyRepayment),
    );
  }

  /// 今の収支のまま続けたとき、資金が尽きるまでの節数。尽きなければ null。
  int? get runwayWeeks => _save == null
      ? null
      : LedgerEngine.runwayWeeks(budget: _save!.budget, weeklyNet: weeklyNet);

  /// 選手とスタッフの週俸の合計(万円/週)。理事会の給与の枠はこれで見る。
  /// 年俸で見せるときは52倍する。スタッフは今の部の規模に直した額。
  int get weeklyWageBill => _save == null
      ? 0
      : ContractEngine.weeklyWageBill(userTeam) +
          scaledMoney(_save!.infrastructure.totalStaffWeeklyWage);

  /// 理事会が設定する週給総額の上限(万円/週)。シーズン開始時に確定する。
  /// 未設定の旧セーブでは現在の状況から同じ式で算出する(必ず余裕がある
  /// 値になるため、既存プレイを突然ブロックしない)。
  int get wageBudgetCap {
    if (_save == null) return 0;
    final base = _save!.wageBudget > 0
        ? _save!.wageBudget
        : BoardEngine.wageBudgetFor(
            tier: _save!.currentDivisionTier,
            currentWeeklyWageBill: weeklyWageBill,
            weeklyIncome: weeklyIncomeFor(_save!.userTeamId),
            theme: currentLeagueTheme,
          );
    // 補強の配分を厚くすると上限が広がり、削ると狭まる(初期の配分で1倍)。
    return (base *
            BudgetEngine.wageCapMultiplier(_save!.budgetPlan) *
            PolicyEngine.wageCapMultiplier(_save!.clubPolicy))
        .round();
  }

  /// 週給[addedWeeklyWage]万円の選手を加えても週給予算に収まるか。
  /// 収まらない場合は[lastSigningBlockReason]に理由をセットしてfalseを返す。
  ///
  /// 選手の補強([isPlayer])では、国の財務規則も見る: スペイン式の人件費の
  /// 上限([fee] は移籍金。契約の年数で割った1年分を人件費に足す)、
  /// イタリア式の流動性の指標、フランス式の人件費の上限。
  bool _wageBudgetAllowsSigning(int addedWeeklyWage,
      {int fee = 0, int contractYears = 3, bool isPlayer = true}) {
    if (isTransferBanned) {
      lastSigningBlockReason = Tr.pick(
          'リーグの規則違反で、今は補強が禁止されています(あと${_save!.transferBanSeasons}季)。',
          'Signings are banned for a rule breach (${Tr.plural(_save!.transferBanSeasons, 'more season')}).');
      return false;
    }
    if (isPlayer) {
      final save = _save!;
      if (save.wageFreezeSeasons > 0 &&
          addedWeeklyWage > 0 &&
          ContractEngine.weeklyWageBill(userTeam) + addedWeeklyWage >
              save.wageFreezeCap) {
        lastSigningBlockReason = Tr.pick(
            '財務の監督機関の決定で、人件費に上限があります(年${formatMoney(annualFromWeekly(save.wageFreezeCap))}まで・あと${save.wageFreezeSeasons}季)。放出して枠を空ければ獲得できます。',
            'The financial watchdog has capped your wage bill at ${formatMoney(annualFromWeekly(save.wageFreezeCap))} a year (${Tr.plural(save.wageFreezeSeasons, 'season')} left). Sell someone to make room.');
        return false;
      }
      // 最初のシーズンは、罰と同じく猶予する(引き継いだ人件費で、何も
      // しないうちから上限を超えていることがある)。画面には状況が出る。
      final block = save.league.season <= RulesEngine.graceSeasons
          ? null
          : RulesEngine.signingBlock(
              ruleSet: ruleSet,
              tier: save.currentDivisionTier,
              snapshot: financeSnapshot,
              addedSquadCost: annualFromWeekly(addedWeeklyWage) +
                  (fee <= 0 ? 0 : fee ~/ max(1, contractYears)),
              // スペイン式: 上限を超えていても、売った分の一部は使える。
              saleAllowance: squadCostSaleAllowance,
            );
      if (block != null) {
        lastSigningBlockReason = block;
        return false;
      }
    }
    final cap = wageBudgetCap;
    if (weeklyWageBill + addedWeeklyWage <= cap) return true;
    lastSigningBlockReason = Tr.pick(
        '給与予算オーバー: 今の年俸の総額${formatMoney(annualFromWeekly(weeklyWageBill))}に新加入の${formatMoney(annualFromWeekly(addedWeeklyWage))}を加えると、理事会の上限(年${formatMoney(annualFromWeekly(cap))})を超えます。放出や施設スタッフの見直しで枠を空けてください。',
        "Over the wage budget: your current annual bill of ${formatMoney(annualFromWeekly(weeklyWageBill))} plus ${formatMoney(annualFromWeekly(addedWeeklyWage))} for the new signing would pass the board's cap of ${formatMoney(annualFromWeekly(cap))} a year. Sell someone or review your staff to make room.");
    return false;
  }

  /// 銀行から借り入れている融資一覧。
  List<BankLoan> get bankLoans => _save?.bankLoans ?? [];

  /// 融資の残り返済総額(元本+利息のうち未払い分)。
  int get outstandingLoanDebt =>
      bankLoans.fold<int>(0, (s, l) => s + l.totalRemaining);

  /// 現在追加で借り入れ可能な上限額。スタジアムの規模と監督としての評価が高いほど拡大する。
  int get maxLoanAmount => _save == null
      ? 0
      : LoanEngine.maxBorrowable(
          stadiumLevel: _save!.infrastructure.facilityLevel(
            FacilityType.stadium,
          ),
          reputation: _save!.managerReputation,
          outstandingDebt: outstandingLoanDebt,
          scale: moneyScale(currentDivisionTier),
        );

  /// 銀行融資を申し込む。頭金なしで即座に資金を得られる代わりに、指定した返済プランで
  /// 毎週の返済が発生する。
  Future<bool> takeLoan(int amount, LoanTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > maxLoanAmount) return false;
    final weekly = LoanEngine.weeklyRepaymentFor(amount, term);
    _save!.bankLoans.add(
      BankLoan(
        id: 'loan${_loanSeq++}',
        principal: amount,
        weeklyRepayment: weekly,
        termWeeks: term.weeks,
        weeksRemaining: term.weeks,
      ),
    );
    _book(LedgerCategory.financing, amount);
    _notify();
    await _persist();
    return true;
  }

  /// 融資の週の返済: 元本の分は融資・預金(損益に入れない)、残りは利息
  /// (損益の支出)として記録する。
  void _repayLoanWeek(BankLoan loan) {
    final principalPart = LoanEngine.principalPartOfWeek(
        loan.principal, loan.termWeeks, loan.termWeeks - loan.weeksRemaining);
    final interest = max(0, loan.weeklyRepayment - principalPart);
    _book(LedgerCategory.financing, -(loan.weeklyRepayment - interest));
    if (interest > 0) _book(LedgerCategory.interest, -interest);
  }

  /// 定期預金の満期: 元本は融資・預金、利息は損益の収入として記録する。
  void _settleDepositMaturity(FixedDeposit deposit) {
    _book(LedgerCategory.financing, deposit.principal);
    final interest = deposit.maturityValue - deposit.principal;
    if (interest != 0) _book(LedgerCategory.interest, interest);
  }

  /// 預け入れ中の定期預金一覧。
  List<FixedDeposit> get fixedDeposits => _save?.fixedDeposits ?? [];

  /// 定期預金として運用中の資金の合計(元本ベース)。
  int get totalDepositedFunds =>
      fixedDeposits.fold<int>(0, (s, d) => s + d.principal);

  /// 定期預金を組む。指定額をただちに資金から差し引いて預け入れ、満期まで
  /// 引き出せない代わりに満期時に利息込みでまとめて払い戻される。
  Future<bool> openFixedDeposit(int amount, DepositTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > _save!.budget) return false;
    _book(LedgerCategory.financing, -(amount));
    _save!.fixedDeposits.add(
      FixedDeposit(
        id: 'deposit${_depositSeq++}',
        principal: amount,
        maturityValue: InvestmentEngine.maturityValueFor(amount, term),
        termWeeks: term.weeks,
        weeksRemaining: term.weeks,
      ),
    );
    _notify();
    await _persist();
    return true;
  }
}
