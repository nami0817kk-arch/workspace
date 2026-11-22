import '../l10n/tr.dart';
import '../logic/economy_scale.dart';
import '../state/game_state.dart';

/// 節送りのお知らせ1件。
class MatchdayNotice {
  const MatchdayNotice(this.text,
      {this.isWarning = false, this.alreadyInInbox = false});

  final String text;

  /// 注意(画面に出す)か。
  final bool isWarning;

  /// 週の処理ですでにクラブニュース(受信箱)に積んである知らせか。
  /// 画面の側でもう一度積むと、受信箱に同じ知らせが2通並ぶ。
  final bool alreadyInInbox;
}

/// 節送りのあいだに起きたこと([GameState]の「直近の出来事」)を読み、
/// 読んだものは空にしてお知らせの一覧にする。
///
/// リリース条項・代表の招集・ローン復帰・定期預金の満期・移籍市場は、
/// 週の処理([GameState]の週の処理)がクラブニュースに書いている
/// ので[MatchdayNotice.alreadyInInbox]にする(2026-11-23)。
List<MatchdayNotice> takeMatchdayNotices(GameState gameState) {
  final notices = <MatchdayNotice>[];

  // 借りていた選手のローン期間が終わった(週の処理・日付で終わるもの)。
  final loanEndings = gameState.lastLoanEndings;
  if (loanEndings.isNotEmpty) {
    notices.add(MatchdayNotice(Tr.pick(
        'ローン期間満了で貸し元へ復帰: ${loanEndings.join('、')}',
        "Loan spells ended, returned to their parent clubs: ${loanEndings.join(', ')}")));
    gameState.lastLoanEndings = [];
  }
  final expired = gameState.lastContractExpirations;
  if (expired.isNotEmpty) {
    notices.add(MatchdayNotice(Tr.pick('契約満了で退団: ${expired.join('、')}',
        "Left on a free at the end of their contract: ${expired.join(', ')}")));
    gameState.lastContractExpirations = [];
  }
  final autoSold = gameState.lastReleaseClauseSales;
  if (autoSold.isNotEmpty) {
    notices.add(MatchdayNotice(
        Tr.pick('リリース条項が発動し移籍が成立: ${autoSold.join('、')}',
            "Release clauses triggered, transfers completed: ${autoSold.join(', ')}"),
        alreadyInInbox: true));
    gameState.lastReleaseClauseSales = [];
  }
  final calledUp = gameState.lastInternationalCallUps;
  if (calledUp.isNotEmpty) {
    notices.add(MatchdayNotice(
        Tr.pick('代表召集: ${calledUp.join('、')}',
            "Called up for international duty: ${calledUp.join(', ')}"),
        alreadyInInbox: true));
    gameState.lastInternationalCallUps = [];
  }
  final loanReturns = gameState.lastLoanReturns;
  if (loanReturns.isNotEmpty) {
    notices.add(MatchdayNotice(
        Tr.pick('ローン放出から復帰: ${loanReturns.join('、')}',
            "Back from loan: ${loanReturns.join(', ')}"),
        alreadyInInbox: true));
    gameState.lastLoanReturns = [];
  }
  final maturedDeposits = gameState.lastMaturedDeposits;
  if (maturedDeposits.isNotEmpty) {
    final total = maturedDeposits.fold<int>(0, (s, d) => s + d.maturityValue);
    notices.add(MatchdayNotice(
        Tr.pick('定期預金が満期を迎え、${formatMoney(total)}が払い戻されました',
            'Your deposit matured and ${formatMoney(total)} was paid back'),
        alreadyInInbox: true));
    gameState.lastMaturedDeposits = [];
  }
  final feesPaid = gameState.lastAppearanceFeesPaid;
  if (feesPaid > 0) {
    // 出場給は資金から自動で引かれる。週次収支の見込みには出ているが、
    // 実際に引かれた額を知らせないと、資金だけが理由なく減ったように
    // 見える。
    notices.add(MatchdayNotice(Tr.pick('出場給として${formatMoney(feesPaid)}を支払いました',
        'You paid ${formatMoney(feesPaid)} in appearance fees')));
    gameState.lastAppearanceFeesPaid = 0;
  }
  final aiTransferNews = gameState.lastAiTransferNews;
  if (aiTransferNews != null) {
    // 週の処理が、成立した主力の移籍を1件ずつ書いている。
    notices.add(MatchdayNotice(
        Tr.pick('移籍市場: $aiTransferNews', 'Transfer market: $aiTransferNews'),
        alreadyInInbox: true));
    gameState.lastAiTransferNews = null;
  }
  // ユースを去った有望株。ユース画面にも出るが、そこを開かない週に
  // 起きると、名簿から静かに消えるだけになる。育てていた選手が去った
  // ことは、その節のうちに知らせる。
  final departures = gameState.lastYouthDepartures;
  if (departures.isNotEmpty) {
    final names = departures.map((d) => d.player.name).join(Tr.pick('、', ', '));
    final compensation =
        departures.fold<int>(0, (sum, d) => sum + d.compensation);
    notices.add(MatchdayNotice(
        Tr.pick('ユースを去りました: $names(育成補償金 ${formatMoney(compensation)})',
            'Left the academy: $names (development fee ${formatMoney(compensation)})'),
        isWarning: true));
    gameState.lastYouthDepartures = [];
  }

  final budgetCrisis = gameState.lastBudgetCrisisWarning;
  if (budgetCrisis != null) {
    notices.add(MatchdayNotice(budgetCrisis, isWarning: true));
    gameState.lastBudgetCrisisWarning = null;
  }
  return notices;
}

/// お知らせを受信箱に振り分け、画面に出すもの(注意)だけを返す。
///
/// 通知を減らす: 注意でないもの(代表召集・出場給・満期など)は受信箱に
/// 積むだけにして、画面には出さない。毎節ダイアログが出ると、本当に
/// 見るべき注意が埋もれる。週の処理がすでに積んだものは積み直さない。
List<MatchdayNotice> routeMatchdayNotices(GameState gameState) {
  final notices = takeMatchdayNotices(gameState);
  for (final n in notices) {
    if (!n.isWarning && !n.alreadyInInbox) gameState.addInboxNote(n.text);
  }
  return [
    for (final n in notices)
      if (n.isWarning) n
  ];
}
