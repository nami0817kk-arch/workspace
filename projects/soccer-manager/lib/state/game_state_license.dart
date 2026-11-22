part of 'game_state.dart';

/// クラブライセンス(昇格の条件)。
extension GameStateLicense on GameState {
  /// [tier]部のライセンスで、自クラブが満たしていない条件(満たしていれば空)。
  List<String> clubLicenseUnmet(int tier) {
    final s = _save;
    if (s == null) return const [];
    return ClubLicenseEngine.unmet(
      tier,
      stadiumLevel: licensedStadiumLevel,
      budget: s.budget,
    );
  }

  /// [tier]部のライセンスで、スタジアム以外に満たしていない条件。
  /// スタジアムの段だけが足りないなら、猶予つきで昇格できる(空になる)。
  List<String> clubLicenseUnmetExceptStadium(int tier) {
    final s = _save;
    if (s == null) return const [];
    return ClubLicenseEngine.unmet(
      tier,
      stadiumLevel: ClubInfrastructure.maxLevel,
      budget: s.budget,
    );
  }

  /// [tier]部のライセンスのスタジアムの段に、届いている(来季の開幕までに
  /// 完成する工事を含む)か。
  bool stadiumMeetsLicense(int tier) =>
      licensedStadiumLevel >= ClubLicenseEngine.stadiumLevelFor(tier);

  /// スタジアムの猶予の季か(足りないまま昇格し、その季を戦っている)。
  bool get inStadiumGrace {
    final s = _save;
    return s != null &&
        s.licenseGraceTier > 0 &&
        s.licenseGraceSeason == s.league.season &&
        s.licenseGraceTier == s.currentDivisionTier;
  }

  /// 猶予の季に要るスタジアムの段(猶予でなければ null)。
  int? get stadiumGraceLevel => inStadiumGrace
      ? ClubLicenseEngine.stadiumLevelFor(_save!.licenseGraceTier)
      : null;

  /// 猶予の期限(その季の終わり、6月30日。猶予でなければ null)。
  DateTime? get stadiumGraceDeadline =>
      inStadiumGrace ? MoneyCalendar.fiscalYearEnd(_save!.league.season) : null;

  /// 猶予の季の表示: 「スタジアムの条件: 2028年6月までに Lv2 が必要(猶予中)」。
  String? get stadiumGraceNote {
    final lvl = stadiumGraceLevel;
    final deadline = stadiumGraceDeadline;
    if (lvl == null || deadline == null) return null;
    final when = TransferWindowCalendar.formatYearMonth(deadline);
    return Tr.pick('スタジアムの条件: $whenまでに Lv$lvl が必要(猶予中)',
        'Stadium requirement: level $lvl needed by $when (grace period)');
  }

  /// 猶予の季の終わりの判定。届いていなければ、ライセンスが下りない
  /// ときの扱い(降格処分: 1つ下の部へ落とす)を当てる。季の締めの
  /// 昇格・降格の前に呼ぶ。返すのは、届かずに処分になったか。
  bool _settleStadiumGrace() {
    final s = _save!;
    if (s.licenseGraceTier <= 0) return false;
    final active = inStadiumGrace;
    final tier = s.licenseGraceTier;
    s.licenseGraceTier = 0;
    s.licenseGraceSeason = 0;
    if (!active || stadiumMeetsLicense(tier)) return false;
    s.adminRelegation = true;
    _logNews(
      Tr.pick(
          '猶予の季のうちにスタジアムがLv${ClubLicenseEngine.stadiumLevelFor(tier)}に届かず、$tier部のクラブライセンスが下りませんでした。1つ下の部へ降格になります。',
          'The stadium did not reach level ${ClubLicenseEngine.stadiumLevelFor(tier)} during the grace season, so the tier $tier licence was refused. You will be relegated one tier.'),
      context: Tr.pick('クラブライセンス', 'Club licence'),
    );
    return true;
  }

  /// ライセンスの判定で数えるスタジアムの段階。増築中で、次の季の開幕
  /// までに完成するなら、完成後の段階で数える(上の部で戦うのは完成後の
  /// スタジアムなので)。
  int get licensedStadiumLevel {
    final s = _save;
    if (s == null) return 1;
    final infra = s.infrastructure;
    final lvl = infra.facilityLevel(FacilityType.stadium);
    final ready = infra.constructionReadyOn(FacilityType.stadium);
    final nextStart = SeasonCalendar.preseasonDate(s.league.season + 1);
    return ready != null && !ready.isAfter(nextStart) ? lvl + 1 : lvl;
  }

  /// 1つ上の部(今が1部なら null)。
  int? get nextTierUp {
    final t = _save?.currentDivisionTier;
    return t == null || t <= 1 ? null : t - 1;
  }
}
