import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import 'contract_offer_screen.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/player_stat_chips.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'glossary_screen.dart';
import 'player_compare_screen.dart';
import '../logic/match_engine.dart';
import '../models/player_instruction.dart';
import '../widgets/squad_table.dart';
import 'player_detail_screen.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';
import '../widgets/screen_bar.dart';
import '../logic/economy_scale.dart';

enum SquadSortOption {
  position,
  overall,
  age,
  potential,
  wage,
  fatigue,
  sharpness,
  happiness,
  contract,
  marketValue,
}

extension on SquadSortOption {
  String get label => switch (this) {
        SquadSortOption.position => Tr.pick('ポジション順', 'By position'),
        SquadSortOption.overall => Tr.pick('総合力', 'Overall'),
        SquadSortOption.age => Tr.pick('年齢(若い順)', 'Age (youngest)'),
        SquadSortOption.potential => Tr.pick('ポテンシャル', 'Potential'),
        SquadSortOption.wage => Tr.pick('年俸', 'Salary'),
        SquadSortOption.fatigue => Tr.pick('疲労が大きい順', 'Most tired'),
        SquadSortOption.sharpness => Tr.pick('実戦感覚が低い順', 'Least sharp'),
        SquadSortOption.happiness => Tr.pick('不満が大きい順', 'Least happy'),
        SquadSortOption.contract =>
          Tr.pick('契約残りが短い順', 'Contract running down'),
        SquadSortOption.marketValue => Tr.pick('市場価値', 'Value'),
      };
}

/// スカッドの状況で絞り込むフィルタ。
enum SquadStatusFilter { all, starters, bench, needsAttention }

extension SquadStatusFilterInfo on SquadStatusFilter {
  String get label => switch (this) {
        SquadStatusFilter.all => Tr.pick('すべて', 'All'),
        SquadStatusFilter.starters => Tr.pick('スタメン', 'Starters'),
        SquadStatusFilter.bench => Tr.pick('控え', 'Backups'),
        SquadStatusFilter.needsAttention => Tr.pick('要対応', 'Needs attention'),
      };
}

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  /// 「要対応」フィルタが拾う状態かどうか。負傷・出場停止・移籍希望のほか、
  /// 疲労過多・実戦感覚の低下(成長ペナルティ圏)・契約最終年(ローンを除く)
  /// といった「放置するとまずい」状態を横断的に検知する。
  static bool needsAttention(Player p) =>
      p.isInjured ||
      p.isSuspended ||
      p.wantsTransfer ||
      p.fatigue >= 75 ||
      (!p.isLoanedOut && p.matchSharpness < 40) ||
      (!p.isLoan && p.contractYearsRemaining <= 1);

  /// フィルタ・検索・並び替えを適用した選手リストを返す。UIから切り離してテスト可能にしてある。
  /// [status]でスタメン/控え/要対応を絞り込む場合は[startingIds]
  /// (現在の先発ID)を渡す。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    SquadSortOption sort = SquadSortOption.position,
    SquadStatusFilter status = SquadStatusFilter.all,
    Set<String> startingIds = const {},
  }) {
    var players = all;
    if (group != null) {
      players = players.where((p) => p.position.group == group).toList();
    }
    switch (status) {
      case SquadStatusFilter.all:
        break;
      case SquadStatusFilter.starters:
        players = players.where((p) => startingIds.contains(p.id)).toList();
        break;
      case SquadStatusFilter.bench:
        players = players
            .where((p) => !startingIds.contains(p.id) && !p.isLoanedOut)
            .toList();
        break;
      case SquadStatusFilter.needsAttention:
        players = players.where(needsAttention).toList();
        break;
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      players = players.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else {
      players = [...players];
    }
    switch (sort) {
      case SquadSortOption.position:
        players.sort((a, b) {
          final c = a.position.index.compareTo(b.position.index);
          if (c != 0) return c;
          return b.overall.compareTo(a.overall);
        });
        break;
      case SquadSortOption.overall:
        players.sort((a, b) => b.overall.compareTo(a.overall));
        break;
      case SquadSortOption.age:
        players.sort((a, b) => a.age.compareTo(b.age));
        break;
      case SquadSortOption.potential:
        players.sort((a, b) => b.potential.compareTo(a.potential));
        break;
      case SquadSortOption.wage:
        players.sort((a, b) => b.wage.compareTo(a.wage));
        break;
      case SquadSortOption.fatigue:
        players.sort((a, b) => b.fatigue.compareTo(a.fatigue));
        break;
      case SquadSortOption.sharpness:
        players.sort((a, b) => a.matchSharpness.compareTo(b.matchSharpness));
        break;
      case SquadSortOption.happiness:
        players.sort((a, b) => a.happiness.compareTo(b.happiness));
        break;
      case SquadSortOption.contract:
        // ローン加入選手には自クラブとの契約年数の概念がないため末尾に回す。
        int key(Player p) => p.isLoan ? 999 : p.contractYearsRemaining;
        players.sort((a, b) => key(a).compareTo(key(b)));
        break;
      case SquadSortOption.marketValue:
        players.sort((a, b) => b.marketValue.compareTo(a.marketValue));
        break;
    }
    return players;
  }

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  bool _compareMode = false;

  /// 表(FM風の密な一覧)で見せるか。横画面の既定は表、押すとカードに切り替わる。
  bool _table = true;
  final List<String> _selected = [];
  PositionGroup? _filterGroup;
  SquadSortOption _sort = SquadSortOption.position;
  SquadStatusFilter _statusFilter = SquadStatusFilter.all;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCompareMode() {
    setState(() {
      _compareMode = !_compareMode;
      _selected.clear();
    });
  }

  void _toggleSelected(String playerId) {
    setState(() {
      if (_selected.contains(playerId)) {
        _selected.remove(playerId);
      } else {
        if (_selected.length >= 2) _selected.removeAt(0);
        _selected.add(playerId);
      }
    });
  }

  void _showContractSheet(BuildContext context, Player p) {
    final gameState = context.read<GameState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final renewalCost = gameState.renewalCostFor(p.id);
        final signingBonus = gameState.signingBonusFor(p.id);
        final totalCost = renewalCost + signingBonus;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  Tr.pick(
                      '年俸: ${formatMoney(annualFromWeekly(p.wage))} / ${ContractEngine.contractLabel(p)}',
                      'Salary: ${formatMoney(annualFromWeekly(p.wage))} / ${ContractEngine.contractLabel(p)}'),
                ),
                const SizedBox(height: 12),
                if (gameState.renewalBlockReason(p) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(gameState.renewalBlockReason(p)!,
                        style: TextStyle(
                            fontSize: 12,
                            color: SemanticColors.negative(context))),
                  ),
                if (gameState.save!.budget < totalCost)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      Tr.pick(
                          '資金が${formatMoney(totalCost - gameState.save!.budget)}足りません'
                              '（必要${formatMoney(totalCost)} / 手元${formatMoney(gameState.save!.budget)}）。',
                          'You are ${formatMoney(totalCost - gameState.save!.budget)} short '
                              '(need ${formatMoney(totalCost)}, you have ${formatMoney(gameState.save!.budget)}).'),
                      style: TextStyle(
                          fontSize: 12,
                          color: SemanticColors.negative(context)),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: gameState.save!.budget < totalCost ||
                            gameState.renewalBlockReason(p) != null
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            openContractOffer(context,
                                player: p, kind: ContractKind.renewal);
                          },
                    child: Text(
                      Tr.pick(
                          '契約の更新を話し合う（手数料${formatMoney(renewalCost)} + サイン料${formatMoney(signingBonus)}）',
                          'Discuss a new contract (fee ${formatMoney(renewalCost)} + bonus ${formatMoney(signingBonus)})'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(playerId: p.id),
                        ),
                      );
                    },
                    child: Text(Tr.pick('年俸交渉・放出など詳しい操作を開く',
                        'Open wage talks, release and other actions')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showIconLegend(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('アイコンの意味', 'What the icons mean')),
        // 横画面(高さ390前後)では全部の行が入りきらず、はみ出しの縞が出ていた。
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendRow(
                icon: Icons.swap_horiz,
                color: Colors.indigo,
                label: Tr.pick('ローンで加入中の選手', 'On loan at your club'),
              ),
              _LegendRow(
                icon: Icons.sentiment_dissatisfied,
                color: Colors.redAccent,
                label: Tr.pick('移籍を希望している', 'Wants a move away'),
              ),
              _LegendRow(
                icon: Icons.flag,
                color: Colors.blueAccent,
                label: Tr.pick('代表召集中', 'On international duty'),
              ),
              // キャプテンを指名する手段は今は無い(2026-11-16 のオーナー型への
              // 作り替えから)。印の表示は古いセーブのために残し、凡例からは外す。
              _LegendRow(
                icon: Icons.block,
                color: Colors.redAccent,
                label: Tr.pick('出場停止中(警告累積または退場)',
                    'Suspended (booked too often, or sent off)'),
              ),
              _LegendRow(
                icon: Icons.flight_takeoff,
                color: Colors.deepPurple,
                label: Tr.pick('他クラブへローン放出中', 'Out on loan elsewhere'),
              ),
              _LegendRow(
                icon: Icons.sell_outlined,
                color: Colors.orange,
                label: Tr.pick('移籍リストに登録中', 'On the transfer list'),
              ),
              _LegendRow(
                icon: Icons.trending_up,
                color: Colors.green,
                label: Tr.pick('総合値の下の▲/▼ = 直近5節の総合力の変化(成長トレンド)',
                    '▲/▼ under the overall = change across the last 5 matchdays'),
              ),
              _LegendRow(
                icon: Icons.monitor_heart_outlined,
                color: Colors.grey,
                label: Tr.pick('2行目の疲労/感覚/士気は、問題のある値だけ赤く強調される',
                    'On the second line, only fatigue, sharpness and morale that need attention turn red'),
              ),
              _LegendRow(
                icon: Icons.workspace_premium,
                color: Colors.teal,
                label: Tr.pick('名前の横のKP/ROT/育成 = スカッド・ステータス(主力は非表示)',
                    'KP/ROT/Prospect beside the name is his squad status (first-team players show nothing)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width > screen.height;
    final players = SquadScreen.filterAndSort(
      team.players,
      group: _filterGroup,
      query: _query,
      sort: _sort,
      status: _statusFilter,
      startingIds: team.startingXI.toSet(),
    );
    final lastRatings = gameState.save!.league
        .lastPlayedFixtureFor(team.id)
        ?.result
        ?.playerRatings;
    Widget cardFor(BuildContext context, int i) =>
        _card(context, players, i, team, lastRatings);

    final actions = <Widget>[
      if (!_compareMode) ...[
        // 横画面は細い段に収めるので、アイコンの意味と用語集を1つの「?」にまとめる。
        if (wide)
          PopupMenuButton<int>(
            icon: const Icon(Icons.help_outline),
            tooltip: Tr.pick('アイコンの意味・用語集', 'Icons and glossary'),
            onSelected: (v) => v == 0
                ? _showIconLegend(context)
                : Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GlossaryScreen())),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 0,
                  child: Text(Tr.pick('アイコンの意味', 'What the icons mean'))),
              PopupMenuItem(value: 1, child: Text(Tr.pick('用語集', 'Glossary'))),
            ],
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: Tr.pick('アイコンの意味', 'What the icons mean'),
            onPressed: () => _showIconLegend(context),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: Tr.pick('用語集', 'Glossary'),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GlossaryScreen())),
          ),
        ],
        PopupMenuButton<SquadSortOption>(
          icon: const Icon(Icons.sort),
          tooltip: Tr.pick('並び替え', 'Sort'),
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (context) => [
            for (final option in SquadSortOption.values)
              PopupMenuItem(value: option, child: Text(option.label)),
          ],
        ),
      ],
      IconButton(
        icon: Icon(_compareMode ? Icons.close : Icons.compare_arrows),
        tooltip: _compareMode
            ? Tr.pick('比較モードを終了', 'Leave compare mode')
            : Tr.pick('選手を比較', 'Compare players'),
        onPressed: _toggleCompareMode,
      ),
    ];

    return Scaffold(
      appBar: screenBar(
        context,
        title: _compareMode
            ? Tr.pick('選手を2人選択', 'Pick two players')
            : Tr.pick('スカッド', 'Squad'),
        // 下タブの一員でもあり、ホームやガイドから直接開かれもする。
        // 開かれた場合は戻るボタンを出す(ドロワーがあると既定では出ない)。
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        // 横画面では印を表の上の細い段に置く(上の段を空にして縦を空ける)。
        actions: wide ? const [] : actions,
      ),
      drawer: const QuickAccessDrawer(),
      floatingActionButton: _compareMode && _selected.length == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => PlayerCompareScreen(
                          playerAId: _selected[0],
                          playerBId: _selected[1],
                        ),
                      ),
                    )
                    .then((_) => _toggleCompareMode());
              },
              icon: const Icon(Icons.compare_arrows),
              label: Text(Tr.pick('比較する', 'Compare')),
            )
          : null,
      body: ResponsiveBody(
        maxWidth: wide ? 1100 : 720,
        child: _SquadLayout(
          wide: wide,
          toolbar: _compareMode
              ? Row(children: [
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(Tr.pick('選手を2人選択', 'Pick two players'),
                          style: Theme.of(context).textTheme.titleSmall)),
                  ...actions,
                ])
              : _SquadToolbar(
                  team: team,
                  table: _table,
                  onTable: (v) => setState(() => _table = v),
                  group: _filterGroup,
                  onGroup: (g) => setState(() => _filterGroup = g),
                  status: _statusFilter,
                  onStatus: (f) => setState(() => _statusFilter = f),
                  searchController: _searchController,
                  query: _query,
                  onQuery: (v) => setState(() => _query = v),
                  actions: actions,
                ),
          header: [
            if (!_compareMode) _SquadSummaryCard(team: team),
            if (!_compareMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style:
                        const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(
                          value: true, label: Text(Tr.pick('表', 'Table'))),
                      ButtonSegment(
                          value: false, label: Text(Tr.pick('カード', 'Cards'))),
                    ],
                    selected: {_table},
                    onSelectionChanged: (s) => setState(() => _table = s.first),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: PositionFilterBar(
                wrap: wide,
                value: _filterGroup,
                onChanged: (g) => setState(() => _filterGroup = g),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final f in SquadStatusFilter.values)
                      ChoiceChip(
                        label: Text(
                          f == SquadStatusFilter.needsAttention
                              ? '${f.label} '
                                  '${team.players.where(SquadScreen.needsAttention).length}'
                              : f.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        selected: _statusFilter == f,
                        onSelected: (_) => setState(() => _statusFilter = f),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: Tr.pick('選手名で検索', 'Search by name'),
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
          ],
          list: players.isEmpty
              ? Center(child: Text(Tr.pick('該当する選手がいません', 'No players match')))
              : (_table && !_compareMode)
                  ? SquadTable(
                      players: players,
                      startingIds: team.startingXI.toSet(),
                      onTap: (p) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerDetailScreen(playerId: p.id),
                        ),
                      ),
                    )
                  : (wide
                      // 横画面のカードは2列。1列だと幅が余り、文が詰まって見えた。
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: (players.length + 1) ~/ 2,
                          itemBuilder: (context, row) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final i in [row * 2, row * 2 + 1])
                                Expanded(
                                  child: i < players.length
                                      ? cardFor(context, i)
                                      : const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: players.length,
                          itemBuilder: cardFor,
                        )),
        ),
      ),
    );
  }

  /// 選手のカード1枚。
  Widget _card(BuildContext context, List<Player> players, int i, Team team,
      Map<String, double>? lastRatings) {
    final gameState = context.read<GameState>();
    final p = players[i];
    final isStarting = team.startingXI.contains(p.id);
    final isSelected = _selected.contains(p.id);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: ListTile(
        // **既定の余白を詰める。** 左右16・顔との間16が
        // 既定で、そのぶん本文の幅が減って「役割 スイーパー
        // キーパー」が折り返していた。
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        horizontalTitleGap: 10,
        minLeadingWidth: 40,
        tileColor: isSelected
            ? Theme.of(context).colorScheme.secondaryContainer
            : isStarting
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3)
                : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: _compareMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelected(p.id),
              )
            : PlayerFaceAvatar(
                playerId: p.id,
                position: p.position,
                size: 40,
                highlighted: isStarting,
              ),
        title: Row(
          children: [
            // 背番号。ユースから上げた選手と移籍加入の
            // 選手に付く。旧セーブでは未設定なので出さない。
            if (p.squadNumber != null) ...[
              Text(
                '${p.squadNumber}',
                style: TextStyle(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: SemanticColors.subtleText(context),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                p.name,
                overflow: TextOverflow.ellipsis,
                // 名前が主役。既定の太さだと、下に続く
                // 細かい数字と同じ重さに見えていた。
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            // 生え抜き(自クラブのユース出身)。買ってきた
            // 選手と育てた選手を見分けられるようにする。
            if (p.academyGraduate) ...[
              const SizedBox(width: 6),
              Tooltip(
                message:
                    Tr.pick('生え抜き(自クラブのユース出身)', 'Came through your academy'),
                child: Icon(
                  Icons.eco,
                  size: 14,
                  color: SemanticColors.positive(context),
                ),
              ),
            ],
            if (team.captainId == p.id) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('キャプテン', 'Captain'),
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.amber.shade700,
                  child: const Text(
                    'C',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (team.viceCaptainId == p.id) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('副キャプテン', 'Vice captain'),
                child: const CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.blueGrey,
                  child: Text(
                    'VC',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (p.squadStatus != SquadStatus.regular) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('スカッド・ステータス: ${p.squadStatus.label}',
                    'Squad status: ${p.squadStatus.label}'),
                child: Text(
                  switch (p.squadStatus) {
                    SquadStatus.keyPlayer => 'KP',
                    SquadStatus.rotation => 'ROT',
                    SquadStatus.prospect => Tr.pick('育成', 'Prospect'),
                    SquadStatus.regular => '',
                  },
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: switch (p.squadStatus) {
                      SquadStatus.keyPlayer => Colors.amber.shade800,
                      SquadStatus.rotation => Colors.teal,
                      _ => SemanticColors.subtleText(context),
                    },
                  ),
                ),
              ),
            ],
            if (p.isLoan) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('ローン加入中', 'On loan here'),
                child: const Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: Colors.indigo,
                ),
              ),
            ],
            if (p.wantsTransfer) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('移籍を希望している', 'Wants a move away'),
                child: const Icon(
                  Icons.sentiment_dissatisfied,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ],
            if (p.isOnInternationalDuty) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: p.onTournamentLeave
                    ? Tr.pick('大会明けの休み', 'Post-tournament break')
                    : Tr.pick('代表召集中', 'On international duty'),
                child: const Icon(
                  Icons.flag,
                  size: 16,
                  color: Colors.blueAccent,
                ),
              ),
            ],
            if (p.isSuspended) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('出場停止中', 'Suspended'),
                child: const Icon(
                  Icons.block,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ],
            if (p.isLoanedOut) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('ローンで放出中', 'Out on loan'),
                child: const Icon(
                  Icons.flight_takeoff,
                  size: 16,
                  color: Colors.deepPurple,
                ),
              ),
            ],
            if (p.isTransferListed) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: Tr.pick('移籍リストに登録済み', 'On the transfer list'),
                child: const Icon(
                  Icons.sell_outlined,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.isInjured
                  ? Tr.pick('負傷中（あと${p.injuryWeeks}週）',
                      'Injured (${Tr.plural(p.injuryWeeks, 'week')})')
                  : p.isSuspended
                      ? Tr.pick('出場停止（あと${p.suspendedMatches}試合）',
                          'Suspended (${Tr.plural(p.suspendedMatches, 'match', 'matches')})')
                      : p.onTournamentLeave
                          ? Tr.pick('大会明けの休み（合流前）',
                              'Post-tournament break (not back yet)')
                          : p.isOnInternationalDuty
                              ? Tr.pick(
                                  '代表召集中（あと${p.internationalDutyWeeksRemaining}週）',
                                  'On international duty (${Tr.plural(p.internationalDutyWeeksRemaining, 'week')})')
                              : p.isLoanedOut
                                  ? Tr.pick(
                                      '${p.loanedOutToClubName}へローン放出中（あと${p.loanedOutWeeksRemaining}週）',
                                      'On loan at ${p.loanedOutToClubName} (${Tr.plural(p.loanedOutWeeksRemaining, 'week')} left)')
                                  : p.notRegistered
                                      ? Tr.pick('登録外（次の移籍の窓まで公式戦に出られない）',
                                          'Not registered (ineligible until the next window)')
                                      : Tr.pick(
                                          // 総合力は右端に大きく出している。ここに重ねて書くと、
                                          // 同じ数字が1行に2回並ぶうえ、行が長くなって
                                          // 「契約残り3年」が途中で折り返していた。
                                          '${p.age}歳 / ${p.position.label}${lastRatings?[p.id] != null ? ' / 前節 ${lastRatings![p.id]!.toStringAsFixed(1)}' : ''}${p.isLoan ? '' : ' / ${ContractEngine.contractLabel(p)}'}',
                                          "Age ${p.age} / ${p.position.label}${lastRatings?[p.id] != null ? ' / last ${lastRatings![p.id]!.toStringAsFixed(1)}' : ''}${p.isLoan ? '' : ' / ${ContractEngine.contractLabel(p)}'}"),
              style: (p.isInjured ||
                      p.isSuspended ||
                      p.isOnInternationalDuty ||
                      p.isLoanedOut ||
                      p.notRegistered)
                  ? const TextStyle(color: Colors.redAccent)
                  : (!p.isLoan && p.contractYearsRemaining <= 1)
                      ? const TextStyle(color: Colors.orange)
                      : null,
            ),
            // 特性・役割・指示は選手詳細を開かないと
            // 見えなかった。25人ぶん開いて回らないと
            // 誰がどういう選手か分からない状態だったので、
            // 設定されているものだけ一覧にも出す。
            if (!_compareMode) _PlayerTagsLine(player: p),
            if (!_compareMode &&
                !p.isInjured &&
                !p.isSuspended &&
                !p.isOnInternationalDuty &&
                !p.isLoanedOut)
              _ConditionLine(
                player: p,
                stats: gameState.seasonStatsFor(p.id),
              ),
          ],
        ),
        trailing: _compareMode
            ? OverallBadge(overall: p.overall)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      // 成長トレンド: 直近5節前と比べた
                      // 総合力の変化(記録が浅ければ先頭と比較)。
                      final h = p.overallHistory;
                      final trend = h.length >= 2
                          ? h.last - h[h.length >= 6 ? h.length - 6 : 0]
                          : 0;
                      // ListTile の右端は高さが決まっている。伸びの印を足すと
                      // 2px はみ出していたので、収まらないときは縮める。
                      return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OverallBadge(overall: p.overall),
                              if (trend != 0)
                                Tooltip(
                                  message: Tr.pick('直近5節の総合力の変化',
                                      'Change over the last 5 matchdays'),
                                  child: Text(
                                    trend > 0 ? '▲$trend' : '▼${-trend}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: trend > 0
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ));
                    },
                  ),
                  if (!p.isLoan && !p.isLoanedOut) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.description_outlined,
                        size: 20,
                      ),
                      tooltip: Tr.pick('契約を操作', 'Contract actions'),
                      onPressed: () => _showContractSheet(context, p),
                    ),
                  ],
                ],
              ),
        onTap: _compareMode
            ? () => _toggleSelected(p.id)
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlayerDetailScreen(playerId: p.id),
                  ),
                ),
      ),
    );
  }
}

/// 絞り込みと一覧の並べ方。縦長の画面では上下に積む。横長の画面では
/// 細い段を1本だけ置き、一覧を幅いっぱいに出す。
///
/// 以前の横画面は左に幅340の絞り込みの欄を置いていて、表が画面の半分しか
/// なく名前が「ウィリアム・ヒ…」で切れた(2026-11-21 に変更)。
class _SquadLayout extends StatelessWidget {
  final bool wide;
  final Widget toolbar;
  final List<Widget> header;
  final Widget list;

  const _SquadLayout({
    required this.wide,
    required this.toolbar,
    required this.header,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(children: [...header, Expanded(child: list)]);
    }
    return Column(
      children: [
        SizedBox(height: 48, child: toolbar),
        const Divider(height: 1),
        Expanded(child: list),
      ],
    );
  }
}

/// 横画面の表の上の細い段。集計・表とカード・位置・状態・検索・印のボタン。
class _SquadToolbar extends StatefulWidget {
  const _SquadToolbar({
    required this.team,
    required this.table,
    required this.onTable,
    required this.group,
    required this.onGroup,
    required this.status,
    required this.onStatus,
    required this.searchController,
    required this.query,
    required this.onQuery,
    required this.actions,
  });

  final Team team;
  final bool table;
  final ValueChanged<bool> onTable;
  final PositionGroup? group;
  final ValueChanged<PositionGroup?> onGroup;
  final SquadStatusFilter status;
  final ValueChanged<SquadStatusFilter> onStatus;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQuery;
  final List<Widget> actions;

  @override
  State<_SquadToolbar> createState() => _SquadToolbarState();
}

class _SquadToolbarState extends State<_SquadToolbar> {
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final players = widget.team.players;
    final count = players.length;
    final avg = count == 0
        ? 0
        : (players.fold<int>(0, (s, p) => s + p.overall) / count).round();
    final injured = players.where((p) => p.isInjured).length;
    final attention = players.where(SquadScreen.needsAttention).length;
    final subtle = SemanticColors.subtleText(context);
    final searching = _searching || widget.query.isNotEmpty;

    Widget menu<T>({
      required String label,
      required T value,
      required List<T> options,
      required String Function(T) name,
      required ValueChanged<T> onSelected,
    }) =>
        PopupMenuButton<T>(
          tooltip: label,
          initialValue: value,
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final o in options)
              PopupMenuItem(value: o, child: Text(name(o))),
          ],
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$label: ', style: TextStyle(fontSize: 12, color: subtle)),
              Text(name(value),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Icon(Icons.arrow_drop_down, size: 18),
            ]),
          ),
        );

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // 集計(人数・平均・負傷)。年俸の合計は「登録と契約」にある。
                Text.rich(
                  TextSpan(style: const TextStyle(fontSize: 12), children: [
                    TextSpan(text: Tr.pick('$count人', '$count players')),
                    TextSpan(
                        text: Tr.pick('・平均$avg', ' • avg $avg'),
                        style: TextStyle(color: subtle)),
                    if (injured > 0)
                      TextSpan(
                          text: Tr.pick('・負傷$injured', ' • injured $injured'),
                          style: const TextStyle(color: Colors.redAccent)),
                  ]),
                ),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.table_rows_outlined, size: 18),
                        tooltip: Tr.pick('表', 'Table')),
                    ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.grid_view, size: 18),
                        tooltip: Tr.pick('カード', 'Cards')),
                  ],
                  selected: {widget.table},
                  onSelectionChanged: (s) => widget.onTable(s.first),
                ),
                const SizedBox(width: 8),
                menu<PositionGroup?>(
                  label: Tr.pick('位置', 'Position'),
                  value: widget.group,
                  options: [null, ...PositionGroup.values],
                  name: PositionFilterBar.labelFor,
                  onSelected: widget.onGroup,
                ),
                const SizedBox(width: 8),
                menu<SquadStatusFilter>(
                  label: Tr.pick('状態', 'Status'),
                  value: widget.status,
                  options: SquadStatusFilter.values,
                  name: (f) => f == SquadStatusFilter.needsAttention
                      ? '${f.label} $attention'
                      : f.label,
                  onSelected: widget.onStatus,
                ),
                const SizedBox(width: 8),
                if (searching)
                  SizedBox(
                    width: 170,
                    height: 36,
                    child: TextField(
                      controller: widget.searchController,
                      autofocus: widget.query.isEmpty,
                      onChanged: widget.onQuery,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: Tr.pick('選手名で検索', 'Search by name'),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: Tr.pick('検索をクリア', 'Clear the search'),
                          onPressed: () {
                            widget.searchController.clear();
                            widget.onQuery('');
                            setState(() => _searching = false);
                          },
                        ),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: Tr.pick('選手名で検索', 'Search by name'),
                    onPressed: () => setState(() => _searching = true),
                  ),
              ],
            ),
          ),
        ),
        ...widget.actions,
      ],
    );
  }
}

class _SquadSummaryCard extends StatelessWidget {
  final Team team;

  const _SquadSummaryCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final players = team.players;
    final count = players.length;
    final avgOverall = count == 0
        ? 0
        : (players.fold<int>(0, (s, p) => s + p.overall) / count).round();
    final avgAge = count == 0
        ? 0
        : (players.fold<int>(0, (s, p) => s + p.age) / count).round();
    final wageBill = ContractEngine.weeklyWageBill(team);
    final injured = players.where((p) => p.isInjured).length;
    final attention = players.where(SquadScreen.needsAttention).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          // 6項目を1行に並べると、英語のラベル(Needs attention など)では
          // 幅に収まらない。折り返せるようにして、収まるときは
          // これまでどおり均等配置になるようにする。
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              _SummaryItem(label: Tr.pick('人数', 'Players'), value: '$count'),
              _SummaryItem(
                  label: Tr.pick('平均総合', 'Avg overall'), value: '$avgOverall'),
              _SummaryItem(
                  label: Tr.pick('平均年齢', 'Avg age'),
                  value: Tr.pick('$avgAge歳', '$avgAge')),
              _SummaryItem(
                  label: Tr.pick('年俸の合計', 'Salaries'),
                  value: formatMoney(annualFromWeekly(wageBill))),
              _SummaryItem(
                label: Tr.pick('負傷', 'Injured'),
                value: '$injured',
                valueColor: injured > 0 ? Colors.redAccent : null,
              ),
              _SummaryItem(
                label: Tr.pick('要対応', 'Needs attention'),
                value: '$attention',
                valueColor: attention > 0 ? Colors.orange : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: valueColor),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: SemanticColors.subtleText(context))),
      ],
    );
  }
}

/// 出場可能な選手のコンディションと今季成績を1行にまとめたサブ表示。
/// 問題のある値(疲労過多・実戦感覚低下・不満)だけを色で強調する。
class _ConditionLine extends StatelessWidget {
  final Player player;
  final PlayerSeasonStats stats;

  const _ConditionLine({required this.player, required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget cond(String label, int value, bool bad) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            // 日本語は「疲労72」と続けて読めるが、英語は語と数字の間に
            // 空白がないと «Fatigue72» になってしまう。
            Tr.pick('$label$value', '$label $value'),
            style: TextStyle(
              fontSize: 11,
              color:
                  bad ? Colors.redAccent : SemanticColors.subtleText(context),
              fontWeight: bad ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );

    // 英語ではラベルが長く1行に収まらないので折り返せるようにする。
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        cond(Tr.pick('疲労', 'Fatigue'), player.fatigue, player.fatigue >= 75),
        cond(Tr.pick('感覚', 'Sharpness'), player.matchSharpness,
            player.matchSharpness < 40),
        cond(Tr.pick('士気', 'Morale'), player.happiness, player.happiness < 40),
        // Wrap の子に Flexible は使えない (FlexParentData を要求してしまう)。
        // 折り返しは Wrap 側が面倒を見るので、そのまま置く。
        Text(
          Tr.pick(
              '今季${stats.appearances}試合${stats.goals}点${stats.averageRating != null ? '・評点${stats.averageRating!.toStringAsFixed(1)}' : ''}',
              "${Tr.plural(stats.appearances, 'app')}, ${Tr.plural(stats.goals, 'goal')}${stats.averageRating != null ? ', avg ${stats.averageRating!.toStringAsFixed(1)}' : ''}"),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11, color: SemanticColors.subtleText(context)),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

/// 選手の特性・役割・指示を1行にまとめて出す。
///
/// これらは選手詳細を開かないと見えなかった。25人ぶん開いて回らないと
/// 誰がどういう選手か分からず、特性を活かす編成が組みにくい。
/// 設定されているものだけを並べるので、何も付いていない選手では消える。
class _PlayerTagsLine extends StatelessWidget {
  final Player player;
  const _PlayerTagsLine({required this.player});

  @override
  Widget build(BuildContext context) {
    // 記号で装飾しない。同梱フォントに字形の無い記号(▸ など)を使うと
    // 豆腐(□)になり、リリースビルドを見るまで気づけない。
    final parts = <String>[
      // 能力値で発動する特性は、条件に届いていないと効果が無い。
      // 一覧では「(未発動)」だけ添える。詳しい条件は選手詳細に出る。
      if (player.trait != null)
        Tr.pick('特性 ${player.trait!.label}${_traitDormantSuffix(player)}',
            'Trait ${player.trait!.label}${_traitDormantSuffix(player)}'),
      if (player.role != PlayerRole.standard)
        Tr.pick('役割 ${player.role.label}', 'Role ${player.role.label}'),
      if (player.instruction != null)
        Tr.pick('指示 ${player.instruction!.label}',
            'Instruction ${player.instruction!.label}'),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        parts.join(' / '),
        style: TextStyle(
          fontSize: 11,
          color: SemanticColors.subtleText(context),
        ),
      ),
    );
  }
}

/// 能力値で発動する特性が、まだ条件に届いていないときの但し書き。
String _traitDormantSuffix(Player player) {
  final trait = player.trait;
  if (trait == null) return '';
  final gate = MatchEngine.attributeGatedTraits[trait];
  if (gate == null) return '';
  return player.attributeValue(gate.attribute) >= gate.threshold
      ? ''
      : Tr.pick('(未発動)', ' (dormant)');
}
