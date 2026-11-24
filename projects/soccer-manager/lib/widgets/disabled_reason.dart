import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../logic/economy_scale.dart';

/// 「資金が足りません(あと いくら)」。あちこちの押せないボタンで同じ文を
/// 使うので、1か所で作る。[shortBy] は足りない額(必要な額 - 手元の資金)。
String fundsShortReason(int shortBy) => Tr.pick(
    '資金が足りません(あと ${formatMoney(shortBy)})',
    'Not enough funds (${formatMoney(shortBy)} short)');

/// 押せないボタンのそばに出す理由(1行)。
///
/// 灰色のボタンだけでは、なぜ押せないのか(資金が足りない・今季は実行済み・
/// 窓が閉じている・工事中)が分からず、何をすれば押せるようになるのかも
/// 分からなかった。押せないときは、必ずこれをボタンの近くに置く。
///
/// [reason] が null か空なら何も出さない(押せるときはそのまま渡せる)。
class DisabledReason extends StatelessWidget {
  const DisabledReason(
    this.reason, {
    super.key,
    this.alignEnd = false,
    this.padding = const EdgeInsets.only(top: 4),
  });

  final String? reason;

  /// 右に寄せるか(ボタンが右端にあるとき)。
  final bool alignEnd;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = reason;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 13, color: color),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
