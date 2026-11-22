part of 'game_state.dart';

/// お金の決まり: 降格したクラブのパラシュート、選手を売ったときの連帯貢献金、
/// 獲得した選手の簿価と償却、移籍金の分割払い、財務の規則に使う数字。
extension GameStateMoneyRules on GameState {
  /// 連帯貢献金の率(%)。売った額のうち、選手を育てたクラブへ回る分。
  static const int solidarityPercent = 5;

  /// 分割払いの頭金の割合(%)。
  static const int installmentDownPercent = 30;

  /// 分割払いの年数の幅。契約の年数に合わせ、この幅に収める。
  static const int installmentMinYears = 2;
  static const int installmentMaxYears = 5;

  /// 国ごとのパラシュート(降格したクラブへの分配金)。上の部との放映権の
  /// 差に対する割合を、降格して1季目から順に並べる(2026-11-22 に実際へ
  /// 寄せた。以前はどの国も2季で、半分→4分の1)。
  ///
  /// - イングランド: 3季(55% → 45% → 20%。プレミアの形)。
  /// - スペイン・フランス: 2季。
  /// - イタリア: 1季(降格した季に一度だけ)。
  /// - ドイツ: 無い(分配は長い期間の成績で決まり、降格の補填は無い)。
  static List<double> parachuteSharesFor(LeagueTheme theme) => switch (theme) {
        LeagueTheme.england => const [0.55, 0.45, 0.2],
        LeagueTheme.spain => const [0.4, 0.2],
        LeagueTheme.france => const [0.35, 0.2],
        LeagueTheme.italy => const [0.4],
        LeagueTheme.germany => const [],
      };

  /// 今季のパラシュートの割合(上の部との放映権の差に対して)。
  double get parachuteShare {
    final left = _save?.parachuteSeasonsLeft ?? 0;
    if (left <= 0) return 0;
    final shares = parachuteSharesFor(currentLeagueTheme);
    if (shares.isEmpty) return 0;
    // 旧セーブ(どの国も2季)で残りが表より長いときは、1季目の割合から。
    final i = (shares.length - left).clamp(0, shares.length - 1);
    return shares[i];
  }

  /// パラシュートの年額(万円)。
  int get parachuteAnnual {
    final s = _save;
    if (s == null || s.parachuteFromTier <= 0) return 0;
    final theme = currentLeagueTheme;
    final diff = annualBroadcast(s.parachuteFromTier, theme) -
        annualBroadcast(s.currentDivisionTier, theme);
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
      final shares = parachuteSharesFor(currentLeagueTheme);
      if (shares.isEmpty) {
        s.parachuteFromTier = 0;
        s.parachuteSeasonsLeft = 0;
        _logNews(
            Tr.pick('この国には、降格したクラブへの分配金(パラシュート)がありません。放映権は来季から下の部の額です。',
                'This country has no parachute payments for relegated clubs. TV money drops to the lower division next season.'),
            context: Tr.pick('放映権', 'Broadcasting'));
        return;
      }
      s.parachuteFromTier = playedTier;
      s.parachuteSeasonsLeft = shares.length;
      final list = shares.map((x) => '${(x * 100).round()}%').join(' → ');
      _logNews(
          Tr.pick(
              '降格したクラブには、上の部の放映権との差の一部(パラシュート)が${shares.length}季払われる: $list。',
              'Relegated clubs receive part of the broadcast gap (a parachute payment) for ${Tr.plural(shares.length, 'season')}: $list.'),
          context: Tr.pick('放映権', 'Broadcasting'));
    }
  }

  /// 選手を売ったとき: 連帯貢献金を差し引き、簿価との差(売却益)を伝える。
  /// 自前で育てた選手(アカデミー出身)には連帯貢献金がかからない。
  /// [player]を[salePrice]で売るときの連帯貢献金(アカデミー出身なら0)。
  ///
  /// 連帯貢献金は FIFA の決まりで、国をまたぐ移籍にだけかかる
  /// ([international]が false なら0。2026-11-22 までは国内の売却にもかけていた)。
  int solidarityFor(Player player, int salePrice, {bool international = true}) =>
      salePrice <= 0 || player.academyGraduate || !international
          ? 0
          : (salePrice * solidarityPercent / 100).round();

  /// 移籍金を受け取って売るとき(来たオファー・リリース条項)に呼ぶ。
  /// 市場価値の7割で手放す「放出」には、連帯貢献金はかからない。
  /// [buyerClubName]が他の国のクラブなら国をまたぐ移籍(連帯貢献金がかかる)。
  void _onPlayerSold(Player player, int salePrice, {String? buyerClubName}) {
    final s = _save!;
    // クラブ史上最高額の売却なら、画面いっぱいの1枚で見せる。
    _checkRecordSale(player, salePrice);
    // 記者会見で「売らない」と言った季に売ると、サポーターが怒る。
    _checkBrokenRumorPromise(player);
    {
      final pay = solidarityFor(player, salePrice,
          international:
              buyerClubName != null && _isForeignClub(buyerClubName));
      if (pay > 0) {
        _book(LedgerCategory.transfers, -pay);
        _logNews(
            Tr.pick(
                '${player.name}の売却から、連帯貢献金(育てたクラブへ$solidarityPercent%)${formatMoney(pay)}を払った。',
                'Paid ${formatMoney(pay)} in solidarity contributions ($solidarityPercent% to the clubs that trained ${player.name}).'),
            context: Tr.pick('移籍', 'Transfer'));
      }
    }
    final book = bookValueOf(player.id);
    if (s.playerBook.containsKey(player.id)) {
      final gain = salePrice - book;
      _logNews(
          Tr.pick(
              '${player.name}の売却: 売値${formatMoney(salePrice)}・簿価${formatMoney(book)}・売却${gain >= 0 ? '益' : '損'}${formatMoney(gain.abs())}。',
              '${player.name} sold for ${formatMoney(salePrice)} against a book value of ${formatMoney(book)}: a ${gain >= 0 ? 'profit' : 'loss'} of ${formatMoney(gain.abs())}.'),
          context: Tr.pick('移籍', 'Transfer'));
      // 残りの簿価を、この季の費用にする(売値は売却の収入に入るので、
      // 損益には売値と簿価の差が残る)。
      _writeOffBook(player.id);
    }
  }

  /// 移籍金(資産になる支払い)を払う。資金はいま減り、損益には償却で入る。
  void _payTransferFee(int amount) {
    if (amount <= 0) return;
    _book(LedgerCategory.transferFees, -amount);
  }

  /// 獲得した選手の簿価を付ける(移籍金を契約の年数で償却する)。
  /// 分割払いなら、頭金だけでなく総額を渡す。
  /// [announce] が false なら、クラブ史上最高額の獲得の1枚は出さない
  /// (簿価だけ付ける。以前から簿価を付けていなかった獲得の道)。
  void _recordPlayerBook(Player p, int fee, {bool announce = true}) {
    if (fee <= 0) return;
    // クラブ史上最高額の獲得なら、画面いっぱいの1枚で見せる。
    if (announce) _checkRecordSigning(p, fee);
    final years = max(1, p.contractEndYear - Player.contractClockYear + 1);
    _save!.playerBook[p.id] = [fee, Player.contractClockYear, years, 0];
  }

  /// 選手の今の簿価(万円)。獲得していない選手は0。
  int bookValueOf(String playerId) {
    final b = _save?.playerBook[playerId];
    if (b == null || b.length < 3) return 0;
    if (b.length >= 4) return max(0, b[0] - b[3]);
    // 旧セーブの行: 獲得からの年数で減らす。
    final (fee, start, years) = (b[0], b[1], b[2]);
    final used = (Player.contractClockYear - start).clamp(0, years);
    return (fee * (years - used) / years).round();
  }

  /// 1年あたりの償却費(万円)。今の簿価を、契約の残りの年数で割る
  /// (契約を延ばすと、残りを新しい年数で割り直す。実際の会計と同じ)。
  int annualAmortizationOf(String playerId) {
    final b = _save?.playerBook[playerId];
    if (b == null || b.length < 3) return 0;
    if (b.length < 4) return (b[0] / max(1, b[2])).round();
    final remaining = b[0] - b[3];
    if (remaining <= 0) return 0;
    final p = _save == null
        ? null
        : userTeam.players.where((x) => x.id == playerId).firstOrNull;
    final yearsLeft = p == null
        ? 1
        : max(1, p.contractEndYear - Player.contractClockYear + 1);
    return (remaining + yearsLeft - 1) ~/ yearsLeft;
  }

  /// [playerId] の残りの簿価を、この季の費用(償却)にして帳簿から外す。
  void _writeOffBook(String playerId) {
    final b = _save!.playerBook.remove(playerId);
    if (b == null || b.length < 4) return;
    final remaining = b[0] - b[3];
    if (remaining > 0) _book(LedgerCategory.amortization, -remaining);
  }

  /// 季の締め: 移籍金の1年分を費用にする(償却)。いなくなった選手の
  /// 残りの簿価は、まとめて費用にする。資金は動かない。
  void _amortizeTransferFees() {
    final s = _save!;
    final owned = {for (final p in userTeam.players) p.id: p};
    var total = 0;
    for (final id in s.playerBook.keys.toList()) {
      final b = s.playerBook[id]!;
      final player = owned[id];
      if (player == null || player.isLoan) {
        // 売った(_onPlayerSold で外れる)のでなく、放出・満了などで
        // いなくなった選手。残りを一度に費用にする。
        if (b.length >= 4) total += max(0, b[0] - b[3]);
        s.playerBook.remove(id);
        continue;
      }
      if (b.length < 4) continue; // 旧セーブの行は払った季に費用にしてある
      final charge = annualAmortizationOf(id);
      if (charge <= 0) continue;
      b[3] += charge;
      total += charge;
    }
    if (total > 0) _book(LedgerCategory.amortization, -total);
  }

  /// いまの選手の移籍金の、1年分の償却の合計(万円)。
  int get annualSquadAmortization => _save == null
      ? 0
      : userTeam.players
          .fold<int>(0, (sum, p) => sum + annualAmortizationOf(p.id));

  /// 分割払いの年数。契約の年数に合わせ、2〜5年に収める。
  static int installmentYearsFor(int contractYears) =>
      contractYears.clamp(installmentMinYears, installmentMaxYears);

  /// 分割払いを組む。頭金は呼び出し元が払う。残り[remaining]を
  /// [contractYears]に合わせた年数で割り、季の締めに毎年同じ額を払う。
  void _addAnnualInstallment(Player player, int remaining, int contractYears) {
    if (remaining <= 0) return;
    final years = installmentYearsFor(contractYears);
    _save!.pendingInstallments.add(Installment(
      description: Tr.pick(
          '${player.name} 分割払い残金', '${player.name} instalments outstanding'),
      weeklyAmount: (remaining / years).ceil(),
      weeksRemaining: years,
      playerId: player.id,
      annual: true,
      capitalized: true,
    ));
  }

  /// 分割払いの1回分を払う。移籍金として組んだもの(新しい形)は資産の
  /// 支払い、旧セーブのものは補強費(費用)として記録する。
  void _payInstallment(Installment inst, int amount) {
    if (amount <= 0) return;
    if (inst.capitalized) {
      _payTransferFee(amount);
    } else {
      _book(LedgerCategory.transfers, -amount);
    }
  }

  /// 季の締め: 年に1回払う分割払いを払う。
  void _payAnnualInstallments() {
    final s = _save!;
    for (final inst in List<Installment>.from(s.pendingInstallments)) {
      if (!inst.annual) continue;
      _payInstallment(inst, inst.weeklyAmount);
      inst.weeksRemaining -= 1;
      if (inst.weeksRemaining <= 0) s.pendingInstallments.remove(inst);
    }
  }

  // ---- 財務の規則に使う数字 ----

  /// 1年の収入の見込み(万円)。終えた季の営業収入と、今いる部・国の
  /// 年収の目安の大きい方。
  ///
  /// 今の1節の収入から1年分を見積もると、季の初め(順位の上乗せが大きい)
  /// に実際の1.5倍ほどに膨らんだ(3部で22億の見込みに対し実際は15億)。
  /// 終えた季の数字と目安なら、昇格した直後でも新しい部の規模で見られる。
  int get projectedAnnualIncome {
    final s = _save;
    if (s == null) return 0;
    final past = s.ledgers.where((l) => l.season < s.league.season).toList()
      ..sort((a, b) => a.season.compareTo(b.season));
    final last = past.isEmpty ? 0 : past.last.operatingIncome;
    return max(
        last, typicalAnnualIncome(currentDivisionTier, currentLeagueTheme));
  }

  /// 選手の人件費(年俸の合計 + 移籍金の1年分の償却。万円/年)。
  int get annualSquadCost => _save == null
      ? 0
      : annualFromWeekly(ContractEngine.weeklyWageBill(userTeam)) +
          annualSquadAmortization;

  /// 分割払いの残りの合計(万円)。
  int get outstandingInstallments => _save == null
      ? 0
      : _save!.pendingInstallments.fold<int>(0, (s, i) => s + i.outstanding);

  /// 自己資本(万円): 資金・預金・災害基金・選手の簿価 − 融資の残り・
  /// 分割払いの残り・オーナーからの借り。
  int get clubEquity {
    final s = _save;
    if (s == null) return 0;
    final books =
        s.playerBook.keys.fold<int>(0, (t, id) => t + bookValueOf(id));
    return s.budget +
        s.reserveFund +
        totalDepositedFunds +
        books -
        outstandingLoanDebt -
        outstandingInstallments -
        s.ownerLoanBalance;
  }

  /// 流動性の指標: 手元の資金(資金・預金・基金) ÷ 1年以内に払う額
  /// (給与の4か月分・融資の返済の残り・1年以内の分割払い)。
  double get liquidityIndex {
    final s = _save;
    if (s == null) return 99;
    final assets = s.budget + s.reserveFund + totalDepositedFunds;
    final dueInstallments = s.pendingInstallments.fold<int>(
        0, (t, i) => t + (i.annual ? i.weeklyAmount : i.outstanding));
    final liabilities = annualFromWeekly(weeklyWageBill) ~/ 3 +
        outstandingLoanDebt +
        dueInstallments;
    if (liabilities <= 0) return 99;
    return assets / liabilities;
  }

  // ---- スペイン式: 上限を超えている間は、売った分の一部だけ使える ----

  /// スペイン式の選手の人件費の上限(万円/年。今の部と収入の見込みで)。
  int get squadCostLimitNow => _save == null
      ? 0
      : RulesEngine.squadCostLimit(
          projectedAnnualIncome, _save!.currentDivisionTier);

  /// 今季、上限を超えている間に売った・外した分から新加入に使える額
  /// (万円/年。[RulesEngine.trackSaleAllowance])。最後に見た人件費からの
  /// 動きまで入れた値(見るだけで保存はしない)。スペイン以外は0。
  int get squadCostSaleAllowance {
    final s = _save;
    if (s == null || ruleSet != RuleSet.spain) return 0;
    final base = s.squadCostAllowanceSeason == s.league.season
        ? s.squadCostAllowance
        : 0;
    return RulesEngine.trackSaleAllowance(
      allowance: base,
      previousCost: s.squadCostObserved,
      cost: annualSquadCost,
      limit: squadCostLimitNow,
    );
  }

  /// スペイン式で、いま新加入に使える人件費(万円/年): 上限までの空きと、
  /// 売った分から使える額の合計。規則の画面に出す。
  int get squadCostSpendable => RulesEngine.spendableSquadCost(
        limit: squadCostLimitNow,
        cost: annualSquadCost,
        allowance: squadCostSaleAllowance,
      );

  /// 人件費の動きを見て、売った分から使える額を覚える(スペインだけ)。
  /// 画面を描き直すたび([_notify])に呼ぶので、売る・取るの順に追える。
  void _observeSquadCost() {
    final s = _save;
    if (s == null || ruleSet != RuleSet.spain) return;
    if (!s.league.teams.any((t) => t.id == s.userTeamId)) return;
    final allowance = squadCostSaleAllowance;
    s.squadCostAllowance = allowance;
    s.squadCostAllowanceSeason = s.league.season;
    s.squadCostObserved = annualSquadCost;
  }

  /// テスト用: 人件費の動きを今すぐ見る([_observeSquadCost])。
  @visibleForTesting
  void debugObserveSquadCost() => _observeSquadCost();

  /// 規則の判定に渡す、いまのお金の様子。
  ClubFinanceSnapshot get financeSnapshot => ClubFinanceSnapshot(
        projectedIncome: projectedAnnualIncome,
        squadCost: annualSquadCost,
        equity: clubEquity,
        liquidity: liquidityIndex,
        debt: outstandingLoanDebt + outstandingInstallments,
        inContinental: _save?.continentalCup != null,
      );
}
