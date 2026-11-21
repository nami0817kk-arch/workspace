import 'career.dart';
import 'combos.dart';
import 'draft.dart';
import 'game_sim.dart';
import 'personality.dart';
import 'player.dart';
import 'potential_view.dart';

/// 図鑑(2026-11-21 の作り込み B-3)。遊ぶうちに見つけたもの(組み合わせ・方針の相性・伸び方の型・隠れた特性・ドラフトの年)を残す。
/// 任期をまたいで残る(プロフィールに持つ)。ごほうびは付けない(ユーザー「ご褒美はいらない」)。未発見は「？？？」。

enum CodexKind {
  combo('組み合わせ'),
  matchup('方針の相性'),
  growth('伸び方の型'),
  trait('隠れた特性'),
  draft('ドラフトの年');

  const CodexKind(this.label);
  final String label;
}

/// 図鑑の1項目。[good] が false なら「失敗の記録」(悪い組み合わせ・不作の年など)。
class CodexEntry {
  const CodexEntry(this.key, this.kind, this.title, this.text, {this.good = true});
  final String key;
  final CodexKind kind;
  final String title, text;
  final bool good;
}

/// 図鑑の全部の項目。
final List<CodexEntry> codexEntries = [
  for (final x in Combo.values) CodexEntry('combo:${x.name}', CodexKind.combo, x.label, x.text, good: x.good),
  for (final x in Matchup.values) CodexEntry('match:${x.name}', CodexKind.matchup, x.label, x.edge > 0 ? '攻める側が有利になる' : '守る側が有利になる'),
  for (final x in GrowthType.values)
    if (x != GrowthType.normal) CodexEntry('growth:${x.name}', CodexKind.growth, x.label, x.text, good: x != GrowthType.bust),
  for (final x in Trait.values)
    if (!visibleTraits.contains(x) && x != Trait.lateBloomer)
      CodexEntry('trait:${x.name}', CodexKind.trait, x.label, x.text, good: x != Trait.troublemaker && x != Trait.fragile),
  const CodexEntry('draft:good', CodexKind.draft, '豊作の年', '上の方の候補の層が厚い'),
  const CodexEntry('draft:bad', CodexKind.draft, '不作の年', '上の方でも当たり外れが大きい', good: false),
  const CodexEntry('draft:star', CodexKind.draft, '目玉のいる年', '1人、飛び抜けた候補がいる'),
  const CodexEntry('draft:pos', CodexKind.draft, '得意なポジションの年', 'あるポジションに良い候補が多い'),
];

/// [c] のキャリアで見つけたもの(項目の key → いつ・何で見つけたか)。
Map<String, String> discoveriesOf(Career c) {
  final out = <String, String>{};
  final team = c.me.def.short;
  for (final x in c.combosFound) {
    out['combo:${x.name}'] = '${c.season}年目・$teamで${c.comboSecs[x.index] ~/ 60}分一緒に出て分かった';
  }
  for (final x in c.matchupsFound) {
    out['match:${x.name}'] = '${c.season}年目・試合で${c.matchupSeen[x.index]}回確かめた';
  }
  final everyone = <int, Player>{
    for (final t in c.teams) ...{for (final p in [...t.roster, ...t.twoWay]) p.id: p},
    for (final p in c.freeAgents) p.id: p,
  };
  for (final id in c.growthKnown) {
    final p = everyone[id];
    if (p == null) continue;
    final g = growthTypeOf(p);
    if (g == GrowthType.normal) continue;
    out.putIfAbsent('growth:${g.name}', () => '${c.season}年目・${p.name}で分かった');
  }
  for (final p in [...c.me.roster, ...c.me.twoWay]) {
    for (final t in traitsShown(c, p).$1) {
      if (visibleTraits.contains(t)) continue;
      out.putIfAbsent('trait:${t.name}', () => '${c.season}年目・${p.name}で分かった');
    }
  }
  // ドラフトの年: 終わったドラフト(今季のドラフトは、指名が始まってから)
  final last = c.phase == Phase.draft || c.phase == Phase.contracts || c.phase == Phase.over ? c.season : c.season - 1;
  for (var s = 1; s <= last; s++) {
    final d = draftClassOf(c.seed, s);
    if (d.quality == 1) out.putIfAbsent('draft:good', () => '$s年目のドラフト');
    if (d.quality == -1) out.putIfAbsent('draft:bad', () => '$s年目のドラフト');
    if (d.star) out.putIfAbsent('draft:star', () => '$s年目のドラフト');
    if (d.strongPos != null) out.putIfAbsent('draft:pos', () => '$s年目のドラフト(${d.strongPos!.label})');
  }
  return out;
}
