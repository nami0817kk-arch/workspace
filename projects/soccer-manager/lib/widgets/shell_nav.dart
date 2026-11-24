import 'package:flutter/material.dart';

import '../logic/todo_advisor.dart';

/// 横画面のシェル(左メニューとその下のタブ)の、いま開いている場所。
///
/// 「やること」の行や知らせの札を押したとき、別の画面を重ねて開くのでは
/// なく、左メニューの項目とタブを切り替える。以前は行き先を新しい画面と
/// して重ねていて、左メニューにある画面が二重に開いていた。
///
/// 場所を変える口は [go] の1つだけ。タブの番号は [TodoPlaces] に集めて
/// あるので、タブの構成を変えるときはそちらを直す。
class ShellNav extends ChangeNotifier {
  TodoMenu _menu = TodoMenu.status;
  final Map<TodoMenu, int> _tabs = {};
  String? _card;
  int _cardSerial = 0;

  /// 横画面(左メニューがある)か。縦画面では項目を切り替えず、今まで
  /// どおり画面を重ねて開く。シェルが描くたびに書き込む。
  bool wide = false;

  /// いま開いている左メニューの項目。
  TodoMenu get menu => _menu;

  /// [menu] で開いているタブ(左から0始まり)。
  int tabOf(TodoMenu menu) => _tabs[menu] ?? 0;

  /// 最後に頼まれた札(オーナーの仕事の分野など)と、その通し番号。
  /// 同じ札を続けて頼まれても、番号が変わるので分かる。
  String? get card => _card;
  int get cardSerial => _cardSerial;

  /// [place] へ移る(左メニューの項目・タブ・札)。
  void go(TodoPlace place) {
    _menu = place.menu;
    _tabs[place.menu] = place.tab;
    if (place.card != null) {
      _card = place.card;
      _cardSerial++;
    }
    notifyListeners();
  }

  /// 左メニューの項目だけを切り替える(タブはそのまま)。
  void select(TodoMenu menu) {
    if (_menu == menu) return;
    _menu = menu;
    notifyListeners();
  }

  /// 利用者がタブを切り替えたのを控える。
  void setTab(TodoMenu menu, int tab) {
    if (tabOf(menu) == tab) return;
    _tabs[menu] = tab;
    notifyListeners();
  }

  /// いちばん近いシェルの場所。シェルの外(重ねて開いた画面)では null。
  static ShellNav? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellNavScope>()?.notifier;
}

/// [ShellNav] を下の画面に渡す。
class ShellNavScope extends InheritedNotifier<ShellNav> {
  const ShellNavScope({
    super.key,
    required ShellNav nav,
    required super.child,
  }) : super(notifier: nav);
}

/// タブを持つ画面(経営・移籍)のタブを、[ShellNav] と合わせる。
///
/// シェルの中に埋め込まれているときだけ働く。[controller] を省くと、上の
/// [DefaultTabController] を使う。
class ShellTabSync extends StatefulWidget {
  const ShellTabSync({
    super.key,
    required this.menu,
    required this.child,
    this.controller,
    this.enabled = true,
  });

  final TodoMenu menu;

  /// 合わせるか。単独で開いた画面(左メニューの外)では false。
  final bool enabled;
  final TabController? controller;
  final Widget child;

  @override
  State<ShellTabSync> createState() => _ShellTabSyncState();
}

class _ShellTabSyncState extends State<ShellTabSync> {
  ShellNav? _nav;
  TabController? _tabs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = widget.enabled ? ShellNav.maybeOf(context) : null;
    final tabs = widget.controller ?? DefaultTabController.maybeOf(context);
    if (nav != _nav) {
      _nav?.removeListener(_fromNav);
      _nav = nav?..addListener(_fromNav);
    }
    if (tabs != _tabs) {
      _tabs?.removeListener(_fromTabs);
      _tabs = tabs?..addListener(_fromTabs);
    }
    // 描いている最中にタブを動かすと、タブの帯の描き直しとぶつかる。
    // この描画が終わってから合わせる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fromNav();
    });
  }

  void _fromNav() {
    final nav = _nav, tabs = _tabs;
    if (nav == null || tabs == null) return;
    final want = nav.tabOf(widget.menu).clamp(0, tabs.length - 1);
    if (tabs.index != want && !tabs.indexIsChanging) tabs.animateTo(want);
  }

  void _fromTabs() {
    final nav = _nav, tabs = _tabs;
    if (nav == null || tabs == null || tabs.indexIsChanging) return;
    nav.setTab(widget.menu, tabs.index);
  }

  @override
  void dispose() {
    _nav?.removeListener(_fromNav);
    _tabs?.removeListener(_fromTabs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
