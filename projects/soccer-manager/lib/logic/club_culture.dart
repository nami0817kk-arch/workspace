import '../l10n/tr.dart';
import '../models/match_result.dart';
import '../models/player.dart';

/// クラブの文化。サポーターが「うちらしさ」と思うもの。オーナーが選び、
/// それに沿った試合をするとサポーターの期待が上がる。
enum ClubCulture { none, attacking, youth, local, defensive }

extension ClubCultureInfo on ClubCulture {
  String get label => switch (this) {
        ClubCulture.none => Tr.pick('決めない', 'None'),
        ClubCulture.attacking => Tr.pick('攻撃的', 'Attacking'),
        ClubCulture.youth => Tr.pick('若手を育てる', 'Youth'),
        ClubCulture.local => Tr.pick('地元育ち', 'Homegrown'),
        ClubCulture.defensive => Tr.pick('堅守', 'Defensive'),
      };

  String get description => switch (this) {
        ClubCulture.none => Tr.pick('文化を打ち出さない。', 'No particular identity.'),
        ClubCulture.attacking => Tr.pick('2点以上取った試合でサポーターが沸く。',
            'Fans love it when you score two or more.'),
        ClubCulture.youth => Tr.pick('先発に21歳以下が3人以上いるとサポーターが喜ぶ。',
            'Fans are pleased when three or more starters are 21 or under.'),
        ClubCulture.local => Tr.pick('先発に国内育ちが6人以上いるとサポーターが喜ぶ。',
            'Fans are pleased when six or more starters are homegrown.'),
        ClubCulture.defensive => Tr.pick('無失点の試合でサポーターが沸く。',
            'Fans love a clean sheet.'),
      };
}

/// クラブの文化の効き目。
class ClubCultureEngine {
  const ClubCultureEngine._();

  /// 文化に沿った試合ならサポーターの期待+1、そうでなければ0。
  static int matchBonus({
    required ClubCulture culture,
    required MatchResult r,
    required String userId,
    required List<Player> starters,
  }) {
    final home = r.homeTeamId == userId;
    final gf = home ? r.homeGoals : r.awayGoals;
    final ga = home ? r.awayGoals : r.homeGoals;
    final ok = switch (culture) {
      ClubCulture.none => false,
      ClubCulture.attacking => gf >= 2,
      ClubCulture.defensive => ga == 0,
      ClubCulture.youth => starters.where((p) => p.age <= 21).length >= 3,
      ClubCulture.local => starters.where((p) => p.isHomegrown).length >= 6,
    };
    return ok ? 1 : 0;
  }

  /// 文化を変えると、古いサポーターが戸惑う(期待-3)。1季に1回まで変えられる。
  static const int changePenalty = 3;
}
