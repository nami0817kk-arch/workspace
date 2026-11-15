import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/signing_proposal_engine.dart';
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
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    return Scaffold(
      appBar: screenBar(
        context,
        title: Tr.pick('移籍市場', 'Transfers'),
        leading: widget.embedded ? null : const BackButton(),
        controller: _tabController,
        tabs: [
          Tr.pick('市場', 'Market'),
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
            _buildProposalTab(context, gameState, save, squadFull),
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
  ) {
    final windowOpen = gameState.isTransferWindowOpen;
    final proposals = SigningProposalEngine.propose(
      gameState.userTeam,
      gameState.transferMarket,
      budget: save.budget,
      passed: _passed,
    );
    return Column(
      children: [
        _TransferWindowBanner(
          open: windowOpen,
          label: gameState.transferWindowStatusLabel,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text(Tr.pick('資金 ${save.budget}万円', 'Funds ${save.budget}'),
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
                                              '総合力 ${pr.player.overall}・移籍金 ${pr.player.marketValue}万円',
                                              'Overall ${pr.player.overall} • Fee ${pr.player.marketValue}'),
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
                                  TextButton(
                                    onPressed: () {
                                      FeedbackService.tap();
                                      setState(() => _passed.add(pr.player.id));
                                    },
                                    child: Text(Tr.pick('見送る', 'Pass')),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: windowOpen && !squadFull
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
          label: gameState.transferWindowStatusLabel,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Tr.pick('移籍金なし・週俸のみで獲得できる選手です。',
                  'These players cost no fee, only wages.'),
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
                  canSign: !squadFull && windowOpen,
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
          final chance = gameState.transferOfferAcceptChance(total, offer);
          return AlertDialog(
            title: Text(Tr.pick(
                '${player.name}への移籍金オファー', 'Your bid for ${player.name}')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.pick('市場価値: $total万円', 'Value: $total')),
                Text(Tr.pick('提示額: $offer万円(${(ratio * 100).round()}%)',
                    'Your bid: $offer (${(ratio * 100).round()}%)')),
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
            content: Text(Tr.pick('${player.name}を$submitted万円で獲得しました!',
                'You signed ${player.name} for $submitted!'))),
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
                    Text(Tr.pick('$total万円を即座に支払う(別に代理人手数料$agentFee万円)', 'Pay $total immediately (plus $agentFee agent fee)')),
                enabled: save.budget >= total + agentFee,
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
                enabled: !gameState.transferOffersRejectedThisWeek
                    .contains(player.id),
                onTap: () {
                  Navigator.pop(ctx);
                  _showNegotiationDialog(context, player);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week),
                title: Text(Tr.pick('分割払いで獲得', 'Pay in instalments')),
                subtitle: Text(Tr.pick('頭金$downPayment万円 + 残額を4週で均等払い',
                    '$downPayment down, the rest in equal payments over 4 weeks')),
                enabled: save.budget >= downPayment + agentFee,
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
                      '契約金$loanFee万円・週俸6割・${GameState.loanDurationWeeks}週で契約終了',
                      '$loanFee fee, 60% of his wages, ending after ${Tr.plural(GameState.loanDurationWeeks, 'week')}'),
                ),
                enabled: save.budget >= loanFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(
                    context,
                    () => gameState.signLoanPlayer(player.id),
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
                      '契約金$loanFee万円・週俸6割・ローン期間中いつでも$buyOptionFee万円で完全移籍化可能',
                      '$loanFee fee, 60% of his wages, and you can make it permanent for $buyOptionFee at any point'),
                ),
                enabled: save.budget >= loanFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(
                    context,
                    () => gameState.signLoanPlayer(
                      player.id,
                      withBuyOption: true,
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

/// 移籍ウィンドウの開閉状態を示すバナー。閉じている間は選手の獲得・放出ができない。
class _TransferWindowBanner extends StatelessWidget {
  final bool open;
  final String label;
  const _TransferWindowBanner({required this.open, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green.shade700 : Colors.grey.shade700;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(open ? Icons.lock_open : Icons.lock, size: 16, color: color),
          const SizedBox(width: 8),
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
