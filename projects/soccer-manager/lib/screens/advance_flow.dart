import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/continental_cup_engine.dart';
import '../logic/cup_engine.dart';
import '../logic/day_events.dart';
import '../logic/economy_scale.dart';
import '../models/match_result.dart';
import '../monetization/quarterly_ad.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/achievement_unlock_notifier.dart';
import '../widgets/match_digest_dialog.dart';
import 'home_screen.dart';

/// 進むボタンの字。どこまで進むかを動詞つきで書く。
/// 「次の試合へ 9/5(土)」「カップ戦へ 9/9(水)」「給料日まで進む 7/31(金)」。
/// 以前は「9/5(土) 第8節」と行き先だけで、押すと何が起きるのかが字から
/// 読めなかった。次の予定が無い(季の終わり)ときは null。
String? advanceButtonLabel(GameState gs) {
  final stop = gs.nextStop;
  if (stop == null) return null;
  final full = CalendarEngine.formatShortDate(stop.date);
  // 英語は字が長いので、曜日を落として「31 Jul」だけにする(帯の幅に収める)。
  final date = Tr.pick(full, full.substring(full.indexOf(' ') + 1));
  return switch (stop.kind) {
    DayEventKind.leagueMatch =>
      Tr.pick('次の試合へ $date', 'Next match • $date'),
    DayEventKind.cupMatch ||
    DayEventKind.superCup ||
    DayEventKind.friendly =>
      Tr.pick('${stop.buttonLabel}へ $date', '${stop.buttonLabel} • $date'),
    // 試合でない日(給料日・放映権・移籍の窓・契約の期日)は、その名前。
    _ => Tr.pick(
        '${stop.buttonLabel}まで進む $date', 'Skip to ${stop.buttonLabel} • $date'),
  };
}

/// 進むボタンのアイコン。試合の日は再生、それ以外は暦。
IconData advanceButtonIcon(GameState gs) =>
    (gs.nextStop?.kind.isMatch ?? true) ? Icons.play_arrow : Icons.event;

/// 次の予定がある日まで進む(何もない日は飛ばす。2026-11-22)。
///
/// - 試合の日(リーグ戦・国内カップ・大陸カップ・スーパーカップ・親善試合):
///   その試合を行い、どの大会でも同じ結果のダイジェスト
///   ([showMatchDigestDialog])を出す。試合経過はその中から開く。
///   (2026-11-24 に揃えた。以前はカップ戦だけ試合経過の画面が開き、
///   スーパーカップと親善試合は進むボタンが止まらなかった)
/// - 給料日・放映権・移籍の窓・契約の期日: その日まで進めて、何が
///   起きたかを1行で知らせる。
///
/// 自クラブの出ないカップ戦は、その日までに来ていれば先に済ませる。
///
/// 進め終えたら、ゲームの中で3か月たっていれば全画面広告を出す
/// ([maybeShowQuarterlyAd])。
Future<void> advanceToNextStop(BuildContext context) async {
  await _advanceToNextStop(context);
  if (context.mounted) await maybeShowQuarterlyAd(context);
}

Future<void> _advanceToNextStop(BuildContext context) async {
  final gs = context.read<GameState>();
  final first = gs.nextStop;
  if (first == null) {
    // 予定が引けないとき(古いセーブなど)は今まで通り次の節へ。
    return const HomeScreen().playMatch(context);
  }
  await gs.playBackgroundCupMatchesBefore(first);
  if (!context.mounted) return;
  final stop = gs.nextStop;
  if (stop == null) return;
  switch (stop.kind) {
    case DayEventKind.leagueMatch:
      await const HomeScreen().playMatch(context);
    case DayEventKind.cupMatch:
      await _playUserCupMatch(context, gs);
    case DayEventKind.superCup:
      await _playSuperCup(context, gs);
    case DayEventKind.friendly:
      await _playFriendly(context, gs, stop);
    case DayEventKind.wages:
    case DayEventKind.broadcast:
    case DayEventKind.windowOpens:
    case DayEventKind.windowDeadline:
    case DayEventKind.preContracts:
    case DayEventKind.optionDeadline:
      FeedbackService.tap();
      final delta = await gs.advanceToDateStop(stop);
      if (!context.mounted) return;
      final hint = switch (stop.kind) {
        DayEventKind.windowDeadline =>
          Tr.pick('今日のうちなら補強・放出ができます。', 'You can still buy and sell today.'),
        DayEventKind.windowOpens =>
          Tr.pick('補強・放出ができます。', 'You can buy and sell again.'),
        DayEventKind.optionDeadline => Tr.pick(
            '延長オプションは今日までです。', 'Contract options must be taken up today.'),
        DayEventKind.preContracts => Tr.pick('今季末で契約が切れる他のクラブの選手と、仮契約を話せます。',
            'You can talk to players whose contracts end this summer.'),
        _ => '',
      };
      final money = delta == 0
          ? ''
          : Tr.pick('資金 ${formatMoneySigned(delta)}。',
              'Funds ${formatMoneySigned(delta)}. ');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Tr.pick(
            '${CalendarEngine.formatShortDate(stop.date)} ${stop.label}。$money$hint',
            '${CalendarEngine.formatShortDate(stop.date)} ${stop.label}. $money$hint')),
        duration: const Duration(seconds: 5),
      ));
  }
}

/// 試合を行って、結果のダイジェストを出す(どの大会でも同じ)。
///
/// [play] が試合を行う。期待の動きは試合の前後の差、賞金は
/// [GameState.lastCupPrizeNote](出したら消す)。
Future<void> _playAndShow(
  BuildContext context,
  GameState gs, {
  required String competition,
  required Future<MatchResult?> Function() play,
  String? Function()? penaltyNote,
}) async {
  FeedbackService.kickOff();
  final teams = gs.allTeamsForCups;
  final userId = gs.userTeam.id;
  final supportBefore = gs.save!.confidence;
  final shareBefore = gs.save!.shareholderExpectation;
  final result = await play();
  if (!context.mounted) return;
  final prize = gs.lastCupPrizeNote;
  gs.lastCupPrizeNote = null;
  if (result == null) {
    // 試合にならなかった(相手が決まっていない等)。賞金だけは知らせる。
    if (prize != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(prize)));
    }
    return;
  }
  await showMatchDigestDialog(
    context,
    result: result,
    userTeamId: userId,
    // 相手が別の部・別の国のクラブでも名前が引けるように、カップ戦の顔ぶれ
    // (リーグ戦の顔ぶれを含む)を渡す。
    teams: teams,
    competition: competition,
    supportDelta: (gs.save?.confidence ?? supportBefore) - supportBefore,
    shareDelta:
        (gs.save?.shareholderExpectation ?? shareBefore) - shareBefore,
    prizeNote: prize,
    penaltyNote: penaltyNote?.call(),
  );
  if (context.mounted) showAchievementUnlockNotification(context, gs);
}

/// PK戦で決まったときの一言。
String? _penaltyLine(String? penaltyWinnerId, String userId) {
  if (penaltyWinnerId == null) return null;
  return penaltyWinnerId == userId
      ? Tr.pick('PK戦で勝ち抜け', 'Through on penalties')
      : Tr.pick('PK戦で敗退', 'Out on penalties');
}

/// 自クラブのカップ戦(国内カップ・4クラブのスーパーカップ・大陸カップ)を
/// 1試合行う。
Future<void> _playUserCupMatch(BuildContext context, GameState gs) async {
  final userId = gs.userTeam.id;
  final domCup = gs.domesticCup;
  final dom = domCup?.nextUnplayedMatch;
  final domesticIsUser = dom != null &&
      gs.canPlayNextDomesticCupMatch &&
      (dom.homeTeamId == userId || dom.awayTeamId == userId);
  // 4クラブのスーパーカップ(スペイン・イタリア)も同じように止まって行う。
  final superCup = !domesticIsUser && gs.canPlayNextFourClubSuperCupMatch;
  final sc = gs.fourClubSuperCup;
  final scm = superCup ? gs.userFourClubSuperCupMatch : null;
  final cont = gs.continentalCup;
  final String competition;
  if (domesticIsUser) {
    competition = Tr.pick(
        '${domCup!.name} ${CupEngine.roundLabel(dom.round, domCup.totalRounds)}',
        '${domCup.name} • ${CupEngine.roundLabel(dom.round, domCup.totalRounds)}');
  } else if (superCup && sc != null && scm != null) {
    competition = Tr.pick('${sc.name} ${CupEngine.roundLabel(scm.round, 2)}',
        '${sc.name} • ${CupEngine.roundLabel(scm.round, 2)}');
  } else if (cont != null && !cont.isGroupStageComplete) {
    competition = Tr.pick('${cont.name} グループステージ', '${cont.name} • Group stage');
  } else if (cont != null) {
    final leg = ContinentalCupEngine.nextKnockoutLeg(cont);
    var total = 0;
    for (var n = cont.groups.length * 2; n > 1; n ~/= 2) {
      total++;
    }
    final round = leg == null
        ? ''
        : ContinentalCupEngine.roundLabel(leg.tie.round, total);
    final legNo = leg == null || leg.tie.singleLeg
        ? ''
        : Tr.pick(' 第${leg.tie.legs.length + 1}戦',
            ' • Leg ${leg.tie.legs.length + 1}');
    competition =
        Tr.pick('${cont.name} $round$legNo', '${cont.name} • $round$legNo');
  } else {
    competition = Tr.pick('カップ戦', 'Cup tie');
  }
  final tie = cont != null && cont.isGroupStageComplete
      ? ContinentalCupEngine.nextKnockoutLeg(cont)?.tie
      : null;
  await _playAndShow(
    context,
    gs,
    competition: competition,
    play: () async => domesticIsUser
        ? await gs.playNextCupMatch()
        : superCup
            ? await gs.playNextFourClubSuperCupMatch()
            : cont == null
                ? null
                : cont.isGroupStageComplete
                    ? await gs.playNextContinentalKnockoutLeg()
                    : await gs.playNextContinentalGroupMatch(),
    penaltyNote: () {
      if (domesticIsUser) {
        return dom.result == null
            ? null
            : _penaltyLine(dom.penaltyWinnerId, userId);
      }
      if (superCup && scm != null) {
        return _penaltyLine(scm.penaltyWinnerId, userId);
      }
      if (tie != null && tie.isComplete) {
        return _penaltyLine(tie.penaltyWinnerId, userId);
      }
      return null;
    },
  );
}

/// 開幕前のスーパーカップ(1試合。中立の会場)。
Future<void> _playSuperCup(BuildContext context, GameState gs) async {
  final match = gs.pendingSuperCup;
  if (match == null) return;
  await _playAndShow(
    context,
    gs,
    competition: Tr.pick('スーパーカップ', 'Super Cup'),
    play: gs.playSuperCup,
    penaltyNote: () => _penaltyLine(match.penaltyWinnerId, gs.userTeam.id),
  );
}

/// 開幕前の親善試合(順位・カップ戦・疲れには響かない)。
Future<void> _playFriendly(
    BuildContext context, GameState gs, DayEvent stop) async {
  final index = gs.friendlyIndexFor(stop);
  if (index == null) return;
  await _playAndShow(
    context,
    gs,
    competition: Tr.pick('親善試合', 'Friendly'),
    play: () => gs.playFriendly(index),
  );
}

/// 何節かまとめて進める(進むボタンの長押し。2026-11-25 にリーグの画面の
/// 「まとめてシミュレーション」のボタンから移した)。
Future<void> showSimAheadDialog(BuildContext context) async {
  final gameState = context.read<GameState>();
  if (gameState.save?.league.isSeasonComplete ?? true) return;
  final remainingMatchdays = gameState.save!.league.fixtures
      .where((f) => f.result == null)
      .map((f) => f.matchday)
      .toSet()
      .length;

  final choice = await showDialog<int>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(Tr.pick('まとめてシミュレーション', 'Sim ahead')),
      children: [
        for (final n in [1, 3, 5])
          if (n < remainingMatchdays)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, n),
              child: Text(Tr.pick('$n節先まで進める', 'Play $n matchdays')),
            ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, remainingMatchdays),
          child:
              Text(Tr.pick('シーズン終了まで進める', 'Play to the end of the season')),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(Tr.pick('キャンセル', 'Cancel')),
        ),
      ],
    ),
  );
  if (choice == null || choice <= 0 || !context.mounted) return;

  FeedbackService.tap();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(Tr.pick('$choice節分をシミュレーションしています…',
                  'Simulating $choice matchdays…')),
            ],
          ),
        ),
      ),
    ),
  );
  // 閉じる手段の無い進行中ダイアログを出しているので、**何があっても
  // 必ず閉じる**。途中で例外が出ると、ぐるぐる回る円だけが残って操作が
  // 一切できなくなる(アプリを再起動するしかない)。
  final List<MatchResult> results;
  try {
    results = await gameState.simulateAheadMatchdays(choice);
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
  if (!context.mounted) return;

  final league = gameState.save!.league;
  final userTeamId = gameState.userTeam.id;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(Tr.pick('シミュレーション結果', 'Simulation results')),
      content: SizedBox(
        width: double.maxFinite,
        child: results.isEmpty
            ? Text(
                Tr.pick('進行できる試合がありませんでした', 'There were no matches to play'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final r = results[i];
                  final isHome = r.homeTeamId == userTeamId;
                  final opponentId = isHome ? r.awayTeamId : r.homeTeamId;
                  final opponentName =
                      league.teams.firstWhere((t) => t.id == opponentId).name;
                  final userGoals = isHome ? r.homeGoals : r.awayGoals;
                  final oppGoals = isHome ? r.awayGoals : r.homeGoals;
                  return ListTile(
                    dense: true,
                    title: Text(Tr.pick('第${r.matchday}節 vs $opponentName',
                        'Matchday ${r.matchday} vs $opponentName')),
                    trailing: Text(
                      '$userGoals - $oppGoals',
                      style: Theme.of(context).textTheme.titleSmall,
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
  if (context.mounted) showAchievementUnlockNotification(context, gameState);
  if (context.mounted) await maybeShowQuarterlyAd(context);
}
