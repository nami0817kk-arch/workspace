import 'package:flutter/material.dart';
import 'advance_flow.dart';
import 'package:provider/provider.dart';

import '../data/quick_access_destinations.dart';
import '../widgets/owner_event_card.dart';
import '../widgets/decision_card.dart';
import '../widgets/agm_demand_card.dart';
import '../widgets/preseason_tour_card.dart';
import '../widgets/surgery_decision_card.dart';
import '../widgets/front_page_card.dart';
import '../widgets/owner_goal_card.dart';
import '../widgets/two_pane.dart';
import '../logic/calendar_engine.dart';
import '../logic/cup_engine.dart';
import '../logic/day_events.dart';
import '../models/league.dart';
import '../models/team.dart';
import '../models/league_theme.dart';
import '../models/owner_legacy.dart';
import '../models/match_result.dart';
import '../monetization/monetization_controller.dart';
import '../services/review_prompt.dart';
import '../state/game_state.dart';
import '../services/feedback_service.dart';
import '../theme/club_palette.dart';
import '../theme/semantic_colors.dart';
import '../widgets/achievement_unlock_notifier.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/club_emblem.dart';
import '../widgets/match_digest_dialog.dart';
import '../widgets/inbox_card.dart';
import '../widgets/incoming_offers_card.dart';
import '../widgets/fm_panel.dart';
import '../widgets/todo_list.dart';
import '../logic/todo_advisor.dart';
import 'todo_navigation.dart';
import '../widgets/disabled_reason.dart';
import '../widgets/season_review_card.dart';
import '../widgets/supporter_month_card.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'glossary_screen.dart';
import 'matchday_notices.dart';
import 'start_screen.dart';
import 'youth_intake_screen.dart';
import '../logic/board_target_progress.dart';
import '../models/club_vision.dart';
import '../l10n/tr.dart';
import '../widgets/screen_bar.dart';
import '../widgets/big_moment_overlay.dart';
import '../widgets/rumor_card.dart';
import '../logic/economy_scale.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// 上のバーの「試合を行う」から、次の試合を始める。
  Future<void> playMatch(BuildContext context) => _playMatch(context);

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final saleReason = gameState.saleReason;
    if (saleReason != null) {
      return _SaleScreen(clubName: save.clubName, reason: saleReason);
    }

    final scheme = Theme.of(context).colorScheme;
    final league = save.league;
    final userTeam = gameState.userTeam;
    final standings = league.sortedStandings;
    final userRank = standings.indexWhere((r) => r.teamId == userTeam.id) + 1;
    final userRow = standings.firstWhere((r) => r.teamId == userTeam.id);
    // 自クラブの次のリーグ戦。リーグ全体の次の試合(nextUnplayedFixture)は
    // 他のクラブ同士の試合のことがあり、次の試合の札に「ボルトン vs
    // ブラックプール」と自クラブの出ない試合が出ていた(2026-11-23)。
    final next = (league.fixtures
                .where((f) =>
                    f.result == null &&
                    (f.homeTeamId == userTeam.id ||
                        f.awayTeamId == userTeam.id))
                .toList()
              ..sort((a, b) => a.matchday.compareTo(b.matchday)))
            .firstOrNull ??
        league.nextUnplayedFixture;
    final seasonComplete = league.isSeasonComplete;
    final preseason = gameState.isPreseason;
    final net = _netWeekly(gameState);
    // 横画面は高さが 400 ほどしかない。帯と数字のタイルを左右に分ける。
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width > screen.height;

    return BusyOverlay(
      visible: gameState.isBusy,
      label: Tr.pick('シーズンを更新しています…', 'Rolling the season over…'),
      child: Scaffold(
        // ヘッダーにエンブレムを出す。クラブ名だけだと、どの画面も
        // 同じ見出しに見えて「自分のクラブ」の感じが出ない。
        // 左メニューに埋め込まれた横画面では、上バーにクラブ名があるので
        // この帯は出さない(同じ名前が二重になり、縦の高さも食う)。
        appBar: EmbeddedInShell.of(context)
            ? null
            : AppBar(
                titleSpacing: 0,
                title: Row(
                  children: [
                    ClubEmblem(
                      teamId: userTeam.id,
                      teamName: save.clubName,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child:
                          Text(save.clubName, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
        drawer: const QuickAccessDrawer(),
        body: ResponsiveBody(
          maxWidth: wide ? 1100 : 720,
          child: TwoPane(
            wide: wide,
            // 横画面: 左は 帯・受信箱・目標・たたんだ数字、右は「やること」と
            // 次の試合。縦長: 帯 → やること → 次の試合 → 数字 の順に1本。
            children: _arrange(
              wide: wide,
              top: [
              // クラブの色で染めた見出しの帯。**状況の先頭に置く**(2026-11-21)。
              // 以前は左の欄の一番下にあり、開いても順位が見えなかった。
              //
              // **1枚だけ主役を作る。** 以前は「ヒント」「リーグ」「数字」
              // 「今週の予定」が全部同じ重さの白いカードで縦に並んでいて、
              // どこから見ればよいのか分からなかった。帯を1本置くと画面に
              // 上下ができる。色はクラブごとに違うので、同じ画面が
              // 「自分のクラブの画面」になる。
              Builder(
                builder: (context) {
                  final palette =
                      ClubPalette.of(userTeam.id, clubName: save.clubName);
                  // 白い文字を載せるので、明るいクラブ色でも必ず暗くする。
                  final hsl = HSLColor.fromColor(palette.base);
                  final top = hsl.withLightness(0.30).toColor();
                  final bottom = hsl.withLightness(0.18).toColor();
                  final progress = BoardTargetProgressEngine.evaluate(
                    league: league,
                    userTeamId: save.userTeamId,
                    targetRank: save.boardTargetRank,
                    matchdaysLeft: gameState.remainingMatchdaysThisSeason,
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [top, bottom],
                      ),
                      borderRadius:
                          BorderRadius.circular(fmRadius(context, 18)),
                      boxShadow: [
                        BoxShadow(
                          color: bottom.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(fmRadius(context, 18)),
                      child: Stack(
                        children: [
                          // 右に薄くエンブレムを敷く。名前を二度書かずに
                          // 「誰の画面か」を出す。
                          Positioned(
                            right: -34,
                            top: -30,
                            child: Opacity(
                              opacity: 0.10,
                              child: ClubEmblem(
                                teamId: userTeam.id,
                                teamName: save.clubName,
                                size: 164,
                              ),
                            ),
                          ),
                          Padding(
                            // 帯は低めに(2026-11-25)。iPhone 横で、帯の下の
                            // 受信箱まで送らずに見えるように。
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // リーグ名は長い。シーズンを別の札に
                                // 分けないと「…5部 シー／ズン1」と折り返す。
                                Row(
                                  children: [
                                    // 上のバーは「3部」と数で書く。帯は
                                    // 部の名前だけで、同じ部だと分からな
                                    // かったので、数を前に付ける(2026-11-23)。
                                    Expanded(
                                      child: Text(
                                        gameState.currentLeagueTheme
                                            .divisionTitle(
                                                save.currentDivisionTier),
                                        key: const ValueKey('band-league-name'),
                                        // 文字1.5倍では1行に入らず、部の名前が
                                        // 切れていた。2行まで折り返す。
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                    // 日付と季は、横画面では上バーに出ている。
                                    // 二度書くとリーグ名が「アルビオ…」で切れる
                                    // ので、上バーが無い縦長のときだけ出す。
                                    if (!EmbeddedInShell.of(context)) ...[
                                      const SizedBox(width: 8),
                                      _BandPill(
                                          text: CalendarEngine.formatDate(
                                              gameState.today)),
                                      const SizedBox(width: 6),
                                      // 上バーと同じ「第N季」に揃える(S1 と混ざっていた)。
                                      _BandPill(
                                          text: Tr.pick(
                                              '第${league.season}季',
                                              // 英語は短い形のまま(Season 1 だと
                                              // 狭い縦長で日付の札とはみ出す)。
                                              'S${league.season}')),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // **順位をここに大きく出す。** このゲームで
                                // いちばん見る数字なのに、6枚のタイルの1枚に
                                // 埋もれていた。帯の主役にする。
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    // 開幕前は全クラブ勝点0で並ぶだけ。
                                    // 「1位」と出すと勝っているように見える。
                                    Text(
                                      preseason ? '—' : '$userRank',
                                      key: const ValueKey('band-rank'),
                                      style: const TextStyle(
                                        fontFamily: 'NotoSansJP',
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                        letterSpacing: -2,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // 文字1.5倍の英語で右へはみ出していた。
                                    // 入らなければ折り返す。
                                    Flexible(
                                      child: Text(
                                        preseason
                                            ? Tr.pick(
                                                ' 開幕前・${standings.length}クラブ',
                                                ' pre-season, ${standings.length} clubs')
                                            : Tr.pick(
                                                '位 / ${standings.length}クラブ',
                                                ' of ${standings.length}'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white
                                              .withValues(alpha: 0.80),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  Tr.pick(
                                      '目標: ${save.boardTargetRank}位以内${gameState.boardCupTargetLabel != null ? '・カップ${gameState.boardCupTargetLabel}進出' : ''}',
                                      "Target: ${Tr.topTarget(save.boardTargetRank)}${gameState.boardCupTargetLabel != null ? ' • reach ${CupEngine.roundInSentence(gameState.boardCupTargetLabel!)} in the cup' : ''}"),
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.88)),
                                ),
                                // 開幕前は「目標圏内(差0点)」と出ても意味が
                                // 無いので出さない。
                                if (progress != null && !preseason)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      // **順位をここで繰り返さない。**
                                      // engine の label は「現在5位。…」で
                                      // 始まるので、帯に大きく出している
                                      // 順位と二度書きになる。中の値から
                                      // 組み直す。
                                      progress.onTrack
                                          ? Tr.pick(
                                              '目標圏内（下位クラブとの差 ${progress.pointsGap}点・残り${progress.matchdaysLeft}節）',
                                              'On target - ${progress.pointsGap} pts clear, ${progress.matchdaysLeft} to play')
                                          : Tr.pick(
                                              '目標まで勝点${progress.pointsGap}差（残り${progress.matchdaysLeft}節）',
                                              '${progress.pointsGap} pts off target, ${progress.matchdaysLeft} to play'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        // 暗い地の上なので、明るいほうへ振る。
                                        // 圏内は緑、圏外は赤。以前は「圏内でも
                                        // 差が小さい」ときに赤く、圏内なのに
                                        // 悪い知らせに見えた。
                                        color: progress.onTrack
                                            ? const Color(0xFF8BE6A8)
                                            : const Color(0xFFFFA8A0),
                                      ),
                                    ),
                                  ),
                                // 前の月のサポーターの期待の内訳。以前は別の札
                                // (「8月の期待」)で、帯の下に1枚ぶんの高さを
                                // 取っていた。順位の札に1行で入れる(2026-11-25)。
                                if (gameState.supporterMonthBandLine
                                    case final month?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      month,
                                      key: const ValueKey('band-month'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // 終わったばかりのシーズンの振り返り。閉じるまで出る。帯の
              // すぐ下に置く。左の欄の一番下だと、季の切り替え直後に出る
              // 実績解除の知らせ(画面下の帯)に「閉じる」ごと隠れた
              // (2026-11-23)。
              // サポーターの最後通告。出ている間は帯のすぐ下に、いちばん
              // 目立つ形で(2026-11-23)。
              const SupporterUltimatumCard(),
              const SeasonReviewCard(),
              // 監督の報告(ひとことと経営診断)は外した(2026-11-25)。順位と
              // 目標は帯に、警告は「やること」に出ていて、同じことを3か所で
              // 言っていた。前の月の期待の内訳は帯の中へ。
              // 受信箱は件数の1行だけ(押すと受信箱の画面)。
              const InboxCard(),
              // オーナーの目標。決めた後の残りだけをここに出す。決める前の
              // 「目標を決める」は、右の「やること」の行の1つだけにした
              // (同じ用件が左右に2つ並んでいた。2026-11-24)。
              if (gameState.ownerGoal != null) const OwnerGoalCard(),
              ],
              todos: [
              // 右の欄の先頭は「やること」の一覧(2026-11-24)。以前は左メニューの
              // 印・「決めること」・「今週の決断」が別々に数えていて、どこにも
              // 出ない用件があった。源は TodoAdvisor の1つ。
              //
              // 上から、必須のうち行き先で片付けるもの(行)、必須のうちその場で
              // 答えるもの(札)、おすすめ(行。多ければたたむ)。
              const TodoHeader(),
              const TodoMustRows(),
              if (gameState.pendingBoardReviewMessage != null)
                // 題と「了解した」だけ。中身は押すと開く(2026-11-25)。
                DecisionCard(
                  key: const ValueKey('board-review-card'),
                  icon: Icons.gavel,
                  title: Tr.pick(
                      'シーズン中盤 理事会レビュー', 'Mid-season board review'),
                  detail: gameState.pendingBoardReviewMessage!,
                  color: scheme.secondaryContainer,
                  onColor: scheme.onSecondaryContainer,
                  choices: [
                    DecisionChoice(Tr.pick('了解した', 'Understood'), () {
                      FeedbackService.tap();
                      gameState.dismissBoardReview();
                    }),
                  ],
                ),
              if (gameState.pendingOwnerEvent != null) const OwnerEventCard(),
              if (gameState.agmDemand != null) const AgmDemandCard(),
              if (gameState.save?.pendingRumor != null) const RumorCard(),
              if (gameState.playersAwaitingSurgeryDecision.isNotEmpty)
                const SurgeryDecisionCard(),
              const IncomingOffersCard(),
              // スポンサー未契約の知らせは、上の必須の行に入れた(押すと経営の
              // 「資金・取引」へ移る。以前はここに別の札があり、画面を重ねて
              // 開いていた)。
              if (gameState.pendingYouthIntake.isNotEmpty)
                Card(
                  color: scheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.emoji_people),
                    title: Text(Tr.pick('ユースインテーク', 'Youth intake')),
                    subtitle: Text(
                      Tr.pick(
                          '${gameState.pendingYouthIntake.length}名の新人候補が加入を待っています',
                          gameState.pendingYouthIntake.length == 1
                              ? 'A young hopeful is waiting to join'
                              : '${gameState.pendingYouthIntake.length} young hopefuls are waiting to join'),
                    ),
                    trailing: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const YouthIntakeScreen(),
                        ),
                      ),
                      child: Text(Tr.pick('選抜する', 'Pick them')),
                    ),
                  ),
                ),
              // 開幕前の海外ツアーも、答えを待つ札としてここに並べる(以前は
              // 数字のタイルの下にあり、決めごとに数えていなかった)。
              if (PreseasonTourCard.visible(gameState))
                const PreseasonTourCard(),
              const TodoRecommendedList(),
              ],
              match: [
              if (gameState.pendingSuperCup != null)
                _SuperCupCard(gameState: gameState),
              // 試合の日が近いときだけ出す。以前は7月から「カップ戦へ」が
              // 出ていて、押しても何週も先の試合だった(2026-11-23)。
              if (gameState.isUserDomesticCupMatchSoon)
                _NoticeCard(
                  key: const ValueKey('domestic-cup-soon'),
                  color: scheme.tertiaryContainer,
                  onColor: scheme.onTertiaryContainer,
                  icon: Icons.emoji_events_outlined,
                  title:
                      Tr.pick('国内カップ戦の出番です', 'You are up in the domestic cup'),
                  body: Tr.pick(
                      '${CalendarEngine.formatShortDate(gameState.userDomesticCupDate!)}に自クラブの試合があります',
                      'Your tie is on ${CalendarEngine.formatShortDate(gameState.userDomesticCupDate!)}'),
                  button: FilledButton(
                    onPressed: () {
                      // 横画面では、リーグのカップ戦のタブへ移る(重ねない)。
                      openTodoPlace(context, TodoPlaces.leagueCups);
                    },
                    child: Text(Tr.pick('カップ戦へ', 'Go to the cup')),
                  ),
                ),
              // 季の後に自クラブのカップ戦が残っていれば、進むボタンで行う
              // (カップ戦の画面の「次の試合をする」は外した。2026-11-24)。
              // 横画面は上の帯に同じボタンがある。
              if (seasonComplete &&
                  gameState.nextStop != null &&
                  !EmbeddedInShell.of(context))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    key: const ValueKey('advance-button'),
                    onPressed: () => advanceToNextStop(context),
                    child: Text(advanceButtonLabel(gameState) ??
                        Tr.pick('次の試合へ', 'Next match')),
                  ),
                ),
              if (seasonComplete)
                _NoticeCard(
                  key: const ValueKey('season-over-card'),
                  color: scheme.primaryContainer,
                  onColor: scheme.onPrimaryContainer,
                  icon: Icons.flag,
                  title: Tr.pick('シーズン終了！', 'Season over.'),
                  // 季を締めたときに来る増減を、押す前に見せる
                  // (2026-11-23。押した後に初めて -20 を知った)。
                  body: Tr.pick(
                      '最終順位: $userRank位。${gameState.seasonEndPreviewLine}',
                      'Final position: ${Tr.ordinal(userRank)}. ${gameState.seasonEndPreviewLine}'),
                  button: FilledButton(
                    onPressed: () => _startNextSeason(context),
                    child: Text(Tr.pick('次のシーズンへ', 'On to next season')),
                  ),
                )
              else if (next != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 進むボタンは日付の順に次の予定へ進む。リーグ戦の前に
                        // 自クラブのカップ戦があると、ボタンはカップ戦の日付
                        // なのに札はリーグ戦を出していて、食い違って見えた
                        // (2026-11-23)。ボタンの側が正しいので、札にも先に
                        // カップ戦があることを出す。
                        //
                        // 給料日・放映権などの日付の予定も同じ。最初の進む
                        // ボタンは「7/31 給料日」なのに札は「第1節 vs …」で、
                        // どちらが次なのか分からなかった(2026-11-23)。
                        if (gameState.nextStop != null &&
                            !gameState.nextStop!.kind.isMatch)
                          Padding(
                            key: const ValueKey('next-stop-before-league'),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.event,
                                    size: 18, color: scheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    Tr.pick(
                                        '進むボタンは${CalendarEngine.formatShortDate(gameState.nextStop!.date)}の${gameState.nextStop!.label}まで。第${next.matchday}節(${CalendarEngine.formatShortDate(gameState.dateOfMatchday(next.matchday))})はその後です。',
                                        'The button takes you to ${CalendarEngine.formatShortDate(gameState.nextStop!.date)} (${gameState.nextStop!.label}). Matchday ${next.matchday} (${CalendarEngine.formatShortDate(gameState.dateOfMatchday(next.matchday))}) comes after.'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (gameState.nextStop?.kind == DayEventKind.cupMatch)
                          Padding(
                            key: const ValueKey('next-cup-before-league'),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.emoji_events_outlined,
                                    size: 18, color: scheme.tertiary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    Tr.pick(
                                        '次の試合は${CalendarEngine.formatShortDate(gameState.nextStop!.date)}の${gameState.nextStop!.label}。下のリーグ戦はその後です。',
                                        'Next up: ${gameState.nextStop!.label} on ${CalendarEngine.formatShortDate(gameState.nextStop!.date)}. The league match below comes after it.'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            ClubEmblem(
                              teamId: next.homeTeamId == userTeam.id
                                  ? next.awayTeamId
                                  : next.homeTeamId,
                              teamName: league.teams
                                  .firstWhere(
                                    (t) =>
                                        t.id ==
                                        (next.homeTeamId == userTeam.id
                                            ? next.awayTeamId
                                            : next.homeTeamId),
                                  )
                                  .name,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(Tr.pick('第${next.matchday}節',
                                          'Matchday ${next.matchday}')),
                                      if (gameState.isRivalFixture(next)) ...[
                                        const SizedBox(width: 6),
                                        Chip(
                                          label: Text(
                                            Tr.pick('ダービー', 'Derby'),
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: Colors.redAccent,
                                          labelStyle: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    _fixtureLabel(league, next),
                                    style: TextStyle(
                                        color:
                                            SemanticColors.subtleText(context)),
                                  ),
                                  // 対戦相手の現在の順位・戦力・直近フォームを
                                  // 一目で確認できるようにする(詳細な分析は
                                  // 従来通りスカウティングレポートで)。
                                  Builder(builder: (context) {
                                    final oppId = next.homeTeamId == userTeam.id
                                        ? next.awayTeamId
                                        : next.homeTeamId;
                                    final opp = league.teams
                                        .firstWhere((t) => t.id == oppId);
                                    final oppRank = standings.indexWhere(
                                          (r) => r.teamId == oppId,
                                        ) +
                                        1;
                                    final form = league.recentFormFor(oppId);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            Tr.pick(
                                                '$oppRank位・総合${opp.overallRating}',
                                                '${Tr.ordinal(oppRank)} in the table • overall ${opp.overallRating}'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: SemanticColors.subtleText(
                                                  context),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          for (final r in form)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 1,
                                              ),
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                alignment: Alignment.center,
                                                // 白い字を乗せる丸なので、暗い見た目
                                                // の明るい赤・緑のままだと読めない
                                                // (2.3:1)。白が読める濃さに寄せる。
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: SemanticColors
                                                      .readableOn(
                                                    r == 'W'
                                                        ? SemanticColors
                                                            .positive(context)
                                                        : r == 'L'
                                                            ? SemanticColors
                                                                .negative(
                                                                    context)
                                                            : Colors
                                                                .grey.shade600,
                                                    Colors.white,
                                                  ),
                                                ),
                                                child: Text(
                                                  r,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // いま何が結果に効いているか。戦術・習熟度・指示と
                        // 効く要素が増えたのに、それを見る場所が無かった。
                        const SizedBox(height: 12),
                        // 横画面では、上の帯に同じ進むボタンが常にある。同じ
                        // ボタンを2つ並べないよう、こちらは上の帯が無い
                        // 縦画面のときだけ出す(2026-11-24)。
                        if (!EmbeddedInShell.of(context)) ...[
                          FilledButton(
                            key: const ValueKey('advance-button'),
                            onPressed: () => advanceToNextStop(context),
                            // 長押しでまとめて進む(上の帯の進むボタンと同じ)。
                            onLongPress: () => showSimAheadDialog(context),
                            child: Text(advanceButtonLabel(gameState) ??
                                Tr.pick('次の節へ', 'Next matchday')),
                          ),
                          const SizedBox(height: 4),
                        ],
                        // 何も決めることが無い週を続けて進める。
                        OutlinedButton(
                          key: const ValueKey('advance-to-decision'),
                          onPressed: gameState.inboxActions.isEmpty
                              ? () => _advanceToDecision(context)
                              : null,
                          child: Text(Tr.pick('決めることが出るまで進む',
                              'Play on until a decision is needed')),
                        ),
                        // 押せないときは、理由をそばに出す。
                        if (gameState.inboxActions.isNotEmpty)
                          DisabledReason(Tr.pick(
                              '答えを待つものがあります。先に上の「やること」の必須に答えてください。',
                              'Something is waiting for your answer. Deal with the must-do items above first.')),
                        // 「結果だけ見る」は「次の節へ」と同じ動きになり、
                        // 偵察レポートは監督の仕事なので、どちらも置かない。
                      ],
                    ),
                  ),
                ),
              ],
              more: [
              // 数字のタイルは「クラブの数字」にたたむ(2026-11-25)。開いた
              // ときにスクロールなしで順位と目標・2つの期待・必須・おすすめが
              // 見えるように。資金と2つの期待は、横画面では上の帯にある。
              _NumbersSection(
                gameState: gameState,
                userTeam: userTeam,
                userRow: userRow,
                net: net,
              ),
              // 理事会の路線。順位だけでなく戦い方も見られている。
              // 守れていないことに気づけないと、信頼が落ちる理由が
              // 分からないまま解任される。
              if ((gameState.save?.clubVision ?? ClubVision.none) !=
                  ClubVision.none)
                Card(
                  child: ListTile(
                    leading: Icon(
                      gameState.isClubVisionSatisfied
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: gameState.isClubVisionSatisfied
                          ? SemanticColors.positive(context)
                          : SemanticColors.negative(context),
                    ),
                    title: Text(
                      Tr.pick('理事会の路線: ${gameState.save!.clubVision.label}',
                          'Board direction: ${gameState.save!.clubVision.label}'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      // 評価はシーズン終了時に一度だけ。いま守れているかと、
                      // 今季どれだけ守れてきたかの両方を出す。片方だけだと
                      // 「いま直せば間に合うのか」が分からない。
                      (gameState.isClubVisionSatisfied
                              ? Tr.pick('守れています。', 'You are meeting it. ')
                              : Tr.pick(
                                  '守れていません。', 'You are not meeting it. ')) +
                          gameState.clubVisionProgressLabel +
                          gameState.save!.clubVision.requirement,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              // まだ見せていない大事な場面があれば、画面いっぱいの1枚で出す。
              const BigMomentPresenter(),
              if (gameState.save?.frontPageHeadline != null)
                const FrontPageCard(),
              // 横画面では、どの画面も左メニューの項目から開ける。同じ入口を
              // 大きなタイルで並べ直すと、状況ページが縦に長くなるだけなので出さない。
              if (!EmbeddedInShell.of(context)) ...[
                const SizedBox(height: 16),
                Text(Tr.pick('クラブ運営', 'Running the club'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: constraints.maxWidth > 500 ? 3 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      for (final dest in quickAccessDestinations)
                        _ActionTile(
                          icon: dest.icon,
                          label: dest.label,
                          color: dest.color,
                          // まだ中身が空になる画面は、開く前にその旨を見せる。
                          lockedReason: dest.lockedReason?.call(gameState),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: dest.builder)),
                        ),
                    ],
                  ),
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1年の収支の見込み。経営の画面の「収支」と同じ数([GameStateFinance.
  /// annualNetForecast])。以前はここだけ1節の収入から**週**の給料を引く
  /// 別の式で、「週収支」が経営の画面より甘く出ていた(2026-11-23)。
  int _netWeekly(GameState gameState) => gameState.annualNetForecast;

  String _fixtureLabel(League league, Fixture f) {
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
    return '$home vs $away';
  }

  Future<void> _playMatch(BuildContext context) async {
    FeedbackService.tap();
    final gameState = context.read<GameState>();
    // 試合にオーナーは直接関わらない。先発も構えも監督が決め、見せるのは
    // 数秒のダイジェストと、2つの期待の動きだけ。
    final fixture = gameState.save?.league.nextUnplayedFixture;
    if (fixture == null) return;
    await _quickSimNextMatch(context, fixture);
  }

  /// 受信箱に答えを待つものが出るまで(最大8節)、節を続けて進め、
  /// 勝ち・引き分け・負けの数と、止まった理由を知らせる。
  Future<void> _advanceToDecision(BuildContext context) async {
    FeedbackService.tap();
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<MatchResult> results;
    try {
      results = await gameState.advanceToNextDecision();
    } catch (e) {
      if (context.mounted) _showProgressFailedSnackBar(context, e);
      return;
    }
    if (!context.mounted) return;
    var w = 0, d = 0, l = 0;
    for (final r in results) {
      final home = r.homeTeamId == userId;
      final ours = home ? r.homeGoals : r.awayGoals;
      final theirs = home ? r.awayGoals : r.homeGoals;
      if (ours > theirs) {
        w++;
      } else if (ours == theirs) {
        d++;
      } else {
        l++;
      }
    }
    final why = gameState.inboxActions.isNotEmpty
        ? gameState.inboxActions.first
        : (gameState.save?.league.isSeasonComplete ?? false)
            ? Tr.pick('季が終わりました', 'The season is over')
            : Tr.pick('${GameStateRivals.advanceLimit}節進めたので一度止めました',
                'Stopped after ${GameStateRivals.advanceLimit} matchdays');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(Tr.pick('${results.length}節進めました($w勝$d分$l敗)。$why',
          'Played ${Tr.plural(results.length, 'matchday')} (W$w D$d L$l). $why')),
      duration: const Duration(seconds: 6),
    ));
    _showMatchdayNotifications(context, gameState);
  }

  /// ライブ観戦せず、次節の結果だけを一括で確定させる(クイックシム)。
  Future<void> _quickSimNextMatch(BuildContext context, Fixture next) async {
    FeedbackService.tap();
    FeedbackService.kickOff();
    final gameState = context.read<GameState>();
    final userTeamId = gameState.userTeam.id;
    final teams = gameState.save!.league.teams;

    final supportBefore = gameState.save!.confidence;
    final shareBefore = gameState.save!.shareholderExpectation;
    final MatchResult? result;
    try {
      result = await gameState.playNextMatchdayQuickSim();
    } catch (e) {
      if (context.mounted) _showProgressFailedSnackBar(context, e);
      return;
    }
    if (!context.mounted || result == null) return;

    await showMatchDigestDialog(
      context,
      result: result,
      userTeamId: userTeamId,
      teams: teams,
      competition: Tr.pick('リーグ戦 第${next.matchday}節',
          'League • Matchday ${next.matchday}'),
      supportDelta:
          (gameState.save?.confidence ?? supportBefore) - supportBefore,
      shareDelta:
          (gameState.save?.shareholderExpectation ?? shareBefore) - shareBefore,
    );
    if (!context.mounted) return;
    _showMatchdayNotifications(context, gameState);
    _showMonthlyAwardNotification(context, gameState);
    showAchievementUnlockNotification(context, gameState);
  }

  /// 節送り処理中に予期しない例外が発生した場合、ボタンが無反応に見える
  /// (何もフィードバックがないまま処理が失敗する)事態を避けるための通知。
  void _showProgressFailedSnackBar(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Tr.pick(
            '節の進行に失敗しました: $error', 'The matchday could not be played: $error')),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
      ),
    );
  }


  /// 節送り時に発生しうる複数の通知(契約満了・リリース条項発動・代表召集・
  /// ローン復帰・CPU移籍ニュース・資金危機警告)をまとめて表示する。1件だけ
  /// なら従来通りSnackBarで、複数同時に発生した場合はスナックバーの
  /// 連続表示で見落とさないよう1つの要約ダイアログにまとめる。
  void _showMatchdayNotifications(BuildContext context, GameState gameState) {
    // 受信箱への振り分けは matchday_notices.dart。週の処理がすでにクラブ
    // ニュースに書いた知らせは、ここで積み直さない(2通になっていた)。
    final messages = <(String text, bool isWarning)>[
      for (final n in routeMatchdayNotices(gameState)) (n.text, n.isWarning),
    ];
    // 締切を過ぎて既定の答えで片付けた決めごと。勝手に決まったことは
    // 必ず画面で知らせる(受信箱に積むだけだと気づかない)。
    for (final note in gameState.lastAutoDecisions) {
      messages.add((note, true));
    }
    gameState.lastAutoDecisions = [];

    if (messages.isEmpty) return;
    if (messages.length == 1) {
      final (text, isWarning) = messages.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: isWarning ? Colors.red.shade700 : null,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Tr.pick('今節のお知らせ', 'This matchday')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (text, isWarning) in messages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isWarning ? Icons.warning_amber : Icons.info_outline,
                        size: 18,
                        color: isWarning
                            ? SemanticColors.ink(context, Colors.red.shade700)
                            : SemanticColors.ink(context, Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Tr.pick('閉じる', 'Close')),
          ),
        ],
      ),
    );
  }

  void _showMonthlyAwardNotification(
    BuildContext context,
    GameState gameState,
  ) {
    final monthlyAward = gameState.lastMonthlyManagerAward;
    if (monthlyAward != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text(Tr.pick('$monthlyAward クラブの監督が月間最優秀監督賞を受賞しました！',
              'Your manager won Manager of the Month for $monthlyAward.'))));
      gameState.lastMonthlyManagerAward = null;
    }
  }

  /// シーズン開始時の通知(昇降格・報奨金・引退・契約満了・契約警告・
  /// 緊急補強・年間監督賞・スーパーカップ)をまとめて表示する。従来は
  /// SnackBarを最大8件連続表示しており(1件5秒のキューで長時間流れ続け、
  /// 途中のものを見落としやすかった)、複数件あるときは1つのレポート
  /// ダイアログへ集約する。1件だけなら従来通りSnackBarで軽く流す。
  Future<void> _showSeasonStartReport(
    BuildContext context,
    GameState gameState,
  ) async {
    final messages = <(String text, _ReportTone tone, _ReportPart part)>[];

    // 節目の絵。昇格と優勝のときだけ出す。毎シーズン出すと、節目が
    // 節目でなくなる。
    final finale = gameState.lastSeasonFinale;
    gameState.lastSeasonFinale = SeasonFinale.none;
    final art = switch (finale) {
      SeasonFinale.champion => 'assets/art/championship.jpg',
      SeasonFinale.promoted => 'assets/art/promotion.jpg',
      SeasonFinale.none => null,
    };

    // 先頭は自クラブの結果(順位・2つの期待・お金・来季)。以前は出来事
    // だけで、自分がどう終わったのかが分からなかった(2026-11-23)。
    final resultLines = gameState.lastSeasonResultLines;
    gameState.lastSeasonResultLines = null;
    final message = gameState.lastDivisionChangeMessage;
    if (message != null) {
      messages.add((
          message,
          gameState.lastDivisionChangeIsGood
              ? _ReportTone.good
              : _ReportTone.bad, _ReportPart.results));
      gameState.lastDivisionChangeMessage = null;
    }
    final boardBonus = gameState.lastBoardBonusNote;
    if (boardBonus != null) {
      messages.add((boardBonus, _ReportTone.good, _ReportPart.money));
      gameState.lastBoardBonusNote = null;
    }
    final contractNote = gameState.lastManagerContractNote;
    if (contractNote != null) {
      messages.add((contractNote, _ReportTone.neutral, _ReportPart.squad));
      gameState.lastManagerContractNote = null;
    }
    if (gameState.lastSeasonManagerAwardWon) {
      messages.add((
        Tr.pick(
            'クラブの監督が年間最優秀監督賞を受賞しました！', 'Your manager won Manager of the Year.'),
        _ReportTone.good, _ReportPart.results));
      gameState.lastSeasonManagerAwardWon = false;
    }
    final superCupNews = gameState.lastSuperCupNews;
    if (superCupNews != null) {
      messages.add((
          superCupNews,
          gameState.lastSuperCupWon
              ? _ReportTone.good
              : _ReportTone.neutral, _ReportPart.results));
      gameState.lastSuperCupNews = null;
    }
    final retirees = gameState.lastRetirements;
    if (retirees.isNotEmpty) {
      messages.add((
        Tr.pick('引退: ${retirees.join('、')}', "Retired: ${retirees.join(', ')}"),
        _ReportTone.neutral, _ReportPart.squad));
      gameState.lastRetirements = [];
    }
    final contractExpired = gameState.lastContractExpirations;
    if (contractExpired.isNotEmpty) {
      messages.add((
        Tr.pick('契約満了で退団: ${contractExpired.join('、')}',
            "Left on a free at the end of their contract: ${contractExpired.join(', ')}"),
        _ReportTone.neutral, _ReportPart.squad));
      gameState.lastContractExpirations = [];
    }
    // 借りていた選手は契約満了ではなく、ローン期間満了で貸し元へ戻る。
    final loanEndings = gameState.lastLoanEndings;
    if (loanEndings.isNotEmpty) {
      messages.add((
        Tr.pick('ローン期間満了で貸し元へ復帰: ${loanEndings.join('、')}',
            "Loan spells ended, returned to their parent clubs: ${loanEndings.join(', ')}"),
        _ReportTone.neutral, _ReportPart.squad));
      gameState.lastLoanEndings = [];
    }
    final contractWarnings = gameState.lastContractWarnings;
    if (contractWarnings.isNotEmpty) {
      messages.add((
        Tr.pick('契約最終年に突入: ${contractWarnings.join('、')}',
            "Into the final year of their contract: ${contractWarnings.join(', ')}"),
        _ReportTone.neutral, _ReportPart.squad));
      gameState.lastContractWarnings = [];
    }
    final emergencySignings = gameState.lastEmergencySignings;
    if (emergencySignings.isNotEmpty) {
      messages.add((
        Tr.pick('緊急補強: ${emergencySignings.join('、')}',
            "Emergency signings: ${emergencySignings.join(', ')}"),
        _ReportTone.neutral, _ReportPart.squad));
      gameState.lastEmergencySignings = [];
    }

    final summary = resultLines ?? const <String>[];
    if (messages.isEmpty && art == null && summary.isEmpty) return;
    // 絵があるときは必ずダイアログで出す。スナックバーには絵が入らない。
    if (messages.length == 1 && art == null && summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messages.first.$1),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    // 横画面(高さ375など)では、絵を縦に積むと結果が欄に収まらず、
    // スクロールできることも分からなかった。横画面では絵を左・結果を右の
    // 2列にし、上下の余白を詰め、スクロールの手掛かり(つまみ)を常に出す。
    // 成績・お金・出入りの3つに分ける(2026-11-25 FM の季の始まりの報告)。
    // 以前は全部を1本の一覧に並べていて、順位とお金と退団者が混ざっていた。
    bool isMoneyLine(String l) =>
        l.contains(Tr.pick('資金の増減', 'Funds over')) ||
        l.contains(Tr.pick('給与', 'Wages up'));
    final parts = <_ReportPart, (List<String>, List<(String, _ReportTone)>)>{
      for (final p in _ReportPart.values)
        p: (<String>[], <(String, _ReportTone)>[]),
    };
    for (final line in summary) {
      parts[isMoneyLine(line) ? _ReportPart.money : _ReportPart.results]!
          .$1
          .add(line);
    }
    for (final (text, tone, part) in messages) {
      parts[part]!.$2.add((text, tone));
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final landscape = size.width > size.height;
        Widget artImage(String path) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(path, fit: BoxFit.cover),
              ),
            );
        Widget partList(_ReportPart part) {
          final (lines, notes) = parts[part]!;
          if (lines.isEmpty && notes.isEmpty) {
            return Center(
              child: Text(
                Tr.pick('知らせはありません', 'Nothing to report'),
                style:
                    TextStyle(color: SemanticColors.subtleText(dialogContext)),
              ),
            );
          }
          return ListView(
            key: ValueKey('season-report-${part.name}'),
            padding: const EdgeInsets.only(top: 8, right: 6),
            children: [
              if (part == _ReportPart.results && art != null && !landscape)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: artImage(art),
                ),
              if (lines.isNotEmpty)
                Container(
                  key: part == _ReportPart.results
                      ? const ValueKey('season-result-summary')
                      : null,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, line) in lines.indexed)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
                          child: Text(line,
                              style: i == 0 && part == _ReportPart.results
                                  ? const TextStyle(fontWeight: FontWeight.bold)
                                  : const TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              // 良い知らせ・悪い知らせ・ふつうで印を分ける。悪い知らせ
              // (降格・プレーオフ敗退)に祝いの印が付いていた(2026-11-25)。
              for (final (text, tone) in notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (tone) {
                          _ReportTone.good => Icons.celebration,
                          _ReportTone.bad => Icons.trending_down,
                          _ReportTone.neutral => Icons.info_outline,
                        },
                        key: ValueKey('report-tone-${tone.name}'),
                        size: 18,
                        color: switch (tone) {
                          _ReportTone.good =>
                            SemanticColors.ink(context, Colors.amber.shade700),
                          _ReportTone.bad => SemanticColors.negative(context),
                          _ReportTone.neutral =>
                            SemanticColors.ink(context, Colors.grey),
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
            ],
          );
        }

        int count(_ReportPart p) => parts[p]!.$1.length + parts[p]!.$2.length;
        final tabs = DefaultTabController(
          length: _ReportPart.values.length,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  for (final p in _ReportPart.values)
                    Tab(
                      key: ValueKey('season-report-tab-${p.name}'),
                      height: 36,
                      text: count(p) == 0 ? p.label : '${p.label} ${count(p)}',
                    ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final p in _ReportPart.values) partList(p),
                  ],
                ),
              ),
            ],
          ),
        );
        // 横画面は縦が短い。高さを画面に合わせて決め、タブの中だけ送る。
        final height =
            (size.height - (landscape ? 150 : 260)).clamp(180.0, 420.0);
        return AlertDialog(
          key: const ValueKey('season-start-report'),
          insetPadding: landscape
              ? const EdgeInsets.symmetric(horizontal: 40, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          titlePadding:
              landscape ? const EdgeInsets.fromLTRB(24, 14, 24, 0) : null,
          contentPadding:
              landscape ? const EdgeInsets.fromLTRB(24, 6, 14, 0) : null,
          actionsPadding:
              landscape ? const EdgeInsets.fromLTRB(24, 0, 24, 8) : null,
          title: Text(switch (finale) {
            SeasonFinale.champion => Tr.pick('優勝！', 'Champions!'),
            SeasonFinale.promoted => Tr.pick('昇格！', 'Promoted!'),
            SeasonFinale.none => Tr.pick('シーズン開始レポート', 'Pre-season report'),
          }),
          content: SizedBox(
            width: landscape ? 640 : double.maxFinite,
            height: height,
            child: art != null && landscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 180, child: artImage(art)),
                      const SizedBox(width: 14),
                      Expanded(child: tabs),
                    ],
                  )
                : tabs,
          ),
          actions: [
            // 昇格・優勝のときだけ、評価への道を添える。**押させない。**
            // いちばん機嫌のいい瞬間に置くだけで、閉じるのと並べてある。
            if (art != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ReviewPrompt().openStoreListing();
                },
                child: Text(Tr.pick('このアプリを評価する', 'Rate this app')),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startNextSeason(BuildContext context) async {
    final gameState = context.read<GameState>();
    try {
      await gameState.startNextSeason();
    } catch (e) {
      if (context.mounted) _showProgressFailedSnackBar(context, e);
      return;
    }
    // 全画面広告はここだけ。シーズンの区切りは進行が一段落する場所で、
    // 試合中やメニュー操作の途中に割り込むことがない。サポーターには
    // 出ない(MonetizationController 側で判定している)。
    if (context.mounted) {
      await context.read<MonetizationController>().showSeasonInterstitial();
    }
    if (context.mounted) {
      await _showSeasonStartReport(context, gameState);
    }
    // ストアの評価を頼むのはここだけ。シーズンを終えて、理事会の目標を
    // 達成した直後。区切りがついていて、かつ結果が良かった瞬間に限る。
    // 遊んでいる最中に割り込むと、むしろ悪い評価を呼ぶ。
    final save = gameState.save;
    if (save != null) {
      await ReviewPrompt().maybeAsk(
        season: save.league.season,
        metBoardTarget: (save.lastSeasonRank ?? 99) <= save.boardTargetRank,
      );
    }
    if (context.mounted &&
        gameState.userInvolvedInLastPromotionPlayoff &&
        gameState.lastPromotionPlayoffResults.isNotEmpty) {
      final results = gameState.lastPromotionPlayoffResults;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(Tr.pick('昇格プレーオフ結果', 'Promotion play-off results')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(line),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        ),
      );
      gameState.lastPromotionPlayoffResults = [];
      gameState.userInvolvedInLastPromotionPlayoff = false;
    }
    if (context.mounted && gameState.lastSeasonGrowthSummary.isNotEmpty) {
      final summary = List.of(gameState.lastSeasonGrowthSummary)
        ..sort((a, b) => b.overallDelta.compareTo(a.overallDelta));
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(Tr.pick('シーズン成長サマリー', 'Season growth summary')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: summary.length,
              itemBuilder: (context, index) {
                final s = summary[index];
                final delta = s.overallDelta;
                final deltaLabel = delta > 0 ? '+$delta' : '$delta';
                final deltaColor = delta > 0
                    ? SemanticColors.positive(context)
                    : delta < 0
                        ? SemanticColors.negative(context)
                        : Theme.of(context).disabledColor;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.playerName)),
                      Text('${s.overallBefore} → ${s.overallAfter}'),
                      const SizedBox(width: 8),
                      Text(
                        deltaLabel,
                        style: TextStyle(
                          color: deltaColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Tr.pick('閉じる', 'Close')),
            ),
          ],
        ),
      );
    }
    if (context.mounted) showAchievementUnlockNotification(context, gameState);
  }
}

/// 状況の札を、横画面は左右2つの欄に、縦長は1本に並べる。
///
/// - [top]: 帯(順位・目標・前の月の期待)・最後通告・受信箱・目標
/// - [todos]: 「やること」(必須とおすすめ)
/// - [match]: 次の試合・カップ戦・季の終わり
/// - [more]: たたんだ数字・理事会の路線・一面
///
/// 開いたとき、スクロールなしで順位と目標・2つの期待・必須・おすすめの上位が
/// 見えるように、[more] は横画面では左の欄の下、縦長ではいちばん下へ
/// (2026-11-25)。
List<Widget> _arrange({
  required bool wide,
  required List<Widget> top,
  required List<Widget> todos,
  required List<Widget> match,
  required List<Widget> more,
}) =>
    wide
        ? [...top, ...more, const PaneBreak(divider: false), ...todos, ...match]
        : [...top, ...todos, ...match, ...more];

/// 数字のタイル。縦長(上の帯が無い)ときの資金と2つの期待だけを開いたまま
/// 出し、残り(勝点・平均総合力・オーナーの評判・観客動員)は「クラブの数字」
/// にたたむ(2026-11-25)。
class _NumbersSection extends StatelessWidget {
  const _NumbersSection({
    required this.gameState,
    required this.userTeam,
    required this.userRow,
    required this.net,
  });

  final GameState gameState;
  final Team userTeam;
  final StandingRow userRow;
  final int net;

  Widget _grid(BuildContext context, List<Widget> tiles) => LayoutBuilder(
        builder: (context, constraints) => GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: constraints.maxWidth > 500 ? 3 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 縦横比で高さを決めると、補足行やプログレスバーを持つ
          // タイルだけ中身がはみ出す。必要な高さを直接指定し、
          // 文字サイズ設定に合わせて伸ばす。
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(108),
          children: tiles,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final save = gameState.save!;
    // 資金と2つの期待は、横画面では上バーに出ている。3か所に同じ数字が
    // 並んでいたので、上バーが無いときだけ出す。
    final primary = EmbeddedInShell.of(context)
        ? const <Widget>[]
        : [
            _StatTile(
              icon: Icons.account_balance_wallet,
              label: Tr.pick('資金', 'Funds'),
              value: formatMoney(save.budget),
              sub: Tr.pick(
                  '1年の収支 ${net >= 0 ? '+' : ''}${formatMoney(net)}',
                  "Per year ${net >= 0 ? '+' : ''}${formatMoney(net)}"),
              color: net >= 0
                  ? SemanticColors.positive(context)
                  : SemanticColors.negative(context),
              subColor: net >= 0
                  ? SemanticColors.positive(context)
                  : SemanticColors.negative(context),
            ),
            // 2つの期待。成績・順位はサポーター、収支は株主が見ている。
            _StatTile(
              icon: Icons.shield,
              label: Tr.pick('サポーターの期待', 'Supporter expectation'),
              glossaryTerm: Tr.pick('サポーターの期待', 'Supporter expectation'),
              value: '${save.confidence}',
              sub: Tr.pick('結果とオーナーの手', 'Results and your moves'),
              progress: save.confidence / 100,
              color: save.confidence <= 25
                  ? SemanticColors.ink(context, Colors.redAccent)
                  : SemanticColors.ink(context, Colors.teal.shade700),
            ),
            _StatTile(
              icon: Icons.account_balance,
              label: Tr.pick('株主の期待', 'Shareholder expectation'),
              value: '${save.shareholderExpectation}',
              sub: Tr.pick('収支', 'Finances'),
              progress: save.shareholderExpectation / 100,
              color: save.shareholderExpectation <= 25
                  ? SemanticColors.ink(context, Colors.redAccent)
                  : SemanticColors.ink(context, Colors.amber.shade800),
            ),
          ];
    final rest = [
      // 順位は帯へ移した。空いた枠には勝点を置く。
      // 順位だけでは「あと何が要るのか」が分からない。
      _StatTile(
        icon: Icons.emoji_events,
        label: Tr.pick('勝点', 'Points'),
        value: '${userRow.points}',
        sub: Tr.pick('${userRow.won}勝${userRow.draw}分${userRow.lost}敗',
            '${userRow.won}W ${userRow.draw}D ${userRow.lost}L'),
        color: SemanticColors.ink(context, Colors.amber.shade800),
      ),
      _StatTile(
        icon: Icons.bar_chart,
        label: Tr.pick('平均総合力', 'Average overall'),
        value: '${userTeam.overallRating}',
        color: SemanticColors.ink(context, Colors.blue.shade700),
        glossaryTerm: Tr.pick('総合力', 'Overall'),
      ),
      _StatTile(
        icon: Icons.star,
        // オーナーとしての世間の評価(グッズ収入などに効く)。
        label: Tr.pick('オーナーの評判', 'Your reputation'),
        glossaryTerm: Tr.pick('オーナーの評判', 'Reputation'),
        value: '${gameState.managerReputation}',
        progress: gameState.managerReputation / 100,
        color: SemanticColors.ink(context, Colors.deepPurple),
      ),
      _StatTile(
        icon: Icons.groups,
        label: Tr.pick('観客動員', 'Attendance'),
        glossaryTerm: Tr.pick('観客動員', 'Attendance'),
        value: Tr.pick(
            '${formatCount(gameState.lastMatchAttendance ?? gameState.expectedAttendance)}人',
            formatCount(gameState.lastMatchAttendance ??
                gameState.expectedAttendance)),
        sub: Tr.pick('収容人数 ${formatCount(gameState.stadiumCapacity)}人',
            'Capacity ${formatCount(gameState.stadiumCapacity)}'),
        color: SemanticColors.ink(context, Colors.brown.shade600),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primary.isNotEmpty) ...[
          _grid(context, primary),
          const SizedBox(height: 8),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const ValueKey('home-numbers'),
            leading: const Icon(Icons.insights_outlined),
            title: Text(Tr.pick('クラブの数字', 'Club numbers'),
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(
              Tr.pick(
                  '勝点${userRow.points}・平均総合力${userTeam.overallRating}・評判${gameState.managerReputation}',
                  '${userRow.points} pts • overall ${userTeam.overallRating} • reputation ${gameState.managerReputation}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [_grid(context, rest)],
          ),
        ),
      ],
    );
  }
}

class _SuperCupCard extends StatelessWidget {
  final GameState gameState;

  const _SuperCupCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final match = gameState.pendingSuperCup!;
    final teams = gameState.save!.allTeams;
    final userId = gameState.userTeam.id;
    final opponentId =
        match.homeTeamId == userId ? match.awayTeamId : match.homeTeamId;
    final opponentName = teams.firstWhere((t) => t.id == opponentId).name;
    final date = CalendarEngine.formatShortDate(
        gameState.seasonCalendar.superCupDate);
    // 試合は進むボタンから行う(2026-11-24。以前はここに「クイック消化」が
    // あり、大会ごとに試合の入口が違った)。この札は日付の案内だけ。
    return Card(
      key: const ValueKey('super-cup-card'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('スーパーカップ', 'Super Cup'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(Tr.pick(
                '開幕前特別マッチ: $dateに$opponentNameと対戦します。進むボタンがその日に止まります。',
                'The curtain-raiser: you face $opponentName on $date. The advance button stops on that day.')),
          ],
        ),
      ),
    );
  }
}

/// 知らせの札(見出し・本文・右寄せのボタンを縦に積む)。
///
/// 以前は ListTile の右にボタンを置いていて、文字1.3〜1.5倍では
/// 本文が細い列に押し込まれ、札が縦に長くなっていた(2026-11-23)。
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.color,
    required this.onColor,
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
  });

  final Color color;

  /// 地の上の字と印の色(地が primaryContainer なら onPrimaryContainer)。
  final Color onColor;
  final IconData icon;
  final String title;
  final String body;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: onColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: onColor)),
                      const SizedBox(height: 2),
                      Text(body,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: onColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: button),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final double? progress;

  /// 補足の行の色。良い/悪いを表すとき(週の収支)だけ渡す。渡さなければ
  /// 地に沈まない控えめな色(onSurfaceVariant)。以前は項目の色(濃い茶など)で、
  /// 暗い地では「収容人数 12000人」が読めなかった。
  final Color? subColor;

  /// 用語集で引く語。指定すると、タイルを押して意味を読めるようになる。
  /// 数字の意味が分からないまま画面を眺める時間を無くすためのもの。
  final String? glossaryTerm;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.progress,
    this.glossaryTerm,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _tile(context);
    final term = glossaryTerm;
    if (term == null) return tile;
    return Semantics(
      button: true,
      hint: Tr.pick('用語の説明を開く', 'Open the explanation'),
      child: InkWell(
        borderRadius: BorderRadius.circular(fmRadius(context, 16)),
        onTap: () {
          FeedbackService.tap();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GlossaryScreen(initialQuery: term),
            ),
          );
        },
        child: tile,
      ),
    );
  }

  Widget _tile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
      decoration: BoxDecoration(
        // **色をタイルごとに変えない。** 6枚が6色だった頃は、色に意味が
        // 無いのに目移りして、どれが大事なのか分からなかった。地は
        // 揃えて、色はアイコンと「良い/悪い」にだけ使う。
        // 真っ平らな灰色にすると、今度は整いすぎて素っ気ない。地の色に
        // その項目の色をごく薄く混ぜて、気配だけ残す。
        color: Color.alphaBlend(
            color.withValues(alpha: 0.035),
            scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainer),
        borderRadius: BorderRadius.circular(fmRadius(context, 16)),
        border: Border.all(
            color: scheme.brightness == Brightness.dark
                ? scheme.outline.withValues(alpha: 0.55)
                : scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // **上から積む。** 中央揃えだと、補足行やバーを持つタイルと
        // 持たないタイルで数字の高さがずれて、6枚が揃って見えない。
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              // 丸い印を足したぶん、見出しの幅が足りなくなって
              // 「監督としての…」と切れた。入らないぶんは縮める。
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // **数字は太いゴシックで大きく。** titleLarge は明朝で、経営の
          // 数字が本文に沈んでいた。桁が揃うよう等幅の数字にする。
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: subColor ?? scheme.onSurfaceVariant),
              ),
            ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// null 以外なら、まだ中身が空になる画面。開放条件を添えて控えめに出す。
  final String? lockedReason;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.lockedReason,
  });

  @override
  Widget build(BuildContext context) {
    final locked = lockedReason;
    return Material(
      color: color.withValues(alpha: locked == null ? 0.12 : 0.05),
      borderRadius: BorderRadius.circular(fmRadius(context, 16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(fmRadius(context, 16)),
        // 押しても開けないので、無反応にせず理由を出す。
        onTap: locked == null
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label: $locked')),
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    locked == null ? color : color.withValues(alpha: 0.35),
                child: Icon(
                  locked == null ? icon : Icons.lock_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (locked != null)
                      // タイルは固定比率で狭い。ここは要点だけ見せ、全文は
                      // 押したときの案内で出す。切り詰めないと溢れる。
                      Flexible(
                        child: Text(
                          locked,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: SemanticColors.subtleText(context),
                          ),
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

/// 期待が尽きてクラブを手放す画面。実績は殿堂に残り、別のクラブを買い直して
/// 続きを遊ぶ。最初からやり直すこともできる。
class _SaleScreen extends StatelessWidget {
  final String clubName;
  final SaleReason reason;

  const _SaleScreen({required this.clubName, required this.reason});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final candidates = gameState.buyoutCandidates;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              // **理由を上に置く。** 以前は 4:3 の絵が先頭で、横画面では
              // 開いた瞬間に絵しか見えず、なぜ手放すのかが分からなかった
              // (2026-11-23)。絵は理由の下に細い帯で出す。
              children: [
                Text(
                  Tr.pick(
                      '$clubName を手放すことになりました', 'You have to sell $clubName'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  switch (reason) {
                    SaleReason.supporters => Tr.pick(
                        'サポーターの不満が限界を超えました。最後通告から3か月のうちに期待を${GameStateSupporters.ultimatumLine}以上へ戻せず、オーナーの座に居られなくなりました。',
                        'The supporters have turned against you. Expectation did not get back to ${GameStateSupporters.ultimatumLine} within three months of their final warning.'),
                    SaleReason.funds => Tr.pick(
                        '資金が尽きました。借金が膨らみ、クラブを売って返すほかなくなりました。',
                        'The money has run out. The debts have grown too large, and selling the club is the only way to pay them.'),
                    SaleReason.shareholders => Tr.pick(
                        '株主の期待が尽きました。赤字が続き、株主に株を手放すよう迫られました。',
                        'The shareholders have lost faith after repeated losses.'),
                  },
                  textAlign: TextAlign.center,
                ),
                // 期待がどう落ちてきたか。直近の推移と、大きな増減の3件。
                if (reason == SaleReason.supporters) ...[
                  // 月ごとの推移と、前の月の内訳(何で下がったか)。
                  if (gameState.supporterMonthTrailLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        gameState.supporterMonthTrailLine!,
                        key: const ValueKey('sale-month-trend'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (gameState.lastMonthSupporterLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        gameState.lastMonthSupporterLine!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  // 節ごとの推移は、月ごとの推移が無い(旧セーブ)ときだけ。
                  if (gameState.supporterMonthTrailLine == null &&
                      gameState.supporterTrailLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        gameState.supporterTrailLine!,
                        key: const ValueKey('sale-trend'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  for (final (delta, why) in gameState.recentSupporterMoves())
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${delta > 0 ? '+$delta' : '$delta'}  $why',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: delta < 0
                                ? SemanticColors.negative(context)
                                : SemanticColors.positive(context)),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Text(
                  switch (reason) {
                    SaleReason.supporters => Tr.pick(
                        '次は: 目標順位に届く戦力を早めにそろえ、毎月の広報・ファンの手、手ごろなチケット、地域活動で期待を支えると良いでしょう。',
                        'Next time: build a squad that can reach the target early, and hold up expectation with a monthly PR or fan move, fair ticket prices and community work.'),
                    SaleReason.funds => Tr.pick(
                        '次は: 人件費を収入の6割ほどに抑え、季の切り替え(6月までの給与)に備えて資金を残すと良いでしょう。',
                        'Next time: keep wages to about 60% of income, and keep cash back for the wages due before the season changes over.'),
                    SaleReason.shareholders => Tr.pick(
                        '次は: スポンサーを結び、人件費を抑えて、黒字の季を作ると株主の期待が戻ります。',
                        'Next time: sign sponsors and keep wages down; a season in profit wins the shareholders back.'),
                  },
                  key: const ValueKey('sale-advice'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                // 手放す夜の絵(大事な場面の1枚と同じ作風)。細い帯で。
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 96,
                    child: Image.asset('assets/art/forced_sale.jpg',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Tr.pick('これまでの実績は殿堂に残ります。別のクラブを買い直して続けましょう。',
                      'Your record stays in the hall of fame. Buy another club and carry on.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (final t in candidates)
                  Card(
                    child: ListTile(
                      leading:
                          ClubEmblem(teamId: t.id, teamName: t.name, size: 36),
                      title: Text(t.name),
                      subtitle: Text(Tr.pick('総合力 ${t.overallRating}',
                          'Overall ${t.overallRating}')),
                      trailing: FilledButton(
                        onPressed: () =>
                            context.read<GameState>().buyClub(t.id),
                        child: Text(Tr.pick('買う', 'Buy')),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  Tr.pick('別の国で新しいクラブを立ち上げる(3部から。その国の規則に従います)',
                      'Or found a new club in another country (starts in Tier 3, under that country\'s rules)'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (final theme in LeagueTheme.values)
                      if (theme != gameState.currentLeagueTheme)
                        OutlinedButton(
                          onPressed: () =>
                              context.read<GameState>().buyClubInCountry(theme),
                          child: Text(theme.flavorLabel),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await context.read<GameState>().deleteSave();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const StartScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: Text(Tr.pick('最初からやり直す', 'Start over from scratch')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 見出しの帯に置く小さな札。シーズンとフォーメーションに使う。
class _BandPill extends StatelessWidget {
  final String text;

  const _BandPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// シーズン開始レポートの分け方(成績・お金・出入り)。
enum _ReportPart {
  results,
  money,
  squad;

  String get label => switch (this) {
        _ReportPart.results => Tr.pick('成績', 'Results'),
        _ReportPart.money => Tr.pick('お金', 'Money'),
        _ReportPart.squad => Tr.pick('出入り', 'Comings & goings'),
      };
}

/// シーズン開始レポートの1行の調子(印の出し分け)。
enum _ReportTone { good, bad, neutral }
