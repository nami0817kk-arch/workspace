part of 'game_state.dart';

/// 大事な場面(画面いっぱいの1枚)。同じ場面は二度出さない。
extension GameStateMoments on GameState {
  /// これより安い獲得・売却は「史上最高額」として見せない(5部の物差し)。
  static const int recordMinimum = 300;

  /// 次に見せる場面(無ければ null)。[種類, 小見出し, 説明]。
  List<String>? get nextMoment {
    final m = _save?.pendingMoments;
    return (m == null || m.isEmpty) ? null : m.first;
  }

  /// 見せ終えた場面を消す。
  Future<void> dismissMoment() async {
    final s = _save;
    if (s == null || s.pendingMoments.isEmpty) return;
    s.pendingMoments.removeAt(0);
    _notify();
    await _persist();
  }

  void _queueMoment(BigMomentKind kind, String key, String tag, String body) {
    final s = _save!;
    if (s.momentKeys.contains(key)) return;
    s.momentKeys.add(key);
    // 印は古いものから捨てる(季ごとに数件しか増えない)。
    if (s.momentKeys.length > 200) s.momentKeys.removeAt(0);
    s.pendingMoments.add([kind.name, tag, body]);
  }

  /// リーグ戦の節のあと: 優勝・昇格・降格が数字の上で決まったか。
  void _checkClinchMoments(int matchday) {
    final s = _save!;
    final league = s.league;
    final userId = s.userTeamId;
    final tier = s.currentDivisionTier;
    final rows = [
      for (final r in league.sortedStandings)
        (
          r.teamId,
          r.points,
          league.fixtures
              .where((f) =>
                  f.result == null &&
                  (f.homeTeamId == r.teamId || f.awayTeamId == r.teamId))
              .length,
        ),
    ];
    final tag = Tr.pick('第$matchday節・$tier部', 'Matchday $matchday, tier $tier');
    final season = league.season;
    final theme = currentLeagueTheme;
    if (ClinchEngine.clinchedTop(rows, userId, 1)) {
      _queueMoment(BigMomentKind.champion, 's$season:champion', tag,
          Tr.pick('$tier部の優勝が決まった。', 'The tier $tier title is ours.'));
    }
    if (tier > 1) {
      final up = theme.rulesBelow(tier - 1).autoUp;
      if (ClinchEngine.clinchedTop(rows, userId, up)) {
        _queueMoment(BigMomentKind.promoted, 's$season:promoted', tag,
            Tr.pick('${tier - 1}部への昇格が決まった(上位$upクラブが自動昇格)。',
                'Promotion to tier ${tier - 1} is sealed (top $up go up).'));
      }
    }
    if (tier < totalDivisionTiers) {
      final down = theme.rulesBelow(tier).autoDown;
      if (ClinchEngine.doomedBottom(rows, userId, down)) {
        _queueMoment(BigMomentKind.relegated, 's$season:relegated', tag,
            Tr.pick('${tier + 1}部への降格が決まった。ここからが建て直しだ。',
                'Relegation to tier ${tier + 1} is confirmed. The rebuild starts here.'));
      }
    }
  }

  /// カップの決勝を戦い終えたか(国内カップ・リーグカップ)。
  void _checkCupFinalMoments() {
    final s = _save!;
    final userId = s.userTeamId;
    for (final cup in s.cups) {
      if (!cup.isComplete) continue;
      final f = cup.rounds.last.first;
      if (f.homeTeamId != userId && f.awayTeamId != userId) continue;
      final won = cup.championId == userId;
      _queueMoment(
          won ? BigMomentKind.cupWon : BigMomentKind.cupLost,
          's${s.league.season}:cup:${cup.name}',
          cup.name,
          won
              ? Tr.pick('${cup.name}を制した。', 'We won the ${cup.name}.')
              : Tr.pick('${cup.name}の決勝で敗れた。あと一歩だった。',
                  'Beaten in the ${cup.name} final. So close.'));
    }
  }

  /// 獲得の額が、クラブ史上最高額か。
  void _checkRecordSigning(Player p, int fee) {
    final s = _save!;
    if (fee < scaledMoney(recordMinimum) || fee <= s.recordSigningFee) return;
    s.recordSigningFee = fee;
    _queueMoment(
        BigMomentKind.recordSigning,
        'sign:${p.id}:$fee',
        p.name,
        Tr.pick('${p.name}を${formatMoney(fee)}で獲得。クラブの歴史でいちばん高い移籍金だ。',
            'Signed ${p.name} for ${formatMoney(fee)}, the biggest fee in club history.'));
  }

  /// 売却の額が、クラブ史上最高額か。
  void _checkRecordSale(Player p, int fee) {
    final s = _save!;
    if (fee < scaledMoney(recordMinimum) || fee <= s.recordSaleFee) return;
    s.recordSaleFee = fee;
    _queueMoment(
        BigMomentKind.recordSale,
        'sale:${p.id}:$fee',
        p.name,
        Tr.pick('${p.name}を${formatMoney(fee)}で売った。クラブの歴史でいちばん高い売却だ。',
            'Sold ${p.name} for ${formatMoney(fee)}, a club record sale.'));
  }

  /// テスト用。
  @visibleForTesting
  void debugCheckClinch(int matchday) => _checkClinchMoments(matchday);
  @visibleForTesting
  void debugCheckRecordSigning(Player p, int fee) => _checkRecordSigning(p, fee);
}
