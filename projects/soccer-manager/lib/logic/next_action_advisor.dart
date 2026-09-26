import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../l10n/tr.dart';
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
enum NextActionTarget { lineup, training, squad, youth, finance, transfer }

/// いまのクラブの状態を見て、次にやることを1つだけ挙げる。
///
/// 画面は30以上あり、何から手を付ければよいのかが分からない。育成
/// アドバイザー([DevelopmentAdvisor])はトレーニング画面の中だけで、
/// 「そもそもその画面を開くべきか」は教えてくれなかった。
///
/// 複数を並べると結局どれからか分からなくなるため、出すのは常に1件。
class NextActionAdvisor {
  const NextActionAdvisor._();

  /// 契約残りがこの年数以下の主力は、放っておくと失う。
  static const int contractWarningYears = 1;

  /// 主力とみなす総合力の下限(チーム平均との比較)。全員を対象にすると
  /// 控えの契約まで急かすことになる。
  static const int keyPlayerMargin = 0;

  /// [transferDeadlineMatchdaysLeft] は移籍ウィンドウが閉じるまでの残り節数
  /// (閉じている・期限なしのときは null)。締切は移籍画面を開かないと
  /// 見えないので、ホームからも知らせる。
  static List<NextAction> all(
    SaveGame save,
    Team team, {
    int? transferDeadlineMatchdaysLeft,
  }) {
    final actions = <NextAction>[];

    // 移籍の締切。過ぎると次のウィンドウまで動けない。
    final left = transferDeadlineMatchdaysLeft;
    if (left != null && left <= deadlineWarningMatchdays) {
      actions.add(NextAction(
        message: left <= 1
            ? Tr.pick('移籍ウィンドウは今節で締切です。', 'The transfer window shuts this matchday.')
            : Tr.pick('移籍ウィンドウの締切まであと$left節です。',
                'The transfer window shuts in $left matchdays.'),
        target: NextActionTarget.transfer,
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

    // スタメンが組めていない。試合に影響する。
    if (team.startingXI.length < 11) {
      actions.add(NextAction(
        message: Tr.pick('スタメンが${team.startingXI.length}人です。11人そろえてください。',
            'Only ${team.startingXI.length} players are in your XI. Fill all eleven.'),
        target: NextActionTarget.lineup,
        urgent: true,
      ));
    }

    // 今週のトレーニングが残っている。毎週の積み上げなので、逃すと戻らない。
    if (!save.trainingDoneThisWeek) {
      actions.add(NextAction(
        message: Tr.pick('今週のトレーニングがまだです。', 'This week\'s training is still waiting.'),
        target: NextActionTarget.training,
      ));
    }

    // ユースの有望株が出ていきそう。気づける場所が他にない。
    final atRisk = save.youthProspects
        .where(YouthDepartureEngine.isAtRisk)
        .toList();
    if (atRisk.isNotEmpty) {
      actions.add(NextAction(
        message: Tr.pick(
            'ユースの${atRisk.first.name}(${atRisk.first.age}歳)が出場機会を求めています。昇格させるか、メンターを付けてください。',
            '${atRisk.first.name} (${atRisk.first.age}) wants first-team football. Promote him or give him a mentor.'),
        target: NextActionTarget.youth,
      ));
    }

    // 主力の契約が切れかけている。切れると無償で出ていく。
    final key = _expiringKeyPlayer(team);
    if (key != null) {
      actions.add(NextAction(
        message: Tr.pick('${key.name}の契約が残り${key.contractYearsRemaining}年です。更新しないと無償で失います。',
            "${key.name}'s contract has ${key.contractYearsRemaining} year(s) left. Renew it or lose him for nothing."),
        target: NextActionTarget.squad,
      ));
    }

    return actions;
  }

  /// 締切の何節前から知らせるか。早すぎると毎週の雑音になる。
  static const int deadlineWarningMatchdays = 3;

  /// いま出すべき1件。何も無ければ null。
  static NextAction? top(
    SaveGame save,
    Team team, {
    int? transferDeadlineMatchdaysLeft,
  }) {
    final actions = all(save, team,
        transferDeadlineMatchdaysLeft: transferDeadlineMatchdaysLeft);
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
