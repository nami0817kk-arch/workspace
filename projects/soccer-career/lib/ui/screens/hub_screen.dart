import 'package:flutter/material.dart';

import '../../models/attributes.dart';
import '../../models/role.dart';
import '../../game/eligibility.dart';
import '../../game/dependencies.dart';
import '../../game/formulas.dart';
import '../../game/knacks.dart';
import '../../game/match_brief.dart';
import '../../game/promises.dart';
import '../../models/promise.dart';
import '../../game/world.dart';
import '../../models/career.dart';
import '../../models/club.dart';
import '../../models/personality.dart';
import '../../models/objective.dart';
import '../../models/competition.dart';
import '../../models/cup.dart';
import '../../game/match_engine.dart';
import '../../game/newsroom.dart';
import '../../game/person.dart';
import '../../game/ranking.dart';
import '../../game/squads.dart';
import '../../game/weekly_plan.dart';
import '../../models/development.dart';
import '../../models/news.dart';
import '../../models/reputation.dart';
import '../../models/entourage.dart';
import '../../models/life.dart';
import '../../models/support.dart';
import '../../models/training.dart';
import '../../models/season.dart';
import '../../state/career_controller.dart';
import '../club_identity.dart';
import '../budget_lines.dart';
import '../fixture_banner.dart';
import '../stat_tile.dart';
import '../../game/impact.dart';
import '../attribute_shape.dart';
import '../player_banner.dart';
import '../readable_width.dart';
import '../../models/traits.dart';
import '../trait_row.dart';
import '../training_sheet.dart';
import '../transfer_code.dart';
import '../../dev/admin.dart';
import '../../feedback/review_prompt.dart';
import '../../l10n/lang.dart';
import '../../monetize/monetization.dart';
import 'admin_screen.dart';
import 'guide_screen.dart';
import 'hall_screen.dart';
import 'match_screen.dart';
import 'season_end_screen.dart';
import 'support_screen.dart';

/// キャリアの拠点。次の試合・練習・成績・順位表・これまでの記録をここから見る。
class HubScreen extends StatelessWidget {
  const HubScreen({
    super.key,
    required this.controller,
    this.monetization,
    this.reviewPrompt,
    this.language,
  });

  final CareerController controller;

  /// 広告と課金。**渡されなければ何も出さない**（テストと、まだ
  /// 初期化が終わっていない起動直後）。
  final Monetization? monetization;

  /// 星を頼む窓口。渡されなければ頼まない。
  final ReviewPrompt? reviewPrompt;

  /// 画面の言葉。**渡されなければ切り替えを出さない**（テストと撮影）。
  final Language? language;

  /// 言葉を選ぶ。**その言語自身の呼び名で並べる**（`Lang.label`）——
  /// 英語しか読めない人に「日本語」と漢字で出しても選べない。
  Future<void> _chooseLanguage(BuildContext context) async {
    final lang = language;
    if (lang == null) return;
    final picked = await showDialog<Lang>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('言語 / Language', 'Language')),
        children: [
          for (final l in Lang.values)
            ListTile(
              title: Text(l.label),
              trailing: l == lang.value
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(l),
            ),
        ],
      ),
    );
    if (picked != null) await lang.set(picked);
  }

  Future<void> _playNext(BuildContext context) async {
    // カップ戦の週なら、そちらへ。1週1試合の刻みは変えない。
    if (controller.state?.isCupWeek ?? false) {
      controller.startCupMatch();
    } else {
      controller.startNextMatch();
    }
    if (controller.currentMatch == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MatchScreen(controller: controller)),
    );
  }

  Future<void> _simulateOne(BuildContext context) async {
    final result = await controller.simulateMatch();
    if (result == null || !context.mounted) return;
    final week = controller.lastWeek;
    final label = result.won ? tr('勝利', 'Win') : (result.drawn ? tr('引き分け', 'Draw') : tr('敗戦', 'Loss'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr('$label ${result.scoreLine} vs ${result.opponentName}'
            '${result.rating != null ? '  評価 ${result.rating!.toStringAsFixed(1)}' : ''}'
            '${week.newInjury != null ? '  負傷: ${week.newInjury!.name}' : ''}', '$label ${result.scoreLine} vs ${result.opponentName}${result.rating != null ? '  rating ${result.rating!.toStringAsFixed(1)}' : ''}${week.newInjury != null ? '  injury: ${week.newInjury!.name}' : ''}'),
          ),
        ),
      );
  }

  Future<void> _simulateUntilEvent(BuildContext context) async {
    final report = await controller.simulateUntilEvent();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _SimReportDialog(report: report),
    );
  }

  Future<void> _endSeason(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SeasonEndScreen(controller: controller, monetization: monetization),
      ),
    );
    final state = controller.state;

    // **星を頼む季は、広告を譲る。**
    //
    // 広告も星の依頼も、置き場は1シーズンの切れ目しかない。以前は
    // 「広告を出した回は星を見送る」だけにしていたが、広告は毎季出るので
    // **星の依頼がほぼ永久に順番待ちになっていた**——公開から5週で
    // 累計1,000ダウンロードを超えて、付いた星は8件（0.6%）だった。
    // ダイアログが出ていれば 2〜5% は付く帯で、星はストアの順位に効く
    // （競合の中央値が26しかない「サッカー 育成」で35位に沈んでいた）。
    //
    // どちらかを譲るしかないが、**広告は1キャリアに約18.6回、星を頼むのは
    // 1回だけ**。譲っても失うのは1人あたり広告1回で、週あたり50〜60円ほど。
    final asking = state != null && (reviewPrompt?.wantsToAsk(state) ?? false);

    // **広告はシーズンの画面を閉じたあと。** 画面の中に挟むと、契約を
    // 選んでいる途中で割り込むことになる。ここなら1シーズンの区切りそのもの。
    // 出すかどうかは `Monetization` が決める（買った人・序盤・連発は出ない）。
    final adShown = asking
        ? false
        : await monetization?.showSeasonAd(
                seasonsPlayed: state?.history.length ?? 0,
              ) ??
              false;

    // **星を頼むのもここ。** 上で広告を譲っているので `adShown` は false。
    // それでも渡しているのは、広告が出た回に頼まない、という決まりを
    // `ReviewPrompt` の側に残しておくため。
    if (state != null) {
      await reviewPrompt?.askIfEarned(state: state, adShown: adShown);
    }
  }

  void _openSupport(BuildContext context) {
    final money = monetization;
    if (money == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportScreen(monetization: money),
      ),
    );
  }

  /// 遊び方のガイドを開く。仕組みが多いので、1か所にまとめてある。
  void _openGuide(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GuideScreen()));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('キャリアを削除しますか', 'Delete this career?')),
        content: Text(tr('この選手の記録はすべて消えます。元に戻せません。', 'Everything about this player is erased. It cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('やめる', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('削除する', 'Delete')),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteCareer();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state!;
    final stats = state.seasonStats;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('${state.player.name}  ${state.year}シーズン', '${state.player.name}  ${state.year}')),
          actions: [
            IconButton(
              onPressed: () => _openGuide(context),
              icon: const Icon(Icons.help_outline),
              tooltip: tr('遊び方', 'How to play'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    TransferCode.show(context, controller);
                  case 'import':
                    TransferCode.import(context, controller);
                  case 'hall':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HallScreen(controller: controller),
                      ),
                    );
                  case 'delete':
                    _confirmDelete(context);
                  case 'support':
                    _openSupport(context);
                  case 'lang':
                    _chooseLanguage(context);
                  // 参照そのものを kAdmin で囲む。メニュー項目だけを囲んでも、
                  // ここが AdminScreen を名指ししているぶん画面が残ってしまう
                  // （公開ビルドに管理画面の文字列が入っていた）。
                  case 'admin' when kAdmin:
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminScreen(controller: controller),
                      ),
                    );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'export', child: Text(tr('引き継ぎコードを出す', 'Show the transfer code'))),
                PopupMenuItem(value: 'import', child: Text(tr('セーブを読み込む', 'Load save'))),
                PopupMenuItem(value: 'hall', child: Text(tr('これまでの選手', 'Players so far'))),
                PopupMenuItem(value: 'delete', child: Text(tr('キャリアを削除', 'Delete career'))),
                if (language != null)
                  PopupMenuItem(
                    value: 'lang',
                    child: Text(tr('言語 / Language', 'Language')),
                  ),
                // 広告も課金もない環境（ブラウザ版・テスト）では出さない。
                if (monetization != null)
                  PopupMenuItem(value: 'support', child: Text(tr('広告について', 'Ads and purchases'))),
                // 管理画面は公開ビルドに入らない（kAdmin は const false）。
                if (kAdmin)
                  PopupMenuItem(value: 'admin', child: Text(tr('管理', 'Admin'))),
              ],
            ),
          ],
          // タブも本文と同じ幅に収める。広い画面で5つが端まで散ると、
          // 隣のタブへ移るのに画面を横断することになる。
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: ReadableWidth(
              child: TabBar(
                labelPadding: EdgeInsets.symmetric(horizontal: 2),
                tabs: [
                  Tab(text: tr('今週', 'Week')),
                  Tab(text: tr('選手', 'Player')),
                  Tab(text: tr('育成', 'Training')),
                  Tab(text: tr('クラブ', 'Club')),
                  Tab(text: tr('記録', 'Record')),
                ],
              ),
            ),
          ),
        ),
        // 一番よく押すものは、どのタブに居ても手の届く場所に置く。
        // 以前は画面を6つ分スクロールしないと試合に入れなかった。
        // ただし今週タブには同じボタンがカードの中にあるので、そこでは出さない。
        // 出すと「区切りまで」など下の操作に被さる。
        floatingActionButton: Builder(
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabs,
              builder: (context, _) => tabs.index == 0 && !state.seasonFinished
                  ? const SizedBox.shrink()
                  : _PrimaryAction(
                      state: state,
                      onPlay: () => _playNext(context),
                      onEndSeason: () => _endSeason(context),
                    ),
            );
          },
        ),
        // 5つのタブをまとめて読める幅に収める。
        body: ReadableWidth(
          child: TabBarView(
            children: [
              _MatchTab(
                controller: controller,
                state: state,
                stats: stats,
                onPlay: () => _playNext(context),
                onSimulate: () => _simulateOne(context),
                onSimulateUntilEvent: () => _simulateUntilEvent(context),
                onSimStyle: controller.setSimStyle,
                onEndSeason: () => _endSeason(context),
              ),
              _PlayerTab(state: state, controller: controller),
              _TrainingTab(state: state, controller: controller),
              _ClubTab(state: state, controller: controller),
              _CareerTab(state: state, stats: stats, controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

/// どのタブからでも押せる、今いちばんやること。
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.state,
    required this.onPlay,
    required this.onEndSeason,
  });

  final CareerState state;
  final VoidCallback onPlay;
  final VoidCallback onEndSeason;

  @override
  Widget build(BuildContext context) {
    if (state.seasonFinished) {
      return FloatingActionButton.extended(
        onPressed: onEndSeason,
        icon: const Icon(Icons.flag_outlined),
        label: Text(tr('シーズンを終える', 'End the season')),
      );
    }
    final out = state.injured || state.suspended;
    final cup = state.pendingCup;
    final label = cup != null
        ? (out ? tr('${cup.kind.label}を欠場', 'Sit out the ${cup.kind.label}') : tr('${cup.kind.label}へ', 'Into the ${cup.kind.label}'))
        : state.pendingInternational
        ? (state.calledUp && !out ? tr('代表戦へ', 'Into the international') : tr('代表ウィークを飛ばす', 'Skip the international week'))
        : state.suspended
        ? tr('出場停止で欠場', 'Suspended, so you sit out')
        : state.injured
        ? tr('欠場する', 'Sit it out')
        : tr('試合へ', 'Into the match');
    return FloatingActionButton.extended(
      onPressed: onPlay,
      icon: Icon(
        state.suspended
            ? Icons.block
            : state.injured
            ? Icons.healing_outlined
            : Icons.sports_soccer_outlined,
      ),
      label: Text(label),
    );
  }
}

/// 次の試合と、今の状態。開いてすぐ「今どうなっていて、次に何をするか」が分かる。
class _MatchTab extends StatelessWidget {
  const _MatchTab({
    required this.controller,
    required this.state,
    required this.stats,
    required this.onPlay,
    required this.onSimulate,
    required this.onSimulateUntilEvent,
    required this.onSimStyle,
    required this.onEndSeason,
  });

  final CareerController controller;
  final CareerState state;
  final SeasonStats stats;
  final VoidCallback onPlay;
  final VoidCallback onSimulate;
  final VoidCallback onSimulateUntilEvent;
  final Future<void> Function(SimStyle) onSimStyle;
  final VoidCallback onEndSeason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finished = state.seasonFinished;

    return ListView(
      // タブを行き来してもスクロール位置が戻らないように。
      // 鍵が無いと TabBarView が画面外のタブを捨てるので、育成タブで
      // 下まで見て今週タブへ戻り、また育成へ行くと先頭に戻されていた。
      key: const PageStorageKey('tab-match'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // 答えを待っているものが先。埋もれると、そのまま忘れられる。
        if (controller.pendingEvent != null) ...[
          _EventCard(controller: controller),
          const SizedBox(height: 16),
        ],
        if (!state.squadStatus.canPlay) ...[
          _OutOfSquadCard(state: state),
          const SizedBox(height: 16),
        ],
        if (state.injured) ...[
          _InjuryCard(state: state, controller: controller),
          const SizedBox(height: 16),
        ],
        // まだ1試合もしていないうちだけ、次にやることを1行で出す。
        if (state.results.isEmpty && state.history.isEmpty) ...[
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('はじめに', 'To begin'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    // 数字は実装から引く。「3つの局面」と書いたまま
                    // 2〜6局面に変わっていて、最初に読む文が嘘になっていた。
                    // 3行に収める。1行増えるだけで「今の状態」が画面の外に出る。
                    tr('下の「試合へ」で試合に入り、局面ごとに3つの手から選ぶ'
                    '（ふつう${Formulas.scenariosPerStart}局面、'
                    'じっくりやる試合は${Formulas.scenariosPerBigStart}局面）。'
                    '練習はすぐ上の「変える」から。', 'Tap Into the match below, and pick one of three moves at each moment (${Formulas.scenariosPerStart} moments usually, ${Formulas.scenariosPerBigStart} in a game that matters). Training is under Change, just above.'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (finished)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('全${state.fixtures.length}節を戦い終えた', 'All ${state.fixtures.length} rounds are played'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('${state.club.name}  ${state.leaguePosition}位', '${state.club.name}  #${state.leaguePosition}'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onEndSeason,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(tr('シーズンを終える', 'End the season')),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _NextMatchCard(
            state: state,
            stake: controller.stake,
            outlook: controller.outlook,
            onOpenTraining: () => TrainingSheet.show(context, controller),
            onPlay: onPlay,
            onSimulate: onSimulate,
            onSimulateUntilEvent: onSimulateUntilEvent,
            onSimStyle: onSimStyle,
          ),
        const SizedBox(height: 16),
        // **決める → 状態 → 起きたこと、の順に置く。**
        // 以前は「最近の話題」（読むだけのもの）が「今の状態」より上に
        // あった。休むか押すかを決める材料が、読み物の下に埋もれていた。
        _StatusCard(state: state, injuryChance: controller.injuryChanceNow),
        const SizedBox(height: 16),
        if (controller.news.isNotEmpty) ...[
          _NewsCard(news: controller.news.take(3).toList()),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// 次の相手と、自動で進める手段。
class _NextMatchCard extends StatelessWidget {
  const _NextMatchCard({
    required this.state,
    required this.stake,
    required this.outlook,
    required this.onOpenTraining,
    required this.onPlay,
    required this.onSimulate,
    required this.onSimulateUntilEvent,
    required this.onSimStyle,
  });

  final CareerState state;

  /// その試合が持つ意味（ダービー・首位攻防など）。
  final FixtureStake stake;

  /// 次節の起用の見通し。落ちた理由が分からないまま数試合過ぎるのが一番きつい。
  final SelectionOutlook? outlook;

  /// 育成タブを開く。今週の練習を変えるため。
  final VoidCallback onOpenTraining;

  final VoidCallback onPlay;
  final VoidCallback onSimulate;
  final VoidCallback onSimulateUntilEvent;
  final Future<void> Function(SimStyle) onSimStyle;

  /// 今日の意味を1枚に。行が無ければ何も足さない。
  List<Widget> _brief(BuildContext context) {
    final theme = Theme.of(context);
    final lines = MatchBrief.of(state);
    if (lines.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      // **灰色のベタ塗りの表をやめる。** 白い紙の上に一段暗い板を置くと、
      // そこだけ「あとから貼った表」に見える——画面で一番安っぽい部品だった。
      // 見出しは小さく字間を開けて、値は本文の濃さで。区切りは細い線1本。
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0)
          Divider(
            height: 9,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              // 日本語は「チーム」の4文字、英語は Opponent の8文字が一番長い。
              width: pick(52.0, 66.0),
              child: Text(
                lines[i].label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                lines[i].text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: lines[i].urgent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: lines[i].urgent ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 2),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final total = state.fixtures.length;

    // **対戦カードは、カードの上端いっぱいに敷く。**
    // 余白の内側に置いていた頃は、紙の上に貼った帯に見えていた
    // （上下に白い隙間が残る）。角まで流し込むと、カードそのものが
    // 「その試合のカード」になる。ついでに上の余白 16px が浮く。
    //
    // **今日はじっくりやる試合か。** 局面の数がここで変わるので、
    // 入る前に分かるようにしておく。**行は増やさない**——
    // 次節カードが1行伸びるだけで、スマホの高さでは
    // 「今の状態」が画面の外に出る（実際に出た）。
    final fixture = state.pendingCup == null && !state.pendingInternational
        ? FixtureBanner(
            club: state.club,
            opponent: state.opponentFor(state.matchday),
            home: state.isHome(state.matchday),
            centre: Text(
              tr('第${state.matchday}節', 'Round ${state.matchday}'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14140F),
                height: 1,
              ),
            ),
            caption:
                tr('${state.isHome(state.matchday) ? 'ホーム' : 'アウェイ'}'
                ' ・ ${state.matchday} / $total'
                '${Newsroom.isBigFixture(state) ? '\nじっくりやる試合' : ''}', '${state.isHome(state.matchday) ? 'Home' : 'Away'} - ${state.matchday} / $total${Newsroom.isBigFixture(state) ? '\na game that matters' : ''}'),
            progress: (state.matchday - 1) / total,
          )
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?fixture,
          Padding(
            padding: EdgeInsets.fromLTRB(16, fixture != null ? 12 : 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fixture == null) ...[
                  Text(
                    tr('${state.pendingCup != null ? state.pendingCup!.label : '代表ウィーク'}'
                    '${Newsroom.isBigFixture(state) ? '  ・  じっくりやる試合' : ''}', '${state.pendingCup != null ? state.pendingCup!.label : 'International week'}${Newsroom.isBigFixture(state) ? '  -  a game that matters' : ''}'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.pendingCup != null
                        ? tr('${state.pendingCup!.round.neutral
                                  ? "中立地"
                                  : state.pendingCup!.home
                                  ? "ホーム"
                                  : "アウェイ"}  '
                              'vs ${state.pendingCup!.opponentName}', '${state.pendingCup!.round.neutral ? "Neutral ground" : state.pendingCup!.home ? "Home" : "Away"}  vs ${state.pendingCup!.opponentName}')
                        : (state.calledUp && !state.injured
                              ? tr('代表に招集された', 'You have been called up')
                              : tr('招集は無かった', 'No call-up came')),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
                // 2戦合計の第2戦は、第1戦の結果を背負っている。
                if (state.pendingCup?.carriesAggregate ?? false)
                  Text(
                    tr('第1戦は ${state.pendingCup!.aggregateFor}-'
                    '${state.pendingCup!.aggregateAgainst}。'
                    '${state.pendingCup!.aggregateMargin > 0
                        ? "リードして迎える"
                        : state.pendingCup!.aggregateMargin < 0
                        ? "追いかける"
                        : "五分"}', 'The first leg was ${state.pendingCup!.aggregateFor}-${state.pendingCup!.aggregateAgainst}. ${state.pendingCup!.aggregateMargin > 0 ? "You go in ahead" : state.pendingCup!.aggregateMargin < 0 ? "You are chasing" : "All square"}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                // 一発勝負。負ければそこで終わる。
                if (state.pendingCup != null &&
                    state.pendingCup!.round != CupRound.group)
                  Text(
                    state.pendingCup!.twoLegged
                        ? tr('2戦合計で決まる。', 'It is settled over two legs.')
                        : tr('負ければそこで終わり。引き分けならPK戦。', 'Lose and it is over. A draw goes to penalties.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (state.suspended || state.yellowCards > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 6),
                        child: Icon(
                          Icons.style,
                          size: 16,
                          color: state.suspended
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          state.suspended
                              ? tr('出場停止。あと${state.suspension}試合は出られない。', 'Suspended. You cannot play for another ${plural(state.suspension, 'game')}.')
                              : tr('今季の警告 ${state.yellowCards}枚。'
                                    '${Formulas.yellowCardsForBan}枚で1試合の出場停止。', '${state.yellowCards} booking${state.yellowCards == 1 ? '' : 's'} this season. Reach ${Formulas.yellowCardsForBan} and you miss a game.'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: state.suspended
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!state.pendingInternational && outlook != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 6),
                        child: Icon(
                          switch (outlook!.likely) {
                            Appearance.start => Icons.check_circle_outline,
                            Appearance.sub => Icons.timelapse,
                            _ => Icons.remove_circle_outline,
                          },
                          size: 16,
                          color: outlook!.likely == Appearance.start
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              outlook!.headline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: outlook!.likely == Appearance.start
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              outlook!.reason,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (!state.pendingInternational && stake.isSpecial) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stake.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          stake.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 今日の1本が何に効くのか。監督・目標・順位・得点王・相手が
                // 4つの画面に散っていたので、試合に入る直前に1枚で見せる。
                ..._brief(context),
                // **見るものと、決めることを分ける。**
                // 1枚に 対戦カード・出場の見通し・今日の意味・今週の練習・
                // 試合へ・自動で進める、の6つを積んでいた。一番押すボタンが
                // 真ん中に埋もれていて、上下に何があるのか読まないと分からない。
                //
                // **カードを2枚に割る案も、見出しを足す案も、高さで諦めた**
                // ——390×844 では2枚で 76px、見出しだけでも 20px 増え、
                // 「今の状態」が画面の外に出る（`ui_test`。この制約に
                // 当たるのは5回目）。**入るのは区切り線1本**（+5px）。
                const SizedBox(height: 8),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                // 練習は毎週決めるものなのに、育成タブを開かないと今の設定が
                // 見えなかった。試合に入る直前に置けば、忘れようがない。
                InkWell(
                  onTap: onOpenTraining,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr('今週の練習', 'Training'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('${state.menu.label}'
                            '${state.menu.isRest ? '' : ' ・ ${state.effort.label}'}'
                            '${state.companion == TrainingCompanion.alone ? '' : ' ・ ${state.companion.label}'}'
                            '${state.drill != null ? '（居残り ${state.drill!.label}）' : ''}', '${state.menu.label}${state.menu.isRest ? '' : ' - ${state.effort.label}'}${state.companion == TrainingCompanion.alone ? '' : ' - ${state.companion.label}'}${state.drill != null ? ' (extra: ${state.drill!.label})' : ''}'),
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.shouldAutoRest(state.player.condition))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              tr('自動で休養', 'Rest, automatically'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          )
                        // 元気なのに休んでいると、その週は何も伸びない。
                        // 実際に遊んで、コンディション100のまま9節「休養」で
                        // 進んでいたのに、どこにもそう書いていなかった。
                        else if (state.restingWhileFresh)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              tr('伸びない', 'Nothing to gain'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        Text(
                          tr('変える', 'Change'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onPlay,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      state.pendingInternational
                          ? (state.calledUp && !state.injured
                                ? tr('代表戦へ', 'Into the international')
                                : tr('代表ウィークを飛ばす', 'Skip the international week'))
                          : state.injured
                          ? tr('欠場する', 'Sit it out')
                          : tr('試合へ', 'Into the match'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(tr('自動で進める', 'Play it out'), style: muted),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in SimStyle.values)
                      Tooltip(
                        message: s.description,
                        child: ChoiceChip(
                          label: Text(s.label),
                          selected: state.simStyle == s,
                          onSelected: (_) => onSimStyle(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSimulate,
                        child: Text(tr('この試合', 'This game')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSimulateUntilEvent,
                        child: Text(tr('区切りまで', 'To the next break')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(tr('負傷・代表ウィーク・シーズン終了で止まる。', 'It stops on an injury, an international week or the end of the season.'), style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 今の状態を1枚に。数字を読まなくても、危ないかどうかが分かるようにする。
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.injuryChance});

  final CareerState state;

  /// 今のまま進めた週に怪我をする確率。判定（`rollInjury`）と同じ式から来る。
  final double injuryChance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = state.player;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('今の状態', 'Where you are'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            // **数字を1行に並べる。** 言葉だけだと、良いのか悪いのかは
            // 分かっても、どれくらいなのかが分からない。
            Row(
              children: [
                _Metric(
                  label: tr('疲労', 'Fatigue'),
                  value: '${state.fatigue.value}',
                  note: state.fatigue.label,
                  fill: state.fatigue.value / 100,
                  line: Formulas.fatigueWarning / 100,
                  warn: state.fatigue.value >= Formulas.fatigueWarning,
                ),
                _Metric(
                  label: tr('気持ち', 'Morale'),
                  value: '${state.morale.value}',
                  note: state.morale.label,
                  fill: state.morale.value / 100,
                  line: Morale.careLine / 100,
                  warn: state.morale.needsCare,
                ),
                _Metric(
                  // **倍率ではなく確率。** 判定と同じ式から引く。
                  label: tr('怪我', 'Injury'),
                  value: '${(injuryChance * 100).toStringAsFixed(1)}%',
                  note: tr('1週あたり', 'per week'),
                  // 目盛りは 0〜10%。普段は 1〜5% に収まる。
                  fill: injuryChance / 0.10,
                  line: Formulas.injuryWarnChance / 0.10,
                  warn: injuryChance >= Formulas.injuryWarnChance,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ConditionBar(condition: player.condition),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.fatigue.value >= Formulas.fatigueWarning)
                  _tag(theme, tr('怪我が重くなりやすい', 'injuries come out heavier'), warn: true),
                // 構想外は、落ちてからでは戻せない。落ちる前に出す。
                if (state.frozenOut)
                  _tag(theme, tr('構想外', 'Out of the plans'), warn: true)
                else if (state.trustAtRisk)
                  _tag(theme, tr('監督の信頼が危うい', 'the manager trust is slipping'), warn: true),
                if (state.form.isActive)
                  _tag(
                    theme,
                    state.form.state.label,
                    good: state.form.state == MomentumState.zone,
                    warn: state.form.state == MomentumState.slump,
                  ),
                if (state.development.inPlateau)
                  _tag(theme, tr('停滞期 あと${state.development.plateau}試合', 'Plateau, ${plural(state.development.plateau, 'game')} to go')),
                // 貯めたまま忘れると、伸びない選手になる。
                if (!state.autoSpend && state.development.totalPoints > 0)
                  _tag(
                    theme,
                    tr('振っていない経験点 ${state.development.totalPoints}点', '${state.development.totalPoints} unspent points'),
                    good: true,
                  ),
                if (state.captain) _tag(theme, tr('キャプテン', 'Captain'), good: true),
                if (state.calledUp) _tag(theme, tr('代表招集', 'Called up'), good: true),
                // 待っている話は、出来事が来るまで気づけないので前に出す。
                if (state.captaincyOffered)
                  _tag(theme, tr('腕章の打診が来ている', 'the armband has been offered'), good: true),
                if (state.sponsorOffer != null)
                  _tag(theme, tr('スポンサーの話が来ている', 'a sponsor has been in touch'), good: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(
    ThemeData theme,
    String label, {
    bool warn = false,
    bool good = false,
  }) {
    final color = warn
        ? theme.colorScheme.errorContainer
        : good
        ? theme.colorScheme.primaryContainer
        : null;
    return Chip(
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// タブの中を、押して切り替える節に割る。
///
/// 縦に積むと画面何枚ぶんにもなるものを、**読む目的ごと**に分ける。
/// 削るのと違って中身は減らないが、一度に見る量が半分になる。
///
/// **二段目のタブバーにはしない**——上のタブと見分けが付かなくなるので、
/// 本文の上に置く札（`SegmentedButton`）にする。
///
/// **選んだ節は `PageStorage` に残す。** `TabBarView` は画面外のタブを
/// 捨てるので、手元の state だけだとタブを往復するたびに1つ目へ戻る
/// （スクロール位置で先に踏んだのと同じ形）。
/// **`identifier` を必ず渡す**——渡さないと一番近い `PageStorageKey` の枠を
/// 読んで、スクロール位置（double）を int として読んで落ちる。
class _Sectioned extends StatefulWidget {
  const _Sectioned({
    required this.storageId,
    required this.labels,
    required this.sections,
  });

  /// `PageStorage` の鍵。タブごとに違うものを渡す。
  final String storageId;
  final List<String> labels;

  /// 節の中身。それぞれ自分の `PageStorageKey` を持つ `ListView`。
  final List<Widget> sections;

  @override
  State<_Sectioned> createState() => _SectionedState();
}

class _SectionedState extends State<_Sectioned> {
  int? _index;

  int get _current => _index ?? 0;

  @override
  void initState() {
    super.initState();
    // build の中ではなくここで読む。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = PageStorage.maybeOf(context)
          ?.readState(context, identifier: widget.storageId);
      if (saved is int && saved != _current && saved < widget.sections.length) {
        setState(() => _index = saved);
      }
    });
  }

  void _select(int value) {
    setState(() => _index = value);
    PageStorage.maybeOf(context)
        ?.writeState(context, value, identifier: widget.storageId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                for (var i = 0; i < widget.labels.length; i++)
                  ButtonSegment(value: i, label: Text(widget.labels[i])),
              ],
              selected: {_current},
              onSelectionChanged: (value) => _select(value.first),
            ),
          ),
        ),
        Expanded(child: widget.sections[_current]),
      ],
    );
  }
}

/// 選手そのもの。能力・身体・積み上げ。
class _PlayerTab extends StatelessWidget {
  const _PlayerTab({required this.state, required this.controller});

  /// 代表の選択と、人となりのために要る。
  final CareerController controller;

  final CareerState state;

  @override
  Widget build(BuildContext context) => _Sectioned(
    storageId: 'section-player',
    labels: [tr('能力', 'Attributes'), tr('人となり', 'The person')],
    sections: [
      ListView(
        key: const PageStorageKey('tab-player'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _LevelCard(state: state),
          const SizedBox(height: 16),
          _PlayerCard(state: state),
          const SizedBox(height: 16),
          _BodyCard(state: state),
        ],
      ),
      ListView(
        key: const PageStorageKey('tab-player-person'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _TraitsCard(state: state),
          const SizedBox(height: 16),
          _DevelopmentCard(state: state),
          const SizedBox(height: 16),
          // **「人となり」は自分のこと。** 性格・監督との信頼・ロッカールーム・
          // 称号・代表の選択が入っているのに、クラブタブに置いてあった。
          // クラブタブは所属先と世界の話に絞る。
          _PersonCard(state: state, controller: controller),
        ],
      ),
    ],
  );
}

/// 育て方を決める場所。練習・居残り・自分への投資。
class _TrainingTab extends StatelessWidget {
  const _TrainingTab({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) => _Sectioned(
    storageId: 'section-training',
    // 見出しで割っていた境目を、そのまま札にした。
    labels: [tr('今週決める', 'Decide this week'), tr('長い目で狙う', 'The long game')],
    sections: [
      ListView(
        key: const PageStorageKey('tab-training'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _WeekPlanCard(state: state, controller: controller),
          const SizedBox(height: 16),
          if (!state.injured) ...[
            _TrainingCard(state: state, controller: controller),
            const SizedBox(height: 16),
          ],
          _ExperienceCard(state: state, controller: controller),
        ],
      ),
      ListView(
        key: const PageStorageKey('tab-training-aim'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _FocusCard(state: state, controller: controller),
          const SizedBox(height: 16),
          _SignatureAimCard(state: state, controller: controller),
          const SizedBox(height: 16),
          _KnackCard(state: state, controller: controller),
          const SizedBox(height: 16),
          _TrainingEffectCard(state: state),
          const SizedBox(height: 16),
          _SupportCard(state: state, controller: controller),
        ],
      ),
    ],
  );
}

/// クラブと、その中での立ち位置。
class _ClubTab extends StatelessWidget {
  const _ClubTab({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) => _Sectioned(
    storageId: 'section-club',
    // 見出しで割っていた境目を、そのまま札にした。
    labels: [tr('立ち位置', 'Where you stand'), tr('この国と、世界', 'This country, and the world')],
    sections: [
      ListView(
        key: const PageStorageKey('tab-club'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [_ClubLifeCard(state: state, controller: controller)],
      ),
      ListView(
        key: const PageStorageKey('tab-club-world'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          _LeagueCard(state: state),
          const SizedBox(height: 16),
          _WorldLeagueCard(state: state),
          const SizedBox(height: 16),
          if (state.domesticCup != null || state.continentalCup != null) ...[
            _CupCard(state: state),
            const SizedBox(height: 16),
          ],
          _ScorerCard(state: state),
          const SizedBox(height: 16),
          _TableCard(state: state),
        ],
      ),
    ],
  );
}

/// 役割。同じポジションでも、求められるものが違う。
///
/// 総合力はポジションの重み付き平均なので、**そのポジションが求めないものを
/// 伸ばすほど総合力が下がる**（実測で、中盤の選手を守備一本で育てると
/// ピークが 75.4 → 69.4、代表は 35 → 4 キャップまで落ちた）。
/// 役割は**重みの置き換え**で、上乗せではない。
///
/// **選べるのは今の監督が使うものだけ。** 好きに付け替えられると
/// 「一番高くなる役割を選ぶ」がただの正解になる。
class _RoleSection extends StatelessWidget {
  const _RoleSection({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final player = state.player;
    final choices = controller.roleChoices;
    final manager = state.manager;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr('役割', 'Role'), style: theme.textTheme.labelMedium),
            ),
            Text(
              player.role?.label ?? tr('${player.position.label}の標準', 'standard for a ${player.position.label}'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          choices.isEmpty
              ? tr('${manager?.tactic.label ?? '今の監督'}は、'
                    '${player.position.label}に特別な役割を置いていない。', '${manager?.tactic.label ?? 'The manager'} gives a ${player.position.label} no special role.')
              : tr('就いた役割で総合力の測り方が変わる。'
                    '重く見てもらう代わりに、他は軽く見られる。', 'The role you take changes how your overall is measured. What it weighs heavily, it weighs at the cost of the rest.'),
          style: muted,
        ),
        // **外れたことは必ず書く。** 黙って外すと、総合力だけが下がって
        // 理由が分からない。
        if (controller.roleDropped != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tr('新しい監督は「${controller.roleDropped!.label}」を使わない。'
              '役割が外れた。', 'The new manager does not use ${controller.roleDropped!.label}. You have lost the role.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        if (choices.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final role in choices)
            _RoleRow(
              role: role,
              selected: player.role == role,
              overall: player.attributes.overallFor(
                player.position,
                weights: role.weights,
              ),
              onTap: () =>
                  controller.setRole(player.role == role ? null : role),
            ),
          _RoleRow(
            role: null,
            label: tr('${player.position.label}の標準', 'standard for a ${player.position.label}'),
            note: tr('そのポジションで普通に求められるもの。', 'What the position normally asks for.'),
            selected: player.role == null,
            overall: player.attributes.overallFor(player.position),
            onTap: () => controller.setRole(null),
          ),
        ],
      ],
    );
  }
}

/// 役割1つぶん。**その役割で測ったときの総合力**を先に出す。
class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.selected,
    required this.overall,
    required this.onTap,
    this.label,
    this.note,
  });

  final PlayerRole? role;
  final String? label;
  final String? note;
  final bool selected;
  final int overall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      role?.label ?? label ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(tr('総合力 $overall', 'Overall $overall'), style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                role?.note ?? note ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = state.player;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 選手証。クラブの色を背に敷いて、名前・番号・総合力を大きく出す。
          PlayerBanner(state: state),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('${player.positionLabel}  ${player.age}歳'
                      '（${state.stage.label}） ・ '
                      '${World.byId(player.nationality.primary).demonym}', '${player.positionLabel}  ${player.age} (${state.stage.label}) - ${World.byId(player.nationality.primary).demonym}'),
                      style: muted,
                    ),
                    Text(
                      tr('${state.club.name}'
                      '（${World.byId(state.club.countryId).name} ${state.club.tier}部）', '${state.club.name} (${World.byId(state.club.countryId).name}, tier ${state.club.tier})'),
                      style: muted,
                    ),
                    Text(
                      tr('年俸 ${_yen(state.salary)} ・ 契約 残り${state.contractYears}年', 'Wage ${_yen(state.salary)} - ${plural(state.contractYears, 'year')} left'),
                      style: muted,
                    ),
                    Text(
                      tr('市場価値 ${state.reputation.valueLabel} ・ '
                      '知名度 ${state.reputation.fame}', 'Market value ${state.reputation.valueLabel} - fame ${state.reputation.fame}'),
                      style: muted,
                    ),
                    if (state.onLoan)
                      Text(tr('${state.parentClub!.name}からのローン', 'On loan from ${state.parentClub!.name}'), style: muted),
                    if (state.releaseClause != null)
                      Text(tr('違約金 ${state.releaseClause}万円', 'Release clause JPY ${(state.releaseClause! / 100).toStringAsFixed(1)}M'), style: muted),
                    Text(
                      tr('代理人 ${state.agent.name}'
                      '${state.caps > 0 ? ' ・ 代表 ${state.caps}キャップ ${state.internationalGoals}ゴール' : ''}', 'Agent ${state.agent.name}${state.caps > 0 ? ' - ${plural(state.caps, 'cap')}, ${plural(state.internationalGoals, 'goal')}' : ''}'),
                      style: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(tr('ポテンシャル ${player.potentialBand}', 'Ceiling ${player.potentialBand}')),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (state.tampered)
                      Chip(
                        label: Text(tr('管理画面で変更済み', 'Edited in the admin screen')),
                        backgroundColor: theme.colorScheme.errorContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (player.isInverted)
                      Tooltip(
                        message:
                            tr('逆足のサイド。逆足の局面が増える代わりに、'
                            '内へ切り込んで利き足で打てる。', 'Your weaker foot side. More moments ask for that foot, but you can cut inside and shoot with the good one.'),
                        child: Chip(
                          label: Text(tr('逆サイド', 'Wrong side')),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (state.calledUp)
                      Chip(
                        label: Text(tr('代表招集', 'Called up')),
                        backgroundColor: theme.colorScheme.primaryContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (player.nationality.roots != null)
                      Chip(
                        label: Text(
                          tr('${World.byId(player.nationality.roots!).name}のルーツ', 'Roots in ${World.byId(player.nationality.roots!).name}'),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (player.nationality.naturalized.isNotEmpty)
                      Chip(
                        label: Text(
                          tr('${World.byId(player.nationality.naturalized.last).name}に帰化', 'Naturalised in ${World.byId(player.nationality.naturalized.last).name}'),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    for (final t in player.traits)
                      Tooltip(
                        message: t.description,
                        child: Chip(
                          label: Text(t.label),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _ConditionBar(condition: player.condition),
                const SizedBox(height: 8),
                // 棒だけでは、数字を読まないと選手の形が分からない。
                // 正確な値は棒で読む。この形は輪郭を覚えるためのもの。
                Center(
                  child: AttributeShape(
                    attributes: player.attributes,
                    compareTo: state.seasonStart,
                    keys: [
                      for (final key in AttributeKey.values)
                        if (key != AttributeKey.goalkeeping ||
                            player.position == Position.gk)
                          key,
                    ],
                  ),
                ),
                if (state.seasonStart != null)
                  Center(child: Text(tr('外側の線が今、細い線が開幕時', 'The outer line is now; the thin one is where you started the season'), style: muted)),
                // **尖った1つは、総合力とは別に効いている。**
                // 総合力はポジションの重みで出すので、尖らせるほど下がる。
                // 見えないと「伸ばしたのに総合力が落ちた」だけが残り、
                // 尖らせる遊び方がただの損に見える。
                if (Person.standoutKey(player) != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tr('一芸 ${Person.standoutKey(player)!.label} '
                      '${player.attributes[Person.standoutKey(player)!]}。'
                      '総合力とは別に、値札・代表の線・出場機会に効いている。', 'One standout: ${Person.standoutKey(player)!.label} ${player.attributes[Person.standoutKey(player)!]}. Apart from your overall, it tells on your price, the call-up line and your minutes.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                for (final key in AttributeKey.values)
                  if (key != AttributeKey.goalkeeping ||
                      player.position == Position.gk)
                    _AttributeBar(
                      label: key.label,
                      value: player.attributes[key],
                    ),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    // 畳んだ/開いたの記憶。タブの ListView に PageStorageKey を付けたので、
                    // 鍵の無い ExpansionTile はスクロール位置と同じ枠を読んで落ちる。
                    key: const PageStorageKey('details'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(tr('詳細能力', 'Every attribute'), style: theme.textTheme.bodySmall),
                    children: [
                      for (final key in AttributeKey.values)
                        if (key != AttributeKey.goalkeeping ||
                            player.position == Position.gk)
                          for (final d in key.details)
                            _AttributeBar(
                              label: '  ${d.label}',
                              value: player.attributes.detail(d),
                              thin: true,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _yen(int man) =>
      man >= 10000 ? tr('${(man / 10000).toStringAsFixed(1)}億円', 'JPY ${(man / 100).round()}M') : tr('$man万円', 'JPY ${(man / 100).toStringAsFixed(1)}M');
}

/// **数字ひとつぶん。** 見出し・数字・一言を縦に積む。
///
/// 参考にした野球のキャリアゲームの状態カード
/// （疲労度20 安全圏 / 調子 普通 / 怪我リスク 1%/週）。
/// 言葉だけだと、良いのか悪いのかは分かっても**どれくらいなのか**が分からない。
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.note,
    required this.fill,
    required this.line,
    this.warn = false,
  });

  final String label;
  final String value;
  final String note;
  final bool warn;

  /// 目盛りの中のどこに居るか（0〜1）。
  final double fill;

  /// 悪くなる線がどこにあるか（0〜1）。**判定と同じ線から出す。**
  /// 数字だけだと「70」が近いのか遠いのか分からない——
  /// コンディションにだけ棒があって、他の3つには無かった。
  final double line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warn ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // **数字を、見出しより明らかに大きくする。** 同じ大きさで
          // 並んでいると、どれが読むべき数字なのか決まらない。
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              height: 1.1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 3, bottom: 4),
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      height: 5,
                      width: box.maxWidth * fill.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    // 悪くなる線。**あとどれだけ余裕があるか**は、
                    // 線が引いてあって初めて読める。
                    // **棒の上へ出す**——塗りの中に埋めると、線を越えた側では
                    // 同じ色に沈んで見えなくなる（気持ち59 で実際に消えた）。
                    Positioned(
                      left: (box.maxWidth * line.clamp(0.0, 1.0) - 1).clamp(
                        0.0,
                        box.maxWidth - 2,
                      ),
                      width: 2,
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            note,
            style: theme.textTheme.labelSmall?.copyWith(
              color: warn
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = condition >= 70
        ? theme.colorScheme.primary
        : condition >= 40
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(tr('コンディション', 'Condition'), style: theme.textTheme.bodySmall),
        ),
        SizedBox(
          width: 28,
          child: Text('$condition', style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: GaugeBar(value: condition / 100, height: 12, color: color),
        ),
      ],
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final menus = [
      for (final m in TrainingMenu.values)
        if (m.availableFor(state.player.position)) m,
    ];
    final menu = state.menu;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('今週の練習', 'Training this week'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            // 疲れたまま練習を続けると、伸びないうえに怪我をする。
            // 毎週の操作を忘れても、そこだけは踏み外さないようにする。
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  tr('自動で休養', 'Rest, automatically'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final value in CareerState.autoRestChoices)
                  ChoiceChip(
                    label: Text(value == 0 ? tr('しない', 'Never') : tr('$value未満', 'below $value')),
                    selected: state.autoRestBelow == value,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => controller.setAutoRestBelow(value),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.autoRestBelow == 0
                  ? tr('コンディションが落ちても、選んだ練習をそのまま続ける。', 'Even as your condition drops, you carry on with the training you picked.')
                  : tr('コンディションが${state.autoRestBelow}を下回った週は、'
                        '練習も居残りも止めて休む。', 'Any week your condition falls below ${state.autoRestBelow}, training and extra work stop and you rest.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            // 選んでいるものが何をするメニューなのかを、常に文字で出す。
            // 説明をツールチップに隠すと、スマホでは長押ししないと読めない。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(menu.description, style: muted),
                  const SizedBox(height: 6),
                  Text(
                    menu.isRest
                        ? tr('コンディション +${menu.recovery}', 'Condition +${menu.recovery}')
                        : tr('消耗 ${menu.conditionCost}'
                              '${menu.isCompound ? ' ・ 2か所に触れるが、1か所あたりは伸びにくい' : ''}'
                              '${menu.injuryFactor > 1 ? ' ・ 怪我をしやすい' : ''}', 'Wear ${menu.conditionCost}${menu.isCompound ? ' - touches two areas, but each one grows more slowly' : ''}${menu.injuryFactor > 1 ? ' - more likely to get hurt' : ''}'),
                    style: muted,
                  ),
                  if (state.player.atPotential) ...[
                    const SizedBox(height: 6),
                    Text(
                      tr('ポテンシャルに達している。今は練習しても伸びない。', 'You are at your ceiling. Training will not add anything for now.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _menuGroup(theme, tr('休む', 'Rest'), [
              for (final m in menus)
                if (m.isRest) m,
            ], muted),
            _menuGroup(theme, tr('1か所を鍛える', 'One area'), [
              for (final m in menus)
                if (!m.isRest && !m.isCompound && !m.weakFoot) m,
            ], muted),
            _menuGroup(theme, tr('2か所を同時に', 'Two at once'), [
              for (final m in menus)
                if (m.isCompound) m,
            ], muted),
            _menuGroup(theme, tr('苦手をつぶす', 'Weak spots'), [
              for (final m in menus)
                if (m.weakFoot) m,
            ], muted),
            const Divider(height: 28),
            Text(tr('居残り練習', 'Extra work'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              tr('セットプレーだけを磨く。余分に${Formulas.drillConditionCost}疲れるが、'
              '${SetPieceSkills.takerThreshold}に届けばキッカーを任され、'
              '試合ごとに得点の機会が回ってくる。', 'Set pieces only. It costs ${Formulas.drillConditionCost} more condition, but reach ${SetPieceSkills.takerThreshold} and you take them for the club, which brings a chance at goal every game.'),
              style: muted,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(tr('やらない', 'Skip it')),
                  selected: state.drill == null,
                  onSelected: (_) => controller.setDrill(null),
                ),
                for (final piece in SetPiece.values)
                  ChoiceChip(
                    label: Text(
                      '${piece.label} ${state.player.setPieces[piece]}',
                    ),
                    selected: state.drill == piece,
                    onSelected: (_) => controller.setDrill(piece),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.player.setPieces.isTaker
                  ? tr('クラブの${state.player.setPieces.best.label}キッカーを任されている', 'You take the ${state.player.setPieces.best.label} for the club')
                  : tr('まだキッカーは任されていない', 'You are not on set pieces yet'),
              style: muted?.copyWith(
                color: state.player.setPieces.isTaker
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 種類ごとに小見出しを付けて並べる。12個を一列に並べると選べない。
  Widget _menuGroup(
    ThemeData theme,
    String title,
    List<TrainingMenu> menus,
    TextStyle? muted,
  ) {
    if (menus.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: muted),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in menus)
                ChoiceChip(
                  label: Text(m.label),
                  selected: state.menu == m,
                  onSelected: (_) => controller.setMenu(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 身体データ。伸ばせないが、試合の判定には効いている。
/// 特性が「どこで・いくつ」効くかと、今季に実際に効いた回数。
///
/// 名前のチップだけでは、付いている意味が分からなかった。
/// 文は判定と同じ `Trait.rules` / 各倍率から作るので、数字を変えれば
/// ここも変わる。試合の外で効くものは回数を数えられないので、その旨を書く。
class _TraitsCard extends StatelessWidget {
  const _TraitsCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final traits = state.player.traits;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('特性の効き', 'What your traits do'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(tr('生まれ持ったもの。伸ばせないが、効く場面は決まっている。', 'You were born with these. They cannot be trained, but each has its moments.'), style: muted),
            if (traits.isEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('特性は付いていない。', 'You have no traits.'), style: theme.textTheme.bodyMedium),
            ],
            for (final trait in traits) ...[
              const SizedBox(height: 12),
              TraitRow(trait: trait, hits: state.traitHits[trait] ?? 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _BodyCard extends StatelessWidget {
  const _BodyCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final physique = state.player.physique;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('身体', 'Body'), style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: Text(physique.buildLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(physique.label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            // **文の壁だった。** 「試合での補正: 加速 +3 最高速 +1
            // シュート力 -1 ヘディング -2 敏捷性 +2 …」と9項目が
            // 地の文で折り返していて、**得手と不得手が同じ色で並んでいた**。
            // 身体は「何を買って、何を諦めたか」なので、符号で色を分けて
            // 大きいものから並べる（`Physique.effectValues`）。
            if (physique.effectValues.isEmpty)
              Text(tr('平均的な体格。得手不得手は無い。', 'An average build. Nothing it is good or bad at.'), style: muted)
            else ...[
              Text(tr('試合での補正', 'What it does in a match'), style: muted),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in physique.effectValues)
                    _BonusTag(label: e.$1, value: e.$2),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 自腹のスタッフと生活習慣。稼ぎの使い道を決めるところ。
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  void _hire(BuildContext context, StaffKind kind, int level) {
    final ok = controller.hireStaff(kind, level);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr('貯蓄が足りない', 'not enough saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final staff = state.staff;
    final habits = state.habits;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('自分への投資', 'Investing in yourself'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                BudgetLines(state: state),
              ],
            ),
          ),
          // 普段は畳んでおく。毎週触るものではないのに、開いた瞬間に
          // 20個近い選択肢が並ぶと、練習を選ぶ邪魔にしかならない。
          ExpansionTile(
            // 畳んだ/開いたの記憶。タブの ListView に PageStorageKey を付けたので、
            // 鍵の無い ExpansionTile はスクロール位置と同じ枠を読んで落ちる。
            key: const PageStorageKey('staff'),
            title: Text(tr('専属スタッフ', 'Your own staff')),
            subtitle: Text(
              staff.isEmpty
                  ? tr('誰も雇っていない', 'You have hired nobody')
                  : [
                      for (final kind in StaffKind.values)
                        if (staff[kind] > 0)
                          '${kind.label} ${StaffTeam.levelLabels[staff[kind]]}',
                    ].join(tr(' ・ ', ' - ')),
              style: muted,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final kind in StaffKind.values) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${kind.label}（${kind.description}）',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var level = 0; level <= StaffTeam.maxLevel; level++)
                      ChoiceChip(
                        label: Text(
                          level == 0
                              ? StaffTeam.levelLabels[0]
                              : tr('${StaffTeam.levelLabels[level]} '
                                    '${StaffTeam.costPerLevel[level]}万', '${StaffTeam.levelLabels[level]} JPY ${(StaffTeam.costPerLevel[level] / 100).toStringAsFixed(1)}M'),
                        ),
                        selected: staff[kind] == level,
                        onSelected: (_) => _hire(context, kind, level),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text(
                tr('費用はシーズンの終わりに貯蓄から引かれる。'
                '払えなければ契約は切れる。', 'The cost comes out of your savings at the end of the season. If you cannot pay, they leave.'),
                style: muted,
              ),
              const SizedBox(height: 4),
              // **強くなる金と、残す金は同じ財布**。片方に寄せれば片方は消える。
              Text(
                tr('貯めた金にも行き先がある——'
                '${Formulas.entrepreneurSavings ~/ 10000}億円を残して引退すると、'
                '実業家の道が開く。', 'Money you keep has somewhere to go — retire with JPY ${Formulas.entrepreneurSavings ~/ 100}M put away and the business road opens up.'),
                style: muted,
              ),
              const SizedBox(height: 8),
              BudgetLines(state: state),
            ],
          ),
          ExpansionTile(
            // 畳んだ/開いたの記憶。タブの ListView に PageStorageKey を付けたので、
            // 鍵の無い ExpansionTile はスクロール位置と同じ枠を読んで落ちる。
            key: const PageStorageKey('habits'),
            title: Text(tr('生活習慣', 'How you live')),
            subtitle: Text(
              tr('暮らし ${state.finances.lifestyleLabel} ・ '
              '睡眠 ${habits.sleepLabel} ・ 食事 ${habits.dietLabel}', 'Living ${state.finances.lifestyleLabel} - sleep ${habits.sleepLabel} - food ${habits.dietLabel}'),
              style: muted,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('毎日の積み重ね。効きは小さいが、10年で別の身体になる。', 'Day after day. Each one is small, but ten years of it makes a different body.'), style: muted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('暮らし方', 'Standard of living'), style: theme.textTheme.labelMedium),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                // 生活費は年俸に比例するので、額まで出さないと選べない。
                child: Text(
                  tr('生活費は年俸から出ていく。'
                  '下げれば手取りが増え、上げれば気持ちが少し上向く。', 'Living costs come out of your wage. Live cheaply and you keep more; live well and your mood lifts a little.'),
                  style: muted,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < Finances.lifestyleLabels.length; i++)
                    ChoiceChip(
                      label: Text(
                        tr('${Finances.lifestyleLabels[i]} '
                        '${state.finances.withLifestyle(i).livingCostFor(state.salary)}万', '${Finances.lifestyleLabels[i]} JPY ${(state.finances.withLifestyle(i).livingCostFor(state.salary) / 100).toStringAsFixed(1)}M'),
                      ),
                      selected: state.finances.lifestyle == i,
                      onSelected: (_) => controller.setLifestyle(i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('睡眠', 'Sleep'), style: theme.textTheme.labelMedium),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < Habits.sleepLabels.length; i++)
                    ChoiceChip(
                      label: Text(Habits.sleepLabels[i]),
                      selected: habits.sleep == i,
                      onSelected: (_) =>
                          controller.setHabits(habits.copyWith(sleep: i)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('食事', 'Food'), style: theme.textTheme.labelMedium),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < Habits.dietLabels.length; i++)
                    ChoiceChip(
                      label: Text(Habits.dietLabels[i]),
                      selected: habits.diet == i,
                      onSelected: (_) =>
                          controller.setHabits(habits.copyWith(diet: i)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('管理された食事は生活費が増える。'
                  '整えるほど回復が早く、怪我をしにくい。', 'Eating properly costs more. The better it is, the faster you recover and the less you break down.'),
                  style: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 積み上げてきたもの。経験・型・個人技・停滞期。
class _DevelopmentCard extends StatelessWidget {
  const _DevelopmentCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final dev = state.development;
    // 限界突破に要る回数は特性で変わる。判定と同じ `player` から読む。
    final player = state.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しと札は `Wrap`。`Row` だと、英語で札が長くなった分だけ
            // 横へ溢れる。入るうちは1行のままなので、日本語の見え方は変わらない。
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(tr('積み上げ', 'What you have built up'), style: theme.textTheme.titleSmall),
                Chip(
                  label: Text(dev.identityLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('試合経験 ${dev.experience}'
              '${dev.breakthroughs > 0 ? ' ・ 限界突破 ${dev.breakthroughs}回' : ''}', 'Match experience ${dev.experience}${dev.breakthroughs > 0 ? ' - broke past the ceiling ${plural(dev.breakthroughs, 'time')}' : ''}'),
              style: muted,
            ),
            const SizedBox(height: 4),
            // 追い込んだ週の積み上げ。ここが「週の選択」と「届く高さ」を
            // 繋いでいる唯一の線なので、進み具合を出す。
            Text(
              dev.greatWeeks >= player.breakthroughWeeks
                  ? tr('練習で大成功 ${dev.greatWeeks}回。限界を超える下地はできている', '${dev.greatWeeks} great weeks in training. The ground for breaking past your ceiling is there')
                  : tr('練習で大成功 ${dev.greatWeeks}回'
                        '（限界突破の下地まであと'
                        '${player.breakthroughWeeks - dev.greatWeeks}回）', '${dev.greatWeeks} great weeks in training (${player.breakthroughWeeks - dev.greatWeeks} more to lay the ground for breaking past your ceiling)'),
              style: muted?.copyWith(
                color: dev.greatWeeks >= player.breakthroughWeeks
                    ? theme.colorScheme.primary
                    : null,
              ),
            ),
            if (dev.signatures.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(tr('個人技', 'Tricks'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in dev.signatures)
                    Chip(
                      label: Text(s.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (dev.faced.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                tr('慣れてきた相手: ${dev.faced.entries.where((e) => e.value >= 10).map((e) => e.key.label).join('  ')}', 'Styles you have got used to: ${dev.faced.entries.where((e) => e.value >= 10).map((e) => e.key.label).join('  ')}'),
                style: muted,
              ),
            ],
            if (dev.inPlateau) ...[
              const SizedBox(height: 10),
              Text(
                tr('停滞期。あと${dev.plateau}試合は伸びにくい。', 'A plateau. For another ${plural(dev.plateau, 'game')}, little will stick.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 今週なにをするか。次の相手・監督の期待・体の状態を1か所に集める。
///
/// 練習を決めるのは育成タブなのに、相手はクラブタブ、監督の期待は試合タブに
/// 出ていた。決めるのは1つなので、決める場所に材料を持ってくる。
class _WeekPlanCard extends StatelessWidget {
  const _WeekPlanCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = WeekPlan.of(state);
    final warn =
        plan.focus == WeekFocus.rest || plan.focus == WeekFocus.injured;
    final onColor = warn
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: warn
          ? theme.colorScheme.onErrorContainer
          : theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      color: warn ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconOf(plan.focus), size: 18, color: onColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('今週  ${plan.headline}', 'This week  ${plan.headline}'),
                    style: theme.textTheme.titleSmall?.copyWith(color: onColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(plan.reason, style: muted),
            if (state.injured) ...[
              const SizedBox(height: 4),
              Text(tr('練習はできない。復帰の進め方は「今週」タブで選べる。', 'No training. You choose how to come back on the Week tab.'), style: muted),
            ],
            if (plan.suggested != null && plan.suggested != state.menu) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => controller.setMenu(plan.suggested!),
                  child: Text(tr('${plan.suggested!.label}にする', 'Switch to ${plan.suggested!.label}')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(WeekFocus focus) => switch (focus) {
    WeekFocus.injured => Icons.healing,
    WeekFocus.rest => Icons.bedtime,
    WeekFocus.matchup => Icons.sports_soccer,
    WeekFocus.objective => Icons.flag,
    WeekFocus.steady => Icons.fitness_center,
  };
}

/// クラブでの立ち位置。監督・方針・同僚・環境・同期。
class _ClubLifeCard extends StatelessWidget {
  const _ClubLifeCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  Future<void> _convert(BuildContext context) async {
    final options = state.player.aptitude.usable
        .where((p) => p != state.player.position)
        .toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('今できるコンバートは無い', 'There is nowhere to convert to right now'))));
      return;
    }
    final picked = await showDialog<Position>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('どのポジションで戦うか', 'Which position you play')),
        children: [
          for (final p in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(p),
              child: Text(
                tr('${p.fullName}'
                '（適性 ${state.player.aptitude[p]}  '
                '想定 ${state.player.overallAt(p)}）', '${p.fullName} (aptitude ${state.player.aptitude[p]}, overall there ${state.player.overallAt(p)})'),
              ),
            ),
        ],
      ),
    );
    if (picked != null) controller.convertPosition(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final manager = state.manager;
    final facilities = state.facilitiesWith(
      World.byId(state.club.countryId).prestige,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // クラブの帯。選手証と同じで、どこに居るのかを絵で出す。
              _ClubBand(club: state.club),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('クラブでの立ち位置', 'Where you stand at the club'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    // 移籍市場の窓。計算はしていたのに、どこにも出ていなかった。
                    // 「なぜ今は移籍の話が来ないのか」は、ここで答えるのが自然。
                    const SizedBox(height: 8),
                    Text(controller.transferWindowLabel, style: muted),
                    const SizedBox(height: 4),
                    Text(controller.transferReachLabel, style: muted),
                    if (manager != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr('監督 ${manager.name}'
                        '${manager.fromLegend ? '（あなたが引退させた選手）' : ''}'
                        '（${manager.tactic.label}）', 'Manager ${manager.name}${manager.fromLegend ? ' (a player you retired)' : ''} (${manager.tactic.label})'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        tr('${manager.fitLabel(state.player.attributes, state.player.position)}'
                        ' ・ 在任${manager.tenure + 1}年目', '${manager.fitLabel(state.player.attributes, state.player.position)} - year ${manager.tenure + 1} in charge'),
                        style: muted,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(facilities.label, style: muted),
                    if (state.competitor != null) ...[
                      const SizedBox(height: 10),
                      // **差を数字で出す。** 「自分が上」だけでは、
                      // あと少しなのか大差なのかが分からない。
                      Text(
                        tr('同ポジション: ${state.competitor!.name}'
                        '（${state.competitor!.overall}）'
                        ' ・ 差 ${state.player.overall - state.competitor!.overall >= 0 ? '+' : ''}'
                        '${state.player.overall - state.competitor!.overall}'
                        '${state.player.overall >= state.competitor!.overall ? '（先発の序列で優位）' : '（超えれば先発に近づく）'}', 'Same position: ${state.competitor!.name} (${state.competitor!.overall}) - gap ${state.player.overall - state.competitor!.overall >= 0 ? '+' : ''}${state.player.overall - state.competitor!.overall}${state.player.overall >= state.competitor!.overall ? ' (you are ahead in the pecking order)' : ' (pass them and you close on a start)'}'),
                        style: muted,
                      ),
                    ],
                    // **同じ枠の序列。** 登録メンバーはこの数で決まるので、
                    // 判定と同じ数え方（`Squad.aheadOf`）をそのまま出す。
                    Builder(
                      builder: (context) {
                        final squad = Squad.of(state.club, year: state.year);
                        final ahead = squad.aheadOf(
                          state.player.position,
                          state.player.overall,
                        );
                        final quota = Squad.quotaFor(
                          state.player.position.family,
                        );
                        return Text(
                          tr('同じ枠: ${ahead + 1}番目 / 登録の定員 $quota'
                          '${ahead >= quota ? '（今は登録外）' : ''}', 'Your slot: ${ahead + 1}th / squad quota $quota${ahead >= quota ? ' (left off as it stands)' : ''}'),
                          style: muted,
                        );
                      },
                    ),
                    if (state.partner != null)
                      Text(
                        tr('相方: ${state.partner!.name}  ${state.partner!.synergyLabel}', 'Partner: ${state.partner!.name}  ${state.partner!.synergyLabel}'),
                        style: muted,
                      ),
                    if (state.mentor != null && state.player.age <= 23)
                      Text(
                        tr('メンター: ${state.mentor!.name}'
                        '${state.mentor!.fromLegend ? '（あなたが引退させた選手）' : ''}'
                        '（練習が身になる）', 'Mentor: ${state.mentor!.name}${state.mentor!.fromLegend ? ' (a player you retired)' : ''} (training sticks better)'),
                        style: muted,
                      ),
                    if (state.rival != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        tr('同期 ${state.rival!.name}（${state.rival!.clubName}）'
                        '  通算${state.rival!.goals}ゴール / ${state.rival!.caps}キャップ', 'Of your year: ${state.rival!.name} (${state.rival!.clubName})  ${plural(state.rival!.goals, 'goal')} / ${plural(state.rival!.caps, 'cap')}'),
                        style: muted?.copyWith(
                          color: state.rival!.leads(state.player.overall)
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // **見るものと、伝えることを分ける。**
        // 1枚に 帯・立ち位置・移籍の窓・届く先・監督・環境・同僚・方針・
        // ポジション変更、の9つを積んでいた。**そのうち押せるのは下の2つだけ**で、
        // 読むものの下に埋もれていた。
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('クラブに伝える', 'Tell the club'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                Text(tr('クラブへの方針', 'What you ask of them'), style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in Directive.values)
                      ChoiceChip(
                        label: Text(d.label),
                        selected: state.directive == d,
                        onSelected: (_) => controller.setDirective(d),
                      ),
                  ],
                ),
                // 説明はツールチップに隠さない。スマホでは長押ししないと読めない。
                if (state.directive.effect.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    state.directive.effect,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _RoleSection(state: state, controller: controller),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _convert(context),
                  child: Text(tr('ポジションを変える（今 ${state.player.positionName}）', 'Change position (now ${state.player.positionName})')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// クラブの帯。エンブレムと名前を、そのクラブの色で出す。
///
/// クラブタブは制度の説明ばかりで、**どこに所属しているのかが
/// 文字の中に埋もれていた**。
class _ClubBand extends StatelessWidget {
  const _ClubBand({required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = ClubIdentity.of(club);
    final on =
        ThemeData.estimateBrightnessForColor(identity.primary) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF14140F);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(identity.primary, Colors.black, 0.14)!,
            Color.lerp(identity.primary, Colors.white, 0.06)!,
          ],
        ),
      ),
      child: Row(
        children: [
          ClubCrest(club: club, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: on,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tr('${World.byId(club.countryId).name} ${club.tier}部'
                  ' ・ 強さ ${club.strength}', '${World.byId(club.countryId).name}, tier ${club.tier} - strength ${club.strength}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: on.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ピッチの外で起きたこと。答えるまで居座る。
class _EventCard extends StatelessWidget {
  const _EventCard({required this.controller});

  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = controller.pendingEvent!;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('今週', 'Week'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            Text(event.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(event.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (final choice in event.choices) ...[
              // 同系色の塗りだと、地の文と見分けが付かず押せると分からなかった。
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
                icon: const Icon(Icons.chevron_right, size: 18),
                iconAlignment: IconAlignment.end,
                onPressed: () async {
                  final outcome = choice.outcome;
                  await controller.resolveEvent(choice);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(outcome)));
                },
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(choice.label),
                      // 何に効くかを出す。名前だけの三択は、どれを押しても
                      // 同じに見えて、選ぶ材料が一つも無かった。
                      if (choice.effect.summary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            choice.effect.summary.join(tr(' ・ ', ' - ')),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// 経験点。伸びるはずだったぶんを、自分で振る。
///
/// 成長は**全部自動**で、伸ばす先を選ぶ余地が無かった。練習の種類で
/// カテゴリは選べても、その中のどれが伸びるかは運任せ。
///
/// 既定は自動のまま。今まで自動で伸びていたものが、ある日から自分で
/// 振らないと伸びなくなるのは、続きから遊ぶ人にとって不意打ちでしかない。
class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final points = state.development.points;
    final keys = [
      for (final k in AttributeKey.values)
        if (k != AttributeKey.goalkeeping ||
            state.player.position == Position.gk)
          k,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tr('経験点', 'Points'), style: theme.textTheme.titleSmall),
                ),
                Text(
                  state.autoSpend ? tr('その場で自動', 'Spent for you') : tr('自分で振る', 'Spend them yourself'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Switch(
                  value: !state.autoSpend,
                  onChanged: (value) => controller.setAutoSpend(!value),
                ),
              ],
            ),
            Text(
              state.autoSpend
                  ? tr('伸びるはずだったぶんは、その場で自動的に振られる（今までと同じ）。'
                        '切り替えると、貯めて自分で振れる。', 'Whatever you would have gained is spent for you on the spot, as it always has been. Switch this and you bank it and spend it yourself.')
                  : tr('練習と試合で貯まったぶんを、自分で振る。'
                        'カテゴリを跨いでは使えない。', 'You spend what training and matches bank for you. Points cannot cross from one category to another.'),
              style: muted,
            ),
            if (!state.autoSpend) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in keys)
                    ActionChip(
                      label: Text('${key.label} ${points[key] ?? 0}'),
                      backgroundColor: (points[key] ?? 0) > 0
                          ? theme.colorScheme.primaryContainer
                          : null,
                      onPressed: () => _open(context, key),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr('上に行くほど値段が上がる。'
                '苦手を安いうちに埋めるか、得意をさらに押し上げるか。', 'The higher it goes, the more it costs. Fill in a weakness while it is cheap, or push a strength further.'),
                style: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, AttributeKey key) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final theme = Theme.of(sheetContext);
          final have = state.development.points[key] ?? 0;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('${key.label}に振る', 'Spend on ${key.label}'), style: theme.textTheme.titleMedium),
                  Text(
                    tr('残り $have 点', '$have left'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final detail in key.details)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(detail.label),
                      subtitle: Text(
                        controller.reasonNotToSpend(detail) ??
                            '${state.player.attributes.detail(detail)} → '
                                '${state.player.attributes.detail(detail) + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: controller.canSpend(detail)
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: controller.canSpend(detail)
                            ? () async {
                                final grown = await controller.spendPoint(
                                  detail,
                                );
                                setSheetState(() {});
                                if (!sheetContext.mounted || grown == null) {
                                  return;
                                }
                                ScaffoldMessenger.of(sheetContext)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        grown == detail
                                            ? tr('${detail.label}が1上がった', '${detail.label} up 1')
                                            : tr('土台が足りず、${grown.label}のほうが伸びた', 'The foundation was not there, so ${grown.label} grew instead'),
                                      ),
                                    ),
                                  );
                              }
                            : null,
                        child: Text(tr('${controller.costOf(detail)}点', '${controller.costOf(detail)}pt')),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 次の一戦。クラブの色とエンブレムで「誰とやるのか」を絵にする。
///
/// 一番よく見るカードなのに、相手は文字でしか出ていなかった。
/// **判定には効かない**——`ClubIdentity` を映しているだけ。
/// コツ。20年やってきたことが、最後に1つだけ性質になる。
///
/// 特性は生まれ持ったもの、という前提はそのまま。ここで開けるのは
/// **1つだけ**で、しかも自分が何度も勝負してきた場面からしか出ない。
class _KnackCard extends StatelessWidget {
  const _KnackCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final missing = Knacks.missing(state);
    final ready = missing == null;
    return Card(
      color: ready ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('コツ', 'Knack'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: ready ? theme.colorScheme.onSecondaryContainer : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('キャリアで1つだけ、やってきたことが特性になる。'
              '何度も勝負してきた場面からしか出ない。', 'Once in a career, what you have done becomes a trait. It only comes from the moments you have fought again and again.'),
              style: ready
                  ? theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    )
                  : muted,
            ),
            if (!ready) ...[
              const SizedBox(height: 8),
              // 「まだ出ない」のか「もう掴んだ」のかが分からないのが一番困る。
              Text(missing, style: muted),
              // **3つ全部を並べる。** 足りないものを1つずつ出していくと、
              // 1つ埋めるたびに次が現れて、いつ届くのか読めない。
              if (!state.learnedKnack) ...[
                const SizedBox(height: 8),
                for (final line in [
                  (
                    tr('試合経験', 'Match experience'),
                    state.development.experience,
                    Knacks.experienceNeeded,
                  ),
                  (
                    tr('練習の大成功', 'Great weeks'),
                    state.development.greatWeeks,
                    Knacks.greatWeeksNeeded,
                  ),
                  (tr('同じ場面での勝負', 'Times in that moment'), Knacks.bestMoments(state), Knacks.momentsNeeded),
                ])
                  // **棒で出す。** 「8 / 350」と数字だけ並べていた頃は、
                  // キャリアで1つだけのものが**どれくらい遠いのか**が
                  // 読めなかった（監督の期待には棒があるのに、ここには
                  // 無かった）。判定と同じ `Knacks` の線から出す。
                  StatBar(
                    label: line.$1,
                    labelWidth: 108,
                    now: line.$2.toDouble(),
                    target: line.$3.toDouble(),
                    text: '${line.$2} / ${line.$3}',
                  ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _choose(context),
                  child: Text(tr('コツを掴む', 'Take the knack')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final offer = Knacks.offer(state);
    final picked = await showModalBottomSheet<Trait>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('どのコツを掴むか', 'Which knack to take'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  tr('キャリアで1つだけ。取り消せない。'
                  'ここに出るものは、あなたが選び続けてきた場面から決まっている。', 'One per career, and it cannot be undone. What shows up here comes from the moments you kept choosing.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final trait in offer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, trait),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TraitRow(trait: trait),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(tr('今は掴まない', 'Not yet')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    final ok = await controller.learnKnack(picked);
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr('${picked.label} を身に付けた', 'You picked up ${picked.label}'))));
  }
}

/// 通算の記録。1年ずつの積み上げの前に、全体を1枚で見せる。
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final totals = state.careerTotals;
    final clubs = {state.club.name, for (final h in state.history) h.clubName};
    final countries = {
      state.club.countryId,
      for (final h in state.history) h.countryId,
    };
    final leagueTitles = state.history
        .where((h) => h.tier == 1 && h.leaguePosition == 1)
        .length;
    final cups = state.history
        .where((h) => h.cupStage == CupStage.winner)
        .length;
    final continental = state.history
        .where((h) => h.continentalStage == ContinentalStage.winner)
        .length;
    final worldCups = state.history
        .where((h) => h.worldCupStage.participated)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('通算', 'Career'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatTile(label: tr('試合', 'Games'), value: '${totals.appearances}'),
                StatTile(label: tr('ゴール', 'Goals'), value: '${totals.goals}'),
                StatTile(label: tr('アシスト', 'Assists'), value: '${totals.assists}'),
                StatTile(
                  label: tr('平均評価', 'Avg rating'),
                  value: totals.appearances == 0
                      ? '—'
                      : totals.averageRating.toStringAsFixed(2),
                  accent: totals.appearances == 0
                      ? null
                      : ratingColor(theme, totals.averageRating),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('${state.history.length + 1}シーズン目 ・ '
              '${clubs.length}クラブ ・ ${countries.length}か国'
              '${state.caps > 0 ? ' ・ 代表${state.caps}キャップ' : ''}', 'Season ${state.history.length + 1} - ${plural(clubs.length, 'club')} - ${plural(countries.length, 'country', 'countries')}${state.caps > 0 ? ' - ${plural(state.caps, 'cap')}' : ''}'),
              style: muted,
            ),
            if (leagueTitles + cups + continental + worldCups > 0) ...[
              const SizedBox(height: 12),
              Text(tr('タイトル', 'Trophies'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (leagueTitles > 0)
                    Chip(
                      label: Text(tr('リーグ優勝 $leagueTitles', 'League titles $leagueTitles')),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (cups > 0)
                    Chip(
                      label: Text(tr('国内カップ $cups', 'Domestic cups $cups')),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (continental > 0)
                    Chip(
                      label: Text(tr('大陸カップ $continental', 'Continental cups $continental')),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (worldCups > 0)
                    Chip(
                      label: Text(tr('世界大会出場 $worldCups', 'World tournaments $worldCups')),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (state.reputation.awards.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr('称号', 'Honours'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in state.reputation.awards)
                    Chip(
                      label: Text(a.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// キャリアの推移。数字の羅列より、線1本のほうが形が分かる。
class _CareerChartCard extends StatelessWidget {
  const _CareerChartCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final history = state.history;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('推移', 'Over the years'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(tr('棒＝シーズンの平均評価　線＝総合力', 'Bars are the season average rating; the line is your overall'), style: muted),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _CareerChartPainter(
                  history: history,
                  bar: theme.colorScheme.primaryContainer,
                  line: theme.colorScheme.primary,
                  grid: theme.colorScheme.outlineVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${history.first.year}', style: muted),
                Text('${history.last.year}', style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerChartPainter extends CustomPainter {
  const _CareerChartPainter({
    required this.history,
    required this.bar,
    required this.line,
    required this.grid,
  });

  final List<SeasonRecord> history;
  final Color bar;
  final Color line;
  final Color grid;

  /// 評価点の見せる範囲。全域（4〜10）を映すと、差が潰れて読めない。
  static const double minRating = 5.5;
  static const double maxRating = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final slot = size.width / history.length;

    // 6.0 の目安線。ここが「普通の出来」。
    final basis =
        size.height * (1 - (6.0 - minRating) / (maxRating - minRating));
    canvas.drawLine(
      Offset(0, basis),
      Offset(size.width, basis),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    final barPaint = Paint()..color = bar;
    for (var i = 0; i < history.length; i++) {
      final record = history[i];
      if (record.stats.appearances == 0) continue;
      final value =
          ((record.stats.averageRating - minRating) / (maxRating - minRating))
              .clamp(0.0, 1.0);
      final height = size.height * value;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            slot * i + slot * 0.2,
            size.height - height,
            slot * 0.6,
            height,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    // 総合力の線。記録が無いシーズン（古い保存データ）は飛ばす。
    final points = <Offset>[];
    for (var i = 0; i < history.length; i++) {
      final overall = history[i].overall;
      if (overall <= 0) continue;
      final value = ((overall - 45) / 50).clamp(0.0, 1.0);
      points.add(Offset(slot * i + slot / 2, size.height * (1 - value)));
    }
    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (final point in points) {
        canvas.drawCircle(point, 2.5, Paint()..color = line);
      }
    }
  }

  @override
  bool shouldRepaint(_CareerChartPainter oldDelegate) =>
      oldDelegate.history.length != history.length;
}

/// 世の中に出た見出し。
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.news, this.title, this.limit = 3});

  final List<NewsItem> news;
  /// 渡されなければ「最近の話題」。**既定の引数には書けない**
  /// （定数しか置けないし、置けたとしても起動時の言語で固まる）。
  final String? title;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title ?? tr('最近の話題', 'In the news'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            for (final item in news.take(limit)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _colorOf(theme, item.kind),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.headline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.body.isNotEmpty) Text(item.body, style: muted),
                        Text(
                          tr('${item.dateLabel} ・ ${item.kind.label}', '${item.dateLabel} - ${item.kind.label}'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorOf(ThemeData theme, NewsKind kind) => switch (kind) {
    NewsKind.milestone => theme.colorScheme.primary,
    NewsKind.transfer => theme.colorScheme.tertiary,
    NewsKind.national => theme.colorScheme.secondary,
    _ => theme.colorScheme.outline,
  };
}

/// リーグの得点ランキング。自分がどのあたりに居るのかを見せる。
/// 今シーズンのカップ戦。どこまで来ていて、次は誰と当たるか。
class _CupCard extends StatelessWidget {
  const _CupCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final runs = [
      for (final run in [state.domesticCup, state.continentalCup]) ?run,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('カップ戦', 'Cups'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final run in runs) ...[
              Row(
                children: [
                  Icon(
                    run.won
                        ? Icons.emoji_events
                        : run.eliminated
                        ? Icons.do_not_disturb_on_outlined
                        : Icons.sports_soccer_outlined,
                    size: 18,
                    color: run.won
                        ? theme.colorScheme.primary
                        : run.eliminated
                        ? theme.colorScheme.outlineVariant
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      run.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: run.won
                            ? theme.colorScheme.primary
                            : run.eliminated
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              // グループは勝ち点で突破が決まる。線をそのまま出す。
              if (run.running && run.round == CupRound.group)
                Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 4),
                  child: Text(
                    tr('突破の目安は勝点${CupRun.groupQualifyPoints}', '${CupRun.groupQualifyPoints} points usually sees you through'),
                    style: muted,
                  ),
                ),
              if (run.running && run.round != CupRound.group)
                Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 4),
                  child: Text(
                    run.next != null
                        ? tr('次は ${run.next!.opponentName}', 'Next: ${run.next!.opponentName}')
                        : tr('次の相手はまだ決まっていない', 'The next opponent is not drawn yet'),
                    style: muted,
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Text(tr('カップ戦の週は練習ができない。連戦のぶんだけ消耗する。', 'There is no training in a cup week, and the extra games wear you down.'), style: muted),
          ],
        ),
      ),
    );
  }
}

class _ScorerCard extends StatelessWidget {
  const _ScorerCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 上位3だけ。得点王レースで知りたいのは「追う相手と、自分の位置」だけで、
    // 4位から6位は別に追っていない。
    final scorers = ScorerRace.table(state, take: 3);
    // 圏外の自分は末尾に付け足されるので、並び順の番号は本当の順位ではない。
    // 6位まで載せて自分が14位でも「7」と出ていた。
    final myRank = ScorerRace.rankOf(state);
    final chase = ScorerRace.chaseFor(state);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('得点ランキング', 'Top scorers'), style: theme.textTheme.titleSmall),
            if (chase != null)
              Text(
                chase,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            const SizedBox(height: 10),
            for (var i = 0; i < scorers.length; i++)
              Container(
                color: scorers[i].isPlayer
                    ? theme.colorScheme.primaryContainer
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${scorers[i].isPlayer ? myRank : i + 1}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        scorers[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: scorers[i].isPlayer
                            ? theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )
                            : theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        scorers[i].clubName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${scorers[i].goals}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 選手としての水準。総合力が世界のどのあたりに当たるのかを言葉にする。
///
/// 数字だけを出しても「78 が高いのか低いのか」は分からない。
/// 世界のクラブと突き合わせて、行ける場所として見せる。
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final player = state.player;
    final grade = Ranking.gradeFor(player.overall);
    final peak = Ranking.gradeFor(player.potential);
    // 代表の線は国の格で動く。判定（`shouldCallUp`）と同じ数字を引く。
    final national = World.byId(state.nationalTeam);
    final callUpLine = Formulas.callUpLineFor(national.prestige);
    final toCallUp = Ranking.toCallUp(player.overall, line: callUpLine);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('選手としての水準', 'Where you rank as a player'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${player.overall}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        tr('総合力', 'Overall'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(grade.label, style: theme.textTheme.titleMedium),
                      Text(grade.description, style: muted),
                      Text(
                        tr('${Ranking.of(state.club.countryId, state.club.tier).name}'
                        'の平均は '
                        '${Ranking.of(state.club.countryId, state.club.tier).average.round()}', '${Ranking.of(state.club.countryId, state.club.tier).name} averages ${Ranking.of(state.club.countryId, state.club.tier).average.round()}'),
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LevelLine(
              icon: Icons.groups,
              text:
                  tr('世界${grade.totalClubs}クラブのうち'
                  '${grade.starterClubs}クラブの主力を上回っている', 'You are above the first choice at ${grade.starterClubs} of the world ${grade.totalClubs} clubs'),
            ),
            _LevelLine(
              icon: Icons.badge,
              text:
                  tr('${state.club.name}（強さ ${state.club.strength}）では'
                  '${Ranking.standingIn(player.overall, state.club)}', 'At ${state.club.name} (strength ${state.club.strength}) you are ${Ranking.standingIn(player.overall, state.club)}'),
            ),
            _LevelLine(
              icon: Icons.public,
              text: grade.bestLeague == null
                  ? tr('今はまだ、どのリーグでも平均には届かない', 'For now you are below average in every league')
                  : tr('平均以上でいられる一番上のリーグ: '
                        '${grade.bestLeague!.name}（世界${grade.bestLeague!.rank}位）', 'The highest league you would be above average in: ${grade.bestLeague!.name} (#${grade.bestLeague!.rank} in the world)'),
            ),
            _LevelLine(
              icon: Icons.flag,
              text: toCallUp == 0
                  ? tr('${national.name}代表の線（総合力$callUpLine）には届いている', 'You are over the ${national.name} call-up line (overall $callUpLine)')
                  : tr('${national.name}代表の線（総合力$callUpLine）まで あと$toCallUp', '$toCallUp short of the ${national.name} call-up line (overall $callUpLine)'),
            ),
            _LevelLine(
              icon: Icons.trending_up,
              text: player.overall >= player.potential
                  ? tr('伸びしろは使い切った。ここからは維持する戦い', 'You have used up your room to grow. From here it is about holding on')
                  : tr('伸び切れば ${player.potential} = ${peak.label}', 'All the way out: ${player.potential} = ${peak.label}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelLine extends StatelessWidget {
  const _LevelLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// 世界のリーグの序列。自分のリーグがどのレベルなのかを示す。
class _WorldLeagueCard extends StatelessWidget {
  const _WorldLeagueCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final mine = Ranking.of(state.club.countryId, state.club.tier);
    final all = Ranking.leagues();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('リーグの格付け', 'How the leagues rank'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mine.grade,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('${mine.name} ・ ${mine.gradeLabel}', '${mine.name} - ${mine.gradeLabel}'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        tr('世界${mine.rank}位 / ${mine.total}リーグ ・ '
                        '平均の強さ ${mine.average.round()} ・ '
                        '首位級 ${mine.top}', '#${mine.rank} of ${mine.total} leagues - average strength ${mine.average.round()} - at the top ${mine.top}'),
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // 畳んだ/開いたの記憶。タブの ListView に PageStorageKey を付けたので、
                // 鍵の無い ExpansionTile はスクロール位置と同じ枠を読んで落ちる。
                key: const PageStorageKey('world-leagues'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(tr('世界のリーグ一覧', 'Every league in the world'), style: theme.textTheme.bodySmall),
                children: [
                  for (final league in all)
                    _LeagueRankRow(
                      league: league,
                      mine:
                          league.countryId == mine.countryId &&
                          league.tier == mine.tier,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueRankRow extends StatelessWidget {
  const _LeagueRankRow({required this.league, required this.mine});

  final LeagueRank league;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: mine ? theme.colorScheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${league.rank}', style: theme.textTheme.bodySmall),
          ),
          SizedBox(
            width: 20,
            child: Text(league.grade, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              league.name,
              overflow: TextOverflow.ellipsis,
              style: mine
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${league.average.round()}',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 練習が試合に出ているかを見せる。
///
/// 能力値は毎週1ずつしか動かないので、画面を見ているだけでは
/// 伸びたことに気付けない。開幕からの差と、その能力で実際に
/// 勝負した局面の成否を並べて、練習の答え合わせにする。
/// 育てる方向。伸ばしたい項目を決めておく。
///
/// 練習も試合の成長も、伸びる先が無作為だったので、何を選んでも
/// 似た選手になっていた。ここを決めると、伸びる先がそこに寄る。
/// **伸びる量は変わらない**——どこに乗るかだけが変わる。
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  /// その項目を極めると覚えられる個人技。無ければ null。
  ///
  /// **そのポジションで覚えられるものだけ**を出す。
  /// GK に「無回転シュート あと12」と書いても、覚えることはない。
  Signature? _signatureFor(Detail detail) {
    for (final s in Signature.forPosition(state.player.position)) {
      if (s.detail == detail) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final player = state.player;
    final full = state.focus.length >= CareerState.maxFocus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しは `Expanded`。`Spacer` だけでは、見出しも右の数字も
            // 幅を持たない子なので、英語で見出しが長くなると `Spacer` が 0 に
            // なってから横へ溢れる。`Expanded` なら見出しが折り返し、
            // 右の数字は端に残る（日本語の見え方は変わらない）。
            Row(
              children: [
                Expanded(
                  child: Text(tr('育てる方向', 'What you are growing'), style: theme.textTheme.titleSmall),
                ),
                Text(
                  '${state.focus.length} / ${CareerState.maxFocus}',
                  style: muted,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              state.focus.isEmpty
                  ? tr('選ぶと、練習も試合の成長もそこに寄る。'
                        '伸びる量は変わらず、どこに乗るかだけが変わる。', 'Pick something and both training and match growth lean that way. The amount does not change — only where it lands.')
                  : tr('練習ではこの項目が優先して伸び、試合の成長も'
                        'ここに寄る。試合の選択肢にも印が付く。', 'Training grows these first and match growth leans here too. Moves in a match are marked for it.'),
              style: muted,
            ),
            if (state.focus.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final detail in state.focus)
                _FocusProgress(
                  detail: detail,
                  value: player.attributes.detail(detail),
                  signature: _signatureFor(detail),
                  learned: state.development.signatures.contains(
                    _signatureFor(detail),
                  ),
                  // 積むほど土台を先行できる。ここが「尖った選手」の作り方で、
                  // 見えないと積む理由が分からない。
                  dedication: state.development.dedicationOf(detail),
                  cap: Dependencies.capFor(
                    detail,
                    player.attributes,
                    ceiling: player.ceilingFor(detail),
                    dedication: state.development.dedicationOf(detail),
                  ),
                ),
            ],
            // **育てた結果、別の選手になっていることがある。**
            // 総合力はポジションの重みで出すので、そのポジションが
            // 求めないものを伸ばすほど下がる。それは間違った育て方ではない。
            if (player.suitedPosition != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tr('今の能力なら ${player.suitedPosition!.label} のほうが向いている。'
                  'クラブタブからコンバートできる。', 'With the attributes you have now, ${player.suitedPosition!.label} suits you better. You can convert from the Club tab.'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // 畳んだ/開いたの記憶。タブの ListView に PageStorageKey を付けたので、
                // 鍵の無い ExpansionTile はスクロール位置と同じ枠を読んで落ちる。
                key: const PageStorageKey('focus-pick'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(tr('項目を選ぶ', 'Choose an attribute'), style: theme.textTheme.bodySmall),
                children: [
                  for (final key in AttributeKey.values)
                    if (key != AttributeKey.goalkeeping ||
                        player.position == Position.gk) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          key.label,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final detail in key.details)
                            FilterChip(
                              label: Text(
                                '${detail.label} '
                                '${player.attributes.detail(detail)}',
                              ),
                              selected: state.focus.contains(detail),
                              // 上限まで入っていたら、外すことしかできない。
                              onSelected: full && !state.focus.contains(detail)
                                  ? null
                                  : (_) => controller.toggleFocus(detail),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 個人技を狙う。**どれを覚えるかを選べる。**
///
/// ずっと「狙って取りには行けない」でやってきた。覚える条件（元になる
/// 能力が78）はどこにも書いておらず、3つの枠は勝手に埋まった。
/// 何が起きたのか分からないまま終わるので、選んだ実感が無い。
///
/// ここで変えたのは**2つだけ**:
/// - 取得条件を全部並べる（元になる能力・必要78・今の値・あと何）
/// - 1つ狙える。狙ったものは掴む確率が上がり、掴むときはそれになる
///
/// **能力は要る。** 78に届いていないものを狙っても何も起きない——
/// 狙いが変えるのは「候補のどれになるか」と「その速さ」だけで、
/// 積み上げの代わりにはならない。
class _SignatureAimCard extends StatelessWidget {
  const _SignatureAimCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final player = state.player;
    final owned = state.development.signatures;
    final full = owned.length >= Signature.maxOwned;

    // **そのポジションで覚えられるものだけ。** 近い順に並べる——
    // 20個を定義順に並べても、どれが手の届く距離なのか読めない。
    final all = [...Signature.forPosition(player.position)]
      ..sort((a, b) {
        final oa = owned.contains(a) ? 1 : 0;
        final ob = owned.contains(b) ? 1 : 0;
        if (oa != ob) return oa - ob;
        return player.attributes
            .detail(b.detail)
            .compareTo(player.attributes.detail(a.detail));
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しは `Expanded`。`Spacer` だけでは、見出しも右の数字も
            // 幅を持たない子なので、英語で見出しが長くなると `Spacer` が 0 に
            // なってから横へ溢れる。`Expanded` なら見出しが折り返し、
            // 右の数字は端に残る（日本語の見え方は変わらない）。
            Row(
              children: [
                Expanded(
                  child: Text(tr('個人技を狙う', 'Going for a trick'), style: theme.textTheme.titleSmall),
                ),
                // 「育てる方向」の 0/3 と紛らわしいので、何の数かを書く。
                Text(
                  tr('覚えた ${owned.length} / ${Signature.maxOwned}', 'Learned ${owned.length} / ${Signature.maxOwned}'),
                  style: muted,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              full
                  ? tr('覚えられるのは${Signature.maxOwned}つまで。'
                        'ここから先は、磨いて深くしていく。', 'You can only learn ${Signature.maxOwned}. From here on it is about polishing them deeper.')
                  : tr('元になる能力が${Signature.requirement}に届くと、'
                        'その練習をしている週に掴むことがある。'
                        '1つ狙っておくと、掴むときはそれになる。', 'Once the underlying attribute reaches ${Signature.requirement}, a week of that training can land it. Name one you are going for and that is the one you get.'),
              style: muted,
            ),
            const SizedBox(height: 10),
            // **覚えたものと狙っているものは、畳まずに出す。**
            // ポジションによっては候補が20個あるので、全部を開いたままだと
            // この下にあるものが画面から押し出される。
            for (final signature in all)
              if (owned.contains(signature) || state.signatureAim == signature)
                _SignatureRow(
                  signature: signature,
                  value: player.attributes.detail(signature.detail),
                  learned: owned.contains(signature),
                  mastery: state.development.masteryOf(signature),
                  aimed: state.signatureAim == signature,
                  focused: state.focus.contains(signature.detail),
                  // 覚えたものは触れない。狙いはもう一度押せば外れる。
                  onTap: owned.contains(signature)
                      ? null
                      : () => controller.aimSignature(signature),
                ),
            // 枠が埋まっていたら、もう狙う先は無い。
            if (!full)
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  // 畳んだ/開いたの記憶。タブの ListView に PageStorageKey を付けたので、
                  // 鍵の無い ExpansionTile はスクロール位置と同じ枠を読んで落ちる。
                  key: const PageStorageKey('aim-pick'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    state.signatureAim == null ? tr('狙う技を選ぶ', 'Choose a trick') : tr('狙いを変える', 'Go for another'),
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    for (final signature in all)
                      if (!owned.contains(signature) &&
                          state.signatureAim != signature)
                        _SignatureRow(
                          signature: signature,
                          value: player.attributes.detail(signature.detail),
                          learned: false,
                          mastery: 0,
                          aimed: false,
                          focused: state.focus.contains(signature.detail),
                          onTap: () => controller.aimSignature(signature),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 個人技1つぶん。取得条件と、あといくつかを出す。
class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.signature,
    required this.value,
    required this.learned,
    required this.mastery,
    required this.aimed,
    required this.focused,
    required this.onTap,
  });

  final Signature signature;
  final int value;
  final bool learned;

  /// 磨いた段（0〜`Signature.maxMastery`）。
  final int mastery;

  final bool aimed;
  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final remaining = Signature.requirement - value;
    final reached = remaining <= 0;

    final String condition;
    if (learned) {
      // **磨いた段まで書く。** 覚えて終わりだと、後半の練習で何が
      // 起きているのかが画面のどこにも出ない。
      condition = mastery <= 0
          ? tr('習得ずみ。伸びなくなった歳から、練習で磨かれていく', 'Learned. Once you stop growing, training polishes it')
          : tr('習得ずみ・${Signature.masteryLabel(mastery)}'
                '（$mastery / ${Signature.maxMastery}）'
                '　噛み合う手に +${((Formulas.signatureOnDetail + Formulas.signaturePerMastery * mastery) * 100).round()}%', 'Learned - ${Signature.masteryLabel(mastery)} ($mastery / ${Signature.maxMastery})  +${((Formulas.signatureOnDetail + Formulas.signaturePerMastery * mastery) * 100).round()}% on a move it fits');
    } else if (reached) {
      condition =
          tr('${signature.detail.label} $value。'
          '条件は満たしている。あとは${signature.key.label}の練習で掴むだけ', '${signature.detail.label} $value. You meet the condition; now it just takes a week of ${signature.key.label} training');
    } else {
      condition =
          tr('${signature.detail.label} $value '
          '（${Signature.requirement}で覚えられる、あと$remaining）', '${signature.detail.label} $value (learnable at ${Signature.requirement}, $remaining to go)');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: aimed
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    learned
                        ? Icons.check_circle
                        : aimed
                        ? Icons.my_location
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(signature.label, style: theme.textTheme.bodyMedium),
                  ),
                  if (aimed) Text(tr('狙っている', 'Going for it'), style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 6),
              GaugeBar(
                // 覚えたあとは、能力ではなく磨いた段を出す。
                value: learned
                    ? mastery / Signature.maxMastery
                    : (value / Signature.requirement).clamp(0.0, 1.0),
                height: 5,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(condition, style: muted),
              // 近づけ方まで書く。条件だけ出しても、何をすれば上がるのかが
              // 分からなければ「狙って取りに行く」にはならない。
              if (!learned && !reached && !focused)
                Text(
                  tr('育てる方向に「${signature.detail.label}」を入れると、'
                  '練習も試合の成長もそこに寄る', 'Put ${signature.detail.label} among what you are growing and both training and match growth lean there'),
                  style: muted,
                ),
              // **値段を先に書く。** 狙っている間は練習の枠を空けて待つ。
              // 後から知らされる話ではない。
              if (aimed && !reached)
                Text(
                  tr('狙っている間、練習では他の技を覚えない', 'While you are going for it, training will not land any other trick'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 方向に入れた項目1つぶん。個人技まであといくつかを出す。
/// 育てる方向の1項目。**積み上げと、いま届く上限**を出す。
class _FocusProgress extends StatelessWidget {
  const _FocusProgress({
    required this.detail,
    required this.value,
    required this.signature,
    required this.learned,
    required this.dedication,
    required this.cap,
  });

  final Detail detail;
  final int value;
  final Signature? signature;
  final bool learned;

  /// その項目を何回狙ってきたか。積むほど土台を先行できる。
  final int dedication;

  /// いま届く上限（土台の平均＋積み上げぶん）。
  final int cap;

  /// 土台を持つ項目か。持たないなら積み上げは効かない。
  bool get _chained => Dependencies.supports[detail]?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final remaining = Signature.requirement - value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(detail.label, style: theme.textTheme.bodyMedium),
              ),
              Text('$value', style: theme.textTheme.titleSmall),
              const SizedBox(width: 10),
              Expanded(
                child: GaugeBar(
                  value: (value / Signature.requirement).clamp(0.0, 1.0),
                  height: 6,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          // 土台で頭打ちなら、そう書く。**書かないと「伸ばしているのに
          // 数字が動かない」理由が分からず、積む意味も見えない。**
          //
          // **土台を持たない項目には積み上げの回数を出さない**——
          // そこは鎖に吸われないので、積んでも上限は動かない。
          // 出すと「積めば上がる」と読めてしまう。
          if (!_chained)
            Text(tr('上限 $cap', 'cap $cap'), style: muted)
          else if (value >= cap)
            Text(
              tr('土台で頭打ち（上限 $cap）。積み上げ $dedication回、あと'
              '${Dependencies.dedicationStep - dedication % Dependencies.dedicationStep}回で上限 +1', 'Held back by the foundation (cap $cap). ${plural(dedication, 'session')} in; ${Dependencies.dedicationStep - dedication % Dependencies.dedicationStep} more raises the cap by 1'),
              style: muted?.copyWith(color: theme.colorScheme.error),
            )
          else
            Text(tr('上限 $cap（積み上げ $dedication回）', 'cap $cap (${plural(dedication, 'session')} in)'), style: muted),
          if (signature != null)
            Text(
              learned
                  ? tr('「${signature!.label}」を覚えている', 'You know ${signature!.label}')
                  : remaining > 0
                  ? tr('${Signature.requirement}で「${signature!.label}」を'
                        '覚える見込み（あと$remaining）', 'At ${Signature.requirement} you can learn ${signature!.label} ($remaining to go)')
                  : tr('「${signature!.label}」を覚える水準に達している', 'You are at the level to learn ${signature!.label}'),
              style: muted,
            ),
        ],
      ),
    );
  }
}

class _TrainingEffectCard extends StatelessWidget {
  const _TrainingEffectCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final rows = [
      for (final g in state.seasonGrowth)
        if ((g.key != AttributeKey.goalkeeping ||
                state.player.position == Position.gk) &&
            // 今週やっている練習の対象は、まだ動いていなくても出す。
            // 「効いていないのか、記録が無いのか」が分からないのが一番困る。
            (g.growth != 0 || g.hasMoments || state.menu.keys.contains(g.key)))
          g,
    ]..sort((a, b) => b.growth.compareTo(a.growth));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('練習の成果（今季）', 'What training gave you this season'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(tr('開幕からの伸びと、その能力で勝負した局面。', 'How much you have grown since the opener, and the moments you used it in.'), style: muted),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(
                tr('まだ記録が無い。試合に出て、練習を積んだぶんがここに出る。', 'Nothing recorded yet. Play games, put in the training, and it shows up here.'),
                style: theme.textTheme.bodySmall,
              )
            else
              for (final g in rows) _GrowthRow(growth: g),
          ],
        ),
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  const _GrowthRow({required this.growth});

  final CategoryGrowth growth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final rate = growth.successRate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  growth.key.label,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                growth.growth == 0
                    ? '${growth.now}'
                    : '${growth.before} → ${growth.now}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              if (growth.growth > 0)
                Text(
                  '+${growth.growth}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                )
              else if (growth.growth < 0)
                Text(
                  '${growth.growth}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              const Spacer(),
              if (rate != null)
                Text(
                  '${growth.successes}/${growth.attempts}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          if (growth.growth > 0)
            Text(
              tr('この能力の局面が '
              '+${Ranking.chanceGainPercent(growth.growth).toStringAsFixed(1)}% '
              '通りやすくなった', 'Moments using it are +${Ranking.chanceGainPercent(growth.growth).toStringAsFixed(1)}% more likely to come off'),
              style: muted,
            ),
          if (rate != null)
            Text(
              tr('今季 ${growth.attempts}回勝負して ${(rate * 100).round()}% 成功', '${growth.attempts} tries this season, ${(rate * 100).round()}% of them off'),
              style: muted,
            ),
        ],
      ),
    );
  }
}

/// **関係の行。** 言葉だけだと、近いのか遠いのかが分からない。
/// 数字と、次の段までの残りを出す。
String _relationLine(
  String title,
  String label,
  int value,
  (String, int)? next,
) {
  final line = '$title: $label $value/100';
  if (next == null) return line;
  return tr('$line ・ あと${next.$2}で「${next.$1}」', '$line - ${next.$2} more to reach ${next.$1}');
}

class _AttributeBar extends StatelessWidget {
  const _AttributeBar({
    required this.label,
    required this.value,
    this.thin = false,
  });

  final String label;
  final int value;

  /// 詳細能力の行。少し細く、詰めて並べる。
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: thin ? 1 : 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              style: theme.textTheme.bodySmall?.copyWith(
                // 上限を超えた値は、超えていることが一目で分かるように。
                color: value > Formulas.maxAttribute
                    ? theme.colorScheme.tertiary
                    : null,
                fontWeight: value > Formulas.maxAttribute
                    ? FontWeight.w700
                    : null,
              ),
            ),
          ),
          Expanded(
            child: GaugeBar(
              value: (value / Formulas.maxAttribute).clamp(0.0, 1.0),
              height: thin ? 5 : 6,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 1試合ぶんの行。押すと、その試合で何があったかを開く。
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.state});

  final MatchResult result;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.won
        ? theme.colorScheme.primary
        : result.drawn
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.error;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _MatchDetail(result: result, state: state),
      ),
      leading: SizedBox(
        width: 52,
        child: Row(
          children: [
            // 勝ち・分け・負けを、読まずに分かる幅で置く。
            Container(
              width: 4,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                result.scoreLine,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
      // **相手が名前だけで並んでいた。** 順位表にも次節カードにも
      // エンブレムがあるのに、5試合ぶんの記録はここだけ文字だった
      // （「名前だけが並ぶ画面は、自分がどこに居るのか分からなくなる」）。
      // IDを控えていない古い記録では、絵を出さずに今までどおりにする。
      title: Row(
        children: [
          if (result.opponentId.isNotEmpty) ...[
            // 色と形はIDと名前だけで決まる（`ClubIdentity.of`）。
            // 強さと部は見ていないので、ここでは持たせない。
            ClubCrest(
              club: Club(
                id: result.opponentId,
                name: result.opponentName,
                strength: 0,
                tier: 1,
              ),
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              result.international
                  ? tr('代表  ${result.opponentName}', 'National team  ${result.opponentName}')
                  : result.cup != null
                  ? '${result.cup!.label}  ${result.opponentName}'
                  : '${result.home ? "H" : "A"}  ${result.opponentName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(result.appearance.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.rating?.toStringAsFixed(1) ?? '—',
            style: theme.textTheme.titleSmall?.copyWith(
              color: ratingColor(theme, result.rating),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          // 開けることが見た目で分かるように。
          Icon(
            Icons.chevron_right,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// 順位表。クラブのタブの中に置く。
/// 終わった試合の中身。
///
/// 結果画面を閉じると、その試合で何があったかは二度と見られなかった。
/// 38試合ぶんの数字が並ぶだけでは、どれも思い出せない。
class _MatchDetail extends StatelessWidget {
  const _MatchDetail({required this.result, required this.state});

  final MatchResult result;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // その節に出た見出し。試合の意味づけはここに残っている。
    final headlines = state.news
        .where((n) => n.year == state.year && n.matchday == result.matchday)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.international
                  ? tr('代表戦  vs ${result.opponentName}', 'International  vs ${result.opponentName}')
                  : tr('第${result.matchday}節  '
                        '${result.home ? 'ホーム' : 'アウェイ'}  '
                        'vs ${result.opponentName}', 'Round ${result.matchday}  ${result.home ? 'home' : 'away'}  vs ${result.opponentName}'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              tr('${result.scoreLine}  '
              '${result.won
                  ? '勝ち'
                  : result.drawn
                  ? '引き分け'
                  : '負け'}'
              '  ・  ${result.appearance.label}', '${result.scoreLine}  ${result.won ? 'won' : result.drawn ? 'drew' : 'lost'}  -  ${result.appearance.label}'),
              style: muted,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _DetailStat(
                  label: tr('評価点', 'Rating'),
                  value: result.rating == null
                      ? '—'
                      : result.rating!.toStringAsFixed(2),
                ),
                _DetailStat(label: tr('ゴール', 'Goals'), value: '${result.goals}'),
                _DetailStat(label: tr('アシスト', 'Assists'), value: '${result.assists}'),
              ],
            ),
            if (result.yellowCards > 0 || result.sentOff) ...[
              const SizedBox(height: 10),
              Text(
                result.sentOff
                    ? tr('退場（警告${result.yellowCards}枚）', 'Sent off (${result.yellowCards} booking${result.yellowCards == 1 ? '' : 's'})')
                    : tr('警告${result.yellowCards}枚', '${result.yellowCards} booking${result.yellowCards == 1 ? '' : 's'}'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (result.goalMinutes.isNotEmpty ||
                result.assistMinutes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(tr('この試合の自分', 'Your game'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              for (final minute in result.goalMinutes)
                Text(
                  tr('${MatchInProgress.minuteLabel(minute)}  ゴール', '${MatchInProgress.minuteLabel(minute)}  goal'),
                  style: theme.textTheme.bodyMedium,
                ),
              for (final minute in result.assistMinutes)
                Text(
                  tr('${MatchInProgress.minuteLabel(minute)}  アシスト', '${MatchInProgress.minuteLabel(minute)}  assist'),
                  style: theme.textTheme.bodyMedium,
                ),
            ],
            if (headlines.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(tr('この節の話題', 'Round talk'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              for (final item in headlines) ...[
                Text(item.headline, style: theme.textTheme.bodyMedium),
                if (item.body.isNotEmpty) Text(item.body, style: muted),
                const SizedBox(height: 6),
              ],
            ],
            if (result.appearance == Appearance.benched)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(tr('出番は無かった。', 'You did not get on.'), style: muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _TableCard extends StatefulWidget {
  const _TableCard({required this.state});

  final CareerState state;

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _all = false;

  /// 既定で見せる行。**首位と、自分の上下2つずつ。**
  ///
  /// 18クラブを全部並べると 888px（スマホ1.2画面分）あって、
  /// クラブタブの3割を一つの表が占めていた。毎週見たいのは
  /// 「自分は今何位で、上と下は誰か」で、全部はたまに見るもの。
  List<int> _window(int count, int me) {
    final picked = <int>{0};
    for (var i = me - 2; i <= me + 2; i++) {
      if (i >= 0 && i < count) picked.add(i);
    }
    return picked.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final rows = state.sortedTable;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final me = rows.indexWhere((r) => r.clubId == state.club.id);
    final shown = _all
        ? [for (var i = 0; i < rows.length; i++) i]
        : _window(rows.length, me < 0 ? 0 : me);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('順位表', 'Table'), style: theme.textTheme.titleSmall),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(tr('試', 'P'), style: muted, textAlign: TextAlign.end),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(tr('差', 'GD'), style: muted, textAlign: TextAlign.end),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(tr('点', 'Pts'), style: muted, textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < shown.length; i++) ...[
              // 飛んだところは黙って詰めない。詰めると順位が隣同士に見える。
              if (i > 0 && shown[i] != shown[i - 1] + 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  child: Text('…', style: muted),
                ),
              _TableRowTile(state: state, position: shown[i] + 1),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? tr('近くだけにする', 'Show just around me') : tr('順位表を全部見る（${rows.length}クラブ）', 'See the whole table (${rows.length} clubs)')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 順位表の1行。
///
/// 行の型（models の TableRow）は Flutter の TableRow と名前がぶつかるので、
/// ここでは型名を書かずに順位から引き直す。
class _TableRowTile extends StatelessWidget {
  const _TableRowTile({required this.state, required this.position});

  final CareerState state;
  final int position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = state.sortedTable[position - 1];
    final mine = row.clubId == state.club.id;
    return Container(
      color: mine ? theme.colorScheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$position')),
          ClubCrest(
            club: state.league.firstWhere(
              (c) => c.id == row.clubId,
              orElse: () => state.club,
            ),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.clubName,
              overflow: TextOverflow.ellipsis,
              style: mine
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('${row.played}', textAlign: TextAlign.end),
          ),
          SizedBox(
            width: 40,
            child: Text(
              row.goalDifference >= 0
                  ? '+${row.goalDifference}'
                  : '${row.goalDifference}',
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${row.points}',
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerTab extends StatelessWidget {
  const _CareerTab({
    required this.state,
    required this.stats,
    required this.controller,
  });

  final CareerState state;

  /// 約束を口にするため。
  final CareerController controller;

  /// 今季の成績。記録の一番上に出す。
  final SeasonStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impact = Impact.of(state.leagueResults);
    return _Sectioned(
      storageId: 'section-career',
      labels: [tr('今季', 'This season'), tr('これまで', 'So far')],
      sections: [
        ListView(
          key: const PageStorageKey('tab-career'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            // **今季の目標と、その達成を並べる。**
            // 監督の期待と約束は「試合」タブの下のほうに積んであった。
            // 毎週の判断に使うものではなく**今季どう見られているか**なので、
            // 今季の成績のすぐ上に置く（次節カードには残りが1行出ている）。
            // 監督の期待と約束は「試合」タブの下のほうに積んであった。
            // 毎試合の判断に使うものではなく、**自分が今季どう見られているか**なので、
            // 水準・選手証の次に置く。
            if (state.objective != null) ...[
              _ObjectiveCard(
                objective: state.objective!,
                stats: stats,
                incentiveCut: state.incentiveCut,
              ),
              const SizedBox(height: 16),
            ],
            // 監督の期待は向こうから降ってくる数字。約束は自分で口にする数字。
            if (state.promise != null || PromiseOffers.canPromise(state)) ...[
              _PromiseCard(controller: controller),
              const SizedBox(height: 16),
            ],
            // **今季の数字は、記録の一番上に置く。**
            // 「試合」タブの下に積んであったので、毎週スクロールで通り過ぎる
            // だけだった。積み上がっていくものは全部ここに集める。
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('今シーズンの成績', 'How the season has gone'), style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StatTile(label: tr('出場', 'Games'), value: '${stats.appearances}'),
                        StatTile(label: tr('ゴール', 'Goals'), value: '${stats.goals}'),
                        StatTile(label: tr('アシスト', 'Assists'), value: '${stats.assists}'),
                        StatTile(
                          label: tr('平均評価', 'Avg rating'),
                          value: stats.appearances == 0
                              ? '—'
                              : stats.averageRating.toStringAsFixed(2),
                          accent: stats.appearances == 0
                              ? null
                              : ratingColor(theme, stats.averageRating),
                        ),
                      ],
                    ),
                    // 出た試合と出なかった試合。持ち上げが数字で見える唯一の場所。
                    if (impact.comparable) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr('出た試合 ${impact.with_.label}（勝ち点 '
                        '${impact.with_.pointsPerGame.toStringAsFixed(1)}/試合）', 'Games you played ${impact.with_.label} (${impact.with_.pointsPerGame.toStringAsFixed(1)} pts a game)'),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        tr('出なかった試合 ${impact.without.label}（勝ち点 '
                        '${impact.without.pointsPerGame.toStringAsFixed(1)}/試合）', 'Games you missed ${impact.without.label} (${impact.without.pointsPerGame.toStringAsFixed(1)} pts a game)'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(tr('直近の試合', 'Recent games'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (state.results.isEmpty)
              Text(
                tr('まだ試合をしていない。', 'No games played yet.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              // 5件まで。8件並べると 512px（スマホ0.7画面）を使う。
              // それより前は「これまでの話題」の側に残る。
              for (final r in state.results.reversed.take(5))
                _ResultRow(result: r, state: state),
          ],
        ),
        ListView(
          key: const PageStorageKey('tab-career-total'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            _TotalsCard(state: state),
            const SizedBox(height: 16),
            if (state.news.isNotEmpty) ...[
              _NewsCard(news: state.news, title: tr('これまでの話題', 'The story so far'), limit: 12),
              const SizedBox(height: 16),
            ],
            if (state.history.length >= 2) ...[
              _CareerChartCard(state: state),
              const SizedBox(height: 16),
            ],
            if (state.history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr('シーズンを終えると、ここに1年ずつ積み上がる。', 'Finish a season and it stacks up here, year by year.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final record in state.history.reversed)
              Card(
                child: ListTile(
                  title: Text('${record.year}  ${record.clubName}'),
                  subtitle: Text(
                    tr('${record.tier}部 ${record.leaguePosition}位 ・ '
                    '${record.stats.appearances}試合 '
                    '${record.stats.goals}G ${record.stats.assists}A ・ '
                    '年俸 ${record.salary}万円'
                    '${record.onLoan ? ' ・ ローン' : ''}'
                    '${record.caps > 0 ? ' ・ 代表${record.caps}' : ''}'
                    '${record.continentalStage.participated ? ' ・ 大陸${record.continentalStage.label}' : ''}'
                    '${record.cupStage.participated ? ' ・ 国内杯${record.cupStage.label}' : ''}'
                    '${record.worldCupStage.participated ? ' ・ 世界大会${record.worldCupStage.label}' : ''}'
                    '${record.objectiveMet ? ' ・ 目標達成' : ''}'
                    // 口にした約束は、果たしても破っても記録に残る。
                    '${record.promiseLabel == null
                        ? ''
                        : record.promiseKept
                        ? ' ・ 約束を果たした'
                        : ' ・ 約束を破った'}', 'Tier ${record.tier} #${record.leaguePosition} - ${plural(record.stats.appearances, 'game')} ${record.stats.goals}G ${record.stats.assists}A - wage JPY ${(record.salary / 100).toStringAsFixed(1)}M${record.onLoan ? ' - on loan' : ''}${record.caps > 0 ? ' - ${plural(record.caps, 'cap')}' : ''}${record.continentalStage.participated ? ' - continental ${record.continentalStage.label}' : ''}${record.cupStage.participated ? ' - domestic cup ${record.cupStage.label}' : ''}${record.worldCupStage.participated ? ' - world ${record.worldCupStage.label}' : ''}${record.objectiveMet ? ' - targets met' : ''}${record.promiseLabel == null ? '' : record.promiseKept ? ' - kept your word' : ' - broke your word'}'),
                  ),
                  trailing: Text(
                    record.stats.appearances == 0
                        ? '—'
                        : record.stats.averageRating.toStringAsFixed(2),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 負傷中であることを伝えるカード。
class _InjuryCard extends StatelessWidget {
  const _InjuryCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final injury = state.injury!;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${injury.name}（${injury.severity.label}）',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('残り${injury.matchesOut}試合の離脱。'
              '試合には出られないが、節は進む。', 'Out for another ${plural(injury.matchesOut, 'game')}. You cannot play, but the rounds go on.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(tr('復帰の進め方', 'How you come back'), style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final plan in RehabPlan.values)
                  ChoiceChip(
                    label: Text(plan.label),
                    selected: state.rehab == plan,
                    onSelected: (_) => controller.setRehab(plan),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // 説明はツールチップに隠さない。スマホでは長押ししないと読めない。
            Text(
              state.rehab.effect,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 監督から与えられた今季の目標。達成状況を並べて見せる。
class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({
    required this.objective,
    required this.stats,
    this.incentiveCut = 0,
  });

  final SeasonObjective objective;
  final SeasonStats stats;

  /// 出来高払いで削られている額（万円）。0 なら普通の契約。
  final int incentiveCut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しは `Expanded`。`Spacer` だけでは、見出しも右の数字も
            // 幅を持たない子なので、英語で見出しが長くなると `Spacer` が 0 に
            // なってから横へ溢れる。`Expanded` なら見出しが折り返し、
            // 右の数字は端に残る（日本語の見え方は変わらない）。
            Row(
              children: [
                Expanded(
                  child: Text(
                    incentiveCut > 0 ? tr('監督の期待（出来高払い）', 'What the manager asks (on performance terms)') : tr('監督の期待', 'What the manager asks'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${objective.achievedCount(stats)} / 3',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: objective.achieved(stats)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 「8 / 30」と書くより、棒の長さのほうが早い。
            StatBar(
              label: tr('出場', 'Games'),
              now: stats.appearances.toDouble(),
              target: objective.appearances.toDouble(),
              text: '${stats.appearances} / ${objective.appearances}',
            ),
            StatBar(
              label: tr('得点関与', 'Goal involvements'),
              now: (stats.goals + stats.assists).toDouble(),
              target: objective.contributions.toDouble(),
              text:
                  '${stats.goals + stats.assists} / ${objective.contributions}',
            ),
            StatBar(
              label: tr('平均評価', 'Avg rating'),
              // 評価は 6.0 が基準なので、そこからの積み上がりで見せる。
              now: stats.appearances == 0 ? 0 : stats.averageRating - 6.0,
              target: objective.rating - 6.0,
              text:
                  '${stats.appearances == 0 ? '—' : stats.averageRating.toStringAsFixed(2)}'
                  ' / ${objective.rating.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 6),
            Text(
              incentiveCut > 0
                  // **賭けている額を、賭けている間ずっと出す。**
                  ? tr('2つ以上で達成。今季は年俸を$incentiveCut万削って賭けている——'
                        '2つで$incentiveCut万、3つで'
                        '${(incentiveCut * Formulas.incentiveFull).round()}万が戻る。', 'Two of them counts as met. This season you cut JPY ${(incentiveCut / 100).toStringAsFixed(1)}M off your wage as a bet — two pays back JPY ${(incentiveCut / 100).toStringAsFixed(1)}M, three pays JPY ${(incentiveCut * Formulas.incentiveFull / 100).toStringAsFixed(1)}M.')
                  : tr('2つ以上で達成。契約更改の年俸に効く。', 'Two of them counts as met. It tells on your next contract.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 監督との約束。自分から数字を口にして、シーズンの意味を変える。
///
/// 監督の与える目標（`_ObjectiveCard`）が**向こうから降ってくる数字**なのに対し、
/// こちらは自分で選んだ数字。大きく出るほど、果たしたときの見返りも
/// 届かなかったときの罰も大きい。取り消せない。
class _PromiseCard extends StatelessWidget {
  const _PromiseCard({required this.controller});

  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = controller.state!;
    final promise = state.promise;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (promise != null) {
      final stats = state.seasonStats;
      final kept = promise.achievedBy(stats);
      final short = promise.shortfall(stats);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(tr('監督との約束', 'Your word to the manager'), style: theme.textTheme.titleSmall),
                  ),
                  Text(promise.weight.label, style: muted),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    kept ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: kept
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promise.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kept ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  Text(short ?? tr('達成', 'met'), style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 6),
              Text(_effectText(promise), style: muted),
            ],
          ),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('監督に約束するか', 'Give the manager your word?'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('自分から数字を口にすれば、果たしたときに信頼と年俸が乗る。'
              '届かなければ両方を失う。第${PromiseOffers.window}節まで。', 'Name a number yourself and, if you reach it, both trust and wage go up. Fall short and you lose both. Until round ${PromiseOffers.window}.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => _choose(context),
                child: Text(tr('約束する', 'Give your word')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _effectText(ManagerPromise promise) {
    final w = promise.weight;
    final kept = ((w.salaryKept - 1) * 100).round();
    final broken = ((1 - w.salaryBroken) * 100).round();
    // 年俸が動くのは契約更改の年だけ（契約が残っていれば条件は動かない）。
    // 「+17%」とだけ書くと、動かない年に嘘になる。
    return tr('果たせば 信頼 +${w.trustKept}・契約更改 +$kept%　'
        '届かなければ 信頼 -${w.trustBroken}・契約更改 -$broken%', 'Keep it: trust +${w.trustKept}, next contract +$kept%.  Fall short: trust -${w.trustBroken}, next contract -$broken%');
  }

  Future<void> _choose(BuildContext context) async {
    final state = controller.state!;
    final offers = PromiseOffers.forState(state);
    final picked = await showModalBottomSheet<ManagerPromise>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('監督に何を約束するか', 'What you promise the manager'), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  tr('一度言えば取り消せない。シーズンの終わりに清算される。', 'Once said it cannot be taken back. It is settled at the end of the season.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final offer in offers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, offer),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    offer.label,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  offer.weight.label,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _effectText(offer),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('今は言わない', 'Say nothing')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) await controller.makePromise(picked);
  }
}

/// 自動で進めた区間のまとめ。
class _SimReportDialog extends StatelessWidget {
  const _SimReportDialog({required this.report});

  final SimReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(tr('${report.played}試合を消化', '${plural(report.played, 'game')} played')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('${report.won}勝 ${report.drawn}分 ${report.lost}敗', '${report.won}W ${report.drawn}D ${report.lost}L'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            tr('${report.goals}ゴール ${report.assists}アシスト'
            '${report.averageRating != null ? '  平均評価 ${report.averageRating!.toStringAsFixed(2)}' : ''}', '${plural(report.goals, 'goal')}, ${plural(report.assists, 'assist')}${report.averageRating != null ? '  average ${report.averageRating!.toStringAsFixed(2)}' : ''}'),
          ),
          const SizedBox(height: 12),
          Text(tr('止まった理由: ${report.stoppedBy.label}', 'Stopped because: ${report.stoppedBy.label}'), style: muted),
          if (report.injury != null) ...[
            const SizedBox(height: 4),
            Text(
              tr('${report.injury!.name}（${report.injury!.severity.label}、'
              '${report.injury!.matchesOut}試合の離脱）', '${report.injury!.name} (${report.injury!.severity.label}, out for ${plural(report.injury!.matchesOut, 'game')})'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('閉じる', 'Close')),
        ),
      ],
    );
  }
}

/// 今いるリーグと、その国の外国人ルール。
///
/// 制度そのものを画面の主役にはしない。「自分がどう扱われるか」が分かれば十分。
class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final country = World.byId(state.club.countryId);
    final foreign = Eligibility.isForeignIn(state.player.nationality, country);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しは `Expanded`。`Spacer` だけでは、見出しも右の数字も
            // 幅を持たない子なので、英語で見出しが長くなると `Spacer` が 0 に
            // なってから横へ溢れる。`Expanded` なら見出しが折り返し、
            // 右の数字は端に残る（日本語の見え方は変わらない）。
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('${country.name} ${state.club.tier}部', '${country.name}, tier ${state.club.tier}'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(tr('格 ${'★' * country.prestige}', 'Standing ${'★' * country.prestige}'), style: muted),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('${country.confederation.label} ・ ${country.calendar.label} ・ '
              '${country.clubsInTier(state.club.tier)}クラブ', '${country.confederation.label} - ${country.calendar.label} - ${country.clubsInTier(state.club.tier)} clubs'),
              style: muted,
            ),
            const SizedBox(height: 8),
            Text(tr('外国人ルール: ${country.foreignRule.summary}', 'Foreigner rule: ${country.foreignRule.summary}'), style: muted),
            const SizedBox(height: 4),
            Text(
              state.club.tier == 1
                  ? tr('上位${country.continentalSlots}クラブが大陸カップへ', 'The top ${country.continentalSlots} go into the continental cup')
                  : tr('上位2クラブが昇格、3〜6位はプレーオフ', 'The top two go up; 3rd to 6th go into a play-off'),
              style: muted,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  foreign ? Icons.flight_takeoff : Icons.home,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    foreign
                        ? tr('この国では外国人として扱われる', 'In this country you count as a foreigner')
                        : state.player.nationality.isHomegrownIn(country.id)
                        ? tr('この国の自国育ちとして扱われる', 'In this country you count as home-grown')
                        : tr('この国では自国民として扱われる', 'In this country you count as a national'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 登録メンバーから外れていることを伝えるカード。
///
/// 怪我でもないのに出られないのは分かりにくいので、理由まで書く。
class _OutOfSquadCard extends StatelessWidget {
  const _OutOfSquadCard({required this.state});

  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = World.byId(state.club.countryId);
    final foreign = Eligibility.isForeignIn(state.player.nationality, country);
    final reason = foreign ? tr('外国人枠が埋まっている', 'The foreigner slots are full') : tr('クラブの中で力が足りず、25人に入れなかった', 'You were not strong enough at the club to make the 25');

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('登録メンバー外', 'Left off the squad list'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('$reason。今季は試合に出られない。'
              'ローンで出場機会を探すか、移籍市場が開くのを待つことになる。', '$reason. You cannot play this season. Either look for minutes on loan, or wait for the transfer market to open.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 選手を「人間」として見るカード。性格・関係・お金・称号。
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.state, required this.controller});

  final CareerState state;
  final CareerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final p = state.player.personality;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 見出しと札は `Wrap`。`Row` だと、英語で札が長くなった分だけ
            // 横へ溢れる。入るうちは1行のままなので、日本語の見え方は変わらない。
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(tr('人となり', 'The person'), style: theme.textTheme.titleSmall),
                Chip(
                  label: Text(p.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final axis in PersonalityAxis.values)
              Tooltip(
                message: axis.description,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        // 日本語は「プロ意識」の4文字、英語は Professionalism の
                        // 15文字が一番長い。76 のままだと途中で割れる。
                        width: pick(76.0, 104.0),
                        child: Text(
                          axis.label,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${p[axis]}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: GaugeBar(
                          value: p[axis] / Personality.max,
                          height: 5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.player.nationality.all.length > 1) ...[
              const SizedBox(height: 12),
              Text(tr('代表を選ぶ', 'Choose a national team'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              // **どちらを選ぶかの取引を、数字で出す。**
              // 小さい国は呼ばれやすく、世界大会では勝ち上がれない。
              Text(
                tr('小さい国ほど呼ばれやすく、強い国ほど世界大会で勝ち上がる。', 'The smaller the country, the easier the call-up; the stronger it is, the further it goes at the world tournament.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in state.player.nationality.all)
                    ChoiceChip(
                      label: Text(
                        tr('${World.byId(id).name}'
                        '（総合力${Formulas.callUpLineFor(World.byId(id).prestige)}〜）', '${World.byId(id).name} (overall ${Formulas.callUpLineFor(World.byId(id).prestige)} and up)'),
                      ),
                      selected:
                          (state.nationalTeamId ??
                              state.player.nationality.primary) ==
                          id,
                      onSelected: (_) => controller.chooseNationalTeam(id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _relationLine(
                      tr('監督', 'Manager'),
                      state.relations.managerLabel,
                      state.relations.manager,
                      state.relations.managerNext,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    _relationLine(
                      tr('ロッカールーム', 'Dressing room'),
                      state.relations.teammatesLabel,
                      state.relations.teammates,
                      state.relations.teammatesNext,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 気持ちと疲労は「今週」タブの『今の状態』が数字で出している。
            // ここで言葉だけ繰り返すと、同じことを二度出すことになる。
            const SizedBox(height: 4),
            Text(
              tr('貯蓄 ${state.finances.savingsLabel} ・ 生活 ${state.finances.lifestyleLabel}'
              '${state.sponsor != null ? ' ・ ${state.sponsor!.name}と契約中' : ''}'
              '${state.charity ? ' ・ 財団' : ''}', 'Savings ${state.finances.savingsLabel} - living ${state.finances.lifestyleLabel}${state.sponsor != null ? ' - signed with ${state.sponsor!.name}' : ''}${state.charity ? ' - foundation' : ''}'),
              style: muted,
            ),
            if (state.reputation.awards.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(tr('称号', 'Honours'), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final a in state.reputation.awards)
                    Chip(
                      label: Text(a.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 身体の補正1つ。**符号で色を分ける**——得手と不得手が同じ色で
/// 並んでいると、身体が何を買って何を諦めたのかが読めない。
class _BonusTag extends StatelessWidget {
  const _BonusTag({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: up
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${up ? '+' : ''}$value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: up
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
