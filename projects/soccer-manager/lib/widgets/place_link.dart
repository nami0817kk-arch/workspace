import 'package:flutter/material.dart';

import '../logic/todo_advisor.dart';
import '../screens/todo_navigation.dart';

/// 別の場所にある同じ用件への入口(1行)。押すと、その場所(左メニューの項目・
/// タブ・札)へ移る。
///
/// 同じ用件の操作は1か所に置き、ほかの関係する画面にはこの入口だけを置く
/// (契約の更新は「選手 > 登録と契約」、資本の手は「オーナーの仕事」など)。
/// 以前は同じ操作が2〜3か所にあり、どこで決めるのかが分からなかった。
class PlaceLink extends StatelessWidget {
  const PlaceLink({
    super.key,
    required this.title,
    required this.note,
    required this.place,
    this.icon = Icons.arrow_outward,
  });

  final String title;
  final String note;
  final TodoPlace place;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openTodoPlace(context, place),
        child: ConstrainedBox(
          // 横画面は約0.93倍で描くので、52 で実寸48pt を超える。
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      if (note.isNotEmpty)
                        Text(note,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
