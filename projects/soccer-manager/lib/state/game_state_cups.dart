part of 'game_state.dart';

/// カップ戦と大陸大会を実在の形に寄せる(2026-11-22)。
///
/// - 国内カップ: 1〜3部の全クラブ。3部が1回戦、2部が2回戦、1部が3回戦から
///   入る。部の違うクラブが当たると下の部のホーム。回戦はまとめて同じ週に
///   行い(自クラブの出ない試合は裏の試合と同じ軽い計算)、決勝は5月。
/// - リーグカップ: イングランドだけ(1〜3部)。
/// - 大陸大会: チャンピオンズカップ(32クラブ=4クラブ×8組)とヨーロッパ
///   カップ(16クラブ=4クラブ×4組)。グループはホームとアウェイの総当たり
///   (6節)、決勝トーナメントは2試合合計で、決勝だけ1試合。自国の他の
///   クラブも、他国の1部の上位も出る。
/// - スーパーカップ: 1部の王者とカップの王者。スペイン・イタリアは4クラブで
///   1月ごろ。2部・3部には無い。
/// - 決勝は中立の会場(2026-11-23)。FA カップは準決勝も中立(ウェンブリー)。
///   スペイン(コパ・デル・レイ)・イタリア(コッパ・イタリア)の国内カップと、
///   イングランドのリーグカップの準決勝は2試合合計。
extension GameStateCups on GameState {
  /// チャンピオンズカップのクラブ数(4クラブ×8組)。
  static const int championsCupClubs = 32;

  /// ヨーロッパカップのクラブ数(4クラブ×4組)。
  static const int europaCupClubs = 16;

  /// 今季の部ごとのクラブ(1部から)。
  Map<int, List<Team>> _teamsByTierNow() {
    final s = _save!;
    return {
      for (var tier = 1; tier <= totalDivisionTiers; tier++)
        tier: tier == s.currentDivisionTier
            ? s.league.teams
            : (tier - 1 < s.otherDivisionLeagues.length
                ? s.otherDivisionLeagues[tier - 1]?.teams ?? const <Team>[]
                : const <Team>[]),
    };
  }

  /// 自クラブの部の1季の節の数(日程を組む前でも、クラブ数から求める)。
  int get _cupSeasonMatchdays => max(2, (_save!.league.teams.length - 1) * 2);

  /// 国内カップの各回戦を消化できるようになる節。1回戦は第3節の前、
  /// 準決勝までを季の中に均し、決勝は最終節の前(5月)。
  static List<int> domesticRoundDue(int totalRounds, int matchdays) {
    final m = matchdays;
    if (totalRounds <= 1) return [m];
    final span = max(1, m - 8);
    final out = <int>[
      for (var r = 1; r < totalRounds; r++)
        3 + ((r - 1) * span / max(1, totalRounds - 2)).round(),
      m,
    ];
    return _strictlyRising(out, m);
  }

  /// リーグカップの各回戦の節。8月に始まり、決勝は季の6割ほど(2〜3月)。
  static List<int> leagueCupRoundDue(int totalRounds, int matchdays) {
    final m = matchdays;
    final last = max(3, (m * 0.62).round());
    if (totalRounds <= 1) return [last];
    final out = <int>[
      for (var r = 1; r < totalRounds; r++)
        2 + ((r - 1) * (last - 4) / max(1, totalRounds - 2)).round(),
      last,
    ];
    return _strictlyRising(out, m);
  }

  /// 大陸大会の各段階の節。グループの6節は9〜12月、決勝トーナメントは
  /// 2〜5月、決勝は最終節の前。
  static List<int> continentalStepDue(int steps, int matchdays) {
    final m = matchdays;
    const groupFr = [0.12, 0.20, 0.28, 0.34, 0.40, 0.46];
    final out = <int>[for (final f in groupFr) max(2, (m * f).round())];
    final ko = steps - groupFr.length - 1;
    for (var i = 0; i < ko; i++) {
      out.add((m * (0.56 + 0.34 * i / max(1, ko - 1))).round());
    }
    out.add(m);
    return _strictlyRising(out, m);
  }

  /// 節を必ず1つずつ増える並びにする(同じ節に2つの回戦を置かない)。
  /// 終わりが[last]を越えるときは、越えた分をそのままにする(季の後に回る)。
  static List<int> _strictlyRising(List<int> due, int last) {
    final out = [...due];
    for (var i = 1; i < out.length; i++) {
      if (out[i] <= out[i - 1]) out[i] = out[i - 1] + 1;
    }
    return out;
  }

  /// [due]の節に達したか(リーグ戦を終えた後は、いつでも)。
  bool _cupDue(int? due) {
    if (due == null) return true;
    if (_save!.league.nextUnplayedFixture == null) return true;
    return _currentLeagueMatchdayMarker >= due;
  }

  /// 今季の国内カップ(1〜3部の全クラブ)。
  Cup _newDomesticCup() {
    final theme = currentLeagueTheme;
    final m = _cupSeasonMatchdays;
    return CupEngine.createTiered(
      type: CupType.domestic,
      name: theme.domesticCupName,
      byTier: {
        for (final e in _teamsByTierNow().entries)
          if (e.value.isNotEmpty) e.key: e.value.map((t) => t.id).toList(),
      },
      roundDue: (total) => domesticRoundDue(total, m),
      focusTeamId: _save!.userTeamId,
      neutralSemiFinal: theme == LeagueTheme.england,
      twoLeggedSemiFinal:
          theme == LeagueTheme.spain || theme == LeagueTheme.italy,
    );
  }

  /// 今季のリーグカップ(イングランドだけ。ほかの国は null)。
  /// 2部・3部が1回戦から、1部は2回戦から入る。
  Cup? _newTieredLeagueCup() {
    final theme = currentLeagueTheme;
    if (!theme.hasLeagueCup) return null;
    final m = _cupSeasonMatchdays;
    return CupEngine.createTiered(
      type: CupType.leagueCup,
      name: theme.leagueCupName,
      byTier: {
        for (final e in _teamsByTierNow().entries)
          if (e.value.isNotEmpty) e.key: e.value.map((t) => t.id).toList(),
      },
      entryRound: const {3: 1, 2: 1, 1: 2},
      roundDue: (total) => leagueCupRoundDue(total, m),
      focusTeamId: _save!.userTeamId,
      twoLeggedSemiFinal: true,
    );
  }

  /// 季の始めのカップ(国内カップと、イングランドならリーグカップ)。
  List<Cup> _newSeasonCups() {
    final lc = _newTieredLeagueCup();
    return [_newDomesticCup(), if (lc != null) lc];
  }

  /// 読み込んだセーブを今の形に合わせる: リーグの順位の決め方を国ごとに
  /// し、イングランド以外に残っているリーグカップを捨てる(古いセーブには
  /// どの国にもリーグカップがあった。途中の成績は静かに消える)。
  void _migrateCupsAndRules() {
    final s = _save;
    if (s == null) return;
    _applyTieBreakRules();
    if (!currentLeagueTheme.hasLeagueCup) {
      s.cups.removeWhere((c) => c.type == CupType.leagueCup);
    }
  }

  /// 順位の決め方(勝ち点で並んだとき、得失点差と直接対決のどちらが先か)を
  /// 国ごとにする。自国の全部と、他国の1部。
  void _applyTieBreakRules() {
    final s = _save;
    if (s == null) return;
    final home = currentLeagueTheme.goalDifferenceFirst;
    s.league.goalDiffFirst = home;
    for (final l in s.otherDivisionLeagues) {
      l?.goalDiffFirst = home;
    }
    for (final e in s.foreignLeagues.entries) {
      final t = LeagueTheme.values.where((x) => x.name == e.key).firstOrNull;
      if (t != null) e.value.goalDiffFirst = t.goalDifferenceFirst;
    }
  }

  // ---- 自クラブの出ない試合を、日が来たらまとめて決める ----

  /// 日が来た回戦・段階の、自クラブの出ない試合をまとめて決める。
  /// 節を進めるとき(リーグ戦の前)と、カップ戦を戦う前後に呼ぶ。
  void _playDueCpuCupMatches() {
    final s = _save;
    if (s == null) return;
    final dom = domesticCup;
    if (dom != null) _playCpuCupRound(dom);
    for (final c in [s.continentalCup, s.secondContinentalCup]) {
      if (c != null) _playCpuContinental(c);
    }
    _playFourClubSuperCup();
  }

  bool _isUserMatch(CupMatch m) {
    final u = _save!.userTeamId;
    return m.homeTeamId == u || m.awayTeamId == u;
  }

  /// 国内カップ(新しい形)の、日が来た回戦のうち自クラブの出ない試合を
  /// 決める。自クラブの試合が残っていれば、その回戦はそこで止まる
  /// (自クラブの試合の後に回戦が終わる)。何か決めたら true。
  bool _playCpuCupRound(Cup cup) {
    if (cup.plannedRounds == null || cup.isComplete) return false;
    var played = false;
    for (var guard = 0; guard < 16; guard++) {
      final next = cup.nextUnplayedMatch;
      if (next == null || !_cupDue(cup.dueMatchdayForMatch(next))) break;
      // 2試合制の組は、第1戦・第2戦それぞれの日が来たものだけ。
      final cpu = cup.rounds.last
          .where((m) =>
              m.result == null &&
              !_isUserMatch(m) &&
              _cupDue(cup.dueMatchdayForMatch(m)))
          .toList();
      if (cpu.isEmpty) break;
      final teams = allTeamsForCups;
      for (final m in cpu) {
        CupEngine.playInBackground(cup, teams, m);
      }
      played = true;
    }
    CupEngine.putTeamFirst(cup, _save!.userTeamId);
    return played;
  }

  /// 大陸大会(新しい形)の、日が来た段階のうち自クラブの出ない試合を決める。
  bool _playCpuContinental(ContinentalCup cup) {
    if (cup.stepDue == null || cup.isComplete) return false;
    var played = false;
    int progress() =>
        cup.groupMatches.where((m) => m.result != null).length +
        cup.knockoutRounds.fold<int>(
            0, (a, r) => a + r.fold<int>(0, (b, t) => b + t.legs.length));
    for (var guard = 0; guard < 24; guard++) {
      if (ContinentalCupEngine.currentStep(cup) == null) break;
      if (!_cupDue(ContinentalCupEngine.currentStepDue(cup))) break;
      final before = progress();
      ContinentalCupEngine.playCpuStep(cup, allTeamsForCups, _save!.userTeamId);
      ContinentalCupEngine.putTeamFirst(cup, _save!.userTeamId);
      if (progress() == before) break;
      played = true;
      _settleContinentalPrizes(cup);
    }
    ContinentalCupEngine.putTeamFirst(cup, _save!.userTeamId);
    return played;
  }

  // ---- 大陸大会 ----

  /// 自クラブが出ている大陸大会(出ていなければ null)。
  ContinentalCup? get _userContinentalCup {
    final s = _save;
    if (s == null) return null;
    final u = s.userTeamId;
    for (final c in [s.continentalCup, s.secondContinentalCup]) {
      if (c != null && c.involvesTeam(u)) return c;
    }
    return null;
  }

  /// 今季の大陸大会(チャンピオンズカップ、ヨーロッパカップの順。無いものは
  /// 外す)。
  List<ContinentalCup> get continentalCups => [
        if (_save?.continentalCup case final c?) c,
        if (_save?.secondContinentalCup case final c?) c,
      ];

  /// [theme]の国のチャンピオンズカップの枠(国の係数の順位で決まる)。
  int championsSpotsFor(LeagueTheme theme) {
    final rank = countryCoefficientRanking.indexWhere((r) => r.$1 == theme) + 1;
    return CountryCoefficientEngine.spotsForRank(rank <= 0 ? 5 : rank);
  }

  /// 大陸大会の出場クラブを決めて、2つの大会を組む。
  ///
  /// [tier1Order]は自国の1部の今季の順位の順(季の始めは強さの順)。
  /// 上から CL の枠(5/4/3)、その下の1クラブと国内カップの優勝クラブが
  /// EL(カップの優勝クラブがすでに CL なら、リーグの次の順位)。
  /// 他国はその国の1部の順位から同じ数え方で(カップの代わりにリーグの
  /// 次の順位)。足りない分は、その他の国のクラブを作って埋める。
  void _setUpContinentalCups({
    required List<Team> tier1Order,
    String? domesticCupWinnerId,
  }) {
    final s = _save!;
    final home = currentLeagueTheme;
    final rng = Random();
    final countries = <String, String>{};
    final cl = <Team>[];
    final el = <Team>[];

    // 自国。
    final homeSpots = championsSpotsFor(home);
    cl.addAll(tier1Order.take(homeSpots));
    final clIds = {for (final t in cl) t.id};
    final allNow = allTeamsForCups;
    final cupWinner = domesticCupWinnerId == null
        ? null
        : allNow.where((t) => t.id == domesticCupWinnerId).firstOrNull;
    final rest = tier1Order.where((t) => !clIds.contains(t.id)).toList();
    final elHome = <Team>[
      if (rest.isNotEmpty) rest.first,
      if (cupWinner != null && !clIds.contains(cupWinner.id)) cupWinner,
    ];
    for (final t in rest) {
      if (elHome.length >= CountryCoefficientEngine.europaSpots) break;
      if (!elHome.any((x) => x.id == t.id)) elHome.add(t);
    }
    final elHomeUnique = <Team>[];
    for (final t in elHome) {
      if (!elHomeUnique.any((x) => x.id == t.id)) elHomeUnique.add(t);
    }
    el.addAll(elHomeUnique.take(CountryCoefficientEngine.europaSpots));
    for (final t in [...cl, ...el]) {
      countries[t.id] = home.name;
    }

    // 他国(順位を控えてあればその順、無ければ強さの順)。
    final copies = <Team>[];
    for (final theme in LeagueTheme.values) {
      if (theme == home) continue;
      final l = s.foreignLeagues[theme.name];
      if (l == null || l.teams.isEmpty) continue;
      final order = _lastForeignOrder[theme.name] ?? _foreignOrderNow(l);
      final spots = championsSpotsFor(theme);
      final picked = order.take(spots + CountryCoefficientEngine.europaSpots);
      var i = 0;
      for (final t in picked) {
        // 他国のリーグの選手そのものは動かさない。強さだけ持つ写しを出す。
        final copy = Team.fromJson(t.toJson(includePlayers: false));
        copies.add(copy);
        countries[copy.id] = theme.name;
        (i < spots ? cl : el).add(copy);
        i++;
      }
    }

    // その他の国のクラブで埋める。
    var made = 0;
    Team filler(int strength) {
      final name = _otherNationClubName(made);
      final t = PlayerGenerator.generateSquad(
        id: 'cont_s${s.league.season}_$made',
        name: name,
        strengthTier: strength,
      );
      made++;
      final copy = Team.fromJson(t.toJson(includePlayers: false));
      copies.add(copy);
      return copy;
    }

    while (cl.length < championsCupClubs) {
      cl.add(filler(80 + rng.nextInt(10)));
    }
    while (el.length < europaCupClubs) {
      el.add(filler(75 + rng.nextInt(10)));
    }
    s.continentalTeams = copies;

    final m = _cupSeasonMatchdays;
    ContinentalCup build(List<Team> teams, int level) {
      final groupCount = (teams.length / ContinentalCupEngine.groupSize).ceil();
      final cup = ContinentalCupEngine.create(
        name: continentalCupName(level),
        teamIds: teams.map((t) => t.id).toList(),
        homeAndAway: true,
        level: level,
        strength: {for (final t in teams) t.id: t.overallRating},
        countries: {
          for (final t in teams)
            if (countries[t.id] != null) t.id: countries[t.id]!,
        },
        stepDue: continentalStepDue(
            ContinentalCupEngine.stepCountFor(groupCount), m),
      );
      ContinentalCupEngine.putTeamFirst(cup, s.userTeamId);
      return cup;
    }

    s.continentalCup = build(cl.take(championsCupClubs).toList(), 1);
    s.secondContinentalCup = build(el.take(europaCupClubs).toList(), 2);
  }

  /// 他国のリーグの今の順位の順(まだ試合が無ければ強さの順)。
  List<Team> _foreignOrderNow(League l) {
    final rows = l.sortedStandings;
    final played = rows.any((r) => r.played > 0);
    if (!played) {
      return [...l.teams]
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    }
    return [
      for (final r in rows)
        if (l.teams.where((t) => t.id == r.teamId).firstOrNull case final t?) t,
    ];
  }

  /// その他の国(大陸大会の枠を埋めるクラブ)の名前。
  String _otherNationClubName(int i) {
    final (ja, en) = _otherNationClubs[i % _otherNationClubs.length];
    final lap = i ~/ _otherNationClubs.length;
    final name = Tr.pick(ja, en);
    return lap == 0 ? name : '$name ${lap + 1}';
  }

  // i18n-ignore: その他の国のクラブの名前(日本語と英語の組。実在から少し変えた)。
  static const List<(String, String)> _otherNationClubs = [
    ('リスボア・スポルティーボ', 'Lisboa Sportivo'),
    ('ポルト・ドラゴンエス', 'Porto Dragoes'),
    ('アムステル・ユナイテッド', 'Amstel United'),
    ('ロッテルダム・ハーフェン', 'Rotterdam Haven'),
    ('アイントホーフェン・リヒト', 'Eindhoven Licht'),
    ('ブリュッセル・ロワイヤル', 'Bruxelles Royale'),
    ('ブルッヘ・クラブ', 'Brugge Club'),
    ('グラスゴー・ケルティック', 'Glasgow Keltic'),
    ('グラスゴー・ローヴァーズ', 'Glasgow Rovers'),
    ('イスタンブール・アスラン', 'Istanbul Aslan'),
    ('イスタンブール・カナリア', 'Istanbul Kanarya'),
    ('ザルツァッハ・シュティーア', 'Salzach Stier'),
    ('ヴィエナ・ラピッド', 'Viena Rapid'),
    ('ザグレブ・プラヴィ', 'Zagreb Plavi'),
    ('ベオグラード・ズヴェズダ', 'Beograd Zvezda'),
    ('プラハ・スパルタク', 'Praha Spartak'),
    ('コベンハウン・ロイヤル', 'Kobenhavn Royal'),
    ('アテネ・オリンピア', 'Athina Olympia'),
    ('ピレウス・ポセイドン', 'Pireas Poseidon'),
    ('キーウ・ディナミカ', 'Kyiv Dinamika'),
    ('バーゼル・ライン', 'Basel Rhein'),
    ('ベルン・ヤングスターズ', 'Bern Youngsters'),
    ('オスロ・ノルド', 'Oslo Nord'),
    ('ストックホルム・ソルナ', 'Stockholm Solna'),
    ('ワルシャワ・レギオン', 'Warszawa Legion'),
  ];

  /// 自クラブの大陸大会の賞金のうち、試合ごとでないもの(出場給・決勝
  /// トーナメントの回戦に進んだ分・優勝)を払う。何度呼んでも二重には
  /// 払わない。
  void _settleContinentalPrizes(ContinentalCup cup) {
    final s = _save!;
    final u = s.userTeamId;
    if (!cup.involvesTeam(u) || cup.stepDue == null) return;
    if (!cup.participationPaid) {
      cup.participationPaid = true;
      final fee = continentalPrize(cup.level, championsCupParticipationPrize);
      _book(LedgerCategory.prize, fee);
      s.careerCupPrize += fee;
      _logNews(
          Tr.pick('${cup.name}の出場給${formatMoney(fee)}が入った。',
              'Received ${formatMoney(fee)} for taking part in the ${cup.name}.'),
          context: cup.name);
    }
    // 決勝トーナメントの回戦の数(決勝を含む)。
    final totalKo = () {
      var n = 0;
      for (var k = cup.groups.length * 2; k > 1; k ~/= 2) {
        n++;
      }
      return n;
    }();
    final reached = cup.knockoutRounds
        .where((r) => r.any((t) => t.teamAId == u || t.teamBId == u))
        .length;
    while (cup.knockoutPrizesPaid < reached) {
      final fromFinal = totalKo - 1 - cup.knockoutPrizesPaid;
      final prize = continentalReachPrize(cup.level, fromFinal);
      cup.knockoutPrizesPaid++;
      _book(LedgerCategory.prize, prize);
      s.careerCupPrize += prize;
      lastCupPrizeNote = Tr.pick('勝ち上がり賞金として${formatMoney(prize)}を獲得!',
          'You collected ${formatMoney(prize)} for going through!');
      _logNews(lastCupPrizeNote!, context: cup.name);
    }
    if (cup.isComplete && cup.championId == u && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final reward = continentalPrize(cup.level, championsCupWinnerPrize);
      _book(LedgerCategory.prize, reward);
      s.careerCupPrize += reward;
      s.confidence = (s.confidence + (cup.level == 1 ? 20 : 12)).clamp(0, 100);
      s.trophyHistory.add(Tr.pick('シーズン${s.league.season}: ${cup.name} 優勝',
          'Season ${s.league.season}: ${cup.name} winners'));
    }
  }

  // ---- スーパーカップ ----

  /// 4クラブのスーパーカップ(スペイン・イタリア)。無ければ null。
  Cup? get fourClubSuperCup =>
      _save == null ? null : _cupOfType(CupType.superCup);

  /// 4クラブのスーパーカップの出場クラブ: リーグの1位・2位とカップの優勝・
  /// 準優勝(重なればリーグの次の順位)。準決勝はリーグ1位 対 カップ準優勝、
  /// カップ優勝 対 リーグ2位。
  static List<String>? fourClubSuperCupField(
      List<String> tier1Order, Cup? domesticCup) {
    if (tier1Order.length < 4) return null;
    String? cupWinner;
    String? cupRunnerUp;
    if (domesticCup != null && domesticCup.isComplete) {
      final f = domesticCup.rounds.last.first;
      cupWinner = f.winnerId;
      cupRunnerUp = f.winnerId == f.homeTeamId ? f.awayTeamId : f.homeTeamId;
    }
    final field = <String>[tier1Order[0], tier1Order[1]];
    for (final id in [cupWinner, cupRunnerUp]) {
      if (id != null && !field.contains(id)) {
        field.add(id);
      } else {
        field.add(tier1Order.firstWhere((x) => !field.contains(x)));
      }
    }
    // [リーグ1位, リーグ2位, カップ優勝(か代わり), カップ準優勝(か代わり)]
    return field;
  }

  /// スペイン・イタリアの4クラブのスーパーカップを組む(1月ごろ)。
  Cup? _newFourClubSuperCup(List<String> tier1Order, Cup? previousCup) {
    if (!currentLeagueTheme.fourClubSuperCup) return null;
    final f = fourClubSuperCupField(tier1Order, previousCup);
    if (f == null) return null;
    final due = _januaryMatchday();
    final cup = Cup(
      type: CupType.superCup,
      name: Tr.pick('スーパーカップ', 'Super Cup'),
      rounds: [
        [
          CupMatch(round: 1, homeTeamId: f[0], awayTeamId: f[3]),
          CupMatch(round: 1, homeTeamId: f[2], awayTeamId: f[1]),
        ],
      ],
      plannedRounds: 2,
      roundDue: [due, due + 1],
    );
    CupEngine.putTeamFirst(cup, _save!.userTeamId);
    return cup;
  }

  /// 今季の日程で、1月の最初の節。見つからなければ季の半ば。
  int _januaryMatchday() {
    final m = _cupSeasonMatchdays;
    final cal = SeasonCalendar.build(
      season: _save!.league.season,
      theme: currentLeagueTheme,
      totalMatchdays: m,
      playsInInternationalWindows:
          SeasonCalendar.playsThroughInternationalWindows(
              currentLeagueTheme, currentDivisionTier),
    );
    for (var md = 1; md <= m; md++) {
      if (cal.dateForMatchday(md).month == 1) return md;
    }
    return m ~/ 2;
  }

  /// 4クラブのスーパーカップの、日が来た試合のうち自クラブの出ない試合を
  /// 決める。自クラブの試合は、ほかのカップ戦と同じく進むボタンがその日に
  /// 止まって行う(自動かライブ観戦。2026-11-22 まではここでその場で
  /// 決めてニュースで伝えるだけだった)。延長は無く、引き分けはPK戦。
  void _playFourClubSuperCup() {
    final cup = fourClubSuperCup;
    if (cup == null || cup.isComplete) return;
    _playCpuCupRound(cup);
    _settleFourClubSuperCup(cup);
  }

  /// 4クラブのスーパーカップの次の試合が自クラブの試合で、日が来ていて
  /// 戦えるか(もう1つの準決勝が残っていても、先に裏で決めてから戦う)。
  bool get canPlayNextFourClubSuperCupMatch {
    final cup = fourClubSuperCup;
    final m = userFourClubSuperCupMatch;
    if (cup == null || m == null) return false;
    return _cupDue(cup.dueMatchdayFor(m.round));
  }

  /// 4クラブのスーパーカップの、今の回戦の自クラブのまだ戦っていない試合
  /// (無ければ null。日が来ているかは見ない)。
  CupMatch? get userFourClubSuperCupMatch {
    final cup = fourClubSuperCup;
    if (cup == null || cup.isComplete || cup.rounds.isEmpty) return null;
    return cup.rounds.last
        .where((m) => m.result == null && !m.isBye && _isUserMatch(m))
        .firstOrNull;
  }

  /// [canPlayNextFourClubSuperCupMatch]に加えて、ほかのライブ観戦の試合が
  /// 進んでいないか。
  bool get canPlayNextFourClubSuperCupMatchLive =>
      _liveFixture == null &&
      _liveCupKind == null &&
      canPlayNextFourClubSuperCupMatch;

  /// [match]が4クラブのスーパーカップの試合か。
  bool _isFourClubSuperCupMatch(CupMatch match) =>
      fourClubSuperCup?.rounds.any((r) => r.contains(match)) ?? false;

  /// 4クラブのスーパーカップで自クラブの試合が決まった後の共通処理(自動・
  /// ライブ共通)。結果をニュースに残し、同じ週の残りを裏で決めて、
  /// 大会が終わっていれば締める。
  void _afterFourClubSuperCupMatchApplied(CupMatch m) {
    final cup = fourClubSuperCup;
    final r = m.result;
    if (cup == null || r == null) return;
    final u = _save!.userTeamId;
    if (_isUserMatch(m)) {
      // 中立の会場。入場収入は折半。
      _bookCupGate(r, neutral: true, split: true);
      final oppId = m.homeTeamId == u ? m.awayTeamId : m.homeTeamId;
      final opp = teamById(oppId)?.name ?? '-';
      final mine = m.homeTeamId == u ? r.homeGoals : r.awayGoals;
      final theirs = m.homeTeamId == u ? r.awayGoals : r.homeGoals;
      final pens =
          m.penaltyWinnerId != null ? Tr.pick('(PK戦)', ' on penalties') : '';
      final stage =
          m.round == 1 ? Tr.pick('準決勝', 'semi-final') : Tr.pick('決勝', 'final');
      _logNews(
          m.winnerId == u
              ? Tr.pick('スーパーカップ$stage: $oppに$mine-$theirs$pensで勝った。',
                  'Super Cup $stage: beat $opp $mine-$theirs$pens.')
              : Tr.pick('スーパーカップ$stage: $oppに$mine-$theirs$pensで敗れた。',
                  'Super Cup $stage: lost $mine-$theirs$pens to $opp.'),
          context: cup.name);
      _playCpuCupRound(cup);
    }
    _settleFourClubSuperCup(cup);
  }

  /// 4クラブのスーパーカップが終わっていれば、優勝を記録して伝える
  /// (何度呼んでも1回だけ)。
  void _settleFourClubSuperCup(Cup cup) {
    final s = _save!;
    final u = s.userTeamId;
    if (cup.isComplete && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final champ = teamById(cup.championId!)?.name ?? '-';
      if (cup.championId == u) {
        s.trophyHistory.add(Tr.pick('シーズン${s.league.season} スーパーカップ優勝',
            'Season ${s.league.season} Super Cup winners'));
        _addTimeline(Tr.pick('スーパーカップで優勝', 'Won the Super Cup'));
      }
      lastSuperCupNews =
          Tr.pick('$champがスーパーカップを制した。', '$champ won the Super Cup.');
      _logNews(lastSuperCupNews!, context: cup.name);
    }
  }

  /// テスト用。
  @visibleForTesting
  void debugPlayDueCpuCupMatches() => _playDueCpuCupMatches();

  @visibleForTesting
  void debugSetUpContinentalCups(List<Team> tier1Order, {String? cupWinner}) =>
      _setUpContinentalCups(
          tier1Order: tier1Order, domesticCupWinnerId: cupWinner);
}
