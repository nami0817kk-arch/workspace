import 'package:flutter/material.dart';

import '../models/attributes.dart';
import '../models/training.dart';
import '../state/career_controller.dart';

/// 今週の練習を、画面を移らずに変える。
///
/// 試合タブから育成タブへ飛ばしていたが、戻ってくるのに2手かかり、
/// スクロール位置も失う。毎週の操作なので、その場で終わるようにする。
class TrainingSheet {
  const TrainingSheet._();

  static Future<void> show(
    BuildContext context,
    CareerController controller,
  ) async {
    final state = controller.state;
    if (state == null) return;
    final position = state.player.position;
    final menus = [
      for (final m in TrainingMenu.values)
        if (m.availableFor(position)) m,
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text('今週の練習', style: theme.textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'コンディション ${state.player.condition}。'
                    '${state.autoRestBelow > 0 ? '${state.autoRestBelow}を下回った週は自動で休養になる。' : '自動休養は切ってある。'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                // 居残りもここで決められるようにする。育成タブの奥にあると、
                // 練習だけ変えて居残りを付けっぱなしにしてしまう。
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('居残り',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      ChoiceChip(
                        label: const Text('なし'),
                        selected: state.drill == null,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) async {
                          await controller.setDrill(null);
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      for (final piece in SetPiece.values)
                        ChoiceChip(
                          label: Text(piece.label),
                          selected: state.drill == piece,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) async {
                            await controller.setDrill(piece);
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final menu in menus)
                        ListTile(
                          dense: true,
                          selected: state.menu == menu,
                          leading: Icon(
                            state.menu == menu
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          title: Text(menu.label),
                          subtitle: Text(
                            '${menu.description}'
                            '${menu.isRest ? '' : ' ・ 消耗 ${menu.conditionCost}'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: menu.keys.isEmpty
                              ? null
                              : Text(
                                  menu.keys
                                      .map((AttributeKey k) => k.label)
                                      .join('・'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                          onTap: () async {
                            await controller.setMenu(menu);
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
