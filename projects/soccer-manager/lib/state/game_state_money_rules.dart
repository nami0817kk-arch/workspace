part of 'game_state.dart';

/// お金の決まり: 降格したクラブのパラシュート、選手を売ったときの連帯貢献金、
/// 獲得した選手の簿価と償却。
extension GameStateMoneyRules on GameState {
  /// パラシュートの期間(季)。
  static const int parachuteSeasons = 2;

  /// 連帯貢献金の率(%)。売った額のうち、選手を育てたクラブへ回る分。
  static const int solidarityPercent = 5;

  /// 降格して1季目は上の部との放映権の差の半分、2季目は4分の1。
  double get parachuteShare {
    final left = _save?.parachuteSeasonsLeft ?? 0;
    if (left >= 2) return 0.5;
    if (left == 1) return 0.25;
    return 0;
  }

  /// パラシュートの年額(万円)。
  int get parachuteAnnual {
    final s = _save;
    if (s == null || s.parachuteFromTier <= 0) return 0;
    final diff = annualBroadcast(s.parachuteFromTier) -
        annualBroadcast(s.currentDivisionTier);
    return diff <= 0 ? 0 : (diff * parachuteShare).round();
  }

  /// 季の終わり: パラシュートを1季進め、降格したら新しく付ける。昇格すれば止まる。
  void _updateParachute({required int playedTier, required int newTier}) {
    final s = _save!;
    if (s.parachuteSeasonsLeft > 0) s.parachuteSeasonsLeft--;
    if (s.parachuteSeasonsLeft == 0) s.parachuteFromTier = 0;
    if (newTier < playedTier) {
      s.parachuteSeasonsLeft = 0;
      s.parachuteFromTier = 0;
    } else if (newTier > playedTier) {
      s.parachuteFromTier = playedTier;
      s.parachuteSeasonsLeft = parachuteSeasons;
      _logNews(
          Tr.pick('降格したクラブには、上の部の放映権との差の一部(パラシュート)が2季払われる: 1季目は半分、2季目は4分の1。',
              'Relegated clubs receive part of the broadcast gap (a parachute payment) for two seasons: half in the first, a quarter in the second.'),
          context: Tr.pick('放映権', 'Broadcasting'));
    }
  }

  /// 選手を売ったとき: 連帯貢献金を差し引き、簿価との差(売却益)を伝える。
  /// 自前で育てた選手(アカデミー出身)には連帯貢献金がかからない。
  /// [player]を[salePrice]で売るときの連帯貢献金(アカデミー出身なら0)。
  int solidarityFor(Player player, int salePrice) =>
      salePrice <= 0 || player.academyGraduate
          ? 0
          : (salePrice * solidarityPercent / 100).round();

  /// 移籍金を受け取って売るとき(来たオファー・リリース条項)に呼ぶ。
  /// 市場価値の7割で手放す「放出」には、連帯貢献金はかからない。
  void _onPlayerSold(Player player, int salePrice) {
    final s = _save!;
    // 記者会見で「売らない」と言った季に売ると、サポーターが怒る。
    _checkBrokenRumorPromise(player);
    {
      final pay = solidarityFor(player, salePrice);
      if (pay > 0) {
        _book(LedgerCategory.transfers, -pay);
        _logNews(
            Tr.pick('${player.name}の売却から、連帯貢献金(育てたクラブへ$solidarityPercent%)${formatMoney(pay)}を払った。',
                'Paid ${formatMoney(pay)} in solidarity contributions ($solidarityPercent% to the clubs that trained ${player.name}).'),
            context: Tr.pick('移籍', 'Transfer'));
      }
    }
    final book = bookValueOf(player.id);
    if (s.playerBook.containsKey(player.id)) {
      final gain = salePrice - book;
      _logNews(
          Tr.pick('${player.name}の売却: 売値${formatMoney(salePrice)}・簿価${formatMoney(book)}・売却${gain >= 0 ? '益' : '損'}${formatMoney(gain.abs())}。',
              '${player.name} sold for ${formatMoney(salePrice)} against a book value of ${formatMoney(book)}: a ${gain >= 0 ? 'profit' : 'loss'} of ${formatMoney(gain.abs())}.'),
          context: Tr.pick('移籍', 'Transfer'));
      s.playerBook.remove(player.id);
    }
  }

  /// 獲得した選手の簿価を付ける(移籍金を契約の年数で償却する)。
  void _recordPlayerBook(Player p, int fee) {
    if (fee <= 0) return;
    final years = max(1, p.contractEndYear - Player.contractClockYear + 1);
    _save!.playerBook[p.id] = [fee, Player.contractClockYear, years];
  }

  /// 選手の今の簿価(万円)。獲得していない選手は0。
  int bookValueOf(String playerId) {
    final b = _save?.playerBook[playerId];
    if (b == null || b.length < 3) return 0;
    final (fee, start, years) = (b[0], b[1], b[2]);
    final used = (Player.contractClockYear - start).clamp(0, years);
    return (fee * (years - used) / years).round();
  }

  /// 1年あたりの償却費(万円)。
  int annualAmortizationOf(String playerId) {
    final b = _save?.playerBook[playerId];
    if (b == null || b.length < 3) return 0;
    return (b[0] / max(1, b[2])).round();
  }
}
