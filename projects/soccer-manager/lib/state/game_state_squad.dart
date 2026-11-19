part of 'game_state.dart';

/// スカッド運用: 育成・トレーニング設定、施設/スタッフ強化、戦術、ラインナップ。
extension GameStateSquad on GameState {
  /// チーム既定のトレーニング方針を設定する(全選手に適用される)。
  void setTeamTrainingFocus(TrainingFocus focus) {
    if (_save == null) return;
    userTeam.defaultTrainingFocus = focus;
    _notify();
    _persist();
  }

  /// 営業ブーストの倍率。ブーストが残っている節の週収入にかかる。
  /// 資金を直接配らないので、赤字を消すほどの力は持たない。
  static const double marketingBoostMultiplier = 1.5;

  /// 貯めておける営業ブーストの上限(節数)。
  static const int marketingBoostCap = 3;

  /// 営業ブーストの残り(節数)。
  int get marketingBoostWeeks => _save?.marketingBoostWeeks ?? 0;

  /// リワード広告の視聴、またはサポーター購入による特典を受け取る。
  /// 次の1節だけ、チケット・スポンサー・グッズの収入が上がる。
  ///
  /// 広告を見せたか・購入済みかの判定は MonetizationController の責務で、
  /// ここはゲームの状態を触るだけ。受け取った事実はクラブニュースに残す。
  /// 戻り値は受け取り後の残り節数。
  int claimMarketingBoost() {
    if (_save == null) return 0;
    _save!.marketingBoostWeeks =
        (_save!.marketingBoostWeeks + 1).clamp(0, marketingBoostCap);
    _logNews(Tr.pick('営業を強化した。次の1節は収入が増える。',
        'Marketing pushed: income is up for the next matchday.'));
    _notify();
    _persist();
    return _save!.marketingBoostWeeks;
  }

  /// 資金パックの購入で受け取る額(万円)。所属ディビジョンに比例する。
  int purchasedFundsAmount(FundsPack pack) =>
      pack.fundsFor(_save?.currentDivisionTier ?? 5);

  /// 資金パックの購入ぶんを受け取る。
  ///
  /// 購入が成立したかの判定は MonetizationController の責務で、ここは
  /// ゲームの状態を触るだけ。特典と同じく、増えた理由をニュースに残す。
  int claimPurchasedFunds(FundsPack pack) {
    if (_save == null) return 0;
    final amount = purchasedFundsAmount(pack);
    _book(LedgerCategory.other, amount);
    _logNews(Tr.pick('${pack.label}で${formatMoney(amount)}をクラブ資金に追加した。',
        'You added ${formatMoney(amount)} to the club budget from a ${pack.label}.'));
    _notify();
    _persist();
    return amount;
  }

  /// 開発者向けのデバッグ機能。資金を任意の額だけ増減させる
  /// (負の値で減額も可能)。設定画面の管理者専用メニューからのみ呼ばれる。
  void addDebugFunds(int amount) {
    if (_save == null) return;
    _book(LedgerCategory.other, amount);
    _notify();
    _persist();
  }

  /// チームのトレーニング強度(軽め/通常/追い込み)を設定する。
  void setTrainingIntensity(TrainingIntensity intensity) {
    if (_save == null) return;
    userTeam.trainingIntensity = intensity;
    _notify();
    _persist();
  }

  /// 週の中で重点的にトレーニングを行う曜日(1=月〜5=金)を設定する。
  void setTrainingDayOfWeek(int weekday) {
    if (_save == null) return;
    userTeam.trainingDayOfWeek = weekday;
    _notify();
    _persist();
  }

  /// 週次トレーニングの自動実施の有効/無効を切り替える。有効な場合、
  /// 毎節の進行時に未実施であれば既定の方針・強度で自動的に実施する。
  void setAutoTrainingEnabled(bool enabled) {
    if (_save == null) return;
    userTeam.autoTrainingEnabled = enabled;
    _notify();
    _persist();
  }

  /// 監督としての生涯経験値(通算勝敗・トロフィー・実績解除数から算出)。
  int get managerCareerXp => _save == null
      ? 0
      : ManagerCareerEngine.xpFor(
          careerWins: _save!.careerWins,
          careerDraws: _save!.careerDraws,
          trophyCount: _save!.trophyHistory.length,
          unlockedAchievementCount: _save!.unlockedAchievements.length,
        );

  /// 監督としての生涯成長レベル(1〜[ManagerCareerEngine.maxLevel])。
  int get managerCareerLevel => ManagerCareerEngine.levelFor(managerCareerXp);

  /// 次のレベルまでに必要な残り経験値。
  int get managerCareerXpToNextLevel =>
      ManagerCareerEngine.xpToNextLevel(managerCareerXp);

  /// 現在のレベル内での経験値の進捗割合(0.0〜1.0)。
  double get managerCareerProgressFraction =>
      ManagerCareerEngine.progressFractionFor(managerCareerXp);

  /// 生涯成長レベルによる選手成長効率の永続ボーナス倍率。
  double get managerCareerGrowthBonus =>
      ManagerCareerEngine.growthBonusFor(managerCareerLevel);

  Future<bool> runWeeklyTraining() async {
    if (_save == null) return false;
    if (_save!.trainingDoneThisWeek) return false;
    final infra = _save!.infrastructure;
    final overallBefore = {for (final p in userTeam.players) p.id: p.overall};
    final attrsBefore = {
      for (final p in userTeam.players)
        p.id: Map<String, int>.from(p.attributes),
    };
    TrainingEngine.applyWeeklyTraining(
      userTeam,
      headCoachLevel: infra.staffLevel(StaffRole.headCoach),
      trainingGroundLevel: infra.facilityLevel(FacilityType.trainingGround),
      fitnessCoachLevel: infra.staffLevel(StaffRole.fitnessCoach),
      injuryFactor: _userInjuryFactor,
      careerGrowthBonus: managerCareerGrowthBonus,
    );
    // 布陣の仕込み。良いヘッドコーチほど早く馴染む。使っていない布陣は
    // 少しずつ薄れるので、あれこれ試すほど何も身につかない。
    userTeam.advanceFamiliarity(
      coachingBonus: infra.staffLevel(StaffRole.headCoach),
    );

    // リザーブ(Bチーム)の試合。トップに絡めない選手が公式戦に近い形で
    // 出場する。人数が足りるならこちらを行い、足りないときだけ紅白戦に
    // 落とす。両方やると疲労も成長も二重取りになる。
    final reserveMatch = ReserveMatchEngine.play(
      userTeam,
      opponentName: Tr.pick('リザーブ', 'Reserves'),
    );
    if (reserveMatch == null) TrainingEngine.applyIntraSquadMatch(userTeam);
    for (final p in userTeam.players) {
      if (p.hadBreakthroughThisWeek) _save!.breakthroughCount++;
    }
    _evaluateAchievements();
    _save!.trainingDoneThisWeek = true;
    lastTrainingResults = _diffTrainingResults(overallBefore, attrsBefore);
    _notify();
    await _persist();
    return true;
  }

  /// トレーニング前後の総合力・属性を比較し、実際に変化があった選手のみを返す。
  List<PlayerGrowthSummary> _diffTrainingResults(
    Map<String, int> overallBefore,
    Map<String, Map<String, int>> attrsBefore,
  ) {
    final changes = <PlayerGrowthSummary>[];
    for (final p in userTeam.players) {
      final prevOverall = overallBefore[p.id];
      final prevAttrs = attrsBefore[p.id];
      if (prevOverall == null || prevAttrs == null) continue;
      final deltas = <String, int>{};
      for (final entry in p.attributes.entries) {
        final before = prevAttrs[entry.key] ?? entry.value;
        if (entry.value != before) deltas[entry.key] = entry.value - before;
      }
      if (deltas.isNotEmpty || p.overall != prevOverall) {
        changes.add(
          PlayerGrowthSummary(
            playerId: p.id,
            playerName: p.name,
            overallBefore: prevOverall,
            overallAfter: p.overall,
            attributeDeltas: deltas,
            isBreakthrough: p.hadBreakthroughThisWeek,
          ),
        );
      }
    }
    changes.sort((a, b) => b.overallDelta.compareTo(a.overallDelta));
    return changes;
  }

  /// 雇えるスタッフの候補を作り直す。シーズン開始時と新規開始時に呼ぶ。
  void _refreshStaffCandidates() {
    if (_save == null) return;
    _save!.staffCandidates = StaffMarket.generate(
      divisionTier: _save!.currentDivisionTier,
      confidence: _save!.confidence,
      // 候補は月ごとに入れ替わる。id が前の月と重ならないよう月を混ぜる。
      seed: _save!.careerSeasons * 100 + today.month,
      avoidNames: {
        for (final s in _save!.infrastructure.staff.values)
          if (s != null) s.name,
      },
    );
    _addManagerCandidates();
    _addFormerPlayerCandidates();
  }

  /// いま雇えるスタッフの候補。月ごとに入れ替わる。
  List<StaffMember> staffCandidatesFor(StaffRole role) =>
      _save?.staffCandidates.where((s) => s.role == role).toList() ?? [];

  /// [role]に就いているスタッフ。空席なら null。
  StaffMember? staffFor(StaffRole role) =>
      _save?.infrastructure.staffFor(role);

  int facilityUpgradeCostFor(FacilityType type) {
    if (_save == null) return 0;
    final lvl = _save!.infrastructure.facilityLevel(type);
    return (scaledMoney(ClubInfrastructure.facilityUpgradeCost(lvl)) *
            BudgetEngine.facilityCostMultiplier(_save!.budgetPlan) *
            PolicyEngine.facilityCostMultiplier(_save!.clubPolicy) *
            AdvisorEngine.facilityCostMultiplier(
                _save!.advisors[Advisor.scouting.name] ?? 0))
        .round();
  }

  /// 候補[staffId]を雇う。既にその役職に人がいれば入れ替わる。
  ///
  /// 費用は掛からない。掛かるのは週俸で、以後ずっと出ていく。一度の出費で
  /// 済んだ旧レベル制と違い、良いスタッフを抱えるほど毎週の重荷になる。
  Future<bool> hireStaff(String staffId) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    final idx = _save!.staffCandidates.indexWhere((s) => s.id == staffId);
    if (idx < 0) return false;
    final hired = _save!.staffCandidates[idx];
    final previous = _save!.infrastructure.staffFor(hired.role);
    final severance = scaledMoney(previous?.severance ?? 0);
    // 他のクラブの監督を引き抜くなら、そのクラブへ補償金を払う。
    final profile = hired.manager;
    final compensation = scaledMoney(profile?.compensation ?? 0);
    if (compensation + severance > 0 &&
        _save!.budget < compensation + severance) {
      lastSigningBlockReason = Tr.pick(
          '資金が足りません(補償金${formatMoney(compensation)}・前任の違約金${formatMoney(severance)})。',
          'You cannot afford it (compensation ${formatMoney(compensation)}, severance ${formatMoney(severance)}).');
      _notify();
      return false;
    }

    // 週俸の総額が給与予算を食い潰さないよう、選手と同じ枠で見る。
    // 入れ替えなら前任者の週俸は出ていかなくなるので、差額で見る。
    if (!_wageBudgetAllowsSigning(
        scaledMoney(hired.wage - (previous?.wage ?? 0)))) {
      return false;
    }

    _save!.infrastructure.staff[hired.role] = hired;
    _save!.staffCandidates.removeAt(idx);
    if (severance > 0) _book(LedgerCategory.staffWages, -severance);
    if (hired.role == StaffRole.manager) {
      _onManagerHired(hired, compensation);
    }
    // 入れ替えで空いた人は候補に戻さない。断った相手が翌週も同じ条件で
    // 待っているのは不自然なため。
    if (previous != null) {
      _logNews(
        Tr.pick('${previous.name}が${previous.role.label}を退任し、${hired.name}が就任しました。',
            '${previous.name} leaves as ${previous.role.label}; ${hired.name} takes over.'),
        context: Tr.pick('スタッフ', 'Staff'),
      );
    } else {
      _logNews(
        Tr.pick('${hired.name}が${hired.role.label}に就任しました。',
            '${hired.name} joins as ${hired.role.label}.'),
        context: Tr.pick('スタッフ', 'Staff'),
      );
    }
    _notify();
    await _persist();
    return true;
  }

  /// [role]のスタッフを解任する。空席のままにもできる(週俸は浮く)。
  Future<bool> dismissStaff(StaffRole role) async {
    if (_save == null) return false;
    final current = _save!.infrastructure.staffFor(role);
    if (current == null) return false;
    _save!.infrastructure.staff[role] = null;
    final severance = scaledMoney(current.severance);
    if (severance > 0) _book(LedgerCategory.staffWages, -severance);
    _logNews(
      Tr.pick('${current.name}が${role.label}を退任しました。',
          '${current.name} leaves his post as ${role.label}.'),
      context: Tr.pick('スタッフ', 'Staff'),
    );
    _notify();
    await _persist();
    return true;
  }

  Future<bool> upgradeFacility(FacilityType type) async {
    if (_save == null) return false;
    final infra = _save!.infrastructure;
    final lvl = infra.facilityLevel(type);
    if (lvl >= ClubInfrastructure.maxLevel) return false;
    final cost = facilityUpgradeCostFor(type);
    if (_save!.budget < cost) return false;
    _book(LedgerCategory.facilities, -(cost));
    infra.upgradeFacility(type);
    _notify();
    await _persist();
    return true;
  }

  /// チケット価格戦略を切り替える(観客動員率と1人あたり収入のトレードオフ)。
  Future<void> setTicketPricing(TicketPricing pricing) async {
    if (_save == null) return;
    _save!.ticketPricing = pricing;
    _notify();
    await _persist();
  }

  void setPressing(int value) {
    if (_save == null) return;
    userTeam.pressing = value.clamp(0, 100);
    _notify();
    _persist();
  }

  /// チームメンタリティ(超守備的〜超攻撃的)を変更する。
  void setMentality(TeamMentality mentality) {
    if (_save == null) return;
    userTeam.mentality = mentality;
    _notify();
    _persist();
  }

  /// 戦術スタイル(ポゼッション/ゲーゲンプレス等)を変更する。
  void setTacticalStyle(TacticalStyle style) {
    if (_save == null) return;
    userTeam.tacticalStyle = style;
    _notify();
    _persist();
  }

  /// 選手のスカッド・ステータス(出場機会の約束)を変更する。
  void setSquadStatus(String playerId, SquadStatus status) {
    if (_save == null) return;
    final idx = userTeam.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final p = userTeam.players[idx];
    p.squadStatus = status;
    // 加入のときに約束した序列より下げれば、約束を破ったことになる。
    final promised = p.promisedStatus;
    if (promised != null && !p.promiseBroken && status.index > promised.index) {
      _breakPromise(
          p,
          Tr.pick('${promised.label}の約束だったのに、${status.label}に下げた',
              'He was promised ${promised.label} billing and you dropped him to ${status.label}'));
    }
    _notify();
    _persist();
  }

  void setLineHeight(int value) {
    if (_save == null) return;
    userTeam.lineHeight = value.clamp(0, 100);
    _notify();
    _persist();
  }

  void setWidth(int value) {
    if (_save == null) return;
    userTeam.width = value.clamp(0, 100);
    _notify();
    _persist();
  }

  void setTempo(int value) {
    if (_save == null) return;
    userTeam.tempo = value.clamp(0, 100);
    _notify();
    _persist();
  }

  /// 選手のデューティ(守備的/バランス/攻撃的)を設定する。
  void setPlayerDuty(String playerId, PlayerDuty duty) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.duty = duty;
    _notify();
    _persist();
  }

  /// 選手のプレースタイル(ロール)を設定する。
  /// 選手に個別指示を出す。null を渡すと指示を外す。
  void setPlayerInstruction(String playerId, PlayerInstruction? instruction) {
    if (_save == null) return;
    final p = userTeam.players.where((p) => p.id == playerId).firstOrNull;
    if (p == null) return;
    p.instruction = instruction;
    _notify();
    _persist();
  }

  void setPlayerRole(String playerId, PlayerRole role) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.role = role;
    _notify();
    _persist();
  }

  /// キャプテンを指名する。既に副キャプテンだった場合はその指名を解除する。
  Future<void> setCaptain(String? playerId) async {
    if (_save == null) return;
    userTeam.captainId = playerId;
    if (playerId != null && userTeam.viceCaptainId == playerId) {
      userTeam.viceCaptainId = null;
    }
    _notify();
    await _persist();
  }

  /// 副キャプテンを指名する。既にキャプテンだった場合はその指名を解除する。
  Future<void> setViceCaptain(String? playerId) async {
    if (_save == null) return;
    userTeam.viceCaptainId = playerId;
    if (playerId != null && userTeam.captainId == playerId) {
      userTeam.captainId = null;
    }
    _notify();
    await _persist();
  }

  /// PK(ペナルティキック)の担当選手を指名する。
  void setPenaltyTaker(String? playerId) {
    if (_save == null) return;
    userTeam.penaltyTakerId = playerId;
    _notify();
    _persist();
  }

  /// 直接FK(フリーキック)の担当選手を指名する。
  void setFreeKickTaker(String? playerId) {
    if (_save == null) return;
    userTeam.freeKickTakerId = playerId;
    _notify();
    _persist();
  }

  /// CK(コーナーキック)の担当選手を指名する。
  void setCornerTaker(String? playerId) {
    if (_save == null) return;
    userTeam.cornerTakerId = playerId;
    _notify();
    _persist();
  }

  /// 次の試合に効いている自チームの状態。
  ///
  /// 戦術・習熟度・個別指示・疲労・士気と結果に効く要素が増えたのに、
  /// どれがどう効いているかを見る場所が無かった。
  List<MatchFactor> get matchFactors {
    if (_save == null) return const [];
    final team = userTeam;
    final lineup =
        team.players.where((p) => team.startingXI.contains(p.id)).toList();
    return MatchFactorEngine.analyze(team: team, startingLineup: lineup);
  }

  /// 開幕前のキャンプで方針を選ぶ。選べるのはシーズンにつき一度だけ。
  ///
  /// 費用が払えなければ実施できない。見送る(none)ことはいつでもできる。
  Future<bool> choosePreseasonCamp(PreseasonCamp camp) async {
    if (_save == null || !_save!.preseasonCampPending) return false;
    final campCost = scaledMoney(camp.cost);
    if (_save!.budget < campCost) return false;

    _book(LedgerCategory.facilities, -campCost);
    _save!.preseasonCampPending = false;

    final team = userTeam;
    for (final p in team.players) {
      p.matchSharpness =
          (p.matchSharpness + camp.sharpnessGain).clamp(0, 100);
      p.fatigue = (p.fatigue + camp.fatigueCost).clamp(0, 100);
      if (p.age <= 23 && camp.youthGrowthChance > 0) {
        // 若手の遠征。出場経験と同じ経路で伸ばす。
        if (GameState._campRng.nextDouble() < camp.youthGrowthChance) {
          TrainingEngine.growFromMatchExperience(p);
        }
      }
    }
    if (camp.familiarityGain > 0) {
      team.formationFamiliarity[team.formation] =
          (team.currentFamiliarity + camp.familiarityGain).clamp(0, 100);
    }

    _logNews(
      camp == PreseasonCamp.none
          ? Tr.pick('今季はキャンプを張らずに開幕を迎えます。',
              'You go into the season without a camp.')
          : Tr.pick('${camp.label}のキャンプを行いました。',
              'You held a ${camp.label}.'),
      context: Tr.pick('キャンプ', 'Pre-season'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 理事会の路線を、いま守れているか。
  bool get isClubVisionSatisfied => _save == null
      ? true
      : BoardEngine.isVisionSatisfied(
          vision: _save!.clubVision,
          team: userTeam,
          budget: _save!.budget,
        );

  /// 今シーズン、路線をどれだけ守れてきたか。
  ///
  /// 評価はシーズン終了時に一度だけなので、途中経過が見えないと
  /// 「いま直せば間に合うのか」が分からない。
  String get clubVisionProgressLabel {
    final save = _save;
    if (save == null || save.visionCheckedMatchdays == 0) return '';
    return Tr.pick(
        '今季 ${save.visionCompliedMatchdays}/${save.visionCheckedMatchdays}節。',
        '${save.visionCompliedMatchdays} of ${save.visionCheckedMatchdays} matchdays so far. ');
  }

  /// 対戦相手への対策を決める。
  void setOppositionPlan(OppositionPlan plan) {
    if (_save == null) return;
    userTeam.oppositionPlan = plan;
    _notify();
    _persist();
  }

  /// コーナーキックの狙いを決める。
  void setCornerRoutine(CornerRoutine routine) {
    if (_save == null) return;
    userTeam.cornerRoutine = routine;
    _notify();
    _persist();
  }

  /// 相手のセットプレー(CK・FK)を守る担当選手を指名する。
  void setSetPieceDefender(String? playerId) {
    if (_save == null) return;
    userTeam.setPieceDefenderId = playerId;
    _notify();
    _persist();
  }

  /// 次の自チームの試合で相手のキープレイヤーにマンマークを付ける
  /// 自チームの選手を指名する。
  void setManMarker(String? playerId) {
    if (_save == null) return;
    userTeam.manMarkerId = playerId;
    _notify();
    _persist();
  }

  /// 逃げ切りモードの有効・無効を切り替える。有効時は自チームの攻撃力が
  /// やや下がる代わりに守備が安定し、疲労蓄積も抑えられる。
  void setTimeWastingMode(bool enabled) {
    if (_save == null) return;
    userTeam.timeWastingMode = enabled;
    _notify();
    _persist();
  }

  /// 試合前・ハーフタイムの檄。トーンに応じて先発イレブンの士気を変動
  /// させる。性格ごとの結果感応度(resultSensitivity)が大きい選手ほど
  /// 変動幅が大きい。
  void giveTeamTalk(TeamTalkTone tone) {
    if (_save == null) return;
    for (final p in userTeam.players.where(
      (p) => userTeam.startingXI.contains(p.id),
    )) {
      final base = tone.baseMoraleDeltaFor(p.personality);
      final delta = (base * p.personality.resultSensitivity).round();
      p.morale = (p.morale + delta).clamp(0, 100);
    }
    _notify();
    _persist();
  }

  void setFormation(Formation formation) {
    if (_save == null) return;
    userTeam.formation = formation;
    LineupUtils.autoFill(userTeam);
    _notify();
    _persist();
  }

  /// 現在の戦術設定(フォーメーション・各種スライダー・セットプレー担当)を
  /// 名前を付けて保存する。同名の既存プリセットがあれば上書きし、新規の
  /// 場合は[maxTacticPresets]件を超えないよう最も古いものから削除する。
  void saveTacticPreset(String name) {
    if (_save == null) return;
    final team = userTeam;
    final preset = TacticPreset(
      name: name,
      formation: team.formation,
      pressing: team.pressing,
      lineHeight: team.lineHeight,
      width: team.width,
      tempo: team.tempo,
      penaltyTakerId: team.penaltyTakerId,
      freeKickTakerId: team.freeKickTakerId,
      cornerTakerId: team.cornerTakerId,
    );
    final existingIndex = team.tacticPresets.indexWhere((p) => p.name == name);
    if (existingIndex >= 0) {
      team.tacticPresets[existingIndex] = preset;
    } else {
      if (team.tacticPresets.length >= maxTacticPresets) {
        team.tacticPresets.removeAt(0);
      }
      team.tacticPresets.add(preset);
    }
    _notify();
    _persist();
  }

  /// 保存済みの戦術プリセットを現在の設定へ適用する。
  void applyTacticPreset(String name) {
    if (_save == null) return;
    final team = userTeam;
    if (team.tacticPresets.isEmpty) return;
    final preset = team.tacticPresets.firstWhere(
      (p) => p.name == name,
      orElse: () => team.tacticPresets.first,
    );
    team.formation = preset.formation;
    team.pressing = preset.pressing;
    team.lineHeight = preset.lineHeight;
    team.width = preset.width;
    team.tempo = preset.tempo;
    final rosterIds = team.players.map((p) => p.id).toSet();
    // プリセット保存後に売却・引き抜き等で離脱した選手が指名されたままに
    // ならないよう、現在のスカッドに残っている場合のみ復元する。
    team.penaltyTakerId = rosterIds.contains(preset.penaltyTakerId)
        ? preset.penaltyTakerId
        : null;
    team.freeKickTakerId = rosterIds.contains(preset.freeKickTakerId)
        ? preset.freeKickTakerId
        : null;
    team.cornerTakerId =
        rosterIds.contains(preset.cornerTakerId) ? preset.cornerTakerId : null;
    LineupUtils.autoFill(team);
    _notify();
    _persist();
  }

  /// 保存済みの戦術プリセットを削除する。
  void deleteTacticPreset(String name) {
    if (_save == null) return;
    userTeam.tacticPresets.removeWhere((p) => p.name == name);
    _notify();
    _persist();
  }

  /// デプスチャート(ポジション別控え順)を手動で入れ替える。
  /// [oldIndex]/[newIndex]は`ReorderableListView.onReorderItem`から渡される
  /// 値をそのまま使う想定(newIndexは削除後の挿入位置に調整済み)。
  void reorderDepthChart(Position position, int oldIndex, int newIndex) {
    if (_save == null) return;
    final team = userTeam;
    final current = team.depthChartFor(position).map((p) => p.id).toList();
    final id = current.removeAt(oldIndex);
    current.insert(newIndex, id);
    team.depthChartOrder[position.name] = current;
    _notify();
    _persist();
  }

  void autoFillStartingXI() {
    if (_save == null) return;
    LineupUtils.autoFill(userTeam);
    _notify();
    _persist();
  }

  /// スタメン入り/除外を切り替える。フォーメーションのポジション別人数上限を超える場合は無視する。
  void toggleStartingPlayer(String playerId) {
    if (_save == null) return;
    final team = userTeam;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isInjured || player.isSuspended) return;

    if (team.startingXI.contains(playerId)) {
      team.startingXI.remove(playerId);
    } else {
      final quota = team.formation.quotaFor(player.position);
      final currentInPosition = team.startingXI
          .map((id) => team.players.firstWhere((p) => p.id == id))
          .where((p) => p.position == player.position)
          .length;
      if (currentInPosition >= quota) return;
      team.startingXI.add(playerId);
    }
    _notify();
    _persist();
  }

  /// スタメンの特定選手を別の選手と入れ替える(戦術画面のピッチタップ操作用)。
  /// クォータ判定は行わず、指定された選手をそのまま入れ替える。
  /// 疲労の溜まったスタメンを、より疲労の少ないベンチ選手に入れ替える提案。
  List<RotationSuggestion> get rotationSuggestions =>
      _save == null ? [] : RotationEngine.suggest(userTeam);

  void swapStartingPlayer({String? outPlayerId, required String inPlayerId}) {
    if (_save == null) return;
    final team = userTeam;
    if (outPlayerId != null) team.startingXI.remove(outPlayerId);
    if (!team.startingXI.contains(inPlayerId)) team.startingXI.add(inPlayerId);
    _notify();
    _persist();
  }
}
