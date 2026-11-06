import 'package:flutter/material.dart';

import '../../gm/draft.dart';
import '../../gm/player.dart';
import '../../monetization/monetization.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// ドラフト。候補の力は幅でしか見えない。スカウトを送ると幅が狭まる。
class DraftView extends StatelessWidget {
  const DraftView({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final pick = car.currentPick;
    final open = car.prospects.where((p) => p.pickedBy == null).toList()..sort((a, b) => b.mid.compareTo(a.mid));
    final myPicks = [
      for (var k = car.draftAt; k < car.order.length; k++)
        if (car.picks[car.order[k]].owner == car.mine) k + 1,
    ];
    final taken = [for (var k = car.draftLog.length - 1; k >= 0; k--) (k + 1, car.prospects[car.draftLog[k]])];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.how_to_reg_rounded, color: GmColors.ball),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(pick == null ? 'ドラフト' : '${car.draftAt + 1}番目の指名(${pick.round}巡目)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                  myPicks.isEmpty
                      ? 'このドラフトでは、もう指名権がない。'
                      : 'こちらの指名: ${myPicks.map((k) => '$k番目').join('・')}。候補の力は幅でしか分からない。スカウトを送ると幅が狭まる。',
                  style: const TextStyle(color: GmColors.sub, height: 1.5)),
              if (car.news.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('このオフの知らせ', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final n in car.news) Text('・$n', style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.travel_explore_rounded, size: 18, color: GmColors.sub),
                const SizedBox(width: 6),
                Text('スカウト 残り${car.scoutsLeft}回', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (car.canAddScouts)
                  TextButton.icon(
                    onPressed: c.busy ? null : () => _moreScouts(context),
                    icon: Icon(c.needsAd ? Icons.smart_display_rounded : Icons.add_rounded, size: 18),
                    label: Text(c.needsAd ? '動画で+2回' : '+2回'),
                  ),
              ]),
              if (car.myTurn && car.me.roster.length >= maxRoster) ...[
                const SizedBox(height: 6),
                const Text('登録が15人いっぱい。指名するなら、先にチームの画面で選手を放す。', style: TextStyle(color: GmColors.bad)),
                const SizedBox(height: 6),
                OutlinedButton(onPressed: c.passPick, child: const Text('この指名を見送る')),
              ],
            ]),
          ),
        ),
        SectionTitle('候補(${open.length}人)'),
        for (final p in open) ...[
          _ProspectRow(c: c, p: p),
          const SizedBox(height: 6),
        ],
        if (taken.isNotEmpty) ...[
          const SectionTitle('ここまでの指名'),
          for (final (k, p) in taken)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 34, child: Text('$k', style: const TextStyle(color: GmColors.sub))),
                TeamBadge(team: p.pickedBy!, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text('${p.player.name}(${p.player.pos.short})', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ],
      ],
    );
  }

  Future<void> _moreScouts(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final g = await c.scoutsWithAd(onWaiting: () => messenger.showSnackBar(const SnackBar(content: Text('動画を読み込んでいます…'))));
    if (g == RecoverGate.unavailable) {
      messenger.showSnackBar(const SnackBar(content: Text('動画の準備ができていません。少し待ってからもう一度。')));
    }
  }
}

class _ProspectRow extends StatelessWidget {
  const _ProspectRow({required this.c, required this.p});
  final GmController c;
  final Prospect p;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final pl = p.player;
    final canPick = car.myTurn && car.me.roster.length < maxRoster && !c.busy;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: GmColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.scouted ? GmColors.gold.withValues(alpha: 0.6) : GmColors.line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(width: 6),
              Tag(pl.pos.short),
              const SizedBox(width: 6),
              Text('${pl.age}歳', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              if (p.scouted) ...[const SizedBox(width: 6), const Tag('調査済み', color: GmColors.gold)],
            ]),
            const SizedBox(height: 4),
            _range('今の力', p.ovrLo, p.ovrHi),
            const SizedBox(height: 2),
            _range('伸びしろ', p.potLo, p.potHi),
          ]),
        ),
        const SizedBox(width: 6),
        Column(mainAxisSize: MainAxisSize.min, children: [
          if (!p.scouted)
            SizedBox(
              height: 34,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(72, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: car.scoutsLeft > 0 && !c.busy ? () => c.scoutProspect(p) : null,
                child: const Text('スカウト', style: TextStyle(fontSize: 13)),
              ),
            ),
          if (car.myTurn) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: canPick ? () => c.pickProspect(p) : null,
                child: const Text('指名', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _range(String label, int lo, int hi) => Row(children: [
        SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 12, color: GmColors.sub))),
        Expanded(
          child: LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth;
            double x(int v) => w * ((v - 35) / 65).clamp(0.0, 1.0);
            return SizedBox(
              height: 14,
              child: Stack(children: [
                Positioned(top: 5, left: 0, right: 0, child: Container(height: 4, color: GmColors.line)),
                Positioned(
                  top: 3,
                  left: x(lo),
                  width: (x(hi) - x(lo)).clamp(4.0, w),
                  child: Container(height: 8, decoration: BoxDecoration(color: GmColors.ovr(hi), borderRadius: BorderRadius.circular(4))),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 52, child: Text('$lo〜$hi', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ]);
}
