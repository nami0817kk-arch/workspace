part of 'game_state.dart';

/// 日付で進む。進むボタンは「次の予定がある日」まで進み、何もない日は
/// 飛ばす(2026-11-22)。予定は、自クラブの試合(リーグ・カップ)と、
/// 日付で決まっている出来事(給料日・放映権・移籍の窓・契約の期日)。
///
/// 練習・不満・ユースなどの週の処理は7日ごとに1回、けがの回復と疲れの
/// 抜けは日数で進む(game_state_week.dart)。節の数では数えない。
extension GameStateCalendar on GameState {
  /// [from]〜[to](両端を含む)の、自クラブに関わる出来事。日付順。
  /// カレンダーの画面が使う。
  List<DayEvent> calendarEventsBetween(DateTime from, DateTime to) {
    final s = _save;
    if (s == null) return const [];
    final a = SeasonCalendar.dateOnly(from);
    final b = SeasonCalendar.dateOnly(to);
    bool inRange(DateTime d) => !d.isBefore(a) && !d.isAfter(b);
    final cal = seasonCalendar;
    final userId = s.userTeamId;
    final league = s.league;
    String nameOf(String id) => _teamById(id)?.name ?? Tr.pick('未定', 'TBC');
    final out = <DayEvent>[];
    for (final f in league.fixtures) {
      if (f.homeTeamId != userId && f.awayTeamId != userId) continue;
      final d = SeasonCalendar.dateOnly(cal.dateForMatchday(f.matchday));
      if (!inRange(d)) continue;
      final home = f.homeTeamId == userId;
      final opp = nameOf(home ? f.awayTeamId : f.homeTeamId);
      final r = f.result;
      final score = r == null
          ? ''
          : ' ${home ? r.homeGoals : r.awayGoals}-${home ? r.awayGoals : r.homeGoals}';
      out.add(DayEvent(
        date: d,
        kind: DayEventKind.leagueMatch,
        matchday: f.matchday,
        label: Tr.pick('第${f.matchday}節 vs $opp(${home ? 'H' : 'A'})$score',
            'MD ${f.matchday} vs $opp (${home ? 'H' : 'A'})$score'),
        shortLabel: Tr.pick('第${f.matchday}節', 'MD ${f.matchday}'),
        match: MatchFacts(
          opponent: opp,
          competition: MatchCompetition.league,
          competitionName: Tr.pick('リーグ戦', 'League'),
          home: home,
          goalsFor: r == null ? null : (home ? r.homeGoals : r.awayGoals),
          goalsAgainst: r == null ? null : (home ? r.awayGoals : r.homeGoals),
        ),
      ));
    }
    for (final c in _playedUserDomesticCupMatches()) {
      if (inRange(c.date)) out.add(c);
    }
    for (final c in _nextUserCupMatches()) {
      if (inRange(c.date)) out.add(c);
    }
    final superCup = s.pendingSuperCup;
    if (superCup != null) {
      final d = SeasonCalendar.dateOnly(cal.superCupDate);
      if (inRange(d)) {
        final opp = superCup.homeTeamId == userId
            ? superCup.awayTeamId
            : superCup.homeTeamId;
        out.add(DayEvent(
          date: d,
          kind: DayEventKind.superCup,
          label: Tr.pick(
              'スーパーカップ vs ${nameOf(opp)}', 'Super Cup vs ${nameOf(opp)}'),
          shortLabel: Tr.pick('スーパーカップ', 'Super Cup'),
          match: MatchFacts(
            opponent: nameOf(opp),
            competition: MatchCompetition.cup,
            competitionName: Tr.pick('スーパーカップ', 'Super Cup'),
          ),
        ));
      }
    }
    for (var i = 0; i < s.friendlies.length; i++) {
      final f = s.friendlies[i];
      final d =
          SeasonCalendar.dateOnly(cal.friendlyDate(i, s.friendlies.length));
      // 終わった親善試合は、その日が来ていれば結果を載せる(状況の札から
      // 先に済ませた試合が、まだ来ない日に結果つきで載らないように)。
      final r = f.result;
      if (r != null && d.isAfter(today)) continue;
      if (!inRange(d)) continue;
      final home = f.homeTeamId == userId;
      final opp = home ? f.awayTeamId : f.homeTeamId;
      final score = r == null
          ? ''
          : ' ${home ? r.homeGoals : r.awayGoals}-${home ? r.awayGoals : r.homeGoals}';
      out.add(DayEvent(
        date: d,
        kind: DayEventKind.friendly,
        label: Tr.pick('親善試合 vs ${nameOf(opp)}$score',
            'Friendly vs ${nameOf(opp)}$score'),
        shortLabel: Tr.pick('親善試合', 'Friendly'),
        match: MatchFacts(
          opponent: nameOf(opp),
          competition: MatchCompetition.friendly,
          competitionName: Tr.pick('親善試合', 'Friendly'),
          home: home,
          goalsFor: r == null ? null : (home ? r.homeGoals : r.awayGoals),
          goalsAgainst: r == null ? null : (home ? r.awayGoals : r.homeGoals),
        ),
      ));
    }
    out.addAll(DayEvents.calendarEvents(
        a.subtract(const Duration(days: 1)), b, currentLeagueTheme));
    DayEvents.sortEvents(out);
    return out;
  }

  /// リーグ・カップ戦のチームを id から引く(見つからなければ null)。
  Team? _teamById(String id) {
    for (final t in allTeamsForCups) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 自クラブの国内カップの次の試合の日。自分の番がまだ来ていなければ null。
  DateTime? get userDomesticCupDate {
    final s = _save;
    if (s == null || !isUserDomesticCupMatchUpNext) return null;
    final dom = domesticCup!;
    final m = dom.nextUnplayedMatch!;
    if (m.isBye) return null;
    return _cupDate(dom.plannedRounds != null ? null : dom.lastPlayedAtMatchday,
        continental: false, due: dom.dueMatchdayForMatch(m));
  }

  /// 国内カップの出番を、状況の画面の札で知らせる時期か。7月のうちから
  /// 「カップ戦へ」と出ていて、まだ何週も先の試合だった(2026-11-23)。
  /// 試合の日まで [cupNoticeDays] 日以内か、次の予定がそのカップ戦のとき。
  bool get isUserDomesticCupMatchSoon {
    final d = userDomesticCupDate;
    if (d == null) return false;
    if (nextStop?.kind == DayEventKind.cupMatch) return true;
    return SeasonCalendar.dateOnly(d)
            .difference(SeasonCalendar.dateOnly(today))
            .inDays <=
        cupNoticeDays;
  }

  /// カップ戦の札を出し始める日数。
  static const int cupNoticeDays = 7;

  /// 自クラブの、次のカップ戦(国内・大陸)。その試合が「次に消化する
  /// 試合」になっているものだけ(他のクラブの試合が先に残っているときは、
  /// いつ自分の番になるかまだ決まらない)。
  List<DayEvent> _nextUserCupMatches() {
    final s = _save!;
    final userId = s.userTeamId;
    final out = <DayEvent>[];
    final dom = domesticCup;
    final m = dom?.nextUnplayedMatch;
    if (dom != null &&
        m != null &&
        !m.isBye &&
        (m.homeTeamId == userId || m.awayTeamId == userId)) {
      final opp = m.homeTeamId == userId ? m.awayTeamId : m.homeTeamId;
      out.add(DayEvent(
        date: _cupDate(
            dom.plannedRounds != null ? null : dom.lastPlayedAtMatchday,
            continental: false,
            due: dom.dueMatchdayForMatch(m)),
        kind: DayEventKind.cupMatch,
        label: Tr.pick(
            '${dom.name} vs ${_teamById(opp)?.name ?? '-'}(${m.nextHomeId == userId ? 'H' : 'A'})',
            '${dom.name} vs ${_teamById(opp)?.name ?? '-'} (${m.nextHomeId == userId ? 'H' : 'A'})'),
        shortLabel: Tr.pick('カップ戦', 'Cup tie'),
        match: MatchFacts(
          opponent: _teamById(opp)?.name ?? '-',
          competition: MatchCompetition.cup,
          competitionName: dom.name,
          home: dom.isNeutral(m) ? null : m.nextHomeId == userId,
        ),
      ));
    }
    // 4クラブのスーパーカップ(スペイン・イタリア。1月ごろ)。
    final sc = fourClubSuperCup;
    final scm = userFourClubSuperCupMatch;
    if (sc != null && scm != null) {
      final home = scm.homeTeamId == userId;
      final opp = home ? scm.awayTeamId : scm.homeTeamId;
      out.add(DayEvent(
        date: _cupDate(null,
            continental: false, due: sc.dueMatchdayFor(scm.round)),
        kind: DayEventKind.cupMatch,
        label: Tr.pick(
            '${sc.name} vs ${_teamById(opp)?.name ?? '-'}(${home ? 'H' : 'A'})',
            '${sc.name} vs ${_teamById(opp)?.name ?? '-'} (${home ? 'H' : 'A'})'),
        shortLabel: Tr.pick('スーパーカップ', 'Super Cup'),
        match: MatchFacts(
          opponent: _teamById(opp)?.name ?? '-',
          competition: MatchCompetition.cup,
          competitionName: sc.name,
          home: sc.isNeutral(scm) ? null : home,
        ),
      ));
    }
    final cont = continentalCup;
    if (cont != null && _continentalHasNextMatch(cont)) {
      String? home;
      String? away;
      if (!cont.isGroupStageComplete) {
        final g = ContinentalCupEngine.nextGroupMatch(cont);
        home = g?.homeTeamId;
        away = g?.awayTeamId;
      } else {
        final leg = ContinentalCupEngine.nextKnockoutLeg(cont);
        home = leg?.homeId;
        away = leg?.awayId;
      }
      if (home != null && away != null && (home == userId || away == userId)) {
        final opp = home == userId ? away : home;
        out.add(DayEvent(
          date: _cupDate(
              cont.stepDue != null ? null : cont.lastPlayedAtMatchday,
              continental: true,
              due: ContinentalCupEngine.currentStepDue(cont)),
          kind: DayEventKind.cupMatch,
          label: Tr.pick(
              '${cont.name} vs ${_teamById(opp)?.name ?? '-'}(${home == userId ? 'H' : 'A'})',
              '${cont.name} vs ${_teamById(opp)?.name ?? '-'} (${home == userId ? 'H' : 'A'})'),
          shortLabel: Tr.pick('大陸カップ', 'Continental'),
          match: MatchFacts(
            opponent: _teamById(opp)?.name ?? '-',
            competition: MatchCompetition.continental,
            competitionName: cont.name,
            home: home == userId,
          ),
        ));
      }
    }
    return out;
  }

  /// 自クラブの、終わった国内カップの試合(回戦ごとに日が決まっている
  /// 新しい形のカップだけ)。日は、その回戦を消化できるようになる節の前の
  /// 平日(進むボタンが止まった日と同じ決め方)。今日より後の日には載せない。
  List<DayEvent> _playedUserDomesticCupMatches() {
    final s = _save!;
    final userId = s.userTeamId;
    final dom = domesticCup;
    if (dom == null || dom.roundDue == null) return const [];
    final out = <DayEvent>[];
    for (final round in dom.rounds) {
      for (final m in round) {
        if (m.isBye || (m.homeTeamId != userId && m.awayTeamId != userId)) {
          continue;
        }
        final base = dom.dueMatchdayFor(m.round);
        if (base == null) continue;
        final legs = <(MatchResult, int)>[
          if (m.twoLegged && m.firstLeg != null) (m.firstLeg!, base),
          if (m.result != null)
            (m.result!, m.twoLegged ? base + Cup.secondLegGap : base),
        ];
        for (final (r, due) in legs) {
          final d = SeasonCalendar.dateOnly(
              seasonCalendar.cupDateBefore(due, continental: false));
          if (d.isAfter(today)) continue;
          final home = r.homeTeamId == userId;
          final opp = home ? r.awayTeamId : r.homeTeamId;
          final gf = home ? r.homeGoals : r.awayGoals;
          final ga = home ? r.awayGoals : r.homeGoals;
          out.add(DayEvent(
            date: d,
            kind: DayEventKind.cupMatch,
            label: Tr.pick(
                '${dom.name} vs ${_teamById(opp)?.name ?? '-'}(${home ? 'H' : 'A'}) $gf-$ga',
                '${dom.name} vs ${_teamById(opp)?.name ?? '-'} (${home ? 'H' : 'A'}) $gf-$ga'),
            shortLabel: Tr.pick('カップ戦', 'Cup tie'),
            match: MatchFacts(
              opponent: _teamById(opp)?.name ?? '-',
              competition: MatchCompetition.cup,
              competitionName: dom.name,
              home: dom.isNeutral(m) ? null : home,
              goalsFor: gf,
              goalsAgainst: ga,
            ),
          ));
        }
      }
    }
    return out;
  }

  /// カップ戦の次の試合の日。1節に1試合の決まり(_canAdvanceCup)で、
  /// 次に消化できる節の前の平日。リーグ戦を終えた後は今日の次の平日。
  ///
  /// [due]は回戦・段階を消化できるようになる節(新しい形のカップ)。
  DateTime _cupDate(int? lastPlayedAtMatchday,
      {required bool continental, int? due}) {
    if (_save!.league.nextUnplayedFixture == null) {
      return SeasonCalendar.dateOnly(
          SeasonCalendar.nextCupWeekdayAfter(today, continental: continental));
    }
    final afterLast = (lastPlayedAtMatchday ?? 0) + 1;
    final marker = _currentLeagueMatchdayMarker;
    var eligible = afterLast > marker ? afterLast : marker;
    if (due != null && due > eligible) eligible = due;
    final d = SeasonCalendar.dateOnly(
        seasonCalendar.cupDateBefore(eligible, continental: continental));
    return d.isBefore(today) ? today : d;
  }

  /// 進むボタンが次に止まる日の出来事。リーグ戦を終えた後(季の終わりの
  /// 流れに入る)や、まだ始めていないときは null。
  ///
  /// 次のリーグ戦の日までにある、自クラブのカップ戦と、日付で決まって
  /// いる出来事のうち、いちばん早いもの。
  DayEvent? get nextStop {
    final s = _save;
    if (s == null) return null;
    final next = s.league.nextUnplayedFixture;
    if (next == null) return null;
    final matchDate = SeasonCalendar.dateOnly(dateOfMatchday(next.matchday));
    final events = calendarEventsBetween(today, matchDate).where((e) {
      // 試合は今日でもよい(今日の試合がまだなら今日に止まる)。
      // 試合以外は今日の分はもう済んでいるので、明日から。
      if (e.kind.isMatch) {
        if (e.kind == DayEventKind.leagueMatch) {
          return e.matchday == next.matchday;
        }
        // 親善試合とスーパーカップは、今まで通り状況の画面の札から行う。
        // 終わったカップ戦(結果つきで載せている)では止まらない。
        return e.kind == DayEventKind.cupMatch && e.match?.played != true;
      }
      return e.date.isAfter(today);
    }).toList();
    return events.isEmpty ? null : events.first;
  }

  /// [stop] までに、自クラブの出ないカップ戦が消化できるなら先に進めて
  /// おく(他のクラブ同士の試合で止まらないように)。
  Future<void> playBackgroundCupMatchesBefore(DayEvent stop) async {
    final s = _save;
    if (s == null) return;
    // 新しい形のカップ・大陸大会は、日が来た回戦の他のクラブの試合を
    // まとめて決める。
    _playDueCpuCupMatches();
    final userId = s.userTeamId;
    final dom = domesticCup;
    final m = dom?.nextUnplayedMatch;
    if (dom != null &&
        dom.plannedRounds == null &&
        m != null &&
        m.homeTeamId != userId &&
        m.awayTeamId != userId &&
        canPlayNextDomesticCupMatch &&
        !_cupDate(dom.lastPlayedAtMatchday, continental: false)
            .isAfter(stop.date)) {
      await playNextCupMatch();
    }
    final cont = continentalCup;
    if (cont != null && cont.stepDue == null && canPlayNextContinentalMatch) {
      final bool userIn;
      if (!cont.isGroupStageComplete) {
        final g = ContinentalCupEngine.nextGroupMatch(cont);
        userIn =
            g != null && (g.homeTeamId == userId || g.awayTeamId == userId);
      } else {
        final leg = ContinentalCupEngine.nextKnockoutLeg(cont);
        userIn = leg != null && (leg.homeId == userId || leg.awayId == userId);
      }
      if (!userIn &&
          !_cupDate(cont.lastPlayedAtMatchday, continental: true)
              .isAfter(stop.date)) {
        if (cont.isGroupStageComplete) {
          await playNextContinentalKnockoutLeg();
        } else {
          await playNextContinentalGroupMatch();
        }
      }
    }
  }

  /// 試合のない出来事の日([stop])まで今日を進める。給料・放映権・窓の
  /// 開閉は、今日を進めたときに走る処理(_setToday)がその日に行う。
  /// 進めた間の資金の増減を返す。
  Future<int> advanceToDateStop(DayEvent stop) async {
    final s = _save;
    if (s == null || stop.kind.isMatch) return 0;
    final before = s.budget;
    _advanceTodayTo(stop.date);
    _notify();
    await _persistNow();
    return s.budget - before;
  }
}
