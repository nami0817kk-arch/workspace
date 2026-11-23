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
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '図鑑に、新しい最期が記された（${c.dexCount} ／ ${kHandEndings.length}）。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pal.good),
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
/// 歩んだ道（`kWays` のキー）ごとの絵。Gemini で作り、assets/images/way_<道>.jpg に置く。
/// 10の道すべてにある（2026-11-23）。
const kWayArt = <String, String>{
  'young': 'assets/images/way_young.jpg',
  'village': 'assets/images/way_village.jpg',
  'merchant': 'assets/images/way_merchant.jpg',
  'priest': 'assets/images/way_priest.jpg',
  'shadow': 'assets/images/way_shadow.jpg',
  'samurai': 'assets/images/way_samurai.jpg',
  'castle': 'assets/images/way_castle.jpg',
  'daimyo': 'assets/images/way_daimyo.jpg',
  'tenka': 'assets/images/way_tenka.jpg',
  'woman': 'assets/images/way_woman.jpg',
};

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
          // 歩んだ道の絵（Gemini で作ったドット絵。絵のある道だけ）。
          if (kWayArt[e.way] case final art?) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                art,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          // 称号が一行に少しだけ収まらないと、最後の一、二字だけが次の行に落ちる。
          // 16まで字を小さくして一行に収まるなら、そうする（もっと長い称号は二行に折る）。
          LayoutBuilder(
            builder: (context, box) {
              final n = e.title.length;
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final oneLine = box.maxWidth / (n * scale) - .5;
              final size = oneLine < 22 && oneLine >= 16 ? oneLine : 22.0;
              return Text(
                e.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size,
                  color: Pal.gold,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            '${e.wayName}・${e.kindName}${e.tierName == null ? '' : '　${e.tierName}'}',
            style: const TextStyle(color: Pal.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(e.text, style: const TextStyle(fontSize: 14, height: 1.8)),
        ],
      ),
    );
  }
}
