import 'package:flutter/material.dart';

import 'quick_access_drawer.dart';

/// 横画面の左メニューの中に埋め込まれている印。
///
/// 埋め込まれた画面は、戻るボタンや引き出しの取っ手を出さない(左のメニューが
/// その役目をする)。また、画面の見出しとタブの帯を1本にして、縦の高さを守る。
class EmbeddedInShell extends InheritedWidget {
  const EmbeddedInShell({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EmbeddedInShell>() != null;

  @override
  bool updateShouldNotify(EmbeddedInShell oldWidget) => false;
}

/// グループのページの中に置かれている印。見出しはグループの帯が受け持つので、
/// 中の画面は自分の見出しを出さない(タブや操作ボタンがあるときだけ細い帯を残す)。
class HideScreenBar extends InheritedWidget {
  const HideScreenBar({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HideScreenBar>() != null;

  @override
  bool updateShouldNotify(HideScreenBar oldWidget) => false;
}

/// 各画面の上の帯。タブは指で押せる高さ(48、実寸で44pt 以上)にする。
///
/// 左メニューに埋め込まれた横画面では、見出しの帯とタブの帯を1本にする
/// (タブがあれば見出しの代わりにタブを並べ、無ければ見出しだけ)。
/// それ以外(縦画面・単独で開かれた画面)は、これまでどおり見出し＋その下にタブ。
PreferredSizeWidget screenBar(
  BuildContext context, {
  required String title,
  List<String> tabs = const [],
  TabController? controller,
  bool scrollable = false,
  Widget? leading,
  List<Widget> actions = const [],
  List<Widget?> tabMarks = const [],
}) {
  // タブの字の右に、「やること」の印(赤い数字・青い点)を付ける。
  Tab tab(int i, {double? height}) {
    final mark = i < tabMarks.length ? tabMarks[i] : null;
    if (mark == null) return Tab(height: height, text: tabs[i]);
    return Tab(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tabs[i]),
          const SizedBox(width: 5),
          KeyedSubtree(key: ValueKey('tab-mark-$i'), child: mark),
        ],
      ),
    );
  }

  if (HideScreenBar.of(context)) {
    // 見出しは出さない。タブか操作ボタンがあるときだけ、細い帯にして残す。
    if (tabs.isEmpty && actions.isEmpty) {
      return const PreferredSize(
          preferredSize: Size.zero, child: SizedBox.shrink());
    }
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      centerTitle: false,
      titleSpacing: 8,
      title: tabs.isEmpty
          ? const SizedBox.shrink()
          : TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              tabs: [for (var i = 0; i < tabs.length; i++) tab(i, height: 48)],
            ),
      actions: actions,
    );
  }
  if (EmbeddedInShell.of(context)) {
    // 左のメニューのページは、どれも「題＋タブ」の同じ形にする(グループの
    // ページと同じ)。他の画面への入口は上の帯の左端にあるので、ここの≡は出さない。
    final titleText = Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      centerTitle: false,
      titleSpacing: 12,
      title: tabs.isEmpty
          ? titleText
          : Row(
              children: [
                titleText,
                // 見出しとタブの間に縦の区切りを置き、タブの左端は薄く消す。
                // 文字1.3倍以上では、スクロールしたタブが見出しのすぐ右で
                // 切れ、見出しと続けて別の語に見えていた(2026-11-23)。
                const SizedBox(width: 10),
                SizedBox(
                  height: 20,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: const [Color(0x00000000), Color(0xFF000000)],
                      stops: [
                        0.0,
                        bounds.width <= 0
                            ? 0.0
                            : (14 / bounds.width).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds),
                    child: TabBar(
                      controller: controller,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                      tabs: [for (var i = 0; i < tabs.length; i++) tab(i, height: 48)],
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        for (final a in actions)
          if (a is! QuickAccessMenuButton) a,
      ],
    );
  }
  return AppBar(
    title: Text(title),
    leading: leading,
    actions: actions,
    bottom: tabs.isEmpty
        ? null
        : TabBar(
            controller: controller,
            isScrollable: scrollable,
            // 縦画面のタブは幅を等分するので、印は付けない(字が入らなくなる)。
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
  );
}
