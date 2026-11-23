import 'package:flutter/material.dart';

import 'fm_panel.dart';
import 'screen_bar.dart';

/// グループの中の1つのページ(見出しの文字と、画面を作る関数)。
class GroupTab {
  const GroupTab(this.label, this.builder);

  final String label;
  final WidgetBuilder builder;
}

/// 関連する画面を1つの項目にまとめるページ(左メニューの1項目)。
///
/// 上に細い帯を置き、サブページを横に並べて切り替える(Football Manager の
/// 左メニュー内の項目に近い)。中の画面は自分の見出しを出さず、帯の下に
/// そのまま並ぶ。切り替えても各画面の状態(スクロール・選択)は残る。
class GroupPage extends StatefulWidget {
  const GroupPage({super.key, required this.title, required this.tabs});

  final String title;
  final List<GroupTab> tabs;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  int _index = 0;

  /// 一度でも開いたページ。開くまでは作らない(最初から全部を描かない)。
  final Set<int> _opened = {0};

  void _select(int i) {
    setState(() {
      _index = i;
      _opened.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            // 上の帯・ほかの画面のタブの帯と同じ地にそろえる(fm_look.dart)。
            color: FmLook.of(context)?.topBar ?? scheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        InkWell(
                          onTap: () => _select(i),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: i == _index
                                      ? scheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.tabs[i].label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: i == _index
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: i == _index
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: HideScreenBar(
            child: Theme(
              // 昔ながらの AppBar を使う画面は、見出しの高さを0にして隠す
              // (タブを持つ画面は、タブの帯だけが残る)。
              data: theme.copyWith(
                appBarTheme: theme.appBarTheme.copyWith(toolbarHeight: 0),
              ),
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < widget.tabs.length; i++)
                    _opened.contains(i)
                        ? widget.tabs[i].builder(context)
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
