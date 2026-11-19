part of 'game_state.dart';

/// クラブ同士の移籍金の交渉(買う側)と、来たオファーへの対案(売る側)。
extension GameStateTalks on GameState {
  /// 進んでいる交渉(決裂したものも、窓が閉じるまで残す)。
  List<TransferTalk> get transferTalks => _save?.transferTalks ?? const [];

  /// [playerId]の選手との交渉(無ければ null)。
  TransferTalk? talkFor(String playerId) =>
      transferTalks.where((t) => t.playerId == playerId).firstOrNull;

  /// 交渉の相手の選手(他のクラブ・作り物の市場にいる)。もういなければ null。
  Player? talkPlayer(String playerId) {
    if (_save == null) return null;
    final m = transferMarket.where((p) => p.id == playerId).firstOrNull;
    if (m != null) return m;
    final fa = _save!.freeAgents.where((p) => p.id == playerId).firstOrNull;
    if (fa != null) return fa;
    return _sellingClubOf(playerId)
        ?.players
        .where((p) => p.id == playerId)
        .firstOrNull;
  }

  /// 相手のクラブの言い値(交渉の材料。画面には対案が来てから出る)。
  int askingPriceFor(Player p) {
    final club = _sellingClubOf(p.id);
    if (club == null) return p.marketValue;
    final top = [...club.players]
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final asking = TransferTalkEngine.askingPrice(
      marketValue: p.marketValue,
      keyPlayer: top.take(3).any((q) => q.id == p.id),
      starter: club.startingXI.contains(p.id),
      contractYearsLeft: p.contractYearsRemaining,
      age: p.age,
      potentialGap: p.potential - p.overall,
    );
    // 破綻したクラブは、選手を投げ売りしている。
    final distress =
        isDistressedClub(club.id) ? GameStateClubFinance.distressDiscount : 1.0;
    // 移籍の相場(季ごとに動く)。
    return (asking * sdPriceFactor * distress * marketIndex / 100).round();
  }

  /// 移籍金[bid]を提示する(新しく申し込む、または対案に出し直す)。
  /// [installments]なら分割払い(頭金3割と、残りを4週で)を求める。
  /// 申し込めなければ false(理由は[lastSigningBlockReason])。
  Future<bool> openTransferTalk(String playerId, int bid,
      {bool installments = false}) async {
    final ok = _openTalkCore(playerId, bid, installments: installments);
    if (ok) {
      _notify();
      await _persist();
    }
    return ok;
  }

  bool _openTalkCore(String playerId, int bid, {bool installments = false}) {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    if (!isTransferWindowOpen) {
      return _blockTalk(Tr.pick('移籍の窓が閉じています。', 'The transfer window is shut.'));
    }
    final existing = talkFor(playerId);
    if (existing != null) {
      switch (existing.stage) {
        case TransferTalkStage.collapsed:
          return _blockTalk(Tr.pick('この窓のあいだは、もう話を聞いてもらえません。',
              'They will not talk to you again in this window.'));
        case TransferTalkStage.waiting:
          return _blockTalk(Tr.pick('相手の返事を待っています。', 'You are waiting for their reply.'));
        case TransferTalkStage.agreed:
          return _blockTalk(Tr.pick('もう合意しています。移籍を決めてください。',
              'You already have a deal. Complete the transfer.'));
        case TransferTalkStage.countered:
          if (existing.round >= TransferTalkEngine.maxRounds) {
            return _blockTalk(Tr.pick('提示できるのは${TransferTalkEngine.maxRounds}回までです。',
                'You can only bid ${TransferTalkEngine.maxRounds} times.'));
          }
          if (bid <= existing.bid) {
            return _blockTalk(Tr.pick('前の提示より高い額でないと出し直せません。',
                'A new bid has to beat your last one.'));
          }
      }
    }
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final player = target.player;
    if (!_minorRuleAllows(player)) return false;
    if (!_registrationAllows(player)) return false;
    final upfront = installments ? (bid * 0.3).round() : bid;
    if (bid <= 0 ||
        _save!.budget < upfront + TransferTermsEngine.agentFee(bid)) {
      return _blockTalk(Tr.pick('資金が足りません(代理人手数料も要ります)。',
          'You cannot afford it (the agent fee comes on top).'));
    }
    if (!_wageBudgetAllowsSigning(player.wage)) return false;

    final replyOn =
        today.add(const Duration(days: TransferTalkEngine.replyDays));
    if (existing != null) {
      existing
        ..round += 1
        ..bid = bid
        ..installments = installments
        ..stage = TransferTalkStage.waiting
        ..replyOn = replyOn;
    } else {
      _save!.transferTalks.add(TransferTalk(
        playerId: player.id,
        playerName: player.name,
        clubId: target.club?.id ?? '',
        clubName: target.club?.name ?? (player.originClubName ?? ''),
        bid: bid,
        installments: installments,
        replyOn: replyOn,
      ));
    }
    final club = talkFor(playerId)!.clubName;
    _logNews(
        Tr.pick(
            '$clubに${player.name}の移籍金として${formatMoney(bid)}を提示した(${installments ? '分割' : '一括'})。返事は${TransferWindowCalendar.formatMonthDay(replyOn)}ごろ。',
            'Bid ${formatMoney(bid)} to $club for ${player.name} (${installments ? 'in instalments' : 'up front'}). Expect a reply around ${TransferWindowCalendar.formatMonthDay(replyOn)}.'),
        context: Tr.pick('移籍', 'Transfer'));
    return true;
  }

  bool _blockTalk(String reason) {
    lastSigningBlockReason = reason;
    _notify();
    return false;
  }

  /// 相手の対案をのむ(その条件で合意する)。
  Future<bool> acceptTalkCounter(String playerId) async {
    final ok = _acceptCounterCore(playerId);
    if (ok) {
      _notify();
      await _persist();
    }
    return ok;
  }

  bool _acceptCounterCore(String playerId) {
    final t = talkFor(playerId);
    if (t == null || t.stage != TransferTalkStage.countered) return false;
    if (!isTransferWindowOpen) return false;
    t
      ..stage = TransferTalkStage.agreed
      ..replyOn = null
      ..deadline =
          today.add(const Duration(days: TransferTalkEngine.agreementDays));
    _logNews(
        Tr.pick('${t.clubName}の対案(${formatMoney(t.fee)})をのみ、${t.playerName}の移籍で合意した。',
            'Accepted ${t.clubName}\'s terms (${formatMoney(t.fee)}) for ${t.playerName}.'),
        context: Tr.pick('移籍', 'Transfer'));
    return true;
  }

  /// 交渉を取り下げる(決裂したものを一覧から消すのにも使う)。決裂した
  /// 相手には、消してもこの窓のあいだは申し込めない。
  Future<void> withdrawTransferTalk(String playerId) async {
    final t = talkFor(playerId);
    if (t == null) return;
    if (t.isOpen) {
      _save!.transferTalks.remove(t);
    }
    _notify();
    await _persist();
  }

  /// クラブの id → 部(自国の各部。他の国の1部は 1)。見つからなければ null。
  int? _tierOfClub(String clubId) {
    final s = _save!;
    if (s.league.teams.any((t) => t.id == clubId)) return s.currentDivisionTier;
    for (var i = 0; i < s.otherDivisionLeagues.length; i++) {
      if (s.otherDivisionLeagues[i]?.teams.any((t) => t.id == clubId) ??
          false) {
        return i + 1;
      }
    }
    if (_foreignTeamIds().containsKey(clubId)) return 1;
    return null;
  }

  /// こちらへ来たら先発になれそうか(同じ大分類の先発の一番下より上)。
  bool _wouldStartHere(Player p) {
    final team = userTeam;
    final starters = [
      for (final q in team.players)
        if (team.startingXI.contains(q.id) &&
            q.position.group == p.position.group)
          q.overall,
    ];
    if (starters.isEmpty) return true;
    return p.overall > starters.reduce(min);
  }

  /// 選手に年俸・契約の満了の年・サイン料を出す。
  ///
  /// 他のクラブの選手は、クラブと移籍金で合意してから(窓のあいだだけ)。
  /// フリーエージェントは、いつでも直接。のめば加入し、足りなければ
  /// 望む額を返され([TransferTalk.demandWage])、離れすぎていれば断られる。
  Future<TermsOutcome> offerPersonalTerms(
    String playerId, {
    required int weeklyWage,
    required int endYear,
    int signingBonus = 0,
    SquadStatus promise = SquadStatus.regular,
  }) async {
    final out = _termsCore(playerId,
        weeklyWage: weeklyWage,
        endYear: endYear,
        signingBonus: signingBonus,
        promise: promise);
    if (out != TermsOutcome.blocked) {
      _notify();
      await _persist();
    }
    return out;
  }

  TermsOutcome _termsCore(
    String playerId, {
    required int weeklyWage,
    required int endYear,
    int signingBonus = 0,
    SquadStatus promise = SquadStatus.regular,
  }) {
    if (_save == null) return TermsOutcome.blocked;
    lastSigningBlockReason = null;
    final fa = _save!.freeAgents.where((p) => p.id == playerId).firstOrNull;
    var t = talkFor(playerId);
    ({Player player, Team? club})? target;
    final Player player;
    if (fa != null) {
      player = fa;
      if (t != null && t.stage == TransferTalkStage.collapsed) {
        _blockTalk(Tr.pick('${fa.name}はもう話を聞いてくれません。',
            '${fa.name} will not talk to you any more.'));
        return TermsOutcome.blocked;
      }
    } else {
      if (t == null || t.stage != TransferTalkStage.agreed) {
        return TermsOutcome.blocked;
      }
      if (!isTransferWindowOpen) {
        _blockTalk(Tr.pick('移籍の窓が閉じています。', 'The transfer window is shut.'));
        return TermsOutcome.blocked;
      }
      target = _acquisitionTarget(playerId);
      if (target == null) return TermsOutcome.blocked;
      player = target.player;
    }
    if (!_minorRuleAllows(player)) return TermsOutcome.blocked;
    if (!_registrationAllows(player)) return TermsOutcome.blocked;

    final inst = t != null && t.installments && t.installmentsOk;
    final fee = fa != null ? 0 : t!.fee;
    final upfront = inst ? (fee * 0.3).round() : fee;
    // 代理人の手数料は、代理人の個性で率が違う。
    final agent = RelationsEngine.agentOf(player);
    final agentFee = (fee * agent.feePercent / 100).round();
    if (weeklyWage <= 0 || signingBonus < 0) return TermsOutcome.blocked;
    if (_save!.budget < upfront + agentFee + signingBonus) {
      _blockTalk(Tr.pick('資金が足りません(移籍金・代理人手数料・サイン料)。',
          'You cannot afford it (fee, agent fee and signing bonus).'));
      return TermsOutcome.blocked;
    }
    if (!_wageBudgetAllowsSigning(weeklyWage)) return TermsOutcome.blocked;

    if (t == null) {
      t = TransferTalk(
        playerId: player.id,
        playerName: player.name,
        clubId: '',
        clubName: Tr.pick('所属なし', 'Free agent'),
        bid: 0,
        stage: TransferTalkStage.agreed,
        freeAgent: true,
        deadline:
            today.add(const Duration(days: TransferTalkEngine.agreementDays)),
      );
      _save!.transferTalks.add(t);
    }
    final ctx = Tr.pick('移籍', 'Transfer');
    final fromTier = fa != null
        ? null
        : (target!.club == null
            ? _save!.currentDivisionTier
            : _tierOfClub(target.club!.id));
    final toTier = _save!.currentDivisionTier;
    final refusal = PlayerTermsEngine.refusal(
        fromTier: fromTier, toTier: toTier, age: player.age);
    if (refusal != null) {
      t.stage = TransferTalkStage.collapsed;
      lastSigningBlockReason = refusal;
      _logNews(Tr.pick('${player.name}: $refusal', '${player.name}: $refusal'),
          context: ctx);
      return TermsOutcome.refused;
    }
    var demand = PlayerTermsEngine.demand(
      currentWage: player.wage,
      marketValue: player.marketValue,
      fromTier: fromTier,
      toTier: toTier,
      wasStarter: target?.club?.startingXI.contains(player.id) ?? false,
      wouldStart: _wouldStartHere(player),
      stepDownFactor: player.traits.stepDownFactor,
      promise: promise,
      agentFactor: agent.demandFactor,
    );
    // 他のクラブも誘っていれば、選手は年俸とクラブの格を比べる。
    if (t.hasRival) {
      demand = max(
          demand,
          PlayerTermsEngine.rivalPull(
              rivalWage: t.rivalWage,
              rivalTier: _tierOfClub(t.rivalClubId!) ?? toTier,
              toTier: toTier));
    }
    final years = max(1, endYear - Player.contractClockYear + 1);
    final effective = PlayerTermsEngine.effectiveWeekly(
        weeklyWage: weeklyWage, years: years, signingBonus: signingBonus);
    t.termsRound += 1;
    switch (PlayerTermsEngine.judge(
        effective: effective,
        demand: demand,
        round: t.termsRound,
        walkAway: agent.walkAwayRatio)) {
      case TermsReplyKind.walkAway:
        t.stage = TransferTalkStage.collapsed;
        lastSigningBlockReason = Tr.pick(
            '${player.name}は条件に納得せず、話は流れました。',
            '${player.name} was not happy with the terms. The deal is off.');
        _logNews(lastSigningBlockReason!, context: ctx);
        return TermsOutcome.refused;
      case TermsReplyKind.counter:
        t.demandWage = demand;
        return TermsOutcome.counter;
      case TermsReplyKind.accept:
        break;
    }

    if (fa != null) {
      _save!.freeAgents.remove(fa);
    } else {
      _book(LedgerCategory.transfers, -upfront);
      if (inst) {
        const weeks = 4;
        _save!.pendingInstallments.add(Installment(
          description: Tr.pick('${player.name} 分割払い残金',
              '${player.name} instalments outstanding'),
          weeklyAmount: ((fee - upfront) / weeks).ceil(),
          weeksRemaining: weeks,
          playerId: player.id,
        ));
      }
      _bookAgentFee(player, agentFee);
      if (t.sellOnPercent > 0) {
        _save!.sellOnClauses[player.id] = t.sellOnPercent;
        _logNews(
            Tr.pick('${player.name}の獲得で、${t.clubName}に売却条項(${t.sellOnPercent}%)を約束した。',
                'To land ${player.name} we agreed a ${t.sellOnPercent}% sell-on clause with ${t.clubName}.'),
            context: ctx);
      }
      _takeFromSeller(target!);
      if (fee < player.marketValue) {
        _save!.negotiationSignings++;
        _evaluateAchievements();
      }
    }
    if (signingBonus > 0) _book(LedgerCategory.transfers, -signingBonus);
    // 移籍金は契約の年数で償却する(簿価)。
    player.wage = weeklyWage;
    ContractEngine.renewContract(player, endYear: endYear);
    _recordPlayerBook(player, fee);
    // 約束した序列と、加入したときの機嫌(順応の高い選手ほど良い)。
    player.squadStatus = promise;
    player.promisedStatus =
        promise.index <= SquadStatus.regular.index ? promise : null;
    player.promiseMisses = 0;
    player.promiseBroken = false;
    player.happiness = player.traits.arrivalHappiness;
    userTeam.players.add(player);
    _save!.transferTalks.remove(t);
    _logNews(
        fa != null
            ? Tr.pick(
                '${player.name}と契約した(年俸${formatMoney(annualFromWeekly(weeklyWage))}・${player.contractEndYear}年6月まで${signingBonus > 0 ? '・サイン料${formatMoney(signingBonus)}' : ''})。',
                'Signed ${player.name} (${formatMoney(annualFromWeekly(weeklyWage))} a year to June ${player.contractEndYear}${signingBonus > 0 ? ', ${formatMoney(signingBonus)} signing bonus' : ''}).')
            : Tr.pick(
                '${player.name}が${t.clubName}から加入した(移籍金${formatMoney(fee)}・年俸${formatMoney(annualFromWeekly(weeklyWage))}・${player.contractEndYear}年6月まで${signingBonus > 0 ? '・サイン料${formatMoney(signingBonus)}' : ''})。',
                '${player.name} joined from ${t.clubName} (fee ${formatMoney(fee)}, ${formatMoney(annualFromWeekly(weeklyWage))} a year to June ${player.contractEndYear}${signingBonus > 0 ? ', ${formatMoney(signingBonus)} signing bonus' : ''}).'),
        context: ctx);
    return TermsOutcome.signed;
  }

  /// 日付が進んだぶん、相手の返事を受け取り、期限の切れた話を流す。
  /// 来たオファーへの対案の返事もここで受け取る。
  void _advanceTransferTalks(DateTime before, DateTime after) {
    if (_save == null) return;
    _advanceTransferTalksInner(before, after);
    if (!TransferWindowCalendar.isOpen(after, currentLeagueTheme)) {
      _save!.sdSignedThisWindow = 0;
    } else {
      _runSportingDirector();
    }
  }

  void _advanceTransferTalksInner(DateTime before, DateTime after) {
    final days = TransferWindowCalendar.daysBetween(before, after);
    _advanceIncomingCounters(after);
    final talks = _save!.transferTalks;
    if (talks.isEmpty) return;
    final ctx = Tr.pick('移籍', 'Transfer');
    if (!TransferWindowCalendar.isOpen(after, currentLeagueTheme)) {
      final open = talks.where((t) => t.isOpen && !t.freeAgent).length;
      talks.removeWhere((t) => !t.freeAgent);
      if (open > 0) {
        _logNews(
            Tr.pick('移籍の窓が閉じ、まとまらなかった交渉$open件は流れた。',
                'The window has shut. $open unfinished negotiation(s) fell through.'),
            context: ctx);
      }
    }
    for (final t in [...talks]) {
      if (t.freeAgent) {
        // フリーエージェントとの話は、期限か、選手がいなくなったら消える。
        final gone = !_save!.freeAgents.any((p) => p.id == t.playerId);
        if (gone || (t.deadline != null && t.deadline!.isBefore(after))) {
          talks.remove(t);
          continue;
        }
        _advanceRival(t, after, days);
        continue;
      }
      final player = talkPlayer(t.playerId);
      final stillThere = player != null &&
          (t.clubId.isEmpty || _sellingClubOf(t.playerId)?.id == t.clubId);
      if (!stillThere) {
        talks.remove(t);
        if (t.isOpen) {
          _logNews(
              Tr.pick('${t.playerName}が${t.clubName}を離れたため、交渉は流れた。',
                  '${t.playerName} has left ${t.clubName}, so the talks are off.'),
              context: ctx);
        }
        continue;
      }
      if (t.stage == TransferTalkStage.agreed &&
          t.deadline != null &&
          t.deadline!.isBefore(after)) {
        talks.remove(t);
        _logNews(
            Tr.pick('${t.playerName}の合意は、期限までに選手と契約しなかったので流れた。',
                'The deal for ${t.playerName} lapsed because you did not complete it in time.'),
            context: ctx);
        continue;
      }
      if (_advanceRival(t, after, days)) continue;
      if (t.stage != TransferTalkStage.waiting ||
          t.replyOn == null ||
          t.replyOn!.isAfter(after)) {
        continue;
      }
      final r = TransferTalkEngine.reply(
        asking: askingPriceFor(player),
        bid: t.bid,
        installments: t.installments,
        round: t.round,
        roll: GameState._transferOfferRng.nextDouble(),
      );
      t.replyOn = null;
      switch (r.kind) {
        case TalkReplyKind.agree:
          t
            ..stage = TransferTalkStage.agreed
            ..fee = r.fee
            ..sellOnPercent = r.sellOnPercent
            ..installmentsOk = r.installmentsOk
            ..deadline = after
                .add(const Duration(days: TransferTalkEngine.agreementDays));
          _logNews(
              Tr.pick('${t.clubName}が${t.playerName}の移籍に${formatMoney(r.fee)}で合意した。${TransferWindowCalendar.formatMonthDay(t.deadline!)}までに決めてください。',
                  '${t.clubName} accepted ${formatMoney(r.fee)} for ${t.playerName}. Complete it by ${TransferWindowCalendar.formatMonthDay(t.deadline!)}.'),
              context: ctx);
        case TalkReplyKind.counter:
          t
            ..stage = TransferTalkStage.countered
            ..fee = r.fee
            ..sellOnPercent = r.sellOnPercent
            ..installmentsOk = r.installmentsOk;
          final extra = [
            if (r.sellOnPercent > 0)
              Tr.pick('売却条項${r.sellOnPercent}%', '${r.sellOnPercent}% sell-on'),
            if (t.installments && !r.installmentsOk)
              Tr.pick('一括払い', 'paid up front'),
          ];
          _logNews(
              Tr.pick(
                  '${t.clubName}から${t.playerName}の対案: ${formatMoney(r.fee)}${extra.isEmpty ? '' : '(${extra.join('・')})'}。',
                  '${t.clubName} came back on ${t.playerName}: ${formatMoney(r.fee)}${extra.isEmpty ? '' : ' (${extra.join(', ')})'}.'),
              context: ctx);
        case TalkReplyKind.collapse:
          t.stage = TransferTalkStage.collapsed;
          _logNews(
              Tr.pick('${t.clubName}は${t.playerName}の話を打ち切った。この窓のあいだは申し込めない。',
                  '${t.clubName} broke off talks over ${t.playerName}. You cannot bid again in this window.'),
              context: ctx);
      }
    }
  }

  // ---- 他のクラブとの競合 ----

  /// 他のクラブが動き出す・選手が行き先を決める。選手が他へ行ったら true
  /// (話は消える)。
  bool _advanceRival(TransferTalk t, DateTime after, int days) {
    if (!t.isOpen) return false;
    if (!t.hasRival) {
      if (days <= 0 || !rivalsEnabled) return false;
      final player = talkPlayer(t.playerId);
      if (player == null) return false;
      final club = _sellingClubOf(t.playerId);
      final key = club != null &&
          ([...club.players]..sort((a, b) => b.overall.compareTo(a.overall)))
              .take(3)
              .any((q) => q.id == player.id);
      final daily = PlayerTermsEngine.rivalDailyChance(keyPlayer: key);
      final chance = 1 - pow(1 - daily, days);
      if (GameState._transferOfferRng.nextDouble() < chance) {
        _startRival(t, player, after);
      }
      return false;
    }
    final decides = t.rivalDecidesOn;
    if (decides == null || !decides.isBefore(after)) return false;
    final player = talkPlayer(t.playerId);
    final rival =
        _worldTeams.where((x) => x.id == t.rivalClubId).firstOrNull;
    _save!.transferTalks.remove(t);
    if (player == null || rival == null) return true;
    if (t.freeAgent) {
      _save!.freeAgents.removeWhere((p) => p.id == player.id);
    } else {
      final target = _acquisitionTarget(player.id);
      if (target == null) return true;
      _takeFromSeller(target);
    }
    player.wage = t.rivalWage;
    ContractEngine.applyTransferContract(player);
    rival.players.add(player);
    _logNews(
        Tr.pick('${player.name}は${rival.name}を選んだ(年俸${formatMoney(annualFromWeekly(t.rivalWage))})。こちらとの話は流れた。',
            '${player.name} chose ${rival.name} (${formatMoney(annualFromWeekly(t.rivalWage))} a year). Your talks are over.'),
        context: Tr.pick('移籍', 'Transfer'));
    return true;
  }

  /// 他のクラブが[player]を狙い始める。同じかそれより上の部のクラブから選ぶ。
  void _startRival(TransferTalk t, Player player, DateTime after) {
    final seller = _sellingClubOf(player.id);
    final sellerTier =
        seller == null ? _save!.currentDivisionTier : (_tierOfClub(seller.id) ?? 1);
    final candidates = [
      for (final c in _worldTeams)
        if (c.id != _save!.userTeamId &&
            c.id != seller?.id &&
            c.players.length < maxSquadSize &&
            (_tierOfClub(c.id) ?? 99) <= sellerTier)
          c,
    ];
    if (candidates.isEmpty) return;
    // 競うオーナーのクラブが、まず横取りしに来る。
    final rival = _rivalOwnerClubFor(
            sellerTier, seller?.id, GameState._transferOfferRng) ??
        candidates[GameState._transferOfferRng.nextInt(candidates.length)];
    final rivalTier = _tierOfClub(rival.id) ?? sellerTier;
    final base = PlayerTermsEngine.demand(
      currentWage: player.wage,
      marketValue: player.marketValue,
      fromTier: t.freeAgent ? null : sellerTier,
      toTier: rivalTier,
      wasStarter: false,
      wouldStart: true,
    );
    t
      ..rivalClubId = rival.id
      ..rivalClubName = rival.name
      ..rivalWage =
          (base * (1 + GameState._transferOfferRng.nextDouble() * 0.15)).round()
      ..rivalDecidesOn = after
          .add(const Duration(days: PlayerTermsEngine.rivalDecisionDays));
    _logNews(
        Tr.pick(
            '${rival.name}も${player.name}の獲得に動いている。${TransferWindowCalendar.formatMonthDay(t.rivalDecidesOn!)}ごろまでに契約しないと、あちらへ行く。',
            '${rival.name} are after ${player.name} too. Sign him by about ${TransferWindowCalendar.formatMonthDay(t.rivalDecidesOn!)} or he goes there.'),
        context: Tr.pick('移籍', 'Transfer'));
  }

  /// テスト用: [playerId]との話に、他のクラブを今すぐ入らせる。
  @visibleForTesting
  void debugStartRival(String playerId) {
    final t = talkFor(playerId);
    final p = talkPlayer(playerId);
    if (t == null || p == null) return;
    _startRival(t, p, today);
  }

  // ---- 売る側: 来たオファーに対案を返す ----

  /// 来たオファーに対案を返せるか(窓が開いていて、条項による成立でなく、
  /// まだ返事待ちでも最終の額でもない)。
  bool canCounterIncomingOffer(IncomingOffer o) =>
      isTransferWindowOpen &&
      !o.viaReleaseClause &&
      !o.isFinal &&
      o.askedAmount == null;

  /// 来たオファーに、[amount](今の額より高い)を求める。返事は数日後。
  Future<bool> counterIncomingOffer(String offerId, int amount) async {
    if (_save == null) return false;
    final o = _save!.incomingOffers.where((x) => x.id == offerId).firstOrNull;
    if (o == null || !canCounterIncomingOffer(o) || amount <= o.amount) {
      return false;
    }
    o
      ..askedAmount = amount
      ..replyOn =
          today.add(const Duration(days: TransferTalkEngine.replyDays));
    _logNews(
        Tr.pick('${o.buyerClubName}に、${o.playerName}の移籍金として${formatMoney(amount)}を求めた。',
            'Asked ${o.buyerClubName} for ${formatMoney(amount)} for ${o.playerName}.'),
        context: Tr.pick('移籍', 'Transfer'));
    _notify();
    await _persist();
    return true;
  }

  void _advanceIncomingCounters(DateTime after) {
    final ctx = Tr.pick('移籍', 'Transfer');
    for (final o in [..._save!.incomingOffers]) {
      final asked = o.askedAmount;
      if (asked == null || o.replyOn == null || o.replyOn!.isAfter(after)) {
        continue;
      }
      final limit = TransferTalkEngine.buyerLimit(o.id, o.amount);
      o
        ..askedAmount = null
        ..replyOn = null
        ..isFinal = true;
      if (asked <= limit) {
        o.amount = asked;
        _logNews(
            Tr.pick('${o.buyerClubName}は${o.playerName}に${formatMoney(asked)}を出すと返してきた。',
                '${o.buyerClubName} agreed to pay ${formatMoney(asked)} for ${o.playerName}.'),
            context: ctx);
      } else if (asked > limit * TransferTalkEngine.buyerWalkAwayRatio) {
        _save!.incomingOffers.remove(o);
        _logNews(
            Tr.pick('${o.buyerClubName}は${o.playerName}の話を打ち切った。',
                '${o.buyerClubName} walked away from the deal for ${o.playerName}.'),
            context: ctx);
      } else {
        o.amount = limit;
        _logNews(
            Tr.pick('${o.buyerClubName}は${o.playerName}に${formatMoney(limit)}が上限だと返してきた。',
                '${o.buyerClubName} say ${formatMoney(limit)} is as high as they go for ${o.playerName}.'),
            context: ctx);
      }
    }
  }
}
