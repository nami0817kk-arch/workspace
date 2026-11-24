import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/todo_advisor.dart';
import '../models/news_item.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/shell_nav.dart';
import 'todo_navigation.dart';

/// 受信箱(FM の受信箱)。左に一覧(日付・分類の印・件名)、右に開いた1件の
/// 中身と、関係する画面への入口。
///
/// 2026-11-25 に作り直し、資料の「クラブニュース」をここへ一本化した(同じ
/// お知らせを2か所で見ていた)。分類は5つ([NewsCategory])で絞り込め、
/// 本文でも探せる。名前がずらりと並ぶお知らせ(「引退: A、B、C…」)は、
/// 一覧には件名と人数だけを出し、名前は中身に回す。
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.nav});

  /// 開いた元のシェル(左メニュー)。関係する画面へ移るときに使う。
  /// 無ければ画面を重ねて開く(縦画面)。
  final ShellNav? nav;

  /// 分類と文字列で絞り込む(UI から切り離して検査できるように)。
  static List<NewsItem> filter(
    List<NewsItem> all, {
    NewsCategory? category,
    String query = '',
  }) {
    var items = all;
    if (category != null) {
      items = items.where((n) => n.category == category).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      items = items
          .where((n) =>
              n.text.toLowerCase().contains(q) ||
              n.context.toLowerCase().contains(q))
          .toList();
    }
    return items;
  }

  /// 一覧に出す件名。名前の並び(「:」のあとに「、」や「, 」で3つ以上)は
  /// 人数にまとめ、名前は中身へ回す。
  static String subjectOf(String text) {
    final m = RegExp(r'^(.{1,40}?)[:：]\s*(.+)$').firstMatch(text);
    if (m != null) {
      final rest = m.group(2)!;
      // 区切りの記号(画面の文言ではない)。i18n-ignore
      final names = rest.split(RegExp(r'、|, '));
      if (names.length >= 3) {
        return Tr.pick('${m.group(1)}(${names.length}人)',
            '${m.group(1)} (${names.length})');
      }
    }
    return text;
  }

  /// お知らせに関係する画面(押すと移る先)。分からなければ null。
  static TodoPlace? placeFor(NewsItem n) {
    final c = n.context;
    bool has(List<String> words) => words.any(c.contains);
    // 札の言葉(画面の文言ではない)。i18n-ignore
    if (has(['スタッフ', 'Staff', 'SD', 'DoF'])) return TodoPlaces.clubStaff;
    // 札の言葉(画面の文言ではない)。i18n-ignore
    if (has(['ユース', 'Youth', 'Academy'])) return TodoPlaces.clubYouth;
    // 札の言葉(画面の文言ではない)。i18n-ignore
    if (has(['施設', 'Facilit'])) return TodoPlaces.clubFacilities;
    // 札の言葉(画面の文言ではない)。i18n-ignore
    if (has(
        ['サポーター', 'Supporter', '自治体', 'Council', '年間シート', 'Season ticket'])) {
      return TodoPlaces.clubCommunity;
    }
    // 札の言葉(画面の文言ではない)。i18n-ignore
    if (has(['カップ', 'Cup'])) return TodoPlaces.leagueCups;
    return switch (n.category) {
      NewsCategory.transfers => TodoPlaces.transferTalks,
      NewsCategory.people => TodoPlaces.squadList,
      NewsCategory.money => TodoPlaces.financeOverview,
      NewsCategory.board => TodoPlaces.ownerWorld,
      NewsCategory.matches => const TodoPlace(TodoMenu.league),
    };
  }

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

extension NewsCategoryLook on NewsCategory {
  String get label => switch (this) {
        NewsCategory.transfers => Tr.pick('移籍・契約', 'Transfers'),
        NewsCategory.matches => Tr.pick('試合・大会', 'Matches'),
        NewsCategory.people => Tr.pick('選手・スタッフ', 'People'),
        NewsCategory.money => Tr.pick('お金・事業', 'Money'),
        NewsCategory.board => Tr.pick('オーナー・理事会', 'Board & owner'),
      };

  IconData get icon => switch (this) {
        NewsCategory.transfers => Icons.swap_horiz,
        NewsCategory.matches => Icons.sports_soccer,
        NewsCategory.people => Icons.groups,
        NewsCategory.money => Icons.payments_outlined,
        NewsCategory.board => Icons.account_balance,
      };

  Color color(BuildContext context) => SemanticColors.ink(
      context,
      switch (this) {
        NewsCategory.transfers => Colors.indigo,
        NewsCategory.matches => Colors.green.shade700,
        NewsCategory.people => Colors.teal,
        NewsCategory.money => Colors.brown,
        NewsCategory.board => Colors.deepPurple,
      });
}

class _InboxScreenState extends State<InboxScreen> {
  late final int _unreadAtOpen;
  NewsCategory? _category;
  String _query = '';
  bool _searching = false;
  final _search = TextEditingController();

  /// 開いている1件(一覧の中の位置ではなく、もの自体)。
  NewsItem? _open;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameState>();
    _unreadAtOpen = gs.unreadNewsCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) gs.markInboxRead();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _goTo(TodoPlace place) {
    final nav = widget.nav;
    if (nav != null && nav.wide) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      nav.go(place);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => standaloneScreenFor(place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final actions = gs.inboxActions;
    final all = gs.save?.newsLog ?? const <NewsItem>[];
    final news = InboxScreen.filter(all, category: _category, query: _query);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height && size.width >= 600;
    final open = _open != null && news.contains(_open)
        ? _open
        : (wide && news.isNotEmpty ? news.first : null);
    final counts = {
      for (final c in NewsCategory.values)
        c: all.where((n) => n.category == c).length,
    };

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 対応が要るもの(答えは状況の「やること」で)。
        if (actions.isNotEmpty)
          Material(
            color: SemanticColors.ink(context, Colors.orange.shade800)
                .withValues(alpha: 0.10),
            child: InkWell(
              key: const ValueKey('inbox-actions'),
              onTap: () => _goTo(TodoPlaces.status),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: [
                    Icon(Icons.priority_high,
                        size: 18,
                        color: SemanticColors.ink(
                            context, Colors.orange.shade800)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        Tr.pick('答えを待つものが${actions.length}件(状況の「やること」へ)',
                            '${actions.length} waiting for your answer (to do list)'),
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: SemanticColors.ink(
                                context, Colors.orange.shade800)),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: const ValueKey('inbox-cat-all'),
                  visualDensity: VisualDensity.compact,
                  label: Text(Tr.pick('すべて', 'All')),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final c in NewsCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('inbox-cat-${c.name}'),
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(c.icon, size: 16, color: c.color(context)),
                    label: Text('${c.label} ${counts[c]}'),
                    selected: _category == c,
                    onSelected: (_) =>
                        setState(() => _category = _category == c ? null : c),
                  ),
                ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: Tr.pick('本文で検索', 'Search the text'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: all.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      Tr.pick('まだお知らせはありません。節を進めると、移籍・賞金・実績などのお知らせが届きます。',
                          'Nothing yet. As you play on, transfers, prize money, achievements and the rest arrive here.'),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: SemanticColors.subtleText(context)),
                    ),
                  ),
                )
              : news.isEmpty
                  ? Center(
                      child: Text(
                        Tr.pick('該当するお知らせはありません', 'Nothing matches that'),
                        style: TextStyle(
                            color: SemanticColors.subtleText(context)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: news.length,
                      itemExtent: 52,
                      itemBuilder: (context, i) {
                        final n = news[i];
                        final unread = all.indexOf(n) < _unreadAtOpen;
                        return _InboxRow(
                          item: n,
                          unread: unread,
                          selected: wide && identical(n, open),
                          odd: i.isOdd,
                          onTap: () {
                            if (wide) {
                              setState(() => _open = n);
                            } else {
                              Navigator.of(context)
                                  .push(MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text(n.category.label)),
                                  body: _InboxDetail(item: n, onGo: _goTo),
                                ),
                              ));
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('受信箱', 'Inbox')),
        actions: [
          IconButton(
            key: const ValueKey('inbox-search'),
            tooltip: Tr.pick('本文で検索', 'Search the text'),
            icon: Icon(_searching ? Icons.search_off : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                _query = '';
              }
            }),
          ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                    width: (size.width * 0.44).clamp(300.0, 480.0),
                    child: list),
                const VerticalDivider(width: 1),
                Expanded(
                  child: open == null
                      ? const SizedBox.shrink()
                      : _InboxDetail(
                          key: ValueKey(open), item: open, onGo: _goTo),
                ),
              ],
            )
          : list,
    );
  }
}

/// 一覧の1行: 分類の印・日付・件名。
class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.item,
    required this.unread,
    required this.selected,
    required this.odd,
    required this.onTap,
  });

  final NewsItem item;
  final bool unread;
  final bool selected;
  final bool odd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = item.category;
    final when = item.date == null
        ? Tr.pick('第${item.season}季', 'S${item.season}')
        : CalendarEngine.formatShortDate(item.date!);
    return Material(
      color: selected
          ? scheme.primaryContainer
          : odd
              ? scheme.surfaceContainerLow
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(c.icon, size: 20, color: c.color(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(when,
                            style: TextStyle(
                                fontSize: 11,
                                color: SemanticColors.subtleText(context))),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(item.context,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: SemanticColors.subtleText(context))),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: scheme.primary, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      InboxScreen.subjectOf(item.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 開いた1件の中身と、関係する画面への入口。
class _InboxDetail extends StatelessWidget {
  const _InboxDetail({super.key, required this.item, required this.onGo});

  final NewsItem item;
  final void Function(TodoPlace) onGo;

  @override
  Widget build(BuildContext context) {
    final c = item.category;
    final place = InboxScreen.placeFor(item);
    return ListView(
      key: const ValueKey('inbox-detail'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(c.icon, size: 20, color: c.color(context)),
            const SizedBox(width: 6),
            Text(c.label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: c.color(context))),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            if (item.date != null) CalendarEngine.formatDate(item.date!),
            Tr.pick('第${item.season}季', 'Season ${item.season}'),
            item.context,
          ].join(' • '),
          style: TextStyle(
              fontSize: 12, color: SemanticColors.subtleText(context)),
        ),
        const Divider(height: 20),
        SelectableText(item.text,
            style: const TextStyle(fontSize: 15, height: 1.5)),
        if (place != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('inbox-go'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(Tr.pick('関係する画面を開く', 'Open the related screen')),
              onPressed: () => onGo(place),
            ),
          ),
        ],
      ],
    );
  }
}
