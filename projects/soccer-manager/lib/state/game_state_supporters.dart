part of 'game_state.dart';

/// サポーターの期待を動かした理由の種類(月の内訳に出す)。
enum SupporterReason {
  /// 試合の結果(月末のまとめ・ダービー・カップ・理事会の評価・季末)。
  results,

  /// チケットの値段(毎月)。
  tickets,

  /// 広報・ファン向けの取り組み(オーナー室・試合日のイベント)。
  pr,

  /// 地域活動(毎月)。
  community,

  /// 補強(主力級の獲得)。
  signings,

  /// 売却(人気の選手を売った)。
  sales,

  /// スタジアム(増築の完成)。
  stadium,

  /// 出来事・その他(事件・噂・規則違反・新しい季の底上げなど)。
  events,
}

extension SupporterReasonInfo on SupporterReason {
  /// 内訳に出す短い名前。
  String get label => switch (this) {
        SupporterReason.results => Tr.pick('結果', 'results'),
        SupporterReason.tickets => Tr.pick('チケット', 'tickets'),
        SupporterReason.pr => Tr.pick('広報', 'PR'),
        SupporterReason.community => Tr.pick('地域', 'community'),
        SupporterReason.signings => Tr.pick('補強', 'signings'),
        SupporterReason.sales => Tr.pick('売却', 'sales'),
        SupporterReason.stadium => Tr.pick('スタジアム', 'stadium'),
        SupporterReason.events => Tr.pick('出来事', 'events'),
      };
}

/// サポーターの期待の増減を1か所に集める(2026-11-23)。
///
/// 以前は約40か所で `confidence` を直接書き換えていて、何でいくつ動いた
/// のかを誰も数えられなかった。1試合ごとに勝ち +3・負け -3 で動き、
/// オーナーの手(広報 +3 など)は試合の波に埋もれ、何もしないオーナーは
/// 10回中10回、3季以内に手放していた。
///
/// - 増減はすべて [_changeSupporters] を通し、理由の種類ごとに今月の内訳へ
///   積む。月末に前の月の内訳として残し、ホームと受信箱に出す。
/// - 試合の結果は月末にまとめて -6〜+6(BoardEngine.monthlyResultDelta)。
/// - チケットの値段・地域活動は毎月、広報は月に1回打てる。
/// - 期待が [ultimatumLine] を割ると最後通告。[ultimatumDays] 日のうちに
///   戻せなければ手放す。
extension GameStateSupporters on GameState {
  /// これを割ると最後通告。
  static const int ultimatumLine = 10;

  /// 最後通告から手放すまでの日数(およそ3か月)。
  static const int ultimatumDays = 91;

  /// 月を数で表す(年×12+月-1)。
  static int monthKeyOf(DateTime d) => d.year * 12 + d.month - 1;

  /// 今日の月。
  int get currentMonthKey => monthKeyOf(today);

  /// 月の名前(「3月」「March」)。
  static String monthLabel(int key) {
    final m = key % 12 + 1;
    const en = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July', //
      'August', 'September', 'October', 'November', 'December',
    ];
    return Tr.pick('$m月', en[m - 1]);
  }

  /// サポーターの期待を [delta] だけ動かし、今月の内訳に [reason] で積む。
  /// [note] があれば、大きな増減として理由を控える(手放す画面に出す)。
  /// 実際に動いた量(0〜100 に収めた後)を返す。
  int _changeSupporters(int delta, SupporterReason reason, {String? note}) {
    final s = _save;
    if (s == null || delta == 0) return 0;
    final before = s.confidence;
    s.confidence = (before + delta).clamp(0, 100);
    final applied = s.confidence - before;
    if (applied != 0) {
      s.supporterMonth[reason.name] =
          (s.supporterMonth[reason.name] ?? 0) + applied;
      if (s.supporterMonth[reason.name] == 0) {
        s.supporterMonth.remove(reason.name);
      }
    }
    if (note != null) _noteSupporterMove(delta, note);
    _checkSupporterUltimatum();
    return applied;
  }

  /// 期待を [value] にそろえる(新しい季の底上げなど)。差を [reason] で積む。
  void _setSupportersTo(int value, SupporterReason reason, {String? note}) {
    final s = _save;
    if (s == null) return;
    _changeSupporters(value - s.confidence, reason, note: note);
  }

  /// テスト用: 理由つきで期待を動かす。
  @visibleForTesting
  int debugChangeSupporters(int delta, SupporterReason reason) =>
      _changeSupporters(delta, reason);

  // ---- 試合 ----

  /// 自クラブのリーグ戦の後: 月末のまとめのために勝点を数え、ダービーなら
  /// その場で動かす。
  void _supportersAfterLeagueMatch(MatchResult r, Fixture f) {
    final s = _save!;
    final dir = BoardEngine.confidenceDeltaForMatch(r, s.userTeamId);
    s.supporterMonthGames++;
    s.supporterMonthPoints += dir > 0 ? 3 : (dir == 0 ? 1 : 0);
    if (isRivalFixture(f)) {
      final d = BoardEngine.derbyDeltaForMatch(r, s.userTeamId);
      if (d != 0) {
        _changeSupporters(d, SupporterReason.results,
            note: d > 0
                ? Tr.pick('ダービーに勝った', 'Won the derby')
                : Tr.pick('ダービーに負けた', 'Lost the derby'));
      }
    }
  }

  // ---- 月末 ----

  /// 今日が [before] から [after] へ進んだあいだの月末ごとに、月を締める。
  void _settleSupporterMonths(DateTime before, DateTime after) {
    for (final end in MoneyCalendar.monthEndsBetween(before, after)) {
      _closeSupporterMonth(end);
    }
  }

  /// テスト用: [end] の月を締める。
  @visibleForTesting
  void debugCloseSupporterMonth(DateTime end) => _closeSupporterMonth(end);

  /// 月末の結果のまとめ(いまの順位と今月の勝点から)。
  int get monthlyResultDeltaNow {
    final s = _save;
    if (s == null) return 0;
    final rank =
        s.league.sortedStandings.indexWhere((r) => r.teamId == s.userTeamId) +
            1;
    return BoardEngine.monthlyResultDelta(
      rank: rank,
      targetRank: s.boardTargetRank,
      points: s.supporterMonthPoints,
      games: s.supporterMonthGames,
      teamCount: s.league.teams.length,
    );
  }

  /// 月を締める: 試合の結果・チケット・地域活動を反映し、内訳を前の月へ
  /// 移して、受信箱に1行出す。
  void _closeSupporterMonth(DateTime end) {
    final s = _save!;
    final games = s.supporterMonthGames;
    final result = monthlyResultDeltaNow;
    if (result != 0) _changeSupporters(result, SupporterReason.results);
    // 結果が悪い月は、広報の効き目が半分になる(負け続けているのに会見と
    // 催しだけで期待が満点に張り付いていた。2026-11-23)。
    final pr = s.supporterMonth[SupporterReason.pr.name] ?? 0;
    if (result < 0 && pr > 0) {
      _changeSupporters(-((pr + 1) ~/ 2), SupporterReason.pr);
    }
    // チケットはリーグ戦のあった月だけ(試合の無い夏に安くしても意味が無い)。
    if (games > 0) {
      final t = BoardEngine.ticketMonthlyDelta(s.ticketPricing);
      if (t != 0) _changeSupporters(t, SupporterReason.tickets);
    }
    if (s.communityLevel > 0) {
      _changeSupporters(
          BoardEngine.communityMonthlyDelta, SupporterReason.community);
    }
    final key = monthKeyOf(end);
    s.supporterLastMonth = Map.of(s.supporterMonth);
    s.supporterLastMonthKey = key;
    s.supporterMonth.clear();
    s.supporterMonthPoints = 0;
    s.supporterMonthGames = 0;
    s.supporterMonthEnds.add(s.confidence);
    while (s.supporterMonthEnds.length > 12) {
      s.supporterMonthEnds.removeAt(0);
    }
    // 月末の資金(収支の詳しい表の月ごとの推移。2026-11-25)。
    s.fundsMonthEnds.add([key, s.budget]);
    while (s.fundsMonthEnds.length > 120) {
      s.fundsMonthEnds.removeAt(0);
    }
    final line = lastMonthSupporterLine;
    if (line != null) {
      _logNews(line, context: Tr.pick('サポーター', 'Supporters'));
    }
    _checkSupporterUltimatum();
  }

  /// 前の月の増減の合計。
  int get lastMonthSupporterTotal =>
      (_save?.supporterLastMonth.values ?? const <int>[])
          .fold(0, (a, b) => a + b);

  /// 前の月の内訳(大きい順)。[理由, 増減]。
  List<(SupporterReason, int)> get lastMonthSupporterParts {
    final m = _save?.supporterLastMonth ?? const <String, int>{};
    final out = <(SupporterReason, int)>[
      for (final r in SupporterReason.values)
        if ((m[r.name] ?? 0) != 0) (r, m[r.name]!),
    ]..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
    return out;
  }

  /// 「2月の期待 +4(広報 +3、結果 -2、値上げ -1)」。前の月が無ければ null。
  String? get lastMonthSupporterLine {
    final s = _save;
    if (s == null || s.supporterLastMonthKey == 0) return null;
    final total = lastMonthSupporterTotal;
    final parts = lastMonthSupporterParts;
    final month = monthLabel(s.supporterLastMonthKey);
    String sign(int v) => v > 0 ? '+$v' : '$v';
    if (parts.isEmpty) {
      return Tr.pick('$monthのサポーターの期待 ±0(いま${s.confidence})',
          'Supporter expectation in $month: ±0 (now ${s.confidence})');
    }
    final detail = parts.map((p) => '${p.$1.label} ${sign(p.$2)}');
    return Tr.pick(
        '$monthのサポーターの期待 ${sign(total)}(${detail.join('、')})・いま${s.confidence}',
        'Supporter expectation in $month: ${sign(total)} (${detail.join(', ')}), now ${s.confidence}');
  }

  /// 今月これまでの増減の合計。
  int get thisMonthSupporterTotal =>
      (_save?.supporterMonth.values ?? const <int>[]).fold(0, (a, b) => a + b);

  /// 状況の順位の札に入れる1行。「8月の期待 +2(結果 +2)・今月 0」。
  /// 前の月が無ければ null(2026-11-25。別の札だったものを1行にした)。
  String? get supporterMonthBandLine {
    final s = _save;
    if (s == null || s.supporterLastMonthKey == 0) return null;
    String sign(int v) => v > 0 ? '+$v' : v == 0 ? '±0' : '$v';
    final month = monthLabel(s.supporterLastMonthKey);
    final parts = lastMonthSupporterParts.take(3).toList();
    final detail = parts.isEmpty
        ? ''
        : Tr.pick(
            '(${parts.map((p) => '${p.$1.label} ${sign(p.$2)}').join('、')})',
            ' (${parts.map((p) => '${p.$1.label} ${sign(p.$2)}').join(', ')})');
    final soFar = sign(thisMonthSupporterTotal);
    return Tr.pick(
        '$monthの期待 ${sign(lastMonthSupporterTotal)}$detail・今月 $soFar',
        'Fans in $month: ${sign(lastMonthSupporterTotal)}$detail • this month $soFar');
  }

  // ---- 補強と売却 ----

  /// 自クラブが [p] を獲った: 主力級(上位3人に入る)ならサポーターが沸く。
  /// [userTeam] に加える前に呼ぶ。
  void _supportersOnSigning(Player p) {
    final s = _save;
    if (s == null || p.isLoanedOut) return;
    final better =
        userTeam.players.where((q) => q.id != p.id && q.overall > p.overall);
    if (better.length >= BoardEngine.keyPlayerRank) return;
    _changeSupporters(BoardEngine.bigSigningDelta, SupporterReason.signings,
        note: Tr.pick(
            '主力級の${p.name}を獲った', 'Signed ${p.name}, a first-team star'));
  }

  /// 人気の選手を売った: 上位3人・長く在籍・生え抜きの数で -3〜-6。
  /// [p] がチームから外れた後に呼ぶ。
  void _supportersOnSale(Player p) {
    final s = _save;
    if (s == null) return;
    final better = userTeam.players
        .where((q) => q.id != p.id && q.overall > p.overall)
        .length;
    final d = BoardEngine.saleDelta(
      topPlayer: better < BoardEngine.keyPlayerRank,
      longServing: (s.clubApps[p.id] ?? 0) >= BoardEngine.longServingApps,
      academy: p.academyGraduate,
    );
    if (d == 0) return;
    _changeSupporters(d, SupporterReason.sales,
        note:
            Tr.pick('人気の${p.name}を売った', 'Sold ${p.name}, a fans\' favourite'));
  }

  /// テスト用: 獲得・売却のときのサポーターの反応だけを走らせる。
  @visibleForTesting
  void debugSupportersOnSigning(Player p) => _supportersOnSigning(p);
  @visibleForTesting
  void debugSupportersOnSale(Player p) => _supportersOnSale(p);

  // ---- 最後通告 ----

  /// 期待が [ultimatumLine] を割ったら最後通告を出し、戻ったら消す。
  void _checkSupporterUltimatum() {
    final s = _save;
    if (s == null) return;
    if (s.confidence < ultimatumLine) {
      if (s.supporterUltimatumUntil != null) return;
      // 季を終えた後は出さない(季の切り替えで最低40へ底上げされる)。
      if (s.league.isSeasonComplete) return;
      final until = SeasonCalendar.dateOnly(today)
          .add(const Duration(days: ultimatumDays));
      s.supporterUltimatumUntil = until;
      _logNews(
          Tr.pick(
              'サポーターから最後通告: 期待が$ultimatumLineを割りました(いま${s.confidence})。${CalendarEngine.formatDate(until)}までに$ultimatumLine以上へ戻せなければ、クラブを手放すことになります。',
              'Final warning from the supporters: expectation has fallen below $ultimatumLine (now ${s.confidence}). Get it back to $ultimatumLine or more by ${CalendarEngine.formatDate(until)}, or you will have to sell the club.'),
          context: Tr.pick('最後通告', 'Final warning'));
      return;
    }
    if (s.supporterUltimatumUntil != null) {
      s.supporterUltimatumUntil = null;
      _logNews(
          Tr.pick('サポーターの期待が${s.confidence}まで戻り、最後通告は取り下げられました。',
              'Supporter expectation is back to ${s.confidence}. The final warning has been lifted.'),
          context: Tr.pick('最後通告', 'Final warning'));
    }
  }

  /// 最後通告が出ているか。
  bool get isUnderSupporterUltimatum =>
      _save?.supporterUltimatumUntil != null &&
      (_save?.confidence ?? 100) < ultimatumLine;

  /// 最後通告の期限までの残り日数(出ていなければ null)。
  int? get supporterUltimatumDaysLeft {
    final until = _save?.supporterUltimatumUntil;
    if (until == null || !isUnderSupporterUltimatum) return null;
    return max(0, until.difference(SeasonCalendar.dateOnly(today)).inDays);
  }

  /// 最後通告の期限を過ぎても戻せなかった(クラブを手放す)。
  bool get supporterUltimatumExpired {
    final until = _save?.supporterUltimatumUntil;
    if (until == null || !isUnderSupporterUltimatum) return false;
    return !SeasonCalendar.dateOnly(today).isBefore(until);
  }

  /// 月末ごとの期待の推移を1行で(「推移 32 → 18 → 9」)。無ければ null。
  String? get supporterMonthTrailLine {
    final t = _save?.supporterMonthEnds;
    if (t == null || t.isEmpty) return null;
    final tail = [...t.sublist(max(0, t.length - 5)), _save!.confidence];
    return Tr.pick('月末ごとの推移 ${tail.join(' → ')}(いま)',
        'Month by month ${tail.join(' → ')} (now)');
  }

  // ---- 広報(月に1回) ----

  /// 今月すでに広報・ファン向けの手を打ったか。
  bool get fanWorkDoneThisMonth =>
      _save != null && _save!.fanWorkMonthKey == currentMonthKey;
}
