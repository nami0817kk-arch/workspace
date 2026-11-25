import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/ending.dart';
import '../engine/play_views.dart';
import '../engine/rng.dart';
import '../monetization/purchase_service.dart';
import 'pixel_castle.dart';
import 'test_birth_screen.dart';
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
              // 題字を長押しすると、試験用の生まれの画面（`TestBirthScreen`）が開く。TestFlight のビルドだけ（`AppController.testTools`）。
              GestureDetector(
                onLongPress: !c.testTools
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => TestBirthScreen(c)),
                      ),
                child: const Text(
                  '乱世下剋上',
                  style: TextStyle(
                    fontSize: 38,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w700,
                  ),
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
              if (c.lifeCount > 0) ...[
                const SizedBox(height: 12),
                BigButton(
                  'これまでの人生　${c.lifeCount}人',
                  c.openLives,
                  secondary: true,
                ),
              ],
              const SizedBox(height: 12),
              BigButton('遊び方', c.openGuide, secondary: true),
              const SizedBox(height: 18),
              AdFreeRow(c),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「広告を消す」と「購入を復元」（審査で、復元の導線が要る）。
class AdFreeRow extends StatefulWidget {
  const AdFreeRow(this.c, {super.key});
  final AppController c;

  @override
  State<AdFreeRow> createState() => _AdFreeRowState();
}

class _AdFreeRowState extends State<AdFreeRow> {
  bool _busy = false;

  Future<void> _run(Future<PurchaseOutcome> Function() f, bool restore) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await f();
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = switch (r) {
      PurchaseOutcome.purchased => '広告を消した。ありがとう。',
      PurchaseOutcome.pending => '承認を待っている。承認されると、広告が消える。',
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable =>
        restore ? '戻せる購入が見つからなかった。' : 'いまは購入できない。',
      PurchaseOutcome.failed => 'うまくいかなかった。少し置いて、もう一度試してほしい。',
    };
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (c.adFree) {
      return const Text(
        '広告は消してある。',
        style: TextStyle(color: Pal.muted, fontSize: 12),
      );
    }
    const style = TextStyle(fontSize: 13);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          onPressed: _busy ? null : () => _run(c.buyRemoveAds, false),
          child: const Text('広告を消す', style: style),
        ),
        TextButton(
          onPressed: _busy ? null : () => _run(c.restorePurchases, true),
          child: const Text('購入を復元', style: style),
        ),
      ],
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
    // 稀な生まれ（万に一人以上か、稀・幻の特性）だけ、引いた瞬間を特別に見せる（`play_views.dart`）。
    final head = specialBirthHead(b);
    final special = head != null;
    final born = Column(
      children: [
        if (head != null) ...[_SpecialHead(head), const SizedBox(height: 12)],
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
        Text(b.cls.d, style: const TextStyle(color: Pal.muted, fontSize: 13)),
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
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: special ? 38 : 30,
            color: Pal.gold,
            fontWeight: special ? FontWeight.w800 : FontWeight.w600,
            shadows: special
                ? const [Shadow(color: Color(0x99E8B84A), blurRadius: 14)]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          rarityText(b.rarity),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: special ? Pal.gold : Pal.muted,
            fontSize: special ? 16 : null,
            fontWeight: special ? FontWeight.w600 : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '（身分・国・性別・生まれ順と、\n際立った才・特性が、すべて揃う確率）\n'
          '戦国の日本で同じ身分に生まれた者は、約${fmtN(b.sameClass)}人',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Pal.muted, fontSize: 12, height: 1.7),
        ),
      ],
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            // 生まれが変われば（引き直し）、演出もはじめから（振動も一度ずつ）。
            if (special)
              _SpecialBirthFx(key: ObjectKey(b), child: born)
            else
              born,
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

/// 稀な生まれの見出し（金の札）。
class _SpecialHead extends StatelessWidget {
  const _SpecialHead(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFB8862A), Pal.gold, Color(0xFFB8862A)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '✦ $text ✦',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFFFF8E6),
        fontSize: 14.5,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 稀な生まれの演出。金の縁と光が広がり、引いた瞬間に一度だけ強く振動する。ふつうの生まれには使わない。
class _SpecialBirthFx extends StatefulWidget {
  const _SpecialBirthFx({super.key, required this.child});
  final Widget child;

  @override
  State<_SpecialBirthFx> createState() => _SpecialBirthFxState();
}

class _SpecialBirthFxState extends State<_SpecialBirthFx> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, t, child) => Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Pal.gold.withValues(alpha: t), width: 2),
          gradient: RadialGradient(
            radius: .9 + .3 * t,
            colors: [
              const Color(0xFFFFE7A3).withValues(alpha: .5 * t),
              const Color(0x00FFE7A3),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8B84A).withValues(alpha: .45 * t),
              blurRadius: 26 * t,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
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
