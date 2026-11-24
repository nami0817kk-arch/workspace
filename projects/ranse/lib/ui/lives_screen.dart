import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../engine/life_record.dart';
import '../engine/rng.dart';
import 'theme.dart';
import 'widgets.dart';

/// これまでの人生（2026-11-25）。終わった人生を一人ずつ新しい順に並べ、押すと詳しく読める。
/// 最期の図鑑（最期の種類ごと）とは別に、生きた人ごとに残す（`SaveStore.recordLife`）。
class LivesScreen extends StatelessWidget {
  const LivesScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final lives = c.lives;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: c.toTitle,
                  icon: const Icon(Icons.arrow_back, color: Pal.ink),
                ),
                const Expanded(
                  child: Text(
                    'これまでの人生',
                    style: TextStyle(fontSize: 20, letterSpacing: 4),
                  ),
                ),
                Text(
                  '${lives.length}人',
                  style: const TextStyle(color: Pal.gold, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: lives.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'まだ誰の人生も記されていない。\n一つの生を生き切ると、ここに記される。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Pal.muted, height: 1.8),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: lives.length,
                    itemBuilder: (context, i) => _LifeTile(lives[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 一覧の一行。名・享年・生まれ・称号。
class _LifeTile extends StatelessWidget {
  const _LifeTile(this.r);
  final LifeRecord r;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Pal.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: tierColor(r.tier)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => LifeDetailScreen(r))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: r.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '　享年${r.age}',
                        style: const TextStyle(color: Pal.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.born}年（${gengo(r.born)}）${r.region}国・${r.birth}',
                  style: const TextStyle(color: Pal.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.tier != null ? '【${r.tier}】' : ''}${r.title}',
                  style: TextStyle(
                    color: tierColor(r.tier) == Pal.line
                        ? Pal.ink
                        : tierColor(r.tier),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 最期の希少度の色（よくある・珍しいは地味に、稀は朱、幻は金）。
Color tierColor(String? tier) {
  if (tier == null) return Pal.line;
  if (tier.startsWith('幻')) return Pal.gold;
  if (tier.startsWith('稀')) return Pal.accent;
  if (tier.startsWith('珍')) return Pal.purple;
  return Pal.line;
}

/// 詳しい画面の一行（呼び名を左に、値を右に。長ければ折り返す）。
class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k, v;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Pal.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: Pal.muted, fontSize: 13.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
      ],
    ),
  );
}

/// 一人ぶんを詳しく読む。
class LifeDetailScreen extends StatelessWidget {
  const LifeDetailScreen(this.r, {super.key});
  final LifeRecord r;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Pal.panel,
        title: Text(r.name, style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: tierColor(r.tier) == Pal.line
                          ? Pal.ink
                          : tierColor(r.tier),
                    ),
                  ),
                  if (r.tier != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        r.tier!,
                        style: const TextStyle(
                          color: Pal.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    r.text,
                    style: const TextStyle(fontSize: 14.5, height: 1.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              title: '生涯',
              child: Column(
                children: [
                  _Row('生まれ', '${r.female ? '女' : '男'}・${r.birth}'),
                  _Row('国', '${r.region}国'),
                  _Row('生年', '${r.born}年（${gengo(r.born)}）'),
                  _Row('没年', '${r.died}年（${gengo(r.died)}）'),
                  _Row('享年', '${r.age}'),
                  _Row('道', r.way),
                  _Row('死に方', r.kind),
                  _Row('生まれの稀少度', '約${fmtN(r.rarity)}分の1'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              title: '最期',
              child: Text(r.cause, style: const TextStyle(height: 1.6)),
            ),
            if (r.path.isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(
                title: '歩んだ道',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in r.path)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          p,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
