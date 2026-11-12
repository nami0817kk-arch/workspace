/// 記録帳の1件。
class RecordEntry {
  const RecordEntry(this.value, this.name, this.season);
  final double value;
  final String name;
  final int season;

  List<Object> toJson() => [value, name, season];
  static RecordEntry fromJson(List j) => RecordEntry((j[0] as num).toDouble(), j[1] as String, j[2] as int);
}

/// 記録の種類(表示名と、値の見せ方)。
const recordLabels = <String, String>{
  'g_pts': '1試合の得点',
  'g_reb': '1試合のリバウンド',
  'g_ast': '1試合のアシスト',
  'g_stl': '1試合のスティール',
  'g_blk': '1試合のブロック',
  's_wins': 'シーズンの勝ち数(自分のチーム)',
  's_streak': '連勝(自分のチーム)',
  's_ppg': 'シーズンの平均得点',
  's_rpg': 'シーズンの平均リバウンド',
  's_apg': 'シーズンの平均アシスト',
};

String recordText(String key, double v) => key.startsWith('s_') && key != 's_wins' && key != 's_streak' ? v.toStringAsFixed(1) : v.round().toString();
