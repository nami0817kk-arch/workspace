import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/inbox.dart';
import '../../gm/league.dart';
import '../../gm/promise.dart';
import '../gm_controller.dart';
import 'style.dart';

IconData _senderIcon(Sender s) => switch (s) {
  Sender.owner => Icons.business_center_rounded,
  Sender.player => Icons.person_rounded,
  Sender.agent => Icons.work_rounded,
  Sender.league => Icons.campaign_rounded,
  Sender.staff => Icons.groups_2_rounded,
  Sender.press => Icons.mic_rounded,
};

/// 送り手ごとの色(カードの左の帯とアイコン)。
Color senderColor(Sender s) => switch (s) {
  Sender.owner => GmColors.gold,
  Sender.player => GmColors.good,
  Sender.agent => const Color(0xFFB794F6),
  Sender.league => const Color(0xFF8FD3FF),
  Sender.staff => const Color(0xFFB0B8C8),
  Sender.press => const Color(0xFFFF8FB1),
};

/// 並び: 返事が要る → オーナー → 読んでいない → そのほか(それぞれ新しい順)。
int _rank(Message m) => m.needsAnswer
    ? 0
    : m.from == Sender.owner && !m.read
    ? 1
    : !m.read
    ? 2
    : 3;

/// 受信箱。返事が要る知らせは上に出し、選ぶと効き目がすぐ起きる。
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.c});
  final GmController c;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  GmController get c => widget.c;
  Sender? _only;

  @override
  void initState() {
    super.initState();
    // 前に見終えた知らせは、開いたときに片付ける(消すボタンは要らない)。返事待ちは残る
    WidgetsBinding.instance.addPostFrameCallback((_) => c.clearReadMessages());
  }

  @override
  void dispose() {
    // 受信箱を閉じたら、返事が要らない知らせは読んだことにする(開くたびに未読の数が残らない)
    WidgetsBinding.instance.addPostFrameCallback((_) => c.readAllMessages());
    super.dispose();
  }

  /// 右に開いている知らせ。
  int? _sel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final car = c.career!;
      final order = {for (var i = 0; i < car.inbox.length; i++) car.inbox[i].id: i};
      final list =
          [
            for (final m in car.inbox)
              if (_only == null || m.from == _only) m,
          ]..sort((a, b) {
            final r = _rank(a).compareTo(_rank(b));
            return r != 0 ? r : order[a.id]!.compareTo(order[b.id]!);
          });
      final senders = {for (final m in car.inbox) m.from}.toList()..sort((a, b) => a.index.compareTo(b.index));
      final sel = list.where((m) => m.id == _sel).firstOrNull ?? list.firstOrNull;
      return Scaffold(
        appBar: AppBar(title: const Text('受信箱'), toolbarHeight: 40),
        body: SafeArea(
          child: car.inbox.isEmpty
              ? const Center(
                  child: Text('知らせはまだない', style: TextStyle(color: GmColors.sub)),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左: 送り手で絞る＋知らせの一覧(1行ずつ)
                      SizedBox(
                        width: 340,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final s in <Sender?>[null, ...senders])
                                  ChoiceChip(
                                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    showCheckmark: false,
                                    avatar: s == null ? null : Icon(_senderIcon(s), size: 13, color: senderColor(s)),
                                    label: Text(s == null ? 'すべて(${car.inbox.length})' : '${s.label}(${car.inbox.where((m) => m.from == s).length})', style: const TextStyle(fontSize: 11)),
                                    selected: _only == s,
                                    onSelected: (_) => setState(() => _only = s),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: GmColors.panel,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: GmColors.line),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ListView(
                                  children: [
                                    for (final (i, m) in list.indexed)
                                      _MessageRow(
                                        m: m,
                                        selected: m == sel,
                                        odd: i.isOdd,
                                        onTap: () {
                                          setState(() => _sel = m.id);
                                          if (!m.read) c.readMessage(m.id);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PromiseBox(car: car),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 右: 開いている知らせの本文と返事
                      Expanded(
                        child: sel == null
                            ? const Center(
                                child: Text('この送り手の知らせは無い', style: TextStyle(color: GmColors.sub)),
                              )
                            : SingleChildScrollView(
                                child: _MessageCard(c: c, m: sel),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}

/// 一覧の1行(送り手の印・題・返事待ち・未読の点)。
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.m, required this.selected, required this.odd, required this.onTap});
  final Message m;
  final bool selected, odd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !m.read || m.needsAnswer;
    final color = senderColor(m.from);
    return Material(
      color: selected
          ? GmColors.ball.withValues(alpha: 0.16)
          : odd
          ? GmColors.panelHi.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.fromLTRB(0, 3, 8, 3),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(_senderIcon(m.from), size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: unread ? FontWeight.bold : FontWeight.normal),
                    ),
                    Text(
                      m.needsAnswer ? '${m.from.label}・返事を待っている' : '${m.from.label}・${m.season}年目',
                      maxLines: 1,
                      style: TextStyle(fontSize: 10, color: m.needsAnswer ? GmColors.gold : GmColors.sub),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: GmColors.ball, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.c, required this.m});
  final GmController c;
  final Message m;

  @override
  Widget build(BuildContext context) {
    final unread = !m.read || m.needsAnswer;
    final color = senderColor(m.from);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: m.needsAnswer
              ? GmColors.gold
              : unread
              ? GmColors.ball.withValues(alpha: 0.6)
              : GmColors.line,
        ),
      ),
      child: Container(
        // 左の帯で送り手を見分ける
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: m.read ? null : () => c.readMessage(m.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(_senderIcon(m.from), size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      m.from.label,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                    ),
                    Text('・${m.season}年目', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                    if (m.needsAnswer) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '返事を待っている',
                        style: TextStyle(fontSize: 11, color: GmColors.gold, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const Spacer(),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: GmColors.ball, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(m.body, style: const TextStyle(fontSize: 13, height: 1.5)),
                if (m.choices.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (m.answer != null)
                    Text(
                      '返事: ${m.choices[m.answer!]}',
                      style: const TextStyle(color: GmColors.good, fontWeight: FontWeight.bold),
                    )
                  else
                    for (var i = 0; i < m.choices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: (i == 0 ? FilledButton.tonal : OutlinedButton.new)(onPressed: () => c.answer(m.id, i), child: Text(m.choices[i])),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// GM の言葉の重みと、いま抱えている約束(返事で約束したこと。期限まで見張られる)。
class PromiseBox extends StatelessWidget {
  const PromiseBox({super.key, required this.car});
  final Career car;

  String _due(Promise x) {
    if (x.kind == PromiseKind.playoffs) return 'シーズンの終わり';
    final s = x.due ~/ blocksPerSeason, b = x.due % blocksPerSeason;
    return '${s == car.season ? '' : '$s年目の'}${b == 0 ? '開幕' : '$b区切り目の終わり'}まで';
  }

  @override
  Widget build(BuildContext context) {
    final open = car.openPromises;
    final done = [for (final x in car.promises) if (x.state == PromiseState.kept || x.state == PromiseState.broken) x].take(2).toList();
    final w = car.word;
    final color = w >= 70 ? GmColors.good : w >= 45 ? GmColors.gold : GmColors.bad;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: GmColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: open.isEmpty ? GmColors.line : GmColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_rounded, size: 14, color: GmColors.gold),
              const SizedBox(width: 4),
              Text(open.isEmpty ? '約束' : '約束(${open.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('GMの言葉の重み ', style: TextStyle(fontSize: 10, color: GmColors.sub)),
              Text('$w・${wordLabel(w)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: w / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: color, backgroundColor: GmColors.line),
            ),
          ),
          if (open.isEmpty && done.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('選手や記者への返事は約束になる。守ると言葉が重くなり、破ると本人とチームの気持ちが下がる。', style: TextStyle(fontSize: 10, color: GmColors.sub, height: 1.4)),
            ),
          for (final x in open)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 12, color: GmColors.gold),
                  const SizedBox(width: 4),
                  Expanded(child: Text(x.line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                  Text(_due(x), style: const TextStyle(fontSize: 10, color: GmColors.sub)),
                ],
              ),
            ),
          for (final x in done)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Icon(x.state == PromiseState.kept ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 12, color: x.state == PromiseState.kept ? GmColors.good : GmColors.bad),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${x.line}(${x.state == PromiseState.kept ? '守った' : '破った'})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: GmColors.sub),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
