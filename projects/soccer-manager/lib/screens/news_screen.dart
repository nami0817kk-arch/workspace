import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/news_item.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// クラブニュース(お知らせ履歴)画面。SnackBarやダイアログで一度だけ
/// 流れて消える通知(移籍・賞金・実績・シーズン開始の出来事など)を、
/// 新しい順にいつでも見返せる。
///
/// 1シーズン回すだけで数十件が積み上がり、種類もユース・移籍・カップ・
/// 理事会と混ざる。並べるだけでは「あの話はどこだったか」を探せないので、
/// 種類での絞り込みと検索を付けてある。
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  /// 種類と文字列で絞り込む。UIから切り離してテストできるようにしてある。
  static List<NewsItem> filter(
    List<NewsItem> all, {
    String? context,
    String query = '',
  }) {
    var items = all;
    if (context != null) {
      items = items.where((n) => n.context == context).toList();
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

  /// 実際にニュースが記録されている種類だけを、多い順に返す。
  ///
  /// 全種類を並べると、まだ1件も起きていない種類のボタンが並ぶ。押しても
  /// 空になるボタンは、選択肢ではなく邪魔になる。
  static List<String> contextsIn(List<NewsItem> all) {
    final counts = <String, int>{};
    for (final n in all) {
      counts[n.context] = (counts[n.context] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys;
  }

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String? _context;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final List<NewsItem> all = gameState.save?.newsLog ?? const [];
    final contexts = NewsScreen.contextsIn(all);
    // 絞り込んだ結果が0件でも、種類のボタンは全部出したままにする。
    // 消すと、いま何で絞っているのかが分からなくなる。
    final news =
        NewsScreen.filter(all, context: _context, query: _query);

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('クラブニュース', 'Club news')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: all.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    Tr.pick(
                        'まだニュースはありません。\n節を進めると、移籍・賞金・実績などのお知らせがここに記録されていきます。',
                        'No news yet.\nAs you play through the matchdays, transfers, prize money, achievements and the rest are recorded here.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SemanticColors.subtleText(context)),
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: Tr.pick('本文で検索', 'Search the text'),
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: Tr.pick('検索をクリア', 'Clear the search'),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(Tr.pick('すべて', 'All')),
                            selected: _context == null,
                            onSelected: (_) => setState(() => _context = null),
                          ),
                        ),
                        for (final c in contexts)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: _context == c,
                              onSelected: (_) => setState(
                                  () => _context = _context == c ? null : c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: news.isEmpty
                        ? Center(
                            child: Text(
                              Tr.pick('該当するお知らせはありません',
                                  'Nothing matches that'),
                              style: TextStyle(
                                  color: SemanticColors.subtleText(context)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: news.length,
                            itemBuilder: (context, index) {
                              final item = news[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    _iconFor(item.context),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  title: Text(item.text),
                                  subtitle: Text(
                                    Tr.pick(
                                        'シーズン${item.season}・${item.context}',
                                        'Season ${item.season} • ${item.context}'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _iconFor(String context) {
    if (context.contains(Tr.pick('移籍', 'Transfer'))) return Icons.swap_horiz;
    if (context.contains(Tr.pick('カップ', 'Cup'))) return Icons.emoji_events;
    if (context.contains(Tr.pick('実績', 'Achievement'))) {
      return Icons.military_tech;
    }
    if (context.contains(Tr.pick('ユース', 'Youth'))) return Icons.eco;
    if (context.contains(Tr.pick('表彰', 'Award'))) return Icons.star;
    if (context.contains(Tr.pick('シーズン開始', 'Season start'))) return Icons.flag;
    return Icons.info_outline;
  }
}
