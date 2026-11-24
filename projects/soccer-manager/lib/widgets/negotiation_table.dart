import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// 契約の交渉の画面の部品(FM の契約の画面)。選手の契約(更新・移籍・
/// 仮契約)と、スタッフの契約で同じ形を使う(2026-11-25 に分けた。
/// スタッフの交渉の画面のつなぎ込みは第6段)。
///
/// 画面の形: 左に相手と代理人([NegotiationLayout.side])、右の上に代理人の
/// 返事の帯([NegotiationReplyBanner])、その下に項目の表
/// ([NegotiationTable]: 項目・相手の要求・こちらの提示)、下に総額とボタン
/// ([NegotiationBottomBar])。横画面では項目の表を2列に割り、iPhone の
/// 横向き1画面に収める。

/// 表の1行。
class NegotiationRow {
  const NegotiationRow({
    required this.label,
    required this.want,
    required this.offer,
    this.note,
    this.key,
  });

  final String label;

  /// 相手の要求の欄。
  final Widget want;

  /// こちらの提示の欄(増減の部品・選ぶ部品)。
  final Widget offer;

  /// 項目の下の小さな説明。
  final String? note;
  final Key? key;
}

/// 返事の調子(帯の色)。
enum NegotiationTone { neutral, good, bad }

/// 代理人の返事の帯。
class NegotiationReplyBanner extends StatelessWidget {
  const NegotiationReplyBanner(
      {super.key, required this.text, this.tone = NegotiationTone.neutral});

  final String text;
  final NegotiationTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (tone) {
      NegotiationTone.bad => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer
        ),
      NegotiationTone.good => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer
        ),
      NegotiationTone.neutral => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(Icons.record_voice_over_outlined, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: TextStyle(fontSize: 12.5, color: fg))),
        ],
      ),
    );
  }
}

/// 項目の表。[columns] が 2 なら、行を前半と後半の2列に割って横に並べる。
class NegotiationTable extends StatelessWidget {
  const NegotiationTable({
    super.key,
    required this.rows,
    this.columns = 1,
    this.wantHeader,
    this.offerHeader,
    this.compact = false,
    this.splitAt,
  });

  final List<NegotiationRow> rows;
  final int columns;
  final String? wantHeader;
  final String? offerHeader;

  /// 行を低くする(横画面で1画面に収めるとき)。説明は項目を長押しで出す。
  final bool compact;

  /// 2列に割るとき、右の列の先頭にする行の番号(省くと半分で割る)。
  final int? splitAt;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1 || rows.length < 2) {
      return _column(context, rows);
    }
    final half = (splitAt ?? (rows.length / 2).ceil()).clamp(1, rows.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column(context, rows.sublist(0, half))),
            const SizedBox(width: 6),
            Expanded(child: _column(context, rows.sublist(half))),
          ],
        ),
        if (compact && rows.any((r) => r.note != null))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              Tr.pick('項目の名前を押すと説明が出ます。', 'Tap a term for an explanation.'),
              style: TextStyle(
                  fontSize: 10.5, color: SemanticColors.subtleText(context)),
            ),
          ),
      ],
    );
  }

  // 欄の幅の割合。要求の欄が狭く、英語の「to Jun 2029」「Welcome」が
  // 縮んだり語の途中で折れたりしていた(2026-11-25 の第7段)。提示の欄は
  // 増減の部品が入る幅を残す。
  int get _termFlex => compact ? 3 : 4;
  int get _wantFlex => compact ? 3 : 4;
  int get _offerFlex => compact ? 4 : 5;

  static Widget _fit(Widget child) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: child,
      );

  Widget _column(BuildContext context, List<NegotiationRow> rows) {
    final theme = Theme.of(context);
    final subtle = SemanticColors.subtleText(context);
    final head =
        TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtle);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            // 見出しは切らずに縮める。「選手の要求」が「選手の…」と切れて
            // いた(2026-11-25 の第7段)。
            child: Row(
              children: [
                Expanded(
                    flex: _termFlex,
                    child: _fit(Text(Tr.pick('項目', 'Term'), style: head))),
                Expanded(
                    flex: _wantFlex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _fit(Text(
                          wantHeader ?? Tr.pick('相手の要求', 'They want'),
                          maxLines: 1,
                          style: head)),
                    )),
                Expanded(
                    flex: _offerFlex,
                    child: _fit(Text(
                        offerHeader ?? Tr.pick('こちらの提示', 'Your offer'),
                        maxLines: 1,
                        style: head))),
              ],
            ),
          ),
          for (final r in rows)
            Container(
              key: r.key,
              constraints: BoxConstraints(minHeight: compact ? 36 : 46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final label = Text(r.label,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: compact ? 12 : 12.5,
                        fontWeight: FontWeight.bold));
                // 横画面(1画面に収める)では説明を出さず、項目を押すと出す
                // (表の下に一言で案内する)。
                final name = compact
                    ? (r.note == null
                        ? label
                        : Tooltip(
                            message: r.note!,
                            triggerMode: TooltipTriggerMode.tap,
                            child: label,
                          ))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          label,
                          if (r.note != null)
                            Text(r.note!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: subtle)),
                        ],
                      );
                // 狭いとき(縦画面)は、提示の欄を下の段に回す。
                if (c.maxWidth < 250) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(flex: 3, child: name),
                        Expanded(flex: 3, child: r.want),
                      ]),
                      Align(alignment: Alignment.centerLeft, child: r.offer),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: _termFlex, child: name),
                    Expanded(
                        flex: _wantFlex,
                        child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: r.want)),
                    Expanded(flex: _offerFlex, child: r.offer),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

/// [-] 値 [+]。
class NegotiationStepper extends StatelessWidget {
  const NegotiationStepper({
    super.key,
    required this.label,
    this.onMinus,
    this.onPlus,
    this.color,
  });

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: Tr.pick('下げる', 'Lower'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: onMinus,
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
          ),
        ),
        IconButton(
          tooltip: Tr.pick('上げる', 'Raise'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: onPlus,
        ),
      ],
    );
  }
}

/// 選択肢から選ぶ欄(小さなドロップダウン)。
class NegotiationChoice<T> extends StatelessWidget {
  const NegotiationChoice({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DropdownButton<T>(
        value: items.contains(value) ? value : items.first,
        isDense: true,
        isExpanded: true,
        items: [
          for (final v in items)
            DropdownMenuItem<T>(
              value: v,
              child: Text(labelOf(v),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5)),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (v) {
                if (v != null) onChanged!(v);
              },
      ),
    );
  }
}

/// 下の帯: 総額などの字と、やめる・提示するのボタン。
class NegotiationBottomBar extends StatelessWidget {
  const NegotiationBottomBar({
    super.key,
    required this.info,
    required this.buttons,
    this.narrow = false,
  });

  final List<Widget> info;
  final List<Widget> buttons;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final infoWrap = Wrap(spacing: 14, runSpacing: 2, children: info);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: narrow
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoWrap,
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: buttons),
              ],
            )
          : Row(
              children: [
                Expanded(child: infoWrap),
                const SizedBox(width: 8),
                ...buttons,
              ],
            ),
    );
  }
}

/// 交渉の画面の並べ方。横長なら左に[side]、右に返事と表。縦長なら上下に積む。
class NegotiationLayout extends StatelessWidget {
  const NegotiationLayout({
    super.key,
    required this.side,
    required this.banner,
    required this.table,
    required this.bottom,
  });

  final Widget side;
  final Widget banner;

  /// 横長かどうかを受け取って表を作る(2列に割るかを決める)。
  final Widget Function(bool wide) table;

  /// 下の帯(狭いかどうかを受け取る)。
  final Widget Function(bool narrow) bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 560;
      if (wide) {
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 横長では返事の帯を左の列の上に置き、表に高さを回す
                  // (iPhone の横向きで表を1画面に収める)。
                  SizedBox(
                      width: 180,
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [banner, const SizedBox(height: 8), side],
                          ))),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: table(true),
                    ),
                  ),
                ],
              ),
            ),
            bottom(false),
          ],
        );
      }
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                side,
                const SizedBox(height: 8),
                banner,
                const SizedBox(height: 6),
                table(false),
              ],
            ),
          ),
          bottom(true),
        ],
      );
    });
  }
}
