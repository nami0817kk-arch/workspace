import 'ending.dart';
import 'game.dart';

/// これまでの人生の一人ぶんの記録（2026-11-25）。
///
/// 人生が終わるたびに一件、タイトルの「これまでの人生」に新しい順で並ぶ（保存は `SaveStore.recordLife`）。
/// 最期の図鑑（`DexEntry`。最期の種類ごとに一件）とは別のもの。こちらは生きた人ごとに一件。
class LifeRecord {
  LifeRecord({
    required this.name,
    required this.female,
    required this.birth,
    required this.region,
    required this.born,
    required this.died,
    required this.age,
    required this.rarity,
    required this.title,
    required this.tier,
    required this.way,
    required this.kind,
    required this.cause,
    required this.text,
    this.path = const [],
  });

  final String name;
  final bool female;

  /// 生まれ（「足軽の家の次男」などの身分の呼び名）と国。
  final String birth, region;

  /// 生年・亡くなった年・享年。
  final int born, died, age;

  /// 生まれの稀少度（約◯分の1）。
  final double rarity;

  /// 最期の称号と、最期の希少度（よくある・珍しい・稀・幻。組み立ての最期なら null）。
  final String title;
  final String? tier;

  /// 道の名と、死に方の名（天寿・戦死・天下統一 など）。
  final String way, kind;

  /// 死因の一行（`Life.dead`。天下統一なら「天下を統一した」）と、最期の文。
  final String cause, text;

  /// 歩んだ道（`Life.path` の終わりの数行）。
  final List<String> path;

  /// 同じ人生を二度記さないための印（名・生年・没年・死因）。
  String get id => '$name|$born|$died|$cause';

  static const kPathLines = 6;

  /// 終わった人生から作る。[e] を渡さなければ、ここで最期を組み立てる。
  factory LifeRecord.of(Game g, [Ending? e]) {
    final l = g.l;
    final end = e ?? buildEnding(g);
    final path = l.path.length > kPathLines
        ? l.path.sublist(l.path.length - kPathLines)
        : [...l.path];
    return LifeRecord(
      name: l.name,
      female: l.female,
      birth: l.clsName,
      region: l.region,
      born: l.startYear,
      died: g.year,
      age: g.age,
      rarity: l.rarity,
      title: end.title,
      tier: end.tierName,
      way: end.wayName,
      kind: end.kindName,
      cause: l.dead ?? (l.victory ? '天下を統一した' : '乱世を生き抜いた'),
      text: end.text,
      path: path,
    );
  }

  Map<String, dynamic> toJson() => {
    'n': name,
    'f': female,
    'b': birth,
    'r': region,
    'y0': born,
    'y1': died,
    'a': age,
    'q': rarity,
    't': title,
    if (tier != null) 'tr': tier,
    'w': way,
    'k': kind,
    'c': cause,
    'x': text,
    'p': path,
  };

  /// 古い記録や欠けた項目でも読めるよう、どの項目にも既定値を置く。
  factory LifeRecord.fromJson(Map<String, dynamic> j) => LifeRecord(
    name: j['n'] as String? ?? '名もなき者',
    female: j['f'] as bool? ?? false,
    birth: j['b'] as String? ?? '',
    region: j['r'] as String? ?? '',
    born: (j['y0'] as num?)?.toInt() ?? 0,
    died: (j['y1'] as num?)?.toInt() ?? 0,
    age: (j['a'] as num?)?.toInt() ?? 0,
    rarity: (j['q'] as num?)?.toDouble() ?? 1,
    title: j['t'] as String? ?? '',
    tier: j['tr'] as String?,
    way: j['w'] as String? ?? '',
    kind: j['k'] as String? ?? '',
    cause: j['c'] as String? ?? '',
    text: j['x'] as String? ?? '',
    path: [for (final p in (j['p'] as List? ?? const [])) '$p'],
  );
}

/// これまでの人生の記録の上限（古いものから捨てる）。
const kMaxLifeRecords = 300;

/// 新しい記録 [r] を先頭に足した一覧（新しい順）。先頭と同じ人生なら足さない。上限を越えたら古いものから捨てる。
List<LifeRecord> addLifeRecord(List<LifeRecord> list, LifeRecord r) {
  if (list.isNotEmpty && list.first.id == r.id) return list;
  final out = [r, ...list];
  if (out.length > kMaxLifeRecords) {
    out.removeRange(kMaxLifeRecords, out.length);
  }
  return out;
}
