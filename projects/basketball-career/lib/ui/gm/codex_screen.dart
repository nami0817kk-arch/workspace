import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/codex.dart';
import '../../gm/profile.dart';
import 'style.dart';

/// 図鑑(2026-11-21 の作り込み B-3)。見つけたものを種類ごとに並べる。未発見は「？？？」。任期をまたいで残る。
class CodexScreen extends StatelessWidget {
  const CodexScreen({super.key, required this.profile, this.career});
  final Profile profile;
  final Career? career;

  @override
  Widget build(BuildContext context) {
    final c = career;
    if (c != null) profile.syncCodex(c);
    final found = profile.codex;
    final total = codexEntries.length, got = codexEntries.where((e) => found.containsKey(e.key)).length;
    return Scaffold(
      appBar: AppBar(title: Text('図鑑  $got / $total')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          children: [
            const Text('遊ぶうちに見つけたものが残る(クビになっても、始め直しても消えない)。まだ見つけていないものは「？？？」。',
                style: TextStyle(fontSize: 12, color: GmColors.sub)),
            for (final k in CodexKind.values) ...[
              const SizedBox(height: 12),
              Text(
                '${k.label}  ${codexEntries.where((e) => e.kind == k && found.containsKey(e.key)).length} / ${codexEntries.where((e) => e.kind == k).length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in codexEntries.where((e) => e.kind == k)) _EntryCard(entry: e, note: found[e.key]),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.note});
  final CodexEntry entry;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final color = n == null ? GmColors.line : entry.good ? GmColors.gold : GmColors.bad;
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: n == null
          ? const Text('？？？', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GmColors.sub))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(entry.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
                if (!entry.good) const Padding(padding: EdgeInsets.only(left: 6), child: Text('失敗の記録', style: TextStyle(fontSize: 10, color: GmColors.bad))),
              ]),
              const SizedBox(height: 2),
              Text(entry.text, style: const TextStyle(fontSize: 11.5, height: 1.35)),
              const SizedBox(height: 2),
              Text(n, style: const TextStyle(fontSize: 10.5, color: GmColors.sub)),
            ]),
    );
  }
}
