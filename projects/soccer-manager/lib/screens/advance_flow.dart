import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/calendar_engine.dart';
import '../logic/day_events.dart';
import '../logic/economy_scale.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import 'cup_screen.dart';
import 'home_screen.dart';
import 'match_screen.dart';

/// 進むボタンの字。「9/5(土) 第8節」「9/1(火) 移籍の締切」。
/// 次の予定が無い(季の終わり)ときは null。
String? advanceButtonLabel(GameState gs) {
  final stop = gs.nextStop;
  if (stop == null) return null;
  return '${CalendarEngine.formatShortDate(stop.date)} ${stop.buttonLabel}';
}

/// 進むボタンのアイコン。試合の日は再生、それ以外は暦。
IconData advanceButtonIcon(GameState gs) =>
    (gs.nextStop?.kind.isMatch ?? true) ? Icons.play_arrow : Icons.event;

/// 次の予定がある日まで進む(何もない日は飛ばす。2026-11-22)。
///
/// - リーグ戦の日: 今まで通り、その節を行って結果を見せる。
/// - 自クラブのカップ戦の日: その試合を行い、試合の画面を開く。
/// - 給料日・放映権・移籍の窓・契約の期日: その日まで進めて、何が
///   起きたかを1行で知らせる。
///
/// 自クラブの出ないカップ戦は、その日までに来ていれば先に済ませる。
Future<void> advanceToNextStop(BuildContext context) async {
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
    case DayEventKind.friendly:
      // 進むボタンはここに止まらない(状況の画面の札から行う)。
      break;
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

/// 自クラブのカップ戦を1試合行い、試合の画面を開く。
Future<void> _playUserCupMatch(BuildContext context, GameState gs) async {
  FeedbackService.kickOff();
  final userId = gs.userTeam.id;
  final teams = gs.allTeamsForCups;
  final dom = gs.domesticCup?.nextUnplayedMatch;
  final domesticIsUser = dom != null &&
      gs.canPlayNextDomesticCupMatch &&
      (dom.homeTeamId == userId || dom.awayTeamId == userId);
  // 4クラブのスーパーカップ(スペイン・イタリア)も同じように止まって行う。
  final superCup = !domesticIsUser && gs.canPlayNextFourClubSuperCupMatch;
  final cont = gs.continentalCup;
  final title = domesticIsUser
      ? Tr.pick('国内カップ', 'Domestic Cup')
      : superCup
          ? Tr.pick('スーパーカップ', 'Super Cup')
          : (cont?.isGroupStageComplete ?? false)
              ? Tr.pick('大陸カップ 決勝トーナメント', 'Continental Cup knockout stage')
              : Tr.pick('大陸カップ グループステージ', 'Continental Cup group stage');
  final result = domesticIsUser
      ? await gs.playNextCupMatch()
      : superCup
          ? await gs.playNextFourClubSuperCupMatch()
          : cont == null
              ? null
              : cont.isGroupStageComplete
                  ? await gs.playNextContinentalKnockoutLeg()
                  : await gs.playNextContinentalGroupMatch();
  if (!context.mounted) return;
  showCupPrizeSnackBar(context, gs);
  if (result != null) {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MatchScreen(result: result, teams: teams, title: title),
    ));
  }
}
