import 'dart:math';

import '../models/player.dart';

/// ユースを去った有望株1人分の記録。
class YouthDeparture {
  final Player player;

  /// 受け取った育成補償金(万円)。
  final int compensation;

  /// 他クラブに引き抜かれたのか、見切りを付けて自分から出ていったのか。
  final bool poached;

  const YouthDeparture({
    required this.player,
    required this.compensation,
    required this.poached,
  });
}

/// 昇格の見込みが立たない有望株がユースを去る仕組み。
///
/// これが無いと、有望株は何年でもユースに置いておける。置いておくほど
/// 施設で育つので、「一軍に上げるか、まだ育てるか」という判断が
/// 「とりあえず置いておく」に潰れていた。年齢が上がるほど去りやすく
/// することで、上げる時期を決める必要が出る。
class YouthDepartureEngine {
  static final Random _rng = Random();

  /// この年齢からユースを出ていくことを考え始める。
  static const int restlessAge = 19;

  /// この年齢を過ぎると、ユースに置いておけるとは考えないほうがよい。
  static const int departureAge = 20;

  /// 育成補償金の割合(市場価値に対して)。引き抜きのほうが高い。
  static const double poachedCompensationRate = 0.35;
  static const double leftCompensationRate = 0.15;

  /// 1週あたりに去る確率。
  ///
  /// - 年齢が上がるほど高い([restlessAge]未満は0)
  /// - 伸びしろが大きい選手ほど、他クラブの関心を集めて高い
  /// - メンターが付いていると半分になる(クラブに居場所がある)
  /// - ユース施設が良いほど下がる
  static double weeklyDepartureChance(
    Player p, {
    required int facilityLevel,
    required bool hasMentor,
  }) {
    if (p.age < restlessAge) return 0;
    final base = p.age >= departureAge ? 0.020 : 0.006;
    final room = ((p.potential - p.overall) / 50).clamp(0.0, 1.0);
    final facility = (1 - facilityLevel * 0.08).clamp(0.4, 1.0);
    final mentor = hasMentor ? 0.5 : 1.0;
    return (base * (1 + room) * facility * mentor).clamp(0.0, 1.0);
  }

  /// 週次の判定。去った選手を[prospects]から取り除き、記録を返す。
  ///
  /// [mentorIds]には、いまメンターが付いている有望株のIDを渡す。
  static List<YouthDeparture> resolveWeekly(
    List<Player> prospects, {
    required int facilityLevel,
    Set<String> mentorIds = const {},
  }) {
    final departures = <YouthDeparture>[];
    for (final p in [...prospects]) {
      final chance = weeklyDepartureChance(
        p,
        facilityLevel: facilityLevel,
        hasMentor: mentorIds.contains(p.id),
      );
      if (chance <= 0 || _rng.nextDouble() >= chance) continue;

      // 伸びしろが大きい選手ほど「引き抜き」の形になる。伸び悩んだ選手は
      // 自分から見切りを付けて出ていく。
      final poached = p.potential - p.overall >= 10;
      final rate = poached ? poachedCompensationRate : leftCompensationRate;
      departures.add(YouthDeparture(
        player: p,
        compensation: (p.marketValue * rate).round(),
        poached: poached,
      ));
      prospects.remove(p);
    }
    return departures;
  }

  /// 画面に出す「そろそろ危ない」の判定。確率そのものではなく、
  /// 利用者が動けるかどうかで線を引く。
  static bool isAtRisk(Player p) => p.age >= restlessAge;
}
