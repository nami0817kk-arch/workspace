import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// オフシーズン(季の終わり〜開幕前)にだけ変えられるもの(予算の配り方・
/// クラブの見た目・チケットの値段・クラブの方針)を、シーズン中に見せる
/// 1行。操作は出さず、今季の中身と、いつ変えられるかだけを書く
/// (2026-11-25)。
class OffseasonLockNote extends StatelessWidget {
  const OffseasonLockNote(this.current, {super.key});

  /// 今季の中身(「補強 40%・育成 20%…」「標準」など)。
  final String current;

  @override
  Widget build(BuildContext context) {
    final subtle = SemanticColors.subtleText(context);
    return Row(
      key: const ValueKey('offseason-lock-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.lock_clock_outlined, size: 16, color: subtle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: Tr.pick('今季: $current', 'This season: $current'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: Tr.pick('（来季の開幕前に変えられます）',
                    ' (you can change it before next season starts)'),
                style: TextStyle(color: subtle),
              ),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
