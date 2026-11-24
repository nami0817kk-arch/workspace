import '../l10n/tr.dart';

/// 系列クラブとの提携の中身(2026-11-25 の第6段。FM の提携クラブに寄せた)。
///
/// 相手は1つまで(第2段で決めた)。どちらが親かは相手の強さで決まる:
/// - 相手が弱ければこちらが親。提携費を払い、若手の貸し出し先・育成先に
///   使い、相手の選手を優先して取れ、相手が選手を売ると取り分が入る。
/// - 相手が強ければこちらが子。提携費を受け取り、相手の若手を安く借りられる
///   が、こちらが選手を売ると相手に取り分を渡す。
class AffiliateDeal {
  AffiliateDeal({
    required this.clubId,
    required this.weAreParent,
    required this.untilSeason,
    required this.annualFee,
    this.loanPriority = true,
    this.youthDevelopment = false,
    this.firstRefusal = true,
    this.sellOnPercent = 0,
  });

  final String clubId;

  /// こちらが親か(相手が弱い)。
  final bool weAreParent;

  /// 提携が切れる季(リーグの季の番号。この季の終わりまで)。null なら
  /// 1季ごとに自動で続く(旧セーブから移したもの)。
  int? untilSeason;

  /// 1季の提携費(5部の物差しの万円)。親が払い、子が受け取る。
  final int annualFee;

  /// 貸し出しの優先: こちらの貸し出しは提携先へ、出場機会付きで送る
  /// (子のときは、親の若手を契約金なしで借りられる)。
  final bool loanPriority;

  /// 若手の育成先: 提携先へ貸した21歳以下の伸びが大きい(親のときだけ)。
  final bool youthDevelopment;

  /// 移籍の優先交渉権: 相手の選手の言い値が2割引(親のとき)。
  final bool firstRefusal;

  /// 売却時の取り分(%): 親は子が他クラブへ選手を売ったときに受け取り、
  /// 子は自分が選手を売ったときに親へ渡す。
  final int sellOnPercent;

  /// 提携の年数の選び方。
  static const yearChoices = [1, 2, 3];

  /// 取り分の選び方。
  static const sellOnChoices = [0, 10, 20];

  /// 1季の提携費(5部の物差しの万円)。項目を足すほど上がる。相手との
  /// 力の差[gap](こちら − 相手。正なら親)が大きいほど、親の払う額は安い。
  static int feeFor({
    required bool weAreParent,
    required int gap,
    required bool loanPriority,
    required bool youthDevelopment,
    required bool firstRefusal,
    required int sellOnPercent,
  }) {
    var fee = 200;
    if (loanPriority) fee += 60;
    if (youthDevelopment) fee += 80;
    if (firstRefusal) fee += 60;
    fee += sellOnPercent * 4;
    // 力の差が大きいほど、親の言うことが通る(安い)。
    final distance = gap.abs().clamp(0, 20);
    final factor = 1.2 - distance * 0.02;
    final base = (fee * factor).round();
    // 子のときに受け取る額は、親が払う額の半分(親の都合で結ぶため)。
    return weAreParent ? base : (base / 2).round();
  }

  /// 旧セーブ(系列クラブの id だけ)から移す。以前の決まり(提携先への
  /// 貸し出しは出場機会付き・相手の選手は2割引・年会費300)のまま、
  /// 1季ごとに続く形にする。
  factory AffiliateDeal.legacy(String clubId) => AffiliateDeal(
        clubId: clubId,
        weAreParent: true,
        untilSeason: null,
        annualFee: 300,
        loanPriority: true,
        youthDevelopment: false,
        firstRefusal: true,
        sellOnPercent: 0,
      );

  /// 項目の一覧(画面の「提携の中身」)。
  List<String> termLabels() => [
        if (loanPriority)
          weAreParent
              ? Tr.pick('貸し出しの優先(出場機会付き)', 'Loans go there first (with playing time)')
              : Tr.pick('親の若手を契約金なしで借りる', 'Borrow their youngsters with no loan fee'),
        if (youthDevelopment && weAreParent)
          Tr.pick('若手の育成先(21歳以下の伸び+)', 'Development club (more growth for 21 and under)'),
        if (firstRefusal && weAreParent)
          Tr.pick('優先交渉権(相手の選手が2割引)', 'First refusal (their players 20% off)'),
        if (sellOnPercent > 0)
          weAreParent
              ? Tr.pick('相手が選手を売ると$sellOnPercent%が入る', '$sellOnPercent% of their player sales')
              : Tr.pick('こちらが選手を売ると$sellOnPercent%を渡す', 'They take $sellOnPercent% of our player sales'),
      ];

  Map<String, dynamic> toJson() => {
        'clubId': clubId,
        'weAreParent': weAreParent,
        if (untilSeason != null) 'untilSeason': untilSeason,
        'annualFee': annualFee,
        'loanPriority': loanPriority,
        'youthDevelopment': youthDevelopment,
        'firstRefusal': firstRefusal,
        'sellOnPercent': sellOnPercent,
      };

  static AffiliateDeal? fromJson(Object? json) {
    if (json is! Map || json['clubId'] is! String) return null;
    return AffiliateDeal(
      clubId: json['clubId'] as String,
      weAreParent: json['weAreParent'] as bool? ?? true,
      untilSeason: json['untilSeason'] as int?,
      annualFee: json['annualFee'] as int? ?? 300,
      loanPriority: json['loanPriority'] as bool? ?? true,
      youthDevelopment: json['youthDevelopment'] as bool? ?? false,
      firstRefusal: json['firstRefusal'] as bool? ?? true,
      sellOnPercent: json['sellOnPercent'] as int? ?? 0,
    );
  }
}
