import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/ending.dart';
import '../engine/rng.dart';
import 'pixel_castle.dart';
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
              // 背の低い画面（iPhone SE など）でも籤の釦が見えるよう、絵の高さを画面の4分の1ほどに抑える。
              LayoutBuilder(
                builder: (context, box) {
                  final byHeight =
                      MediaQuery.sizeOf(context).height *
                      .25 *
                      kTitleArtW /
                      kTitleArtH;
                  var w = box.maxWidth < 340 ? box.maxWidth : 340.0;
                  if (byHeight < w) w = byHeight;
                  return TitleArt(width: w);
                },
              ),
              const SizedBox(height: 20),
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
                '身分も、国も、才も、選べない。\n選べるのは、生まれる性別と、人生の岐路だけ。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.8),
              ),
              const SizedBox(height: 14),
              Text(
                '天下を狙うも、名もなき幸せを選ぶも、\nあなた次第。乱世はやがて終わり、\n泰平の世が来る。人生は、命の尽きるまで続く。\nこの世には、${kHandEndings.length}の最期がある。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Pal.muted,
                  fontSize: 13,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 28),
              SexPicker(c),
              const SizedBox(height: 14),
              BigButton('運命の籤を引く', c.draw),
              if (c.hasSave) ...[
                const SizedBox(height: 12),
                BigButton('続きから', c.resume, secondary: true),
              ],
              if (c.dexCount > 0) ...[
                const SizedBox(height: 12),
                BigButton(
                  '最期の図鑑　${c.dexCount} ／ ${kHandEndings.length}',
                  c.openDex,
                  secondary: true,
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
                  TraitList(b.traits),
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
              '（身分・国・性別・生まれ順と、\n際立った才・特性が、すべて揃う確率）\n'
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
            const SizedBox(height: 10),
            // 生まれる前なら、何度でも籤を引き直せる（2026-11-23 ユーザー指示）。
            BigButton('籤を引き直す', c.draw, secondary: true),
            if (c.redraws > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '引き直し　${c.redraws}度目',
                  style: const TextStyle(color: Pal.muted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 生まれる性別を選ぶ（2026-11-23 ユーザー「男か女は選べるように」）。運に任せることもできる。
class SexPicker extends StatelessWidget {
  const SexPicker(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, bool? v) {
      final on = c.sexChoice == v;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: on ? Pal.accent.withValues(alpha: .12) : Pal.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: on ? Pal.accent : Pal.line,
                width: on ? 1.6 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => c.chooseSex(v),
              child: SizedBox(
                height: 42,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      letterSpacing: 1,
                      color: on ? Pal.accent : Pal.ink,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          '生まれる性別',
          style: TextStyle(color: Pal.muted, fontSize: 12.5, letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        Row(children: [item('男', false), item('女', true), item('運に任せる', null)]),
      ],
    );
  }
}
