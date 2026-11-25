import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/attribute_context_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/injury_care.dart';
import '../logic/retirement_engine.dart';
import '../logic/dynamics_engine.dart';
import '../logic/match_engine.dart';
import '../logic/transfer_window.dart';
import '../models/attributes.dart';
import '../models/card_rules.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../models/player_traits.dart';
import '../models/team.dart';
import '../models/training_result.dart';
import '../data/glossary_entries.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'glossary_screen.dart';
import 'player_actions.dart';
import '../logic/scout_knowledge.dart';
import '../widgets/attribute_radar.dart';
import '../widgets/estimate_stars.dart';
import '../widgets/fm_panel.dart';
import '../widgets/growth_sparkline.dart';
import '../widgets/player_face_avatar.dart';
import '../logic/rating_words.dart';
import '../logic/player_popularity.dart';
import '../l10n/tr.dart';
import '../widgets/player_stat_chips.dart';
import '../logic/economy_scale.dart';

/// 選手の詳しい画面(FM の選手の画面に寄せた。2026-11-25)。
///
/// - 上の「操作」1つから、更新の交渉・移籍リスト・貸し出し・放出・比べるを
///   開く(以前は「契約」のタブに7つのボタンが縦に並んでいた)
/// - 概要: 左に所属・年俸・契約の残り・市場価値・調子・けが・序列、右に
///   総合力と五角形と今季の成績
/// - 能力: 能力の表・得意な位置の図・伸びの記録・似た選手
/// - 経歴: 季ごとの成績の表と移籍の歴
/// - 人柄: 性格を数字ではなく言葉で(FM と同じく、細かい値は隠す)
///
/// 自クラブの選手だけでなく、他クラブ・市場・所属なしの選手も開ける。
/// そのときの「操作」は、移籍金の提示・ローン・注目・スカウトに見させる・
/// 比べる(2026-11-25)。総合力と伸びしろは見立て(星と幅)で出す。
class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = game.anyPlayerById(playerId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(Tr.pick('選手', 'Player'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              Tr.pick('この選手は見つかりませんでした。引退などで居なくなった可能性があります。',
                  'This player could not be found. He may have retired.'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final tabBar = TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      tabs: [
        Tab(text: Tr.pick('概要', 'Overview')),
        Tab(text: Tr.pick('能力', 'Attributes')),
        Tab(text: Tr.pick('経歴', 'History')),
        Tab(text: Tr.pick('人柄', 'Character')),
      ],
    );
    final screen = MediaQuery.sizeOf(context);
    // 横画面は高さが 400 ほどしかない。名前とタブを1段に並べて縦を空ける。
    final wide = screen.width > screen.height;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: wide ? 52 : null,
          titleSpacing: wide && Navigator.of(context).canPop() ? 0 : null,
          title: wide
              ? Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: tabBar),
                  ],
                )
              : Text(p.name),
          bottom: wide ? null : tabBar,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.tonalIcon(
                key: const ValueKey('player-actions'),
                icon: const Icon(Icons.more_horiz, size: 18),
                label: Text(Tr.pick('操作', 'Actions')),
                onPressed: () =>
                    showPlayerActions(context, p, showOpenDetail: false),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: Tr.pick('能力値の意味を見る', 'What the attributes mean'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GlossaryScreen(
                    initialCategory: GlossaryCategory.attribute,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _OverviewTab(player: p),
            _AttributesTab(player: p),
            _HistoryTab(player: p),
            _CharacterTab(player: p),
          ],
        ),
      ),
    );
  }
}

/// 横幅が足りれば左右2列、狭ければ上下に積む。
class _TwoPane extends StatelessWidget {
  const _TwoPane({required this.left, required this.right, this.leftFlex = 5});

  final List<Widget> left;
  final List<Widget> right;
  final int leftFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 600) {
        return ListView(
          padding: const EdgeInsets.all(10),
          children: [...left, ...right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: leftFlex,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
                children: left),
          ),
          Expanded(
            flex: 9 - leftFlex,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
                children: right),
          ),
        ],
      );
    });
  }
}

/// 概要: 左に所属と契約・体調、右に総合力・五角形・今季の成績。
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = player;
    final mine = game.isMyPlayer(p.id);
    final club = game.clubOfPlayer(p.id);
    final stats = game.seasonStatsForAll([p.id])[p.id] ??
        const PlayerSeasonStats();
    final form = game.recentFormForAll([p.id])[p.id];
    final subtle = SemanticColors.subtleText(context);
    final error = SemanticColors.ink(context, Colors.redAccent);
    final clause = game.releaseClauseOf(p);
    final starting = club?.startingXI.contains(p.id) ?? false;

    // 序列: 自クラブは約束した立場、他クラブは先発か控えか。
    final standing = mine
        ? p.squadStatus.label
        : (club == null
            ? '—'
            : (starting
                ? Tr.pick('先発', 'Starter')
                : Tr.pick('控え', 'Backup')));

    String injuryText() {
      if (p.isInjured) {
        return p.injuryType == null
            ? Tr.pick('負傷中(あと${p.injuryWeeks}週)',
                'Injured (${Tr.plural(p.injuryWeeks, 'week')})')
            : Tr.pick('${InjuryCare.describe(p)}(あと${p.injuryWeeks}週)',
                '${InjuryCare.describe(p)} (${Tr.plural(p.injuryWeeks, 'week')})');
      }
      if (p.isSuspended) {
        return Tr.pick('出場停止(あと${p.suspendedMatches}試合)',
            'Suspended (${Tr.plural(p.suspendedMatches, 'match', 'matches')})');
      }
      if (p.isOnInternationalDuty) {
        return p.onTournamentLeave
            ? _tournamentLeaveText(game)
            : Tr.pick('代表召集中(あと${p.internationalDutyWeeksRemaining}週)',
                'International duty (${Tr.plural(p.internationalDutyWeeksRemaining, 'week')})');
      }
      return Tr.pick('なし', 'None');
    }

    final left = <Widget>[
      Row(
        children: [
          PlayerFaceAvatar.of(
            p,
            game,
            size: 48,
            highlighted: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.pick(
                      '${p.position.fullLabel}・${p.age}歳(誕生日 ${p.birthMonth}月${p.birthDay}日)',
                      '${p.position.fullLabel} • ${p.age} (birthday ${TransferWindowCalendar.formatMonthDay(p.birthdayIn(2001))})'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if (p.secondaryPositions.isNotEmpty)
                  Text(
                    Tr.pick(
                        'ほかにこなせる位置: ${p.secondaryPositions.map((s) => s.label).join(', ')}',
                        "Also plays: ${p.secondaryPositions.map((s) => s.label).join(', ')}"),
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      _StatusChips(player: p, club: club, mine: mine),
      const SizedBox(height: 6),
      FmPanel(
        title: Tr.pick('所属と契約', 'Club and contract'),
        child: Column(
          children: [
            FmRow(
              label: Tr.pick('所属', 'Club'),
              value: p.isLoanedOut
                  ? Tr.pick('${club?.name ?? ''}(${p.loanedOutToClubName}へ貸し出し中)',
                      '${club?.name ?? ''} (on loan at ${p.loanedOutToClubName})')
                  : (club?.name ??
                      game.clubNameOf(p.id) ??
                      Tr.pick('所属なし', 'Free agent')),
            ),
            FmRow(
              label: Tr.pick('年俸', 'Salary'),
              value: formatMoney(annualFromWeekly(p.wage)),
            ),
            FmRow(
              label: Tr.pick('契約の残り', 'Contract'),
              value: p.isLoan
                  ? (p.loanEndDate != null
                      ? Tr.pick(
                          'ローン(${TransferWindowCalendar.formatMonthDay(p.loanEndDate!)}まで)',
                          'Loan (until ${TransferWindowCalendar.formatMonthDay(p.loanEndDate!)})')
                      : Tr.pick('ローン(残り${p.loanWeeksRemaining}週)',
                          'Loan (${Tr.plural(p.loanWeeksRemaining, 'week')} left)'))
                  : (club == null && !mine
                      ? Tr.pick('なし', 'None')
                      : ContractEngine.contractLabel(p)),
              valueColor: !p.isLoan && p.contractYearsRemaining <= 1 &&
                      club != null
                  ? SemanticColors.ink(context, Colors.orange)
                  : null,
            ),
            _ValueRow(player: p),
            if (clause != null)
              FmRow(
                label: Tr.pick('リリース条項', 'Release clause'),
                value: formatMoney(clause),
              ),
            FmRow(label: Tr.pick('序列', 'Squad status'), value: standing),
            if (mine && p.appearanceFee > 0)
              FmRow(
                label: Tr.pick('出場手当', 'Appearance fee'),
                value: Tr.pick('${formatMoney(p.appearanceFee)}/試合',
                    '${formatMoney(p.appearanceFee)} a game'),
              ),
          ],
        ),
      ),
      FmPanel(
        title: Tr.pick('体調', 'Condition'),
        child: Column(
          children: [
            FmRow(
              label: Tr.pick('調子', 'Form'),
              value: form == null
                  ? Tr.pick('まだ出ていない', 'No games yet')
                  : Tr.pick(
                      '${RatingWords.form(form)}(直近の採点 ${form.toStringAsFixed(1)})',
                      '${RatingWords.form(form)} (recent ${form.toStringAsFixed(1)})'),
            ),
            FmRow(
              label: Tr.pick('けが', 'Injury'),
              value: injuryText(),
              valueColor: p.isInjured || p.isSuspended ? error : null,
            ),
            FmRow(
              label: Tr.pick('疲れ', 'Fatigue'),
              value: '${p.fatigue}',
              valueColor: p.fatigue >= 70 ? error : null,
            ),
            FmRow(
              label: Tr.pick('実戦の感覚', 'Match sharpness'),
              value: '${p.matchSharpness}',
              valueColor: p.matchSharpness < 40 ? error : null,
            ),
            FmRow(
              label: Tr.pick('気持ち', 'Morale'),
              value: _happinessWord(p),
              valueColor: p.wantsTransfer ? error : null,
            ),
          ],
        ),
      ),
      if (p.yellowCards > 0) _leagueYellowLine(context, p, game.leagueCardRulesNow),
      for (final (left, label) in [
        (p.cupSuspendedMatches, Tr.pick('国内カップ戦', 'domestic cups')),
        (p.continentalSuspendedMatches, Tr.pick('大陸大会', 'European competition')),
      ])
        if (left > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              Tr.pick('$labelは出場停止中(あと$left試合)',
                  'Suspended in $label (${Tr.plural(left, 'match', 'matches')} left)'),
              style: TextStyle(color: error, fontSize: 12),
            ),
          ),
      // 高齢の選手は、契約を残していてもシーズン終了時に引退しうる。
      if (mine && RetirementEngine.retirementChance(p) > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            Tr.pick(
                '今シーズン終了時に引退する可能性: ${(RetirementEngine.retirementChance(p) * 100).round()}%(契約が残っていても引退します)',
                'Chance he retires at the end of this season: ${(RetirementEngine.retirementChance(p) * 100).round()}% (even with time left on his deal)'),
            style: TextStyle(fontSize: 12, color: subtle),
          ),
        ),
    ];

    final right = <Widget>[
      _OverallBlock(player: p),
      const SizedBox(height: 4),
      // 他のクラブの選手は、見え60%までは能力の形を出さない(見立て)。
      if (mine || game.knowledgeOf(p) >= 60)
        Center(child: AttributeRadar(player: p, size: 170))
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            Tr.pick('能力の形は、スカウトの見えが60%を超えると出ます。',
                'The attribute shape shows once your scouts know him 60% or more.'),
            style: TextStyle(fontSize: 12, color: subtle),
          ),
        ),
      FmPanel(
        title: Tr.pick('今季の成績(リーグ戦)', 'This season (league)'),
        child: Column(
          children: [
            FmRow(
                label: Tr.pick('出場', 'Appearances'),
                value: '${stats.appearances}'),
            FmRow(label: Tr.pick('得点', 'Goals'), value: '${stats.goals}'),
            FmRow(
                label: Tr.pick('平均採点', 'Average rating'),
                value: stats.averageRating?.toStringAsFixed(2) ?? '—'),
            FmRow(
                label: Tr.pick('警告・退場', 'Yellow / red'),
                value: '${stats.yellowCards} / ${stats.redCards}'),
            FmRow(
                label: Tr.pick('通算(このゲームで)', 'Career (in this game)'),
                value: Tr.pick(
                    '${p.careerAppearances}試合 ${p.careerGoals}得点',
                    '${Tr.plural(p.careerAppearances, 'app')}, ${Tr.plural(p.careerGoals, 'goal')}')),
          ],
        ),
      ),
      if (p.trait != null)
        Text(
          Tr.pick('特性: ${p.trait!.label} — ${p.trait!.description}',
              'Trait: ${p.trait!.label} — ${p.trait!.description}'),
          style: TextStyle(fontSize: 12, color: subtle),
        ),
    ];
    return _TwoPane(left: left, right: right);
  }
}

/// 満足度を言葉で(数字は人柄の画面でも出さない)。
String _happinessWord(Player p) {
  if (p.wantsTransfer) return Tr.pick('移籍を望んでいる', 'Wants to leave');
  if (p.happiness >= 75) return Tr.pick('とても満足', 'Very happy');
  if (p.happiness >= 55) return Tr.pick('満足', 'Content');
  if (p.happiness >= 40) return Tr.pick('ふつう', 'Okay');
  return Tr.pick('不満がある', 'Unhappy');
}

/// 市場価値の行(押すと内訳)。
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final b = p.marketValueBreakdown;
    final detail = Tr.pick(
        '内訳: 基礎${formatMoney(b.base.round())} + 伸びしろ${formatMoney(b.potentialBonus.round())} を年齢×${b.ageFactor.toStringAsFixed(2)} ポジション×${b.positionFactor.toStringAsFixed(2)} 性格×${b.personalityFactor.toStringAsFixed(2)} 統率力×${b.leadershipFactor.toStringAsFixed(2)}${b.tournamentFactor != 1 ? ' 夏の大会の活躍×${b.tournamentFactor.toStringAsFixed(2)}' : ''}',
        'Breakdown: base ${formatMoney(b.base.round())} + potential ${formatMoney(b.potentialBonus.round())}, times age ${b.ageFactor.toStringAsFixed(2)}, position ${b.positionFactor.toStringAsFixed(2)}, personality ${b.personalityFactor.toStringAsFixed(2)}, leadership ${b.leadershipFactor.toStringAsFixed(2)}${b.tournamentFactor != 1 ? ', summer tournament ${b.tournamentFactor.toStringAsFixed(2)}' : ''}');
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(Tr.pick('市場価値の内訳', 'How the value is worked out')),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        ),
      ),
      child: FmRow(
        label: Tr.pick('市場価値(押すと内訳)', 'Value (tap for breakdown)'),
        value: formatMoney(p.marketValue),
      ),
    );
  }
}

/// 立場・印の札(スタメン・キャプテン・リーダー・ローン・移籍希望など)。
class _StatusChips extends StatelessWidget {
  const _StatusChips(
      {required this.player, required this.club, required this.mine});

  final Player player;
  final Team? club;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final team = club;
    Widget chip(String text, {Color? color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.15),
            border: Border.all(
                color: color ?? Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color == null
                      ? null
                      : SemanticColors.ink(context, color))),
        );
    final popularity = PlayerPopularityEngine.popularity(p);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (team != null && team.startingXI.contains(p.id))
          chip(Tr.pick('スタメン', 'Starter'), color: Colors.blue),
        if (team?.captainId == p.id)
          chip(Tr.pick('キャプテン', 'Captain'), color: Colors.amber),
        if (team?.viceCaptainId == p.id)
          chip(Tr.pick('副キャプテン', 'Vice Captain'), color: Colors.blueGrey),
        // ダイナミクス: 影響力上位のチームリーダー。
        if (mine && team != null && DynamicsEngine.isTeamLeader(team, p.id))
          chip(Tr.pick('チームリーダー', 'Team Leader'), color: Colors.deepOrange),
        if (p.academyGraduate)
          chip(Tr.pick('生え抜き', 'Academy graduate'), color: Colors.green),
        if (p.isLoan) chip(Tr.pick('ローン加入中', 'On loan here'), color: Colors.indigo),
        if (p.wantsTransfer)
          chip(Tr.pick('移籍を希望している', 'Wants a move away'),
              color: Colors.redAccent),
        if (p.isTransferListed)
          chip(Tr.pick('移籍リスト登録中', 'Transfer listed'), color: Colors.orange),
        if (p.isOnInternationalDuty)
          chip(
              p.onTournamentLeave
                  ? Tr.pick('大会明けの休み', 'Post-tournament break')
                  : Tr.pick('代表召集中', 'On international duty'),
              color: Colors.blueAccent),
        chip(Tr.pick(
            '人気: ${PlayerPopularityEngine.label(popularity)}',
            'Popularity: ${PlayerPopularityEngine.label(popularity)}')),
      ],
    );
  }
}

/// 総合力(大きく)・評価の言葉・伸びしろ・今季の伸び。
class _OverallBlock extends StatelessWidget {
  const _OverallBlock({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = player;
    final subtle = SemanticColors.subtleText(context);
    PlayerGrowthSummary? latestGrowth;
    for (final r in game.lastTrainingResults) {
      if (r.playerId == p.id) {
        latestGrowth = r;
        break;
      }
    }
    final seasonStart = game.save?.seasonStartOverallByPlayerId[p.id];
    final seasonDelta = seasonStart != null ? p.overall - seasonStart : null;
    // 他のクラブ・所属なしの選手は、本当の値ではなくスカウトの見立てを
    // 星と幅で出す(2026-11-25。FM と同じく見えている分だけ)。
    if (!game.isMyPlayer(p.id)) {
      final known = game.knowledgeOf(p);
      final ref = EstimateStars.referenceOf(game.userTeam);
      Widget line(String caption, (int, int)? r) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                    width: 120,
                    child: Text(caption,
                        style: TextStyle(fontSize: 12, color: subtle))),
                EstimateStars(range: r, reference: ref, size: 16),
                const SizedBox(width: 6),
                Text(ScoutKnowledge.label(r),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          );
      return Column(
        key: const ValueKey('detail-estimate'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(Tr.pick('総合(見立て)', 'OVR (est.)'), game.overallEstimate(p)),
          line(Tr.pick('伸びしろ(見立て)', 'POT (est.)'),
              game.potentialEstimate(p)),
          Text(
            known >= 100
                ? Tr.pick('スカウトの報告が揃っています(見え100%)',
                    'Fully scouted (100% known)')
                : Tr.pick(
                    '見え$known%: 星の薄い所が、まだ見えていない幅です。星3つが自クラブの先発の平均。${game.isScoutingPlayer(p.id) ? 'スカウトが見ています。' : '「操作」からスカウトに見させると狭まります。'}',
                    '$known% known: the faint stars are what your scouts cannot see yet. Three stars is your starters\' average. ${game.isScoutingPlayer(p.id) ? 'Your scouts are on him.' : 'Have him scouted (Actions) to narrow it.'}'),
            style: TextStyle(fontSize: 11, color: subtle),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Tr.pick('総合力', 'Overall'),
                style: TextStyle(fontSize: 11, color: subtle)),
            Text(
              '${p.overall}',
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -1,
                color: OverallBadge.colorFor(context, p.overall),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(RatingWords.forOverall(p.overall),
                style: TextStyle(fontSize: 11, color: subtle)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Tr.pick('伸びしろ: ${game.growthRoomWordFor(p)}',
                    'Room to grow: ${game.growthRoomWordFor(p)}'),
                style: const TextStyle(fontSize: 12),
              ),
              if (seasonDelta != null)
                Text(
                  Tr.pick(
                      '今シーズンの成長: ${seasonDelta > 0 ? '+' : ''}$seasonDelta',
                      "Growth this season: ${seasonDelta > 0 ? '+' : ''}$seasonDelta"),
                  style: TextStyle(
                    fontSize: 12,
                    color: seasonDelta > 0
                        ? SemanticColors.ink(context, Colors.green)
                        : subtle,
                    fontWeight:
                        seasonDelta > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              if (latestGrowth != null && latestGrowth.overallDelta != 0)
                Text(
                  Tr.pick(
                      '今週 ${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta}',
                      "This week ${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta}"),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: latestGrowth.overallDelta > 0
                        ? SemanticColors.ink(context, Colors.green)
                        : SemanticColors.ink(context, Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 能力: 能力の表・効いている能力・得意な位置の図・伸びの記録・似た選手。
class _AttributesTab extends StatelessWidget {
  const _AttributesTab({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = player;
    final categories = [
      AttributeCategory.technical,
      AttributeCategory.mental,
      AttributeCategory.physical,
      if (p.position == Position.gk) AttributeCategory.goalkeeping,
    ];
    final keys =
        AttributeContextEngine.keyAttributesFor(p).map((k) => k.key).toSet();
    final similar = game.similarPlayers(p);
    final subtle = SemanticColors.subtleText(context);
    final seasonStart = game.save?.seasonStartOverallByPlayerId[p.id];

    final left = <Widget>[
      _AttributeGrid(
          player: p,
          categories: categories,
          keys: keys,
          knowledge: game.isMyPlayer(p.id) ? 100 : game.knowledgeOf(p)),
      _KeyAttributesCard(player: p),
    ];
    final right = <Widget>[
      FmPanel(
        key: const ValueKey('position-map'),
        title: Tr.pick('得意な位置', 'Positions'),
        child: _PositionMap(player: p),
      ),
      FmPanel(
        title: Tr.pick('伸びの記録', 'Progress'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick(
                  '伸びしろ: ${game.growthRoomWordFor(p)}${p.growthType != PlayerGrowthType.balanced ? '・${p.growthType.label}' : ''}',
                  'Room to grow: ${game.growthRoomWordFor(p)}${p.growthType != PlayerGrowthType.balanced ? ' • ${p.growthType.label}' : ''}'),
              style: const TextStyle(fontSize: 12),
            ),
            if (seasonStart != null)
              Text(
                Tr.pick('今季の初め $seasonStart → 今 ${p.overall}',
                    'Season start $seasonStart → now ${p.overall}'),
                style: TextStyle(fontSize: 12, color: subtle),
              ),
            if (p.overallHistory.length >= 2) ...[
              const SizedBox(height: 4),
              Text(
                p.overallHistory.toSet().length > 1
                    ? Tr.pick(
                        '直近${p.overallHistory.length}節: ${p.overallHistory.first} → ${p.overallHistory.last}',
                        'Last ${p.overallHistory.length} matchdays: ${p.overallHistory.first} → ${p.overallHistory.last}')
                    : Tr.pick('直近${p.overallHistory.length}節は${p.overallHistory.last}のまま',
                        'Unchanged at ${p.overallHistory.last} over the last ${p.overallHistory.length} matchdays'),
                style: TextStyle(fontSize: 11, color: subtle),
              ),
              if (p.overallHistory.toSet().length > 1)
                GrowthSparkline(history: p.overallHistory, height: 44),
            ] else
              Text(
                Tr.pick('まだ伸びの記録がありません(試合の節ごとに付きます)。',
                    'No progress recorded yet (logged every matchday).'),
                style: TextStyle(fontSize: 11, color: subtle),
              ),
          ],
        ),
      ),
      FmPanel(
        key: const ValueKey('similar-players'),
        title: Tr.pick('似た選手(同じ位置・近い年齢)', 'Similar players'),
        padding: EdgeInsets.zero,
        child: similar.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: Text(Tr.pick('見つかりませんでした。', 'None found.'),
                    style: const TextStyle(fontSize: 12)),
              )
            : Column(
                children: [
                  for (final s in similar)
                    InkWell(
                      onTap: () => openPlayerDetail(context, s.player.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.player.name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      Tr.pick(
                                          '${s.club.name}・${s.player.position.label}・${s.player.age}歳',
                                          '${s.club.name} • ${s.player.position.label} • ${s.player.age}'),
                                      style:
                                          TextStyle(fontSize: 11, color: subtle),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            OverallBadge(overall: s.player.overall),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: Text(formatMoney(s.player.marketValue),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ];
    // 能力の表は4つの分類を横に並べるので、左を広くする。
    return _TwoPane(left: left, right: right, leftFlex: 6);
  }
}

/// 得意な位置の図(FM の選手の画面の小さなピッチ)。本職・こなせる・
/// 慣れてきた・不慣れで色を分ける。
class _PositionMap extends StatelessWidget {
  const _PositionMap({required this.player});

  final Player player;

  /// 縦のピッチの上の位置(x: 左0〜右1、y: 相手のゴール0〜自分のゴール1)。
  static const _spots = <Position, Offset>{
    Position.st: Offset(0.5, 0.1),
    Position.aml: Offset(0.15, 0.27),
    Position.amc: Offset(0.5, 0.27),
    Position.amr: Offset(0.85, 0.27),
    Position.ml: Offset(0.15, 0.44),
    Position.mc: Offset(0.5, 0.44),
    Position.mr: Offset(0.85, 0.44),
    Position.wbl: Offset(0.12, 0.6),
    Position.dm: Offset(0.5, 0.6),
    Position.wbr: Offset(0.88, 0.6),
    Position.dl: Offset(0.15, 0.76),
    Position.dc: Offset(0.5, 0.76),
    Position.dr: Offset(0.85, 0.76),
    Position.gk: Offset(0.5, 0.92),
  };

  /// 0: 不慣れ 1: 慣れてきた 2: こなせる 3: 本職。
  int _level(Position pos) {
    if (pos == player.position) return 3;
    if (player.secondaryPositions.contains(pos)) return 2;
    if (player.familiarityFor(pos) >= 50) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = SemanticColors.positive(context);
    Color colorOf(int level) => switch (level) {
          3 => green,
          2 => green.withValues(alpha: 0.55),
          1 => SemanticColors.ink(context, Colors.amber, min: 3),
          _ => scheme.outlineVariant,
        };
    final legend = [
      (3, Tr.pick('本職', 'Natural')),
      (2, Tr.pick('こなせる', 'Accomplished')),
      (1, Tr.pick('慣れてきた', 'Getting used to it')),
      (0, Tr.pick('不慣れ', 'Unfamiliar')),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          height: 170,
          child: LayoutBuilder(builder: (context, c) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.06),
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // 真ん中の線。
                Positioned(
                  left: 0,
                  right: 0,
                  top: c.maxHeight / 2,
                  child: Container(height: 1, color: scheme.outlineVariant),
                ),
                for (final e in _spots.entries)
                  Positioned(
                    left: e.value.dx * c.maxWidth - 15,
                    top: e.value.dy * c.maxHeight - 9,
                    child: Container(
                      key: ValueKey('pos-spot-${e.key.name}'),
                      width: 30,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorOf(_level(e.key)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          e.key.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _level(e.key) >= 2
                                ? Colors.white
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (level, label) in legend)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Container(
                      width: 14,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorOf(level),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(label,
                            style: const TextStyle(fontSize: 11))),
                  ]),
                ),
              const SizedBox(height: 4),
              Text(
                Tr.pick('本職の外で使うと出来が落ちます。出るたびに慣れていきます。',
                    'He plays worse out of position, but gets used to a role the more he plays it.'),
                style: TextStyle(
                    fontSize: 11, color: SemanticColors.subtleText(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 経歴: 季ごとの成績の表と移籍の歴。
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = player;
    final club = game.clubOfPlayer(p.id);
    final subtle = SemanticColors.subtleText(context);
    final theme = Theme.of(context);
    // 今季の行は試合の結果からその場で作る(季の終わりに記録へ移る)。
    final inMyLeague =
        club != null && game.save!.league.teams.any((t) => t.id == club.id);
    final now = game.seasonStatsForAll([p.id])[p.id] ??
        const PlayerSeasonStats();
    final current = PlayerCareerLine(
      seasonEndYear: Player.contractClockYear,
      club: club?.name ?? Tr.pick('所属なし', 'Free agent'),
      apps: now.appearances,
      goals: now.goals,
      rating: now.averageRating,
      loan: p.isLoan,
    );
    final lines = [
      if (club != null && inMyLeague) current,
      ...p.careerLog.reversed,
    ];
    final head =
        TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtle);
    const cell = TextStyle(fontSize: 12);

    Widget seasonRow(PlayerCareerLine l, {bool now = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: now ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
            border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(children: [
            SizedBox(
                width: 64,
                child: Text(l.seasonLabel,
                    style: cell.copyWith(fontWeight: FontWeight.w600))),
            Expanded(
              child: Text(
                  l.loan
                      ? Tr.pick('${l.club}(ローン)', '${l.club} (loan)')
                      : l.club,
                  style: cell,
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
                width: 40,
                child: Text('${l.apps}', textAlign: TextAlign.center, style: cell)),
            SizedBox(
                width: 40,
                child:
                    Text('${l.goals}', textAlign: TextAlign.center, style: cell)),
            SizedBox(
                width: 44,
                child: Text(l.rating?.toStringAsFixed(2) ?? '—',
                    textAlign: TextAlign.center, style: cell)),
          ]),
        );

    String kindLabel(PlayerMoveKind k) => switch (k) {
          PlayerMoveKind.transfer => Tr.pick('完全移籍', 'Transfer'),
          PlayerMoveKind.free => Tr.pick('移籍金なし', 'Free'),
          PlayerMoveKind.loan => Tr.pick('ローン', 'Loan'),
          PlayerMoveKind.loanReturn => Tr.pick('ローンから戻る', 'Loan return'),
          PlayerMoveKind.preContract => Tr.pick('仮契約', 'Pre-contract'),
          PlayerMoveKind.release => Tr.pick('契約解除', 'Released'),
        };

    final left = <Widget>[
      FmPanel(
        key: const ValueKey('career-table'),
        title: Tr.pick('季ごとの成績(リーグ戦)', 'Season by season (league)'),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(children: [
                SizedBox(width: 64, child: Text(Tr.pick('季', 'Season'), style: head)),
                Expanded(child: Text(Tr.pick('クラブ', 'Club'), style: head)),
                SizedBox(
                    width: 40,
                    child: Text(Tr.pick('出場', 'Apps'),
                        textAlign: TextAlign.center, style: head)),
                SizedBox(
                    width: 40,
                    child: Text(Tr.pick('得点', 'Gls'),
                        textAlign: TextAlign.center, style: head)),
                SizedBox(
                    width: 44,
                    child: Text(Tr.pick('採点', 'Rat'),
                        textAlign: TextAlign.center, style: head)),
              ]),
            ),
            for (var i = 0; i < lines.length; i++)
              seasonRow(lines[i], now: i == 0 && club != null && inMyLeague),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                p.careerLog.isEmpty
                    ? Tr.pick('前の季の記録はありません。今季から季の終わりごとに記録します。',
                        'No earlier seasons on record. Each season is added when it ends.')
                    : Tr.pick('通算(このゲームで): ${p.careerAppearances}試合 ${p.careerGoals}得点',
                        'Career (in this game): ${Tr.plural(p.careerAppearances, 'app')}, ${Tr.plural(p.careerGoals, 'goal')}'),
                style: TextStyle(fontSize: 11, color: subtle),
              ),
            ),
          ],
        ),
      ),
    ];
    final right = <Widget>[
      FmPanel(
        key: const ValueKey('move-history'),
        title: Tr.pick('移籍の歴', 'Transfer history'),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in p.moveLog.reversed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m.from} → ${m.to}',
                        style: cell.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      [
                        Tr.pick('${m.date.year}年${m.date.month}月${m.date.day}日',
                            '${TransferWindowCalendar.formatMonthDay(m.date)} ${m.date.year}'),
                        kindLabel(m.kind),
                        if (m.fee > 0) formatMoney(m.fee),
                      ].join(Tr.pick('・', ' • ')),
                      style: TextStyle(fontSize: 11, color: subtle),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                p.academyGraduate
                    ? Tr.pick('${club?.name ?? ''}のユース出身(生え抜き)。',
                        'Came through the ${club?.name ?? ''} academy.')
                    : (p.moveLog.isEmpty
                        ? Tr.pick('移籍の記録はまだありません(これからの移籍を記録します)。',
                            'No moves on record yet; future moves will be listed here.')
                        : ''),
                style: TextStyle(fontSize: 11, color: subtle),
              ),
            ),
          ],
        ),
      ),
      FmPanel(
        title: Tr.pick('けがの歴', 'Injury history'),
        child: Text(
          p.injuryHistoryCounts.isEmpty
              ? Tr.pick('大きなけがの記録はありません。', 'No injuries on record.')
              : p.injuryHistoryCounts.entries.map((e) {
                  final type = InjuryType.values.firstWhere(
                      (t) => t.name == e.key,
                      orElse: () => InjuryType.bruise);
                  return Tr.pick(
                      '${type.label}${e.value}回', '${type.label} x${e.value}');
                }).join(Tr.pick('・', ' • ')),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ];
    return _TwoPane(left: left, right: right, leftFlex: 5);
  }
}

/// 人柄: 性格・6つの軸・約束・移籍の気持ち・けがのしやすさ・特性。数字は
/// 出さず、言葉で(FM と同じく、細かい値は隠す)。
class _CharacterTab extends StatelessWidget {
  const _CharacterTab({required this.player});

  final Player player;

  /// 人柄の軸(1〜20)を言葉にする。
  static String traitWord(int v) {
    if (v >= 17) return Tr.pick('とても強い', 'Very high');
    if (v >= 13) return Tr.pick('強い', 'High');
    if (v >= 8) return Tr.pick('ふつう', 'Average');
    if (v >= 4) return Tr.pick('弱い', 'Low');
    return Tr.pick('とても弱い', 'Very low');
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final p = player;
    final subtle = SemanticColors.subtleText(context);
    final t = p.traits;
    final latestGrowth = game.lastTrainingResults
        .where((r) => r.playerId == p.id)
        .firstOrNull;
    final left = <Widget>[
      FmPanel(
        title: Tr.pick('性格: ${p.personality.label}', 'Personality: ${p.personality.label}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.personality.description,
                style: TextStyle(fontSize: 12, color: subtle)),
            const SizedBox(height: 6),
            for (final a in TraitAxis.values)
              Tooltip(
                message: a.description,
                triggerMode: TooltipTriggerMode.tap,
                child: FmRow(label: a.label, value: traitWord(t[a])),
              ),
          ],
        ),
      ),
    ];
    final right = <Widget>[
      FmPanel(
        title: Tr.pick('気持ちと約束', 'Mood and promises'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FmRow(label: Tr.pick('気持ち', 'Morale'), value: _happinessWord(p)),
            if (p.promisedStatus != null)
              Text(
                p.promiseBroken
                    ? Tr.pick(
                        '加入のときの約束(${p.promisedStatus!.label})を破られたとして、移籍を願い出ている',
                        'Says you broke the promise made when he joined (${p.promisedStatus!.label}) and wants to leave')
                    : Tr.pick('${p.promisedStatus!.label}として扱うと約束している',
                        'Promised ${p.promisedStatus!.label} billing'),
                style: TextStyle(
                    fontSize: 12,
                    color: p.promiseBroken
                        ? SemanticColors.ink(context, Colors.redAccent)
                        : subtle),
              ),
            if (p.wantsTransfer)
              Text(
                p.promiseBroken
                    ? Tr.pick('約束を破られたため、移籍を希望している',
                        'Wants a move because you broke your word')
                    : Tr.pick('不満が募り、移籍を希望している',
                        'Unhappy enough to want a move'),
                style: TextStyle(
                    fontSize: 12,
                    color: SemanticColors.ink(context, Colors.redAccent)),
              ),
            FmRow(
              label: Tr.pick('けがのしやすさ', 'Injury proneness'),
              value: p.injuryPronenessLabel,
              valueColor: p.injuryProneness >= 14
                  ? SemanticColors.negative(context)
                  : null,
            ),
            if (p.role != PlayerRole.standard)
              Text(
                Tr.pick('ロール: ${p.role.label} — ${p.role.description}',
                    'Role: ${p.role.label} — ${p.role.description}'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.ink(context, Colors.teal)),
              ),
            if (p.growthType != PlayerGrowthType.balanced)
              Text(
                Tr.pick(
                    '成長タイプ: ${p.growthType.label} — ${p.growthType.description}',
                    'Growth: ${p.growthType.label} — ${p.growthType.description}'),
                style: TextStyle(
                    fontSize: 12,
                    color: SemanticColors.ink(context, Colors.indigo)),
              ),
            if (latestGrowth != null && latestGrowth.isBreakthrough)
              Text(
                Tr.pick('今週、才能開花が発生しました', 'A breakthrough came this week'),
                style: TextStyle(
                  fontSize: 12,
                  color: SemanticColors.ink(context, Colors.amber, min: 3),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
      if (p.trait != null)
        FmPanel(
          title: Tr.pick('特性: ${p.trait!.label}', 'Trait: ${p.trait!.label}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.trait!.description, style: const TextStyle(fontSize: 12)),
              // 能力値で発動する特性は、条件に届いていないと何も起きない。
              Builder(builder: (context) {
                final gate = MatchEngine.attributeGatedTraits[p.trait!];
                if (gate == null) return const SizedBox.shrink();
                final current = p.attributeValue(gate.attribute);
                final active = current >= gate.threshold;
                final gain = ((gate.bonus - 1) * 100).round();
                return Text(
                  active
                      ? Tr.pick(
                          '発動中: ${AttributeKeys.labelOf(gate.attribute)}$current(${gate.threshold}以上)→ 出来が+$gain%',
                          'Active: ${AttributeKeys.labelOf(gate.attribute)} $current (needs ${gate.threshold}) → +$gain% to his display')
                      : Tr.pick(
                          '未発動: ${AttributeKeys.labelOf(gate.attribute)}が${gate.threshold}以上で+$gain%(現在$current / あと${gate.threshold - current})',
                          'Dormant: needs ${AttributeKeys.labelOf(gate.attribute)} ${gate.threshold} for +$gain% (now $current, ${gate.threshold - current} to go)'),
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? SemanticColors.positive(context) : subtle,
                  ),
                );
              }),
            ],
          ),
        ),
    ];
    return _TwoPane(left: left, right: right, leftFlex: 4);
  }
}

/// この選手で効いている能力を、理由つきで並べるカード。
///
/// 42項目を全部見せても、どれを見ればいいのかは分からない。ロールが
/// 見ている能力・特性の発動条件・そのポジションの総合力に効く能力——
/// **実際に計算へ使われているもの**だけを拾って出す。
class _KeyAttributesCard extends StatelessWidget {
  final Player player;
  const _KeyAttributesCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final keys = AttributeContextEngine.keyAttributesFor(
      player,
      league: gameState.save?.league,
    );
    if (keys.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('この選手で効いている能力', 'What matters for this player'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${AttributeKeys.labelOf(k.key)} ${k.value}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (k.standingLabel != null)
                          Text(
                            k.standingLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              color: SemanticColors.subtleText(context),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      k.why,
                      style: TextStyle(
                        fontSize: 11,
                        color: SemanticColors.subtleText(context),
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

/// 夏の大会のあとの休みの説明(合流の日つき)。
String _tournamentLeaveText(GameState game) {
  final back = game.tournamentReturnDate;
  final name = game.summerTournament?.name ?? '';
  if (back == null) {
    return Tr.pick('夏の大会のあとの休み(まもなく合流)', 'Post-tournament break (back soon)');
  }
  final day = TransferWindowCalendar.formatMonthDay(back);
  return Tr.pick('$nameのあとの休み($dayに合流するまで出場不可)',
      'Break after the $name (cannot play until he rejoins on $day)');
}

/// FM 風の能力の一覧。分類ごとに列を分け、値の高さで色を変える。
/// この選手で効いている能力には印を付ける。
class _AttributeGrid extends StatelessWidget {
  final Player player;
  final List<AttributeCategory> categories;
  final Set<String> keys;

  /// どれだけ見えているか(%)。100 未満なら値は見立ての幅で出す
  /// (他のクラブの選手。2026-11-25)。
  final int knowledge;
  const _AttributeGrid({
    required this.player,
    required this.categories,
    required this.keys,
    this.knowledge = 100,
  });

  /// 能力[k]の表示と、色を決める値。
  (String, int) _shown(String k) {
    final v = player.attributeValue(k);
    if (knowledge >= 100) return ('$v', v);
    final salt = 10 + k.codeUnits.fold<int>(0, (a, c) => a + c);
    final r = ScoutKnowledge.range(v, knowledge, player.id, salt);
    if (r == null) return ('?', 50);
    if (r.$1 == r.$2) return ('${r.$1}', r.$1);
    return ('${r.$1}-${r.$2}', (r.$1 + r.$2) ~/ 2);
  }

  static Color colorFor(BuildContext context, int v) {
    if (v >= 80) return Colors.green.shade700;
    if (v >= 65) return Colors.lightGreen.shade700;
    if (v >= 45) return Theme.of(context).colorScheme.onSurface;
    if (v >= 30) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final small =
        TextStyle(fontSize: 11, color: SemanticColors.subtleText(context));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in categories)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(c.label,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          for (final k in c.keys)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    keys.contains(k)
                                        ? Tr.pick(
                                            '★${AttributeKeys.labelOf(k)}',
                                            '* ${AttributeKeys.labelOf(k)}')
                                        : AttributeKeys.labelOf(k),
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _shown(k).$1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorFor(context, _shown(k).$2),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                Tr.pick('色: 80以上 濃い緑・65以上 緑・45未満 橙・30未満 赤。★はこの選手で効いている能力。',
                    'Colours: 80+ dark green, 65+ green, under 45 orange, under 30 red. * marks the attributes that matter for him.'),
                style: small),
            if (knowledge < 100)
              Text(
                  Tr.pick('見え$knowledge%: 数字はスカウトの見立ての幅です(「?」はまだ見えていない)。',
                      '$knowledge% known: the numbers are your scouts\' estimated ranges ("?" means not seen yet).'),
                  key: const ValueKey('attribute-estimate-note'),
                  style: small),
          ],
        ),
      ),
    );
  }
}

/// 今季のリーグ戦の警告の数と、あと何枚で出場停止か(国の決まりで数える。
/// 2026-11-23)。
Widget _leagueYellowLine(BuildContext context, Player p, CardRules rules) {
  final next = rules.nextBanAt(p.yellowCards);
  final left = next == null ? null : next - p.yellowCards;
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      left == null
          ? Tr.pick('今季リーグ戦の警告: ${p.yellowCards}枚',
              'League yellow cards this season: ${p.yellowCards}')
          : Tr.pick('今季リーグ戦の警告: ${p.yellowCards}枚(あと$left枚で出場停止)',
              'League yellow cards this season: ${p.yellowCards} ($left more brings a ban)'),
      style: TextStyle(
        color: left == 1
            ? SemanticColors.ink(context, Colors.redAccent)
            : SemanticColors.subtleText(context),
        fontSize: 12,
      ),
    ),
  );
}
