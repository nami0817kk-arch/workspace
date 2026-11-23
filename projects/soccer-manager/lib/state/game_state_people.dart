part of 'game_state.dart';

/// クラブの人(いまは監督の人事。目標・立場・経歴・引き抜き)。
extension GameStatePeople on GameState {
  /// 今の監督(いなければ null)。
  StaffMember? get currentManager =>
      _save?.infrastructure.staffFor(StaffRole.manager);

  /// 戦力どおりの順位(リーグの中で総合力が何番目か)。目標の既定。
  int get suggestedManagerTarget {
    if (_save == null) return 1;
    final teams = [..._save!.league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final i = teams.indexWhere((t) => t.id == _save!.userTeamId);
    return i < 0 ? 1 : i + 1;
  }

  /// 監督に伝えている今季の目標の順位。
  int get managerTarget {
    final t = _save?.managerTargetRank ?? 0;
    return t > 0 ? t : suggestedManagerTarget;
  }

  int get managerStanding => _save?.managerStanding ?? 0;

  /// 監督に今季の目標の順位を伝える。高すぎる目標は、立場を早く削る。
  Future<void> setManagerTarget(int rank) async {
    if (_save == null) return;
    _save!.managerTargetRank = rank.clamp(1, _save!.league.teams.length);
    _notify();
    await _persist();
  }

  /// 監督の候補に、考え方・経歴を付け、他のクラブで指揮している人を足す。
  void _addManagerCandidates() {
    final s = _save!;
    final rng = Random();
    final clubs = [
      for (final t in _worldTeams)
        if (t.id != s.userTeamId) (name: t.name, tier: _tierOfClub(t.id) ?? 1),
    ];
    final season = Player.contractClockYear;
    // 旧セーブ・始めたときから居る監督にも、考え方を持たせる。
    final cur = s.infrastructure.staffFor(StaffRole.manager);
    if (cur != null && cur.manager == null) {
      cur.manager = ManagerHrEngine.randomProfile(rng,
          clubs: clubs, season: season - 1);
    }
    for (final c in s.staffCandidates) {
      if (c.role == StaffRole.manager && c.manager == null) {
        c.manager =
            ManagerHrEngine.randomProfile(rng, clubs: clubs, season: season - 1);
      }
    }
    // 他のクラブで指揮している監督(同じか下の部のクラブ)。良い人ほど
    // 上のクラブへ移りたがるので、こちらの部の一つ上の水準から選ぶ。
    final employers = [
      for (final t in _worldTeams)
        if (t.id != s.userTeamId &&
            (_tierOfClub(t.id) ?? 1) >= s.currentDivisionTier &&
            !_isForeignTeamId(t.id))
          t,
    ];
    final avoid = {
      for (final c in s.staffCandidates) c.name,
      if (cur != null) cur.name,
    };
    for (var i = 0; i < 2 && employers.isNotEmpty; i++) {
      final club = employers.removeAt(rng.nextInt(employers.length));
      final m = StaffMarket.generateOne(
        role: StaffRole.manager,
        divisionTier: max(1, s.currentDivisionTier - 1),
        confidence: s.confidence,
        id: 'staff-${s.careerSeasons * 100 + today.month}-manager-employed-$i',
        avoid: avoid,
      );
      avoid.add(m.name);
      m.manager = ManagerHrEngine.randomProfile(
        rng,
        clubs: clubs,
        season: season - 1,
        employerClubId: club.id,
        employerClubName: club.name,
        compensation: ManagerHrEngine.compensation(
            weeklyWage: m.wage, contractYears: m.contractYears),
      );
      s.staffCandidates.add(m);
    }
  }

  /// 監督を雇ったあと: 立場を新しくし、好みの布陣に変え、補償金を払う。
  void _onManagerHired(StaffMember hired, int compensation) {
    final s = _save!;
    final profile = hired.manager;
    if (compensation > 0 && profile?.employerClubName != null) {
      _book(LedgerCategory.staffWages, -compensation);
      _logNews(
          Tr.pick('${profile!.employerClubName}へ、${hired.name}の引き抜きの補償金${formatMoney(compensation)}を払った。',
              'Paid ${profile.employerClubName} ${formatMoney(compensation)} in compensation for ${hired.name}.'),
          context: Tr.pick('スタッフ', 'Staff'));
    }
    if (profile != null) {
      hired.manager = profile.hiredCopy();
      final team = userTeam;
      if (team.formation != profile.formation) {
        team.formation = profile.formation;
        LineupUtils.autoFill(team);
        _logNews(
            Tr.pick('新監督の${hired.name}は、布陣を${profile.formation.label}に変えた(${profile.style.label})。',
                'New manager ${hired.name} switched to ${profile.formation.label} (${profile.style.label}).'),
            context: Tr.pick('スタッフ', 'Staff'));
      }
    }
    s.managerStanding = ManagerHrEngine.startingStanding;
    s.managerWarned = false;
    if (profile != null) {
      // 新しい監督は、自分の考え方で戦い方を決め、キャプテンを選び直す。
      ManagerTactics.apply(userTeam,
          style: profile.style,
          level: s.infrastructure.staffLevel(StaffRole.manager));
      _managerAppointsCaptain();
    }
  }

  /// 監督がキャプテン・副キャプテンを指名する。変わったらニュースに出す。
  void _managerAppointsCaptain() {
    final team = userTeam;
    final before = team.captainId;
    ManagerTactics.appointCaptains(team);
    final id = team.captainId;
    if (id == null || id == before) return;
    final captain = team.players.firstWhere((p) => p.id == id);
    final manager = currentManager;
    _logNews(
        manager == null
            ? Tr.pick('${captain.name}がキャプテンになった。',
                '${captain.name} is the new captain.')
            : Tr.pick('${manager.name}監督は、${captain.name}をキャプテンに指名した。',
                '${manager.name} has named ${captain.name} captain.'),
        context: Tr.pick('スタッフ', 'Staff'));
  }

  /// 節ごと: 監督の立場を目標の順位と比べて動かす。若手を使う監督なら、
  /// 21歳以下の選手の不満を和らげる。
  void _updateManagerWeekly(int rank) {
    final s = _save!;
    final m = currentManager;
    if (m == null) return;
    if (m.manager?.style == ManagerStyle.youth) {
      for (final p in userTeam.players) {
        if (p.age <= 21) p.happiness = (p.happiness + 2).clamp(0, 100);
      }
    }
    // 序盤の数節は順位がまだ意味を持たない。
    final played = s.league.sortedStandings
            .where((r) => r.teamId == s.userTeamId)
            .firstOrNull
            ?.played ??
        0;
    if (played < 4) return;
    s.managerStanding = (s.managerStanding +
            ManagerHrEngine.standingDelta(rank: rank, target: managerTarget))
        .clamp(0, 100);
    if (!s.managerWarned &&
        s.managerStanding < ManagerHrEngine.warningStanding) {
      s.managerWarned = true;
      _logNews(
          Tr.pick('${m.name}監督の立場が危うい、と報じられている(目標$managerTarget位・いま$rank位)。続けるか替えるかはオーナー次第。',
              'The press say ${m.name} is under pressure (target ${Tr.ordinal(managerTarget)}, now ${Tr.ordinal(rank)}). Whether he stays is your call.'),
          context: Tr.pick('スタッフ', 'Staff'));
    }
  }

  /// 節ごと: 序列を約束した選手が、出られるのに先発から外れ続けていないか。
  /// 外れ続けたら約束を破ったことになり、選手は移籍を願い出る。
  void _checkPromisesWeekly() {
    final team = userTeam;
    for (final p in team.players) {
      final promised = p.promisedStatus;
      if (promised == null || p.promiseBroken) continue;
      if (team.startingXI.contains(p.id)) {
        p.promiseMisses = 0;
        continue;
      }
      // 出られない事情(負傷・出場停止・代表・貸し出し・登録の名簿の外)が
      // あれば数えない。名簿の外の選手は公式戦に出られない(2026-11-23)。
      if (p.isInjured ||
          p.isSuspended ||
          p.isOnInternationalDuty ||
          p.isLoanedOut ||
          p.notRegistered) {
        continue;
      }
      p.promiseMisses++;
      if (p.promiseMisses >= PlayerTermsEngine.promiseTolerance(promised)) {
        _breakPromise(
            p,
            Tr.pick('${promised.label}として出すと約束したのに、${p.promiseMisses}節続けて先発から外れた',
                'He was promised ${promised.label} billing but has missed ${p.promiseMisses} straight starts'));
      }
    }
  }

  /// テスト用: 約束の点検を1節ぶん行う。
  @visibleForTesting
  void debugCheckPromises() => _checkPromisesWeekly();

  /// 約束を破った: 選手は大きく不満を持ち、移籍を願い出る(移籍リストに載る)。
  void _breakPromise(Player p, String why) {
    p.promiseBroken = true;
    p.happiness = (p.happiness - 25).clamp(0, 100);
    p.isTransferListed = true;
    _logNews(
        Tr.pick('${p.name}が「約束が違う」と移籍を願い出た($why)。',
            '${p.name} has asked to leave, saying you broke your word ($why).'),
        context: Tr.pick('選手', 'Players'));
  }

  /// 季の終わり: 監督の経歴に今季を足し、目標を果たしたら立場を上げる。
  /// 目標は「戦力どおり」に戻す(新しい季に改めて伝える)。
  void _closeManagerSeason({
    required int finalRank,
    required int teams,
    required int tier,
  }) {
    final s = _save!;
    final m = currentManager;
    if (m != null) {
      m.manager ??= ManagerProfile(
          style: ManagerStyle.pragmatic, formation: userTeam.formation);
      m.manager!.career.add(ManagerSpell(
        club: s.clubName,
        season: Player.contractClockYear,
        rank: finalRank,
        teams: teams,
        tier: tier,
      ));
      s.managerStanding = (s.managerStanding +
              ManagerHrEngine.seasonEndBonus(
                  rank: finalRank, target: managerTarget))
          .clamp(0, 100);
    }
    s.managerTargetRank = 0;
    s.managerWarned = false;
  }
}
