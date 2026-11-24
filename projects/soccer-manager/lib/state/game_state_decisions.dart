part of 'game_state.dart';

/// 初めて遊ぶ人がつまずく所の手当て(2026-11-23)。
///
/// - 答えを待つ決めごと(噂の記者会見・手術の判断・スポンサー)に締切を
///   付け、過ぎたら既定の答えで片付ける。放っておくと右の欄に溜まり続けた。
/// - サポーターの期待の推移を控え、下がり続けたら早めに知らせる。
/// - 季末に来る増減を、季を締める前に見せる。
///
/// サポーターの期待の増減の仕組みそのものは game_state_supporters.dart。
/// ここは見せ方と、決めごとの片付けだけ。
extension GameStateDecisions on GameState {
  /// 決めごとの締切(自クラブのリーグ戦の数)。
  static const int decisionDeadlineMatchdays = 3;

  /// 「下がり続けている」と見る、直近の節の数。
  static const int supporterTrendWindow = 5;

  /// 直近 [supporterTrendWindow] 節でこれ以上下がったら、早めに知らせる。
  static const int supporterDropAlert = 10;

  /// 手放す画面に出す、大きな増減の下限(小さな増減は数えない)。
  static const int bigSupporterMove = 5;

  // ---- 締切 ----

  /// いま答えを待っている決めごとのキー。
  List<String> get _openDecisionKeys {
    final s = _save;
    if (s == null) return const [];
    return [
      if (s.pendingRumor != null) 'rumor',
      for (final p in playersAwaitingSurgeryDecision) 'surgery:${p.id}',
      if (s.sponsorDeal == null && s.pendingSponsorOffers.isNotEmpty) 'sponsor',
    ];
  }

  /// テスト用: 自クラブのリーグ戦1つぶん、締切を数える。
  @visibleForTesting
  Future<void> debugTickDecisionDeadlines() => _tickDecisionDeadlines();

  /// 決めごと [key] が既定の答えで片付くまでの、残りの節の数。
  int decisionMatchdaysLeft(String key) {
    final age = _save?.decisionAges[key] ?? 0;
    return max(1, decisionDeadlineMatchdays - age);
  }

  /// 医療スタッフのおすすめ。長期の怪我(骨折・前十字靭帯・アキレス腱)は
  /// 再発させると長く失うので手術、靭帯の怪我は離脱を縮める保存療法。
  /// 手術の費用が払えないときは保存療法。
  bool recommendsSurgery(Player p) {
    final type = p.injuryType;
    if (type == null || !type.isLongTerm) return false;
    return (_save?.budget ?? 0) >= surgeryCost;
  }

  /// 自クラブのリーグ戦ごと: 決めごとの経過を数え、締切を過ぎたものを
  /// 既定の答えで片付ける。
  Future<void> _tickDecisionDeadlines() async {
    final s = _save;
    if (s == null) return;
    final open = _openDecisionKeys.toSet();
    s.decisionAges.removeWhere((k, _) => !open.contains(k));
    for (final key in open) {
      final age = (s.decisionAges[key] ?? 0) + 1;
      if (age < decisionDeadlineMatchdays) {
        s.decisionAges[key] = age;
        continue;
      }
      s.decisionAges.remove(key);
      final note = await _resolveByDefault(key);
      if (note != null) {
        lastAutoDecisions.add(note);
        _logNews(note, context: Tr.pick('締切', 'Deadline'));
      }
    }
  }

  /// 既定の答えで片付け、知らせる1行を返す。
  Future<String?> _resolveByDefault(String key) async {
    final s = _save!;
    if (key == 'rumor') {
      final r = s.pendingRumor;
      if (r == null) return null;
      // 何も言わないのが、いちばん波風の立たない答え。
      final saved = List<String>.of(r);
      // answerRumor は保存と通知もするが、節の処理の途中なので構わない。
      await answerRumor(RumorAnswer.noComment);
      return Tr.pick('${saved[1]}の噂は、答えないまま締切を過ぎたので「コメントしない」にしました。',
          'The ${saved[1]} rumour went unanswered, so the club gave no comment.');
    }
    if (key == 'sponsor') {
      final offers = s.pendingSponsorOffers;
      if (s.sponsorDeal != null || offers.isEmpty) return null;
      // 未契約のままだと週の収入を取りこぼし続ける。週の収入がいちばん多い
      // 話を結ぶ(同じなら年数の長いほう)。取り下げると、すぐ次の話が
      // 来るだけなので、結ぶほうが自然。
      var best = 0;
      for (var i = 1; i < offers.length; i++) {
        final a = offers[i], b = offers[best];
        if (a.weeklyIncome > b.weeklyIncome ||
            (a.weeklyIncome == b.weeklyIncome &&
                a.yearsRemaining > b.yearsRemaining)) {
          best = i;
        }
      }
      final deal = offers[best];
      await chooseSponsor(best);
      return Tr.pick(
          'スポンサーを選ばないまま締切を過ぎたので、収入がいちばん多い${deal.name}(年${formatMoney(deal.weeklyIncome * matchdaysPerSeason)}・${deal.yearsRemaining}年)と結びました。',
          'No sponsor was chosen in time, so the club signed the best-paying offer: ${deal.name} (${formatMoney(deal.weeklyIncome * matchdaysPerSeason)} a year for ${Tr.plural(deal.yearsRemaining, 'year')}).');
    }
    if (key.startsWith('surgery:')) {
      final id = key.substring('surgery:'.length);
      final p = userTeam.players.where((x) => x.id == id).firstOrNull;
      if (p == null || s.injuryPlans[id] != 'pending') return null;
      final surgery = recommendsSurgery(p);
      await decideSurgery(id, surgery: surgery);
      return surgery
          ? Tr.pick(
              '${p.name}の治療は締切を過ぎたので、医療スタッフのおすすめどおり手術にしました(長い怪我の再発を防ぐため)。',
              "${p.name}'s treatment was not decided in time, so the medical staff went with their advice: surgery, to avoid a setback on a long injury.")
          : Tr.pick('${p.name}の治療は締切を過ぎたので、医療スタッフのおすすめどおり保存療法にしました(離脱を縮めるため)。',
              "${p.name}'s treatment was not decided in time, so the medical staff went with their advice: rest, to get him back sooner.");
    }
    return null;
  }

  /// 答えを待っている決めごとの数(右の欄の見出し)。
  int get openDecisionCount =>
      inboxActions.length + (_save?.pendingBoardReviewMessage != null ? 1 : 0);

  // ---- サポーターの期待の推移 ----

  /// クラブを買い直したとき: 前のクラブの推移と決めごとを持ち越さない。
  void _resetSupporterRecords() {
    final s = _save;
    if (s == null) return;
    s.supporterTrail
      ..clear()
      ..add(s.confidence);
    s.supporterMoves.clear();
    s.decisionAges.clear();
    // 月の内訳と最後通告も、前のクラブのものは持ち越さない。
    s.supporterMonth.clear();
    s.supporterLastMonth.clear();
    s.supporterLastMonthKey = 0;
    s.supporterMonthEnds.clear();
    s.supporterMonthPoints = 0;
    s.supporterMonthGames = 0;
    s.fanWorkMonthKey = 0;
    s.supporterUltimatumUntil = null;
  }

  /// 自クラブのリーグ戦の後に、いまの期待を控える。
  void _recordSupporterTrail() {
    final s = _save;
    if (s == null) return;
    s.supporterTrail.add(s.confidence);
    // 1季の節より長くは持たない。
    if (s.supporterTrail.length > 60) s.supporterTrail.removeAt(0);
  }

  /// 大きな増減を理由つきで控える(手放す画面で見せる)。
  void _noteSupporterMove(int delta, String reason) {
    final s = _save;
    if (s == null || delta.abs() < bigSupporterMove) return;
    s.supporterMoves.add(['$delta', reason]);
    if (s.supporterMoves.length > 8) s.supporterMoves.removeAt(0);
  }

  /// 直近 [supporterTrendWindow] 節での期待の増減。控えが2つ未満なら null。
  int? get supporterTrend {
    final t = _save?.supporterTrail;
    if (t == null || t.length < 2) return null;
    final from = t[max(0, t.length - 1 - supporterTrendWindow)];
    return t.last - from;
  }

  /// 期待が下がり続けているか(直近5節で -10 以上)。
  bool get supporterFalling {
    final trend = supporterTrend;
    return trend != null && trend <= -supporterDropAlert;
  }

  /// 直近の大きな増減(新しい順、最大 [n] 件)。[増減, 理由]。
  List<(int, String)> recentSupporterMoves([int n = 3]) {
    final moves = _save?.supporterMoves ?? const <List<String>>[];
    return [
      for (final m in moves.reversed.take(n))
        (int.tryParse(m[0]) ?? 0, m.length > 1 ? m[1] : ''),
    ];
  }

  /// 期待の推移を1行で(「直近の推移 52 → 46 → 40」)。控えが無ければ null。
  String? get supporterTrailLine {
    final t = _save?.supporterTrail;
    if (t == null || t.length < 2) return null;
    final tail = t.sublist(max(0, t.length - 6));
    return Tr.pick(
        '直近の推移 ${tail.join(' → ')}', 'Recent trend ${tail.join(' → ')}');
  }

  /// 開幕前か(自クラブのリーグ戦がまだ1つも終わっていない)。順位は
  /// 全クラブ勝点0で並ぶだけなので、「1位」と出さない。
  bool get isPreseason {
    final s = _save;
    if (s == null) return false;
    final id = s.userTeamId;
    return !s.league.fixtures.any(
        (f) => f.result != null && (f.homeTeamId == id || f.awayTeamId == id));
  }

  /// オフシーズンか。季の終わり(自クラブのリーグ戦の最終節のあと)から、
  /// 次の季の開幕前(自クラブのリーグ戦がまだ1つも終わっていない)まで。
  ///
  /// 予算の配り方・クラブの見た目・チケットの値段・クラブの方針は、この間
  /// だけ変えられる(2026-11-25)。シーズン中は「今季: ○○」と見せるだけ。
  bool get isOffseason {
    final s = _save;
    if (s == null) return false;
    if (isPreseason) return true;
    final id = s.userTeamId;
    final mine = s.league.fixtures
        .where((f) => f.homeTeamId == id || f.awayTeamId == id);
    return mine.isNotEmpty && mine.every((f) => f.result != null);
  }

  /// 開幕前の海外ツアーに出るかを、まだ決めていないか(開幕前で未決)。
  /// 状況の札と「やること」の一覧が同じ判定を使う。
  bool get preseasonTourPending {
    final s = _save;
    if (s == null || !s.preseasonCampPending) return false;
    return s.league.fixtures.every((f) => f.result == null);
  }

  // ---- 季末の見通し ----

  /// 季を締めたときのサポーターの期待の増減(順位による分だけ)。季の
  /// 途中でも、いまの順位のまま終わった場合として出せる。
  int get seasonEndSupporterDelta {
    final s = _save;
    if (s == null) return 0;
    final rank =
        s.league.sortedStandings.indexWhere((r) => r.teamId == s.userTeamId) +
            1;
    return BoardEngine.confidenceDeltaForSeasonEnd(
        finalRank: rank, targetRank: s.boardTargetRank);
  }

  /// 「シーズン終了！」の札に出す、季末に来る増減の説明。
  String get seasonEndPreviewLine {
    final s = _save!;
    final delta = seasonEndSupporterDelta;
    final sign = delta > 0 ? '+$delta' : '$delta';
    final floor = BoardEngine.newSeasonConfidenceFloor;
    final after = (s.confidence + delta).clamp(0, 100);
    // 最後通告の期限を過ぎて手放すことが決まっていれば、底上げは無い。
    // 季末に最後通告の線を割っていれば、底上げせず、新しい季の初日に
    // 最後通告が出る(2026-11-23)。
    final line = GameStateSupporters.ultimatumLine;
    // すでに最後通告が出ていれば、新しく出るのではなく、その期限のまま
    // 続く(以前は「新しい季の初日に最後通告が出ます」と出ていた。
    // 2026-11-23)。
    final until = s.supporterUltimatumUntil;
    var floorNote = '';
    if (supporterUltimatumExpired) {
      floorNote = '';
    } else if (after < line && until != null) {
      floorNote = Tr.pick(
          '最後通告は季をまたいでも続きます。${CalendarEngine.formatDate(until)}までに$line以上へ戻せなければ、クラブを手放します。',
          'The final warning carries over into the new season. Get back to $line or more by ${CalendarEngine.formatDate(until)}, or you will have to sell the club.');
    } else if (after < line) {
      floorNote = Tr.pick('$lineを割ったまま季を終えると、新しい季の初日に最後通告が出ます。',
          'Finish the season below $line and the supporters will issue a final warning on day one of the new season.');
    } else if (after < floor) {
      floorNote = Tr.pick(
          '新しい季は最低$floorから始まります。', 'The new season starts from at least $floor.');
    }
    return Tr.pick(
        'この順位なら、サポーターの期待 $sign(目標${s.boardTargetRank}位以内)。$floorNote',
        'This finish means supporter expectation $sign (target: ${Tr.topTarget(s.boardTargetRank)}). $floorNote');
  }

  /// 終えた季の、自クラブの結果のまとめ(シーズン開始レポートの先頭)。
  /// 以前は昇格・報奨金などの出来事しか出ず、自分が何位で終わり、期待が
  /// どう動いたのかが分からなかった。
  List<String> _seasonResultLines({
    required int season,
    required int finalRank,
    required int teamCount,
    required int targetRank,
    required int playedTier,
    required int newTier,
    required int supporterBefore,
    required int supporterAfter,
    required int supporterNow,
    required int shareholderBefore,
    required int cashChange,
    required int rolloverWages,
  }) {
    final s = _save!;
    final met = finalRank <= targetRank;
    final floorNote = supporterNow > supporterAfter
        ? Tr.pick('(新しい季は$supporterNowから)',
            ' (the new season starts at $supporterNow)')
        : '';
    return [
      Tr.pick(
          '第$season季の結果: $finalRank位/$teamCountクラブ(目標$targetRank位以内・${met ? '達成' : '未達'})',
          'Season $season: finished ${Tr.ordinal(finalRank)} of $teamCount (target: ${Tr.topTarget(targetRank)},${met ? 'met' : 'missed'})'),
      Tr.pick('サポーターの期待 $supporterBefore→$supporterAfter$floorNote',
          'Supporter expectation $supporterBefore→$supporterAfter$floorNote'),
      Tr.pick('株主の期待 $shareholderBefore→${s.shareholderExpectation}',
          'Shareholder expectation $shareholderBefore→${s.shareholderExpectation}'),
      Tr.pick(
          '1年の資金の増減 ${formatMoneySigned(cashChange)}(いまの資金 ${formatMoney(s.budget)})',
          'Funds over the year ${formatMoneySigned(cashChange)} (now ${formatMoney(s.budget)})'),
      if (rolloverWages > 0)
        Tr.pick('季の切り替えまで(〜6月分)の給与 ${formatMoneySigned(-rolloverWages)}',
            'Wages up to the end of June ${formatMoneySigned(-rolloverWages)}'),
      Tr.pick('来季: $newTier部・目標${s.boardTargetRank}位以内',
          'Next season: Tier $newTier, target: ${Tr.topTarget(s.boardTargetRank)}'),
      // 一番下の部は降格が無い。最下位で「落ちるのか」と心配させない。
      if (playedTier == totalDivisionTiers &&
          newTier == playedTier &&
          finalRank > teamCount - 3)
        Tr.pick('$playedTier部はいちばん下の部なので、下位で終えても降格はありません。',
            'Tier $playedTier is the bottom tier, so there is no relegation from it.'),
    ];
  }

  /// 季の切り替え(会計年度の終わりの6月30日)までに払う給与の見込み。
  int get projectedRolloverWages {
    final s = _save;
    if (s == null) return 0;
    final end = MoneyCalendar.fiscalYearEnd(s.league.season);
    final days = end.difference(SeasonCalendar.dateOnly(today)).inDays;
    if (days <= 0) return 0;
    return (weeklyWageBill * days / 7).round();
  }

  /// 季の切り替えで資金が赤字になりそうなら、その足りない額(正の数)。
  /// 季の残りが少ない(最後の数節か、季を終えた)ときだけ見る。
  int? get rolloverShortfall {
    final s = _save;
    if (s == null) return null;
    if (!s.league.isSeasonComplete && remainingMatchdaysThisSeason > 2) {
      return null;
    }
    final after = s.budget - projectedRolloverWages;
    return after < 0 ? -after : null;
  }
}
