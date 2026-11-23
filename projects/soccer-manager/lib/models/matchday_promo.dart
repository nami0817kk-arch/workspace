import '../l10n/tr.dart';

/// 次の節に打てる、試合日のイベント。1節に1つだけ。
///
/// 費用(万円)を払い、その節の観客収入の倍率と、サポーターの期待の増減が
/// 決まる。節を終えると使い切る。
class MatchdayPromo {
  const MatchdayPromo({
    required this.id,
    required this.cost,
    required this.gateMultiplier,
    required this.supporters,
    this.shareholders = 0,
  });

  final String id;
  final int cost;

  /// その節の観客収入に掛ける倍率。
  final double gateMultiplier;

  /// 節を終えたときのサポーターの期待の増減。
  final int supporters;

  /// 節を終えたときの株主の期待の増減。
  final int shareholders;

  String get title => matchdayPromoTexts[id]!.$1;
  String get description => matchdayPromoTexts[id]!.$2;
}

Map<String, (String, String)> get matchdayPromoTexts => {
      'family_day': (
        Tr.pick('ファミリーデー', 'Family day'),
        Tr.pick('子ども連れを割引で呼ぶ。客足が少し伸びる。',
            'Discounts for families. Attendance rises a little.')
      ),
      'discount_day': (
        Tr.pick('割引デー', 'Discount day'),
        Tr.pick('チケットを値引きしてファンに還元。収入は落ちるが、人気は上がる。',
            'Cheaper tickets as a thank-you. Less income, more goodwill.')
      ),
      'light_up': (
        Tr.pick('ナイトゲーム演出', 'Floodlit show'),
        Tr.pick('照明と演出で盛り上げる。観客が増える。',
            'Lights and a show. Bigger crowd.')
      ),
      'mascot_fest': (
        Tr.pick('マスコット祭り', 'Mascot festival'),
        Tr.pick('マスコットのイベントで、安く盛り上げる。',
            'A mascot event: a cheap way to liven things up.')
      ),
      'legends_talk': (
        Tr.pick('OBトークショー', 'Legends talk show'),
        Tr.pick('往年の名選手を招く。古参のファンが集まる。',
            'Bring back old heroes. Long-time fans turn out.')
      ),
      'community_day': (
        Tr.pick('地元感謝デー', 'Community day'),
        Tr.pick('地元の人を招待する。人気が上がる。',
            'Invite the locals. Goodwill grows.')
      ),
      'vip_hospitality': (
        Tr.pick('VIP接待席', 'VIP hospitality'),
        Tr.pick('企業向けの接待席で大きく稼ぐ。庶民のファンは面白くない。',
            'Corporate boxes bring big money. Ordinary fans are not pleased.')
      ),
      'charity_collect': (
        Tr.pick('募金デー', 'Charity collection day'),
        Tr.pick('募金を呼びかける。評判が上がり、株主にも悪くない。',
            'A collection drive. Good for the name, and shareholders approve.')
      ),
    };

const List<MatchdayPromo> matchdayPromos = [
  MatchdayPromo(id: 'family_day', cost: 80, gateMultiplier: 1.10, supporters: 1),
  MatchdayPromo(id: 'discount_day', cost: 0, gateMultiplier: 0.90, supporters: 3),
  MatchdayPromo(id: 'light_up', cost: 150, gateMultiplier: 1.15, supporters: 1),
  MatchdayPromo(id: 'mascot_fest', cost: 60, gateMultiplier: 1.05, supporters: 1),
  MatchdayPromo(id: 'legends_talk', cost: 100, gateMultiplier: 1.08, supporters: 2),
  MatchdayPromo(id: 'community_day', cost: 120, gateMultiplier: 1.04, supporters: 3),
  MatchdayPromo(id: 'vip_hospitality', cost: 200, gateMultiplier: 1.18, supporters: -1),
  MatchdayPromo(id: 'charity_collect', cost: 40, gateMultiplier: 1.0, supporters: 2, shareholders: 1),
];
