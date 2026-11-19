part of 'game_state.dart';

/// 同じリーグの、競い合う他のオーナー。
extension GameStateRivals on GameState {
  List<RivalOwner> get rivalOwners => _save?.rivalOwners ?? const [];

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
}
