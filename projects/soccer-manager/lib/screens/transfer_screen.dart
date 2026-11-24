import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/disabled_reason.dart';
import '../logic/contract_engine.dart';
import '../logic/scout_knowledge.dart';
import '../logic/signing_proposal_engine.dart';
import '../logic/squad_registration_engine.dart';
import '../logic/transfer_window.dart';
import '../logic/transfer_talk_engine.dart';
import '../models/transfer_talk.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/affiliate_card.dart';
import '../widgets/estimate_stars.dart';
import '../widgets/incoming_offers_card.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../logic/todo_advisor.dart';
import '../widgets/shell_nav.dart';
import '../widgets/todo_list.dart';
import '../widgets/chip_switcher.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';
import '../widgets/screen_bar.dart';
import '../logic/economy_scale.dart';
import 'player_actions.dart';
import 'transfer_actions.dart';

enum TransferSortOption { overall, potential, marketValue, age, contract }

/// 「探す」の絞り込み(FM の移籍の検索。2026-11-25 に増やした)。
///
/// 星の下限は見立ての真ん中で見る([EstimateStars.starsFor]。星3つが自クラブの
/// 先発の平均)。見えていない選手は、星の下限を付けると外れる。
class TransferSearchFilter {
  TransferSearchFilter();

  PositionGroup? group;
  int minAge = minAgeLimit;
  int maxAge = maxAgeLimit;

  /// 総合(見立て)の星の下限(0 は問わない。1〜5)。
  int minOverallStars = 0;

  /// 伸びしろ(見立て)の星の下限(0 は問わない。1〜5)。
  int minPotentialStars = 0;

  /// 市場価値: 0 問わない・1 資金で買える・2 資金の半分まで。
  int valueCap = 0;

  /// 年俸: 0 問わない・1 自クラブの最高まで・2 自クラブの平均まで。
  int wageCap = 0;

  /// 契約の残り: 0 問わない・1 1年以内・2 2年以内。
  int contractMax = 0;

  /// 国・リーグ(スカウトの地域の key)。null は全部。
  String? region;
  bool listedOnly = false;
  bool loanOnly = false;
  bool knownOnly = false;

  static const int minAgeLimit = 16;
  static const int maxAgeLimit = 40;

  TransferSearchFilter copy() => TransferSearchFilter()
    ..group = group
    ..minAge = minAge
    ..maxAge = maxAge
    ..minOverallStars = minOverallStars
    ..minPotentialStars = minPotentialStars
    ..valueCap = valueCap
    ..wageCap = wageCap
    ..contractMax = contractMax
    ..region = region
    ..listedOnly = listedOnly
    ..loanOnly = loanOnly
    ..knownOnly = knownOnly;

  /// 位置の札のほかに付いている絞り込みの数。
  int get activeCount => [
        minAge != minAgeLimit || maxAge != maxAgeLimit,
        minOverallStars > 0,
        minPotentialStars > 0,
        valueCap > 0,
        wageCap > 0,
        contractMax > 0,
        region != null,
        listedOnly,
        loanOnly,
        knownOnly,
      ].where((x) => x).length;
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    this.embedded = false,
    this.initialTab = 0,
    this.initialCard,
  });

  /// 下タブの一員として表示するか。true なら戻るボタンを出さない。
  final bool embedded;

  /// 開いたときに出すタブ。
  final int initialTab;

  /// 開いたときに出す札([TodoPlaces.cardAffiliate] など)。
  final String? initialCard;

  /// 「届いたオファー」のタブの位置。状況の判断カードからここへ飛ぶ。
  static const offersTab = 2;

  /// タブの数(候補・探す・交渉とオファー)。
  static const int tabCount = 3;

  /// 「探す」の札の並び(選手を探す・フリー・スカウトの地域・系列クラブ)。
  static const int searchChipAffiliate = 3;

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
      case TransferSortOption.contract:
        players.sort((a, b) =>
            a.contractYearsRemaining.compareTo(b.contractYearsRemaining));
        break;
    }
    return players;
  }

  /// 「探す」の絞り込みと並べ替え(見立てで並べる)。UI から切り離して
  /// テストできるようにしてある。
  static List<Player> searchPlayers(
    GameState game,
    List<Player> targets,
    TransferSearchFilter f, {
    TransferSortOption sort = TransferSortOption.overall,
    Set<String>? same,
  }) {
    final sameIds = same ?? game.sameLeaguePlayerIds();
    final ref = EstimateStars.referenceOf(game.userTeam);
    final budget = game.save?.budget ?? 0;
    final wages = [for (final p in game.userTeam.players) p.wage];
    final maxWage = wages.isEmpty ? 0 : wages.reduce((a, b) => a > b ? a : b);
    final avgWage = wages.isEmpty
        ? 0
        : (wages.reduce((a, b) => a + b) / wages.length).round();
    final regionOf = <String, String>{
      if (f.region != null)
        for (final r in game.scoutRegions)
          if (r.key == f.region)
            for (final t in r.teams)
              for (final p in t.players) p.id: r.key,
    };
    int center((int, int)? r) => ScoutKnowledge.center(r);
    bool starsOk((int, int)? r, int min) =>
        min <= 0 ||
        (r != null && EstimateStars.starsFor(center(r), ref) >= min);
    final out = <Player>[];
    final ovr = <String, (int, int)?>{};
    final pot = <String, (int, int)?>{};
    for (final p in targets) {
      if (f.group != null && p.position.group != f.group) continue;
      if (p.age < f.minAge || p.age > f.maxAge) continue;
      if (f.valueCap == 1 && p.marketValue > budget) continue;
      if (f.valueCap == 2 && p.marketValue > budget ~/ 2) continue;
      if (f.wageCap == 1 && p.wage > maxWage) continue;
      if (f.wageCap == 2 && p.wage > avgWage) continue;
      if (f.contractMax > 0 && p.contractYearsRemaining > f.contractMax) {
        continue;
      }
      if (f.region != null && !regionOf.containsKey(p.id)) continue;
      if (f.listedOnly && !game.isListedByClub(p)) continue;
      if (f.loanOnly && !game.isLoanAvailable(p)) continue;
      final k = game.knowledgeOf(p, sameLeagueIds: sameIds);
      if (f.knownOnly && k <= 0) continue;
      final o = game.overallEstimate(p, sameLeagueIds: sameIds);
      final q = game.potentialEstimate(p, sameLeagueIds: sameIds);
      if (!starsOk(o, f.minOverallStars)) continue;
      if (!starsOk(q, f.minPotentialStars)) continue;
      ovr[p.id] = o;
      pot[p.id] = q;
      out.add(p);
    }
    switch (sort) {
      // 総合力・伸びしろは本当の値ではなく、見立ての真ん中で並べる
      // (見えていない選手は後ろ)。
      case TransferSortOption.overall:
        out.sort((a, b) => center(ovr[b.id]).compareTo(center(ovr[a.id])));
      case TransferSortOption.potential:
        out.sort((a, b) => center(pot[b.id]).compareTo(center(pot[a.id])));
      case TransferSortOption.marketValue:
        out.sort((a, b) => a.marketValue.compareTo(b.marketValue));
      case TransferSortOption.age:
        out.sort((a, b) => a.age.compareTo(b.age));
      case TransferSortOption.contract:
        out.sort((a, b) =>
            a.contractYearsRemaining.compareTo(b.contractYearsRemaining));
    }
    return out;
  }

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  /// オーナーが見送った候補。この画面を開いているあいだだけ覚える。
  final Set<String> _passed = {};

  // 「探す」の絞り込み。
  TransferSearchFilter _filter = TransferSearchFilter();
  TransferSortOption _searchSort = TransferSortOption.overall;
  int _searchLimit = 40;
  late final TabController _tabController;

  /// 「候補」の札(窓の開き具合で並びが変わる)と「探す」の札。
  final ValueNotifier<int> _shortlistChip = ValueNotifier(0);
  final ValueNotifier<int> _searchChip = ValueNotifier(0);
  ShellNav? _nav;
  int _seenCardSerial = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: TransferScreen.tabCount,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, TransferScreen.tabCount - 1));
    _applyCard(widget.initialCard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = widget.embedded ? ShellNav.maybeOf(context) : null;
    if (nav != _nav) {
      _nav?.removeListener(_fromNav);
      _nav = nav?..addListener(_fromNav);
      _fromNav();
    }
  }

  @override
  void dispose() {
    _nav?.removeListener(_fromNav);
    _tabController.dispose();
    _shortlistChip.dispose();
    _searchChip.dispose();
    super.dispose();
  }

  /// 「やること」や入口の行から札を選ばれた。
  void _fromNav() {
    final nav = _nav;
    if (!mounted || nav == null || nav.cardSerial == _seenCardSerial) return;
    _seenCardSerial = nav.cardSerial;
    if (nav.menu != TodoMenu.transfer) return;
    _applyCard(nav.card);
  }

  void _applyCard(String? card) {
    if (card == TodoPlaces.cardAffiliate) {
      _searchChip.value = TransferScreen.searchChipAffiliate;
    }
  }

  /// 「探す」の選手の一覧へ(絞り込みを[edit]で変えてから)。
  void _goSearch([void Function(TransferSearchFilter f)? edit]) {
    setState(() {
      if (edit != null) {
        _filter = _filter.copy();
        edit(_filter);
      }
    });
    _searchChip.value = 0;
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final windowOpen = gameState.isTransferWindowOpen;
    // 申し込める他のクラブの選手。この画面の作り直しのたびに1回だけ集める。
    final targets = gameState.transferTargets;
    // 同じ部の選手(最初から少し見えている)。見え方を何度も測るので1回だけ集める。
    final same = gameState.sameLeaguePlayerIds();

    final proposals = (
      Tr.pick('監督の補強案', "Manager's signing picks"),
      (BuildContext context) =>
          _buildProposalTab(context, gameState, save, squadFull, targets, same)
    );
    final watch = (
      Tr.pick('注目 (${save.watchlistPlayerIds.length})',
          'Shortlist (${save.watchlistPlayerIds.length})'),
      (BuildContext context) =>
          _buildWatchTab(context, gameState, save, squadFull, targets, same)
    );

    // 左メニューの中にあるときは、「やること」の行き先からタブを選べる。
    return ShellTabSync(
      menu: TodoMenu.transfer,
      controller: _tabController,
      enabled: widget.embedded,
      child: Scaffold(
        appBar: screenBar(
          context,
          title: Tr.pick('移籍市場', 'Transfers'),
          leading: widget.embedded ? null : const BackButton(),
          controller: _tabController,
          tabMarks: widget.embedded
              ? todoTabMarks(context, TodoMenu.transfer, TransferScreen.tabCount)
              : const [],
          tabs: [
            // 7つあったタブを、用件ごとの3つにまとめた(2026-11-24)。
            // 候補 = 監督の補強案と注目、探す = 他クラブの選手・フリー・
            // スカウトを送る地域・系列クラブ、交渉とオファー = 進んでいる話の全部。
            Tr.pick('候補', 'Shortlist'),
            Tr.pick('探す', 'Search'),
            // 進んでいる交渉と届いたオファーの数。左の「移籍」の印と合う。
            Tr.pick(
                '交渉とオファー (${gameState.transferTalks.length + gameState.incomingOffers.length})',
                'Talks & offers (${gameState.transferTalks.length + gameState.incomingOffers.length})'),
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
              // 候補: 窓が開いているあいだは監督の補強案(すぐ入札できる)を
              // 先に、閉じているあいだは注目(次の窓へ向けて見ておく選手)を
              // 先にする(2026-11-25)。
              ChipSwitcher(
                key: ValueKey('transfer-shortlist-chips-$windowOpen'),
                index: _shortlistChip,
                items: windowOpen ? [proposals, watch] : [watch, proposals],
              ),
              // 探す: 他のクラブの選手・所属のない選手・スカウトを送る地域・
              // 系列クラブ。
              ChipSwitcher(
                key: const ValueKey('transfer-search-chips'),
                index: _searchChip,
                items: [
                  (
                    Tr.pick('選手を探す', 'Find players'),
                    (context) => _buildSearchTab(
                        context, gameState, squadFull, targets, same)
                  ),
                  (
                    Tr.pick('フリー (${gameState.freeAgents.length})',
                        'Free agents (${gameState.freeAgents.length})'),
                    (context) =>
                        _buildFreeAgentTab(context, gameState, squadFull, same)
                  ),
                  (
                    // クラブの「ユース・新人発掘」(自前の育成)とは別。こちらは
                    // 他のクラブの選手を見に行く先。
                    Tr.pick('スカウトの地域', 'Scouting regions'),
                    (context) => _buildScoutTab(context, gameState, save)
                  ),
                  (
                    // 選手の貸し借りの相手(2026-11-25 にクラブの施設から移した)。
                    Tr.pick('系列クラブ', 'Feeder club'),
                    (context) => _buildAffiliateTab(
                        context, gameState, squadFull, same)
                  ),
                ],
              ),
              // 交渉とオファー: 届いたオファー・移籍リストの選手・進んでいる
              // 交渉・買い戻せる選手を、1つの一覧で。
              ListView(
                key: const ValueKey('transfer-deals-tab'),
                children: [
                  _buildOffersTab(context, gameState, nested: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      Tr.pick('進んでいる交渉 (${gameState.transferTalks.length})',
                          'Talks under way (${gameState.transferTalks.length})'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  _buildTalksTab(context, gameState, nested: true),
                ],
              ),
            ],
          ),
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
              : Tr.pick(
                  'スカッド $count/$maxSquadSize', 'Squad $count/$maxSquadSize'),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Tr.pick('いまは監督から候補がありません。次の節のあとにまた挙がります。',
                              'No candidates right now. Your manager will suggest more after the next matchday.'),
                          textAlign: TextAlign.center,
                        ),
                        _moreTargetsHint(context, save),
                      ],
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
                    _moreTargetsHint(context, save),
                  ],
                ),
        ),
      ],
    );
  }

  /// 監督の案の下に置く、ほかの選手の探し方。候補は最大
  /// [SigningProposalEngine.count] 人なので、iPad では下半分が空いていた
  /// (2026-11-23)。空いた所に「探す」「注目」への入り口を置く。
  Widget _moreTargetsHint(BuildContext context, SaveGame save) {
    final watching = save.watchlistPlayerIds.length;
    final windowOpen = context.read<GameState>().isTransferWindowOpen;
    return Padding(
      key: const ValueKey('transfer-more-targets'),
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Column(
        children: [
          Text(
            Tr.pick(
                '監督が挙げるのは、層の薄い位置を中心に${SigningProposalEngine.count}人までです。ほかの選手は「探す」で位置や年齢を絞って探せます。',
                'Your manager puts forward up to ${SigningProposalEngine.count} players, mostly where the squad is thin. Use Search to look for anyone else by position or age.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: SemanticColors.subtleText(context)),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: () => _goSearch(),
                icon: const Icon(Icons.search, size: 18),
                label: Text(Tr.pick('探す', 'Search')),
              ),
              OutlinedButton.icon(
                // 注目は「候補」の札(窓が開いていれば2つ目)。
                onPressed: () => _shortlistChip.value = windowOpen ? 1 : 0,
                icon: const Icon(Icons.star_border, size: 18),
                label: Text(Tr.pick('注目 ($watching)', 'Shortlist ($watching)')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 監督の案の1人分の行。名前・位置・年齢・所属と、総合力・移籍金を
  /// 列にして並べ、注目・見送る・買うも同じ行に置く(2026-11-21)。
  /// 名前の所を押すと選手の詳しい画面(2026-11-25)。
  Widget _proposalRow(
    BuildContext context,
    GameState gameState,
    Player p,
    bool windowOpen,
    bool squadFull,
    Set<String> same,
  ) {
    final range = gameState.overallEstimate(p, sameLeagueIds: same);
    final ref = EstimateStars.referenceOf(gameState.userTeam);
    final fee = formatMoney(p.marketValue);
    final affordable = gameState.save!.budget >= p.marketValue;
    final club = gameState.clubNameOf(p.id) ?? '-';
    final canSign = (windowOpen ||
            (gameState.isGoalkeeperEmergency && p.position == Position.gk)) &&
        !squadFull;
    final subtle = SemanticColors.subtleText(context);
    Widget value(String caption, Widget v) => SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(caption, style: TextStyle(fontSize: 10, color: subtle)),
              v,
            ],
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 520;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('proposal-row-${p.id}'),
                onTap: () => openPlayerDetail(context, p.id),
                child: Row(
                  children: [
                    PlayerFaceAvatar(
                        playerId: p.id, position: p.position, size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            wide
                                ? Tr.pick('${p.position.label}・${p.age}歳・$club',
                                    '${p.position.label} • ${p.age} • $club')
                                : Tr.pick(
                                    '${p.position.label}・${p.age}歳・総合 ${ScoutKnowledge.label(range)}・$fee',
                                    '${p.position.label} • ${p.age} • OVR ${ScoutKnowledge.label(range)} • $fee'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: subtle),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      value(
                          Tr.pick('総合(見立て)', 'OVR (est.)'),
                          EstimateStars(
                              range: range,
                              reference: ref,
                              size: 12,
                              showNumbers: true)),
                      value(
                          Tr.pick('移籍金', 'Fee'),
                          Text(fee,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: affordable
                                      ? null
                                      : Theme.of(context).colorScheme.error))),
                    ],
                  ],
                ),
              ),
            ),
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
              onPressed: canSign ? () => showAcquireSheet(context, p) : null,
              child: Text(Tr.pick('買う', 'Sign')),
            ),
          ],
        ),
      );
    });
  }

  /// 他のクラブの選手を表で並べる(探す・注目・フリー・系列クラブ)。数字を
  /// 列にそろえて、選手どうしを比べやすくする(2026-11-21)。行を押すと
  /// 選手の詳しい画面(2026-11-25)。総合力・伸びしろは見立ての星。
  Widget _targetTable(
    BuildContext context,
    GameState gameState,
    List<Player> players,
    bool squadFull,
    Set<String> same, {
    Widget? footer,
    bool windowBannerAbove = false,
    bool free = false,
    String emptyText = '',
  }) {
    final scheme = Theme.of(context).colorScheme;
    final budget = gameState.save!.budget;
    final ref = EstimateStars.referenceOf(gameState.userTeam);
    final canSignNow = (free || gameState.isTransferWindowOpen) && !squadFull;
    final affiliateId = gameState.affiliateClub?.id;
    // 「獲得」が全部の行で押せない理由。行ごとに出すと表の高さが倍になる
    // ので、表の上に1回だけ出す。窓の状態は、上に帯がある画面(探す)では
    // 帯に任せる。
    final String? blocked = squadFull
        ? Tr.pick(
            'スカッドが上限($maxSquadSize人)です。誰かを手放すと獲得できます',
            'Your squad is full ($maxSquadSize). Move someone on before you sign anyone')
        : free
            ? null
            : gameState.isGoalkeeperEmergency
                // 窓の外でも GK だけは押せる(緊急の特例)。
                ? Tr.pick('移籍の窓が閉じています。いまは特例で GK だけ獲得できます',
                    'The window is shut. Only a goalkeeper can be signed, under the emergency rule')
                : (!gameState.isTransferWindowOpen && !windowBannerAbove)
                    ? Tr.pick(
                        '${gameState.transferWindowStatusLabel}。獲得はそれまで押せません',
                        '${gameState.transferWindowStatusLabel}. You cannot sign anyone until then')
                    : null;
    final head = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: scheme.onSurfaceVariant);
    const small = TextStyle(fontSize: 12);
    Widget cell(String s, double w, {TextStyle? base}) => SizedBox(
          width: w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s, textAlign: TextAlign.center, style: base),
          ),
        );
    Widget tag(String s, Color c) => Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            border: Border.all(color: c),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(s,
              style: TextStyle(
                  fontSize: 10, color: c, fontWeight: FontWeight.bold)),
        );
    return LayoutBuilder(builder: (context, c) {
      // 横幅に合わせて列を増やす。所属の字は縮めない(2026-11-25)。
      final showClub = !free && c.maxWidth >= 560;
      final showPot = c.maxWidth >= 640;
      final showMore = c.maxWidth >= 820;
      final header = Container(
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(Tr.pick('名前', 'Name'), style: head)),
            if (showClub)
              SizedBox(
                  width: 116,
                  child: Text(Tr.pick('所属', 'Club'), style: head)),
            cell(Tr.pick('年', 'Age'), 28, base: head),
            cell(Tr.pick('位置', 'Pos'), 40, base: head),
            cell(Tr.pick('総合(見立て)', 'OVR (est.)'), 76, base: head),
            if (showPot) cell(Tr.pick('伸びしろ(見立て)', 'POT (est.)'), 76, base: head),
            cell(free ? Tr.pick('年俸', 'Salary') : Tr.pick('市場価値', 'Value'), 60,
                base: head),
            if (showMore && !free) cell(Tr.pick('年俸', 'Salary'), 60, base: head),
            if (showMore && !free) cell(Tr.pick('契約', 'Contract'), 44, base: head),
            if (showMore) cell(Tr.pick('見え', 'Known'), 40, base: head),
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
        final club = gameState.sellingClubOf(p.id);
        final clubName = club?.name ?? gameState.clubNameOf(p.id) ?? '-';
        final listed = !free && gameState.isListedByClub(p);
        final affiliate = club != null && club.id == affiliateId;
        return Material(
          color: i.isOdd ? scheme.surfaceContainerLow : Colors.transparent,
          child: InkWell(
            key: ValueKey('target-row-${p.id}'),
            onTap: () => openPlayerDetail(context, p.id),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: small.copyWith(
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (listed)
                              tag(Tr.pick('売', 'TL'),
                                  SemanticColors.ink(
                                      context, Colors.green.shade700)),
                            if (affiliate)
                              tag(Tr.pick('系列', 'Feeder'),
                                  SemanticColors.ink(context, Colors.indigo)),
                          ],
                        ),
                        // 狭いときは所属を名前の下に(字は小さくしない)。
                        if (!showClub && clubName != '-')
                          Text(clubName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: small.copyWith(
                                  color: SemanticColors.subtleText(context))),
                      ],
                    ),
                  ),
                  if (showClub)
                    SizedBox(
                      width: 116,
                      child: Text(clubName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small),
                    ),
                  cell('${p.age}', 28, base: small),
                  cell(p.position.label, 40, base: small),
                  SizedBox(
                    width: 76,
                    child: Center(
                      child: EstimateStars(
                          range:
                              gameState.overallEstimate(p, sameLeagueIds: same),
                          reference: ref,
                          size: 11,
                          showNumbers: true),
                    ),
                  ),
                  if (showPot)
                    SizedBox(
                      width: 76,
                      child: Center(
                        child: EstimateStars(
                            range: gameState.potentialEstimate(p,
                                sameLeagueIds: same),
                            reference: ref,
                            size: 11,
                            showNumbers: true),
                      ),
                    ),
                  cell(
                      free
                          ? formatMoney(annualFromWeekly(p.wage))
                          : formatMoney(p.marketValue),
                      60,
                      base: small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: free || budget >= p.marketValue
                              ? null
                              : scheme.error)),
                  if (showMore && !free)
                    cell(formatMoney(annualFromWeekly(p.wage)), 60, base: small),
                  if (showMore && !free)
                    cell(ContractEngine.untilTinyLabel(p.contractEndYear), 44, base: small),
                  if (showMore)
                    cell('$k%', 40,
                        base: small.copyWith(
                            color: SemanticColors.subtleText(context))),
                  SizedBox(width: 40, child: _WatchButton(playerId: p.id)),
                  SizedBox(
                    width: 52,
                    // 行の主な操作なので塗りのボタン(文字だけだと押せる所に
                    // 見えなかった。2026-11-24)。
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(52, 40)),
                      onPressed: canSign
                          ? () => free
                              ? openPersonalTerms(context, p)
                              : showAcquireSheet(context, p)
                          : null,
                      child: Text(Tr.pick('獲得', 'Sign'), style: small),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DisabledReason(blocked,
              key: const ValueKey('target-table-blocked'),
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 2)),
          header,
          Expanded(
            child: players.isEmpty && emptyText.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(emptyText, textAlign: TextAlign.center),
                    ),
                  )
                : ListView.builder(
                    itemCount: players.length + (footer == null ? 0 : 1),
                    itemBuilder: (context, i) => i < players.length
                        ? SizedBox(height: showClub ? 42 : 48, child: row(i))
                        : footer!,
                  ),
          ),
        ],
      );
    });
  }

  /// 探す: 他のクラブの選手を、位置・年齢・見立て・お金・契約・国などで
  /// 絞って並べる(FM の検索。2026-11-25 に絞り込みを増やした)。
  Widget _buildSearchTab(
    BuildContext context,
    GameState gameState,
    bool squadFull,
    List<Player> targets,
    Set<String> same,
  ) {
    final found = TransferScreen.searchPlayers(gameState, targets, _filter,
        sort: _searchSort, same: same);
    final shown = found.take(_searchLimit).toList();
    final active = _filter.activeCount;
    return Column(
      children: [
        _TransferWindowBanner(
          open: gameState.isTransferWindowOpen,
          deadlineDay: gameState.isTransferDeadlineDay,
          label: gameState.transferWindowStatusLabel,
        ),
        // 絞り込みは1段に。細かい条件は「絞り込み」の中へ。
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
                      for (final g in <PositionGroup?>[
                        null,
                        ...PositionGroup.values
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text(_groupLabel(g)),
                            selected: _filter.group == g,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() {
                              _filter = _filter.copy()..group = g;
                            }),
                          ),
                        ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        key: const ValueKey('search-filter-open'),
                        style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        onPressed: () => _openFilterSheet(context, gameState),
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text(active == 0
                            ? Tr.pick('絞り込み', 'Filters')
                            : Tr.pick('絞り込み ($active)', 'Filters ($active)')),
                      ),
                      const SizedBox(width: 8),
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
                    '自国の全部と、他の4か国の1部のクラブの選手から探せます。上から${shown.length}人を表示しています(下の「もっと見る」で増えます)。行を押すと選手の詳しい画面が開き、入札・比較・スカウトに見させるができます。\n\n総合と伸びしろはスカウトの見立てです。星3つが自クラブの先発の平均で、濃い星が見立ての下の端、薄い星が上の端(まだ見えていない幅)。「見え」が高いほど幅が狭くなります。市場価値が資金より高い選手は赤で出ます。\n\n「売」は相手のクラブが売りに出している選手(言い値が1割安い)、「系列」は系列クラブの選手(2割引)。',
                    'Every club at home and the top flights of the other four countries. Showing the top ${shown.length} ("Show more" at the bottom adds more). Tap a row to open his profile, where you can bid, compare or have him scouted.\n\nOverall and potential are your scouts\' estimates. Three stars is your starters\' average; solid stars are the low end, faint stars the high end still unseen. The better known a player is, the narrower the range. Values above your funds are shown in red.\n\n"TL" marks players their club has transfer-listed (10% cheaper); "Feeder" marks players at your feeder club (20% off).'),
              ),
            ],
          ),
        ),
        if (active > 0) _activeFilterChips(context, gameState),
        Expanded(
          child: _targetTable(
            context,
            gameState,
            shown,
            squadFull,
            same,
            windowBannerAbove: true,
            emptyText: Tr.pick('条件に合う選手がいません。絞り込みをゆるめてください。',
                'Nobody matches. Loosen the filters.'),
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

  /// 付いている絞り込みを札で並べる(✕で外す)。
  Widget _activeFilterChips(BuildContext context, GameState game) {
    final f = _filter;
    final chips = <(String, void Function(TransferSearchFilter))>[
      if (f.minAge != TransferSearchFilter.minAgeLimit ||
          f.maxAge != TransferSearchFilter.maxAgeLimit)
        (
          Tr.pick('${f.minAge}〜${f.maxAge}歳', 'Age ${f.minAge}-${f.maxAge}'),
          (x) => x
            ..minAge = TransferSearchFilter.minAgeLimit
            ..maxAge = TransferSearchFilter.maxAgeLimit
        ),
      if (f.minOverallStars > 0)
        (
          Tr.pick('総合 星${f.minOverallStars}以上', 'OVR ${f.minOverallStars}+ stars'),
          (x) => x.minOverallStars = 0
        ),
      if (f.minPotentialStars > 0)
        (
          Tr.pick('伸びしろ 星${f.minPotentialStars}以上',
              'POT ${f.minPotentialStars}+ stars'),
          (x) => x.minPotentialStars = 0
        ),
      if (f.valueCap > 0) (_valueCapLabel(f.valueCap), (x) => x.valueCap = 0),
      if (f.wageCap > 0) (_wageCapLabel(f.wageCap), (x) => x.wageCap = 0),
      if (f.contractMax > 0)
        (_contractLabel(f.contractMax), (x) => x.contractMax = 0),
      if (f.region != null)
        (
          game.scoutRegions
                  .where((r) => r.key == f.region)
                  .map((r) => r.label)
                  .firstOrNull ??
              '-',
          (x) => x.region = null
        ),
      if (f.listedOnly)
        (Tr.pick('移籍リスト入り', 'Transfer listed'), (x) => x.listedOnly = false),
      if (f.loanOnly)
        (Tr.pick('貸し出し可', 'Available for loan'), (x) => x.loanOnly = false),
      if (f.knownOnly)
        (Tr.pick('見えている選手だけ', 'Scouted only'), (x) => x.knownOnly = false),
    ];
    return SizedBox(
      key: const ValueKey('search-active-filters'),
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final (label, clear) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InputChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onDeleted: () => setState(() {
                  _filter = _filter.copy();
                  clear(_filter);
                }),
              ),
            ),
          TextButton(
            onPressed: () => setState(() {
              _filter = TransferSearchFilter()..group = _filter.group;
            }),
            child: Text(Tr.pick('全部外す', 'Clear all')),
          ),
        ],
      ),
    );
  }

  static String _valueCapLabel(int v) => switch (v) {
        1 => Tr.pick('資金で買える', 'Within your funds'),
        2 => Tr.pick('資金の半分まで', 'Up to half your funds'),
        _ => Tr.pick('問わない', 'Any'),
      };

  static String _wageCapLabel(int v) => switch (v) {
        1 => Tr.pick('年俸 自クラブの最高まで', 'Salary up to your top earner'),
        2 => Tr.pick('年俸 自クラブの平均まで', 'Salary up to your average'),
        _ => Tr.pick('問わない', 'Any'),
      };

  static String _contractLabel(int v) => switch (v) {
        1 => Tr.pick('契約 残り1年以内', 'Contract: 1 year or less'),
        2 => Tr.pick('契約 残り2年以内', 'Contract: 2 years or less'),
        _ => Tr.pick('問わない', 'Any'),
      };

  /// 絞り込みの細かい条件(下から出る。横画面では2列)。
  Future<void> _openFilterSheet(BuildContext context, GameState game) async {
    var f = _filter.copy();
    final regions = game.scoutRegions;
    final applied = await showModalBottomSheet<TransferSearchFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final size = MediaQuery.sizeOf(ctx);
          final wide = size.width > size.height;
          final itemWidth = wide
              ? ((size.width < 760 ? size.width : 760) - 48) / 2
              : size.width - 32;
          Widget item(String label, Widget child) => SizedBox(
                width: itemWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              );
          Widget drop<T>(T value, List<T> items, String Function(T) label,
                  void Function(T) set) =>
              DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final v in items)
                    DropdownMenuItem(
                        value: v,
                        child: Text(label(v),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) {
                  if (v != null) setSheet(() => set(v));
                },
              );
          String stars(int n) =>
              n == 0 ? Tr.pick('問わない', 'Any') : Tr.pick('星$n以上', '$n+ stars');
          Widget toggle(String label, bool v, void Function(bool) set) =>
              SizedBox(
                width: itemWidth,
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label, style: const TextStyle(fontSize: 13)),
                  value: v,
                  onChanged: (x) => setSheet(() => set(x)),
                ),
              );
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.9),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(Tr.pick('絞り込み', 'Filters'),
                        style: Theme.of(ctx).textTheme.titleMedium),
                    Wrap(
                      spacing: 16,
                      children: [
                        item(
                          Tr.pick('年齢 ${f.minAge}〜${f.maxAge}歳',
                              'Age ${f.minAge}-${f.maxAge}'),
                          RangeSlider(
                            values: RangeValues(
                                f.minAge.toDouble(), f.maxAge.toDouble()),
                            min: TransferSearchFilter.minAgeLimit.toDouble(),
                            max: TransferSearchFilter.maxAgeLimit.toDouble(),
                            divisions: TransferSearchFilter.maxAgeLimit -
                                TransferSearchFilter.minAgeLimit,
                            onChanged: (r) => setSheet(() {
                              f.minAge = r.start.round();
                              f.maxAge = r.end.round();
                            }),
                          ),
                        ),
                        item(
                            Tr.pick('総合(見立て)', 'OVR (est.)'),
                            drop<int>(f.minOverallStars, const [0, 2, 3, 4, 5],
                                stars, (v) => f.minOverallStars = v)),
                        item(
                            Tr.pick('伸びしろ(見立て)', 'POT (est.)'),
                            drop<int>(f.minPotentialStars,
                                const [0, 2, 3, 4, 5], stars,
                                (v) => f.minPotentialStars = v)),
                        item(
                            Tr.pick('市場価値', 'Value'),
                            drop<int>(f.valueCap, const [0, 1, 2],
                                _valueCapLabel, (v) => f.valueCap = v)),
                        item(
                            Tr.pick('年俸', 'Salary'),
                            drop<int>(f.wageCap, const [0, 1, 2],
                                _wageCapLabel, (v) => f.wageCap = v)),
                        item(
                            Tr.pick('契約の残り', 'Contract'),
                            drop<int>(f.contractMax, const [0, 1, 2],
                                _contractLabel, (v) => f.contractMax = v)),
                        item(
                            Tr.pick('国・リーグ', 'Country / league'),
                            drop<String>(
                                f.region ?? '',
                                ['', for (final r in regions) r.key],
                                (k) => k.isEmpty
                                    ? Tr.pick('全部', 'All')
                                    : regions
                                        .firstWhere((r) => r.key == k)
                                        .label,
                                (v) => f.region = v.isEmpty ? null : v)),
                        toggle(
                            Tr.pick('移籍リスト入り(売りに出ている)だけ',
                                'Transfer-listed only'),
                            f.listedOnly,
                            (v) => f.listedOnly = v),
                        toggle(
                            Tr.pick('貸し出し可(先発でない)だけ',
                                'Available for loan (non-starters) only'),
                            f.loanOnly,
                            (v) => f.loanOnly = v),
                        toggle(
                            Tr.pick('スカウトが見ている選手だけ', 'Scouted players only'),
                            f.knownOnly,
                            (v) => f.knownOnly = v),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setSheet(() {
                            f = TransferSearchFilter()..group = f.group;
                          }),
                          child: Text(Tr.pick('全部外す', 'Clear all')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const ValueKey('search-filter-apply'),
                          onPressed: () => Navigator.pop(ctx, f),
                          child: Text(Tr.pick('この条件で探す', 'Search')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (applied == null || !mounted) return;
    setState(() {
      _filter = applied;
      _searchLimit = 40;
    });
  }

  /// 注目(ショートリスト): 注目に入れた選手。窓が閉じているあいだは
  /// この札が先に出る(次の窓へ向けて見ておく)。
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
    final windowOpen = gameState.isTransferWindowOpen;
    final notes = <Widget>[
      if (!windowOpen)
        _TransferWindowBanner(
          open: false,
          label: gameState.transferWindowStatusLabel,
        ),
      if (!windowOpen)
        Padding(
          key: const ValueKey('watch-closed-hint'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Text(
            Tr.pick(
                '窓が閉じているあいだは、気になる選手を注目に入れて見立てを進めておく時期です。注目の選手は毎週${ScoutKnowledge.watchWeeklyGain}%ずつ見えてきます。',
                'While the window is shut, build your shortlist: shortlisted players become ${ScoutKnowledge.watchWeeklyGain}% clearer every week.'),
            style: TextStyle(
                fontSize: 12, color: SemanticColors.subtleText(context)),
          ),
        ),
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
    ];
    if (watched.isEmpty) {
      return Column(
        children: [
          ...notes,
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Tr.pick('注目している選手はいません。監督の補強案や「探す」で星を押すと入ります。',
                          "Your shortlist is empty. Tap the star in the manager's signing picks or in Search to add one."),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _goSearch(),
                      icon: const Icon(Icons.search, size: 18),
                      label: Text(Tr.pick('探す', 'Search')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        ...notes,
        Expanded(
            child: _targetTable(context, gameState, watched, squadFull, same)),
      ],
    );
  }

  /// スカウト: 地域(国と部)にスカウトを送る・替える。地域ごとに、どれだけ
  /// 見つかったかを出す。個別に見させている選手もここに並べる(2026-11-25)。
  Widget _buildScoutTab(
    BuildContext context,
    GameState gameState,
    SaveGame save,
  ) {
    final regions = gameState.scoutRegions;
    final used = save.scoutRegionKeys.length;
    final slots = gameState.scoutSlots;
    final full = used >= slots;
    // 出張費は1年あたりで見せる(1節ごとに払う額 × 1季の節の数)。
    final cost = gameState.scoutTripCostPerWeek * gameState.matchdaysPerSeason;
    final subtle = SemanticColors.subtleText(context);
    final help = Tr.pick(
        '送った地域の選手は、毎週${gameState.scoutWeeklyGain}%ずつ見えてきます(出張費は1か所 年${formatMoney(cost)})。見えているほど、総合力と伸びしろの幅が狭くなります。同じ部の選手は試合で見ているので最初から${ScoutKnowledge.sameLeagueBase}%、所属なしの選手は${ScoutKnowledge.freeAgentBase}%、注目リストの選手はどこにいても毎週${ScoutKnowledge.watchWeeklyGain}%ずつ見えてきます。送れる場所の数と見えてくる速さは、スカウトの見極めの力で決まります。\n\n「見つけた」は、監督が補強の案に挙げられるくらい(${ScoutKnowledge.proposalMinimum}%以上)見えている選手の数です。送れる数がいっぱいのときは「替える」で、送っている地域と入れ替えます。\n\n選手を個別に見させることもできます(${GameStateTransfer.scoutPlayerSlots}人まで・地域と同じ速さ・出張費は1か所の半分)。選手の詳しい画面の「操作」から。',
        'Players in the regions you cover become ${gameState.scoutWeeklyGain}% clearer each week (travel costs ${formatMoney(cost)} a year per region). The clearer they are, the narrower the overall and potential ranges. Players in your own division start at ${ScoutKnowledge.sameLeagueBase}% because you see them in matches, free agents at ${ScoutKnowledge.freeAgentBase}%, and shortlisted players anywhere gain ${ScoutKnowledge.watchWeeklyGain}% a week. Your scout\'s judging decides how many regions you can cover and how fast.\n\n"Found" counts players known well enough (${ScoutKnowledge.proposalMinimum}%+) for your manager to put forward. When every slot is taken, use "Swap" to replace a region you cover.\n\nYou can also have up to ${GameStateTransfer.scoutPlayerSlots} players followed one by one (same speed, half the travel cost) from the Actions button on a player\'s profile.');
    Widget region(({String key, String label, List<Team> teams}) r) {
      final active = gameState.isScoutRegionActive(r.key);
      final size = gameState.regionSize(r.key);
      final found = gameState.regionFoundCount(r.key);
      final Widget secondary = active
          ? IconButton(
              key: ValueKey('scout-search-${r.key}'),
              tooltip: Tr.pick('この地域で探す', 'Search this region'),
              icon: const Icon(Icons.search),
              onPressed: () => _goSearch((f) => f.region = r.key),
            )
          : full
              ? TextButton(
                  key: ValueKey('scout-swap-${r.key}'),
                  onPressed: () => _swapRegion(context, gameState, r.key),
                  child: Text(Tr.pick('替える', 'Swap')),
                )
              : Icon(Icons.public, color: subtle);
      return Card(
        margin: const EdgeInsets.all(3),
        child: SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          secondary: secondary,
          title: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            Tr.pick(
                '${size.clubs}クラブ・${size.players}人・見つけた$found人・平均${gameState.regionKnowledgePercent(r.key)}%見えている${active ? '(送っている)' : ''}',
                '${size.clubs} clubs, ${size.players} players • $found found • ${gameState.regionKnowledgePercent(r.key)}% known${active ? ' (covering)' : ''}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          value: active,
          onChanged: active || !full
              ? (_) {
                  FeedbackService.tap();
                  gameState.toggleScoutRegion(r.key);
                }
              : null,
        ),
      );
    }

    final singles = gameState.scoutedPlayers;
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
                      '送っている地域 $used / $slots か所・出張費は1か所 年${formatMoney(cost)}',
                      'Regions covered: $used of $slots • ${formatMoney(cost)} a year per region'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _HelpButton(
                  title: Tr.pick('スカウトの送り先', 'Scouting regions'), text: help),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 12, 3, 4),
            child: Text(
              Tr.pick(
                  '個別に見させている選手 (${singles.length} / ${GameStateTransfer.scoutPlayerSlots})',
                  'Players followed one by one (${singles.length} of ${GameStateTransfer.scoutPlayerSlots})'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (singles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                Tr.pick('いません。選手の詳しい画面の「操作」から「スカウトに見させる」で入ります。',
                    'None. Use "Have him scouted" from the Actions button on a player\'s profile.'),
                style: TextStyle(fontSize: 12, color: subtle),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.all(3),
              child: Column(
                children: [
                  for (final p in singles)
                    ListTile(
                      key: ValueKey('scouted-${p.id}'),
                      dense: true,
                      leading: PlayerFaceAvatar(
                          playerId: p.id, position: p.position, size: 28),
                      title: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(Tr.pick(
                          '${p.position.label}・${p.age}歳・${gameState.clubNameOf(p.id) ?? '所属なし'}・見え${gameState.knowledgeOf(p)}%',
                          '${p.position.label} • ${p.age} • ${gameState.clubNameOf(p.id) ?? 'Free agent'} • ${gameState.knowledgeOf(p)}% known')),
                      onTap: () => openPlayerDetail(context, p.id),
                      trailing: TextButton(
                        onPressed: () {
                          FeedbackService.tap();
                          gameState.toggleScoutPlayer(p.id);
                        },
                        child: Text(Tr.pick('やめる', 'Stop')),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    });
  }

  /// 送れる数がいっぱいのとき、[newKey]をどの地域と入れ替えるか選ぶ。
  Future<void> _swapRegion(
      BuildContext context, GameState game, String newKey) async {
    final active = [
      for (final r in game.scoutRegions)
        if (game.isScoutRegionActive(r.key)) r
    ];
    final label =
        game.scoutRegions.firstWhere((r) => r.key == newKey).label;
    final old = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(Tr.pick('$labelへ替える地域', 'Swap which region for $label?')),
        children: [
          for (final r in active)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r.key),
              child: Text(Tr.pick(
                  '${r.label}(見つけた${game.regionFoundCount(r.key)}人)を引き上げる',
                  'Pull out of ${r.label} (${game.regionFoundCount(r.key)} found)')),
            ),
        ],
      ),
    );
    if (old == null) return;
    final ok = await game.replaceScoutRegion(old, newKey);
    ok ? FeedbackService.tap() : FeedbackService.error();
  }

  /// 系列クラブ: 提携の相手と、その選手(2割引・貸し出しの相手)。
  /// 2026-11-25 にクラブの施設から移した(作り込みは第6段)。
  Widget _buildAffiliateTab(BuildContext context, GameState gameState,
      bool squadFull, Set<String> same) {
    final club = gameState.affiliateClub;
    final players = club == null
        ? const <Player>[]
        : [
            for (final p in club.players)
              if (gameState.transferTargets.any((q) => q.id == p.id)) p
          ];
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 640;
      final card = const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(9, 4, 9, 12),
        child: AffiliateCard(),
      );
      final list = club == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  Tr.pick('提携すると、ここに系列クラブの選手が並びます(言い値2割引・押すと詳しい画面)。',
                      'Once you have a feeder club, its players appear here (20% off; tap for the profile).'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.subtleText(context)),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: Text(
                    Tr.pick('${club.name}の選手(言い値2割引)',
                        '${club.name} players (20% off)'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                    child: _targetTable(
                        context, gameState, players, squadFull, same)),
              ],
            );
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 300, child: card),
            const VerticalDivider(width: 1),
            Expanded(child: list),
          ],
        );
      }
      return Column(
        children: [
          card,
          Expanded(child: list),
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
        TransferSortOption.overall => Tr.pick('総合(見立て)が高い順', 'Best overall (est.)'),
        TransferSortOption.potential =>
          Tr.pick('伸びしろ(見立て)の順', 'Best potential (est.)'),
        TransferSortOption.marketValue => Tr.pick('安い順', 'Cheapest'),
        TransferSortOption.age => Tr.pick('若い順', 'Youngest'),
        TransferSortOption.contract => Tr.pick('契約が短い順', 'Shortest contract'),
      };

  Widget _buildFreeAgentTab(
    BuildContext context,
    GameState gameState,
    bool squadFull,
    Set<String> same,
  ) {
    final freeAgents = [...gameState.freeAgents];
    // 見立ての真ん中で並べる(所属なしの選手も見立てで見る)。
    final keys = {
      for (final p in freeAgents)
        p.id: ScoutKnowledge.center(gameState.overallEstimate(p))
    };
    freeAgents.sort((a, b) => keys[b.id]!.compareTo(keys[a.id]!));
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
                          ? SemanticColors.ink(context, Colors.orange)
                          : SemanticColors.subtleText(context)),
                ),
              ),
              _HelpButton(
                title: Tr.pick('フリーエージェント', 'Free agents'),
                text: Tr.pick(
                    '移籍金なし・年俸のみで獲得できる選手です。所属が無いので、移籍の窓の外でも取れます。年俸・年数・サイン料を本人と話して決めます。\n\n求める年俸は、前のクラブの額ではなく、能力と経験から自クラブのリーグの水準で決まります。名の知れた選手ほど強気で、季が進んで行き先が決まらないほど下がります。総合と伸びしろはスカウトの見立てです(星3つが自クラブの先発の平均)。',
                    'These players cost no fee, only wages. They have no club, so you can sign them outside the window too. Agree salary, length and signing bonus with the player.\n\nWhat they ask is set by ability and experience at your league\'s level, not by their old deal. Well-known players ask more, and the longer they go unsigned, the less they ask. Overall and potential are your scouts\' estimates (three stars is your starters\' average).'),
              ),
            ],
          ),
        ),
        Expanded(
          child: freeAgents.isEmpty
              ? Center(
                  child: Text(Tr.pick('現在フリーエージェントはいません',
                      'There are no free agents right now')))
              : _targetTable(context, gameState, freeAgents, squadFull, same,
                  free: true),
        ),
      ],
    );
  }

  /// 交渉: クラブとの移籍金の交渉の一覧。
  /// 自分の選手に届いたオファーと、移籍リストに載せている選手(2026-11-23)。
  /// 以前はオファーが状況(ホーム)にしか出ず、移籍の画面を開いても見つからなかった。
  Widget _buildOffersTab(BuildContext context, GameState gameState,
      {bool nested = false}) {
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    final listed = [
      for (final p in gameState.userTeam.players)
        if (p.isTransferListed) p,
    ];
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(text,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        );
    return ListView(
      // 「交渉とオファー」の一覧の中に並べるときは、外の一覧と一緒に送る。
      shrinkWrap: nested,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
      key: const ValueKey('transfer-offers-tab'),
      padding: const EdgeInsets.all(12),
      children: [
        heading(Tr.pick('届いたオファー', 'Offers received')),
        if (gameState.incomingOffers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              Tr.pick('いま届いているオファーはありません。選手を移籍リストに載せると、窓のあいだに買い手から届きます。',
                  'No offers right now. Put a player on the transfer list and buyers may bid while the window is open.'),
              style: small,
            ),
          )
        else ...[
          if (!gameState.isTransferWindowOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(
                Tr.pick('移籍の窓が閉じているあいだは承諾できません。',
                    'You cannot accept while the window is shut.'),
                style: small,
              ),
            ),
          const IncomingOffersCard(showTitle: false),
        ],
        heading(Tr.pick('移籍リストに載せている選手 (${listed.length})',
            'On the transfer list (${listed.length})')),
        if (listed.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              Tr.pick('載せている選手はいません。選手の詳しい画面の「操作」から載せられます。',
                  'Nobody is listed. List a player from the Actions button on his profile.'),
              style: small,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, p) in listed.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    key: ValueKey('listed-${p.id}'),
                    dense: true,
                    leading: const Icon(Icons.sell_outlined, size: 18),
                    onTap: () => openPlayerDetail(context, p.id),
                    title: Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      Tr.pick(
                          '${p.position.label}・${p.age}歳・相場${formatMoney(p.marketValue)}・オファー${gameState.incomingOffers.where((o) => o.playerId == p.id).length}件',
                          '${p.position.label}, ${p.age}, worth ${formatMoney(p.marketValue)}, ${Tr.plural(gameState.incomingOffers.where((o) => o.playerId == p.id).length, 'offer')}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      key: ValueKey('unlist-${p.id}'),
                      onPressed: () {
                        FeedbackService.tap();
                        gameState.setTransferListed(p.id, false);
                      },
                      child: Text(Tr.pick('リストから外す', 'Take off')),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTalksTab(BuildContext context, GameState gameState,
      {bool nested = false}) {
    final talks = gameState.transferTalks;
    final small =
        TextStyle(fontSize: 12, color: SemanticColors.subtleText(context));
    final buyBacks = gameState.buyBackCandidates;
    if (talks.isEmpty) {
      // 空の交渉から、探す・売りに出ている選手への入口(2026-11-25)。
      return ListView(
        shrinkWrap: nested,
        physics: nested ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(12),
        children: [
          if (buyBacks.isNotEmpty) _buyBackCard(context, gameState, buyBacks),
          Padding(
            key: const ValueKey('talks-empty'),
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              Tr.pick('交渉中の話はありません。選手を押して詳しい画面の「操作」から、または一覧の「獲得」から移籍金を提示できます。',
                  'No talks under way. Bid from Sign in a list, or from Actions on a player\'s profile.'),
              style: small,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('talks-empty-listed'),
                onPressed: () => _goSearch((f) => f.listedOnly = true),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: Text(Tr.pick('移籍リスト入りの選手を見る', 'See transfer-listed players')),
              ),
              OutlinedButton.icon(
                key: const ValueKey('talks-empty-search'),
                onPressed: () => _goSearch(),
                icon: const Icon(Icons.search, size: 18),
                label: Text(Tr.pick('選手を探す', 'Find players')),
              ),
            ],
          ),
        ],
      );
    }
    return ListView(
      // 「交渉とオファー」の一覧の中に並べるときは、外の一覧と一緒に送る。
      shrinkWrap: nested,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
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
            // 窓が閉じているあいだは「買い戻す」が押せない。行ごとではなく
            // 見出しの下に1回だけ出す。
            if (!gameState.isTransferWindowOpen)
              DisabledReason(gameState.transferWindowStatusLabel,
                  key: const ValueKey('buy-back-blocked')),
            for (final p in players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => openPlayerDetail(context, p.id),
                title: Text(p.name),
                subtitle: Text(Tr.pick(
                    '${gameState.clubNameOf(p.id) ?? '-'}・${formatMoney(gameState.buyBackClauses[p.id]![0])}で${gameState.buyBackClauses[p.id]![1]}年6月まで',
                    '${gameState.clubNameOf(p.id) ?? '-'}: ${formatMoney(gameState.buyBackClauses[p.id]![0])} until June ${gameState.buyBackClauses[p.id]![1]}')),
                trailing: FilledButton(
                  onPressed: gameState.isTransferWindowOpen
                      ? () => runAcquire(context,
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
        ? (t.installmentYears > 0
            ? Tr.pick('分割${t.installmentYears}年', '${t.installmentYears}-year instalments')
            : Tr.pick('分割', 'instalments'))
        : Tr.pick('一括', 'up front');
    // こちらが付けた中身(出来高・上乗せ・交換)。
    final extras = [
      if (t.addOn > 0)
        Tr.pick('出来高${formatMoney(t.addOn)}', '${formatMoney(t.addOn)} add-on'),
      if (t.offeredSellOn > 0)
        Tr.pick('上乗せ${t.offeredSellOn}%', '${t.offeredSellOn}% sell-on'),
      if (t.exchangePlayerName != null)
        Tr.pick('交換: ${t.exchangePlayerName}', 'plus ${t.exchangePlayerName}'),
    ];
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
        OutlinedButton(
          onPressed: player != null && t.round < TransferTalkEngine.maxRounds
              ? () => openTransferBid(context, player, talk: t)
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
              player == null ? null : () => openPersonalTerms(context, player),
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
              key: ValueKey('talk-${t.playerId}'),
              onTap: player == null
                  ? null
                  : () => openPlayerDetail(context, player.id),
              leading: player == null
                  ? null
                  : PlayerFaceAvatar(
                      playerId: player.id, position: player.position),
              title: Text(Tr.pick('${t.playerName}(${t.clubName})',
                  '${t.playerName} (${t.clubName})')),
              subtitle: Text(extras.isEmpty
                  ? status
                  : '$status\n${extras.join(Tr.pick('・', ', '))}'),
            ),
            if (t.hasRival && t.isOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  Tr.pick(
                      '競合: ${t.rivalClubName}が年俸${formatMoney(annualFromWeekly(t.rivalWage))}で誘っている。${md(t.rivalDecidesOn)}ごろまでに契約しないと、選手はあちらへ行く',
                      'Rival: ${t.rivalClubName} offer ${formatMoney(annualFromWeekly(t.rivalWage))} a year. Sign him by about ${md(t.rivalDecidesOn)} or he goes there'),
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          SemanticColors.ink(context, Colors.orange.shade800)),
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
            // 提示の回数を使い切ると「出し直す」が押せない。
            if (t.stage == TransferTalkStage.countered &&
                t.round >= TransferTalkEngine.maxRounds)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: DisabledReason(
                  Tr.pick(
                      '提示は${TransferTalkEngine.maxRounds}回までです。対案をのむか、取り下げてください',
                      'You have used all ${TransferTalkEngine.maxRounds} bids. Accept their terms or withdraw'),
                  alignEnd: true,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
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
            ? SemanticColors.ink(context, Colors.green.shade700)
            : SemanticColors.ink(context, Colors.grey.shade700);
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
            content: SingleChildScrollView(child: Text(text)),
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
        style: TextStyle(
            color: SemanticColors.ink(context, Colors.orange), fontSize: 12),
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
    if (!gameState.registrationOverLimit) return const SizedBox.shrink();
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
                  '22歳以上は${SquadRegistration.seniorLimit}人まで(国外で育った選手は${gameState.registrationRules.nonHomegrownLimit}人まで${gameState.registrationRules.nonEuLimit == null ? '' : '・EU 外の国籍は${gameState.registrationRules.nonEuLimit}人まで'})です。'
                      '${deadline == null ? '締切' : TransferWindowCalendar.formatMonthDay(deadline)}に次の選手が名簿から外れ、次の窓まで公式戦に出られません: '
                      '${planned.map((p) => p.name).join('、')}',
                  'Only ${SquadRegistration.seniorLimit} players aged 22 or over may be registered (${gameState.registrationRules.nonHomegrownLimit} trained abroad${gameState.registrationRules.nonEuLimit == null ? '' : ', ${gameState.registrationRules.nonEuLimit} non-EU'}). '
                      'At the deadline${deadline == null ? '' : ' (${TransferWindowCalendar.formatMonthDay(deadline)})'} these players drop off the list and cannot play until the next window: '
                      '${planned.map((p) => p.name).join(', ')}'),
              style: const TextStyle(fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
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
          color: watched
              ? SemanticColors.ink(context, Colors.amber, min: 3)
              : null),
      tooltip: watched
          ? Tr.pick('注目から外す', 'Remove from shortlist')
          : Tr.pick('注目に入れる', 'Add to shortlist'),
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
            'SD(${sd.name})に補強を任せる', 'Let your DoF (${sd.name}) run signings')),
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
                'SDは、見えている選手のうち方針に合い、今の先発より上の選手を探して、クラブとも選手とも交渉します。上限を超える値なら降ります。位置を選ばなければ全部の位置から探します。下の候補は監督が挙げたもので、任せていても変わらずに出ます。',
                'Your DoF looks for players you have scouted who fit the brief and beat your current starters, then negotiates with the club and the player. He walks away if the price passes your limit. Pick no position to search them all. The candidates below come from your manager and stay there either way.'),
            style: small,
          ),
        ],
      ),
    );
  }
}
