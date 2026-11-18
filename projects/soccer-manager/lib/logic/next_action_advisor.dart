import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../l10n/tr.dart';
import 'contract_engine.dart';
import 'youth_departure_engine.dart';

/// 「次にやること」1件。
class NextAction {
  /// 画面に出す一文。何をすればよいかが、これだけで分かるようにする。
  final String message;

  /// どの画面へ行けばよいか。ホームのタイルやドロワーの項目名と揃える。
  final NextActionTarget target;

  /// 放っておくと損が出るものは true。見た目を分けて、順番を追い越す。
  final bool urgent;

  const NextAction({
    required this.message,
    required this.target,
    this.urgent = false,
  });
}

/// 行き先。画面そのものを持たせると、このファイルが UI に依存してしまう。
enum NextActionTarget { squad, youth, finance, transfer }

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
  static List<NextAction> all(
    SaveGame save,
    Team team, {
    int? transferDeadlineDaysLeft,
    bool transferDeadlineBeforeNextMatch = false,
    bool hasSigningProposals = false,
  }) {
    final actions = <NextAction>[];

    // 移籍の締切。過ぎると次の窓まで動けない。
    final left = transferDeadlineDaysLeft;
    if (left != null &&
        (left <= deadlineWarningDays || transferDeadlineBeforeNextMatch)) {
      actions.add(NextAction(
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
        message: Tr.pick('監督から補強の候補が届いています。買うか見送るかを決めてください。',
            'Your manager has sent signing candidates. Sign them or pass.'),
        target: NextActionTarget.transfer,
      ));
    }

    // 他クラブから売却のオファーが届いている。承認するか断るかを決める。
    if (save.incomingOffers.isNotEmpty) {
      actions.add(NextAction(
        message: Tr.pick(
            '${save.incomingOffers.first.playerName}に売却のオファーが届いています。承認するか断るかを決めてください。',
            'An offer for ${save.incomingOffers.first.playerName} has arrived. Accept or turn it down.'),
        target: NextActionTarget.squad,
      ));
    }

    // 資金がマイナス。放置すると理事会の信頼度が毎週削られる。
    if (save.budget < 0) {
      actions.add(NextAction(
        message: Tr.pick('資金がマイナスです。放っておくと理事会の信頼を失います。',
            'You are in the red. The board will lose patience if it stays that way.'),
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

  /// いま出すべき1件。何も無ければ null。
  static NextAction? top(
    SaveGame save,
    Team team, {
    int? transferDeadlineDaysLeft,
    bool transferDeadlineBeforeNextMatch = false,
    bool hasSigningProposals = false,
  }) {
    final actions = all(save, team,
        transferDeadlineDaysLeft: transferDeadlineDaysLeft,
        transferDeadlineBeforeNextMatch: transferDeadlineBeforeNextMatch,
        hasSigningProposals: hasSigningProposals);
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
