part of 'game_state.dart';

/// 選手の契約の日付まわり: 満了日・仮契約(ボスマン)・延長オプション・
/// 「延長しない」・給料の未払いによる解除・合意解除。
extension GameStateContracts on GameState {
  static Random contractRng = Random();

  /// 契約の残り年数を数える基準の年を、セーブのシーズンに合わせる。
  void _syncContractClock([SaveGame? save]) {
    final s = save ?? _save;
    if (s == null) return;
    Player.contractClockYear = Player.seasonEndYearOf(s.league.season);
    final theme = leagueThemeFromName(s.leagueName) ?? LeagueTheme.england;
    // 契約の長さの上限は国で違う(スペインは5年を超えてよい)。
    ContractEngine.adultContractYearsCap = ContractEngine.adultCapFor(theme);
    // 年俸の水準も国・部で違う(economy_scale.dart の wageCountryFactor)。
    setHomeWageLevel(theme, s.currentDivisionTier);
  }

  /// [t]のいる国・部の年俸の水準([wageCountryFactor])。他国のクラブは
  /// その国の1部。
  double _wageLevelOfTeam(Team t) {
    final s = _save!;
    for (final e in s.foreignLeagues.entries) {
      if (!e.value.teams.any((x) => x.id == t.id)) continue;
      final theme =
          LeagueTheme.values.where((x) => x.name == e.key).firstOrNull;
      return wageCountryFactor(theme ?? LeagueTheme.england, 1);
    }
    return wageCountryFactor(
        currentLeagueTheme, _tierOfClub(t.id) ?? s.currentDivisionTier);
  }

  /// [t]のいる部(補充の強さを寄せる先。他国のクラブは1部)。
  int _cpuTierOf(Team t) => _tierOfClub(t.id) ?? _save!.currentDivisionTier;

  /// [t]のいる国・部の水準で選手を作る(他の部・他国のクラブの補充)。
  T _generatingFor<T>(Team t, T Function() body) =>
      withWageLevel(_wageLevelOfTeam(t), body);

  /// 選手を持つ全クラブ(自国の全部と他の4か国の1部)。
  List<Team> get _worldTeams => [
        ..._save!.allTeams,
        for (final l in _save!.foreignLeagues.values) ...l.teams,
      ];

  bool _isForeignTeamId(String teamId) => _save!.foreignLeagues.values.any(
        (l) => l.teams.any((t) => t.id == teamId),
      );

  Team? _worldTeamById(String id) {
    for (final t in _worldTeams) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 結ばれている仮契約の全部。
  List<PreContract> get preContracts => _save?.preContracts ?? const [];

  /// 自クラブが結んだ仮契約(7月1日に加入する選手)。
  List<PreContract> get incomingPreContracts => [
        for (final c in preContracts)
          if (c.toClubId == _save!.userTeamId) c,
      ];

  /// 自クラブの選手が他のクラブと結んだ仮契約(7月1日に出ていく選手)。
  List<PreContract> get outgoingPreContracts => [
        for (final c in preContracts)
          if (c.fromClubId == _save!.userTeamId) c,
      ];

  /// 選手が他のクラブと仮契約を結んでいれば、その仮契約。
  PreContract? outgoingPreContractFor(String playerId) {
    for (final c in outgoingPreContracts) {
      if (c.playerId == playerId) return c;
    }
    return null;
  }

  /// 今日、仮契約を結べる時期か(満了の年の1月1日〜6月30日)。
  bool get preContractWindowOpen =>
      _save != null && PreContractEngine.isOpen(today);

  /// 仮契約を結べる他のクラブの選手(総合力の高い順、[limit]人まで)。
  /// 他国の18歳未満と、もう仮契約を結んだ選手は出さない。
  List<({Player player, Team team})> preContractTargets({int limit = 40}) {
    if (!preContractWindowOpen) return const [];
    final taken = {for (final c in preContracts) c.playerId};
    final list = <({Player player, Team team})>[];
    for (final t in _worldTeams) {
      if (t.id == _save!.userTeamId) continue;
      for (final p in t.players) {
        if (!PreContractEngine.inFinalYear(p)) continue;
        if (taken.contains(p.id)) continue;
        if (_minorBlockedFromClub(p, t.id)) continue;
        list.add((player: p, team: t));
      }
    }
    list.sort((a, b) => b.player.overall.compareTo(a.player.overall));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// 仮契約で[p]が求める週俸。他国のクラブの選手は、こちらの国の水準に
  /// 直した今の週俸から求める([wageScaleToHome])。
  int preContractWageDemand(Player p, {bool option = false}) {
    String? origin;
    if (_save != null) {
      for (final e in _save!.foreignLeagues.entries) {
        if (e.value.teams.any((t) => t.players.any((q) => q.id == p.id))) {
          origin = e.key;
          break;
        }
      }
    }
    return PreContractEngine.wageDemand(p,
        option: option, currentWageScale: wageScaleToHome(origin));
  }

  /// 他のクラブの選手と仮契約を結ぶ。年俸はその場の要求額
  /// ([PreContractEngine.wageDemand])、満了の年は[endYear](省略時は年齢に
  /// 応じた年数)。結べないときは[lastSigningBlockReason]に理由を入れて
  /// false を返す。
  Future<bool> signPreContract(
    String playerId, {
    int? endYear,
    bool option = false,
  }) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    Player? player;
    Team? from;
    for (final t in _worldTeams) {
      if (t.id == _save!.userTeamId) continue;
      for (final p in t.players) {
        if (p.id == playerId) {
          player = p;
          from = t;
        }
      }
    }
    if (player == null || from == null) return false;
    final reason = PreContractEngine.blockReason(
      player,
      today: today,
      fromForeignLeague: _isForeignTeamId(from.id),
      minorBlocked: _minorBlockedFromClub(player, from.id),
      domesticOpensOn: PreContractEngine.domesticOpensOn(currentLeagueTheme),
      alreadyPreContracted: preContracts.any((c) => c.playerId == playerId),
    );
    if (reason != null) {
      lastSigningBlockReason = switch (reason) {
        'closed' => Tr.pick(
            '仮契約は満了の年の1月1日から6月30日までに結べます。',
            'Pre-contracts can be signed from 1 Jan to 30 Jun of the final year.',
          ),
        'notFinalYear' => Tr.pick(
            'この選手の契約は今シーズン末では切れません。',
            "This player's contract does not run out at the end of this season.",
          ),
        'taken' => Tr.pick(
            'この選手はもう他のクラブと仮契約を結んでいます。',
            'This player has already agreed a pre-contract elsewhere.',
          ),
        'domesticNotYet' => Tr.pick(
            '国内のクラブの選手とは、${TransferWindowCalendar.formatMonthDay(PreContractEngine.domesticOpensOn(currentLeagueTheme))}まで仮契約を結べません(他の国のクラブの選手は1月1日から)。',
            'You cannot pre-sign a player from a domestic club until ${TransferWindowCalendar.formatMonthDay(PreContractEngine.domesticOpensOn(currentLeagueTheme))} (players at foreign clubs from 1 Jan).',
          ),
        _ => Tr.pick(
            '18歳未満の選手は国をまたいで移籍できません(EU の中の16〜17歳は除く)。',
            'Players under 18 cannot move between countries (16 and 17-year-olds may move within the EU).',
          ),
      };
      _notify();
      return false;
    }
    // 来季も残る選手(満了の年ではない選手とローン選手)と、仮契約で来る
    // 選手で、登録の上限を超えないか。
    final staying = userTeam.players
        .where((p) => p.isLoan || p.contractEndYear > Player.contractClockYear)
        .length;
    if (staying + incomingPreContracts.length + 1 > maxSquadSize) {
      lastSigningBlockReason = Tr.pick(
        '来季の選手が上限($maxSquadSize人)を超えます。',
        "That would take next season's squad over the limit of $maxSquadSize.",
      );
      _notify();
      return false;
    }
    final choices = PreContractEngine.endYearChoices(player);
    var end = endYear ?? PreContractEngine.defaultEndYear(player);
    if (choices.isEmpty) return false;
    if (end < choices.first) end = choices.first;
    if (end > choices.last) end = choices.last;
    final withOption = option &&
        ContractEngine.canAttachOption(end, player.age, nextSeasonStart: true);
    final contract = PreContract(
      playerId: player.id,
      playerName: player.name,
      fromClubId: from.id,
      fromClubName: from.name,
      toClubId: _save!.userTeamId,
      toClubName: _save!.clubName,
      wage: preContractWageDemand(player, option: withOption),
      endYear: end,
      option: withOption,
      signedOn: today,
    );
    _save!.preContracts.add(contract);
    _logNews(
      Tr.pick(
        '${player.name}(${from.name})と仮契約を結びました。7月1日に移籍金なしで加入します(年俸${formatMoney(annualFromWeekly(contract.wage))}・${ContractEngine.untilLabel(end)})。',
        'Pre-contract agreed with ${player.name} (${from.name}). He joins on a free on 1 Jul (salary ${formatMoney(annualFromWeekly(contract.wage))}, ${ContractEngine.untilLabel(end)}).',
      ),
      context: Tr.pick('仮契約', 'Pre-contract'),
    );
    _notify();
    await _persist();
    return true;
  }

  /// 日付が[before]から[after]へ進んだときの契約の処理。
  void _onContractDatesAdvanced(DateTime before, DateTime after) {
    if (_save == null) return;
    final season = _save!.league.season;
    // 1月1日: 仮契約の解禁。
    if (!after.isBefore(PreContractEngine.opensOn()) &&
        _save!.preContractOpenedSeason != season) {
      _openPreContractSeason();
    }
    // 3月31日を過ぎた: 行使しなかった延長オプションは消える。
    final deadline = ContractEngine.optionDeadline(Player.contractClockYear);
    if (after.isAfter(deadline) && _save!.optionDeadlineSeason != season) {
      _lapseUnusedOptions();
    }
    // イングランド(6月1日)・イタリア(2月1日)は、その日に国内のクラブ同士の
    // 仮契約が始まる(AI 同士の国内の話はそこで決める)。
    if (_save!.preContractOpenedSeason == season) {
      for (final country in PreContractEngine.lateDomesticCountries) {
        final opens = PreContractEngine.domesticOpensOn(country);
        if (before.isBefore(opens) && !after.isBefore(opens)) {
          _openDomesticPreContractsForAi(country);
        }
      }
    }
    // 仮契約の時期は、他のクラブが自クラブの満了の年の選手に声をかける。
    if (_save!.preContractOpenedSeason == season &&
        PreContractEngine.isOpen(after)) {
      final from = before.isBefore(PreContractEngine.opensOn())
          ? PreContractEngine.opensOn()
          : before;
      final days = TransferWindowCalendar.daysBetween(from, after);
      if (days > 0) _rollPoachingOfUserPlayers(days / 7);
    }
  }

  /// 1月1日の解禁。他のクラブは満了の年の選手を更新するか決め、更新しない
  /// 選手の一部とはほかのクラブが仮契約を結ぶ。自クラブの満了の年の選手を
  /// 知らせる。
  void _openPreContractSeason() {
    _save!.preContractOpenedSeason = _save!.league.season;
    final foreign = _foreignTeamIds();
    final made = PreContractEngine.openSeasonForAi(
      _worldTeams,
      _save!.userTeamId,
      contractRng,
      today: today,
      alreadyTaken: {for (final c in preContracts) c.playerId},
      countryOf: (t) => _countryOfClub(t.id, foreign),
      canRegister: _aiPreContractRegistrable(foreign),
      maxSquad: AiTransferEngine.maxSquadSize,
      incoming: _preContractsByDestination(),
    );
    _save!.preContracts.addAll(made);
    final mine = userTeam.players
        .where(
          (p) =>
              PreContractEngine.inFinalYear(p) &&
              outgoingPreContractFor(p.id) == null,
        )
        .toList();
    _logNews(
      mine.isEmpty
          ? Tr.pick(
              '今季末で契約が切れる他のクラブの選手と、仮契約を結べるようになりました(契約の画面)。',
              'You can now sign pre-contracts with players at other clubs whose deals expire this summer (Contracts screen).',
            )
          : Tr.pick(
              '仮契約の時期に入りました。自クラブで今季末に契約が切れる選手(${mine.map((p) => p.name).join('、')})は、他のクラブと仮契約を結ぶことがあります。',
              'Pre-contract season is open. Your players whose deals expire this summer (${mine.map((p) => p.name).join(', ')}) may agree terms elsewhere.',
            ),
      context: Tr.pick('仮契約', 'Pre-contract'),
    );
  }

  /// AI 同士の仮契約の行き先が、登録の決まりで[p]を加えられるか。
  /// 選手の今のクラブの国は、選手のいるクラブから引く。
  bool Function(Team, Player) _aiPreContractRegistrable(
      Map<String, String> foreign) {
    // 選手ごとに全クラブを探すと重いので、選手の国は1回だけ引く。
    final fromOf = <String, LeagueTheme>{};
    return (to, p) {
      final fromCountry = fromOf.putIfAbsent(p.id, () {
        final from = _sellingClubOf(p.id);
        return from == null
            ? currentLeagueTheme
            : _countryOfClub(from.id, foreign);
      });
      return _cpuCanRegister(to, p, fromCountry: fromCountry, foreign: foreign);
    };
  }

  /// 国[country]の国内のクラブ同士の仮契約の開始日([PreContractEngine
  /// .domesticOpensOn])に、AI 同士の国内の仮契約を決める。
  void _openDomesticPreContractsForAi(LeagueTheme country) {
    final foreign = _foreignTeamIds();
    final made = PreContractEngine.openDomesticForAi(
      _worldTeams,
      _save!.userTeamId,
      contractRng,
      country: country,
      countryOf: (t) => _countryOfClub(t.id, foreign),
      today: today,
      alreadyTaken: {for (final c in preContracts) c.playerId},
      canRegister: (to, p) =>
          _cpuCanRegister(to, p, fromCountry: country, foreign: foreign),
      maxSquad: AiTransferEngine.maxSquadSize,
      incoming: _preContractsByDestination(),
    );
    _save!.preContracts.addAll(made);
  }

  /// 結ばれている仮契約の、行き先のクラブ ID→人数(7月1日に加わる人数)。
  Map<String, int> _preContractsByDestination() {
    final n = <String, int>{};
    for (final c in preContracts) {
      n[c.toClubId] = (n[c.toClubId] ?? 0) + 1;
    }
    return n;
  }

  /// 3月31日までに行使しなかった延長オプションを消す。
  void _lapseUnusedOptions() {
    _save!.optionDeadlineSeason = _save!.league.season;
    final lapsed = <Player>[];
    for (final p in userTeam.players) {
      if (p.contractOption && p.contractEndYear == Player.contractClockYear) {
        p.contractOption = false;
        lapsed.add(p);
      }
    }
    if (lapsed.isEmpty) return;
    _logNews(
      Tr.pick(
        '延長オプションを行使しなかったため、${lapsed.map((p) => p.name).join('、')}の契約は6月30日で満了します。',
        'The 1-year options were not taken up, so ${lapsed.map((p) => p.name).join(', ')} will be out of contract on 30 Jun.',
      ),
      context: Tr.pick('契約', 'Contracts'),
    );
  }

  /// 自クラブの満了の年の選手に、他のクラブが仮契約を持ちかける。
  void _rollPoachingOfUserPlayers(double weeks) {
    final cpuTeams =
        _save!.league.teams.where((t) => t.id != _save!.userTeamId).toList();
    final foreign = _foreignTeamIds();
    final made = PreContractEngine.poachFromUser(
      userTeam,
      cpuTeams,
      contractRng,
      today: today,
      weeks: weeks,
      alreadyTaken: {for (final c in preContracts) c.playerId},
      // 国内のクラブが声をかけられるのは国の開始日から(イングランドは
      // 6月1日・イタリアは2月1日)。それまでは他の国のクラブだけ。
      foreignTeams: [
        for (final l in _save!.foreignLeagues.values) ...l.teams,
      ],
      domesticOpensOn: PreContractEngine.domesticOpensOn(currentLeagueTheme),
      canRegister: (to, p) => _cpuCanRegister(to, p,
          fromCountry: currentLeagueTheme, foreign: foreign),
      maxSquad: AiTransferEngine.maxSquadSize,
      incoming: _preContractsByDestination(),
    );
    for (final c in made) {
      _save!.preContracts.add(c);
      if (_save!.pendingContractNegotiation?.playerId == c.playerId) {
        _save!.pendingContractNegotiation = null;
      }
      _logNews(
        Tr.pick(
          '${c.playerName}が${c.toClubName}と仮契約を結びました。7月1日に移籍金なしで出ていきます。それまでに売れば移籍金が入ります。',
          '${c.playerName} has agreed a pre-contract with ${c.toClubName} and will leave on a free on 1 Jul. Sell him before then to get a fee.',
        ),
        context: Tr.pick('仮契約', 'Pre-contract'),
      );
    }
  }

  /// 7月1日(新しいシーズンの始まり)の契約の処理。呼ぶ前に
  /// [_syncContractClock]で新しいシーズンに合わせておくこと。
  ///
  /// 1. 自クラブ: 満了日を過ぎた選手が出ていく(仮契約の先があればそこへ、
  ///    無ければフリーエージェントへ)。満了の年に入った選手を知らせ、
  ///    一部は「延長しない」と言い出す。
  /// 2. 仮契約: 自クラブが結んだ選手を加え、AI 同士の仮契約も移す。
  /// 3. 他のクラブ: 満了日を過ぎた選手が出ていき、若手で埋める。
  /// 4. 他のクラブ: 上限([AiTransferEngine.maxSquadSize])を超えたクラブは、
  ///    弱い選手からフリーエージェントへ出す(古いセーブで膨らんだクラブも
  ///    ここで上限まで減る)。
  void _settleContractsAtSeasonStart() {
    final userId = _save!.userTeamId;
    final contracts = List<PreContract>.from(_save!.preContracts);
    _save!.preContracts.clear();
    final byPlayer = {for (final c in contracts) c.playerId: c};
    // クラブ ID→クラブ・他国のクラブの国は1回だけ引く(以前は仮契約1件ごとに
    // 全クラブの一覧を作り直していた)。
    final worldTeams = _worldTeams;
    final teamById = {for (final t in worldTeams) t.id: t};
    final foreign = _foreignTeamIds();
    // 選手が入れ替わった CPU のクラブ。先発の組み直しは最後に1回ずつ。
    final touched = <Team>{};

    // 1. 自クラブ。
    final contractResult = ContractEngine.advanceSeason(userTeam);
    lastContractExpirations =
        contractResult.expired.map((p) => p.name).toList();
    for (final p in contractResult.expired) {
      _logMove(p,
          from: userTeam.name,
          to: Tr.pick('所属なし(契約満了)', 'Free agent (contract expired)'),
          kind: PlayerMoveKind.free);
      _clearPlayerRoleReferences(userTeam, p.id);
      userTeam.players.remove(p);
      userTeam.startingXI.remove(p.id);
      // 貸し出し中に契約が切れた選手は、貸し出しを終えてから出す。貸し出しの
      // 清算([_settleLoansByDate])はこの後に回るので、以前は「貸し出し中」の
      // 印を付けたまま他のクラブ・所属なしへ移っていた(2026-11-23)。
      if (p.isLoanedOut) _endLoanOutSilently(p);
      final c = byPlayer[p.id];
      final dest = c == null ? null : teamById[c.toClubId];
      if (c != null && dest != null && c.fromClubId == userId) {
        PreContractEngine.applyOnJoin(p, c);
        _fixNationality(p);
        dest.players.add(p);
        touched.add(dest);
        continue;
      }
      p.contractOption = false;
      p.refusesRenewal = false;
      if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize) {
        _save!.freeAgents.add(p);
      }
    }
    lastContractWarnings =
        contractResult.nearingExpiry.map((p) => p.name).toList();
    final refusing = <String>[];
    for (final p in contractResult.nearingExpiry) {
      if (p.contractOption || p.refusesRenewal) continue;
      if (contractRng.nextDouble() < ContractEngine.refuseRenewalChance(p)) {
        p.refusesRenewal = true;
        refusing.add(p.name);
      }
    }
    lastRenewalRefusals = refusing;

    // 2. 仮契約で移る選手(自クラブへ・AI 同士)。
    final joined = <String>[];
    for (final c in contracts) {
      if (c.fromClubId == userId) continue; // 上で済ませた
      final from = teamById[c.fromClubId];
      final player = from?.players.where((p) => p.id == c.playerId).firstOrNull;
      if (from == null || player == null) continue; // 引退・消滅したクラブ
      final to = c.toClubId == userId ? userTeam : teamById[c.toClubId];
      if (to == null) continue;
      // イタリアの「EU 外は1季2人まで」は、仮契約で国外から来る選手も
      // 数える(加入の季に。元のクラブから外す前に)。
      if (to.id == userId) {
        _noteSigningFromAbroad(player);
      } else {
        _noteCpuSigning(to, player,
            fromCountry: _countryOfClub(from.id, foreign), foreign: foreign);
      }
      _fixNationality(player);
      _removeFromCpuTeam(from, player);
      PreContractEngine.applyOnJoin(player, c);
      player.originLeague = null;
      player.originClubName = null;
      to.players.add(player);
      if (to.id == userId) {
        joined.add(player.name);
      } else {
        touched.add(to);
      }
      touched.add(from);
      // 抜けたクラブは、最低人数を割るときだけ若手で埋める。以前は必ず
      // 1人足していて、受け入れ側の1人ぶん世界の選手が毎回増えていた。
      if (from.players.length < minSquadSize) {
        from.players.add(_generatingFor(
            from,
            () => RetirementEngine.cpuRecruitFor(from, player.position,
                replacedOverall: player.overall,
                tier: _cpuTierOf(from))));
      }
    }
    lastPreContractArrivals = joined;

    // 3. 他のクラブの満了。
    for (final t in worldTeams) {
      if (t.id == userId) continue;
      final expired = t.players
          .where(
            (p) => !p.isLoan && p.contractEndYear < Player.contractClockYear,
          )
          .toList();
      if (expired.isEmpty) continue;
      for (final p in expired) {
        _removeFromCpuTeam(t, p);
        if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize &&
            p.age < 34) {
          _save!.freeAgents.add(p);
        }
        t.players.add(_generatingFor(
            t,
            () => RetirementEngine.cpuRecruitFor(t, p.position,
                replacedOverall: p.overall, tier: _cpuTierOf(t))));
      }
      touched.add(t);
    }

    // 4. 上限を超えた CPU のクラブは、弱い選手から出す。
    for (final t in worldTeams) {
      if (t.id == userId) continue;
      if (_trimCpuSquad(t)) touched.add(t);
    }

    for (final t in touched) {
      if (t.id != userId) LineupUtils.autoFill(t);
    }
    // 自クラブも、満了・引退で抜けた先発の枠だけを埋める(残っている先発は
    // 動かさない)。以前は季の切り替え直後に先発が7〜9人で表示されていた
    // (2026-11-23)。
    LineupUtils.fillVacancies(userTeam);
  }

  /// CPU のクラブ[t]が上限([AiTransferEngine.maxSquadSize])を超えていたら、
  /// 総合力の低い選手からフリーエージェントへ出して上限に収める。ローンで
  /// 来ている選手は出さない(持ち主のクラブがある)。GK は2人を残す。
  /// 出した選手がいれば true。
  bool _trimCpuSquad(Team t) {
    final limit = AiTransferEngine.maxSquadSize;
    var excess = t.players.length - limit;
    if (excess <= 0) return false;
    var keepers = t.players.where((p) => p.position == Position.gk).length;
    final candidates = t.players.where((p) => !p.isLoan).toList()
      ..sort((a, b) => a.overall.compareTo(b.overall));
    for (final p in candidates) {
      if (excess <= 0) break;
      if (p.position == Position.gk) {
        if (keepers <= 2) continue;
        keepers--;
      }
      _removeFromCpuTeam(t, p);
      if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize &&
          p.age < 34) {
        p.contractOption = false;
        p.refusesRenewal = false;
        _save!.freeAgents.add(p);
      }
      excess--;
    }
    return true;
  }

  /// 貸し出しの印を消す(復帰の知らせは出さない。契約が切れて出ていく
  /// 選手・手放したクラブの選手に使う)。
  void _endLoanOutSilently(Player p) {
    p.loanedOutWeeksRemaining = 0;
    p.loanedOutUntil = null;
    p.loanRecallClause = false;
    p.loanedOutToClubName = null;
    p.loanedWithPlayingTime = false;
    p.loanStartOverall = 0;
  }

  @visibleForTesting
  void debugSettleContractsAtSeasonStart() => _settleContractsAtSeasonStart();

  /// CPU クラブから選手を外す(先発・役割の指名も外す)。
  void _removeFromCpuTeam(Team team, Player p) {
    team.players.remove(p);
    team.startingXI.remove(p.id);
    if (team.captainId == p.id) team.captainId = null;
    if (team.viceCaptainId == p.id) team.viceCaptainId = null;
    if (team.penaltyTakerId == p.id) team.penaltyTakerId = null;
    if (team.freeKickTakerId == p.id) team.freeKickTakerId = null;
    if (team.cornerTakerId == p.id) team.cornerTakerId = null;
    if (team.manMarkerId == p.id) team.manMarkerId = null;
    if (team.setPieceDefenderId == p.id) team.setPieceDefenderId = null;
  }

  // ---- 111. 延長オプション ----

  /// 延長オプションを今日行使できるか。
  bool canExerciseContractOption(String playerId) {
    if (_save == null) return false;
    final p = userTeam.players.where((p) => p.id == playerId).firstOrNull;
    return p != null && ContractEngine.canExerciseOption(p, today);
  }

  /// 延長オプションを行使する。満了が1年延び、年俸はそのまま。
  Future<bool> exerciseContractOption(String playerId) async {
    if (!canExerciseContractOption(playerId)) return false;
    final p = userTeam.players.firstWhere((p) => p.id == playerId);
    ContractEngine.exerciseOption(p);
    _logNews(
      Tr.pick(
        '${p.name}の延長オプションを行使しました(${ContractEngine.untilLabel(p.contractEndYear)})。',
        'Took up the 1-year option on ${p.name} (${ContractEngine.untilLabel(p.contractEndYear)}).',
      ),
      context: Tr.pick('契約', 'Contracts'),
    );
    _notify();
    await _persist();
    return true;
  }

  // ---- 113. 更新できない理由 ----

  /// 更新の交渉ができない理由(できるなら null)。
  String? renewalBlockReason(Player p) {
    if (p.isLoan) {
      return Tr.pick('ローン選手とは更新できません。', 'You cannot renew a loan player.');
    }
    if (outgoingPreContractFor(p.id) != null) {
      return Tr.pick(
        '他のクラブと仮契約を結んでいるので、更新に応じません。',
        'He has agreed a pre-contract elsewhere and will not renew.',
      );
    }
    if (p.refusesRenewal) {
      return Tr.pick(
        '契約を延長しないと言っています。売るか、満了で手放すことになります。',
        'He has said he will not sign a new deal. Sell him, or lose him for nothing when it expires.',
      );
    }
    return null;
  }

  // ---- 114. 給料の未払い ----

  /// 資金のマイナスが続いたときの、給料の未払いの通告と契約の解除。
  /// 毎週の処理から呼ぶ。出ていった選手の名前を返す。
  List<String> _checkUnpaidWages() {
    final weeks = _save!.consecutiveNegativeBudgetWeeks;
    if (weeks == 0) {
      _save!.unpaidWagesNoticeGiven = false;
      return const [];
    }
    if (weeks >= ContractEngine.unpaidNoticeWeeks &&
        !_save!.unpaidWagesNoticeGiven) {
      _save!.unpaidWagesNoticeGiven = true;
      _logNews(
        Tr.pick(
          '給料を2か月分払えていないとして、選手たちから支払いの催告が届きました。2週のうちに資金をプラスに戻さないと、契約を解除して出ていく選手が出ます。',
          'The players have formally demanded two months of unpaid wages. Get back in the black within two weeks, or some will terminate their contracts and leave.',
        ),
        context: Tr.pick('契約', 'Contracts'),
      );
    }
    final leaving = ContractEngine.unpaidWageWalkouts(
      userTeam,
      weeks,
      contractRng,
    );
    if (leaving.isEmpty) return const [];
    // 最低人数は割らない(試合ができなくなる)。
    final room = userTeam.players.length - minSquadSize;
    final names = <String>[];
    for (final p in leaving.take(room < 0 ? 0 : room)) {
      _clearPlayerRoleReferences(userTeam, p.id);
      userTeam.players.remove(p);
      userTeam.startingXI.remove(p.id);
      _save!.preContracts.removeWhere((c) => c.playerId == p.id);
      p.contractEndYear = Player.contractClockYear - 1;
      p.contractOption = false;
      p.refusesRenewal = false;
      if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize) {
        _save!.freeAgents.add(p);
      }
      names.add(p.name);
    }
    if (names.isEmpty) return const [];
    LineupUtils.fillVacancies(userTeam);
    _logNews(
      Tr.pick(
        '給料の未払いを理由に、${names.join('、')}が契約を解除して自由契約で出ていきました。',
        '${names.join(', ')} terminated their contracts over unpaid wages and left on a free.',
      ),
      context: Tr.pick('契約', 'Contracts'),
    );
    return names;
  }

  // ---- 115. 合意解除 ----

  /// 合意して契約を解除するときに払う額(万円)。解除できない選手は null。
  int? mutualTerminationCostFor(String playerId) {
    if (_save == null) return null;
    final p = userTeam.players.where((p) => p.id == playerId).firstOrNull;
    if (p == null || p.isLoan || p.isLoanedOut) return null;
    return ContractEngine.mutualTerminationCost(p, today);
  }

  /// 残りの年俸の一部を払って、合意のうえで契約を解除する。選手は
  /// 自由契約になる。資金が足りない・最低人数を割るときは false。
  Future<bool> terminateContractByMutualConsent(String playerId) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    final cost = mutualTerminationCostFor(playerId);
    if (cost == null) return false;
    if (userTeam.players.length <= minSquadSize) {
      lastSigningBlockReason = Tr.pick(
        'これ以上人数を減らせません。',
        'Your squad cannot get any smaller.',
      );
      _notify();
      return false;
    }
    if (_save!.budget < cost) {
      lastSigningBlockReason = Tr.pick(
        '解除に払う${formatMoney(cost)}が足りません(資金${formatMoney(_save!.budget)})。',
        'You cannot cover the ${formatMoney(cost)} settlement (funds ${formatMoney(_save!.budget)}).',
      );
      _notify();
      return false;
    }
    final p = userTeam.players.firstWhere((p) => p.id == playerId);
    _book(LedgerCategory.playerWages, -cost);
    _logMove(p,
        from: userTeam.name,
        to: Tr.pick('所属なし', 'Free agent'),
        kind: PlayerMoveKind.release);
    _clearPlayerRoleReferences(userTeam, p.id);
    userTeam.players.remove(p);
    userTeam.startingXI.remove(p.id);
    _save!.preContracts.removeWhere((c) => c.playerId == p.id);
    p.contractEndYear = Player.contractClockYear - 1;
    p.contractOption = false;
    p.refusesRenewal = false;
    if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize) {
      _save!.freeAgents.add(p);
    }
    LineupUtils.fillVacancies(userTeam);
    _logNews(
      Tr.pick(
        '${p.name}と合意して契約を解除しました(${formatMoney(cost)}を支払い)。',
        "Terminated ${p.name}'s contract by mutual consent (paid ${formatMoney(cost)}).",
      ),
      context: Tr.pick('契約', 'Contracts'),
    );
    _notify();
    await _persist();
    return true;
  }
}
