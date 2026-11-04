// 歴代記録: 架空の名選手10人の通算記録と、自分の順位。
//
// プロに入ってから伸びが小さくなる年でも、「歴代5位まであと120点」と追いかける目標が残るように。
// 名選手は架空(実在の選手の名前・記録は使わない決まり)。記録の大きさは、おすすめどおりに遊んだときの通算
// (得点 中央約3,000・上位1割約4,600・最大約6,800)に合わせ、10位は届きやすく、1位は一生かけて届くかどうか。

/// 歴代記録の種目。
enum AllTimeStat {
  points('通算得点', '点'),
  rebounds('通算リバウンド', ''),
  assists('通算アシスト', ''),
  titles('プロ優勝', '回');

  const AllTimeStat(this.label, this.unit);
  final String label;
  final String unit;
}

/// 架空の名選手。
class Legend {
  const Legend(this.name, this.points, this.rebounds, this.assists, this.titles);
  final String name;
  final int points;
  final int rebounds;
  final int assists;
  final int titles;

  /// 肖像の絵(Gemini で作った架空の顔。`legends` の並びの番号)。
  String get portrait => 'assets/art/legends/legend_${legends.indexOf(this)}.jpg';

  int of(AllTimeStat s) => switch (s) {
        AllTimeStat.points => points,
        AllTimeStat.rebounds => rebounds,
        AllTimeStat.assists => assists,
        AllTimeStat.titles => titles,
      };
}

/// 歴代の名選手(種目ごとに並べ替えて使う)。
const legends = <Legend>[
  Legend('嵐山 剛志', 6400, 1500, 1200, 4),
  Legend('神楽坂 蓮', 5800, 900, 2100, 3),
  Legend('鳴海 大河', 5200, 2300, 700, 5),
  Legend('早乙女 迅', 4900, 1100, 1800, 2),
  Legend('久遠寺 誠', 4500, 2000, 900, 6),
  Legend('東雲 拓真', 4200, 1300, 1500, 2),
  Legend('白銀 哲也', 3900, 1750, 1100, 3),
  Legend('不破 隆之介', 3600, 800, 1650, 1),
  Legend('霧島 慎吾', 3300, 1400, 1300, 4),
  Legend('御子柴 航', 3000, 1000, 1000, 1),
];

/// 歴代の表の1行。`legend` は名選手(自分の行は null)。
typedef AllTimeRow = ({int rank, String name, int value, bool me, Legend? legend});

/// 自分を入れた順位(1始まり)。同じ数なら名選手が上(抜いたことにならない)。
int allTimeRank(AllTimeStat s, int mine) => 1 + legends.where((l) => l.of(s) >= mine).length;

/// 自分の1つ上の名選手(もう1位なら null)。
({String name, int value})? nextLegend(AllTimeStat s, int mine) {
  Legend? best;
  for (final l in legends) {
    if (l.of(s) >= mine && (best == null || l.of(s) < best.of(s))) best = l;
  }
  return best == null ? null : (name: best.name, value: best.of(s));
}

/// 自分を入れた歴代の表(上から11行まで。自分が11位以下でも最後に入れる)。
List<AllTimeRow> allTimeTable(AllTimeStat s, int mine, String myName) {
  final rows = <({String name, int value, bool me, Legend? legend})>[
    for (final l in legends) (name: l.name, value: l.of(s), me: false, legend: l),
    (name: myName, value: mine, me: true, legend: null),
  ]..sort((a, b) {
      final c = b.value.compareTo(a.value);
      if (c != 0) return c;
      return a.me ? 1 : (b.me ? -1 : 0); // 同じ数なら名選手が上
    });
  return [
    for (var i = 0; i < rows.length; i++)
      (rank: i + 1, name: rows[i].name, value: rows[i].value, me: rows[i].me, legend: rows[i].legend)
  ];
}

/// `before` から `after` に増えたときに抜いた名選手の名前(上の順)。
List<String> passedLegends(AllTimeStat s, int before, int after) {
  final passed = legends.where((l) => l.of(s) >= before && l.of(s) < after).toList()
    ..sort((a, b) => b.of(s).compareTo(a.of(s)));
  return [for (final l in passed) l.name];
}

/// 抜いたときの知らせの文(抜いていなければ空)。
List<String> allTimeLines(AllTimeStat s, int before, int after) {
  final names = passedLegends(s, before, after);
  if (names.isEmpty) return const [];
  final rank = allTimeRank(s, after);
  final who = names.length == 1 ? names.first : '${names.first}ら${names.length}人';
  return ['$whoを抜き、${s.label}で歴代$rank位に!'];
}

/// 歴代10位以内に入った種目の数(実績・エンディングに使う)。
int allTimeTop10Count(Map<AllTimeStat, int> mine) =>
    mine.entries.where((e) => e.value > 0 && allTimeRank(e.key, e.value) <= legends.length).length;

/// 状態カードに出す一言: いちばん順位の高い種目と、次の目標までの差。
/// 例「通算得点 歴代6位(5位の早乙女 迅まであと120点)」「通算アシスト 歴代10位まであと340」。記録が無ければ null。
String? allTimeSummary(Map<AllTimeStat, int> mine) {
  AllTimeStat? best;
  var bestRank = 1 << 30, bestGap = 1 << 30;
  for (final e in mine.entries) {
    if (e.value <= 0) continue;
    final rank = allTimeRank(e.key, e.value);
    final gap = (nextLegend(e.key, e.value)?.value ?? e.value) - e.value;
    if (rank < bestRank || (rank == bestRank && gap < bestGap)) {
      best = e.key;
      bestRank = rank;
      bestGap = gap;
    }
  }
  if (best == null) return null;
  final v = mine[best]!;
  final next = nextLegend(best, v);
  final gap = next == null ? 0 : next.value - v + 1;
  if (next == null) return '${best.label} 歴代1位!';
  if (bestRank > legends.length) {
    final tenth = legends.map((l) => l.of(best!)).reduce((a, b) => a < b ? a : b);
    return '${best.label} 歴代10位まであと${tenth - v + 1}${best.unit}';
  }
  return '${best.label} 歴代$bestRank位(${bestRank - 1}位の${next.name}まであと$gap${best.unit})';
}
