import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/signing_proposal_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../logic/transfer_window.dart';
import '../logic/transfer_terms_engine.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';
import '../widgets/transfer_table.dart';
import '../widgets/screen_bar.dart';
import '../logic/economy_scale.dart';

enum TransferSortOption { overall, potential, marketValue, age }

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, this.embedded = false});

  /// 下タブの一員として表示するか。true なら戻るボタンを出さない。
  final bool embedded;

  /// フィルタ・検索・並び替えを適用した移籍市場選手リストを返す。UIから切り離してテスト可能にしてある。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    TransferSortOption sort = TransferSortOption.overall,
  }) {
    var players = all;
    if (group != null) {
      players = players.where((p) => p.position.group == group).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      players = players.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else {
      players = [...players];
    }
    switch (sort) {
      case TransferSortOption.overall:
        players.sort((a, b) => b.overall.compareTo(a.overall));
        break;
      case TransferSortOption.potential:
        players.sort((a, b) => b.potential.compareTo(a.potential));
        break;
      case TransferSortOption.marketValue:
        players.sort((a, b) => a.marketValue.compareTo(b.marketValue));
        break;
      case TransferSortOption.age:
        players.sort((a, b) => a.age.compareTo(b.age));
        break;
    }
    return players;
  }

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  /// オーナーが見送った候補。この画面を開いているあいだだけ覚える。
  final Set<String> _passed = {};

  // 「探す」の絞り込み。
  PositionGroup? _searchGroup;
  int? _searchMaxAge;
  TransferSortOption _searchSort = TransferSortOption.overall;
  int _searchLimit = 40;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    // 申し込める他のクラブの選手。この画面の作り直しのたびに1回だけ集める。
    final targets = gameState.transferTargets;

    return Scaffold(
      appBar: screenBar(
        context,
        title: Tr.pick('移籍市場', 'Transfers'),
        leading: widget.embedded ? null : const BackButton(),
        controller: _tabController,
        tabs: [
          Tr.pick('監督の案', 'Proposals'),
          Tr.pick('探す', 'Search'),
          Tr.pick('注目 (${save.watchlistPlayerIds.length})',
              'Watchlist (${save.watchlistPlayerIds.length})'),
          Tr.pick('フリーエージェント (${gameState.freeAgents.length})',
              'Free agents (${gameState.freeAgents.length})'),
        ],
        actions: [
          const QuickAccessMenuButton(),
        ],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProposalTab(context, gameState, save, squadFull, targets),
            _buildSearchTab(context, gameState, squadFull, targets),
            _buildWatchTab(context, gameState, save, squadFull, targets),
            _buildFreeAgentTab(context, gameState, squadFull),
          ],
        ),
      ),
    );
  }

  /// 監督の補強提案。オーナーは市場を探さず、候補を買う/見送るで決める。
  Widget _buildProposalTab(
    BuildContext context,
    GameState gameState,
    SaveGame save,
    bool squadFull,
    List<Player> targets,
  ) {
    final windowOpen = gameState.isTransferWindowOpen;
    final proposals = SigningProposalEngine.propose(
      gameState.userTeam,
      targets,
      budget: save.budget,
      passed: _passed,
    );
    return Column(
      children: [
        _TransferWindowBanner(
          open: windowOpen,
          deadlineDay: gameState.isTransferDeadlineDay,
          label: gameState.transferWindowStatusLabel,
        ),
        if (gameState.isGoalkeeperEmergency)
          _NoticeLine(
            text: Tr.pick(
                '登録中のGKが全員出られないため、窓の外でもGKを1人だけローンで取れます(緊急の特例)。',
                'Every registered goalkeeper is unavailable, so you may take one goalkeeper on loan outside the window (emergency rule).'),
          ),
        _RegistrationCard(windowOpen: windowOpen),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text(Tr.pick('資金 ${formatMoney(save.budget)}', 'Funds ${formatMoney(save.budget)}'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 12),
              Text(
                Tr.pick(
                    'スカッド ${gameState.userTeam.players.length}/$maxSquadSize',
                    'Squad ${gameState.userTeam.players.length}/$maxSquadSize'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (squadFull) ...[
                const SizedBox(width: 8),
                Text(
                  Tr.pick('枠が上限です', 'Squad full'),
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Tr.pick('監督が挙げた補強の候補です。買うか見送るかを決めてください。',
                  'Candidates your manager picked. Sign them or pass.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: proposals.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      Tr.pick('いまは監督から候補がありません。次の節のあとにまた挙がります。',
                          'No candidates right now. Your manager will suggest more after the next matchday.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final pr in proposals)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  PlayerFaceAvatar(
                                      playerId: pr.player.id,
                                      position: pr.player.position),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Tr.pick(
                                              '${pr.player.name}(${pr.player.position.label}・${pr.player.age}歳)',
                                              '${pr.player.name} (${pr.player.position.label}, ${pr.player.age})'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          Tr.pick(
                                              '${gameState.clubNameOf(pr.player.id) ?? '-'}・総合力 ${pr.player.overall}・移籍金 ${formatMoney(pr.player.marketValue)}',
                                              '${gameState.clubNameOf(pr.player.id) ?? '-'} • Overall ${pr.player.overall} • Fee ${formatMoney(pr.player.marketValue)}'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(pr.reason),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _WatchButton(playerId: pr.player.id),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      FeedbackService.tap();
                                      setState(() => _passed.add(pr.player.id));
                                    },
                                    child: Text(Tr.pick('見送る', 'Pass')),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: (windowOpen ||
                                                (gameState
                                                        .isGoalkeeperEmergency &&
                                                    pr.player.position ==
                                                        Position.gk)) &&
                                            !squadFull
                                        ? () => _showAcquireSheet(
                                            context, pr.player)
                                        : null,
                                    child: Text(Tr.pick('買う', 'Sign')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// 探す: 他のクラブの選手を、ポジション・年齢で絞って並べる。
  Widget _buildSearchTab(
    BuildContext context,
    GameState gameState,
    bool squadFull,
    List<Player> targets,
  ) {
    var found = TransferScreen.filterAndSort(
      targets,
      group: _searchGroup,
      sort: _searchSort,
    );
    if (_searchMaxAge != null) {
      found = found.where((p) => p.age <= _searchMaxAge!).toList();
    }
    final shown = found.take(_searchLimit).toList();
    return Column(
      children: [
        _TransferWindowBanner(
          open: gameState.isTransferWindowOpen,
          deadlineDay: gameState.isTransferDeadlineDay,
          label: gameState.transferWindowStatusLabel,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final g in <PositionGroup?>[null, ...PositionGroup.values])
                ChoiceChip(
                  label: Text(_groupLabel(g)),
                  selected: _searchGroup == g,
                  onSelected: (_) => setState(() => _searchGroup = g),
                ),
              DropdownButton<int?>(
                value: _searchMaxAge,
                items: [
                  for (final a in const <int?>[null, 21, 25, 29])
                    DropdownMenuItem(
                      value: a,
                      child: Text(a == null
                          ? Tr.pick('年齢を問わない', 'Any age')
                          : Tr.pick('$a歳以下', '$a or younger')),
                    ),
                ],
                onChanged: (v) => setState(() => _searchMaxAge = v),
              ),
              DropdownButton<TransferSortOption>(
                value: _searchSort,
                items: [
                  for (final o in TransferSortOption.values)
                    DropdownMenuItem(value: o, child: Text(_sortLabel(o))),
                ],
                onChanged: (v) =>
                    setState(() => _searchSort = v ?? _searchSort),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Tr.pick(
                  '自国の全部と、他の4か国の1部のクラブの選手から探せます。該当 ${found.length}人(上から${shown.length}人を表示)。',
                  'Search players at every club at home and in the top flights of the other four countries. ${found.length} match (showing the top ${shown.length}).'),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final p in shown)
                _targetTile(context, gameState, p, squadFull),
              if (found.length > shown.length)
                TextButton(
                  onPressed: () => setState(() => _searchLimit += 40),
                  child: Text(Tr.pick('もっと見る', 'Show more')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 注目: 注目リストに入れた選手。
  Widget _buildWatchTab(
    BuildContext context,
    GameState gameState,
    SaveGame save,
    bool squadFull,
    List<Player> targets,
  ) {
    final byId = {for (final p in targets) p.id: p};
    final watched = [
      for (final id in save.watchlistPlayerIds)
        if (byId[id] != null) byId[id]!,
    ];
    final unavailable = save.watchlistPlayerIds.length - watched.length;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            Tr.pick(
                '星を付けた選手です。監督の案や「探す」で星を押すと入ります。',
                'Players you starred. Tap the star in Proposals or Search to add one.'),
            style: TextStyle(
                fontSize: 12, color: SemanticColors.subtleText(context)),
          ),
        ),
        if (unavailable > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              Tr.pick(
                  'ほかに$unavailable人は、今は申し込めません(自クラブの選手・ローン中・他のクラブと仮契約済み・引退など)。',
                  '$unavailable more cannot be approached right now (your own players, on loan, pre-contracted elsewhere, retired and so on).'),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ),
        if (watched.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(Tr.pick('注目している選手はいません',
                  'You are not watching anyone')),
            ),
          ),
        for (final p in watched) _targetTile(context, gameState, p, squadFull),
      ],
    );
  }

  /// 他のクラブの選手の1行(所属・総合力・市場価値・注目・獲得)。
  Widget _targetTile(
    BuildContext context,
    GameState gameState,
    Player p,
    bool squadFull,
  ) {
    final canSign = (gameState.isTransferWindowOpen ||
            (gameState.isGoalkeeperEmergency && p.position == Position.gk)) &&
        !squadFull;
    return Card(
      child: ListTile(
        leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
        title: Text(Tr.pick('${p.name}(${p.position.label}・${p.age}歳)',
            '${p.name} (${p.position.label}, ${p.age})')),
        subtitle: Text(Tr.pick(
            '${gameState.clubNameOf(p.id) ?? '-'}・総合力 ${p.overall}・市場価値 ${formatMoney(p.marketValue)}',
            '${gameState.clubNameOf(p.id) ?? '-'} • Overall ${p.overall} • Value ${formatMoney(p.marketValue)}')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WatchButton(playerId: p.id),
            TextButton(
              onPressed: canSign ? () => _showAcquireSheet(context, p) : null,
              child: Text(Tr.pick('獲得', 'Sign')),
            ),
          ],
        ),
      ),
    );
  }

  static String _groupLabel(PositionGroup? g) => switch (g) {
        null => Tr.pick('全員', 'All'),
        PositionGroup.gk => 'GK',
        PositionGroup.def => Tr.pick('守備', 'DEF'),
        PositionGroup.mid => Tr.pick('中盤', 'MID'),
        PositionGroup.att => Tr.pick('攻撃', 'ATT'),
      };

  static String _sortLabel(TransferSortOption o) => switch (o) {
        TransferSortOption.overall => Tr.pick('総合力が高い順', 'Best overall'),
        TransferSortOption.potential => Tr.pick('伸びしろの順', 'Best potential'),
        TransferSortOption.marketValue => Tr.pick('安い順', 'Cheapest'),
        TransferSortOption.age => Tr.pick('若い順', 'Youngest'),
      };

  Widget _buildFreeAgentTab(
    BuildContext context,
    GameState gameState,
    bool squadFull,
  ) {
    final freeAgents = [...gameState.freeAgents]
      ..sort((a, b) => b.overall.compareTo(a.overall));
    final windowOpen = gameState.isTransferWindowOpen;

    return Column(
      children: [
        _TransferWindowBanner(
          open: windowOpen,
          deadlineDay: gameState.isTransferDeadlineDay,
          label: gameState.transferWindowStatusLabel,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Tr.pick('移籍金なし・年俸のみで獲得できる選手です。所属が無いので、移籍の窓の外でも取れます。',
                  'These players cost no fee, only wages. They have no club, so you can sign them outside the window too.'),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ),
        ),
        if (squadFull)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              Tr.pick('スカッドが上限のため、獲得するには誰かを放出してください。',
                  'Your squad is full. Release someone before you sign anyone.'),
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        Expanded(
          child: freeAgents.isEmpty
              ? Center(
                  child: Text(Tr.pick('現在フリーエージェントはいません',
                      'There are no free agents right now')))
              : TransferTable(
                  players: freeAgents,
                  market: false,
                  budget: 0,
                  canSign: !squadFull,
                  onSign: (p) => _signFreeAgent(context, p),
                ),
        ),
      ],
    );
  }

  Future<void> _signFreeAgent(BuildContext context, Player player) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.signFreeAgent(player.id);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      final reason = gameState.lastSigningBlockReason;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? Tr.pick('${player.name}と契約しました', 'You signed ${player.name}')
                : (reason ??
                    Tr.pick('契約できませんでした', 'The signing did not go through')),
          ),
          duration: Duration(seconds: reason != null && !ok ? 6 : 4),
        ),
      );
    }
  }

  /// 移籍金の値切り交渉ダイアログ。提示割合をスライダーで選び、成立見込みを
  /// 事前に示した上でオファーを出す。断られるとその週は再交渉できない。
  Future<void> _showNegotiationDialog(
    BuildContext context,
    Player player,
  ) async {
    final gameState = context.read<GameState>();
    final total = player.marketValue;
    double ratio = 0.85;
    final submitted = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final offer = (total * ratio).round();
          final chance = gameState.transferOfferAcceptChance(total, offer,
              player: player);
          return AlertDialog(
            title: Text(Tr.pick(
                '${player.name}への移籍金オファー', 'Your bid for ${player.name}')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.pick('市場価値: ${formatMoney(total)}', 'Value: ${formatMoney(total)}')),
                Text(Tr.pick('提示額: ${formatMoney(offer)}(${(ratio * 100).round()}%)',
                    'Your bid: ${formatMoney(offer)} (${(ratio * 100).round()}%)')),
                Slider(
                  value: ratio,
                  min: 0.6,
                  max: 1.0,
                  divisions: 8,
                  label: '${(ratio * 100).round()}%',
                  onChanged: (v) => setState(() => ratio = v),
                ),
                Text(Tr.pick('成立見込み: ${(chance * 100).round()}%',
                    'Chance of acceptance: ${(chance * 100).round()}%')),
                Text(
                  Tr.pick('断られるとこの週は再交渉できない(満額での獲得は可能)。',
                      'If they turn you down you cannot bid again this week, though you can still pay full price.'),
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.subtleText(context)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Tr.pick('やめる', 'Never mind')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, offer),
                child: Text(Tr.pick('オファーを出す', 'Make the bid')),
              ),
            ],
          );
        },
      ),
    );
    if (submitted == null || !context.mounted) return;
    final result = await gameState.makeTransferOffer(player.id, submitted);
    if (!context.mounted) return;
    if (result.accepted) {
      FeedbackService.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(Tr.pick('${player.name}を${formatMoney(submitted)}で獲得しました!',
                'You signed ${player.name} for ${formatMoney(submitted)}!'))),
      );
    } else if (result.attempted) {
      FeedbackService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(Tr.pick('オファーは断られた。この週は再交渉できない。',
                'The bid was rejected. You cannot go back this week.'))),
      );
    } else {
      FeedbackService.error();
      final reason = gameState.lastSigningBlockReason;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason ??
              Tr.pick('交渉できませんでした(資金・スカッド枠・ウィンドウを確認)',
                  'The talks could not open. Check your funds, squad space and the transfer window')),
          duration: Duration(seconds: reason != null ? 6 : 4),
        ),
      );
    }
  }

  void _showAcquireSheet(BuildContext context, Player player) {
    final gameState = context.read<GameState>();
    final save = gameState.save!;
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    final agentFee = TransferTermsEngine.agentFee(total);
    final loanFee = (total * GameState.loanFeeRatioPercent / 100).round();
    final buyOptionFee = (total * GameState.loanBuyOptionRatio).round();
    // 窓の外で開けるのは GK の緊急の特例だけ。そのときは期限付き(ローン)のみ。
    final permanentAllowed = gameState.isTransferWindowOpen;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Tr.pick('${player.name}を獲得', 'Sign ${player.name}'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.payments),
                title: Text(Tr.pick('一括で獲得', 'Pay it all now')),
                subtitle:
                    Text(Tr.pick('${formatMoney(total)}を即座に支払う(別に代理人手数料${formatMoney(agentFee)})', 'Pay ${formatMoney(total)} immediately (plus ${formatMoney(agentFee)} agent fee)')),
                enabled: permanentAllowed && save.budget >= total + agentFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(
                    context,
                    () => gameState.buyPlayer(player.id),
                    player.name,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.handshake),
                title: Text(Tr.pick('値切り交渉で獲得', 'Haggle over the fee')),
                subtitle: Text(
                  gameState.transferOffersRejectedThisWeek.contains(player.id)
                      ? Tr.pick('今週は既に断られている(来週また交渉できる)',
                          'They already said no this week; you can try again next week')
                      : Tr.pick('市場価値より安い移籍金を提示する(安いほど断られやすい)',
                          'Bid below his value. The lower you go, the more likely they refuse'),
                ),
                enabled: permanentAllowed &&
                    !gameState.transferOffersRejectedThisWeek
                        .contains(player.id),
                onTap: () {
                  Navigator.pop(ctx);
                  _showNegotiationDialog(context, player);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week),
                title: Text(Tr.pick('分割払いで獲得', 'Pay in instalments')),
                subtitle: Text(Tr.pick('頭金${formatMoney(downPayment)} + 残額を4週で均等払い',
                    '${formatMoney(downPayment)} down, the rest in equal payments over 4 weeks')),
                enabled: permanentAllowed && save.budget >= downPayment + agentFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(
                    context,
                    () => gameState.buyPlayerOnInstallments(player.id),
                    player.name,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(Tr.pick('ローンで獲得', 'Take him on loan')),
                subtitle: Text(
                  Tr.pick(
                      '契約金${formatMoney(loanFee)}・給与の6割を負担・期間は半年(冬の窓まで)か1年(シーズン末まで)',
                      '${formatMoney(loanFee)} fee, 60% of his wages, for half a season (to the winter window) or the full season'),
                ),
                enabled: save.budget >= loanFee,
                onTap: () async {
                  Navigator.pop(ctx);
                  final length = await _chooseLoanLength(context);
                  if (length == null || !context.mounted) return;
                  _acquire(
                    context,
                    () => gameState.signLoanPlayer(player.id, length: length),
                    player.name,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.request_quote),
                title: Text(
                    Tr.pick('買取オプション付きローンで獲得', 'Loan with an option to buy')),
                subtitle: Text(
                  Tr.pick(
                      '契約金${formatMoney(loanFee)}・給与の6割を負担・ローン期間中いつでも${formatMoney(buyOptionFee)}で完全移籍化可能',
                      '${formatMoney(loanFee)} fee, 60% of his wages, and you can make it permanent for ${formatMoney(buyOptionFee)} at any point'),
                ),
                enabled: save.budget >= loanFee,
                onTap: () async {
                  Navigator.pop(ctx);
                  final length = await _chooseLoanLength(context);
                  if (length == null || !context.mounted) return;
                  _acquire(
                    context,
                    () => gameState.signLoanPlayer(
                      player.id,
                      withBuyOption: true,
                      length: length,
                    ),
                    player.name,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ローンの長さを選ぶ。半年は冬の窓が開く日まで、1年はシーズン末まで。
  /// 冬の窓より後(半年が組めない時期)は1年だけ。
  Future<LoanLength?> _chooseLoanLength(BuildContext context) {
    final gameState = context.read<GameState>();
    final theme = gameState.currentLeagueTheme;
    final today = gameState.today;
    final halfOk = TransferWindowCalendar.halfLoanAvailable(today, theme);
    final halfEnd = TransferWindowCalendar.formatMonthDay(
        TransferWindowCalendar.loanEndDate(today, theme, LoanLength.half));
    final fullEnd = TransferWindowCalendar.formatMonthDay(
        TransferWindowCalendar.loanEndDate(today, theme, LoanLength.full));
    return showDialog<LoanLength>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(Tr.pick('ローンの期間', 'Loan length')),
        children: [
          if (halfOk)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, LoanLength.half),
              child: Text(Tr.pick('半年(冬の窓が開く$halfEndまで)',
                  'Half a season (until the winter window opens, $halfEnd)')),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, LoanLength.full),
            child: Text(Tr.pick('1年(シーズン末の$fullEndまで)',
                'Full season (until $fullEnd)')),
          ),
        ],
      ),
    );
  }

  Future<void> _acquire(
    BuildContext context,
    Future<bool> Function() action,
    String name,
  ) async {
    final gameState = context.read<GameState>();
    final ok = await action();
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      final reason = gameState.lastSigningBlockReason;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? Tr.pick('$nameを獲得しました', 'You signed $name')
              : (reason ??
                  Tr.pick('獲得できませんでした', 'The signing did not go through'))),
          duration: Duration(seconds: reason != null && !ok ? 6 : 4),
        ),
      );
    }
  }
}

/// 移籍の窓の開閉を示すバナー。閉じている間は選手の獲得・放出ができない
/// (自由契約の選手はいつでも取れる)。締切日は札を付けて目立たせる。
class _TransferWindowBanner extends StatelessWidget {
  final bool open;
  final bool deadlineDay;
  final String label;
  const _TransferWindowBanner({
    required this.open,
    required this.label,
    this.deadlineDay = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = deadlineDay
        ? SemanticColors.negative(context)
        : open
            ? Colors.green.shade700
            : Colors.grey.shade700;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(open ? Icons.lock_open : Icons.lock, size: 16, color: color),
          const SizedBox(width: 8),
          if (deadlineDay) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                Tr.pick('締切日', 'DEADLINE DAY'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1行の注意書き。
class _NoticeLine extends StatelessWidget {
  final String text;
  const _NoticeLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.orange, fontSize: 12),
      ),
    );
  }
}

/// 締切で出す登録の名簿。22歳以上が25人(国外で育った選手は17人)を
/// 超えているときだけ出る。外れる予定の選手を見せ、入れ替えられるようにする。
class _RegistrationCard extends StatelessWidget {
  final bool windowOpen;
  const _RegistrationCard({required this.windowOpen});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final unregistered = team.players.where((p) => p.notRegistered).toList();
    if (!windowOpen) {
      if (unregistered.isEmpty) return const SizedBox.shrink();
      return _NoticeLine(
        text: Tr.pick(
            '登録外(次の窓まで公式戦に出られない): ${unregistered.map((p) => p.name).join('、')}',
            'Not registered (ineligible until the next window): ${unregistered.map((p) => p.name).join(', ')}'),
      );
    }
    if (!SquadRegistration.isOverLimit(team)) return const SizedBox.shrink();
    final planned = gameState.plannedRegistrationExclusions;
    final deadline = gameState.transferDeadline;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick('締切の登録名簿', 'Squad list at the deadline'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '22歳以上は${SquadRegistration.seniorLimit}人まで(国外で育った選手は${SquadRegistration.nonHomegrownLimit}人まで)です。'
                      '${deadline == null ? '締切' : TransferWindowCalendar.formatMonthDay(deadline)}に次の選手が名簿から外れ、次の窓まで公式戦に出られません: '
                      '${planned.map((p) => p.name).join('、')}',
                  'Only ${SquadRegistration.seniorLimit} players aged 22 or over may be registered (${SquadRegistration.nonHomegrownLimit} trained abroad). '
                      'At the deadline${deadline == null ? '' : ' (${TransferWindowCalendar.formatMonthDay(deadline)})'} these players drop off the list and cannot play until the next window: '
                      '${planned.map((p) => p.name).join(', ')}'),
              style: const TextStyle(fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _editRoster(context),
                child: Text(Tr.pick('名簿を選ぶ', 'Choose the list')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editRoster(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Consumer<GameState>(
        builder: (ctx, gameState, _) {
          final seniors = gameState.userTeam.players
              .where(SquadRegistration.isSenior)
              .toList()
            ..sort((a, b) => b.overall.compareTo(a.overall));
          final planned =
              gameState.plannedRegistrationExclusions.map((p) => p.id).toSet();
          return AlertDialog(
            title: Text(Tr.pick('締切の登録名簿', 'Squad list at the deadline')),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    Tr.pick('外す選手に印を付けてください。足りない分は総合力の低い選手から自動で外します。',
                        'Tick the players to leave out. If that is not enough, the lowest rated are left out for you.'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  for (final p in seniors)
                    CheckboxListTile(
                      dense: true,
                      value: p.leaveOffRegistration,
                      onChanged: (v) =>
                          gameState.setLeaveOffRegistration(p.id, v ?? false),
                      title: Text(Tr.pick(
                          '${p.name}(${p.position.label}・${p.age}歳・総合${p.overall})',
                          '${p.name} (${p.position.label}, ${p.age}, overall ${p.overall})')),
                      subtitle: Text(
                        [
                          if (p.isHomegrown) Tr.pick('国内育成', 'Homegrown'),
                          if (planned.contains(p.id))
                            Tr.pick('締切で外れる', 'Left out at the deadline'),
                        ].join(' / '),
                        style: TextStyle(
                            fontSize: 11,
                            color: planned.contains(p.id)
                                ? SemanticColors.negative(ctx)
                                : null),
                      ),
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
          );
        },
      ),
    );
  }
}

/// 注目リストに入れる・外す星。
class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final watched = game.isWatched(playerId);
    return IconButton(
      icon: Icon(watched ? Icons.star : Icons.star_border,
          color: watched ? Colors.amber : null),
      tooltip: watched
          ? Tr.pick('注目から外す', 'Stop watching')
          : Tr.pick('注目に入れる', 'Watch this player'),
      onPressed: () {
        FeedbackService.tap();
        game.toggleWatched(playerId);
      },
    );
  }
}
