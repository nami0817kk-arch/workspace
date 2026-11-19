/// 他のクラブの選手を買うための、クラブ同士の交渉(1人につき1件)。
///
/// こちらが移籍金を提示すると、数日後に相手のクラブから返事が来る。
/// 返事は「受ける(合意)」「対案」「打ち切る(決裂)」のどれか。対案には
/// 出し直せる(提示は3回まで)。合意したら期限までに移籍を決める。
/// 移籍の窓が閉じると、まとまらなかった話はすべて流れる。
enum TransferTalkStage {
  /// こちらが提示して、相手の返事を待っている。
  waiting,

  /// 相手から対案が来ている([TransferTalk.fee] ほか)。
  countered,

  /// 相手が合意した。[TransferTalk.deadline] までに移籍を決める。
  agreed,

  /// 相手が話を打ち切った。この窓のあいだは申し込めない。
  collapsed,
}

class TransferTalk {
  final String playerId;

  /// 選手の名前(一覧の表示用)。
  final String playerName;

  /// 相手のクラブ。作り物の市場(テスト・旧セーブの名残)なら空。
  final String clubId;
  final String clubName;

  TransferTalkStage stage;

  /// 何回目の提示か(1〜)。
  int round;

  /// こちらの最新の提示額(万円)。
  int bid;

  /// 分割払い(頭金3割と、残りを4週で)で申し込んだか。
  bool installments;

  /// 相手の返事が来る日(返事待ちのとき)。
  DateTime? replyOn;

  /// 相手の条件(対案・合意のとき): 移籍金(万円)。
  int fee;

  /// 相手の条件: 売却条項(将来売るときに元のクラブへ払う割合、%)。
  int sellOnPercent;

  /// 相手の条件: 分割払いを認めるか。
  bool installmentsOk;

  /// 合意の期限。この日を過ぎても決めなければ話は流れる。
  DateTime? deadline;

  TransferTalk({
    required this.playerId,
    required this.playerName,
    required this.clubId,
    required this.clubName,
    required this.bid,
    this.stage = TransferTalkStage.waiting,
    this.round = 1,
    this.installments = false,
    this.replyOn,
    this.fee = 0,
    this.sellOnPercent = 0,
    this.installmentsOk = false,
    this.deadline,
  });

  /// まだ話が生きているか(決裂していない)。
  bool get isOpen => stage != TransferTalkStage.collapsed;

  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parse(Object? s) {
    final d = DateTime.tryParse(s as String? ?? '');
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'clubId': clubId,
        'clubName': clubName,
        'stage': stage.name,
        'round': round,
        'bid': bid,
        if (installments) 'installments': true,
        if (replyOn != null) 'replyOn': _date(replyOn),
        if (fee > 0) 'fee': fee,
        if (sellOnPercent > 0) 'sellOnPercent': sellOnPercent,
        if (installmentsOk) 'installmentsOk': true,
        if (deadline != null) 'deadline': _date(deadline),
      };

  factory TransferTalk.fromJson(Map<String, dynamic> json) => TransferTalk(
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String? ?? '',
        clubId: json['clubId'] as String? ?? '',
        clubName: json['clubName'] as String? ?? '',
        stage: TransferTalkStage.values.firstWhere(
            (s) => s.name == json['stage'],
            orElse: () => TransferTalkStage.waiting),
        round: json['round'] as int? ?? 1,
        bid: json['bid'] as int? ?? 0,
        installments: json['installments'] as bool? ?? false,
        replyOn: _parse(json['replyOn']),
        fee: json['fee'] as int? ?? 0,
        sellOnPercent: json['sellOnPercent'] as int? ?? 0,
        installmentsOk: json['installmentsOk'] as bool? ?? false,
        deadline: _parse(json['deadline']),
      );
}
