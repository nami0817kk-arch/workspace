import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// 説明文は「?」を押したときだけ出す。横画面は縦が狭いので、札の中では
/// 数字とボタンを先に見せる(2026-11-21)。
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.help_outline, size: 18),
        tooltip: title,
        // 押せる広さは 48x48 を保つ(accessibility_test)。
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(Tr.pick('閉じる', 'Close')),
              ),
            ],
          ),
        ),
      );
}

/// 札の見出しと、右端の「?」。
class TitleWithHelp extends StatelessWidget {
  const TitleWithHelp({
    super.key,
    required this.title,
    required this.help,
    this.style,
  });

  final String title;
  final String help;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: style ?? Theme.of(context).textTheme.titleMedium),
          ),
          HelpButton(title: title, text: help),
        ],
      );
}
