import 'birth.dart';
import 'data.dart';
import 'life.dart';

/// 画面の見せ方の判定（2026-11-25）。画面に依存しない形にして、純 Dart のテストで見る。

// ---------- 縁の深さ（人物タブの縁のある人の欄） ----------

/// 絆（`Person.bond`、0〜100）を言葉で。数字は出さない。
/// 縁の物語（`bonds.dart`）は 50 を境に筋が分かれるので、50 を「打ち解けた仲」の下の端にそろえる。
String bondWord(int bond) {
  if (bond >= 80) return '深い絆';
  if (bond >= 50) return '打ち解けた仲';
  if (bond >= 25) return 'ぎこちない';
  return '冷えた仲';
}

// ---------- 見聞録の絞り込み ----------

enum LogFilter {
  all('すべて'),
  self('自分のこと'),
  world('世の動き'),
  people('縁のある人');

  const LogFilter(this.label);
  final String label;
}

/// 世の動きの行か。史実の年表と勢力の小競り合いは、どちらも文の頭に【世】を付けて書いている
/// （`history.dart` の `applyHistory`・`Game._simWorld`。kind は 'big' と '' で揃っていないので、文の頭で見る）。
bool isWorldLog(LogEntry e) => e.txt.startsWith('【世】');

/// 見聞録の一行が、絞り込み [f] に当たるか。[names] はいま縁のある人の名（`Life.people` の name）。
bool logMatches(LogFilter f, LogEntry e, Iterable<String> names) => switch (f) {
  LogFilter.all => true,
  LogFilter.world => isWorldLog(e),
  LogFilter.self => !isWorldLog(e),
  LogFilter.people => names.any((n) => n.isNotEmpty && e.txt.contains(n)),
};

/// 見聞録を絞り込む（新しい順のまま）。
List<LogEntry> filterLog(LogFilter f, List<LogEntry> log, Life l) {
  final names = [for (final p in l.people.values) p.name];
  return [
    for (final e in log)
      if (logMatches(f, e, names)) e,
  ];
}

// ---------- 稀な生まれ ----------

/// 生まれの稀少度がこれ以上なら、引いた瞬間を特別に見せる（万に一人。`rarityText` の段と同じ）。
const kSpecialBirthRarity = 1e4;

/// 稀な生まれか（稀少度が [kSpecialBirthRarity] 以上か、稀・幻の特性を持つ）。ふつうの生まれは見た目を変えない。
bool isSpecialBirth(Birth b) =>
    b.rarity >= kSpecialBirthRarity ||
    b.traits.any((t) => t.tier == TraitTier.rare || t.tier == TraitTier.mythic);

/// 稀な生まれの見出し（幻の特性・百万に一人が最上）。ふつうの生まれは null。
String? specialBirthHead(Birth b) {
  if (!isSpecialBirth(b)) return null;
  final myth = b.traits.where((t) => t.tier == TraitTier.mythic).toList();
  if (myth.isNotEmpty) return '幻の才「${myth.first.name}」を持って生まれた';
  if (b.rarity >= 1e6) return '天に選ばれし生まれ';
  final rare = b.traits.where((t) => t.tier == TraitTier.rare).toList();
  if (rare.isNotEmpty && b.rarity < kSpecialBirthRarity) {
    return '稀なる才「${rare.first.name}」を持って生まれた';
  }
  return '稀なる生まれ';
}
