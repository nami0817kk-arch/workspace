/// 稼いだお金(資産)の使い道。プロの間、投資(`invest.dart`)とは別に買える。
/// 金額は万円。`perYear` は1年に使える回数、`once` は一生に一度。
enum ShopItem {
  gear('最新の用具をそろえる', 'この1年、行動で貯まる経験点+8%', 2000, perYear: 1),
  camp('海外で自主トレ合宿', '重点の種類の経験点+15・ほかの種類+5・疲れ+10', 4000, perYear: 1),
  care('疲労回復の施術', '疲れ-35', 800, perYear: 3),
  gift('大切な人に贈り物', '恋人(いなければ家族)との絆+20', 500, perYear: 1),
  house('家族に家を贈る', '家族との絆+40。毎年の年末に、疲れがさらに抜ける', 10000, once: true),
  donate('地元に野球場を寄付する', 'やる気+20。地元の英雄として語り継がれる', 30000, once: true);

  const ShopItem(this.label, this.description, this.cost,
      {this.perYear = 0, this.once = false});
  final String label;
  final String description;
  final int cost;
  final int perYear;
  final bool once;

  static ShopItem? parse(String? s) {
    for (final i in ShopItem.values) {
      if (i.name == s) return i;
    }
    return null;
  }
}

/// 最新の用具の経験点の倍率。
const gearMultiplier = 1.08;
