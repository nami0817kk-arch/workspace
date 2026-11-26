import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/spending.dart';
import 'theme.dart';

/// 遊ぶ画面の上の帯の「使い道」の印（2026-11-25、ユーザーと決めた案）。
/// 年の初め（「この年の心がけ」の問いが出ているとき）だけ一覧を開ける。ほかのときは押すと訳を一言出す。
class SpendButton extends StatelessWidget {
  const SpendButton(this.g, {super.key});
  final Game g;

  @override
  Widget build(BuildContext context) {
    final open = spendingOpen(g);
    return IconButton(
      icon: Icon(
        Icons.account_balance_wallet_outlined,
        color: open ? Pal.gold : Pal.line,
      ),
      tooltip: '銭と功の使い道',
      onPressed: () {
        final why = spendingClosedReason(g);
        if (why != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(why),
                duration: const Duration(seconds: 2),
              ),
            );
          return;
        }
        showSpendSheet(context, g);
      },
    );
  }
}

/// 「銭と功の使い道」の一覧（下から出るシート）。
Future<void> showSpendSheet(BuildContext context, Game g) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pal.bg,
      showDragHandle: true,
      builder: (context) =>
          FractionallySizedBox(heightFactor: .8, child: SpendSheet(g)),
    );

class SpendSheet extends StatefulWidget {
  const SpendSheet(this.g, {super.key});
  final Game g;

  @override
  State<SpendSheet> createState() => _SpendSheetState();
}

class _SpendSheetState extends State<SpendSheet> {
  /// この一覧を開いてから使ったものの文（上に出す）。
  final List<String> done = [];

  Game get g => widget.g;

  Future<void> _buy(SpendItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Pal.bg,
        title: Text(it.label, style: const TextStyle(fontSize: 17)),
        content: Text(
          '${it.merit ? '功を' : '銭を'}${it.price.replaceFirst('功', '')}${it.merit ? '差し出します' : '使います'}。\n${it.hint}',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              it.merit ? '願い出る' : '使う',
              style: const TextStyle(color: Pal.accent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final res = spendingBuy(g, it.id);
    if (res != null) setState(() => done.insert(0, res));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final open = spendingOpen(g);
        final views = spendingCatalog(g);
        final gold = views.where((v) => !v.item.merit).toList();
        final merit = views.where((v) => v.item.merit).toList();
        final usable = open && views.any((v) => v.usable);
        final l = g.l;
        final spare = spMeritSpare(g);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Text(
              '銭と功の使い道',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '蓄え ${l.gold}貫　功 ${l.merit}${l.rank >= 1 && l.rank <= 7 && spare > 0 ? '（昇進に要る分の余り $spare）' : ''}',
              style: const TextStyle(color: Pal.gold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              '年の初めにだけ使える。持ち物は一つずつ、寄進や献上などは一年に一度ずつ。',
              style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.5),
            ),
            for (final d in done)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Pal.panel,
                  border: Border.all(color: Pal.good),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  d,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            if (!open)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('この年の使い道は、もう考えられない。'),
              )
            else if (!usable)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'いまの蓄えと功で使えるものはない。薄い行は、何があれば使えるかの目安。',
                  style: TextStyle(color: Pal.muted),
                ),
              ),
            if (gold.isNotEmpty) ...[
              const _Head('銭の使い道'),
              for (final v in gold)
                _ItemRow(
                  v.item,
                  open && v.usable ? () => _buy(v.item) : null,
                  lack: v.lack,
                ),
            ],
            if (merit.isNotEmpty) ...[
              const _Head('功の使い道（主君に願い出る）'),
              if (merit.any((v) => v.lack?.startsWith('主家') ?? false))
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    '功は、主家に仕えると主君に願い出て使える。',
                    style: TextStyle(color: Pal.muted, fontSize: 12),
                  ),
                ),
              for (final v in merit)
                _ItemRow(
                  v.item,
                  open && v.usable ? () => _buy(v.item) : null,
                  lack: v.lack,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(text, style: const TextStyle(color: Pal.accent, fontSize: 14)),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(this.it, this.onTap, {this.lack});
  final SpendItem it;

  /// null なら押せない（足りない・年の初めでない）。
  final VoidCallback? onTap;

  /// 使えない訳（「あと30貫」など）。あれば行を薄くして添える。
  final String? lack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Opacity(
      opacity: lack == null ? 1 : .5,
      child: Material(
        color: Pal.panel,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border.all(color: Pal.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        it.label,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      it.price,
                      style: const TextStyle(color: Pal.gold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  it.hint,
                  style: const TextStyle(
                    color: Pal.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (lack != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    lack!,
                    style: const TextStyle(color: Pal.accent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
