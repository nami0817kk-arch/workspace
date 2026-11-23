import 'game.dart';
import 'rng.dart';

/// 手書きの最期（最期の場面1000本、2026-11-23 決定）。
///
/// - 一本ずつ、道（`kWays` のキー）・死に方（`kDeathKinds` のキー。null ならどれでも）・希少度・称号・最期の文・条件を持つ。
/// - 条件に合う手書きの最期のうち、**いちばん条件の細かいもの**（[EndingDef.spec] が大きいもの）が出る。
///   同じ細かさが並んだら、その人生の名と生年で決まる一本（遊ぶたびには変わらない）。
/// - 合うものがなければ、`ending.dart` の組み立て（道×死に方×幸福）に落ちる。
/// - 図鑑では、手書きの最期は `hand:<id>` の鍵で数える。
///
/// 本数の配分（CLAUDE.md）: 幼くして40／村70／商い70／仏門80／忍び・流れ者・野盗90／足軽・侍130／城主・家老150／
/// 大名・下剋上180／天下人70／女の道120。いまは幼くして40本（`endings_young.dart`）。

/// 希少度（よくある500・珍しい300・稀150・幻50）。
enum Tier { common, uncommon, rare, phantom }

const kTierNames = {
  Tier.common: 'よくある最期',
  Tier.uncommon: '珍しい最期',
  Tier.rare: '稀な最期',
  Tier.phantom: '幻の最期',
};

class EndingDef {
  const EndingDef({
    required this.id,
    required this.way,
    required this.tier,
    required this.title,
    required this.text,
    required this.cond,
    this.kinds,
    this.spec = 1,
  });

  final String id, way;

  /// 当てはまる死に方。null ならどれでも。
  final Set<String>? kinds;
  final Tier tier;
  final String title;

  /// 最期の文。{名}{歳}{年}{元号}{国}{友}{子} を、その人生の値で置き換える。
  final String text;
  final bool Function(Game g) cond;

  /// 条件の細かさ。大きいほど優先する。
  final int spec;
}

/// 最期の文の差し込み。
String fillEnding(Game g, String t) {
  final l = g.l;
  final friend = l.people['幼なじみ']?.name ?? '幼なじみ';
  return t
      .replaceAll('{名}', l.name)
      .replaceAll('{歳}', '${g.age}')
      .replaceAll('{年}', '${g.year}')
      .replaceAll('{元号}', gengo(g.year))
      .replaceAll('{国}', l.region)
      .replaceAll('{友}', friend)
      .replaceAll('{子}', l.female ? '娘' : '子');
}

/// 条件に合う手書きの最期を探す。なければ null。
EndingDef? findHandEnding(
  Game g,
  String way,
  String kind,
  List<EndingDef> catalog, {
  bool Function(EndingDef e)? eraFits,
}) {
  // [eraFits]: 泰平の世まで生きて亡くなった人には、「乱世を生き抜いた」最期（kinds に era を持つもの）も
  // 候補に入れる（`ending.dart` の `eraEndingFits`）。どれが出るかは、ほかの最期と同じく細かさで決まる。
  final cands = [
    for (final e in catalog)
      if (e.way == way &&
          (e.kinds == null ||
              e.kinds!.contains(kind) ||
              (eraFits != null && e.kinds!.contains('era') && eraFits(e))) &&
          e.cond(g))
        e,
  ];
  if (cands.isEmpty) return null;
  final top = cands.map((e) => e.spec).reduce((a, b) => a > b ? a : b);
  final best = cands.where((e) => e.spec == top).toList();
  // 同じ細かさなら、その人生の名と生年で決まる一本。
  var h = g.l.startYear;
  for (final c in g.l.name.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return best[h % best.length];
}
