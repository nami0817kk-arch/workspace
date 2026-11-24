part of 'game_state.dart';

/// 系列クラブ(2026-11-25 の第6段で FM の提携クラブに寄せた)。
///
/// 相手は1つまで。相手が弱ければこちらが親(提携費を払い、若手の貸し出し
/// 先・育成先に使い、相手の選手を優先して取れる)、強ければ子(提携費を
/// 受け取り、親の若手を安く借りられる)。中身は[AffiliateDeal]。
extension GameStateAffiliate on GameState {
  /// 以前の年会費(5部の物差しの万円)。旧セーブから移した提携の額。
  static const int annualFee = 300;

  /// 優先交渉権のある相手の選手の言い値の割引。
  static const double priceDiscount = 0.8;

  /// 育成先に貸した21歳以下の伸びの倍率。
  static const double youthDevelopmentGrowth = 1.25;

  /// 今の系列クラブ(無ければ null)。
  Team? get affiliateClub {
    final id = _save?.affiliateClubId;
    return id == null ? null : _worldTeamById(id);
  }

  /// 今の提携の中身(無ければ null)。
  AffiliateDeal? get affiliateDeal {
    final s = _save;
    if (s == null || s.affiliateClubId == null) return null;
    return s.affiliateDeal ??= AffiliateDeal.legacy(s.affiliateClubId!);
  }

  bool isAffiliateClub(String teamId) => _save?.affiliateClubId == teamId;

  /// [teamId] の選手が優先交渉権で割り引かれるか(親で、その項目があるとき)。
  bool affiliateDiscountApplies(String teamId) {
    final d = affiliateDeal;
    return d != null && d.clubId == teamId && d.weAreParent && d.firstRefusal;
  }

  /// 貸し出しを系列クラブへ出場機会付きで送るか。
  bool get affiliateTakesLoans {
    final d = affiliateDeal;
    return d != null && d.weAreParent && d.loanPriority && affiliateClub != null;
  }

  /// [teamId] のいる部(わからなければ null)。
  int? affiliateTierOf(String teamId) => _tierOfClub(teamId);

  /// 提携できるクラブ: こちらより弱いクラブ(こちらが親)を力の近い順に
  /// [n]件と、強いクラブ(こちらが子)を近い順に[stronger]件。
  List<Team> affiliateCandidates({int n = 6, int stronger = 3}) {
    final s = _save;
    if (s == null) return const [];
    final mine = userTeam.overallRating;
    final rival = s.rivalTeamId;
    bool ok(Team t) =>
        t.id != s.userTeamId && t.id != rival && t.players.isNotEmpty;
    final weaker = [
      for (final t in _worldTeams)
        if (ok(t) && t.overallRating < mine) t,
    ]..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final higher = [
      for (final t in _worldTeams)
        if (ok(t) && t.overallRating > mine) t,
    ]..sort((a, b) => a.overallRating.compareTo(b.overallRating));
    return [...weaker.take(n), ...higher.take(stronger)];
  }

  /// [t] と結ぶとき、こちらが親になるか(相手が弱い)。
  bool weAreParentWith(Team t) => t.overallRating < userTeam.overallRating;

  /// [t] と、この中身で結ぶときの1季の提携費(5部の物差しの万円)。
  int affiliateFeeFor(Team t,
          {required bool loanPriority,
          required bool youthDevelopment,
          required bool firstRefusal,
          required int sellOnPercent}) =>
      AffiliateDeal.feeFor(
        weAreParent: weAreParentWith(t),
        gap: userTeam.overallRating - t.overallRating,
        loanPriority: loanPriority,
        youthDevelopment: youthDevelopment && weAreParentWith(t),
        firstRefusal: firstRefusal && weAreParentWith(t),
        sellOnPercent: sellOnPercent,
      );

  /// 系列クラブと提携する(以前の決まりのまま。テストと旧い入口用)。
  Future<bool> setAffiliateClub(String teamId) => signAffiliate(teamId,
      years: 1,
      loanPriority: true,
      youthDevelopment: false,
      firstRefusal: true,
      sellOnPercent: 0);

  /// 系列クラブと[years]年の提携を結ぶ(すでにあれば付け替える)。親なら
  /// 1季目の提携費をすぐ払い、子なら受け取る。
  Future<bool> signAffiliate(
    String teamId, {
    required int years,
    required bool loanPriority,
    required bool youthDevelopment,
    required bool firstRefusal,
    required int sellOnPercent,
  }) async {
    final s = _save;
    if (s == null || s.affiliateClubId == teamId) return false;
    final team = affiliateCandidates(n: 999, stronger: 999)
        .where((t) => t.id == teamId)
        .firstOrNull;
    if (team == null) return false;
    final parent = weAreParentWith(team);
    final baseFee = affiliateFeeFor(team,
        loanPriority: loanPriority,
        youthDevelopment: youthDevelopment,
        firstRefusal: firstRefusal,
        sellOnPercent: sellOnPercent);
    final fee = scaledMoney(baseFee);
    if (parent && s.budget < fee) return false;
    s.affiliateClubId = teamId;
    s.affiliateDeal = AffiliateDeal(
      clubId: teamId,
      weAreParent: parent,
      untilSeason: s.league.season + years.clamp(1, 3) - 1,
      annualFee: baseFee,
      loanPriority: loanPriority,
      youthDevelopment: youthDevelopment && parent,
      firstRefusal: firstRefusal && parent,
      sellOnPercent: sellOnPercent,
    );
    _book(LedgerCategory.facilities, parent ? -fee : fee);
    _logNews(
        parent
            ? Tr.pick(
                '${team.name}を系列クラブにした(こちらが親・$years年・提携費 毎季${formatMoney(fee)})。',
                'Made ${team.name} our feeder club (we are the parent, ${Tr.plural(years, 'year')}, ${formatMoney(fee)} a season).')
            : Tr.pick(
                '${team.name}の系列クラブになった(相手が親・$years年・提携費 毎季${formatMoney(fee)}を受け取る)。',
                'We became a feeder club of ${team.name} (they are the parent, ${Tr.plural(years, 'year')}, we receive ${formatMoney(fee)} a season).'),
        context: Tr.pick('系列クラブ', 'Affiliate'));
    _notify();
    await _persist();
    return true;
  }

  /// 提携をやめる。
  Future<bool> endAffiliate() async {
    final s = _save;
    if (s == null || s.affiliateClubId == null) return false;
    s.affiliateClubId = null;
    s.affiliateDeal = null;
    _notify();
    await _persist();
    return true;
  }

  /// こちらが子で、選手を売ったとき: 親へ取り分を渡す。
  void _payAffiliateSellOn(Player player, int salePrice) {
    final d = affiliateDeal;
    if (d == null || d.weAreParent || d.sellOnPercent <= 0) return;
    final cut = (salePrice * d.sellOnPercent / 100).round();
    if (cut <= 0) return;
    _book(LedgerCategory.playerSales, -cut);
    _logNews(
        Tr.pick(
            '${player.name}の売却額から、親クラブの${affiliateClub?.name ?? '-'}へ取り分${d.sellOnPercent}%(${formatMoney(cut)})を渡した。',
            '${affiliateClub?.name ?? '-'}, our parent club, took their ${d.sellOnPercent}% (${formatMoney(cut)}) of the ${player.name} fee.'),
        context: Tr.pick('系列クラブ', 'Affiliate'));
  }

  /// こちらが親で、系列クラブが他クラブへ選手を売ったとき: 取り分が入る。
  void _receiveAffiliateSellOn(AiTransferMove m) {
    final d = affiliateDeal;
    if (d == null || !d.weAreParent || d.sellOnPercent <= 0) return;
    if (m.from.id != d.clubId) return;
    final cut = (m.fee * d.sellOnPercent / 100).round();
    if (cut <= 0) return;
    _book(LedgerCategory.playerSales, cut);
    _logNews(
        Tr.pick(
            '系列クラブの${m.from.name}が${m.player.name}を${m.to.name}へ売り、取り分${d.sellOnPercent}%(${formatMoney(cut)})が入った。',
            'Our feeder club ${m.from.name} sold ${m.player.name} to ${m.to.name}; our ${d.sellOnPercent}% share came to ${formatMoney(cut)}.'),
        context: Tr.pick('系列クラブ', 'Affiliate'));
  }

  /// テスト用: 季の切り替えの提携費の処理。
  @visibleForTesting
  void debugRollAffiliate() => _rollAffiliate();

  /// 季の切り替え: 提携費を払う(子なら受け取る)。期間が終われば切れる。
  /// 親で払えなければ切れる。
  void _rollAffiliate() {
    final s = _save!;
    if (s.affiliateClubId == null) return;
    final d = affiliateDeal!;
    if (affiliateClub == null) {
      s.affiliateClubId = null;
      s.affiliateDeal = null;
      return;
    }
    final until = d.untilSeason;
    if (until != null && s.league.season > until) {
      final name = affiliateClub?.name ?? '-';
      s.affiliateClubId = null;
      s.affiliateDeal = null;
      _logNews(
          Tr.pick('$nameとの系列クラブの提携が期間を終えた。続けるなら結び直してください。',
              'Our affiliate deal with $name has run its course. Sign a new one to carry on.'),
          context: Tr.pick('系列クラブ', 'Affiliate'));
      return;
    }
    final fee = scaledMoney(d.annualFee);
    if (!d.weAreParent) {
      _book(LedgerCategory.facilities, fee);
      return;
    }
    if (s.budget < fee) {
      s.affiliateClubId = null;
      s.affiliateDeal = null;
      _logNews(
          Tr.pick('年会費が払えず、系列クラブとの提携が切れた。',
              'The affiliate partnership lapsed: we could not pay the fee.'),
          context: Tr.pick('系列クラブ', 'Affiliate'));
      return;
    }
    _book(LedgerCategory.facilities, -fee);
  }
}
