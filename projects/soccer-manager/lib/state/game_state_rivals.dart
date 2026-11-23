part of 'game_state.dart';

/// 同じリーグの、競い合う他のオーナー。
extension GameStateRivals on GameState {
  List<RivalOwner> get rivalOwners => _save?.rivalOwners ?? const [];

  /// クラブを id で探す(自国の全部の部と、他の国の1部)。
  Team? worldTeamById(String id) =>
      _save == null ? null : _worldTeams.where((t) => t.id == id).firstOrNull;

  /// 作り物のオーナーの名前(実在しない)。
  static List<String> get _ownerNames => [
        Tr.pick('実業家 バルガス', 'Tycoon Vargas'),
        Tr.pick('投資家 ラーセン', 'Investor Larsen'),
        Tr.pick('富豪 オコンコ', 'Magnate Okonkwo'),
        Tr.pick('建設王 マルティーニ', 'Builder Martini'),
        Tr.pick('資産家 ヴェーバー', 'Heir Weber'),
        Tr.pick('商社の シルバ', 'Trader Silva'),
      ];

  /// 同じリーグの他のクラブから、競うオーナーを3人決める(強い2クラブと、
  /// ほかの1クラブ)。新しく始めたとき・季が替わって顔ぶれが変わったとき。
  void _assignRivalOwners() {
    final s = _save;
    if (s == null) return;
    final others = [
      for (final t in s.league.teams)
        if (t.id != s.userTeamId) t,
    ]..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    if (others.length < 3) {
      s.rivalOwners = [];
      return;
    }
    final keep = {
      for (final r in s.rivalOwners)
        if (others.any((t) => t.id == r.clubId)) r.clubId: r,
    };
    final rng = Random(s.league.season * 7919 + others.length);
    final picks = <Team>[others[0], others[1]];
    final rest = others.skip(2).toList();
    picks.add(rest[rng.nextInt(rest.length)]);
    final names = _ownerNames;
    s.rivalOwners = [
      for (var i = 0; i < picks.length; i++)
        keep[picks[i].id] ??
            RivalOwner(
              clubId: picks[i].id,
              clubName: picks[i].name,
              name: names[(rng.nextInt(names.length) + i) % names.length],
              ambition: 1 + rng.nextInt(3),
            ),
    ];
  }

  /// 窓が開いたら、他のオーナーが自分のクラブへ選手を足す(野心の数まで)。
  /// 自由契約の中から、そのクラブの平均より上の選手を取る。
  void _rivalOwnersInvest() {
    final s = _save;
    if (s == null) return;
    if (s.rivalOwners.isEmpty) _assignRivalOwners();
    for (final r in s.rivalOwners) {
      final club = s.league.teams.where((t) => t.id == r.clubId).firstOrNull;
      if (club == null) continue;
      final avg = club.players.isEmpty
          ? 0
          : club.players.fold<int>(0, (t, p) => t + p.overall) ~/
              club.players.length;
      final pool = [
        for (final p in s.freeAgents)
          if (p.overall > avg) p,
      ]..sort((a, b) => b.overall.compareTo(a.overall));
      final added = <String>[];
      for (final p in pool.take(r.ambition)) {
        if (club.players.length >= maxSquadSize) break;
        // 国の登録の決まりで加えられない選手は取らない(所属なしの選手は、
        // イタリアの「EU 外は1季2人まで」では他の国から来たのと同じ)。
        if (!_cpuCanRegister(club, p, fromCountry: null)) continue;
        _noteCpuSigning(club, p, fromCountry: null);
        _fixNationality(p);
        s.freeAgents.remove(p);
        ContractEngine.renewContract(p);
        club.players.add(p);
        added.add(p.name);
      }
      if (added.isEmpty) continue;
      r.signingsThisSeason += added.length;
      _logNews(
          Tr.pick('${r.clubName}のオーナー(${r.name})が補強に動いた: ${added.join('、')}。',
              '${r.clubName}\'s owner (${r.name}) has been spending: ${added.join(', ')}.'),
          context: Tr.pick('他のオーナー', 'Rival owners'));
    }
  }

  /// 交渉中の選手を狙うクラブとして、他のオーナーのクラブを優先する
  /// (野心が高いほど)。当てはまらなければ null。
  Team? _rivalOwnerClubFor(int sellerTier, String? sellerId, Random rng) {
    final s = _save!;
    for (final r in s.rivalOwners) {
      if (r.clubId == sellerId) continue;
      if (rng.nextInt(6) >= r.ambition) continue; // 野心3で半分
      final club = _worldTeams.where((t) => t.id == r.clubId).firstOrNull;
      if (club == null || club.players.length >= maxSquadSize) continue;
      if ((_tierOfClub(club.id) ?? 99) > sellerTier) continue;
      return club;
    }
    return null;
  }

  /// 季の終わり: 足した人数を戻し、顔ぶれ(昇降格)に合わせて選び直す。
  void _resetRivalOwners() {
    final s = _save;
    if (s == null) return;
    for (final r in s.rivalOwners) {
      r.signingsThisSeason = 0;
    }
    _assignRivalOwners();
  }

  // ---- 受信箱 ----

  /// 受信箱の未読の数(残っているお知らせの数まで)。
  int get unreadNewsCount {
    final s = _save;
    if (s == null) return 0;
    return (s.newsTotal - s.newsSeenTotal).clamp(0, s.newsLog.length);
  }

  /// 受信箱を読んだことにする。
  Future<void> markInboxRead() async {
    final s = _save;
    if (s == null || s.newsSeenTotal == s.newsTotal) return;
    s.newsSeenTotal = s.newsTotal;
    _notify();
    await _persist();
  }

  /// 画面に出していたお知らせを、受信箱に積む(注意でないもの)。
  void addInboxNote(String text) {
    _logNews(text);
    _notify();
  }

  /// オーナーの答えを待っているもの(1行ずつ)。
  List<String> get inboxActions {
    final s = _save;
    if (s == null) return const [];
    final talks = s.transferTalks;
    final countered =
        talks.where((t) => t.stage == TransferTalkStage.countered).length;
    final agreed =
        talks.where((t) => t.stage == TransferTalkStage.agreed).length;
    return [
      if (pendingOwnerEvent != null)
        Tr.pick('オーナーの判断を待つ出来事があります', 'An owner decision is waiting'),
      if (s.pendingRumor != null)
        Tr.pick('${s.pendingRumor![1]}の噂に、記者会見で答えていません',
            'Answer the ${s.pendingRumor![1]} rumour at the press conference'),
      // 手術か保存療法かも、答えを待つもの(以前は数えておらず、決めずに
      // 何節でも進められた)。
      for (final p in playersAwaitingSurgeryDecision)
        Tr.pick('${p.name}の治療(手術か保存療法か)を決めていません',
            "Decide ${p.name}'s treatment: surgery or rest"),
      if (s.agmDemand != null)
        Tr.pick('株主の要求に答えていません', 'The shareholders want an answer'),
      if (s.incomingOffers.isNotEmpty)
        Tr.pick('自分の選手へのオファーが${s.incomingOffers.length}件',
            '${Tr.plural(s.incomingOffers.length, 'offer')} for your players'),
      if (countered > 0)
        Tr.pick('相手のクラブから対案が$countered件', '${Tr.plural(countered, 'counter-offer')} from clubs'),
      if (agreed > 0)
        Tr.pick('クラブと合意し、選手と話す交渉が$agreed件',
            '${Tr.plural(agreed, 'deal')} agreed with clubs: talk to the player'),
      if (s.staffOffers.isNotEmpty)
        Tr.pick('スタッフの引き抜きの話が${s.staffOffers.length}件',
            '${Tr.plural(s.staffOffers.length, 'approach', 'approaches')} for your staff'),
      if (s.pendingSponsorOffers.isNotEmpty)
        Tr.pick('スポンサーを選んでいません', 'Pick a sponsor'),
    ];
  }

  /// 一度に進める節の上限(何も起きなくても、ここで一度止まる)。
  static const int advanceLimit = 8;

  /// オーナーが決めることが出るまで(受信箱に答えを待つものが出るか、
  /// 季が終わるか、[advanceLimit]節まで)、節を続けて進める。
  /// 返すのは、進めた試合の結果(自クラブの試合)。
  /// 保存は終わったときに1回だけ([_inBulkSave])。
  Future<List<MatchResult>> advanceToNextDecision() => _inBulkSave(() async {
        final out = <MatchResult>[];
        final s = _save;
        if (s == null) return out;
        for (var i = 0; i < advanceLimit; i++) {
          if (s.league.isSeasonComplete || saleReason != null) break;
          if (inboxActions.isNotEmpty || s.pendingBoardReviewMessage != null) {
            break;
          }
          final r = await playNextMatchdayQuickSim();
          if (r == null) break;
          out.add(r);
        }
        return out;
      });
}
