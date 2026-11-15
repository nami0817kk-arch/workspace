import 'package:flutter/material.dart';

import '../models/player.dart';
import '../l10n/tr.dart';

/// ポジション大分類(GK/DEF/MID/ATT)で一覧を絞り込むためのチップ列。
/// 移籍市場・スカウト画面など、選手リストを扱う画面で共通して使う。
class PositionFilterBar extends StatelessWidget {
  final PositionGroup? value;
  final ValueChanged<PositionGroup?> onChanged;

  /// 横にスクロールさせず、収まらなければ折り返す(狭い左の欄に置くとき)。
  final bool wrap;

  /// チップを小さくする(横画面の狭い欄・1行に詰めたいとき)。
  final bool compact;

  const PositionFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.wrap = false,
    this.compact = false,
  });

  static String labelFor(PositionGroup? g) => switch (g) {
        null => Tr.pick('すべて', 'All'),
        PositionGroup.gk => 'GK',
        PositionGroup.def => 'DF',
        PositionGroup.mid => 'MF',
        PositionGroup.att => 'FW',
      };

  @override
  Widget build(BuildContext context) {
    final options = <PositionGroup?>[null, ...PositionGroup.values];
    final small = wrap || compact;
    Widget chip(PositionGroup? g) => ChoiceChip(
          label: Text(labelFor(g),
              style: small ? const TextStyle(fontSize: 12) : null),
          visualDensity: small ? VisualDensity.compact : null,
          labelPadding:
              small ? const EdgeInsets.symmetric(horizontal: 2) : null,
          selected: value == g,
          onSelected: (_) => onChanged(g),
        );
    if (wrap) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [for (final g in options) chip(g)],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final g in options)
            Padding(
              padding: EdgeInsets.only(right: small ? 4 : 8),
              child: chip(g),
            ),
        ],
      ),
    );
  }
}
