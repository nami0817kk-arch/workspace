/// 他クラブから届いた、自クラブ所属選手への移籍オファー。
class IncomingOffer {
  final String id;
  final String playerId;
  final String playerName;
  final String buyerClubName;
  /// 買い手の提示額(万円)。対案に応じて上がることがある。
  int amount;
  int weeksRemaining;

  /// こちらが返した対案の額(返事待ちのあいだだけ)。
  int? askedAmount;

  /// 対案への返事が来る日。
  DateTime? replyOn;

  /// 買い手がこれ以上は出さない(対案はもう返せない)。
  bool isFinal;

  /// リリース条項の金額提示による自動成立オファーかどうか。
  /// trueの場合は交渉の余地なく必ず成立する。
  final bool viaReleaseClause;

  IncomingOffer({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.buyerClubName,
    required this.amount,
    this.weeksRemaining = 3,
    this.viaReleaseClause = false,
    this.askedAmount,
    this.replyOn,
    this.isFinal = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'playerName': playerName,
        'buyerClubName': buyerClubName,
        'amount': amount,
        'weeksRemaining': weeksRemaining,
        'viaReleaseClause': viaReleaseClause,
        if (askedAmount != null) 'askedAmount': askedAmount,
        if (replyOn != null)
          'replyOn': '${replyOn!.year.toString().padLeft(4, '0')}-'
              '${replyOn!.month.toString().padLeft(2, '0')}-'
              '${replyOn!.day.toString().padLeft(2, '0')}',
        if (isFinal) 'isFinal': true,
      };

  factory IncomingOffer.fromJson(Map<String, dynamic> json) => IncomingOffer(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        buyerClubName: json['buyerClubName'] as String,
        amount: json['amount'] as int,
        weeksRemaining: json['weeksRemaining'] as int? ?? 3,
        viaReleaseClause: json['viaReleaseClause'] as bool? ?? false,
        askedAmount: json['askedAmount'] as int?,
        replyOn: DateTime.tryParse(json['replyOn'] as String? ?? ''),
        isFinal: json['isFinal'] as bool? ?? false,
      );
}
