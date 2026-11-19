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
    return TransferTalkEngine.askingPrice(
      marketValue: p.marketValue,
      keyPlayer: top.take(3).any((q) => q.id == p.id),
      starter: club.startingXI.contains(p.id),
      contractYearsLeft: p.contractYearsRemaining,
      age: p.age,
      potentialGap: p.potential - p.overall,
    );
  }

  /// 移籍金[bid]を提示する(新しく申し込む、または対案に出し直す)。
  /// [installments]なら分割払い(頭金3割と、残りを4週で)を求める。
  /// 申し込めなければ false(理由は[lastSigningBlockReason])。
  Future<bool> openTransferTalk(String playerId, int bid,
      {bool installments = false}) async {
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
    _notify();
    await _persist();
    return true;
  }

  bool _blockTalk(String reason) {
    lastSigningBlockReason = reason;
    _notify();
    return false;
  }

  /// 相手の対案をのむ(その条件で合意する)。
  Future<bool> acceptTalkCounter(String playerId) async {
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
    _notify();
    await _persist();
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

  /// 合意した条件で移籍を決める。払えない・登録の決まりに当たるなどで
  /// 決められなければ false(理由は[lastSigningBlockReason])。
  Future<bool> completeTransferTalk(String playerId) async {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    final t = talkFor(playerId);
    if (t == null || t.stage != TransferTalkStage.agreed) return false;
    if (!isTransferWindowOpen) {
      return _blockTalk(Tr.pick('移籍の窓が閉じています。', 'The transfer window is shut.'));
    }
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final player = target.player;
    if (!_minorRuleAllows(player)) return false;
    if (!_registrationAllows(player)) return false;
    final inst = t.installments && t.installmentsOk;
    final upfront = inst ? (t.fee * 0.3).round() : t.fee;
    final agentFee = TransferTermsEngine.agentFee(t.fee);
    if (_save!.budget < upfront + agentFee) {
      return _blockTalk(Tr.pick('資金が足りません(代理人手数料も要ります)。',
          'You cannot afford it (the agent fee comes on top).'));
    }
    if (!_wageBudgetAllowsSigning(player.wage)) return false;

    _book(LedgerCategory.transfers, -upfront);
    if (inst) {
      const weeks = 4;
      _save!.pendingInstallments.add(Installment(
        description: Tr.pick(
            '${player.name} 分割払い残金', '${player.name} instalments outstanding'),
        weeklyAmount: ((t.fee - upfront) / weeks).ceil(),
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
          context: Tr.pick('移籍', 'Transfer'));
    }
    ContractEngine.applyTransferContract(player);
    _takeFromSeller(target);
    userTeam.players.add(player);
    _save!.transferTalks.remove(t);
    if (t.fee < player.marketValue) {
      _save!.negotiationSignings++;
      _evaluateAchievements();
    }
    _logNews(
        Tr.pick('${player.name}が${t.clubName}から加入した(移籍金${formatMoney(t.fee)})。',
            '${player.name} joined from ${t.clubName} for ${formatMoney(t.fee)}.'),
        context: Tr.pick('移籍', 'Transfer'));
    _notify();
    await _persist();
    return true;
  }

  /// 日付が進んだぶん、相手の返事を受け取り、期限の切れた話を流す。
  /// 来たオファーへの対案の返事もここで受け取る。
  void _advanceTransferTalks(DateTime after) {
    if (_save == null) return;
    _advanceIncomingCounters(after);
    final talks = _save!.transferTalks;
    if (talks.isEmpty) return;
    final ctx = Tr.pick('移籍', 'Transfer');
    if (!TransferWindowCalendar.isOpen(after, currentLeagueTheme)) {
      final open = talks.where((t) => t.isOpen).length;
      talks.clear();
      if (open > 0) {
        _logNews(
            Tr.pick('移籍の窓が閉じ、まとまらなかった交渉$open件は流れた。',
                'The window has shut. $open unfinished negotiation(s) fell through.'),
            context: ctx);
      }
      return;
    }
    for (final t in [...talks]) {
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
            Tr.pick('${t.playerName}の合意は、期限までに決めなかったので流れた。',
                'The deal for ${t.playerName} lapsed because you did not complete it in time.'),
            context: ctx);
        continue;
      }
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
