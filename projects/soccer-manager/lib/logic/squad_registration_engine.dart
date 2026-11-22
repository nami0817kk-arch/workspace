import '../l10n/tr.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 一軍の選手登録の決まり。実在のリーグに寄せて、国ごとに違う
/// (2026-11-22。それまではどの国もイングランドの1部の決まりだった)。
///
/// どの国も共通:
/// - 22歳以上の選手は25人まで登録できる。21歳以下は枠の外で、何人でもよい
/// - 在籍の総数(21歳以下を含む)にも上限を置く。セーブの大きさと、表の
///   見やすさのため
///
/// 国ごと([RegistrationRules.forCountry]):
/// - イングランド: 25人のうち国内で育った選手([Player.isHomegrown])を8人。
///   足りない分は登録枠が減る(国外で育った選手は17人まで)
/// - スペイン: EU 外の国籍の選手は3人まで(2部も同じ)
/// - イタリア: 25人のうち国内で育った選手8人、そのうち4人はクラブで
///   育った選手(ユース出身)。EU 外の国籍の選手を他の国から取れるのは
///   1季に2人まで
/// - ドイツ: 国籍の枠は無い。国内で育った選手8人と、ドイツ国籍の選手を
///   12人以上(外国籍は在籍の上限から12人を引いた数まで)
/// - フランス: EU 外の国籍の選手は4人まで
///
/// EU 外の国籍は、5か国のうちイングランド国籍([isEuNation])。
///
/// 決まりは新しく加える選手を止めるときにだけ使う。誕生日で21歳を越えて
/// 枠を超えた選手を、勝手に外したりはしない。
class SquadRegistration {
  /// 22歳以上の登録の上限。
  static const int seniorLimit = 25;

  /// 25人のうち、国内で育った選手を入れる人数(イングランド)。
  static const int homegrownQuota = 8;

  /// 国外で育った22歳以上の選手を登録できる人数(イングランド)。
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

  /// 22歳以上で、クラブで育った(ユース出身の)選手の数。
  static int clubTrainedSeniorCount(Team team) =>
      team.players.where((p) => isSenior(p) && p.academyGraduate).length;

  /// 在籍の総数が上限に達しているか。誰を足すかを問わず、もう入らない。
  static bool isFull(Team team) => team.players.length >= totalLimit;

  /// [incoming]を加えられない理由。加えられるなら null。
  ///
  /// [rules]を省くとイングランドの決まり。国籍の枠を見るには[nationOf]
  /// (選手の国籍)が要る。イタリアの「EU 外の選手は1季に2人まで」は、
  /// 今季に他の国から取った人数[nonEuSignedThisSeason]と、[incoming]が
  /// 他の国から来るか([incomingFromAbroad])で見る。
  static String? blockReason(
    Team team,
    Player incoming, {
    RegistrationRules rules = RegistrationRules.england,
    LeagueTheme Function(Player)? nationOf,
    int nonEuSignedThisSeason = 0,
    bool incomingFromAbroad = false,
  }) {
    if (isFull(team)) {
      return Tr.pick('在籍が上限の$totalLimit人です。誰かを放出してください。',
          'The squad is at the $totalLimit-player limit. Let someone go first.');
    }
    // 国籍の枠は年齢を問わない(21歳以下も数える)。
    if (nationOf != null) {
      final nation = nationOf(incoming);
      final limit = rules.nonEuLimit;
      if (limit != null && !isEuNation(nation)) {
        final count = nonEuCount(team, nationOf);
        if (count >= limit) {
          return Tr.pick(
              'EU 外の国籍の選手の枠($limit人)が埋まっています(${rules.countryLabel}の決まり)。',
              'All $limit places for non-EU players are taken (${rules.countryLabel} rules).');
        }
      }
      final perSeason = rules.nonEuSigningsPerSeason;
      if (perSeason != null &&
          incomingFromAbroad &&
          !isEuNation(nation) &&
          nonEuSignedThisSeason >= perSeason) {
        return Tr.pick(
            'EU 外の国籍の選手を他の国から取れるのは1季に$perSeason人までです(${rules.countryLabel}の決まり)。',
            'Only $perSeason non-EU players may be signed from abroad each season (${rules.countryLabel} rules).');
      }
      final minNationals = rules.minNationals;
      if (minNationals != null && nation != rules.country) {
        final foreigners =
            team.players.where((p) => nationOf(p) != rules.country).length;
        final maxForeigners = totalLimit - minNationals;
        if (foreigners >= maxForeigners) {
          return Tr.pick(
              '${rules.countryLabel}国籍の選手を$minNationals人以上残すため、外国籍の選手はあと入れられません($maxForeigners人まで)。',
              'You must keep at least $minNationals ${rules.countryLabel} nationals, so no more foreign players fit ($maxForeigners at most).');
        }
      }
    }
    if (!isSenior(incoming)) return null;
    if (seniorCount(team) >= seniorLimit) {
      return Tr.pick(
          '22歳以上の登録枠($seniorLimit人)が埋まっています。21歳以下なら枠の外です。',
          'All $seniorLimit senior places are taken. Players aged $underAge or under do not count.');
    }
    final hgLimit = rules.nonHomegrownLimit;
    if (!incoming.isHomegrown && nonHomegrownSeniorCount(team) >= hgLimit) {
      return Tr.pick(
          '国外で育った選手の枠($hgLimit人)が埋まっています。国内で育った選手なら登録できます。',
          'All $hgLimit places for players trained abroad are taken. A homegrown player would still fit.');
    }
    final clubLimit = rules.nonClubTrainedLimit;
    if (!incoming.academyGraduate &&
        team.players
                .where((p) => isSenior(p) && !p.academyGraduate)
                .length >=
            clubLimit) {
      return Tr.pick(
          'クラブで育った選手を${rules.clubTrainedQuota}人入れるため、ほかから来た22歳以上はあと入れられません($clubLimit人まで)。',
          'You must register ${rules.clubTrainedQuota} club-trained players, so no more senior signings fit ($clubLimit at most).');
    }
    return null;
  }

  static bool canAdd(
    Team team,
    Player incoming, {
    RegistrationRules rules = RegistrationRules.england,
    LeagueTheme Function(Player)? nationOf,
  }) =>
      blockReason(team, incoming, rules: rules, nationOf: nationOf) == null;

  /// 在籍している EU 外の国籍の選手の数(年齢を問わない)。
  static int nonEuCount(Team team, LeagueTheme Function(Player) nationOf) =>
      team.players.where((p) => !isEuNation(nationOf(p))).length;

  /// 締切で登録の枠を超えているか(22歳以上が25人を超える、国外で育った
  /// 22歳以上が枠を超える、EU 外の国籍の選手が枠を超える)。誕生日で21歳を
  /// 越えた選手が出ると起きる。
  static bool isOverLimit(
    Team team, {
    RegistrationRules rules = RegistrationRules.england,
    LeagueTheme Function(Player)? nationOf,
  }) =>
      seniorCount(team) > seniorLimit ||
      nonHomegrownSeniorCount(team) > rules.nonHomegrownLimit ||
      seniorCount(team) - clubTrainedSeniorCount(team) >
          rules.nonClubTrainedLimit ||
      (nationOf != null &&
          rules.nonEuLimit != null &&
          nonEuCount(team, nationOf) > rules.nonEuLimit!);

  /// 締切で名簿から外す選手(枠を超えていなければ空)。
  ///
  /// オーナーが「外す」と決めた選手([Player.leaveOffRegistration])を先に
  /// 外し、それでも超えていれば総合力の低い選手から外す。EU 外の国籍の
  /// 選手が枠を超えていれば、まず EU 外の選手から外し(21歳以下も)、国外で
  /// 育った選手が枠を超えていれば、次に国外で育った選手から外す。GK は
  /// 登録に2人は残す(全員が出られないと試合が組めない)。
  static List<Player> plannedExclusions(
    Team team, {
    RegistrationRules rules = RegistrationRules.england,
    LeagueTheme Function(Player)? nationOf,
  }) {
    if (!isOverLimit(team, rules: rules, nationOf: nationOf)) return const [];
    final registered =
        team.players.where((p) => !p.leaveOffRegistration).toList();
    final excluded = team.players.where((p) => p.leaveOffRegistration).toList();

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

    final nonEuLimit = rules.nonEuLimit;
    if (nationOf != null && nonEuLimit != null) {
      bool nonEu(Player p) => !isEuNation(nationOf(p));
      while (registered.where(nonEu).length > nonEuLimit) {
        if (!dropLowest(nonEu)) break;
      }
    }
    while (registered.where((p) => isSenior(p) && !p.isHomegrown).length >
        rules.nonHomegrownLimit) {
      if (!dropLowest((p) => isSenior(p) && !p.isHomegrown)) break;
    }
    bool notClubTrained(Player p) => isSenior(p) && !p.academyGraduate;
    while (registered.where(notClubTrained).length >
        rules.nonClubTrainedLimit) {
      if (!dropLowest(notClubTrained)) break;
    }
    while (registered.where(isSenior).length > seniorLimit) {
      if (!dropLowest(isSenior)) break;
    }
    // 21歳以下は、国籍の枠で外したときだけ名簿から外れる。
    return [
      for (final p in excluded)
        if (isSenior(p) ||
            (nationOf != null && !isEuNation(nationOf(p)) && nonEuLimit != null))
          p,
    ];
  }
}

/// 国ごとの登録の決まり([SquadRegistration])。
class RegistrationRules {
  const RegistrationRules({
    required this.country,
    this.homegrownQuota = 0,
    this.clubTrainedQuota = 0,
    this.nonEuLimit,
    this.nonEuSigningsPerSeason,
    this.minNationals,
  });

  final LeagueTheme country;

  /// 22歳以上の25人のうち、国内で育った選手を入れる人数(0なら決まり無し)。
  final int homegrownQuota;

  /// そのうち、クラブで育った(ユース出身の)選手を入れる人数。
  final int clubTrainedQuota;

  /// EU 外の国籍の選手を在籍させられる人数(null なら枠無し)。
  final int? nonEuLimit;

  /// EU 外の国籍の選手を他の国から取れる、1季あたりの人数(null なら無し)。
  final int? nonEuSigningsPerSeason;

  /// 自国籍の選手を在籍させる最低の人数(null なら無し)。
  final int? minNationals;

  /// 国外で育った22歳以上の選手を登録できる人数。
  int get nonHomegrownLimit => SquadRegistration.seniorLimit - homegrownQuota;

  /// ほかのクラブから来た(ユース出身でない)22歳以上を登録できる人数。
  int get nonClubTrainedLimit =>
      SquadRegistration.seniorLimit - clubTrainedQuota;

  String get countryLabel => country.flavorLabel;

  static const england = RegistrationRules(
    country: LeagueTheme.england,
    homegrownQuota: SquadRegistration.homegrownQuota,
  );
  static const spain = RegistrationRules(
    country: LeagueTheme.spain,
    nonEuLimit: 3,
  );
  static const italy = RegistrationRules(
    country: LeagueTheme.italy,
    homegrownQuota: 8,
    clubTrainedQuota: 4,
    nonEuSigningsPerSeason: 2,
  );
  static const germany = RegistrationRules(
    country: LeagueTheme.germany,
    homegrownQuota: 8,
    minNationals: 12,
  );
  static const france = RegistrationRules(
    country: LeagueTheme.france,
    nonEuLimit: 4,
  );

  static RegistrationRules forCountry(LeagueTheme t) => switch (t) {
        LeagueTheme.england => england,
        LeagueTheme.spain => spain,
        LeagueTheme.italy => italy,
        LeagueTheme.germany => germany,
        LeagueTheme.france => france,
      };
}
