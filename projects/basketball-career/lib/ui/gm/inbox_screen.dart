import 'package:flutter/material.dart';

import '../../gm/inbox.dart';
import '../gm_controller.dart';
import '../layout.dart';
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
      return Scaffold(
        appBar: AppBar(title: const Text('受信箱')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
              child: car.inbox.isEmpty
                  ? const Center(
                      child: Text('知らせはまだない', style: TextStyle(color: GmColors.sub)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                      children: [
                        // 送り手で絞る
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final s in <Sender?>[null, ...senders])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6, bottom: 8),
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: s == null ? null : Icon(_senderIcon(s), size: 16, color: senderColor(s)),
                                    label: Text(
                                      s == null ? 'すべて(${car.inbox.length})' : '${s.label}(${car.inbox.where((m) => m.from == s).length})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    selected: _only == s,
                                    onSelected: (_) => setState(() => _only = s),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final m in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _MessageCard(c: c, m: m),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
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
            padding: const EdgeInsets.all(14),
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
                Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(m.body, style: const TextStyle(height: 1.5)),
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
