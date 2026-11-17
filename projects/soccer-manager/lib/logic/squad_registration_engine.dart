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
}
