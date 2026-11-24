import '../l10n/tr.dart';

/// クラブの事業(2026-11-25 の第7段で「投資案件」から改めた)。
///
/// 以前は「投資案件」と呼んでいたが、中身はお金を払って建てる・始める
/// 事業(アプリ・店・建物)で、投資(お金を預けて増やす)ではなかった。
/// いまは「事業」と呼び、始める費用・毎月の収入・回収までの期間・状態を
/// 見せる。本当の投資(定期預金)は同じタブの「投資」の札にある。
///
/// 名前(name)はセーブの `projects` の鍵になる。2026-11-25 より前の
/// `partnerClub`(提携クラブ。系列クラブと紛らわしかった)は、中身が
/// 「毎季、評判とサポーターの期待が少し上がる建物」なので [museum]
/// (クラブ博物館)に改め、[fromStoredName] で読み替える。
enum ClubProject {
  /// ファンアプリ: 毎月のグッズ収入が増える。
  fanApp,

  /// 公式ショップ: 評判が高いほど毎月のグッズ収入が増える。
  clubShop,

  /// クラブ博物館: 毎季末に、評判とサポーターの期待がじわじわ上がる。
  museum;

  /// 保存された名前から引く。2026-11-25 より前の名前も読める。
  static ClubProject? fromStoredName(String name) => switch (name) {
        'partnerClub' => ClubProject.museum,
        _ => ClubProject.values.where((p) => p.name == name).firstOrNull,
      };

  String get label => switch (this) {
        fanApp => Tr.pick('ファンアプリ', 'Fan app'),
        clubShop => Tr.pick('公式ショップ', 'Club shop'),
        museum => Tr.pick('クラブ博物館', 'Club museum'),
      };

  /// 何の事業か(1行)。
  String get summary => switch (this) {
        fanApp => Tr.pick('アプリでグッズを売る。上の部ほど売れる',
            'Sells merchandise through an app. Sells more in higher divisions'),
        clubShop => Tr.pick('スタジアムの店。評判が高いほど売れる',
            'A shop at the ground. Sells more the better your reputation'),
        museum => Tr.pick('お金は生まない。毎季末に評判+2・サポーターの期待+1',
            'Earns nothing. Each season end: reputation +2, supporters +1'),
      };

  /// お金を生む事業か(博物館は生まない)。
  bool get earns => this != museum;

  /// 始める費用(5部の物差しの万円)。
  int get cost => switch (this) {
        fanApp => 500,
        clubShop => 800,
        museum => 1200,
      };

  /// 開業までのシーズン数。
  int get buildSeasons => switch (this) {
        fanApp => 1,
        clubShop => 1,
        museum => 2,
      };
}

class ProjectEngine {
  const ProjectEngine._();

  /// 開業した事業が週のグッズ収入に足す額(商業の倍率を掛ける前)。
  static int weeklyMerchandiseBonus(
      Map<String, int> projects, int managerReputation) {
    var sum = 0;
    if (isActive(projects, ClubProject.fanApp)) sum += 25;
    if (isActive(projects, ClubProject.clubShop)) {
      sum += managerReputation.clamp(0, 100) ~/ 4;
    }
    return sum;
  }

  /// 始めていて、開業まで残り0季か。
  static bool isActive(Map<String, int> projects, ClubProject p) =>
      projects[p.name] == 0;

  /// 始めた(建設中を含む)か。
  static bool started(Map<String, int> projects, ClubProject p) =>
      projects.containsKey(p.name);

  /// 開業まで残りの季数。始めていなければ null。
  static int? seasonsLeft(Map<String, int> projects, ClubProject p) =>
      projects[p.name];

  /// 費用を毎月の収入で割った、元が取れるまでの月数(切り上げ)。収入が
  /// 無ければ null。
  static int? paybackMonths(int cost, int monthlyIncome) =>
      monthlyIncome <= 0 ? null : (cost + monthlyIncome - 1) ~/ monthlyIncome;

  /// 古いセーブの鍵を今の名前へ読み替える。知らない鍵は捨てる。何度
  /// 通しても同じ結果になる(2回読んでも動かない)。
  static Map<String, int> migrate(Map<String, int> stored) {
    final out = <String, int>{};
    for (final e in stored.entries) {
      final p = ClubProject.fromStoredName(e.key);
      if (p == null) continue;
      // 古い鍵と新しい鍵の両方があれば、新しい鍵を正とする。
      if (out.containsKey(p.name) && e.key != p.name) continue;
      out[p.name] = e.value;
    }
    return out;
  }

  /// シーズン末に建設を1季進める。この季に開業した事業を返す。
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
