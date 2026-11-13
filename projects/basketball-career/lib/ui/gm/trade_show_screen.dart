import 'package:flutter/material.dart';

import '../../gm/player.dart';
import '../../gm/trade.dart';
import '../../gm/trade_show.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// トレードを成立させ、成立したら中身と効き目の画面を出す。[run] は成立したら true を返す。
bool tradeWithShow(BuildContext context, GmController c, TradeOffer o, bool Function() run) {
  final car = c.career!;
  final snap = tradeSnap(car, o);
  final nav = Navigator.of(context);
  if (!run()) return false;
  nav.push(MaterialPageRoute<void>(builder: (_) => TradeDoneScreen(c: c, r: tradeResult(car, snap))));
  return true;
}

/// トレード成立の画面。出したもの・受け取ったもの・強さの順位・年俸・先発の入れ替わり・値打ちの釣り合い。
class TradeDoneScreen extends StatelessWidget {
  const TradeDoneScreen({super.key, required this.c, required this.r});
  final GmController c;
  final TradeResult r;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final s = r.snap;
    final gradeColor = switch (r.grade) {
      'A' || 'B' => GmColors.good,
      'C' => GmColors.gold,
      _ => GmColors.bad,
    };

    Widget side(String title, Color color, List<Player> ps, List<String> picks) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.6))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              for (final p in ps)
                Text('${p.name}(${p.pos.short}・${p.age}歳・OVR${shown(p.ovr)})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.5)),
              for (final l in picks) Text('指名権 $l', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.5)),
              if (ps.isEmpty && picks.isEmpty) const Text('なし', style: TextStyle(color: GmColors.sub)),
            ]),
          ),
        );

    Widget compare(String label, String before, String after, int better) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
              width: 170,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GmColors.sub, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('$before → $after', style: const TextStyle(fontWeight: FontWeight.bold))),
            if (better != 0)
              Icon(better > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 18, color: better > 0 ? GmColors.good : GmColors.bad),
          ]),
        );

    final up = s.rank - r.rankAfter;
    return Scaffold(
      appBar: AppBar(title: Text('${car.teams[s.partner].name}とのトレード成立'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                side('出した', GmColors.bad, s.give, s.givePicks),
                const SizedBox(width: 8),
                side('受け取った', GmColors.good, s.get, s.getPicks),
              ]),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gradeColor, width: 2.5)),
                      child: Text(r.grade, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: gradeColor)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('評価: ${r.label}', style: TextStyle(fontWeight: FontWeight.bold, color: gradeColor, fontSize: 16)),
                        Text(r.note, style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SectionTitle('チームの変化'),
              compare('自分の強さ', '${s.rank + 1}位', '${r.rankAfter + 1}位', up),
              compare('${car.teams[s.partner].def.short}の強さ', '${s.partnerRank + 1}位', '${r.partnerRankAfter + 1}位', 0),
              compare('年俸の合計', money(s.payroll), money(r.payrollAfter), 0),
              if (r.payrollAfter > taxLine && s.payroll <= taxLine)
                const Text('ぜいたく税の線を超えた。シーズンの終わりに税がかかる。', style: TextStyle(fontSize: 12, color: GmColors.bad)),
              if (r.payrollAfter <= taxLine && s.payroll > taxLine)
                const Text('ぜいたく税の線を下回った。', style: TextStyle(fontSize: 12, color: GmColors.good)),
              if (r.newStarters.isNotEmpty || r.lostStarters.isNotEmpty) ...[
                const SectionTitle('先発の入れ替わり'),
                if (r.newStarters.isNotEmpty) Text('先発に入る: ${r.newStarters.join('・')}', style: const TextStyle(color: GmColors.good, height: 1.5)),
                if (r.lostStarters.isNotEmpty) Text('先発から外れる: ${r.lostStarters.join('・')}', style: const TextStyle(color: GmColors.sub, height: 1.5)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('閉じる')),
            ),
          ),
        ]),
      ),
    );
  }
}
