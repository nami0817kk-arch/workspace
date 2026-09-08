/// 選手の国籍。
///
/// 主国籍のほかに、ルーツ（親の出身）と帰化で増える。国籍が増えると
/// その国で外国人扱いされなくなり、行ける先が広がる。
class Nationality {
  const Nationality({
    required this.primary,
    this.roots,
    this.naturalized = const [],
    this.homegrownCountryId,
    this.homegrownClubName,
  });

  /// 主国籍。生まれた国。
  final String primary;

  /// ルーツの国籍。代表を選ぶときの葛藤になる。
  final String? roots;

  /// 帰化で得た国籍。
  final List<String> naturalized;

  /// 自国育ち（ホームグロウン）として認められる国。
  final String? homegrownCountryId;

  /// 育ったクラブの名前。表示用。
  final String? homegrownClubName;

  /// 国籍が分からないときの既定。国を持たせる前の保存データもここに寄せる。
  static const String defaultCountryId = 'yamato';
  static const Nationality unknown = Nationality(primary: defaultCountryId);

  List<String> get all => [
        primary,
        ?roots,
        ...naturalized,
      ];

  bool has(String countryId) => all.contains(countryId);

  bool isHomegrownIn(String countryId) => homegrownCountryId == countryId;

  Nationality naturalize(String countryId) => has(countryId)
      ? this
      : Nationality(
          primary: primary,
          roots: roots,
          naturalized: [...naturalized, countryId],
          homegrownCountryId: homegrownCountryId,
          homegrownClubName: homegrownClubName,
        );

  Nationality withHomegrown(String countryId, String clubName) => Nationality(
        primary: primary,
        roots: roots,
        naturalized: naturalized,
        homegrownCountryId: countryId,
        homegrownClubName: clubName,
      );

  Map<String, dynamic> toJson() => {
        'primary': primary,
        'roots': roots,
        'naturalized': naturalized,
        'homegrownCountryId': homegrownCountryId,
        'homegrownClubName': homegrownClubName,
      };

  factory Nationality.fromJson(Map<String, dynamic>? json, String fallback) {
    if (json == null) return Nationality(primary: fallback);
    return Nationality(
      primary: json['primary'] as String? ?? fallback,
      roots: json['roots'] as String?,
      naturalized: (json['naturalized'] as List? ?? const []).cast<String>(),
      homegrownCountryId: json['homegrownCountryId'] as String?,
      homegrownClubName: json['homegrownClubName'] as String?,
    );
  }
}
