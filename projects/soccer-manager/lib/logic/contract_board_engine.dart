import '../models/player.dart';
import '../models/team.dart';

/// 登録と契約の一覧のための集計。純粋な関数だけ。
class ContractBoardEngine {
  const ContractBoardEngine._();

  /// 契約が残りこの年数以下の選手は「更新の時期」。切れると無償で去る。
  static const int renewalWindowYears = 1;

  /// 契約が切れる順(残りが短く、同じなら総合力が高い順)。ローン中の選手は
  /// こちらでは更新できないので外す。
  static List<Player> expiring(Team team) {
    final list = team.players
        .where((p) => !p.isLoan && p.contractYearsRemaining <= renewalWindowYears)
        .toList()
      ..sort((a, b) {
        final c = a.contractYearsRemaining.compareTo(b.contractYearsRemaining);
        return c != 0 ? c : b.overall.compareTo(a.overall);
      });
    return list;
  }

  /// 登録人数の上限に対する余裕。負なら超過。
  static int registrationRoom(Team team, int maxSquad) =>
      maxSquad - team.players.length;

  /// 週給の合計。
  static int weeklyWages(Team team) =>
      team.players.fold<int>(0, (s, p) => s + p.wage);

  /// 契約年数別の人数(残り0年・1年・2年・3年以上)。
  static Map<int, int> byYearsRemaining(Team team) {
    final m = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (final p in team.players) {
      final k = p.contractYearsRemaining.clamp(0, 3);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }
}
