import 'package:flutter/material.dart';

import '../../deck/cards.dart';
import 'style.dart';

/// カード1枚の見た目。左上にスタミナ、まん中に絵、下に名前と効き目。
/// 試合中は [points]・[guard] に、いま出したら何点・守備いくつになるかを渡す。
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.width = 112,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.points,
    this.guard,
    this.selected = false,
    this.showUpgrade = false,
  });

  final CardInstance card;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final int? points;
  final int? guard;
  final bool selected;

  /// 強くしたあとの文を出す(練習で選ぶとき)。
  final bool showUpgrade;

  static const aspect = 1.42;

  @override
  Widget build(BuildContext context) {
    final def = card.def;
    final color = DeckColors.kind(def.kind);
    final h = width * aspect;
    final upgraded = showUpgrade || card.upgraded;
    final text = showUpgrade ? def.text(true) : card.text;
    final scale = width / 112;
    return Semantics(
      button: onTap != null,
      label: '${card.name}、スタミナ${card.cost}、$text',
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            height: h,
            decoration: BoxDecoration(
              color: DeckColors.panelHi,
              borderRadius: BorderRadius.circular(12 * scale),
              border: Border.all(color: selected ? Colors.white : color, width: selected ? 3 : 2),
              boxShadow: [
                if (enabled && onTap != null)
                  BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 絵
                    Expanded(
                      flex: 9,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(6 * scale, 6 * scale, 6 * scale, 0),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(6 * scale),
                          child: Image.asset('assets/art/icons/${def.icon}.png',
                              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        ),
                      ),
                    ),
                    // 名前
                    Padding(
                      padding: EdgeInsets.fromLTRB(4 * scale, 4 * scale, 4 * scale, 0),
                      child: Text(
                        showUpgrade ? '${def.name}＋' : card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5 * scale,
                          fontWeight: FontWeight.bold,
                          color: upgraded ? DeckColors.good : DeckColors.text,
                        ),
                      ),
                    ),
                    // 効き目
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(5 * scale, 2 * scale, 5 * scale, 4 * scale),
                        child: Center(
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10 * scale, height: 1.25, color: DeckColors.sub),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // スタミナ
                if (!def.unplayable)
                  Positioned(
                    left: 3 * scale,
                    top: 3 * scale,
                    child: Container(
                      width: 24 * scale,
                      height: 24 * scale,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: DeckColors.bg, width: 2),
                      ),
                      child: Text('${card.cost}',
                          style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                // いま出したときの点・守備
                if ((points ?? 0) > 0 || (guard ?? 0) > 0)
                  Positioned(
                    right: 3 * scale,
                    top: 3 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if ((points ?? 0) > 0) _Badge('$points点', DeckColors.ball, scale),
                        if ((guard ?? 0) > 0) _Badge('守$guard', DeckColors.kind(CardKind.defense), scale),
                      ],
                    ),
                  ),
                // めずらしさ
                Positioned(
                  right: 6 * scale,
                  bottom: 4 * scale,
                  child: Icon(Icons.circle, size: 6 * scale, color: DeckColors.rarity(def.rarity)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color, this.scale);
  final String text;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: 2 * scale),
        padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 1 * scale),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8 * scale)),
        child: Text(text,
            style: TextStyle(fontSize: 10.5 * scale, fontWeight: FontWeight.bold, color: Colors.white)),
      );
}

/// カードの説明を大きく見せる(長押し)。
Future<void> showCardDetail(BuildContext context, CardInstance c) => showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CardView(card: c, width: 200),
            const SizedBox(height: 12),
            Text('${c.def.kind.label}・${c.def.rarity.label}',
                style: const TextStyle(color: DeckColors.sub)),
            if (c.canUpgrade) ...[
              const SizedBox(height: 6),
              Text('強くすると: ${c.def.text(true)}',
                  textAlign: TextAlign.center, style: const TextStyle(color: DeckColors.good, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
          ],
        ),
      ),
    );

/// デッキを一覧で見せる。[onPick] を渡すと選べる(練習・外す)。
Future<CardInstance?> showDeckSheet(
  BuildContext context,
  List<CardInstance> deck, {
  String title = 'デッキ',
  bool Function(CardInstance c)? selectable,
  bool upgradePreview = false,
}) {
  final sorted = [...deck]..sort((a, b) {
      final k = a.def.kind.index.compareTo(b.def.kind.index);
      return k != 0 ? k : a.def.name.compareTo(b.def.name);
    });
  return showModalBottomSheet<CardInstance>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.78,
        child: Column(
          children: [
            Text('$title(${deck.length}枚)',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(builder: (ctx, box) {
                final cols = (box.maxWidth / 120).floor().clamp(3, 8);
                final w = (box.maxWidth - 24 - (cols - 1) * 8) / cols;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in sorted)
                        CardView(
                          card: c,
                          width: w,
                          showUpgrade: upgradePreview && c.canUpgrade,
                          enabled: selectable == null || selectable(c),
                          onTap: selectable == null
                              ? () => showCardDetail(ctx, c)
                              : (selectable(c) ? () => Navigator.pop(ctx, c) : null),
                          onLongPress: () => showCardDetail(ctx, c),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    ),
  );
}
