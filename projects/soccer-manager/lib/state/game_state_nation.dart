part of 'game_state.dart';

/// 選手の国籍と、労働許可(アルビオン式のリーグだけ)。
extension GameStateNation on GameState {
  /// 国の呼び名(リーグ名の語幹。「アルビオン」など)。
  static String nationLabel(LeagueTheme t) {
    final l = t.label;
    // 区切りの中黒(U+30FB)。文字を直接書くと翻訳漏れの点検に掛かる。
    final dot = String.fromCharCode(0x30FB);
    return l.contains(dot) ? l.split(dot).first : l.split(' ').first;
  }

  /// 自国のクラブのうち、外国籍の選手の割合(国と部で違う)。
  ///
  /// 実在の1部は外国籍が5〜7割(イングランド約65%・イタリア約60%・
  /// ドイツ約55%・スペインとフランス約45%)。下の部ほど自国の選手が多く、
  /// 2部は1部の6割ほど・3部は4割5分ほど(2〜4割)。以前はどの国・どの部も
  /// 1割だった(2026-11-22)。
  static double foreignShare(LeagueTheme country, int tier) {
    final top = switch (country) {
      LeagueTheme.england => 0.65,
      LeagueTheme.italy => 0.60,
      LeagueTheme.germany => 0.55,
      LeagueTheme.spain => 0.45,
      LeagueTheme.france => 0.45,
    };
    if (tier <= 1) return top;
    if (tier == 2) return top * 0.6;
    return top * 0.45;
  }

  /// id [id]の選手が、国[country]の[tier]部のクラブで外国籍になるか。
  /// 外国籍なら国、自国籍なら null。id から毎回同じ答えを出す。
  static LeagueTheme? foreignNationalityFor(
      String id, LeagueTheme country, int tier) {
    // id そのもののハッシュは、続き番号の id で下の桁がほぼ並んでしまう
    // (同じクラブの選手がそろって外国籍・自国籍になる)。散らした値で引く
    // ([Player.spreadRoll])。
    if (Player.spreadRoll('$id#nat') >= foreignShare(country, tier)) {
      return null;
    }
    final others = [
      for (final t in LeagueTheme.values)
        if (t != country) t,
    ];
    return others[(Player.spreadRoll('$id#from') * others.length).floor()];
  }

  /// アフリカの代表の数(名前は出さず、番号で分ける)。
  static const int africanTeamCount = 12;

  /// id [id]・国籍[nationality]の選手が、アフリカの国の代表を選んだ二重
  /// 国籍の選手なら、その代表の番号(0〜[africanTeamCount]-1)。そうでなければ
  /// null(2026-11-22)。
  ///
  /// このゲームの国籍は5か国([LeagueTheme])だけで、アフリカの国籍を持た
  /// ない。実際の欧州のリーグには、アフリカの国の代表としてプレーする選手
  /// (二重国籍を含む)が多いので、国籍と id から毎回同じ答えを出して、その
  /// 選手を決める。フランス国籍は多く(12%)、ほかの国籍は4%。この選手は
  /// 国籍の国の代表には呼ばれず、アフリカの代表に呼ばれる(代表ウィークと、
  /// アフリカネイションズカップ)。
  static int? africanTeamFor(String id, LeagueTheme nationality) {
    final share = nationality == LeagueTheme.france ? 0.12 : 0.04;
    final h = Player.nationalityHash('$id#afr');
    if (h % 1000 >= (share * 1000).round()) return null;
    return Player.nationalityHash('$id#afrteam') % africanTeamCount;
  }

  /// [p]がアフリカの国の代表の選手か([africanTeamFor])。
  bool isAfricanInternational(Player p) =>
      africanTeamFor(p.id, nationalityOf(p)) != null;

  /// [p]の国籍。移ったことのある選手は覚えている国籍、そうでなければ
  /// 今いるクラブの国と部から決める。自由契約と作り物の市場の選手は自国。
  LeagueTheme nationalityOf(Player p) {
    final stored = p.nation;
    if (stored != null) {
      return LeagueTheme.values.firstWhere((t) => t.name == stored,
          orElse: () => currentLeagueTheme);
    }
    final club = _sellingClubOf(p.id);
    return _nationalityAt(p, club, _foreignTeamIds(),
        tier: club == null ? null : _tierOfClub(club.id));
  }

  /// [nationalityOf] の中身。所属クラブ[club]と他国のクラブの一覧[foreign]を
  /// 外から渡せるようにして、全選手を回すときに毎回探し直さない(選手ごとに
  /// 全クラブを探すと、3,500人で1回あたり数秒かかっていた)。[tier]はクラブの
  /// 部(他国の1部は1)。
  LeagueTheme _nationalityAt(Player p, Team? club, Map<String, String> foreign,
      {int? tier}) {
    final stored = p.nation;
    if (stored != null) {
      return LeagueTheme.values.firstWhere((t) => t.name == stored,
          orElse: () => currentLeagueTheme);
    }
    final home = currentLeagueTheme;
    // 自由契約・作り物の市場・自クラブの選手は自国(国籍の揺れはクラブに
    // いる他の選手だけに付ける)。
    if (club == null) return home;
    final foreignName = foreign[club.id];
    final base = foreignName == null
        ? home
        : LeagueTheme.values
            .firstWhere((t) => t.name == foreignName, orElse: () => home);
    if ((_save?.nationRuleVersion ?? SaveGame.currentNationRuleVersion) < 2) {
      return _legacyNationality(p.id, base);
    }
    return foreignNationalityFor(p.id, base, tier ?? 1) ?? base;
  }

  /// 版1の国籍の決め方(どの部も1割が別の国)。版1のセーブを読んだときに、
  /// 今の国籍を覚えさせるのに使う。
  static LeagueTheme _legacyNationality(String id, LeagueTheme base) {
    if (!Player.foreignNationalFromId(id)) return base;
    final h = Player.nationalityHash(id);
    final others = [
      for (final t in LeagueTheme.values)
        if (t != base) t,
    ];
    return others[(h ~/ 10) % others.length];
  }

  /// 他のクラブの選手の国籍を覚えさせる(読み込み・新しいゲーム・季の
  /// 切り替えで、[_localizeNames]から呼ぶ)。
  ///
  /// - 版1のセーブ: 今の国籍(どの部も1割)をそのまま覚えさせてから版2にする
  ///   (国籍が変わると名前が付け替わるため)。国内育成の印は変えない。
  /// - 版2: まだ国籍を覚えていない選手に、クラブの国と部で決めた国籍を
  ///   覚えさせ、国内育成の印を国籍に合わせて引き直す(自国籍は3人に2人、
  ///   外国籍は10人に1人。[PlayerGenerator.homegrownRoll]と同じ割合)。
  ///   ユース出身の印は変えない。
  void _assignClubNationalities(Map<String, String> foreign) {
    final s = _save;
    if (s == null) return;
    final legacy = s.nationRuleVersion < 2;
    for (final t in _worldTeams) {
      if (t.id == s.userTeamId) continue;
      final tier = _tierOfClub(t.id) ?? 1;
      for (final p in t.players) {
        if (p.nation != null) continue;
        final nation = _nationalityAt(p, t, foreign, tier: tier);
        p.nation = nation.name;
        if (legacy) continue;
        final country = LeagueTheme.values.firstWhere(
            (c) => c.name == (foreign[t.id] ?? currentLeagueTheme.name),
            orElse: () => currentLeagueTheme);
        p.homegrown = PlayerGenerator.homegrownRollFor(
            national: nation == country,
            roll: Player.spreadRoll('${p.id}#hg'));
      }
    }
    s.nationRuleVersion = SaveGame.currentNationRuleVersion;
  }

  /// 新しいゲームの自クラブの選手に国籍と国内育成の印を付ける
  /// ([startNewGame]で、名前を国籍に合わせる前に1回だけ呼ぶ)。
  ///
  /// 以前は自クラブの選手が全員自国籍で、CPU のクラブ(3部で2〜3割が
  /// 外国籍)と食い違っていた(2026-11-22)。CPU と同じ国・部の割合
  /// ([foreignShare])で外国籍を混ぜ、国内育成の印も国籍で引き直す(自国籍は
  /// 3人に2人、外国籍は10人に1人)。ただし始めた時点で国の登録の決まり
  /// (EU 外の枠・国外で育った選手の枠)を破らないように、超える分は
  /// 自国籍で国内育成の選手に戻す。
  ///
  /// 古いセーブの自クラブの選手は国籍を覚えていないので、今までどおり
  /// 自国籍のまま(名前も印も変わらない)。ユースから上がった選手も同じ。
  /// 新しいゲームの自クラブで、22歳以上の登録枠に残しておく空きの人数。
  static const int startSeniorRoom = 2;

  void _assignUserNationalitiesAtStart(int tier) {
    if (_save == null) return;
    final home = currentLeagueTheme;
    final rules = registrationRules;
    final team = userTeam;
    LeagueTheme nationOf(Player p) => LeagueTheme.values
        .firstWhere((t) => t.name == p.nation, orElse: () => home);
    bool homegrownFor(Player p, {required bool national}) =>
        PlayerGenerator.homegrownRollFor(
            national: national,
            roll: Player.spreadRoll('${p.id}#hg'));
    void makeNational(Player p, {bool forceHomegrown = false}) {
      p.nation = home.name;
      p.homegrown = forceHomegrown || homegrownFor(p, national: true);
    }

    for (final p in team.players) {
      final nation = foreignNationalityFor(p.id, home, tier) ?? home;
      p.nation = nation.name;
      p.homegrown = homegrownFor(p, national: nation == home);
    }
    final nonEuLimit = rules.nonEuLimit;
    if (nonEuLimit != null) {
      final nonEu = [
        for (final p in team.players)
          if (!isEuNation(nationOf(p))) p,
      ];
      // 始めた時点で枠ちょうどだと、すぐには誰も取れない。1人分あける。
      for (final p in nonEu.skip(max(0, nonEuLimit - 1))) {
        makeNational(p);
      }
    }
    final minNationals = rules.minNationals;
    if (minNationals != null) {
      final foreigners = [
        for (final p in team.players)
          if (nationOf(p) != home) p,
      ];
      final room = SquadRegistration.totalLimit - minNationals;
      for (final p in foreigners.skip(room)) {
        makeNational(p);
      }
    }
    // 22歳以上の登録枠も、始めた時点で2人分はあけておく。25人の選手を
    // 年齢のくじで作るので、22歳以上がちょうど25人そろうことがあり、
    // 22歳以上を1人も取れずに始まった(2026-11-23)。超える分は、22歳以上の
    // うち若い順に21歳(枠の外)にし、年俸も年齢に合わせて引き直す。
    final seniors = team.players.where(SquadRegistration.isSenior).toList()
      ..sort((a, b) => a.age.compareTo(b.age));
    final seniorRoom = SquadRegistration.seniorLimit - startSeniorRoom;
    for (final p in seniors.take(max(0, seniors.length - seniorRoom))) {
      p
        ..age = SquadRegistration.underAge
        ..wage = p.fairWeeklyWage();
    }
    final notHomegrown = [
      for (final p in team.players)
        if (SquadRegistration.isSenior(p) && !p.homegrown) p,
    ];
    // 国外で育った選手の枠も、始めた時点で3人分はあけておく(枠ちょうどで
    // 始まると、国外育成の選手を1人も取れなかった。2026-11-22)。
    for (final p
        in notHomegrown.skip(max(0, rules.nonHomegrownLimit - 3))) {
      makeNational(p, forceHomegrown: true);
    }
  }

  /// 選手の名前を国籍に合わせる(読み込み・新しいゲーム・季の切り替えで呼ぶ)。
  ///
  /// 以前は日本語の表示で全員に日本の姓名を付けていて、欧州を模したリーグ
  /// なのに「選手が日本人だけ」に見えた。国籍の名前の一覧から作られていない
  /// 名前だけを、選手の id から決まる名前に付け替える(同じクラブで重ならない
  /// ように引き直す)。一度合わせた名前は変えない。
  void _localizeNames() {
    final s = _save;
    if (s == null) return;
    NamePool.homeTheme = currentLeagueTheme;
    final foreign = _foreignTeamIds();
    // 先に他のクラブの選手の国籍を決めて覚えさせる(名前はその国籍に合わせる)。
    _assignClubNationalities(foreign);
    for (final t in _worldTeams) {
      final club = t.id == s.userTeamId ? null : t;
      final used = {for (final p in t.players) p.name};
      for (final p in t.players) {
        final nation = _nationalityAt(p, club, foreign);
        if (NationNames.fits(p.name, nation)) continue;
        used.remove(p.name);
        final h =
            p.id.codeUnits.fold<int>(17, (a, c) => (a * 131 + c) % 1000003);
        var name = NationNames.nameFor(nation, h);
        for (var k = 1;
            used.contains(name) && k < NationNames.combinations(nation);
            k++) {
          name = NationNames.nameFor(nation, h + k * 7);
        }
        p.name = name;
        used.add(name);
      }
    }
  }

  /// 国籍を覚えさせる(国をまたいで移る前に呼ぶ)。
  void _fixNationality(Player p) {
    p.nation ??= nationalityOf(p).name;
  }

  // ---- 国ごとの選手登録の決まり ----

  /// 今の国の選手登録の決まり([SquadRegistration])。
  RegistrationRules get registrationRules =>
      RegistrationRules.forCountry(currentLeagueTheme);

  /// 今季、他の国から取った EU 外の国籍の選手の数(イタリアの決まりに使う)。
  int get nonEuSignedThisSeason {
    final s = _save;
    if (s == null) return 0;
    return s.nonEuSigningsSeason == s.league.season ? s.nonEuSignings : 0;
  }

  /// [p]を自クラブへ加えられない理由(登録の決まり。国ごと)。加えられるなら null。
  String? registrationBlockFor(Player p) {
    if (_save == null) return null;
    return SquadRegistration.blockReason(
      userTeam,
      p,
      rules: registrationRules,
      nationOf: nationalityOf,
      nonEuSignedThisSeason: nonEuSignedThisSeason,
      incomingFromAbroad: _comesFromAbroad(p),
    );
  }

  /// 締切で登録の枠を超えているか(国ごとの決まりで)。
  bool get registrationOverLimit =>
      _save != null &&
      SquadRegistration.isOverLimit(userTeam,
          rules: registrationRules, nationOf: nationalityOf);

  /// 自クラブにいる EU 外の国籍の選手の数(登録の画面の表示用)。
  int get nonEuPlayerCount => _save == null
      ? 0
      : SquadRegistration.nonEuCount(userTeam, nationalityOf);

  /// 自クラブにいる、自国籍の選手の数(登録の画面の表示用)。
  int get nationalPlayerCount => _save == null
      ? 0
      : userTeam.players
          .where((p) => nationalityOf(p) == currentLeagueTheme)
          .length;

  /// [p]が他の国のクラブから来るか(イタリアの EU 外の獲得の数え方)。
  ///
  /// 所属なしの選手も数える(2026-11-22。実際のイタリアの決まりは「国外から
  /// 新しく登録する EU 外の選手」で、所属なしで来る選手もその枠を使う)。
  /// ローンで借りる選手も、他の国のクラブからなら数える。
  bool _comesFromAbroad(Player p) {
    if (_save!.freeAgents.any((q) => q.id == p.id)) return true;
    final club = _sellingClubOf(p.id);
    if (club != null) return _foreignTeamIds().containsKey(club.id);
    final origin = p.originLeague;
    return origin != null && origin != currentLeagueTheme.name;
  }

  /// 自クラブが他の国から EU 外の国籍の選手を取ったら数える(獲得のたび、
  /// 元のクラブから外す前に呼ぶ)。所属なしの選手も数える
  /// ([_comesFromAbroad])。ローンで借りるときも、元のクラブから外す
  /// ([_takeFromSeller])ときに数える。
  void _noteSigningFromAbroad(Player p) {
    final s = _save;
    if (s == null) return;
    if (!_comesFromAbroad(p) || isEuNation(nationalityOf(p))) return;
    if (s.nonEuSigningsSeason != s.league.season) {
      s.nonEuSigningsSeason = s.league.season;
      s.nonEuSignings = 0;
    }
    s.nonEuSignings++;
  }

  // ---- CPU のクラブの選手登録(2026-11-22) ----
  //
  // 以前は登録の決まりが自クラブの補強にしか効かず、CPU のクラブは人数の
  // 上限(26人)だけを見て取っていた。いまは CPU のクラブも、そのクラブの
  // 国の決まり([RegistrationRules.forCountry])で加えられない選手は取らない
  // (AI 同士の移籍・自クラブからの買い取り・放出の行き先・横取り・他の
  // オーナーの補強・AI 同士の仮契約)。

  /// クラブ[clubId]の国(自国のクラブは今の国、他国の1部はその国)。
  LeagueTheme _countryOfClub(String clubId, [Map<String, String>? foreign]) {
    final name = (foreign ?? _foreignTeamIds())[clubId];
    if (name == null) return currentLeagueTheme;
    return LeagueTheme.values
        .firstWhere((t) => t.name == name, orElse: () => currentLeagueTheme);
  }

  /// CPU のクラブ[clubId]が今季、他の国(と所属なし)から取った EU 外の
  /// 国籍の選手の数(イタリアの決まり)。
  int _cpuNonEuSignedThisSeason(String clubId) {
    final s = _save!;
    if (s.cpuNonEuSigningsSeason != s.league.season) return 0;
    return s.cpuNonEuSignings[clubId] ?? 0;
  }

  /// CPU のクラブ[club]が[p]を加えられるか(そのクラブの国の登録の決まり)。
  ///
  /// [fromCountry]は選手が今いるクラブの国。null は所属なしの選手(イタリア
  /// の「EU 外は1季2人まで」では、他の国から来たのと同じに数える)。
  bool _cpuCanRegister(Team club, Player p,
      {required LeagueTheme? fromCountry, Map<String, String>? foreign}) {
    if (_save == null) return true;
    final f = foreign ?? _foreignTeamIds();
    final country = _countryOfClub(club.id, f);
    final tier = _tierOfClub(club.id) ?? 1;
    // クラブの選手の国籍は、そのクラブを分かっている形で引く(全クラブを
    // 探し直さない)。加える選手はいまの所属で決まる国籍。
    LeagueTheme nationOf(Player q) => q.id == p.id
        ? nationalityOf(p)
        : _nationalityAt(q, club, f, tier: tier);
    return SquadRegistration.blockReason(
          club,
          p,
          rules: RegistrationRules.forCountry(country),
          nationOf: nationOf,
          nonEuSignedThisSeason: _cpuNonEuSignedThisSeason(club.id),
          incomingFromAbroad: fromCountry != country,
        ) ==
        null;
  }

  /// テスト用: CPU のクラブ[club]が[p]を加えられるか([_cpuCanRegister])。
  @visibleForTesting
  bool debugCpuCanRegister(Team club, Player p, {LeagueTheme? fromCountry}) =>
      _cpuCanRegister(club, p, fromCountry: fromCountry);

  /// [clubs]のうち、[p]を登録の決まりで加えられる CPU のクラブ。
  List<Team> _cpuClubsThatCanRegister(Iterable<Team> clubs, Player p,
      {required LeagueTheme? fromCountry}) {
    final f = _foreignTeamIds();
    return [
      for (final c in clubs)
        if (_cpuCanRegister(c, p, fromCountry: fromCountry, foreign: f)) c,
    ];
  }

  /// CPU のクラブ[club]が[p]を取ったら、イタリアの「EU 外は1季2人まで」を
  /// 数える(他の国・所属なしから来た EU 外の選手だけ)。
  void _noteCpuSigning(Team club, Player p,
      {required LeagueTheme? fromCountry}) {
    final s = _save;
    if (s == null) return;
    final country = _countryOfClub(club.id);
    if (RegistrationRules.forCountry(country).nonEuSigningsPerSeason == null) {
      return;
    }
    if (fromCountry == country || isEuNation(nationalityOf(p))) return;
    if (s.cpuNonEuSigningsSeason != s.league.season) {
      s.cpuNonEuSigningsSeason = s.league.season;
      s.cpuNonEuSignings.clear();
    }
    s.cpuNonEuSignings[club.id] = (s.cpuNonEuSignings[club.id] ?? 0) + 1;
  }

  /// 労働許可が要るリーグか(アルビオン式だけ)。
  bool get workPermitRequired => currentLeagueTheme == LeagueTheme.england;

  /// 労働許可に要る総合力(上の部ほど高い)。
  int workPermitMinimum(int tier) => 76 - tier * 4; // 1部72・3部64

  /// 労働許可が下りないなら、その理由。下りるなら null。
  String? workPermitBlock(Player p) {
    if (_save == null || !workPermitRequired) return null;
    final nation = nationalityOf(p);
    if (nation == currentLeagueTheme) return null;
    final need = workPermitMinimum(_save!.currentDivisionTier);
    if (p.overall >= need) return null;
    return Tr.pick(
        '${p.name}(${nationLabel(nation)}国籍)には労働許可が下りません。${_save!.currentDivisionTier}部では総合力$need以上が要ります。',
        '${p.name} (${nationLabel(nation)}) would not get a work permit: tier ${_save!.currentDivisionTier} needs an overall of $need or more.');
  }
}

/// スペインのリリース条項(解放金額)。2026-11-22 に実在の決まりへ寄せた。
///
/// スペインでは、選手の契約に必ずリリース条項が付く(AI のクラブの選手にも。
/// 額は市場価値の数倍)。条項の額を払えば、クラブの同意は要らない。ただし
/// 移るかどうかは選手が決める(以前は条項の額が払われると、選手の同意なしに
/// その場で売れていた)。自クラブの選手に条項を付けるのは、スペイン以外では
/// オーナーの任意のまま。
extension GameStateReleaseClause on GameState {
  /// スペインのクラブの選手の条項が、市場価値の何倍か(3〜6倍。伸びしろの
  /// 大きい若手は2倍上乗せ)。id から毎回同じ答えを出す。
  static double spanishClauseMultiple(Player p) {
    var m = 3.0 + Player.nationalityHash('${p.id}#clause') % 4;
    if (p.age <= 23 && p.potential - p.overall >= 8) m += 2;
    return m;
  }

  /// スペインのクラブの選手に既定で付くリリース条項の額(万円)。
  static int defaultSpanishClause(Player p) =>
      max(1, (p.marketValue * spanishClauseMultiple(p)).round());

  /// 自クラブの選手にリリース条項が必ず付く国か(スペイン)。
  bool get releaseClausesRequired => currentLeagueTheme == LeagueTheme.spain;

  /// [p]のいるクラブの国(自クラブは今の国、他のクラブはその国)。
  /// 自由契約・作り物の市場・借りている選手は null。
  LeagueTheme? _clubCountryOf(Player p) {
    if (_save == null || p.isLoan) return null;
    if (userTeam.players.any((q) => q.id == p.id)) return currentLeagueTheme;
    final club = _sellingClubOf(p.id);
    if (club == null) return null;
    final name = _foreignTeamIds()[club.id];
    if (name == null) return currentLeagueTheme;
    return LeagueTheme.values.where((t) => t.name == name).firstOrNull;
  }

  /// [p]のリリース条項(万円)。無ければ null。スペインのクラブの選手には
  /// 必ず付く(決めていなければ市場価値の数倍)。それ以外は自クラブの選手に
  /// オーナーが付けたときだけ。
  int? releaseClauseOf(Player p) {
    final country = _clubCountryOf(p);
    if (country == null) return null;
    if (country == LeagueTheme.spain) {
      return p.releaseClause ?? defaultSpanishClause(p);
    }
    if (userTeam.players.any((q) => q.id == p.id)) return p.releaseClause;
    return null;
  }

  /// AI のクラブが、自クラブの選手の条項の額を払いに来る確率。市場価値
  /// 以下なら必ず払い、2倍以上なら払わない(以前は額を問わず払っていた)。
  static double aiClausePayChance(int clause, int marketValue) {
    if (marketValue <= 0) return 1;
    final ratio = clause / marketValue;
    if (ratio <= 1) return 1;
    return (2 - ratio).clamp(0.0, 1.0);
  }

  /// 条項の額が払われたとき、選手が移るのに同意する確率。不満な選手・
  /// 移籍リストに載せた選手・野心家は移りたがり、忠誠心の強い選手は残る。
  static double releaseClauseConsentChance(Player p) {
    var c = 0.4;
    if (p.happiness < 50) {
      c += 0.3;
    } else if (p.happiness >= 75) {
      c -= 0.15;
    }
    if (p.isTransferListed) c += 0.2;
    switch (p.personality) {
      case PlayerPersonality.loyal:
      case PlayerPersonality.clubLegendType:
        c -= 0.25;
      case PlayerPersonality.ambitious:
      case PlayerPersonality.veryAmbitious:
      case PlayerPersonality.mercenary:
        c += 0.15;
      default:
        break;
    }
    return c.clamp(0.05, 0.95);
  }

  /// 他のクラブの選手のリリース条項の額を払う。クラブとの交渉なしで移籍金が
  /// 決まり(合意の扱い)、あとは選手が条件をのむか次第([offerPersonalTerms])。
  /// 払えなければ false(理由は[lastSigningBlockReason])。
  Future<bool> triggerReleaseClause(String playerId) async {
    final ok = _triggerReleaseClauseCore(playerId);
    _notify();
    if (ok) await _persist();
    return ok;
  }

  bool _triggerReleaseClauseCore(String playerId) {
    if (_save == null) return false;
    lastSigningBlockReason = null;
    if (!isTransferWindowOpen) {
      lastSigningBlockReason =
          Tr.pick('移籍の窓が閉じています。', 'The transfer window is shut.');
      return false;
    }
    final target = _acquisitionTarget(playerId);
    if (target == null || target.club == null) return false;
    final player = target.player;
    final clause = releaseClauseOf(player);
    if (clause == null) {
      lastSigningBlockReason = Tr.pick('この選手にはリリース条項がありません。',
          'This player has no release clause.');
      return false;
    }
    if (!_minorRuleAllows(player)) return false;
    if (!_registrationAllows(player)) return false;
    final agentFee = TransferTermsEngine.agentFee(clause);
    if (_save!.budget < clause + agentFee) {
      lastSigningBlockReason = Tr.pick(
          '資金が足りません(条項の額${formatMoney(clause)}と代理人手数料${formatMoney(agentFee)})。',
          'You cannot afford it (the clause of ${formatMoney(clause)} plus the agent fee of ${formatMoney(agentFee)}).');
      return false;
    }
    // 前の交渉(決裂したものも)は消す。条項を払えばクラブの同意は要らない。
    _save!.transferTalks.removeWhere((t) => t.playerId == playerId);
    _save!.transferTalks.add(TransferTalk(
      playerId: player.id,
      playerName: player.name,
      clubId: target.club!.id,
      clubName: target.club!.name,
      bid: clause,
      fee: clause,
      stage: TransferTalkStage.agreed,
      deadline:
          today.add(const Duration(days: TransferTalkEngine.agreementDays)),
    ));
    _logNews(
        Tr.pick(
            '${player.name}のリリース条項(${formatMoney(clause)})を払う意思を${target.club!.name}に伝えた。移るかどうかは選手の返事次第。',
            'Told ${target.club!.name} we will pay the release clause for ${player.name} (${formatMoney(clause)}). Now it is up to the player.'),
        context: Tr.pick('移籍', 'Transfer'));
    return true;
  }
}
