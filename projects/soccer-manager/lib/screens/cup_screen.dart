import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/continental_cup_engine.dart';
import '../logic/cup_engine.dart';
import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

class CupScreen extends StatelessWidget {
  const CupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(Tr.pick('カップ戦', 'Cups')),
          leading: const BackButton(),
          actions: const [QuickAccessMenuButton()],
          bottom: TabBar(
            tabs: [
              Tab(text: Tr.pick('国内カップ', 'Domestic Cup')),
              Tab(text: Tr.pick('大陸カップ', 'Continental Cup')),
            ],
          ),
        ),
        drawer: const QuickAccessDrawer(),
        body: const ResponsiveBody(
          child: TabBarView(
            children: [_DomesticCupTab(), _ContinentalCupTab()],
          ),
        ),
      ),
    );
  }
}

class _DomesticCupTab extends StatelessWidget {
  const _DomesticCupTab();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cup = gameState.domesticCup;

    if (cup == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              Tr.pick('カップ戦の情報がありません。', 'There is no cup information yet.'),
              textAlign: TextAlign.center),
        ),
      );
    }

    final userId = gameState.userTeam.id;
    final teams = gameState.allTeamsForCups;
    // 見つからない id を先頭のクラブ(自クラブ)の名前で埋めていたため、
    // 不戦勝の組が「◯◯ vs 青嵐FC 1-0」と出ていた(2026-11-21)。
    String nameOf(String id) => id == byeTeamId
        ? Tr.pick('(不戦勝)', '(bye)')
        : teams.where((t) => t.id == id).firstOrNull?.name ?? '-';
    // 回戦の数は、できている回戦の数ではなく大会の形から出す
    // (1回戦しかできていないときに、1回戦が「決勝」と出ていた)。
    // 1〜3部の全クラブが出るカップは、上の部が後の回戦から入るので、
    // 作るときに決まった回戦の数を使う。
    final totalRounds = cup.totalRounds;
    final nextMatch = cup.nextUnplayedMatch;
    final userEliminated = cup.isEliminated(userId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _LeagueCupCard(),
        const _FourClubSuperCupSection(),
        // ここから下は国内カップ。上のリーグカップの「敗退しました」の札の
        // すぐ下に、大会名なしで回戦表が続き、どの大会の表か分からなかった
        // (2026-11-23)。大会名の見出しで区切る。
        _CupHeading(
          key: const ValueKey('domestic-cup-heading'),
          title: cup.name,
          divider: gameState.leagueCup != null ||
              gameState.fourClubSuperCup != null,
        ),
        if (cup.isComplete)
          Card(
            color: cup.championId == userId
                ? SemanticColors.positive(context).withValues(alpha: 0.15)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.emoji_events,
                color: cup.championId == userId
                    ? SemanticColors.positive(context)
                    : null,
              ),
              title: Text(Tr.pick('優勝: ${nameOf(cup.championId!)}',
                  'Winners: ${nameOf(cup.championId!)}')),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: SemanticColors.negative(context),
              ),
              title: Text(Tr.pick('自クラブは敗退しました', 'You are out')),
              subtitle: Text(Tr.pick(
                  '他クラブの結果は引き続き更新されます', 'The other results keep coming in')),
            ),
          ),
        // 試合は全部、上の進むボタンから行う(2026-11-24。季の後も、ここの
        // 「次の試合をする」ではなく進むボタンがその日に止まる)。
        if (nextMatch != null && !userEliminated) const _CupByDateNote(),
        for (final round in cup.rounds) ...[
          _RoundSection(
            title: CupEngine.roundLabel(round.first.round, totalRounds),
            initiallyExpanded:
                round.any((m) => m.result == null) || round == cup.rounds.last,
            children: [
              for (final m in [
                ...round.where(
                    (m) => m.homeTeamId == userId || m.awayTeamId == userId),
                ...round.where(
                    (m) => m.homeTeamId != userId && m.awayTeamId != userId)
              ])
                _BracketMatchCard(match: m, nameOf: nameOf, userId: userId),
            ],
          ),
        ],
      ],
    );
  }

}

/// 出場のしかたの説明(チャンピオンズカップとヨーロッパカップ)。
String _continentalQualifyText(GameState gameState) => Tr.pick(
    '1部の上位${gameState.continentalSpots}クラブがチャンピオンズカップ、その下の1クラブと国内カップの優勝クラブがヨーロッパカップに出ます(チャンピオンズカップの枠は国の係数で3〜5に変わります)。',
    'The top ${gameState.continentalSpots} of the top division go into the Champions Cup; the next club and the domestic cup winners go into the Europa Cup (the Champions Cup places, 3 to 5, depend on the country coefficient).');

class _ContinentalCupTab extends StatefulWidget {
  const _ContinentalCupTab();

  @override
  State<_ContinentalCupTab> createState() => _ContinentalCupTabState();
}

class _ContinentalCupTabState extends State<_ContinentalCupTab> {
  /// 見ている大会(null なら、自クラブの出ている大会か、チャンピオンズカップ)。
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cups = gameState.continentalCups;

    if (cups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _continentalQualifyText(gameState),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final mine = gameState.continentalCup;
    final idx = (_selected ?? (mine == null ? 0 : cups.indexOf(mine)))
        .clamp(0, cups.length - 1);
    final cup = cups[idx];
    final userId = gameState.userTeam.id;
    final userInCup = cup.involvesTeam(userId);
    final teams = gameState.allTeamsForCups;
    String nameOf(String id) =>
        teams.where((t) => t.id == id).firstOrNull?.name ?? '-';
    // 決勝トーナメントの回戦の数(できている回戦の数ではなく組の数から)。
    var knockoutTotal = 0;
    for (var n = cup.groups.length * 2; n > 1; n ~/= 2) {
      knockoutTotal++;
    }
    if (knockoutTotal < cup.knockoutRounds.length) {
      knockoutTotal = cup.knockoutRounds.length;
    }
    final userEliminated = userInCup && cup.isEliminated(userId);
    final groupStageDone = cup.isGroupStageComplete;
    final nextGroupMatch = ContinentalCupEngine.nextGroupMatch(cup);
    final knockoutPending = cup.knockoutRounds.isNotEmpty &&
        cup.knockoutRounds.last.any((t) => !t.isComplete);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cups.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < cups.length; i++)
                ChoiceChip(
                  label: Text(cups[i].name),
                  selected: i == idx,
                  onSelected: (_) => setState(() => _selected = i),
                ),
            ],
          ),
        if (!userInCup)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(Tr.pick(
                  '自クラブはこの大会に出ていません', 'Your club is not in this competition')),
              subtitle: Text(_continentalQualifyText(gameState)),
            ),
          ),
        if (cup.isComplete)
          Card(
            color: cup.championId == userId
                ? SemanticColors.positive(context).withValues(alpha: 0.15)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.emoji_events,
                color: cup.championId == userId
                    ? SemanticColors.positive(context)
                    : null,
              ),
              title: Text(Tr.pick('優勝: ${nameOf(cup.championId!)}',
                  'Winners: ${nameOf(cup.championId!)}')),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: SemanticColors.negative(context),
              ),
              title: Text(Tr.pick('自クラブは敗退しました', 'You are out')),
              subtitle: Text(Tr.pick(
                  '他クラブの結果は引き続き更新されます', 'The other results keep coming in')),
            ),
          ),
        if (userInCup &&
            !userEliminated &&
            (nextGroupMatch != null || knockoutPending))
          const _CupByDateNote(),
        _RoundSection(
          title: Tr.pick('グループステージ', 'Group stage'),
          initiallyExpanded: !groupStageDone,
          children: [
            for (int g = 0; g < cup.groups.length; g++)
              _GroupTable(
                label: Tr.pick('グループ${String.fromCharCode(65 + g)}',
                    'Group ${String.fromCharCode(65 + g)}'),
                groupIndex: g,
                cup: cup,
                teams: teams,
                userId: userId,
              ),
          ],
        ),
        if (cup.knockoutRounds.isNotEmpty)
          for (final round in cup.knockoutRounds)
            _RoundSection(
              title: ContinentalCupEngine.roundLabel(
                round.first.round,
                knockoutTotal,
              ),
              initiallyExpanded: round == cup.knockoutRounds.last,
              children: [
                for (final tie in round)
                  _TieCard(tie: tie, nameOf: nameOf, userId: userId),
              ],
            ),
      ],
    );
  }

}

/// 国内カップの1試合分カード。自クラブの試合は背景色に加えて、
/// スクリーンリーダー向けにもその旨を読み上げる。
class _BracketMatchCard extends StatelessWidget {
  final CupMatch match;
  final String Function(String) nameOf;
  final String userId;

  const _BracketMatchCard({
    required this.match,
    required this.nameOf,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final isUserMatch =
        match.homeTeamId == userId || match.awayTeamId == userId;
    final resultLabel = match.isBye
        ? Tr.pick('不戦勝', 'Bye')
        : match.result == null
            ? Tr.pick('これから', 'To play')
            : '${match.result!.homeGoals} - ${match.result!.awayGoals}';
    final scheme = Theme.of(context).colorScheme;
    // 1試合を細い1行に。自クラブの試合は色と太字ではっきり分ける
    // (どれも同じ大きな札で、自分の試合を探しにくかった。2026-11-21)。
    final card = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            isUserMatch ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.isBye
                      ? nameOf(match.homeTeamId == byeTeamId
                          ? match.awayTeamId
                          : match.homeTeamId)
                      : '${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isUserMatch ? FontWeight.bold : FontWeight.normal),
                ),
                // 2試合合計の組(準決勝): 第1戦の得点と、終われば合計。
                if (match.twoLegged && match.firstLeg != null)
                  Text(
                      match.result == null
                          ? Tr.pick(
                              '第1戦 ${match.firstLeg!.awayGoals} - ${match.firstLeg!.homeGoals}(2試合合計で勝ち抜け)',
                              'First leg ${match.firstLeg!.awayGoals} - ${match.firstLeg!.homeGoals} (decided on aggregate)')
                          : Tr.pick(
                              '2試合合計 ${match.goalsFor(match.homeTeamId)} - ${match.goalsFor(match.awayTeamId)}',
                              'Aggregate ${match.goalsFor(match.homeTeamId)} - ${match.goalsFor(match.awayTeamId)}'),
                      style: TextStyle(
                          fontSize: 11,
                          color: SemanticColors.subtleText(context))),
                if (match.penaltyWinnerId != null)
                  Text(
                      Tr.pick('PK戦: ${nameOf(match.penaltyWinnerId!)}が勝利',
                          'Shootout: ${nameOf(match.penaltyWinnerId!)} go through'),
                      style: TextStyle(
                          fontSize: 11,
                          color: SemanticColors.subtleText(context)))
                else if (match.extraTime)
                  Text(Tr.pick('延長戦で決着', 'Decided after extra time'),
                      style: TextStyle(
                          fontSize: 11,
                          color: SemanticColors.subtleText(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            resultLabel,
            style: match.result == null || match.isBye
                ? TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context))
                : const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
    if (!isUserMatch) return card;
    return Semantics(
      label: Tr.pick(
          '自クラブの試合。${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}、$resultLabel${match.penaltyWinnerId != null ? '、PK戦: ${nameOf(match.penaltyWinnerId!)}が勝利' : ''}',
          "Your match. ${nameOf(match.homeTeamId)} vs ${nameOf(match.awayTeamId)}, $resultLabel${match.penaltyWinnerId != null ? ', shootout won by ${nameOf(match.penaltyWinnerId!)}' : ''}"),
      child: ExcludeSemantics(child: card),
    );
  }
}

class _GroupTable extends StatelessWidget {
  final String label;
  final int groupIndex;
  final ContinentalCup cup;
  final List<Team> teams;
  final String userId;

  const _GroupTable({
    required this.label,
    required this.groupIndex,
    required this.cup,
    required this.teams,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final standings = ContinentalCupEngine.groupStandings(
      cup,
      groupIndex,
      teams,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (int i = 0; i < standings.length; i++)
                Builder(
                  builder: (context) {
                    final isUserRow = standings[i].teamId == userId;
                    final teamName = teams
                            .where((t) => t.id == standings[i].teamId)
                            .firstOrNull
                            ?.name ??
                        '-';
                    final row = Container(
                      color: isUserRow
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.25)
                          : null,
                      child: ListTile(
                        dense: true,
                        leading: SizedBox(width: 20, child: Text('${i + 1}')),
                        title: Text(teamName),
                        trailing: Text(
                          Tr.pick(
                              '${standings[i].points}pt (${standings[i].played}試合)',
                              '${standings[i].points} pts (${standings[i].played} played)'),
                        ),
                      ),
                    );
                    if (!isUserRow) return row;
                    return Semantics(
                      label: Tr.pick(
                          '自クラブ。${i + 1}位: $teamName、${standings[i].points}pt (${standings[i].played}試合)',
                          'Your club. ${i + 1}: $teamName, ${standings[i].points} pts (${standings[i].played} played)'),
                      child: ExcludeSemantics(child: row),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TieCard extends StatelessWidget {
  final CupTie tie;
  final String Function(String) nameOf;
  final String userId;

  const _TieCard({
    required this.tie,
    required this.nameOf,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final isUserTie = tie.teamAId == userId || tie.teamBId == userId;
    final legsLabel = tie.legs.isEmpty
        ? Tr.pick('これから', 'To play')
        : tie.legs.map((r) => '${r.homeGoals}-${r.awayGoals}').join(' / ');
    final scoreLabel = tie.singleLeg
        ? Tr.pick('1試合制: $legsLabel', 'Single leg: $legsLabel')
        : Tr.pick(
            '合計スコア: ${tie.goalsFor(tie.teamAId)} - ${tie.goalsFor(tie.teamBId)} ($legsLabel)',
            'Aggregate: ${tie.goalsFor(tie.teamAId)} - ${tie.goalsFor(tie.teamBId)} ($legsLabel)');
    final how = tie.penaltyWinnerId != null
        ? Tr.pick('(PK戦)', ' (on penalties)')
        : tie.extraTime
            ? Tr.pick('(延長戦)', ' (after extra time)')
            : '';
    final resultLabel = tie.winnerId == null
        ? Tr.pick('対戦中', 'In progress')
        : Tr.pick('${nameOf(tie.winnerId!)}が勝利$how',
            '${nameOf(tie.winnerId!)} go through$how');
    final card = Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        tileColor: isUserTie
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.25)
            : null,
        title: Text('${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}'),
        subtitle: Text(scoreLabel),
        trailing: tie.winnerId == null
            ? Text(Tr.pick('対戦中', 'In progress'))
            : Text(resultLabel, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
    if (!isUserTie) return card;
    return Semantics(
      label: Tr.pick(
          '自クラブの対戦。${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}、$scoreLabel、$resultLabel',
          'Your tie. ${nameOf(tie.teamAId)} vs ${nameOf(tie.teamBId)}, $scoreLabel, $resultLabel'),
      child: ExcludeSemantics(child: card),
    );
  }
}

/// 1つの大会の始まりを示す見出し。上に別の大会があるときは線で区切る。
class _CupHeading extends StatelessWidget {
  const _CupHeading({super.key, required this.title, this.divider = false});

  final String title;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: divider ? 8 : 0, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (divider) const Divider(height: 16),
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// カップ戦の1ラウンド分をまとめる折りたたみ可能なセクション。
/// 消化済みの過去ラウンドはデフォルトで畳んでおき、画面のスクロール量を抑える。
class _RoundSection extends StatelessWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _RoundSection({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        // 横画面では試合を2列に並べる(2026-11-21)。
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 560 ? 2 : 1;
            final w = (c.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(
              spacing: 8,
              children: [
                for (final ch in children) SizedBox(width: w, child: ch),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// リーグカップ(イングランドだけ。1〜3部のクラブ)の進み具合。回戦ごとに
/// 決まった節で自動で進む。
class _LeagueCupCard extends StatelessWidget {
  const _LeagueCupCard();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final cup = gs.leagueCup;
    if (cup == null) return const SizedBox.shrink();
    final userId = gs.userTeam.id;
    final teams = gs.allTeamsForCups;
    String nameOf(String id) =>
        teams.where((t) => t.id == id).firstOrNull?.name ?? '-';
    // 決勝までの回戦の数(上の部が後から入る形では、作るときに決まる)。
    final total = cup.totalRounds;
    final String status;
    if (cup.isComplete) {
      status = Tr.pick('優勝: ${nameOf(cup.championId!)}',
          'Winners: ${nameOf(cup.championId!)}');
    } else if (cup.isEliminated(userId)) {
      status = Tr.pick('自クラブは敗退しました', 'You are out');
    } else {
      final round = cup.nextUnplayedMatch?.round ?? cup.currentRoundNumber;
      status = Tr.pick('次は${CupEngine.roundLabel(round, total)}',
          'Next: ${CupEngine.roundLabel(round, total)}');
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined),
        title: Text(gs.leagueCupName),
        subtitle: Text(Tr.pick(
            '$status。1〜3部のクラブが出て、回戦ごとに決まった週に自動で進みます。決勝は2〜3月(賞金は国内カップの半分)。',
            '$status. Clubs from all three tiers take part; each round is played automatically in its set week, with the final in February or March (half the domestic cup prize money).')),
      ),
    );
  }
}

/// 4クラブのスーパーカップ(スペイン・イタリア。1月ごろ。準決勝と決勝)。
/// 自クラブの試合は、ほかのカップ戦と同じく進むボタンがその日に止まって
/// 行う。延長は無く、並べばPK戦。
class _FourClubSuperCupSection extends StatelessWidget {
  const _FourClubSuperCupSection();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final cup = gs.fourClubSuperCup;
    if (cup == null) return const SizedBox.shrink();
    final userId = gs.userTeam.id;
    final teams = gs.allTeamsForCups;
    String nameOf(String id) =>
        teams.where((t) => t.id == id).firstOrNull?.name ?? '-';
    final involved = cup.involvesTeam(userId);
    final String status;
    if (cup.isComplete) {
      status = Tr.pick('優勝: ${nameOf(cup.championId!)}',
          'Winners: ${nameOf(cup.championId!)}');
    } else if (!involved) {
      status = Tr.pick('自クラブは出ていません', 'Your club is not taking part');
    } else if (cup.isEliminated(userId)) {
      status = Tr.pick('自クラブは敗退しました', 'You are out');
    } else {
      final round = cup.nextUnplayedMatch?.round ?? cup.currentRoundNumber;
      status = Tr.pick('次は${CupEngine.roundLabel(round, 2)}',
          'Next: ${CupEngine.roundLabel(round, 2)}');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events),
              title: Text(cup.name),
              subtitle: Text(Tr.pick(
                  '$status。リーグの1・2位とカップの優勝・準優勝の4クラブで、1月ごろに準決勝と決勝を行います(延長は無く、並べばPK戦)。',
                  '$status. The top two in the league and the two cup finalists meet in January: semi-finals, then the final (no extra time; level games go to penalties).')),
            ),
            if (involved && !cup.isComplete && !cup.isEliminated(userId)) ...[
              const _CupByDateNote(),
            ],
            for (final round in cup.rounds)
              _RoundSection(
                title: CupEngine.roundLabel(round.first.round, 2),
                initiallyExpanded: round == cup.rounds.last,
                children: [
                  for (final m in round)
                    _BracketMatchCard(match: m, nameOf: nameOf, userId: userId),
                ],
              ),
          ],
        ),
      ),
    );
  }

}

/// カップ戦の試合は、進むボタンがその日に止まって行う(2026-11-22)。
/// 季の後のカップ戦も同じ(2026-11-24。ここにあった「次の試合をする」は外した)。
class _CupByDateNote extends StatelessWidget {
  const _CupByDateNote();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.event,
                size: 16, color: SemanticColors.subtleText(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                Tr.pick('自クラブの試合の日が来ると、上の進むボタンがその日に止まって試合をします。',
                    'When your tie comes round, the advance button stops on that day and plays it.'),
                style: TextStyle(
                    fontSize: 12, color: SemanticColors.subtleText(context)),
              ),
            ),
          ],
        ),
      );
}
