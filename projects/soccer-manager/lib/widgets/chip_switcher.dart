import 'package:flutter/material.dart';

/// 似た中身をいくつか持つタブを1つにまとめ、中で選ぶ部品。
///
/// タブが8つ以上並ぶと横にはみ出して見つからなかった(リーグの2段目・
/// オーナー室)。似たもの(他の部の順位表・他国の順位表・記録もの)は
/// 1つのタブにし、上の札で切り替える。
class ChipSwitcher extends StatefulWidget {
  const ChipSwitcher({super.key, required this.items, this.index});

  /// 札の名前と、選んだときに出す中身。
  final List<(String, WidgetBuilder)> items;

  /// 外から札を選ぶとき(「注目へ」の入口など)。省くと中で覚える。
  final ValueNotifier<int>? index;

  @override
  State<ChipSwitcher> createState() => _ChipSwitcherState();
}

class _ChipSwitcherState extends State<ChipSwitcher> {
  int _own = 0;

  int get _index => widget.index?.value ?? _own;
  set _index(int v) {
    if (widget.index != null) {
      widget.index!.value = v;
    } else {
      _own = v;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.index?.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChipSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      old.index?.removeListener(_changed);
      widget.index?.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.index?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final i = _index.clamp(0, widget.items.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var k = 0; k < widget.items.length; k++)
                ChoiceChip(
                  key: ValueKey('chip-$k'),
                  label: Text(widget.items[k].$1),
                  selected: k == i,
                  onSelected: (_) => setState(() => _index = k),
                ),
            ],
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(i),
            child: widget.items[i].$2(context),
          ),
        ),
      ],
    );
  }
}
