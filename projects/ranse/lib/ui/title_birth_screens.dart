import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/rng.dart';
import 'theme.dart';
import 'widgets.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '乱世下剋上',
                style: TextStyle(
                  fontSize: 38,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '戦国の世に、およそ千五百万の民がいた。\nあなたは、そのうちの一人として生まれる。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Pal.muted, height: 1.8),
              ),
              const SizedBox(height: 14),
              const Text(
                '身分も、国も、性別も、才も、選べない。\n選べるのは、その人生の岐路だけ。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.8),
              ),
              const SizedBox(height: 14),
              const Text(
                '目標：成り上がり、天下の過半を握れ。\nただし乱世は1600年で終わる。\nそれとも、名もなき幸せを選ぶか。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Pal.muted, fontSize: 13, height: 1.8),
              ),
              const SizedBox(height: 36),
              BigButton('運命の籤を引く', c.draw),
              if (c.hasSave) ...[
                const SizedBox(height: 12),
                BigButton('続きから', c.resume, secondary: true),
              ],
              if (c.best > 0) ...[
                const SizedBox(height: 18),
                Text(
                  'これまでの最高：${c.best}点',
                  style: const TextStyle(color: Pal.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BirthScreen extends StatelessWidget {
  const BirthScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final b = c.birth;
    if (b == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('運命の糸をたぐっている…', style: TextStyle(color: Pal.muted)),
                const SizedBox(height: 24),
                Text(
                  c.flick,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Pal.muted,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final rk = b.female ? kRanksF : kRanksM;
    final s = b.stats;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            Text(
              '${b.startYear}年（${gengo(b.startYear)}）${b.month}月${b.day}日、${b.region.n}国に生を受ける',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              b.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${b.female ? '女' : '男'}・${ordLabel(b.female, b.order)}　／　${b.label}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              b.cls.d,
              style: const TextStyle(color: Pal.muted, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              '${b.faction}家の領内。${b.birthRank >= 1 ? '十五で「${rk[b.birthRank]}」の身分を得る' : '十五の時点で身分はない'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gauge('武', s.bu.toDouble(), labelWidth: 36),
                  Gauge('知', s.chi.toDouble(), labelWidth: 36),
                  Gauge('政', s.sei.toDouble(), labelWidth: 36),
                  Gauge('魅', s.mi.toDouble(), labelWidth: 36),
                  Gauge('運', s.un.toDouble(), labelWidth: 36),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (b.traits.isEmpty)
                        const Text(
                          '特性なし',
                          style: TextStyle(color: Pal.muted, fontSize: 13),
                        )
                      else
                        for (final t in b.traits) Tag(t.name),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '約 ${fmtN(b.rarity)} 分の 1',
              style: const TextStyle(
                fontSize: 30,
                color: Pal.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rarityText(b.rarity),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.muted),
            ),
            const SizedBox(height: 6),
            Text(
              '（身分・国・性別・生まれ順・生年月日・\n能力・特性が、すべて揃う確率）\n'
              '戦国の日本で同じ身分に生まれた者は、約${fmtN(b.sameClass)}人',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Pal.muted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            BigButton('この人生を生きる', c.begin),
          ],
        ),
      ),
    );
  }
}
