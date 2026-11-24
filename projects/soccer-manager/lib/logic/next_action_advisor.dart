import '../models/club_infrastructure.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../l10n/tr.dart';
import 'contract_engine.dart';
import 'economy_scale.dart';
import 'youth_departure_engine.dart';

/// 「次にやること」1件。
class NextAction {
  /// 画面に出す一文。何をすればよいかが、これだけで分かるようにする。
  final String message;

  /// どの画面へ行けばよいか。ホームのタイルやドロワーの項目名と揃える。
  final NextActionTarget target;

  /// 放っておくと損が出るものは true。見た目を分けて、順番を追い越す。
  final bool urgent;

  /// 何の知らせか。「やること」の一覧(todo_advisor.dart)が、種類ごとに
  /// 題・重さ・行き先を決めるのに使う。
  final NextActionKind kind;

  const NextAction({
    required this.kind,
    required this.message,
    required this.target,
    this.urgent = false,
  });
}

/// 知らせの種類([NextActionAdvisor.all] が挙げる順)。
enum NextActionKind {
  ultimatum,
  staffVacant,
  sponsor,
  ownerGoal,
  rolloverShortfall,
  supporterFalling,
  transferDeadline,
  signingProposals,
  incomingOffer,
  budgetNegative,
  youthAtRisk,
  contractExpiring,
}

/// 行き先。画面そのものを持たせると、このファイルが UI に依存してしまう。
/// [transferOffers] は移籍の画面の「届いたオファー」のタブを開く。
/// [ownerWork] はオーナー室(広報・試合日のイベント)、[staff] はスタッフ、
/// [ownerGoal] はオーナーの目標を選ぶ一覧。
enum NextActionTarget {
  squad,
  youth,
  finance,
  transfer,
  transferOffers,
  ownerWork,
  staff,
  ownerGoal,
}

/// いまのクラブの状態を見て、次にやることを1つだけ挙げる。
///
/// 画面は30以上あり、何から手を付ければよいのかが分からない。
///
/// 複数を並べると結局どれからか分からなくなるため、出すのは常に1件。
class NextActionAdvisor {
  const NextActionAdvisor._();

  /// 契約残りがこの年数以下の主力は、放っておくと失う。
  static const int contractWarningYears = 1;

  /// 主力とみなす総合力の下限(チーム平均との比較)。全員を対象にすると
  /// 控えの契約まで急かすことになる。
  static const int keyPlayerMargin = 0;

  /// [transferDeadlineDaysLeft] は移籍の窓の締切までの残り日数
  /// (閉じているときは null)。[transferDeadlineBeforeNextMatch] は次の試合の
  /// 前に窓が閉まるか(この節のあいだが最後の機会)。締切は移籍画面を
  /// 開かないと見えないので、ホームからも知らせる。
  ///
  /// [includeSetup] は、始めたばかりのクラブの用意(スタッフ・スポンサー・
  /// オーナーの目標)も挙げるか。状況の画面のカードは true で呼ぶ。
  /// [supporterTrend] は直近の節でのサポーターの期待の増減、
  /// [rolloverShortfall] は季の切り替えの給与で資金が足りなくなる額。
  static List<NextAction> all(
    SaveGame save,
    Team team, {
    int? transferDeadlineDaysLeft,
    bool transferDeadlineBeforeNextMatch = false,
    bool hasSigningProposals = false,
    bool includeSetup = false,
    int? supporterTrend,
    int? rolloverShortfall,
    int? supporterUltimatumDaysLeft,
  }) {
    final actions = <NextAction>[];

    // サポーターの最後通告。期限までに戻せなければ手放すので、何よりも先に
    // (2026-11-23)。
    final ultimatum = supporterUltimatumDaysLeft;
    if (ultimatum != null) {
      actions.add(NextAction(
        kind: NextActionKind.ultimatum,
        message: Tr.pick(
            '最後通告: 残り$ultimatum日でサポーターの期待を10以上に戻さないと、クラブを手放します(いま${save.confidence})。広報・ファンの手、安いチケット、地域活動で支えましょう。',
            'Final warning: get supporter expectation back to 10 within ${Tr.plural(ultimatum, 'day')} or sell the club (now ${save.confidence}). Use a PR or fan move, cheaper tickets and community work.'),
        target: NextActionTarget.ownerWork,
        urgent: true,
      ));
    }

    // 開幕前は、まずクラブの用意。何から手を付けるか分からないまま
    // 第1節へ進めてしまうと、空席のスタッフとスポンサー無しで季を戦う。
    final preseason = !save.league.fixtures.any((f) =>
        f.result != null &&
        (f.homeTeamId == save.userTeamId || f.awayTeamId == save.userTeamId));
    if (includeSetup) {
      final roles = StaffRole.values.length;
      final hired = StaffRole.values
          .where((r) => save.infrastructure.staffFor(r) != null)
          .length;
      if (hired == 0 || (preseason && hired < roles)) {
        actions.add(NextAction(
        kind: NextActionKind.staffVacant,
          message: Tr.pick('スタッフが空席です($roles役中$hired人)。まず監督とコーチを雇いましょう。',
              'Staff posts are empty ($hired of $roles filled). Start by hiring a manager and coaches.'),
          target: NextActionTarget.staff,
        ));
      }
      if (save.sponsorDeal == null && save.pendingSponsorOffers.isNotEmpty) {
        actions.add(NextAction(
        kind: NextActionKind.sponsor,
          message: Tr.pick('スポンサーが未契約です。結ぶと毎節の収入が増えます。',
              'You have no sponsor. Signing one adds income every matchday.'),
          target: NextActionTarget.finance,
        ));
      }
      if (save.ownerGoal == null && preseason) {
        actions.add(NextAction(
        kind: NextActionKind.ownerGoal,
          message: Tr.pick('オーナーの目標が未設定です。決めると達成が殿堂に残ります。',
              'You have not set an owner goal. Achieving one puts it in the hall of fame.'),
          target: NextActionTarget.ownerGoal,
        ));
      }
    }

    // 季の切り替えで、6月までの給与がまとめて引かれる。7月の初めに赤字に
    // なるなら先に知らせる(説明なしに2億減って見えた)。
    final shortfall = rolloverShortfall;
    if (shortfall != null && shortfall > 0) {
      actions.add(NextAction(
        kind: NextActionKind.rolloverShortfall,
        message: Tr.pick('季の切り替えで6月までの給与が引かれ、資金が${formatMoney(shortfall)}足りなくなります。売却や借入で備えてください。',
            'Wages up to the end of June will leave you ${formatMoney(shortfall)} short at the changeover. Sell or borrow to cover it.'),
        target: NextActionTarget.finance,
        urgent: true,
      ));
    }

    // サポーターの期待が下がり続けている。0で手放すので、契約の知らせ
    // より先に、打てる手(広報・試合日のイベント)を示す。
    final trend = supporterTrend;
    if (trend != null && trend <= -supporterDropAlert) {
      actions.add(NextAction(
        kind: NextActionKind.supporterFalling,
        message: Tr.pick(
            'サポーターの期待が下がっています(直近で$trend、いま${save.confidence})。オーナー室の広報・ファン向けの手や、試合日のイベントで支えましょう。',
            'Supporter expectation is falling ($trend lately, now ${save.confidence}). Use PR and fan moves or a matchday event in the owner\'s office.'),
        target: NextActionTarget.ownerWork,
        urgent: save.confidence <= supporterUrgentLine,
      ));
    }

    // 移籍の締切。過ぎると次の窓まで動けない。
    final left = transferDeadlineDaysLeft;
    if (left != null &&
        (left <= deadlineWarningDays || transferDeadlineBeforeNextMatch)) {
      actions.add(NextAction(
        kind: NextActionKind.transferDeadline,
        message: left <= 0
            ? Tr.pick('今日が移籍の締切日です。', 'Today is transfer deadline day.')
            : transferDeadlineBeforeNextMatch
                ? Tr.pick('移籍の窓は次の試合の前に閉まります(残り$left日)。',
                    'The transfer window shuts before the next match (${Tr.plural(left, 'day')} left).')
                : Tr.pick('移籍の締切まで残り$left日です。',
                    'The transfer window shuts in ${Tr.plural(left, 'day')}.'),
        target: NextActionTarget.transfer,
      ));
    }

    // 監督から補強の候補が届いている。買うか見送るかを決める。
    if (hasSigningProposals) {
      actions.add(NextAction(
        kind: NextActionKind.signingProposals,
        message: Tr.pick('監督から補強の候補が届いています。買うか見送るかを決めてください。',
            'Your manager has picked out signing candidates. Sign them or pass.'),
        target: NextActionTarget.transfer,
      ));
    }

    // 他クラブから売却のオファーが届いている。承認するか断るかを決める。
    if (save.incomingOffers.isNotEmpty) {
      actions.add(NextAction(
        kind: NextActionKind.incomingOffer,
        message: Tr.pick(
            '${save.incomingOffers.first.playerName}に売却のオファーが届いています。承認するか断るかを決めてください。',
            'An offer for ${save.incomingOffers.first.playerName} has arrived. Accept or turn it down.'),
        target: NextActionTarget.transferOffers,
      ));
    }

    // 資金がマイナス。放置すると株主の期待が削られていく。
    if (save.budget < 0) {
      actions.add(NextAction(
        kind: NextActionKind.budgetNegative,
        message: Tr.pick('資金がマイナスです。放っておくと株主の期待が下がります。',
            'You are in the red. Shareholder expectation will fall if it stays that way.'),
        target: NextActionTarget.finance,
        urgent: true,
      ));
    }

    // ユースの有望株が出ていきそう。気づける場所が他にない。
    final atRisk = save.youthProspects
        .where(YouthDepartureEngine.isAtRisk)
        .toList();
    if (atRisk.isNotEmpty) {
      actions.add(NextAction(
        kind: NextActionKind.youthAtRisk,
        message: Tr.pick(
            'ユースの${atRisk.first.name}(${atRisk.first.age}歳)が出場機会を求めています。昇格させるか、ユース施設を上げて引き止めてください。',
            '${atRisk.first.name} (${atRisk.first.age}) wants first-team football. Promote him, or improve the academy to keep him.'),
        target: NextActionTarget.youth,
      ));
    }

    // 主力の契約が切れかけている。切れると無償で出ていく。
    final key = _expiringKeyPlayer(team);
    if (key != null) {
      actions.add(NextAction(
        kind: NextActionKind.contractExpiring,
        message: Tr.pick('${key.name}の契約は${ContractEngine.untilLabel(key.contractEndYear)}です。更新しないと無償で失います。',
            "${key.name}'s contract runs ${ContractEngine.untilLabel(key.contractEndYear)}. Renew it or lose him for nothing."),
        target: NextActionTarget.squad,
      ));
    }

    return actions;
  }

  /// 締切の何日前から知らせるか。早すぎると毎週の雑音になる
  /// (およそ2節ぶん)。
  static const int deadlineWarningDays = 14;

  /// 直近の節でこれ以上サポーターの期待が下がったら知らせる。
  static const int supporterDropAlert = 10;

  /// サポーターの期待がこの値以下なら、下がっている知らせを急ぎにする。
  static const int supporterUrgentLine = 35;

  /// いま出すべき1件。何も無ければ null。
  static NextAction? top(
    SaveGame save,
    Team team, {
    int? transferDeadlineDaysLeft,
    bool transferDeadlineBeforeNextMatch = false,
    bool hasSigningProposals = false,
    bool includeSetup = false,
    int? supporterTrend,
    int? rolloverShortfall,
    int? supporterUltimatumDaysLeft,
  }) {
    final actions = all(save, team,
        transferDeadlineDaysLeft: transferDeadlineDaysLeft,
        transferDeadlineBeforeNextMatch: transferDeadlineBeforeNextMatch,
        hasSigningProposals: hasSigningProposals,
        includeSetup: includeSetup,
        supporterTrend: supporterTrend,
        rolloverShortfall: rolloverShortfall,
        supporterUltimatumDaysLeft: supporterUltimatumDaysLeft);
    if (actions.isEmpty) return null;
    // 損が確定しているものを先に出す。
    final urgent = actions.where((a) => a.urgent);
    return urgent.isNotEmpty ? urgent.first : actions.first;
  }

  static Player? _expiringKeyPlayer(Team team) {
    if (team.players.isEmpty) return null;
    final average =
        team.players.fold<int>(0, (s, p) => s + p.overall) / team.players.length;
    Player? worst;
    for (final p in team.players) {
      if (p.isLoan) continue;
      if (p.contractYearsRemaining > contractWarningYears) continue;
      if (p.overall < average + keyPlayerMargin) continue;
      if (worst == null || p.overall > worst.overall) worst = p;
    }
    return worst;
  }
}
