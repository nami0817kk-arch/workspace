import 'dart:math';

import '../models/formation.dart';
import '../models/manager_profile.dart';

/// 監督の人事の決まり(目標・立場・引き抜きの補償・経歴の作り方)。
class ManagerHrEngine {
  const ManagerHrEngine._();

  /// 新しく就いた監督の立場(0〜100)。
  static const int startingStanding = 60;

  /// これを割ると「立場が危うい」と報じられる。
  static const int warningStanding = 30;

  /// 目標の順位[target]に対して今[rank]位のとき、1節で立場がどれだけ動くか。
  /// 目標どおりか上なら上がり(3つ以上上なら+3)、下なら下回った分だけ
  /// 下がる(1つにつき1.5、最大6)。
  static int standingDelta({required int rank, required int target}) {
    final diff = rank - target;
    if (diff <= -3) return 3;
    if (diff <= 0) return 2;
    return -min(6, (diff * 1.5).ceil());
  }

  /// 季の終わりに目標を果たしたら、立場に上乗せする分。
  static int seasonEndBonus({required int rank, required int target}) =>
      rank <= target ? 10 : 0;

  /// 他のクラブの監督を引き抜くときの補償金(5部の物差しの万円)。
  /// 残りの契約の年俸の半分。
  static int compensation({required int weeklyWage, required int contractYears}) =>
      (weeklyWage * 52 * contractYears * 0.5).round();

  /// 監督の解任の違約金の率(残りの契約の年俸に対して)。監督は全額。
  static const double managerSeveranceRate = 1.0;

  /// 候補の監督の経歴を作る。[clubs]から選んだクラブで、1〜4季。
  /// [season]は今の季が終わる年。
  static ManagerProfile randomProfile(
    Random rng, {
    required List<({String name, int tier})> clubs,
    required int season,
    String? employerClubId,
    String? employerClubName,
    int compensation = 0,
  }) {
    final style = ManagerStyle.values[rng.nextInt(ManagerStyle.values.length)];
    // 布陣は、よく使われる4つに寄せる(珍しい布陣ばかりだと選手が合わない)。
    const common = [
      Formation.f442,
      Formation.f433,
      Formation.f4231,
      Formation.f352,
    ];
    final formation = rng.nextInt(4) == 0
        ? Formation.values[rng.nextInt(Formation.values.length)]
        : common[rng.nextInt(common.length)];
    final career = <ManagerSpell>[];
    if (clubs.isNotEmpty) {
      final n = 1 + rng.nextInt(4);
      var club = clubs[rng.nextInt(clubs.length)];
      for (var i = n; i >= 1; i--) {
        // 2季ごとくらいにクラブを変える。
        if (i != n && rng.nextBool()) club = clubs[rng.nextInt(clubs.length)];
        career.add(ManagerSpell(
          club: club.name,
          season: season - i,
          rank: 1 + rng.nextInt(18),
          teams: 18,
          tier: club.tier,
        ));
      }
    }
    if (employerClubName != null) {
      // 今のクラブでの直近の季。
      career.add(ManagerSpell(
        club: employerClubName,
        season: season,
        rank: 1 + rng.nextInt(8),
        teams: 18,
        tier: clubs
                .where((c) => c.name == employerClubName)
                .map((c) => c.tier)
                .firstOrNull ??
            1,
      ));
    }
    return ManagerProfile(
      style: style,
      formation: formation,
      career: career,
      employerClubId: employerClubId,
      employerClubName: employerClubName,
      compensation: compensation,
    );
  }
}
