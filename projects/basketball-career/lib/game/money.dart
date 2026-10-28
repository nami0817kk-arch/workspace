import 'dart:math';

/// プロの年俸(万円)と、お金の表示。
///
/// 実世界のプロ選手と同じく、1年目は新人契約(ドラフトの順位で決まる)、2年目からは
/// 毎年の契約更改で、総合評価と前の年の表彰に応じて年俸が変わる。海外は国内より高い。
/// リーグ・チームの名前と同じく、金額も実在の選手のものではなく、このアプリの目安の数字。

/// 新人契約の年俸。ドラフト1位は高く、下位は低い。
int rookieSalary(int draftPick) {
  if (draftPick <= 0) return 400;
  if (draftPick == 1) return 1500;
  if (draftPick <= 10) return 1000;
  if (draftPick <= 30) return 600;
  return 400;
}

/// 契約更改後の年俸。総合評価(45を超えた分の2乗)と、前の年の表彰の数で上がる。
/// 総合60で約850万円、70で約1,650万円、80で約3,000万円、90で約6,500万円(国内)。
int salaryOf({required double overall, required int honorsLastYear, required bool abroad}) {
  final over = max(0.0, overall - 45);
  var base = 400 + over * over * 3;
  base *= 1 + min(honorsLastYear, 5) * 0.08;
  if (abroad) base *= 4;
  // 10万円単位に丸める。
  return (base / 10).round() * 10;
}

/// スポンサー契約の年収(万円)。人気で決まる: 前の年の表彰・優勝・華がある・上位指名・日本代表・海外での活躍。
/// 地元への寄付(`Spend.court`)でも人気が上がる。総合60未満は付かない。1点あたり300万円、最大3,000万円。
int sponsorOf({
  required double overall,
  required int honorsLastYear,
  required bool champion,
  required bool star,
  required int draftPick,
  required int caps,
  required bool abroad,
  bool charity = false,
}) {
  if (overall < 60) return 0;
  final points = min(honorsLastYear, 4) * 2 +
      (champion ? 3 : 0) +
      (star ? 3 : 0) +
      (draftPick >= 1 && draftPick <= 10 ? 2 : 0) +
      (caps > 0 ? 2 : 0) +
      (abroad ? 2 : 0) +
      (charity ? 3 : 0);
  return min(points * 300, 3000);
}

/// 「1億2,500万円」「850万円」のように読みやすく。
String moneyLabel(int man) {
  if (man <= 0) return '0円';
  final oku = man ~/ 10000;
  final rest = man % 10000;
  String withComma(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  if (oku == 0) return '${withComma(rest)}万円';
  if (rest == 0) return '$oku億円';
  return '$oku億${withComma(rest)}万円';
}
