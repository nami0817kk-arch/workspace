import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../engine/ending.dart';
import '../engine/game.dart';
import '../engine/rng.dart';
import 'theme.dart';
import 'widgets.dart';

/// 一生の終わり。人生の振り返りを見せる。
class EndScreen extends StatelessWidget {
  const EndScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final l = g.l;
    final child = g.age < 15;
    final e = buildEnding(g);
    final aj = g.avgJoy;
    final head = child ? '幼き命' : (l.victory ? '天下統一' : '一生の終わり');
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          children: [
            Text(
              head,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _ResultCard(g: g, e: e),
            if (c.newEnding)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '図鑑に、新しい最期が記された。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Pal.good),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shareText(g, e)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('結果を写した。SNS に貼り付けられる。')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18, color: Pal.gold),
                label: const Text('結果を写す', style: TextStyle(color: Pal.gold)),
              ),
            ),
            const SizedBox(height: 16),
            Panel(
              title: '人生の軌跡',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LifeChart(l.hist),
                  const SizedBox(height: 10),
                  Text(
                    '平均の幸福度は${aj.round()}。',
                    style: const TextStyle(color: Pal.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  KV('最高位', child ? '—' : g.rk[l.maxRank]),
                  KV('功', '${l.merit}'),
                  KV('名声', '${l.fame}'),
                  KV('滅ぼした家', '${l.conq}'),
                  KV('子', '${l.kids}人'),
                  KV('銭', '${l.gold}貫'),
                  const SizedBox(height: 8),
                  Text(
                    '生まれの稀少度：約${fmtN(l.rarity)}分の1／同じ身分の者は約${fmtN(l.sameClass)}人',
                    style: const TextStyle(color: Pal.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (l.path.isNotEmpty) ...[
              const SizedBox(height: 14),
              Panel(
                title: '歩んだ道',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in l.path)
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
            const SizedBox(height: 14),
            Text(
              'スコア ${g.score}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, color: Pal.gold),
            ),
            if (c.newBest)
              const Text(
                '最高記録を更新した！',
                textAlign: TextAlign.center,
                style: TextStyle(color: Pal.good),
              ),
            const SizedBox(height: 14),
            Panel(title: '最期のころ', child: LogList(l.log.take(8).toList())),
            const SizedBox(height: 20),
            BigButton('新たな生を引く', c.draw),
            const SizedBox(height: 10),
            BigButton('タイトルへ', c.toTitle, secondary: true),
          ],
        ),
      ),
    );
  }
}

/// 結果カード。生まれの稀少度・選んだ道・結末の称号（共有する一枚）。
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.g, required this.e});
  final Game g;
  final Ending e;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Pal.panel,
        border: Border.all(color: Pal.gold.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '約 ${fmtN(l.rarity)} 分の 1 の生まれ',
            style: const TextStyle(color: Pal.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${l.region}国・${l.clsName}　${l.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (e.highlights.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final h in e.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            e.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              color: Pal.gold,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${e.wayName}・${e.kindName}',
            style: const TextStyle(color: Pal.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(e.text, style: const TextStyle(fontSize: 14, height: 1.8)),
        ],
      ),
    );
  }
}
