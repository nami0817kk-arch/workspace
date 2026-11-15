import 'package:flutter/material.dart';

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

/// 各画面の上の帯。
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
}) {
  if (EmbeddedInShell.of(context)) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 40,
      centerTitle: false,
      titleSpacing: 8,
      title: tabs.isEmpty
          ? Text(title, style: const TextStyle(fontSize: 15))
          : TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              tabs: [for (final t in tabs) Tab(height: 36, text: t)],
            ),
      actions: actions,
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
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
  );
}
