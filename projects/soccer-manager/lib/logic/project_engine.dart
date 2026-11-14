import '../l10n/tr.dart';

/// 投資案件。お金をかけて、しばらくしてから効果が出る。
enum ClubProject {
  /// ファンアプリ: 週のグッズ収入が増える。
  fanApp,

  /// 公式ショップ: 評判が高いほど週のグッズ収入が増える。
  clubShop,

  /// 提携クラブ: 毎季末に、評判とサポーターの期待がじわじわ上がる。
  partnerClub;

  String get label => switch (this) {
        fanApp => Tr.pick('ファンアプリ', 'Fan app'),
        clubShop => Tr.pick('公式ショップ', 'Official shop'),
        partnerClub => Tr.pick('提携クラブ', 'Partner club'),
      };

  String get summary => switch (this) {
        fanApp => Tr.pick('完成後、グッズ収入が毎週25万円増えます',
            'Once built, merchandise income rises by 25 a week'),
        clubShop => Tr.pick('完成後、評判の4分の1だけ、グッズ収入が毎週増えます',
            'Once built, merchandise rises weekly by a quarter of your reputation'),
        partnerClub => Tr.pick('完成後、毎季末に評判+2・サポーターの期待+1',
            'Once built, each season end gives reputation +2 and supporters +1'),
      };

  /// 費用(万円)。
  int get cost => switch (this) {
        fanApp => 500,
        clubShop => 800,
        partnerClub => 1200,
      };

  /// 完成までのシーズン数。
  int get buildSeasons => switch (this) {
        fanApp => 1,
        clubShop => 1,
        partnerClub => 2,
      };
}

class ProjectEngine {
  const ProjectEngine._();

  /// 完成した案件が週のグッズ収入に足す額。
  static int weeklyMerchandiseBonus(
      Map<String, int> projects, int managerReputation) {
    var sum = 0;
    if (isActive(projects, ClubProject.fanApp)) sum += 25;
    if (isActive(projects, ClubProject.clubShop)) {
      sum += managerReputation.clamp(0, 100) ~/ 4;
    }
    return sum;
  }

  /// 着手していて、完成まで残り0季か。
  static bool isActive(Map<String, int> projects, ClubProject p) =>
      projects[p.name] == 0;

  /// 着手済み(建設中を含む)か。
  static bool started(Map<String, int> projects, ClubProject p) =>
      projects.containsKey(p.name);

  /// 完成まで残りの季数。着手していなければ null。
  static int? seasonsLeft(Map<String, int> projects, ClubProject p) =>
      projects[p.name];

  /// シーズン末に建設を1季進める。この季に完成した案件を返す。
  static List<ClubProject> tick(Map<String, int> projects) {
    final done = <ClubProject>[];
    for (final p in ClubProject.values) {
      final left = projects[p.name];
      if (left == null || left <= 0) continue;
      projects[p.name] = left - 1;
      if (left - 1 == 0) done.add(p);
    }
    return done;
  }
}
