import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scout_knowledge.dart';
import '../logic/signing_proposal_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../logic/transfer_window.dart';
import '../logic/transfer_terms_engine.dart';
import '../logic/transfer_talk_engine.dart';
import '../logic/player_terms_engine.dart';
import '../logic/relations_engine.dart';
import '../logic/contract_engine.dart';
import '../models/transfer_talk.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
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
    _tabController = TabController(length: 6, vsync: this);
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
    // 同じ部の選手(最初から少し見えている)。見え方を何度も測るので1回だけ集める。
    final same = gameState.sameLeaguePlayerIds();

    return Scaffold(
      appBar: screenBar(
        context,
        title: Tr.pick('移籍市場', 'Transfers'),
        leading: widget.embedded ? null : const BackButton(),
        controller: _tabController,
        tabs: [
          gameState.currentSd != null
              ? Tr.pick('SDの案', 'SD shortlist')
              : Tr.pick('監督の案', 'Proposals'),
          Tr.pick('探す', 'Search'),
          Tr.pick('交渉 (${gameState.transferTalks.length})',
              'Talks (${gameState.transferTalks.length})'),
          Tr.pick('注目 (${save.watchlistPlayerIds.length})',
              'Watchlist (${save.watchlistPlayerIds.length})'),
          Tr.pick('フリーエージェント (${gameState.freeAgents.length})',
              'Free agents (${gameState.freeAgents.length})'),
          Tr.pick('スカウト', 'Scouting'),
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
            _buildProposalTab(
                context, gameState, save, squadFull, targets, same),
            _buildSearchTab(context, gameState, squadFull, targets, same),
            _buildTalksTab(context, gameState),
            _buildWatchTab(context, gameState, save, squadFull, targets, same),
            _buildFreeAgentTab(context, gameState, squadFull),
            _buildScoutTab(context, gameState, save),
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
    Set<String> same,
  ) {
    final windowOpen = gameState.isTransferWindowOpen;
    // 監督が挙げるのは、ある程度見えている選手だけ。
    final known = [
      for (final p in targets)
        if (gameState.knowledgeOf(p, sameLeagueIds: same) >=
            ScoutKnowledge.proposalMinimum)
          p,
    ];
    final proposals = SigningProposalEngine.propose(
      gameState.userTeam,
      known,
      budget: save.budget,
      passed: _passed,
    );
    // 理由が同じ候補はまとめ、理由は見出しとして1回だけ出す(2026-11-21)。
    final groups = <String, List<SigningProposal>>{};
    for (final pr in proposals) {
      groups.putIfAbsent(pr.reason, () => []).add(pr);
    }
    final count = gameState.userTeam.players.length;
    return Column(
      children: [
        _TransferWindowBanner(
          open: windowOpen,
          deadlineDay: gameState.isTransferDeadlineDay,
          label: gameState.transferWindowStatusLabel,
          // 資金は上の段に出ているので、ここはスカッドの人数だけ。
          trailing: squadFull
              ? Tr.pick('スカッド $count/$maxSquadSize(上限)',
                  'Squad $count/$maxSquadSize (full)')
              : Tr.pick('スカッド $count/$maxSquadSize',
                  'Squad $count/$maxSquadSize'),
        ),
        if (gameState.isGoalkeeperEmergency)
          _NoticeLine(
            text: Tr.pick('登録中のGKが全員出られないため、窓の外でもGKを1人だけローンで取れます(緊急の特例)。',
                'Every registered goalkeeper is unavailable, so you may take one goalkeeper on loan outside the window (emergency rule).'),
          ),
        _RegistrationCard(windowOpen: windowOpen),
        if (gameState.currentSd != null) const _SdBriefCard(),
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
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  children: [
                    for (final g in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                        child: Text(
                          g.key,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SemanticColors.subtleText(context)),
                        ),
                      ),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, pr) in g.value.indexed) ...[
                              if (i > 0) const Divider(height: 1),
                              _proposalRow(context, gameState, pr.player,
                                  windowOpen, squadFull, same),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// 監督の案の1人分の行。名前・位置・年齢・所属と、総合力・移籍金を
  /// 列にして並べ、注目・見送る・買うも同じ行に置く(2026-11-21)。
  Widget _proposalRow(
    BuildContext context,
    GameState gameState,
    Player p,
    bool windowOpen,
    bool squadFull,
    Set<String> same,
  ) {
    final ovr =
        ScoutKnowledge.label(gameState.overallEstimate(p, sameLeagueIds: same));
    final fee = formatMoney(p.marketValue);
    final affordable = gameState.save!.budget >= p.marketValue;
    final club = gameState.clubNameOf(p.id) ?? '-';
    final canSign = (windowOpen ||
            (gameState.isGoalkeeperEmergency && p.position == Position.gk)) &&
        !squadFull;
    final subtle = SemanticColors.subtleText(context);
    Widget value(String caption, String v, {Color? color}) => SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(caption, style: TextStyle(fontSize: 10, color: subtle)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 520;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            PlayerFaceAvatar(playerId: p.id, position: p.position, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    wide
                        ? Tr.pick('${p.position.label}・${p.age}歳・$club',
                            '${p.position.label} • ${p.age} • $club')
                        : Tr.pick(
                            '${p.position.label}・${p.age}歳・総合力 $ovr・移籍金 $fee',
                            '${p.position.label} • ${p.age} • OVR $ovr • Fee $fee'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              value(Tr.pick('総合力', 'Overall'), ovr),
              value(Tr.pick('移籍金', 'Fee'), fee,
                  color: affordable ? null : Theme.of(context).colorScheme.error),
            ],
            _WatchButton(playerId: p.id),
            TextButton(
              onPressed: () {
                FeedbackService.tap();
                setState(() => _passed.add(p.id));
              },
              child: Text(Tr.pick('見送る', 'Pass')),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: canSign ? () => _showAcquireSheet(context, p) : null,
              child: Text(Tr.pick('買う', 'Sign')),
            ),
          ],
        ),
      );
    });
  }

  /// 他のクラブの選手を表で並べる(探す・注目)。数字を列にそろえて、
  /// 選手どうしを比べやすくする(2026-11-21)。
  Widget _targetTable(
    BuildContext context,
    GameState gameState,
    List<Player> players,
    bool squadFull,
    Set<String> same, {
    Widget? footer,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final budget = gameState.save!.budget;
    final canSignNow = (gameState.isTransferWindowOpen) && !squadFull;
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    const small = TextStyle(fontSize: 12);
    Widget cell(String s, double w, {TextStyle? style, TextStyle? base}) =>
        SizedBox(
          width: w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s, textAlign: TextAlign.center, style: style ?? base),
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 560;
      final header = Container(
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(Tr.pick('名前', 'Name'), style: head)),
            if (wide) cell(Tr.pick('所属', 'Club'), 96, base: head),
            cell(Tr.pick('年', 'Age'), 28, base: head),
            cell(Tr.pick('位置', 'Pos'), 40, base: head),
            cell(Tr.pick('総合力', 'OVR'), 60, base: head),
            cell(Tr.pick('伸びしろ', 'POT'), 60, base: head),
            cell(Tr.pick('市場価値', 'Value'), 56, base: head),
            if (wide) cell(Tr.pick('見え', 'Seen'), 40, base: head),
            const SizedBox(width: 92),
          ],
        ),
      );
      Widget row(int i) {
        final p = players[i];
        final k = gameState.knowledgeOf(p, sameLeagueIds: same);
        final canSign = canSignNow ||
            (gameState.isGoalkeeperEmergency &&
                p.position == Position.gk &&
                !squadFull);
        return Container(
          color: i.isOdd ? scheme.surfaceContainerLow : null,
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: small.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (wide)
                cell(gameState.clubNameOf(p.id) ?? '-', 96, base: small),
              cell('${p.age}', 28, base: small),
              cell(p.position.label, 40, base: small),
              cell(
                  ScoutKnowledge.label(
                      gameState.overallEstimate(p, sameLeagueIds: same)),
                  60,
                  base: small.copyWith(fontWeight: FontWeight.w700)),
              cell(
                  ScoutKnowledge.label(
                      gameState.potentialEstimate(p, sameLeagueIds: same)),
                  60,
                  base: small),
              cell(formatMoney(p.marketValue), 56,
                  base: small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: budget >= p.marketValue ? null : scheme.error)),
              if (wide)
                cell('$k%', 40,
                    base: small.copyWith(
                        color: SemanticColors.subtleText(context))),
              SizedBox(width: 40, child: _WatchButton(playerId: p.id)),
              SizedBox(
                width: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(52, 40)),
                  onPressed:
                      canSign ? () => _showAcquireSheet(context, p) : null,
                  child: Text(Tr.pick('獲得', 'Sign'), style: small),
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          header,
          Expanded(
            child: ListView.builder(
              itemCount: players.length + (footer == null ? 0 : 1),
              itemBuilder: (context, i) => i < players.length
                  ? SizedBox(height: 40, child: row(i))
                  : footer!,
            ),
          ),
        ],
      );
    });
  }

  /// 探す: 他のクラブの選手を、ポジション・年齢で絞って並べる。
  Widget _buildSearchTab(
    BuildContext context,
    GameState gameState,
    bool squadFull,
    List<Player> targets,
    Set<String> same,
  ) {
    // 総合力・伸びしろは本当の値ではなく、見立ての真ん中で並べる(見えて
    // いない選手は後ろ)。
    final byEstimate = _searchSort == TransferSortOption.overall ||
        _searchSort == TransferSortOption.potential;
    var found = TransferScreen.filterAndSort(
      targets,
      group: _searchGroup,
      sort: byEstimate ? TransferSortOption.marketValue : _searchSort,
    );
    if (_searchMaxAge != null) {
      found = found.where((p) => p.age <= _searchMaxAge!).toList();
    }
    if (byEstimate) {
      int key(Player p) =>
          ScoutKnowledge.center(_searchSort == TransferSortOption.overall
              ? gameState.overallEstimate(p, sameLeagueIds: same)
              : gameState.potentialEstimate(p, sameLeagueIds: same));
      final keys = {for (final p in found) p.id: key(p)};
      found.sort((a, b) => keys[b.id]!.compareTo(keys[a.id]!));
    }
    final shown = found.take(_searchLimit).toList();
    return Column(
      children: [
        _TransferWindowBanner(
          open: gameState.isTransferWindowOpen,
          deadlineDay: gameState.isTransferDeadlineDay,
          label: gameState.transferWindowStatusLabel,
        ),
        // 絞り込みは1段に。説明文は「?」の中へ(2026-11-21)。
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (final g
                          in <PositionGroup?>[null, ...PositionGroup.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text(_groupLabel(g)),
                            selected: _searchGroup == g,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                setState(() => _searchGroup = g),
                          ),
                        ),
                      const SizedBox(width: 8),
                      DropdownButton<int?>(
                        value: _searchMaxAge,
                        underline: const SizedBox.shrink(),
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
                      const SizedBox(width: 12),
                      DropdownButton<TransferSortOption>(
                        value: _searchSort,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final o in TransferSortOption.values)
                            DropdownMenuItem(
                                value: o, child: Text(_sortLabel(o))),
                        ],
                        onChanged: (v) =>
                            setState(() => _searchSort = v ?? _searchSort),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                Tr.pick('該当${found.length}人', '${found.length} found'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
              _HelpButton(
                title: Tr.pick('探せる選手', 'Who you can search'),
                text: Tr.pick(
                    '自国の全部と、他の4か国の1部のクラブの選手から探せます。上から${shown.length}人を表示しています(下の「もっと見る」で増えます)。\n\n総合力と伸びしろは見立ての幅です。「見え」はスカウトがどれだけ見えているかで、高いほど幅が狭くなります。移籍金が資金より高い選手は赤で出ます。',
                    'You can search every club at home and the top flights of the other four countries. Showing the top ${shown.length} ("Show more" at the bottom adds more).\n\nOverall and potential are estimated ranges. "Seen" is how well your scouts know the player; the higher it is, the narrower the range. Values above your funds are shown in red.'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _targetTable(
            context,
            gameState,
            shown,
            squadFull,
            same,
            footer: found.length > shown.length
                ? TextButton(
                    onPressed: () => setState(() => _searchLimit += 40),
                    child: Text(Tr.pick('もっと見る', 'Show more')),
                  )
                : null,
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
    Set<String> same,
  ) {
    final byId = {for (final p in targets) p.id: p};
    final watched = [
      for (final id in save.watchlistPlayerIds)
        if (byId[id] != null) byId[id]!,
    ];
    final unavailable = save.watchlistPlayerIds.length - watched.length;
    if (watched.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Tr.pick('注目している選手はいません。監督の案や「探す」で星を押すと入ります。',
                'You are not watching anyone. Tap the star in Proposals or Search to add one.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (unavailable > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Text(
              Tr.pick(
                  'ほかに$unavailable人は、今は申し込めません(自クラブの選手・ローン中・他のクラブと仮契約済み・引退など)。',
                  '$unavailable more cannot be approached right now (your own players, on loan, pre-contracted elsewhere, retired and so on).'),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ),
        Expanded(
            child:
                _targetTable(context, gameState, watched, squadFull, same)),
      ],
    );
  }

  /// スカウト: 地域(国と部)にスカウトを送る。
  Widget _buildScoutTab(
    BuildContext context,
    GameState gameState,
    SaveGame save,
  ) {
    final regions = gameState.scoutRegions;
    final used = save.scoutRegionKeys.length;
    final slots = gameState.scoutSlots;
    final cost = gameState.scoutTripCostPerWeek;
    final help = Tr.pick(
              '送った地域の選手は、毎週${gameState.scoutWeeklyGain}%ずつ見えてきます(出張費は1か所 毎週${formatMoney(cost)})。見えているほど、総合力と伸びしろの幅が狭くなります。同じ部の選手は試合で見ているので最初から${ScoutKnowledge.sameLeagueBase}%、注目リストの選手はどこにいても毎週${ScoutKnowledge.watchWeeklyGain}%ずつ見えてきます。送れる場所の数と見えてくる速さは、スカウトの見極めの力で決まります。',
              'Players in the regions you cover become ${gameState.scoutWeeklyGain}% clearer each week (travel costs ${formatMoney(cost)} a week per region). The clearer they are, the narrower the overall and potential ranges. Players in your own division start at ${ScoutKnowledge.sameLeagueBase}% because you see them in matches, and watchlisted players anywhere gain ${ScoutKnowledge.watchWeeklyGain}% a week. Your scout\'s judging decides how many regions you can cover and how fast.');
    Widget region(({String key, String label, List<Team> teams}) r) => Card(
          margin: const EdgeInsets.all(3),
          child: SwitchListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(Tr.pick(
                '平均 ${gameState.regionKnowledgePercent(r.key)}% 見えている',
                '${gameState.regionKnowledgePercent(r.key)}% scouted on average')),
            value: gameState.isScoutRegionActive(r.key),
            onChanged: gameState.isScoutRegionActive(r.key) || used < slots
                ? (_) {
                    FeedbackService.tap();
                    gameState.toggleScoutRegion(r.key);
                  }
                : null,
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      // 横画面では地域を2列に並べる(2026-11-21)。
      final cols = c.maxWidth >= 560 ? 2 : 1;
      return ListView(
        padding: const EdgeInsets.fromLTRB(9, 4, 9, 12),
        children: [
          Row(
            children: [
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  Tr.pick(
                      '送っている場所 $used / $slots か所・出張費は1か所 毎週${formatMoney(cost)}',
                      'Regions covered: $used of $slots • ${formatMoney(cost)} a week per region'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _HelpButton(
                  title: Tr.pick('スカウトの送り先', 'Scouting regions'),
                  text: help),
            ],
          ),
          for (var i = 0; i < regions.length; i += cols)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + cols; j++)
                  Expanded(
                      child: j < regions.length
                          ? region(regions[j])
                          : const SizedBox.shrink()),
              ],
            ),
        ],
      );
    });
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
        // 説明は1行に縮め、詳しくは「?」の中へ(2026-11-21)。
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  squadFull
                      ? Tr.pick('スカッドが上限のため、獲得するには誰かを放出してください。',
                          'Your squad is full. Release someone before you sign anyone.')
                      : Tr.pick('移籍金なし・年俸だけで取れる選手(窓の外でも取れます)',
                          'No fee, wages only (you can sign them outside the window too)'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: squadFull
                          ? Colors.orange
                          : SemanticColors.subtleText(context)),
                ),
              ),
              _HelpButton(
                title: Tr.pick('フリーエージェント', 'Free agents'),
                text: Tr.pick(
                    '移籍金なし・年俸のみで獲得できる選手です。所属が無いので、移籍の窓の外でも取れます。年俸・年数・サイン料を本人と話して決めます。',
                    'These players cost no fee, only wages. They have no club, so you can sign them outside the window too. Agree salary, length and signing bonus with the player.'),
              ),
            ],
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
                  onSign: (p) => _showTermsDialog(context, p),
                ),
        ),
      ],
    );
  }

  /// 選手(代理人)に年俸・契約の満了の年・サイン料を出す。他のクラブの
  /// 選手はクラブと合意したあと、フリーエージェントはいつでも。
  Future<void> _showTermsDialog(BuildContext context, Player player) async {
    final gameState = context.read<GameState>();
    final talk = gameState.talkFor(player.id);
    final demand = talk?.demandWage ?? 0;
    final current = player.wage;
    final top = [current * 3, demand * 2, 20].reduce((a, b) => a > b ? a : b);
    final low = (current ~/ 2).clamp(minWeeklyWage, top - 1);
    var wage = (demand > 0 ? demand : current).clamp(low, top).toDouble();
    final choices = ContractEngine.endYearChoicesNow(player.age);
    var endYear = choices.isEmpty
        ? Player.contractClockYear + 1
        : choices[(choices.length - 1).clamp(0, 2)];
    final bonusMax = [annualFromWeekly(top), (talk?.fee ?? 0) ~/ 10, 10]
        .reduce((a, b) => a > b ? a : b);
    var bonus = 0.0;
    var promise = SquadStatus.regular;
    final submitted = await showDialog<(int, int, int, SquadStatus)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final w = wage.round();
          final years = endYear - Player.contractClockYear + 1;
          final effective = PlayerTermsEngine.effectiveWeekly(
              weeklyWage: w, years: years, signingBonus: bonus.round());
          return AlertDialog(
            title: Text(Tr.pick(
                '${player.name}に条件を出す', 'Offer terms to ${player.name}')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Tr.pick(
                      '今の年俸: ${formatMoney(annualFromWeekly(current))}',
                      'Current salary: ${formatMoney(annualFromWeekly(current))}')),
                  Text(
                    Tr.pick(
                        '代理人: ${RelationsEngine.agentOf(player).label}(${RelationsEngine.agentOf(player).description})',
                        'Agent: ${RelationsEngine.agentOf(player).label} (${RelationsEngine.agentOf(player).description})'),
                    style: TextStyle(
                        fontSize: 12,
                        color: SemanticColors.subtleText(context)),
                  ),
                  if (talk != null && talk.hasRival)
                    Text(
                      Tr.pick(
                          '${talk.rivalClubName}も年俸${formatMoney(annualFromWeekly(talk.rivalWage))}で誘っています。選手は年俸とクラブの格を比べて選びます。',
                          '${talk.rivalClubName} offer ${formatMoney(annualFromWeekly(talk.rivalWage))} a year too. He compares money and the size of the club.'),
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  if (demand > 0)
                    Text(
                      Tr.pick(
                          '望む年俸: ${formatMoney(annualFromWeekly(demand))}(サイン料を含めて)',
                          'He wants: ${formatMoney(annualFromWeekly(demand))} a year (signing bonus included)'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 8),
                  Text(Tr.pick('年俸: ${formatMoney(annualFromWeekly(w))}',
                      'Salary: ${formatMoney(annualFromWeekly(w))} a year')),
                  Slider(
                    value: wage,
                    min: low.toDouble(),
                    max: top.toDouble(),
                    divisions: 60,
                    onChanged: (v) => setState(() => wage = v),
                  ),
                  Text(Tr.pick('サイン料: ${formatMoney(bonus.round())}',
                      'Signing bonus: ${formatMoney(bonus.round())}')),
                  Slider(
                    value: bonus,
                    max: bonusMax.toDouble(),
                    divisions: 40,
                    onChanged: (v) => setState(() => bonus = v),
                  ),
                  Text(Tr.pick('約束する序列', 'Promised billing')),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final st in SquadStatus.values)
                        ChoiceChip(
                          label: Text(st.label),
                          selected: promise == st,
                          onSelected: (_) => setState(() => promise = st),
                        ),
                    ],
                  ),
                  Text(
                    Tr.pick(
                        '出番を約束するほど望む年俸は上がります(キープレイヤー +15%・ローテーション -8%・育成枠 -15%)。あとで序列を上げると、選手は週俸の見直しを求めます。キープレイヤーは3節、主力は5節続けて先発から外すと約束を破ったことになり、移籍を願い出ます。',
                        'The more minutes you promise, the more he asks for (Key Player +15%, Squad Rotation -8%, Prospect -15%). Raise his billing later and he will want his wage reviewed. Leave a Key Player out for 3 straight matches, or a First Team player for 5, and you have broken your word: he will ask to leave.'),
                    style: TextStyle(
                        fontSize: 11,
                        color: SemanticColors.subtleText(context)),
                  ),
                  const SizedBox(height: 6),
                  if (choices.length > 1)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final y in choices)
                          ChoiceChip(
                            label: Text(Tr.pick('$y年6月まで', 'To June $y')),
                            selected: endYear == y,
                            onSelected: (_) => setState(() => endYear = y),
                          ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    Tr.pick(
                        'サイン料は契約の年数でならして年俸に足して見られます(実質 ${formatMoney(annualFromWeekly(effective))})。下の部へ移る選手や、こちらで控えになりそうな選手は多く望みます。条件を出せるのは${PlayerTermsEngine.maxRounds}回まで。離れすぎた額だと席を立たれます。',
                        'The bonus is spread over the contract and added to the salary (about ${formatMoney(annualFromWeekly(effective))} a year in all). Players dropping a division, or likely to be on your bench, want more. You get ${PlayerTermsEngine.maxRounds} offers; a lowball makes him walk away.'),
                    style: TextStyle(
                        fontSize: 12,
                        color: SemanticColors.subtleText(context)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Tr.pick('やめる', 'Never mind')),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, (w, endYear, bonus.round(), promise)),
                child: Text(Tr.pick('条件を出す', 'Make the offer')),
              ),
            ],
          );
        },
      ),
    );
    if (submitted == null || !context.mounted) return;
    final outcome = await gameState.offerPersonalTerms(player.id,
        weeklyWage: submitted.$1,
        endYear: submitted.$2,
        signingBonus: submitted.$3,
        promise: submitted.$4);
    if (!context.mounted) return;
    outcome == TermsOutcome.signed
        ? FeedbackService.success()
        : FeedbackService.error();
    final want = gameState.talkFor(player.id)?.demandWage ?? 0;
    final text = switch (outcome) {
      TermsOutcome.signed =>
        Tr.pick('${player.name}と契約しました', 'You signed ${player.name}'),
      TermsOutcome.counter => Tr.pick(
          '${player.name}はもっと欲しいそうです(年俸${formatMoney(annualFromWeekly(want))}ほど)。',
          '${player.name} wants more (about ${formatMoney(annualFromWeekly(want))} a year).'),
      _ => gameState.lastSigningBlockReason ??
          Tr.pick('契約できませんでした', 'The signing did not go through'),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 6)),
    );
  }

  /// 移籍金を提示する(新しく申し込む、または相手の対案に出し直す)。
  Future<void> _showBidDialog(
    BuildContext context,
    Player player, {
    TransferTalk? talk,
  }) async {
    final gameState = context.read<GameState>();
    final value = player.marketValue;
    final minBid = talk == null ? (value * 0.5).round() : talk.bid + 1;
    final maxBid = [value * 2, (talk?.fee ?? 0) * 3 ~/ 2, minBid + 1]
        .reduce((a, b) => a > b ? a : b);
    var bid = (talk?.fee ?? value).clamp(minBid, maxBid).toDouble();
    var inst = talk?.installments ?? false;
    final submitted = await showDialog<(int, bool)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final amount = bid.round();
          final pct = value <= 0 ? 0 : (amount * 100 / value).round();
          return AlertDialog(
            title: Text(
                Tr.pick('${player.name}の移籍金を提示', 'Bid for ${player.name}')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.pick('市場価値: ${formatMoney(value)}',
                    'Value: ${formatMoney(value)}')),
                if (talk != null)
                  Text(Tr.pick(
                      '相手の対案: ${formatMoney(talk.fee)}・前の提示: ${formatMoney(talk.bid)}',
                      'Their terms: ${formatMoney(talk.fee)} • Your last bid: ${formatMoney(talk.bid)}')),
                Text(Tr.pick('提示額: ${formatMoney(amount)}(市場価値の$pct%)',
                    'Your bid: ${formatMoney(amount)} ($pct% of value)')),
                Slider(
                  value: bid,
                  min: minBid.toDouble(),
                  max: maxBid.toDouble(),
                  divisions: 60,
                  onChanged: (v) => setState(() => bid = v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: inst,
                  onChanged: (v) => setState(() => inst = v ?? false),
                  title: Text(Tr.pick('分割払い(頭金3割、残りを4週で)',
                      'Instalments (30% now, the rest over 4 weeks)')),
                ),
                Text(
                  Tr.pick(
                      '返事は${TransferTalkEngine.replyDays}日ほどで来ます。安すぎると話を打ち切られます。提示できるのは${TransferTalkEngine.maxRounds}回まで。主力や若い有望株は高く、契約の残りが短い選手は安く売ってくれます。',
                      'Expect a reply in about ${TransferTalkEngine.replyDays} days. Bid too low and they walk away. You get ${TransferTalkEngine.maxRounds} bids at most. Key men and young prospects cost more; players near the end of their contracts cost less.'),
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
                onPressed: () => Navigator.pop(ctx, (amount, inst)),
                child: Text(Tr.pick('提示する', 'Make the bid')),
              ),
            ],
          );
        },
      ),
    );
    if (submitted == null || !context.mounted) return;
    final ok = await gameState.openTransferTalk(player.id, submitted.$1,
        installments: submitted.$2);
    if (!context.mounted) return;
    ok ? FeedbackService.tap() : FeedbackService.error();
    final reason = gameState.lastSigningBlockReason;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? Tr.pick('提示しました。返事は「交渉」のタブに届きます。',
                'Bid made. The reply will appear on the Talks tab.')
            : (reason ?? Tr.pick('提示できませんでした', 'The bid could not be made'))),
        duration: Duration(seconds: reason != null && !ok ? 6 : 4),
      ),
    );
  }

  /// 交渉: クラブとの移籍金の交渉の一覧。
  Widget _buildTalksTab(BuildContext context, GameState gameState) {
    final talks = gameState.transferTalks;
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    final buyBacks = gameState.buyBackCandidates;
    if (talks.isEmpty && buyBacks.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [_buyBackCard(context, gameState, buyBacks)],
      );
    }
    if (talks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Tr.pick('交渉中の話はありません。「探す」や「注目」で選手の「獲得」から移籍金を提示できます。',
                'No talks under way. Use Sign on a player in Search or Watchlist to make a bid.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          Tr.pick(
              '提示すると、${TransferTalkEngine.replyDays}日ほどで相手のクラブから返事が来ます。返事は「合意」「対案」「打ち切り」のどれかです。提示できるのは${TransferTalkEngine.maxRounds}回まで。クラブと合意したら、${TransferTalkEngine.agreementDays}日以内に選手(代理人)と年俸・年数・サイン料を決めます。窓が閉じると、まとまらなかった話は流れます。',
              'After a bid, the club replies in about ${TransferTalkEngine.replyDays} days: a deal, a counter, or a walk-out. You get ${TransferTalkEngine.maxRounds} bids at most. Once the clubs agree, settle salary, length and signing bonus with the player within ${TransferTalkEngine.agreementDays} days. Anything unfinished falls through when the window shuts.'),
          style: small,
        ),
        const SizedBox(height: 8),
        if (buyBacks.isNotEmpty) _buyBackCard(context, gameState, buyBacks),
        for (final t in talks) _talkCard(context, gameState, t),
      ],
    );
  }

  /// 買い戻し条項で呼び戻せる選手。
  Widget _buyBackCard(
      BuildContext context, GameState gameState, List<Player> players) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('買い戻せる選手', 'Buy-back options'),
                style: Theme.of(context).textTheme.titleSmall),
            for (final p in players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text(Tr.pick(
                    '${gameState.clubNameOf(p.id) ?? '-'}・${formatMoney(gameState.buyBackClauses[p.id]![0])}で${gameState.buyBackClauses[p.id]![1]}年6月まで',
                    '${gameState.clubNameOf(p.id) ?? '-'}: ${formatMoney(gameState.buyBackClauses[p.id]![0])} until June ${gameState.buyBackClauses[p.id]![1]}')),
                trailing: FilledButton(
                  onPressed: gameState.isTransferWindowOpen
                      ? () => _acquire(context,
                          () => gameState.exerciseBuyBack(p.id), p.name)
                      : null,
                  child: Text(Tr.pick('買い戻す', 'Buy back')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _talkCard(BuildContext context, GameState gameState, TransferTalk t) {
    String md(DateTime? d) =>
        d == null ? '-' : TransferWindowCalendar.formatMonthDay(d);
    final pay = t.installments && t.installmentsOk
        ? Tr.pick('分割', 'instalments')
        : Tr.pick('一括', 'up front');
    final terms = [
      formatMoney(t.fee),
      if (t.sellOnPercent > 0)
        Tr.pick('売却条項${t.sellOnPercent}%', '${t.sellOnPercent}% sell-on'),
      pay,
    ].join(Tr.pick('・', ', '));
    final status = switch (t.stage) {
      TransferTalkStage.waiting => Tr.pick(
          '提示 ${formatMoney(t.bid)}(${t.installments ? '分割' : '一括'})・返事は${md(t.replyOn)}ごろ',
          'Bid ${formatMoney(t.bid)} (${t.installments ? 'instalments' : 'up front'}) • reply around ${md(t.replyOn)}'),
      TransferTalkStage.countered => Tr.pick(
          '対案: $terms(こちらの提示 ${formatMoney(t.bid)}・${t.round}/${TransferTalkEngine.maxRounds}回目)',
          'Their terms: $terms (your bid ${formatMoney(t.bid)}, ${t.round} of ${TransferTalkEngine.maxRounds})'),
      TransferTalkStage.agreed => t.freeAgent
          ? Tr.pick(
              '条件の話し合い中・望む年俸 ${t.demandWage > 0 ? formatMoney(annualFromWeekly(t.demandWage)) : '?'}',
              'Discussing terms • wants ${t.demandWage > 0 ? formatMoney(annualFromWeekly(t.demandWage)) : '?'} a year')
          : Tr.pick(
              'クラブと合意: $terms・${md(t.deadline)}までに選手と契約する${t.demandWage > 0 ? '・望む年俸 ${formatMoney(annualFromWeekly(t.demandWage))}' : ''}',
              'Clubs agreed: $terms • sign him by ${md(t.deadline)}${t.demandWage > 0 ? ' • wants ${formatMoney(annualFromWeekly(t.demandWage))} a year' : ''}'),
      TransferTalkStage.collapsed =>
        Tr.pick('決裂(この窓のあいだは申し込めない)', 'Broken off (no more bids this window)'),
    };
    final player = gameState.talkPlayer(t.playerId);
    final withdraw = TextButton(
      onPressed: () {
        FeedbackService.tap();
        gameState.withdrawTransferTalk(t.playerId);
      },
      child: Text(Tr.pick('取り下げる', 'Withdraw')),
    );
    final buttons = <Widget>[
      if (t.stage == TransferTalkStage.waiting) withdraw,
      if (t.stage == TransferTalkStage.countered) ...[
        withdraw,
        TextButton(
          onPressed: player != null && t.round < TransferTalkEngine.maxRounds
              ? () => _showBidDialog(context, player, talk: t)
              : null,
          child: Text(Tr.pick('出し直す', 'Bid again')),
        ),
        FilledButton(
          onPressed: () {
            FeedbackService.tap();
            gameState.acceptTalkCounter(t.playerId);
          },
          child: Text(Tr.pick('対案をのむ', 'Accept their terms')),
        ),
      ],
      if (t.stage == TransferTalkStage.agreed) ...[
        withdraw,
        FilledButton(
          onPressed:
              player == null ? null : () => _showTermsDialog(context, player),
          child: Text(Tr.pick('選手と話す', 'Talk to the player')),
        ),
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: player == null
                  ? null
                  : PlayerFaceAvatar(
                      playerId: player.id, position: player.position),
              title: Text(Tr.pick('${t.playerName}(${t.clubName})',
                  '${t.playerName} (${t.clubName})')),
              subtitle: Text(status),
            ),
            if (t.hasRival && t.isOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  Tr.pick(
                      '競合: ${t.rivalClubName}が年俸${formatMoney(annualFromWeekly(t.rivalWage))}で誘っている。${md(t.rivalDecidesOn)}ごろまでに契約しないと、選手はあちらへ行く',
                      'Rival: ${t.rivalClubName} offer ${formatMoney(annualFromWeekly(t.rivalWage))} a year. Sign him by about ${md(t.rivalDecidesOn)} or he goes there'),
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                ),
              ),
            if (buttons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: buttons,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAcquireSheet(BuildContext context, Player player) {
    final gameState = context.read<GameState>();
    final save = gameState.save!;
    final total = player.marketValue;
    final agentFee = TransferTermsEngine.agentFee(total);
    final talk = gameState.talkFor(player.id);
    final loanFee = (total * GameState.loanFeeRatioPercent / 100).round();
    final buyOptionFee = (total * GameState.loanBuyOptionRatio).round();
    // 窓の外で開けるのは GK の緊急の特例だけ。そのときは期限付き(ローン)のみ。
    final permanentAllowed = gameState.isTransferWindowOpen;

    // 横画面は縦が短く、4つの選び方の下が切れていた。中でスクロールでき、
    // 横画面では2列に並べる。
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final wide = size.width > size.height;
        Widget cell(Widget tile) => wide
            ? SizedBox(
                width: ((size.width < 760 ? size.width : 760) - 48) / 2,
                child: tile)
            : tile;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.9),
            child: SingleChildScrollView(
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
                  Wrap(children: [
                    cell(ListTile(
                      leading: const Icon(Icons.handshake),
                      title: Text(Tr.pick('移籍金を提示する', 'Make a bid')),
                      subtitle: Text(talk != null
                          ? Tr.pick('もう交渉しています(「交渉」のタブで続きを)',
                              'Talks are already under way (see the Talks tab)')
                          : Tr.pick(
                              '相手のクラブと交渉します。返事は${TransferTalkEngine.replyDays}日ほどで来ます(別に代理人手数料${formatMoney(agentFee)}ほど)',
                              'Open talks with his club. They reply in about ${TransferTalkEngine.replyDays} days (plus about ${formatMoney(agentFee)} in agent fees)')),
                      enabled: permanentAllowed && talk == null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showBidDialog(context, player);
                      },
                    )),
                    cell(ListTile(
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
                          () => gameState.signLoanPlayer(player.id,
                              length: length),
                          player.name,
                        );
                      },
                    )),
                    cell(ListTile(
                      leading: const Icon(Icons.request_quote),
                      title: Text(Tr.pick(
                          '買取オプション付きローンで獲得', 'Loan with an option to buy')),
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
                    )),
                    cell(ListTile(
                      leading: const Icon(Icons.gavel),
                      title: Text(Tr.pick(
                          '買取義務付きローンで獲得', 'Loan with an obligation to buy')),
                      subtitle: Text(
                        Tr.pick(
                            '契約金${formatMoney((loanFee * GameStateForms.obligationLoanFeeFactor).round())}(ふつうの半分)・給与の6割を負担・満了したら必ず${formatMoney(buyOptionFee)}で買い取る',
                            '${formatMoney((loanFee * GameStateForms.obligationLoanFeeFactor).round())} fee (half the usual), 60% of his wages, and you must buy him for ${formatMoney(buyOptionFee)} when it ends'),
                      ),
                      enabled: permanentAllowed &&
                          save.budget >=
                              (loanFee * GameStateForms.obligationLoanFeeFactor)
                                  .round(),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final length = await _chooseLoanLength(context);
                        if (length == null || !context.mounted) return;
                        _acquire(
                          context,
                          () => gameState.signLoanPlayer(
                            player.id,
                            withObligation: true,
                            length: length,
                          ),
                          player.name,
                        );
                      },
                    )),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
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
            child: Text(Tr.pick(
                '1年(シーズン末の$fullEndまで)', 'Full season (until $fullEnd)')),
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

  /// 右端に添える短い字(スカッドの人数など)。
  final String? trailing;
  const _TransferWindowBanner({
    required this.open,
    required this.label,
    this.deadlineDay = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = deadlineDay
        ? SemanticColors.negative(context)
        : open
            ? Colors.green.shade700
            : Colors.grey.shade700;
    // 横画面は縦が狭いので、1行・細めにする(2026-11-21)。
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          Icon(open ? Icons.lock_open : Icons.lock, size: 14, color: color),
          const SizedBox(width: 6),
          if (deadlineDay) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                Tr.pick('締切日', 'DEADLINE DAY'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!,
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context))),
          ],
        ],
      ),
    );
  }
}

/// 説明文は「?」を押したときだけ出す(横画面の縦を空けるため)。
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.help_outline, size: 18),
        tooltip: title,
        visualDensity: VisualDensity.compact,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(Tr.pick('閉じる', 'Close')),
              ),
            ],
          ),
        ),
      );
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

/// SD に渡す補強の方針(任せるか・移籍金の上限・欲しい位置・年齢・人数)。
class _SdBriefCard extends StatelessWidget {
  const _SdBriefCard();

  static String _groupName(PositionGroup g) => switch (g) {
        PositionGroup.gk => 'GK',
        PositionGroup.def => Tr.pick('守備', 'DEF'),
        PositionGroup.mid => Tr.pick('中盤', 'MID'),
        PositionGroup.att => Tr.pick('攻撃', 'ATT'),
      };

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final sd = gameState.currentSd!;
    final b = gameState.sdBrief;
    final save = gameState.save!;
    // 上限は資金までを目安に動かせる(今の値が上なら今の値まで)。
    final top = [save.budget, b.maxFee, 10].reduce((a, c) => a > c ? a : c);
    final working = gameState.transferTalks
        .where((t) => t.bySd && t.isOpen)
        .map((t) => t.playerName)
        .toList();
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ExpansionTile(
        title: Text(Tr.pick(
            'SD(${sd.name})に補強を任せる', 'Let your SD (${sd.name}) run signings')),
        subtitle: Text(
          b.active
              ? Tr.pick(
                  '任せている・この窓 ${save.sdSignedThisWindow}/${b.maxSignings}人${working.isEmpty ? '' : '・交渉中: ${working.join('、')}'}',
                  'On • this window ${save.sdSignedThisWindow} of ${b.maxSignings}${working.isEmpty ? '' : ' • talking to ${working.join(', ')}'}')
              : Tr.pick('任せていない', 'Off'),
          style: small,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Tr.pick('任せる', 'Hand it over')),
            value: b.active,
            onChanged: (v) => gameState.updateSdBrief(active: v),
          ),
          Text(Tr.pick('1人あたりの移籍金の上限: ${formatMoney(b.maxFee)}',
              'Fee limit per player: ${formatMoney(b.maxFee)}')),
          Slider(
            value: b.maxFee.clamp(0, top).toDouble(),
            max: top.toDouble(),
            divisions: 40,
            onChanged: (v) => gameState.updateSdBrief(maxFee: v.round()),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final g in PositionGroup.values)
                FilterChip(
                  label: Text(_groupName(g)),
                  selected: b.groups.contains(g),
                  onSelected: (on) => gameState.updateSdBrief(
                      groups:
                          on ? {...b.groups, g} : ({...b.groups}..remove(g))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(Tr.pick('年齢の上限: ${b.maxAge}歳', 'Age limit: ${b.maxAge}')),
          Slider(
            value: b.maxAge.toDouble(),
            min: 18,
            max: 35,
            divisions: 17,
            onChanged: (v) => gameState.updateSdBrief(maxAge: v.round()),
          ),
          Row(
            children: [
              Text(Tr.pick('この窓で取る人数', 'Signings this window')),
              const SizedBox(width: 8),
              for (final n in [1, 2, 3])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: b.maxSignings == n,
                    onSelected: (_) => gameState.updateSdBrief(maxSignings: n),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            Tr.pick(
                'SDは、見えている選手のうち方針に合い、今の先発より上の選手を探して、クラブとも選手とも交渉します。上限を超える値なら降ります。位置を選ばなければ全部の位置から探します。',
                'Your SD looks for players you have scouted who fit the brief and beat your current starters, then negotiates with the club and the player. He walks away if the price passes your limit. Pick no position to search them all.'),
            style: small,
          ),
        ],
      ),
    );
  }
}
