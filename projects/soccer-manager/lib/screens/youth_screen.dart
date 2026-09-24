import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scouting_engine.dart';
import '../logic/training_engine.dart';
import '../logic/youth_departure_engine.dart';
import '../models/youth_league.dart';
import '../logic/youth_match_engine.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/position_filter_bar.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';
import '../theme/semantic_colors.dart';

/// 潜在能力と現在能力の差がこの値以上なら、伸びしろの大きい「有望株」として強調する。
const int _wonderkidGap = 15;

enum YouthSortOption { overall, potential, age, wonderkidGap }

extension on YouthSortOption {
  String get label => switch (this) {
        YouthSortOption.overall => Tr.pick('総合力', 'Overall'),
        YouthSortOption.potential => Tr.pick('ポテンシャル', 'Potential'),
        YouthSortOption.age => Tr.pick('年齢(若い順)', 'Age (youngest)'),
        YouthSortOption.wonderkidGap =>
          Tr.pick('伸びしろ(潜在−総合)', 'Room to grow (potential − overall)'),
      };
}

class YouthScreen extends StatefulWidget {
  const YouthScreen({super.key});

  /// フィルタ・検索・並び替えを適用した選手リストを返す。UIから切り離してテスト可能にしてある。
  static List<Player> filterAndSort(
    List<Player> all, {
    PositionGroup? group,
    String query = '',
    YouthSortOption sort = YouthSortOption.overall,
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
      case YouthSortOption.overall:
        players.sort((a, b) => b.overall.compareTo(a.overall));
        break;
      case YouthSortOption.potential:
        players.sort((a, b) => b.potential.compareTo(a.potential));
        break;
      case YouthSortOption.age:
        players.sort((a, b) => a.age.compareTo(b.age));
        break;
      case YouthSortOption.wonderkidGap:
        players.sort(
          (a, b) =>
              (b.potential - b.overall).compareTo(a.potential - a.overall),
        );
        break;
    }
    return players;
  }

  @override
  State<YouthScreen> createState() => _YouthScreenState();
}

class _YouthScreenState extends State<YouthScreen> {
  PositionGroup? _filter;
  YouthSortOption _sort = YouthSortOption.overall;
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
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final scoutCost = gameState.scoutCost;
    final maxProspects = gameState.maxYouthProspects;
    final refreshCost = gameState.scoutRefreshCost;
    final canRefresh = save.budget >= refreshCost;

    final prospects = YouthScreen.filterAndSort(
      save.youthProspects,
      group: _filter,
      query: _query,
      sort: _sort,
    );
    final canScout =
        save.budget >= scoutCost && save.youthProspects.length < maxProspects;

    final candidates = YouthScreen.filterAndSort(
      gameState.scoutCandidates,
      group: _filter,
      query: _query,
      sort: _sort,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('ユース・スカウト', 'Youth & scouting')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      Tr.pick('資金: ${save.budget}万円', 'Funds: ${save.budget}'),
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      Tr.pick(
                          '昇格枠: ${save.youthProspects.length}/$maxProspects',
                          'Academy places: ${save.youthProspects.length}/$maxProspects'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      Tr.pick(
                          'スカウト網（獲得費用: $scoutCost万円/人・${candidates.length}人閲覧可）',
                          'Scouting network ($scoutCost per signing, ${candidates.length} to look at)'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: Tr.pick('候補を更新する（$refreshCost万円）',
                        'Refresh the shortlist ($refreshCost)'),
                    onPressed: canRefresh ? () => _refresh(context) : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: PositionFilterBar(
                      value: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                  ),
                  PopupMenuButton<YouthSortOption>(
                    icon: const Icon(Icons.sort),
                    tooltip: Tr.pick('並び替え', 'Sort'),
                    initialValue: _sort,
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (context) => [
                      for (final option in YouthSortOption.values)
                        PopupMenuItem(value: option, child: Text(option.label)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  Tr.pick('該当する候補選手はいません', 'No prospects match'),
                  style: TextStyle(color: SemanticColors.subtleText(context)),
                ),
              )
            else
              for (final p in candidates)
                Builder(
                  builder: (context) {
                    final range = ScoutingEngine.estimatedPotentialRange(
                      p,
                      scoutLevel: gameState.scoutLevel,
                    );
                    final maybeWonderkid =
                        range.$2 - p.overall >= _wonderkidGap;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Card(
                        child: ListTile(
                          leading: PlayerFaceAvatar(
                            playerId: p.id,
                            position: p.position,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (maybeWonderkid) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: Tr.pick(
                                      'ワンダーキッドの可能性あり(推定潜在能力の上限が高い。獲得するまで確定情報ではない)',
                                      'Could be a wonderkid. His estimated ceiling is high, but nothing is certain until you sign him'),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            Tr.pick(
                                '${p.age}歳 / ${p.position.label} / 総合 ${p.overall} / 潜在(推定) ${range.$1}〜${range.$2} / 成長 ${p.growthType.label}',
                                'Age ${p.age} / ${p.position.label} / overall ${p.overall} / potential (est.) ${range.$1}-${range.$2} / ${p.growthType.label}'),
                          ),
                          trailing: FilledButton(
                            onPressed:
                                canScout ? () => _scout(context, p.id) : null,
                            child: Text(Tr.pick('獲得', 'Sign')),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                Tr.pick('昇格候補', 'Academy prospects'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                Tr.pick(
                    '昇格候補はユース施設で育成され続けます(成長係数 x${gameState.youthAcademyGrowthFactor.toStringAsFixed(2)}。ユース施設のレベルを上げるとじっくり育てる価値が高まります)。毎週ユース練習試合も行われ、活躍した候補はさらに伸びます',
                    'Prospects keep developing in your youth setup (growth x${gameState.youthAcademyGrowthFactor.toStringAsFixed(2)}; better facilities make it more worthwhile to be patient). They also play a youth match each week, and those who do well improve faster'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
            ),
            if (gameState.save!.youthLeague != null)
              _YouthLeagueTable(league: gameState.save!.youthLeague!),
            // 今週ユースを去った選手。ニュースにも残るが、ユース画面を開いた
            // ときに名簿から消えているだけだと、何が起きたのか分からない。
            if (gameState.lastYouthDepartures.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final d in gameState.lastYouthDepartures)
                          Text(
                            d.poached
                                ? Tr.pick(
                                    '${d.player.name}(${d.player.age}歳)が他クラブに引き抜かれました。育成補償金 ${d.compensation}万円',
                                    '${d.player.name} (${d.player.age}) was poached by another club. Development fee ${d.compensation}')
                                : Tr.pick(
                                    '${d.player.name}(${d.player.age}歳)が出場機会を求めて去りました。育成補償金 ${d.compensation}万円',
                                    '${d.player.name} (${d.player.age}) left in search of first-team football. Development fee ${d.compensation}'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (gameState.lastYouthMatchReport != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Builder(
                      builder: (context) {
                        final report = gameState.lastYouthMatchReport!;
                        final best = report.performances.isEmpty
                            ? null
                            : report.performances.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Tr.pick(
                                  '今週のユース練習試合: ${report.scoreLabel} ${report.isWin ? '勝利' : report.isDraw ? '引き分け' : '敗戦'}(相手の総合力 ${report.opponentRating})',
                                  "This week's youth match: ${report.scoreLabel} ${report.isWin ? 'win' : report.isDraw ? 'draw' : 'defeat'} (opponent overall ${report.opponentRating})"),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (best != null)
                              Text(
                                Tr.pick(
                                    'ベストプレイヤー: ${best.player.name}(評点 ${best.rating.toStringAsFixed(1)}${best.goals > 0 ? '・${best.goals}得点' : ''})',
                                    "Best on the day: ${best.player.name} (rated ${best.rating.toStringAsFixed(1)}${best.goals > 0 ? ', ${Tr.plural(best.goals, 'goal')}' : ''})"),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SemanticColors.subtleText(context),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (prospects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  save.youthProspects.isEmpty
                      ? Tr.pick(
                          '現在、昇格候補はいません', 'You have no prospects right now')
                      : Tr.pick('該当する昇格候補はいません', 'No prospects match'),
                ),
              )
            else
              for (final p in prospects)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Card(
                    child: ListTile(
                      leading: PlayerFaceAvatar(
                        playerId: p.id,
                        position: p.position,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.potential - p.overall >= _wonderkidGap) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: Tr.pick('ワンダーキッド(潜在能力が現在能力を大きく上回る逸材)',
                                  'Wonderkid: his ceiling sits far above where he is now'),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Tr.pick(
                                '${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential} / 成長 ${p.growthType.label}',
                                'Age ${p.age} / overall ${p.overall} / potential ${p.potential} / ${p.growthType.label}'),
                          ),
                          Text(
                            p.youthMatchApps == 0
                                ? Tr.pick(
                                    'ユース戦: まだ出場なし', 'Youth matches: none yet')
                                : Tr.pick(
                                    'ユース戦: ${p.youthMatchApps}試合 ${p.youthMatchGoals}得点 / 直近評点 ${p.lastYouthMatchRating.toStringAsFixed(1)}',
                                    'Youth matches: ${Tr.plural(p.youthMatchApps, 'app')}, ${Tr.plural(p.youthMatchGoals, 'goal')} / last rating ${p.lastYouthMatchRating.toStringAsFixed(1)}'),
                            style: TextStyle(
                              fontSize: 12,
                              color: p.lastYouthMatchRating >=
                                      YouthMatchEngine.standoutRatingThreshold
                                  ? Colors.green
                                  : SemanticColors.subtleText(context),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                Tr.pick('育成方針: ', 'Focus: '),
                                style: const TextStyle(fontSize: 12),
                              ),
                              DropdownButton<TrainingFocus?>(
                                value: p.individualFocus,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                                hint: Text(
                                  Tr.pick(
                                      'ポジション別(既定)', 'By position (default)'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                items: [
                                  DropdownMenuItem<TrainingFocus?>(
                                    value: null,
                                    child: Text(Tr.pick(
                                        'ポジション別(既定)', 'By position (default)')),
                                  ),
                                  for (final focus in const [
                                    TrainingFocus.attack,
                                    TrainingFocus.defense,
                                    TrainingFocus.fitness,
                                  ])
                                    DropdownMenuItem<TrainingFocus?>(
                                      value: focus,
                                      child: Text(focus.label),
                                    ),
                                ],
                                onChanged: (focus) {
                                  FeedbackService.tap();
                                  context
                                      .read<GameState>()
                                      .setYouthProspectTrainingFocus(
                                        p.id,
                                        focus,
                                      );
                                },
                              ),
                            ],
                          ),
                          _MentorRow(prospect: p),
                          if (YouthDepartureEngine.isAtRisk(p))
                            Text(
                              Tr.pick(
                                  '${p.age}歳。出場機会を求めており、いつ去ってもおかしくありません',
                                  'Age ${p.age}. He wants first-team football and could leave at any time'),
                              style: TextStyle(
                                fontSize: 12,
                                color: SemanticColors.negative(context),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: Tr.pick('解雇', 'Release'),
                            onPressed: () =>
                                _confirmRelease(context, p.id, p.name),
                          ),
                          FilledButton(
                            onPressed: squadFull
                                ? null
                                : () => _promote(context, p.id, p.name),
                            child: Text(Tr.pick('昇格', 'Promote')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final ok = await context.read<GameState>().refreshScoutCandidates();
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
                ? Tr.pick('スカウト候補を更新しました', 'Shortlist refreshed')
                : Tr.pick('資金が足りず更新できませんでした', 'Not enough funds to refresh'))),
      );
    }
  }

  Future<void> _scout(BuildContext context, String candidateId) async {
    final ok = await context.read<GameState>().scoutProspect(candidateId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
                ? Tr.pick('新しい有望株を発見しました', 'You found a new prospect')
                : Tr.pick('スカウトできませんでした', 'The scouting did not come off'))),
      );
    }
  }

  Future<void> _promote(
    BuildContext context,
    String playerId,
    String name,
  ) async {
    final gameState = context.read<GameState>();
    // 昇格はプロ契約を結ぶ手続きになった。押した瞬間に契約金が引かれるので、
    // 条件を見せてから決めさせる。
    final terms = gameState.youthPromotionTermsFor(playerId);
    if (terms == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('$nameとプロ契約を結びますか？',
            'Sign $name to a professional contract?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('背番号: ${terms.squadNumber}',
                'Squad number: ${terms.squadNumber}')),
            Text(Tr.pick('週俸: ${terms.weeklyWage}万円',
                'Wage: ${terms.weeklyWage} per week')),
            Text(Tr.pick('契約金: ${terms.signingBonus}万円(一括)',
                'Signing fee: ${terms.signingBonus} (one-off)')),
            Text(Tr.pick('契約年数: ${terms.years}年',
                'Contract: ${terms.years} years')),
            const SizedBox(height: 8),
            Text(
              Tr.pick('昇格直後は一軍の強度に慣れておらず、実戦感覚が低い状態から始まります。出番を作ると戻ります。',
                  'He will start short of match sharpness until he adjusts to first-team football. Playing him brings it back.'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Tr.pick('やめる', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Tr.pick('契約して昇格', 'Sign and promote')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await gameState.promoteYouthProspect(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? Tr.pick('$nameが背番号${terms.squadNumber}でトップチームに昇格しました',
                  '$name joined the first team with the number ${terms.squadNumber}')
              // 失敗の理由は GameState 側が入れている(資金・週給予算・枠)。
              : gameState.lastSigningBlockReason ??
                  Tr.pick('昇格できませんでした', 'The promotion did not go through')),
        ),
      );
    }
  }

  void _confirmRelease(BuildContext context, String playerId, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この有望株を解雇しますか？', 'Release this prospect?')),
        content: Text(Tr.pick('$nameを手放します。この操作は元に戻せません。',
            'You let $name go. This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              FeedbackService.tap();
              context.read<GameState>().releaseYouthProspect(playerId);
            },
            child: Text(Tr.pick('解雇する', 'Release him')),
          ),
        ],
      ),
    );
  }
}

/// 有望株に付けるメンター(一軍のベテラン)の選択欄。
///
/// 性格特性はユースでは練習で身に付かず、メンターを通してしか手に入らない。
/// 成長も速くなるが、ベテラン1人が見られるのは1人だけなので、誰に付けるかを
/// 選ぶことになる。
class _MentorRow extends StatelessWidget {
  final Player prospect;

  const _MentorRow({required this.prospect});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final candidates =
        gameState.youthMentorCandidates(forProspectId: prospect.id);
    final current = prospect.mentorId == null
        ? null
        : gameState.userTeam.players
            .where((p) => p.id == prospect.mentorId)
            .firstOrNull;

    // 付けられる相手が1人も居ないときは、空の選択欄を出しても押せるものが
    // 無いだけなので、理由のほうを出す。
    if (candidates.isEmpty && current == null) {
      return Text(
        Tr.pick('メンター: ${TrainingEngine.minMentorAge}歳以上の手の空いた選手がいません',
            'Mentor: nobody aged ${TrainingEngine.minMentorAge}+ is free'),
        style: const TextStyle(fontSize: 12),
      );
    }

    return Row(
      children: [
        Text(Tr.pick('メンター: ', 'Mentor: '), style: const TextStyle(fontSize: 12)),
        Flexible(
          child: DropdownButton<String?>(
            value: current?.id,
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            hint: Text(Tr.pick('付けない', 'None'),
                style: const TextStyle(fontSize: 12)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(Tr.pick('付けない', 'None')),
              ),
              for (final m in [
                if (current != null && !candidates.contains(current)) current,
                ...candidates,
              ])
                DropdownMenuItem<String?>(
                  value: m.id,
                  child: Text(
                    Tr.pick('${m.name} (${m.age}歳 / 総合${m.overall})',
                        '${m.name} (${m.age} / ovr ${m.overall})'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              FeedbackService.tap();
              context.read<GameState>().setYouthProspectMentor(prospect.id, id);
            },
          ),
        ),
      ],
    );
  }
}


/// ユースリーグの順位表。
///
/// 練習試合の勝敗が何にも残らなかったため、年間の積み上がりを出す。
/// 自クラブの行だけ太字にして、長い表の中でも自分を見失わないようにする。
class _YouthLeagueTable extends StatelessWidget {
  final YouthLeague league;

  const _YouthLeagueTable({required this.league});

  @override
  Widget build(BuildContext context) {
    final sorted = league.sorted;
    final next = league.nextOpponent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                league.isComplete
                    ? Tr.pick('ユースリーグ 最終順位 (${league.userRank}位)',
                        'Youth league, final table (${league.userRank})')
                    : Tr.pick(
                        'ユースリーグ 第${league.matchday + 1}節 / 全${YouthLeague.matchdayCount}節',
                        'Youth league, round ${league.matchday + 1} of ${YouthLeague.matchdayCount}'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (next != null)
                Text(
                  Tr.pick('今節の相手: ${next.name}(強さ ${next.strength})',
                      'Next up: ${next.name} (strength ${next.strength})'),
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.subtleText(context)),
                ),
              const SizedBox(height: 8),
              for (var i = 0; i < sorted.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          sorted[i].name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sorted[i].isUser
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        Tr.pick(
                            '${sorted[i].played}試 ${sorted[i].points}点 ${sorted[i].goalDiff >= 0 ? '+' : ''}${sorted[i].goalDiff}',
                            '${sorted[i].played}P ${sorted[i].points}pts ${sorted[i].goalDiff >= 0 ? '+' : ''}${sorted[i].goalDiff}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sorted[i].isUser
                              ? FontWeight.bold
                              : FontWeight.normal,
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
