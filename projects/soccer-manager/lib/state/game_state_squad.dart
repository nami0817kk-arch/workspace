part of 'game_state.dart';

/// スカッド運用: 育成・トレーニング設定、施設/スタッフ強化、戦術、ラインナップ。
extension GameStateSquad on GameState {
  /// チーム既定のトレーニング方針を設定する（個別方針未設定の選手に適用される）。
  void setTeamTrainingFocus(TrainingFocus focus) {
    if (_save == null) return;
    userTeam.defaultTrainingFocus = focus;
    _notify();
    _persist();
  }

  /// 選手個別のトレーニング方針を設定する。nullでチーム既定に戻す。
  void setPlayerTrainingFocus(String playerId, TrainingFocus? focus) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.individualFocus = focus;
    _notify();
    _persist();
  }

  /// ユース昇格候補の個別トレーニング方針を設定する。nullでポジション別の
  /// 既定の育成配分に戻す(TrainingEngine.applyYouthAcademyGrowth参照)。
  void setYouthProspectTrainingFocus(String playerId, TrainingFocus? focus) {
    if (_save == null) return;
    final player = _save!.youthProspects.firstWhere((p) => p.id == playerId);
    player.individualFocus = focus;
    _notify();
    _persist();
  }

  /// 現在のディビジョンに応じた特典資金の額(万円)。
  /// ボタンに「いくら貰えるか」を出すため、受け取り前に参照できるようにする。
  int get rewardFundsAmount =>
      RewardOffer.fundsFor(_save?.currentDivisionTier ?? 5);

  /// リワード広告の視聴、またはサポーター購入による特典資金を受け取る。
  ///
  /// 広告を見せたか・購入済みかの判定は MonetizationController の責務で、
  /// ここはゲームの状態を触るだけ。受け取った事実はクラブニュースに残す
  /// (資金が増えた理由が後から分からないと、収支を追えなくなるため)。
  int claimRewardFunds() {
    if (_save == null) return 0;
    final amount = rewardFundsAmount;
    _save!.budget += amount;
    _logNews(Tr.pick('スポンサーの特別協賛金として$amount万円を受け取った。',
        'You received $amount in special sponsorship.'));
    _notify();
    _persist();
    return amount;
  }

  /// 開発者向けのデバッグ機能。資金を任意の額だけ増減させる
  /// (負の値で減額も可能)。設定画面の管理者専用メニューからのみ呼ばれる。
  void addDebugFunds(int amount) {
    if (_save == null) return;
    _save!.budget += amount;
    _notify();
    _persist();
  }

  /// ポジションコンバート特訓の目標ポジションを設定する(nullで解除)。
  /// 生成時に偶然割り当てられた副ポジションとは無関係に、任意のポジション
  /// への転向を目指せる。
  void setPlayerTrainingConvertTarget(String playerId, Position? target) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.trainingConvertTargetPosition = target?.name;
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

  /// 選手にメンター(指導役のベテラン)を指名する。[minMentorAge]未満の選手や
  /// 本人自身は指名できない。nullで解除する。
  bool setMentor(String menteeId, String? mentorId) {
    if (_save == null) return false;
    final mentee = userTeam.players.firstWhere((p) => p.id == menteeId);
    if (mentorId == null) {
      mentee.mentorId = null;
      _notify();
      _persist();
      return true;
    }
    if (mentorId == menteeId) return false;
    Player? mentor;
    for (final p in userTeam.players) {
      if (p.id == mentorId) {
        mentor = p;
        break;
      }
    }
    if (mentor == null || mentor.age < TrainingEngine.minMentorAge) {
      return false;
    }
    mentee.mentorId = mentorId;
    _notify();
    _persist();
    return true;
  }

  /// 育成アドバイザーの提案を、その場で適用する。
  ///
  /// 助言を読んでから該当画面へ移動して設定する往復が、毎週分だけ積み重なる。
  /// 提案どおりでよいときは1タップで済ませられるようにする。
  /// 適用できたら true。ドリルは枠(ヘッドコーチのレベル)が埋まっていると
  /// 失敗するので、その結果をそのまま返す。
  bool applyAdviceFix(DevelopmentAdvice advice) {
    final fix = advice.fix;
    if (fix == null) return false;
    switch (fix) {
      case AssignMentorFix(:final mentorId):
        return setMentor(advice.playerId, mentorId);
      case SetDrillFix(:final attributeKey):
        return setDrillAttribute(advice.playerId, attributeKey);
      case RestFix():
        setPlayerTrainingFocus(advice.playerId, TrainingFocus.rest);
        return true;
    }
  }

  /// 同時にピンポイント特訓ドリルを指定できる人数の上限。ヘッドコーチの
  /// レベルが高いほど、より多くの選手を同時に個別指導できる。
  int get maxDrillSlots =>
      _save == null ? 1 : _save!.infrastructure.staffLevel(StaffRole.headCoach);

  /// 選手のピンポイント特訓ドリル(重点的に伸ばす1属性)を設定する。nullで解除。
  /// 既に[maxDrillSlots]人が指定済みの場合、新規の指定はfalseを返し失敗する
  /// (解除・指定済み選手の対象属性変更は上限に関係なく常に可能)。
  bool setDrillAttribute(String playerId, String? attributeKey) {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (attributeKey != null && player.drillAttributeKey == null) {
      final activeCount =
          userTeam.players.where((p) => p.drillAttributeKey != null).length;
      if (activeCount >= maxDrillSlots) return false;
    }
    player.drillAttributeKey = attributeKey;
    _notify();
    _persist();
    return true;
  }

  /// 選手の2つ目のピンポイント特訓ドリルを設定する。nullで解除。
  /// 1つ目のドリルとは独立して[maxDrillSlots]の上限が適用される。
  bool setDrillAttribute2(String playerId, String? attributeKey) {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (attributeKey != null && player.drillAttributeKey2 == null) {
      final activeCount =
          userTeam.players.where((p) => p.drillAttributeKey2 != null).length;
      if (activeCount >= maxDrillSlots) return false;
    }
    player.drillAttributeKey2 = attributeKey;
    _notify();
    _persist();
    return true;
  }

  /// 選手個別の特性特訓の目標特性を設定する。nullで解除。既に特性を
  /// 保有している選手にも設定自体は可能(効果が発現しないだけ)。技術
  /// カテゴリ以外の特性(才能・性格)は練習では習得できないため無視する。
  void setTraitTrainingTarget(String playerId, PlayerTrait? target) {
    if (_save == null) return;
    if (target != null && target.category != PlayerTraitCategory.technical) {
      return;
    }
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.traitTrainingTarget = target;
    _notify();
    _persist();
  }

  /// 選手個別の性格特性の目標を設定する。nullで解除。メンター(チーム
  /// メイト)や監督との関わりを通じて習得を目指す仕組みのため、性格
  /// カテゴリ以外の特性は無視する。
  void setPersonalityTraitTrainingTarget(String playerId, PlayerTrait? target) {
    if (_save == null) return;
    if (target != null && target.category != PlayerTraitCategory.personality) {
      return;
    }
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.personalityTraitTrainingTarget = target;
    _notify();
    _persist();
  }

  /// 選手個別の育成プラン(目標ロール)を設定する。nullで解除。
  /// 選手のポジション大分類で選択できないロール、およびstandard
  /// (プレースタイルを指定しない)は無視する。
  void setDevelopmentTargetRole(String playerId, PlayerRole? role) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (role != null &&
        (role == PlayerRole.standard ||
            !role.allowedGroups.contains(player.position.group))) {
      return;
    }
    player.developmentTargetRole = role;
    _notify();
    _persist();
  }

  /// 選手個別のローテーション方針(週替わりで自動的に切り替わる複数方針)を
  /// 設定する。nullまたは空リストで解除し、個別方針/チーム既定方針に戻る。
  void setPlayerFocusRotation(String playerId, List<TrainingFocus>? rotation) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.focusRotation =
        (rotation == null || rotation.isEmpty) ? null : rotation;
    player.rotationWeekIndex = 0;
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
    lastReserveMatch = ReserveMatchEngine.play(
      userTeam,
      opponentName: Tr.pick('リザーブ', 'Reserves'),
    );
    lastPracticeMatchCount = lastReserveMatch == null
        ? TrainingEngine.applyIntraSquadMatch(userTeam).length
        : 0;
    for (final p in userTeam.players) {
      if (p.hadBreakthroughThisWeek) _save!.breakthroughCount++;
      if (p.acquiredTraitThisWeek != null) _save!.traitsAcquired++;
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
      if (deltas.isNotEmpty ||
          p.overall != prevOverall ||
          p.acquiredTraitThisWeek != null) {
        changes.add(
          PlayerGrowthSummary(
            playerId: p.id,
            playerName: p.name,
            overallBefore: prevOverall,
            overallAfter: p.overall,
            attributeDeltas: deltas,
            isBreakthrough: p.hadBreakthroughThisWeek,
            acquiredTrait: p.acquiredTraitThisWeek,
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
      seed: _save!.careerSeasons,
      avoidNames: {
        for (final s in _save!.infrastructure.staff.values)
          if (s != null) s.name,
      },
    );
  }

  /// いま雇えるスタッフの候補。シーズンごとに入れ替わる。
  List<StaffMember> staffCandidatesFor(StaffRole role) =>
      _save?.staffCandidates.where((s) => s.role == role).toList() ?? [];

  /// [role]に就いているスタッフ。空席なら null。
  StaffMember? staffFor(StaffRole role) =>
      _save?.infrastructure.staffFor(role);

  int facilityUpgradeCostFor(FacilityType type) {
    if (_save == null) return 0;
    final lvl = _save!.infrastructure.facilityLevel(type);
    return ClubInfrastructure.facilityUpgradeCost(lvl);
  }

  /// 候補[staffId]を雇う。既にその役職に人がいれば入れ替わる。
  ///
  /// 費用は掛からない。掛かるのは週俸で、以後ずっと出ていく。一度の出費で
  /// 済んだ旧レベル制と違い、良いスタッフを抱えるほど毎週の重荷になる。
  Future<bool> hireStaff(String staffId) async {
    if (_save == null) return false;
    final idx = _save!.staffCandidates.indexWhere((s) => s.id == staffId);
    if (idx < 0) return false;
    final hired = _save!.staffCandidates[idx];

    // 週俸の総額が給与予算を食い潰さないよう、選手と同じ枠で見る。
    if (!_wageBudgetAllowsSigning(hired.wage)) return false;

    final previous = _save!.infrastructure.staffFor(hired.role);
    _save!.infrastructure.staff[hired.role] = hired;
    _save!.staffCandidates.removeAt(idx);
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
    final cost = ClubInfrastructure.facilityUpgradeCost(lvl);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
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
    userTeam.players[idx].squadStatus = status;
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
