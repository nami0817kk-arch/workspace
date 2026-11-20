/// 番付に並ぶ1クラブ。
class RankedClub {
  const RankedClub({
    required this.name,
    required this.value,
    required this.tier,
    required this.isUser,
  });

  final String name;
  final int value;
  final int tier;
  final bool isUser;
}

/// 世界クラブ価値番付。自クラブの価値と、他クラブの見積もりを並べる。
class ClubRankingEngine {
  const ClubRankingEngine._();

  /// 部ごとの、選手以外の価値の見積もり(施設・ブランド・稼ぐ力の相当分)。
  static int tierBase(int tier) => switch (tier) {
        <= 1 => 3000,
        2 => 1800,
        3 => 1000,
        4 => 600,
        _ => 300,
      };

  /// 他クラブの価値の見積もり。選手の市場価値の合計に、部ごとの底上げ。
  static int estimate({required int playersValue, required int tier}) =>
      playersValue + tierBase(tier);

  /// 価値の高い順に並べる(同値は名前順)。
  static List<RankedClub> rank(List<RankedClub> clubs) {
    final sorted = [...clubs];
    sorted.sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// 自クラブの順位(1が最上位)。見つからなければ 0。
  static int userRank(List<RankedClub> ranked) {
    final i = ranked.indexWhere((c) => c.isUser);
    return i < 0 ? 0 : i + 1;
  }
}
