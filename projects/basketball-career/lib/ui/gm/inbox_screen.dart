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

/// 受信箱。返事が要る知らせは上に出し、選ぶと効き目がすぐ起きる。
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.c});
  final GmController c;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  GmController get c => widget.c;

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
          final list = [...car.inbox]..sort((a, b) => (b.needsAnswer ? 1 : 0).compareTo(a.needsAnswer ? 1 : 0));
          return Scaffold(
            appBar: AppBar(
              title: const Text('受信箱'),
              actions: [
                if (car.inbox.any((m) => m.read && !m.needsAnswer))
                  TextButton.icon(
                    onPressed: c.clearReadMessages,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('読んだ知らせを消す'),
                  ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
                  child: list.isEmpty
                      ? const Center(child: Text('知らせはまだない', style: TextStyle(color: GmColors.sub)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                          children: [
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: m.needsAnswer ? GmColors.gold : unread ? GmColors.ball.withValues(alpha: 0.6) : GmColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: m.read ? null : () => c.readMessage(m.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(_senderIcon(m.from), size: 18, color: unread ? GmColors.ball : GmColors.sub),
              const SizedBox(width: 6),
              Text('${m.from.label}・${m.season}年目', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              const Spacer(),
              if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: GmColors.ball, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 6),
            Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(m.body, style: const TextStyle(height: 1.5)),
            if (m.choices.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (m.answer != null)
                Text('返事: ${m.choices[m.answer!]}', style: const TextStyle(color: GmColors.good, fontWeight: FontWeight.bold))
              else
                for (var i = 0; i < m.choices.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: (i == 0 ? FilledButton.tonal : OutlinedButton.new)(
                      onPressed: () => c.answer(m.id, i),
                      child: Text(m.choices[i]),
                    ),
                  ),
            ],
          ]),
        ),
      ),
    );
  }
}
