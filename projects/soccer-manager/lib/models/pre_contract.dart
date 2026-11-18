/// 仮契約(ボスマン)。満了の年の1月1日から、今のクラブとの契約が切れる
/// 選手と、移籍金なしで来季の契約を結んでおける。7月1日に加入する。
///
/// 自クラブが他のクラブの選手と結んだものも、他のクラブ(AI)が自クラブや
/// 別のクラブの選手と結んだものも、同じ形で持つ。
class PreContract {
  final String playerId;

  /// 選手の名前(一覧の表示用。選手を探さなくても出せるように持つ)。
  final String playerName;

  /// 今いるクラブ(7月1日に出ていくクラブ)。
  final String fromClubId;
  final String fromClubName;

  /// 加入するクラブ。
  final String toClubId;
  final String toClubName;

  /// 加入後の週俸(万円)。
  final int wage;

  /// 加入後の契約の満了の年(その年の6月30日まで)。
  final int endYear;

  /// クラブ側の1年延長オプションを付けたか。
  final bool option;

  /// 結んだ日(表示用)。
  final DateTime signedOn;

  const PreContract({
    required this.playerId,
    required this.playerName,
    required this.fromClubId,
    required this.fromClubName,
    required this.toClubId,
    required this.toClubName,
    required this.wage,
    required this.endYear,
    required this.option,
    required this.signedOn,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerName': playerName,
    'fromClubId': fromClubId,
    'fromClubName': fromClubName,
    'toClubId': toClubId,
    'toClubName': toClubName,
    'wage': wage,
    'endYear': endYear,
    if (option) 'option': true,
    'signedOn':
        '${signedOn.year.toString().padLeft(4, '0')}-'
        '${signedOn.month.toString().padLeft(2, '0')}-'
        '${signedOn.day.toString().padLeft(2, '0')}',
  };

  factory PreContract.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['signedOn'] as String? ?? '');
    return PreContract(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String? ?? '',
      fromClubId: json['fromClubId'] as String? ?? '',
      fromClubName: json['fromClubName'] as String? ?? '',
      toClubId: json['toClubId'] as String? ?? '',
      toClubName: json['toClubName'] as String? ?? '',
      wage: json['wage'] as int? ?? 0,
      endYear: json['endYear'] as int? ?? 0,
      option: json['option'] as bool? ?? false,
      signedOn: parsed == null
          ? DateTime(2027, 1, 1)
          : DateTime(parsed.year, parsed.month, parsed.day),
    );
  }
}
