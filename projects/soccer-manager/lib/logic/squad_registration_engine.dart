import '../l10n/tr.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 一軍の選手登録の決まり。実在のリーグ(イングランドの1部)に寄せる。
///
/// - 22歳以上の選手は25人まで登録できる。21歳以下は枠の外で、何人でもよい
/// - 25人のうち、国内で育った選手([Player.isHomegrown])を8人入れる。
///   足りない分は登録枠が減る(国外の選手は17人まで)
/// - それとは別に、在籍の総数(21歳以下を含む)にも上限を置く。
///   セーブの大きさと、表の見やすさのため
///
/// 決まりは新しく加える選手を止めるときにだけ使う。誕生日で21歳を越えて
/// 枠を超えた選手を、勝手に外したりはしない。
class SquadRegistration {
  /// 22歳以上の登録の上限。
  static const int seniorLimit = 25;

  /// 25人のうち、国内で育った選手を入れる人数。
  static const int homegrownQuota = 8;

  /// 国外で育った22歳以上の選手を登録できる人数。
  static const int nonHomegrownLimit = seniorLimit - homegrownQuota;

  /// この年齢までは枠の外で数える。
  static const int underAge = 21;

  /// 在籍の総数の上限(21歳以下を含む)。
  static const int totalLimit = 30;

  static bool isSenior(Player p) => p.age > underAge;

  /// 22歳以上で、登録枠を使う選手の数。
  static int seniorCount(Team team) => team.players.where(isSenior).length;

  /// 22歳以上で、国外で育った選手の数。
  static int nonHomegrownSeniorCount(Team team) =>
      team.players.where((p) => isSenior(p) && !p.isHomegrown).length;

  /// 22歳以上で、国内で育った選手の数。
  static int homegrownSeniorCount(Team team) =>
      team.players.where((p) => isSenior(p) && p.isHomegrown).length;

  /// 在籍の総数が上限に達しているか。誰を足すかを問わず、もう入らない。
  static bool isFull(Team team) => team.players.length >= totalLimit;

  /// [incoming]を加えられない理由。加えられるなら null。
  static String? blockReason(Team team, Player incoming) {
    if (isFull(team)) {
      return Tr.pick('在籍が上限の$totalLimit人です。誰かを放出してください。',
          'The squad is at the $totalLimit-player limit. Let someone go first.');
    }
    if (!isSenior(incoming)) return null;
    if (seniorCount(team) >= seniorLimit) {
      return Tr.pick(
          '22歳以上の登録枠($seniorLimit人)が埋まっています。21歳以下なら枠の外です。',
          'All $seniorLimit senior places are taken. Players aged $underAge or under do not count.');
    }
    if (!incoming.isHomegrown &&
        nonHomegrownSeniorCount(team) >= nonHomegrownLimit) {
      return Tr.pick(
          '国外で育った選手の枠($nonHomegrownLimit人)が埋まっています。国内で育った選手なら登録できます。',
          'All $nonHomegrownLimit places for players trained abroad are taken. A homegrown player would still fit.');
    }
    return null;
  }

  static bool canAdd(Team team, Player incoming) =>
      blockReason(team, incoming) == null;

  /// 締切で登録の枠を超えているか(22歳以上が25人を超える、または国外で
  /// 育った22歳以上が17人を超える)。誕生日で21歳を越えた選手が出ると起きる。
  static bool isOverLimit(Team team) =>
      seniorCount(team) > seniorLimit ||
      nonHomegrownSeniorCount(team) > nonHomegrownLimit;

  /// 締切で名簿から外す選手(枠を超えていなければ空)。
  ///
  /// オーナーが「外す」と決めた選手([Player.leaveOffRegistration])を先に
  /// 外し、それでも超えていれば総合力の低い選手から外す。国外で育った
  /// 選手が17人を超えていれば、まず国外で育った選手から外す。GK は
  /// 登録に2人は残す(全員が出られないと試合が組めない)。
  static List<Player> plannedExclusions(Team team) {
    if (!isOverLimit(team)) return const [];
    final seniors = team.players.where(isSenior).toList();
    final registered = seniors.where((p) => !p.leaveOffRegistration).toList();
    final excluded = seniors.where((p) => p.leaveOffRegistration).toList();

    int gkCount() =>
        registered.where((p) => p.position == Position.gk).length;

    /// [pool]から総合力が最も低い1人を外す。外せる人が居なければ false。
    bool dropLowest(bool Function(Player) inPool) {
      final candidates = registered
          .where(inPool)
          .where((p) => p.position != Position.gk || gkCount() > 2)
          .toList()
        ..sort((a, b) => a.overall.compareTo(b.overall));
      if (candidates.isEmpty) return false;
      registered.remove(candidates.first);
      excluded.add(candidates.first);
      return true;
    }

    while (registered.where((p) => !p.isHomegrown).length >
        nonHomegrownLimit) {
      if (!dropLowest((p) => !p.isHomegrown)) break;
    }
    while (registered.length > seniorLimit) {
      if (!dropLowest((_) => true)) break;
    }
    return excluded;
  }
}
