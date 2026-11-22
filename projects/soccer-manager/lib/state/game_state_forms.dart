part of 'game_state.dart';

/// 移籍の形: 買取義務付きローンと、買い戻し条項。
extension GameStateForms on GameState {
  /// 買取義務付きローンの借り賃(ふつうのローンの半分。買うのが決まっている)。
  static const double obligationLoanFeeFactor = 0.5;

  /// 買い戻し条項を付けると、売値を1割下げる代わりに、2季のあいだ売値の
  /// 1.5倍で買い戻せる。
  static const double buyBackDiscount = 0.9;
  static const double buyBackMultiple = 1.5;
  static const int buyBackSeasons = 2;

  /// ローンが満了したとき、買取義務が付いていれば完全移籍に切り替える。
  /// 切り替えたら true(選手はチームに残る)。資金が足りなくても払う(義務)。
  bool _completeObligationIfAny(Player p) {
    if (!p.loanObligation || p.loanBuyOptionFee == null) return false;
    final fee = p.loanBuyOptionFee!;
    _book(LedgerCategory.transfers, -fee);
    p.isLoan = false;
    p.loanEndDate = null;
    p.loanBuyOptionFee = null;
    p.loanObligation = false;
    p.wage = p.loanBaseWage ?? p.wage;
    p.loanFromClubId = null;
    p.loanBaseWage = null;
    // 完全移籍になった時点で、こちらとの契約を結ぶ(年齢に応じた年数。
    // 18歳未満は3年まで)。以前は元のクラブとの契約のまま残り、それが
    // 切れていると「契約なし」の選手になっていた。
    ContractEngine.applyTransferContract(p);
    _recordPlayerBook(p, fee);
    _logNews(
        Tr.pick('${p.name}のローンが満了し、買取義務により${formatMoney(fee)}で完全移籍になった。',
            '${p.name}\'s loan has ended and the obligation to buy kicked in: he is ours for ${formatMoney(fee)}.'),
        context: Tr.pick('ローン', 'Loan'));
    return true;
  }

  /// 買い戻せる選手(選手 id → [買い戻しの額, 期限の年(その年の6月30日まで)])。
  Map<String, List<int>> get buyBackClauses => _save?.buyBacks ?? const {};

  /// 来たオファーを、買い戻し条項付きで受ける(売値は1割下がる)。
  Future<bool> acceptIncomingOfferWithBuyBack(String offerId) async {
    final s = _save;
    if (s == null) return false;
    final o = s.incomingOffers.where((x) => x.id == offerId).firstOrNull;
    if (o == null || o.viaReleaseClause) return false;
    final price = (o.amount * buyBackDiscount).round();
    final original = o.amount;
    o.amount = price;
    final ok = await acceptIncomingOffer(offerId);
    if (!ok) {
      o.amount = original;
      return false;
    }
    s.buyBacks[o.playerId] = [
      (price * buyBackMultiple).round(),
      Player.contractClockYear + buyBackSeasons - 1,
    ];
    _logNews(
        Tr.pick('${o.playerName}を買い戻し条項付きで売った(${Player.contractClockYear + buyBackSeasons - 1}年6月まで、${formatMoney((price * buyBackMultiple).round())}で買い戻せる)。',
            'Sold ${o.playerName} with a buy-back clause (we can bring him back for ${formatMoney((price * buyBackMultiple).round())} until June ${Player.contractClockYear + buyBackSeasons - 1}).'),
        context: Tr.pick('移籍', 'Transfer'));
    _notify();
    await _persist();
    return true;
  }

  /// 買い戻せる選手(まだどこかのクラブにいて、期限内)。
  List<Player> get buyBackCandidates {
    final s = _save;
    if (s == null) return const [];
    final out = <Player>[];
    for (final id in s.buyBacks.keys) {
      final p = _sellingClubOf(id)?.players.where((x) => x.id == id).firstOrNull;
      if (p != null) out.add(p);
    }
    return out;
  }

  /// 買い戻し条項を使う(窓のあいだだけ)。
  Future<bool> exerciseBuyBack(String playerId) async {
    final s = _save;
    if (s == null) return false;
    lastSigningBlockReason = null;
    final c = s.buyBacks[playerId];
    if (c == null || !isTransferWindowOpen) return false;
    final target = _acquisitionTarget(playerId);
    if (target == null) return false;
    final p = target.player;
    if (!_registrationAllows(p)) return false;
    if (s.budget < c[0]) {
      lastSigningBlockReason = Tr.pick('資金が足りません。', 'You cannot afford it.');
      _notify();
      return false;
    }
    _book(LedgerCategory.transfers, -c[0]);
    _takeFromSeller(target);
    ContractEngine.applyTransferContract(p);
    userTeam.players.add(p);
    s.buyBacks.remove(playerId);
    _recordPlayerBook(p, c[0]);
    _logNews(
        Tr.pick('買い戻し条項で${p.name}を${formatMoney(c[0])}で呼び戻した。',
            'Used the buy-back clause to bring ${p.name} home for ${formatMoney(c[0])}.'),
        context: Tr.pick('移籍', 'Transfer'));
    _notify();
    await _persist();
    return true;
  }

  /// 季の始め: 期限の切れた買い戻し条項を消す。
  void _expireBuyBacks() {
    final s = _save;
    if (s == null) return;
    s.buyBacks.removeWhere((_, c) => c.length < 2 || c[1] < Player.contractClockYear);
  }
}
