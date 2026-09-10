import 'package:flutter/material.dart';

import '../game/match_engine.dart';
import '../models/attributes.dart';
import '../models/career.dart';
import '../models/training.dart';
import '../state/career_controller.dart';

/// 今週の練習を、画面を移らずに変える。
///
/// 試合タブから育成タブへ飛ばしていたが、戻ってくるのに2手かかり、
/// スクロール位置も失う。毎週の操作なので、その場で終わるようにする。
///
/// 決めるのは3つ。**何をするか・どこまで踏み込むか・誰と組むか**。
/// メニューだけだった頃は、毎週同じ画面で同じものを選ぶだけだった。
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
        // 踏み込み方と組む相手は、選んでもシートを閉じない。
        // 3つを見比べながら決めるものなので、毎回開き直させない。
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          final odds = MatchEngine.outcomeOdds(
            effort: state.effort,
            companion: state.companion,
            condition: state.player.condition,
            professionalism: state.player.personality.professionalism,
          );
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  // 踏み込み方。ここが週の判断の中心。
                  _Row(
                    label: '踏み込み',
                    children: [
                      for (final effort in TrainingEffort.values)
                        ChoiceChip(
                          label: Text(effort.label),
                          selected: state.effort == effort,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) async {
                            await controller.setEffort(effort);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: Text(
                      '${state.effort.description}　'
                      '大成功 ${(odds.great * 100).round()}%'
                      ' ・ 空回り ${(odds.flat * 100).round()}%'
                      ' ・ 消耗 ×${state.effort.cost}'
                      ' ・ 怪我 ×${state.effort.injury}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  // 組む相手。居ない相手は出さない。
                  if (state.companionChoices.length > 1) ...[
                    _Row(
                      label: '組む相手',
                      children: [
                        for (final companion in state.companionChoices)
                          ChoiceChip(
                            label: Text(_companionLabel(state, companion)),
                            selected: state.companion == companion,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) async {
                              await controller.setCompanion(companion);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                      child: Text(
                        state.companion.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                  // 居残りもここで決められるようにする。育成タブの奥にあると、
                  // 練習だけ変えて居残りを付けっぱなしにしてしまう。
                  _Row(
                    label: '居残り',
                    children: [
                      ChoiceChip(
                        label: const Text('なし'),
                        selected: state.drill == null,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) async {
                          await controller.setDrill(null);
                          setSheetState(() {});
                        },
                      ),
                      for (final piece in SetPiece.values)
                        ChoiceChip(
                          label: Text(piece.label),
                          selected: state.drill == piece,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) async {
                            await controller.setDrill(piece);
                            setSheetState(() {});
                          },
                        ),
                    ],
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
                                        color: theme
                                            .colorScheme.onSurfaceVariant),
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
        });
      },
    );
  }

  /// 「相方と組む（真木 遼）」。名前が出ないと、誰と組むのか分からない。
  static String _companionLabel(CareerState state, TrainingCompanion companion) {
    final kind = companion.needs;
    if (kind == null) return companion.label;
    final who = state.teammateOf(kind);
    return who == null ? companion.label : '${companion.label}（${who.name}）';
  }
}

/// 見出しと選択肢を1行に並べる。
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ...children,
        ],
      ),
    );
  }
}
