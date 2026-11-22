/// 分割払いで獲得した選手の残金支払い予定。
///
/// 2026-11-22 から、新しい分割払いは「頭金3割 + 残りを契約の年数(2〜5年)
/// で毎年同じ額」([annual] が true。季の締めに1回払う)。それより前に
/// 組んだ分割払い(残りを4週で払う形)は、保存したときの形のまま払い終わる。
class Installment {
  String description;

  /// 1回に払う額(万円)。[annual] なら1年ぶん、そうでなければ1週ぶん。
  /// 名前は旧セーブとの互換のため変えない。
  int weeklyAmount;

  /// 残りの支払い回数。[annual] なら年の数、そうでなければ週の数。
  int weeksRemaining;

  /// この分割払いの対象選手。売却・引き抜きで手放した際に残金請求を
  /// 打ち切れるよう紐付ける(旧セーブにはないため復元時はnullになりうる)。
  String? playerId;

  /// 年に1回(季の締め)払う形か。旧セーブは false(毎週払う形)。
  bool annual;

  /// 払う額が移籍金(資産)として記録されるか。旧セーブの分割払いは
  /// 頭金を費用として記録していたので、残りも費用のまま記録する(false)。
  bool capitalized;

  Installment({
    required this.description,
    required this.weeklyAmount,
    required this.weeksRemaining,
    this.playerId,
    this.annual = false,
    this.capitalized = false,
  });

  /// まだ払っていない額の合計。
  int get outstanding => weeklyAmount * weeksRemaining;

  Map<String, dynamic> toJson() => {
        'description': description,
        'weeklyAmount': weeklyAmount,
        'weeksRemaining': weeksRemaining,
        'playerId': playerId,
        if (annual) 'annual': true,
        if (capitalized) 'capitalized': true,
      };

  factory Installment.fromJson(Map<String, dynamic> json) => Installment(
        description: json['description'] as String,
        weeklyAmount: json['weeklyAmount'] as int,
        weeksRemaining: json['weeksRemaining'] as int,
        playerId: json['playerId'] as String?,
        annual: json['annual'] as bool? ?? false,
        capitalized: json['capitalized'] as bool? ?? false,
      );
}
