import 'package:flutter/material.dart';

import '../../gm/draft.dart';
import '../../gm/player.dart';
import '../../monetization/monetization.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// 候補の並べ方。
enum _Sort { mock, mid, board }

/// ドラフト。候補の力は幅でしか見えない。スカウトを送ると幅が狭まる。
/// 模擬ドラフトの予想順位・経歴・身体測定を見て、自分のボード(注目の印)を作る。
class DraftView extends StatefulWidget {
  const DraftView({super.key, required this.c});
  final GmController c;

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  _Sort _sort = _Sort.mock;

  GmController get c => widget.c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final pick = car.currentPick;
    final ranks = mockRanks(car.prospects);
    final before = car.picksBeforeMine();
    final all = car.prospects.where((p) => p.pickedBy == null).toList();
    final open = switch (_sort) {
      _Sort.mock => all..sort((a, b) => ranks[a]!.compareTo(ranks[b]!)),
      _Sort.mid => all..sort((a, b) => b.mid.compareTo(a.mid)),
      _Sort.board => [
        for (final id in car.board)
          for (final p in all)
            if (p.player.id == id) p,
      ],
    };
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.how_to_reg_rounded, color: GmColors.ball),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pick == null ? 'ドラフト' : '${car.draftAt + 1}番目の指名(${pick.round}巡目)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  myPicks.isEmpty ? 'このドラフトでは、もう指名権がない。' : 'こちらの指名: ${myPicks.map((k) => '$k番目').join('・')}。候補の力は幅でしか分からない。スカウトを送ると幅が狭まる。',
                  style: const TextStyle(color: GmColors.sub, height: 1.5),
                ),
                if (car.news.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('このオフの知らせ', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final n in car.news) Text('・$n', style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
                const SizedBox(height: 6),
                Text(
                  myPicks.isEmpty
                      ? 'やること: 何もない。他チームの指名が終わるまで進める。'
                      : 'やること: 候補から欲しい選手を選び「指名」を押す(分からなければ、予想順位が高い選手でよい)。自分の番まで自動で進む。',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GmColors.gold, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
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
                  ],
                ),
                if (before != null && before > 0) ...[
                  const SizedBox(height: 6),
                  Text('次の指名まで、ほかのチームが$before人取る。予想$before位までの候補は、先に取られそう。', style: const TextStyle(fontSize: 12, color: GmColors.gold, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Text('契約中の選手 ${car.signedCount}人(オフは$offseasonRoster人まで。契約が切れる選手は数えない。開幕までに$maxRoster人にする)',
                    style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                if (car.myTurn && car.draftProblem != null) ...[
                  const SizedBox(height: 6),
                  Text(car.draftProblem!, style: const TextStyle(color: GmColors.bad)),
                  const SizedBox(height: 6),
                  OutlinedButton(onPressed: c.passPick, child: const Text('この指名を見送る')),
                ],
              ],
            ),
          ),
        ),
        SectionTitle(_sort == _Sort.board ? '自分のボード(${open.length}人)' : '候補(${all.length}人)'),
        Wrap(
          spacing: 6,
          children: [
            for (final (s, label) in [(_Sort.mock, '予想順'), (_Sort.mid, '見込み順'), (_Sort.board, '注目だけ(${car.board.length})')])
              ChoiceChip(label: Text(label), selected: _sort == s, onSelected: (_) => setState(() => _sort = s)),
          ],
        ),
        const SizedBox(height: 8),
        if (_sort == _Sort.board && open.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('候補の☆を押すと、ここに並ぶ(押した順)。', style: TextStyle(color: GmColors.sub)),
          ),
        for (final p in open) ...[_ProspectRow(c: c, p: p, rank: ranks[p]!, gone: before != null && ranks[p]! <= before), const SizedBox(height: 6)],
        if (taken.isNotEmpty) ...[
          const SectionTitle('ここまでの指名'),
          for (final (k, p) in taken)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text('$k', style: const TextStyle(color: GmColors.sub)),
                  ),
                  TeamBadge(team: p.pickedBy!, size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${p.player.name}(${p.player.pos.short})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
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
  const _ProspectRow({required this.c, required this.p, required this.rank, required this.gone});
  final GmController c;
  final Prospect p;

  /// 模擬ドラフトの予想順位。
  final int rank;

  /// 自分の次の指名までに取られそうか。
  final bool gone;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final pl = p.player;
    final canPick = car.canDraftPick && !c.busy;
    final starred = car.board.contains(pl.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showProspect(context, c, p, rank),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: GmColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.scouted ? GmColors.gold.withValues(alpha: 0.6) : GmColors.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Text('予想', style: TextStyle(fontSize: 9, color: gone ? GmColors.bad : GmColors.sub)),
                  Text(
                    '$rank',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: gone ? GmColors.bad : null),
                  ),
                  InkWell(
                    onTap: c.busy ? null : () => c.toggleBoard(p),
                    child: Icon(starred ? Icons.star_rounded : Icons.star_border_rounded, size: 22, color: starred ? GmColors.gold : GmColors.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tag(pl.pos.short),
                      const SizedBox(width: 6),
                      Text('${pl.age}歳', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                      if (p.scouted) ...[const SizedBox(width: 6), const Tag('調査済み', color: GmColors.gold)],
                    ],
                  ),
                  Text(
                    '${backgroundOf(p)}・${() {
                      final s = amateurStatsOf(p);
                      return '${s.ppg}点 ${s.rpg}リ ${s.apg}ア';
                    }()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: GmColors.sub),
                  ),
                  const SizedBox(height: 4),
                  _range('OVR', p.ovrLo, p.ovrHi),
                  const SizedBox(height: 2),
                  _range('POT', p.potLo, p.potHi),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _range(String label, int lo, int hi) => Row(
    children: [
      SizedBox(
        width: 56,
        child: Text(label, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, cons) {
            final w = cons.maxWidth;
            double x(int v) => w * ((v - 35) / 65).clamp(0.0, 1.0);
            return SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Positioned(top: 5, left: 0, right: 0, child: Container(height: 4, color: GmColors.line)),
                  Positioned(
                    top: 3,
                    left: x(lo),
                    width: (x(hi) - x(lo)).clamp(4.0, w),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: GmColors.ovr(hi), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 52,
        child: Text(
          '${shown(lo)}〜${shown(hi)}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}

/// 候補の詳しい情報(経歴・身体測定・去年の成績・見立て)。
Future<void> _showProspect(BuildContext context, GmController c, Prospect p, int rank) => showGmSheet<void>(
  context,
  builder: (ctx) => ListenableBuilder(
    listenable: c,
    builder: (ctx, _) {
      final car = c.career!;
      final pl = p.player;
      final (h, w, span) = physicalOf(pl);
      final cb = combineOf(p);
      final st = amateurStatsOf(p);
      final (good, bad) = strengthsOf(pl);
      final starred = car.board.contains(pl.id);
      Widget line(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: Text(k, style: const TextStyle(color: GmColors.sub)),
            ),
            Expanded(
              child: Text(
                v,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(pl.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  ),
                  Tag(pl.pos.short),
                ],
              ),
              Text('${pl.age}歳・${backgroundOf(p)}・模擬ドラフト 予想$rank位', style: const TextStyle(color: GmColors.sub)),
              const SizedBox(height: 10),
              const Text(
                'コンバイン(身体測定)',
                style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
              ),
              line('身長・体重', '${h}cm・${w}kg'),
              line('ウイングスパン', '${span}cm'),
              line('垂直跳び', '${cb.vertical}cm'),
              line('4分の3コート', '${cb.sprint}秒'),
              const SizedBox(height: 8),
              const Text(
                '去年の成績(1試合あたり)',
                style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
              ),
              line('得点・リバ・アシ', '${st.ppg}点 ${st.rpg}リ ${st.apg}ア'),
              const SizedBox(height: 8),
              const Text(
                '見立て',
                style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
              ),
              line('OVR', '${shown(p.ovrLo)}〜${shown(p.ovrHi)}'),
              line('POT', '${shown(p.potLo)}〜${shown(p.potHi)}'),
              if (p.scouted) ...[
                line('得意', good.map((a) => a.label).join('・'), color: GmColors.good),
                line('苦手', bad.label, color: GmColors.bad),
              ] else
                line('得意・苦手', 'スカウトを送ると分かる'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: c.busy ? null : () => c.toggleBoard(p),
                      icon: Icon(starred ? Icons.star_rounded : Icons.star_border_rounded, color: starred ? GmColors.gold : null),
                      label: Text(starred ? '注目を外す' : '注目する'),
                    ),
                  ),
                  if (!p.scouted) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: car.scoutsLeft > 0 && !c.busy ? () => c.scoutProspect(p) : null,
                        child: Text('スカウト(残り${car.scoutsLeft})'),
                      ),
                    ),
                  ],
                ],
              ),
              if (car.myTurn && p.pickedBy == null) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: car.canDraftPick && !c.busy
                      ? () {
                          Navigator.of(ctx).pop();
                          c.pickProspect(p);
                        }
                      : null,
                  child: const Text('この選手を指名する'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  ),
);
