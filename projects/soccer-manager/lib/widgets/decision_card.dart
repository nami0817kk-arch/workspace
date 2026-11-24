import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import 'fm_panel.dart';

/// 「決める」札の答え1つ。
class DecisionChoice {
  const DecisionChoice(
    this.label,
    this.onPressed, {
    this.effect,
    this.primary = true,
    this.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 答えが起こすこと(「資金-1,444万 / サポーター+2」)。開いたときだけ出す。
  final String? effect;

  /// 塗りのボタンにするか(断る・見送る答えは枠だけにする)。
  final bool primary;
  final Key? key;
}

/// 状況の右の欄に並ぶ、その場で答える必須の札(事件・総会・噂・手術・
/// ツアー・理事会レビュー)。
///
/// **題と答えのボタンだけを出す。** 説明と効き目は、札を押すと開く
/// (2026-11-25)。以前は1枚に説明・答えごとの効き目まで並び、必須が2枚
/// あるだけで右の欄が埋まって、おすすめが画面の外に落ちていた。
class DecisionCard extends StatefulWidget {
  const DecisionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.choices,
    this.detail,
    this.deadline,
    this.color,
    this.onColor,
    this.extra = const [],
  });

  final IconData icon;
  final String title;
  final List<DecisionChoice> choices;

  /// 説明(開いたときだけ)。
  final String? detail;

  /// 締切(「あと2節答えないと…」)。題の下に小さく、いつも出す。
  final String? deadline;

  /// 札の地と字の色(無ければテーマの札の色)。
  final Color? color;
  final Color? onColor;

  /// 開いたときに説明の下に足すもの。
  final List<Widget> extra;

  @override
  State<DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends State<DecisionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = widget.onColor ?? scheme.onSurface;
    final sub = widget.onColor?.withValues(alpha: 0.85) ??
        scheme.onSurfaceVariant;
    final effects = [
      for (final c in widget.choices)
        if (c.effect != null && c.effect!.isNotEmpty) c,
    ];
    // 答えのボタンは小さめに(長い答えが2つ並ぶ)。
    final compact = ButtonStyle(
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
    final hasMore =
        widget.detail != null || effects.isNotEmpty || widget.extra.isNotEmpty;
    return Card(
      color: widget.color,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: const ValueKey('decision-toggle'),
              onTap: hasMore ? () => setState(() => _open = !_open) : null,
              borderRadius: BorderRadius.circular(fmRadius(context, 8)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 20, color: on),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: on),
                      ),
                    ),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          _open ? Icons.expand_less : Icons.info_outline,
                          size: 20,
                          color: sub,
                          semanticLabel: _open
                              ? Tr.pick('説明をたたむ', 'Hide details')
                              : Tr.pick('説明と効き目を見る', 'Show details'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.deadline != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 8),
                child: Text(widget.deadline!,
                    style: TextStyle(fontSize: 11, color: sub)),
              ),
            if (_open) ...[
              if (widget.detail != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, right: 8),
                  child: Text(widget.detail!,
                      style: TextStyle(fontSize: 12, color: on)),
                ),
              ...widget.extra,
              for (final c in effects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 8),
                  child: Text('${c.label}: ${c.effect}',
                      style: TextStyle(fontSize: 12, color: sub)),
                ),
              const SizedBox(height: 4),
            ],
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final c in widget.choices)
                    c.primary
                        ? FilledButton(
                            key: c.key,
                            style: compact,
                            onPressed: c.onPressed,
                            child: Text(c.label, textAlign: TextAlign.center),
                          )
                        : OutlinedButton(
                            key: c.key,
                            style: compact,
                            onPressed: c.onPressed,
                            child: Text(c.label, textAlign: TextAlign.center),
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
