import '../l10n/tr.dart';

/// オーナーが選ぶクラブの方針。2つの期待(サポーター・株主)のどちらを
/// 優先して引っ張るかを決める。理事会が毎季決める「路線」(ClubVision)とは別。
/// 名前(name)はセーブに残すので、変えない。
enum ClubPolicy {
  /// 偏らない。従来と同じ。
  balanced,

  /// 勝利優先。補強に余裕が出るが、株主は財布の紐が緩いと見る。
  win,

  /// 育成優先。施設が安くなる。若手が育てばサポーターも株主も喜ぶ。
  develop,

  /// 収益優先。収入が増えるが、サポーターは物足りなく感じる。
  profit;

  String get label => switch (this) {
        balanced => Tr.pick('バランス', 'Balanced'),
        win => Tr.pick('勝利優先', 'Win first'),
        develop => Tr.pick('育成優先', 'Develop first'),
        profit => Tr.pick('収益優先', 'Profit first'),
      };

  String get summary => switch (this) {
        balanced => Tr.pick('どちらにも偏りません。', 'No lean either way.'),
        win => Tr.pick(
            '週給の上限が10%広がる。目標順位に届けばサポーター+6、届かなければ-6。株主は毎季-3。',
            'Wage cap +10%. Supporters +6 if you hit the target rank, -6 if not. Shareholders -3 every season.'),
        develop => Tr.pick(
            '施設の増築費が10%安くなる。若手(21歳以下)が${PolicyEngine.youngCountRequired}人以上いればサポーター+4・株主+2、いなければ両方-3。',
            'Facility costs -10%. With ${PolicyEngine.youngCountRequired}+ players aged 21 or under: supporters +4, shareholders +2; otherwise -3 each.'),
        profit => Tr.pick(
            '収入が5%増える。黒字なら株主+6、赤字なら-6。サポーターは毎季-3。',
            'Income +5%. Shareholders +6 if you profit, -6 if not. Supporters -3 every season.'),
      };
}

/// シーズン末の方針の採点。
class PolicyResult {
  const PolicyResult({
    required this.supporters,
    required this.shareholders,
    required this.reason,
  });

  final int supporters;
  final int shareholders;
  final String reason;
}

class PolicyEngine {
  const PolicyEngine._();

  /// 育成優先で求める若手の人数。
  static const int youngCountRequired = 6;

  static const int youngAge = 21;

  static double wageCapMultiplier(ClubPolicy p) =>
      p == ClubPolicy.win ? 1.10 : 1.0;

  static double facilityCostMultiplier(ClubPolicy p) =>
      p == ClubPolicy.develop ? 0.90 : 1.0;

  static double incomeMultiplier(ClubPolicy p) =>
      p == ClubPolicy.profit ? 1.05 : 1.0;

  /// シーズン末の採点。[balanced]は null(何も動かさない)。
  static PolicyResult? score({
    required ClubPolicy policy,
    required int finalRank,
    required int targetRank,
    required int youngCount,
    required int seasonProfit,
  }) {
    switch (policy) {
      case ClubPolicy.balanced:
        return null;
      case ClubPolicy.win:
        final hit = finalRank <= targetRank;
        return PolicyResult(
          supporters: hit ? 6 : -6,
          shareholders: -3,
          reason: hit
              ? Tr.pick('勝利優先: 目標順位に届き、サポーターが沸きました', 'Win first: you hit the target and the fans cheer')
              : Tr.pick('勝利優先: 目標順位に届かず、サポーターが失望しました',
                  'Win first: you missed the target and the fans are let down'),
        );
      case ClubPolicy.develop:
        final ok = youngCount >= youngCountRequired;
        return PolicyResult(
          supporters: ok ? 4 : -3,
          shareholders: ok ? 2 : -3,
          reason: ok
              ? Tr.pick('育成優先: 若手が育ち、期待が高まりました', 'Develop first: the young players are coming through')
              : Tr.pick('育成優先: 若手が足りず、方針が口先だけと見られました',
                  'Develop first: too few young players, and the policy looks empty'),
        );
      case ClubPolicy.profit:
        final ok = seasonProfit > 0;
        return PolicyResult(
          supporters: -3,
          shareholders: ok ? 6 : -6,
          reason: ok
              ? Tr.pick('収益優先: 黒字で株主が満足しました', 'Profit first: a profit pleases the shareholders')
              : Tr.pick('収益優先: 赤字で株主が怒っています', 'Profit first: a loss angers the shareholders'),
        );
    }
  }
}
