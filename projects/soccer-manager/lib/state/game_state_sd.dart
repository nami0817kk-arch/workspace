part of 'game_state.dart';

/// SD(スポーツディレクター)。補強の交渉を任せられる。
extension GameStateSd on GameState {
  /// 今の SD(いなければ null)。
  StaffMember? get currentSd =>
      _save?.infrastructure.staffFor(StaffRole.sportingDirector);

  /// SD の見極めで、相手の言い値がどれだけ下がるか(1.0 は下がらない)。
  /// 見極めの水準1つにつき1.5%、最大で約1割。オーナーが自分で交渉しても
  /// 効く(SD がクラブ同士の下話をしているため)。
  double get sdPriceFactor {
    final sd = currentSd;
    if (sd == null) return 1.0;
    return 1 - 0.015 * (sd.levelOf(StaffAttribute.judging) - 1);
  }

  SdBrief get sdBrief => _save?.sdBrief ?? SdBrief();

  /// SD への方針を変える。
  Future<void> updateSdBrief({
    bool? active,
    int? maxFee,
    Set<PositionGroup>? groups,
    int? maxAge,
    int? maxSignings,
  }) async {
    if (_save == null) return;
    final b = _save!.sdBrief;
    if (active != null) b.active = active;
    if (maxFee != null) b.maxFee = max(0, maxFee);
    if (groups != null) b.groups = {...groups};
    if (maxAge != null) b.maxAge = maxAge.clamp(17, 40);
    if (maxSignings != null) b.maxSignings = maxSignings.clamp(1, 3);
    _notify();
    await _persist();
  }

  /// SD が狙う選手(見えている選手のうち、方針に合い、今の先発より上の人)。
  /// 見立ての良い順。
  List<Player> get sdShortlist {
    if (_save == null) return const [];
    final b = _save!.sdBrief;
    final same = sameLeaguePlayerIds();
    final team = userTeam;
    int weakestStarter(PositionGroup g) {
      final xs = [
        for (final q in team.players)
          if (team.startingXI.contains(q.id) && q.position.group == g)
            q.overall,
      ];
      return xs.isEmpty ? 0 : xs.reduce(min);
    }

    final out = <(Player, int)>[];
    for (final p in proposalTargets) {
      if (b.groups.isNotEmpty && !b.groups.contains(p.position.group)) {
        continue;
      }
      if (p.age > b.maxAge || talkFor(p.id) != null) continue;
      if (askingPriceFor(p) > b.maxFee * 1.1) continue;
      final est = ScoutKnowledge.center(overallEstimate(p, sameLeagueIds: same));
      if (est <= weakestStarter(p.position.group)) continue;
      out.add((p, est));
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in out) e.$1];
  }

  /// 1日ぶん SD が動く(窓が開いていて、任されているとき)。
  void _runSportingDirector() {
    final s = _save;
    if (s == null) return;
    final b = s.sdBrief;
    final sd = currentSd;
    if (!b.active || sd == null || !isTransferWindowOpen) return;
    final ctx = Tr.pick('SD', 'SD');
    for (final t in [...s.transferTalks.where((t) => t.bySd)]) {
      switch (t.stage) {
        case TransferTalkStage.waiting:
          break;
        case TransferTalkStage.collapsed:
          s.transferTalks.remove(t);
        case TransferTalkStage.countered:
          if (t.fee <= b.maxFee) {
            if (_acceptCounterCore(t.playerId)) {
              _logNews(
                  Tr.pick('SDの${sd.name}が、${t.clubName}の対案(${formatMoney(t.fee)})をのんだ。',
                      'Your SD ${sd.name} accepted ${t.clubName}\'s terms (${formatMoney(t.fee)}).'),
                  context: ctx);
            }
          } else {
            // 上限との間で出し直す。届かなければ降りる。
            final rebid = min(b.maxFee, ((t.bid + t.fee) / 2).round());
            final ok = t.round < TransferTalkEngine.maxRounds &&
                rebid > t.bid &&
                _openTalkCore(t.playerId, rebid);
            if (!ok) {
              s.transferTalks.remove(t);
              _logNews(
                  Tr.pick('SDの${sd.name}は、${t.playerName}の値が上限を超えるので降りた。',
                      'Your SD ${sd.name} pulled out of the ${t.playerName} deal: it went past your limit.'),
                  context: ctx);
            }
          }
        case TransferTalkStage.agreed:
          final p = talkPlayer(t.playerId);
          if (p == null) {
            s.transferTalks.remove(t);
            break;
          }
          final wage = t.demandWage > 0
              ? t.demandWage
              : (max(p.wage, p.fairWeeklyWage()) * 1.1).round();
          final choices = ContractEngine.endYearChoicesNow(p.age);
          final end = choices.isEmpty
              ? Player.contractClockYear + 1
              : choices[min(2, choices.length - 1)];
          final out = _termsCore(p.id, weeklyWage: wage, endYear: end);
          switch (out) {
            case TermsOutcome.signed:
              s.sdSignedThisWindow++;
              _logNews(
                  Tr.pick('SDの${sd.name}が、${p.name}の獲得をまとめた。',
                      'Your SD ${sd.name} closed the deal for ${p.name}.'),
                  context: ctx);
            case TermsOutcome.counter:
              break; // 次の日に、望む額で出し直す。
            case TermsOutcome.refused:
            case TermsOutcome.blocked:
              final reason = lastSigningBlockReason;
              s.transferTalks.removeWhere((x) => x.playerId == p.id);
              _logNews(
                  Tr.pick('SDの${sd.name}は${p.name}の獲得をあきらめた${reason == null ? '' : '($reason)'}。',
                      'Your SD ${sd.name} gave up on ${p.name}${reason == null ? '' : ' ($reason)'}.'),
                  context: ctx);
          }
      }
    }
    // 新しく動く: SD の話が無く、この窓で取る人数が残っていれば。
    if (s.transferTalks.any((t) => t.bySd && t.isOpen)) return;
    if (s.sdSignedThisWindow >= b.maxSignings) return;
    for (final p in sdShortlist.take(5)) {
      final bid = min(b.maxFee, (askingPriceFor(p) * 0.9).round());
      if (bid <= 0) return;
      if (_openTalkCore(p.id, bid)) {
        talkFor(p.id)!.bySd = true;
        _logNews(
            Tr.pick('SDの${sd.name}が、${clubNameOf(p.id) ?? '-'}の${p.name}に動いた(${formatMoney(bid)}を提示)。',
                'Your SD ${sd.name} made a move for ${p.name} of ${clubNameOf(p.id) ?? '-'} (bid ${formatMoney(bid)}).'),
            context: ctx);
        return;
      }
    }
  }
}
