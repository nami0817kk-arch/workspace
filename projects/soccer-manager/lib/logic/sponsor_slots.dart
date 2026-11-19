import 'dart:math';

import '../l10n/tr.dart';
import '../models/sponsor.dart';
import 'sponsor_engine.dart';

/// 胸(今のスポンサー契約)と命名権のほかに、別の会社と結べる枠。
enum SponsorSlot {
  /// 袖の広告。
  sleeve,

  /// 練習着の広告。
  training,

  /// 背中の広告。
  back,
}

extension SponsorSlotInfo on SponsorSlot {
  String get label => switch (this) {
        SponsorSlot.sleeve => Tr.pick('袖', 'Sleeve'),
        SponsorSlot.training => Tr.pick('練習着', 'Training kit'),
        SponsorSlot.back => Tr.pick('背中', 'Shirt back'),
      };

  /// 胸のスポンサーの基準額に対する割合。胸より露出が少ないぶん安い。
  double get share => switch (this) {
        SponsorSlot.sleeve => 0.30,
        SponsorSlot.training => 0.15,
        SponsorSlot.back => 0.20,
      };
}

class SponsorSlotEngine {
  static final Random _rng = Random();

  // 胸のスポンサーと重ならないよう、別の会社の名前にする。
  static List<String> get _names => [
        Tr.pick('稲穂ホールディングス', 'Ricefield Holdings'),
        Tr.pick('瑞雲ガス', 'Auspicious Gas'),
        Tr.pick('翠嶺不動産', 'Jade Ridge Estates'),
        Tr.pick('鶴見物流', 'Cranewatch Logistics'),
        Tr.pick('花筏スポーツ', 'Petalraft Sports'),
        Tr.pick('星屑通信', 'Stardust Telecom'),
        Tr.pick('山吹ビール', 'Kerria Brewing'),
        Tr.pick('岬ホテルズ', 'Cape Hotels'),
      ];

  /// [slot]の提示を1件作る。額は胸のスポンサーの基準額(2年契約のもの)に
  /// 枠の割合を掛けたもの。2年契約。
  static SponsorDeal offerFor(
    SponsorSlot slot,
    int overallRating, {
    required int tier,
    required int managerReputation,
    required int stadiumLevel,
  }) {
    final chest = SponsorEngine.generateOffers(
      overallRating,
      tier: tier,
      managerReputation: managerReputation,
      stadiumLevel: stadiumLevel,
    )[1];
    final names = _names;
    return SponsorDeal(
      name: names[_rng.nextInt(names.length)],
      weeklyIncome: max(1, (chest.weeklyIncome * slot.share).round()),
      yearsRemaining: 2,
    );
  }
}
