/// 同じリーグで競う、他のクラブのオーナー(作り物)。
///
/// 窓が開くたびに自分のクラブへ選手を足し、交渉中の選手を横取りしに来る。
class RivalOwner {
  final String clubId;
  final String clubName;
  final String name;

  /// 野心(1〜3)。窓ごとに足す人数と、横取りしに来る強さ。
  final int ambition;

  /// 今季に足した人数(季の終わりに0へ戻す)。
  int signingsThisSeason;

  RivalOwner({
    required this.clubId,
    required this.clubName,
    required this.name,
    required this.ambition,
    this.signingsThisSeason = 0,
  });

  Map<String, dynamic> toJson() => {
        'clubId': clubId,
        'clubName': clubName,
        'name': name,
        'ambition': ambition,
        if (signingsThisSeason > 0) 'signingsThisSeason': signingsThisSeason,
      };

  factory RivalOwner.fromJson(Map<String, dynamic> j) => RivalOwner(
        clubId: j['clubId'] as String? ?? '',
        clubName: j['clubName'] as String? ?? '',
        name: j['name'] as String? ?? '',
        ambition: j['ambition'] as int? ?? 1,
        signingsThisSeason: j['signingsThisSeason'] as int? ?? 0,
      );
}
