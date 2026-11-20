part of 'game_state.dart';

/// 選手の私生活の出来事と、仲の良い選手が去ったときの寂しさ。
extension GameStateLife on GameState {
  /// 1か月あたり、1人に出来事が起きる確率。
  static const double lifeEventChance = 0.02;

  /// [p]に起きた私生活の出来事の印(古い順)。
  List<String> lifeEventsOf(String playerId) =>
      _save?.lifeEvents[playerId] ?? const [];

  /// 月が替わったら、選手ごとに私生活の出来事を振る。
  void _rollLifeEvents(DateTime before, DateTime after) {
    final s = _save;
    if (s == null) return;
    if (before.year == after.year && before.month == after.month) return;
    final rng = GameState._offerRng;
    for (final p in userTeam.players) {
      if (rng.nextDouble() >= lifeEventChance) continue;
      _lifeEventFor(p, after.year, rng);
    }
    // 去った選手の記録は捨てる。
    final ids = {for (final p in userTeam.players) p.id};
    s.lifeEvents.removeWhere((id, _) => !ids.contains(id));
  }

  /// [p]に起きうる出来事から1つ起こす(起きうるものが無ければ何もしない)。
  /// [year]はホームシックなどを1年に1回にするために使う。
  void _lifeEventFor(Player p, int year, Random rng) {
    final s = _save!;
    final past = s.lifeEvents[p.id] ?? const <String>[];
    final married = past.contains('married');
    final children = past.where((e) => e == 'child').length;
    final options = <(String, int, String)>[
      if (!married && p.age >= 23 && p.age <= 35)
        ('married', 10, Tr.pick('${p.name}が結婚した。機嫌が良い。',
            '${p.name} got married and is in fine spirits.')),
      if (married && children < 3 && p.age >= 24)
        ('child', 8, Tr.pick('${p.name}に子どもが生まれた。',
            '${p.name} has become a father.')),
      if (p.traits.adaptability <= 7 && !past.contains('homesick-$year'))
        ('homesick-$year', -12, Tr.pick('${p.name}がホームシックにかかっている。',
            '${p.name} is homesick.')),
      if (!past.contains('loss-$year') && rng.nextInt(5) == 0)
        ('loss-$year', -8, Tr.pick('${p.name}の家族に不幸があった。',
            'There has been a death in ${p.name}\'s family.')),
    ];
    if (options.isEmpty) return;
    final (key, delta, text) = options[rng.nextInt(options.length)];
    (s.lifeEvents[p.id] ??= []).add(key);
    p.happiness = (p.happiness + delta).clamp(0, 100);
    _logNews(text, context: Tr.pick('選手', 'Players'));
  }

  /// テスト用: [p]に出来事を1つ起こす。
  @visibleForTesting
  void debugLifeEvent(Player p, {int year = 2027}) =>
      _lifeEventFor(p, year, Random(1));

  /// [left]が去ったとき、仲の良かった選手の機嫌が下がる。
  void _friendsMissPlayer(Player left) {
    final friends = [
      for (final q in userTeam.players)
        if (RelationsEngine.areFriends(left, q)) q,
    ];
    if (friends.isEmpty) return;
    for (final q in friends) {
      q.happiness =
          (q.happiness - RelationsEngine.friendLeftPenalty).clamp(0, 100);
    }
    _logNews(
        Tr.pick('${left.name}と仲の良かった${friends.map((q) => q.name).join('、')}が寂しがっている。',
            '${friends.map((q) => q.name).join(', ')} will miss ${left.name}, a close friend.'),
        context: Tr.pick('選手', 'Players'));
  }
}
