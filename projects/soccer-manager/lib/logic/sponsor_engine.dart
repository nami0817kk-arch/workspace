import 'dart:math';

import '../models/sponsor.dart';
import '../l10n/tr.dart';

class SponsorEngine {
  static final Random _rng = Random();

  // スポンサー名は架空の企業名。表示時の言語で選ぶため const にできない。
  static List<String> get _names => [
        Tr.pick('蒼海銀行', 'Bluewater Bank'),
        Tr.pick('白鷺自動車', 'Heron Motors'),
        Tr.pick('紅葉飲料', 'Maple Drinks'),
        Tr.pick('北斗テック', 'Northstar Tech'),
        Tr.pick('旭丘保険', 'Sunhill Insurance'),
        Tr.pick('常盤エナジー', 'Evergreen Energy'),
        Tr.pick('朝霧食品', 'Morningmist Foods'),
        Tr.pick('東雲航空', 'Daybreak Airways'),
        Tr.pick('潮風モビリティ', 'Seabreeze Mobility'),
        Tr.pick('若鮎製薬', 'Riverfin Pharma'),
      ];

  /// 所属ディビジョンによるスポンサー料の倍率。
  ///
  /// 以前はスポンサー料が選手の総合力だけで決まっていた。5部のクラブと
  /// 1部のクラブが、同じ戦力なら同じ額を提示される。昇格しても大きくならず、
  /// 「クラブが成長してもスポンサー料が変わらない」状態だった。
  ///
  /// 実際には露出の量が違う。上のディビジョンほど大きく付ける。
  static double tierFactor(int tier) => switch (tier) {
        1 => 3.0,
        2 => 2.1,
        3 => 1.6,
        4 => 1.25,
        _ => 1.0,
      };

  /// 監督の評価(=クラブの知名度)による倍率。0.85〜1.30。
  ///
  /// 実績を積んだクラブほど条件が良くなる。総合力だけだと、選手を売って
  /// 戦力が落ちた年に一気に条件が悪くなり、積み上げが効かない。
  static double reputationFactor(int managerReputation) =>
      (0.85 + managerReputation / 200).clamp(0.85, 1.30);

  /// スタジアム規模による倍率。1.0〜1.35。観客が多いほど広告価値が高い。
  static double stadiumFactor(int stadiumLevel) =>
      (1 + (stadiumLevel - 1) * 0.05).clamp(1.0, 1.35);

  /// クラブの規模に応じたスポンサー候補を3件生成する。
  /// 週間収入が高いほど契約期間(年単位)は短くなるトレードオフを持つ。
  ///
  /// 期間の選択に意味が出るのはここが効いてから。昇格を狙っているなら、
  /// 高額でも短い契約を選んで、上がった後に結び直す判断ができる。
  static List<SponsorDeal> generateOffers(
    int overallRating, {
    int tier = 5,
    int managerReputation = 50,
    int stadiumLevel = 1,
  }) {
    final base = ((40 + overallRating.clamp(0, 99)) *
            tierFactor(tier) *
            reputationFactor(managerReputation) *
            stadiumFactor(stadiumLevel))
        .round();
    final shuffled = ([..._names]..shuffle(_rng)).take(3).toList();
    return [
      SponsorDeal(
        name: shuffled[0],
        weeklyIncome: (base * 0.8).round(),
        yearsRemaining: 3,
      ),
      SponsorDeal(name: shuffled[1], weeklyIncome: base, yearsRemaining: 2),
      SponsorDeal(
        name: shuffled[2],
        weeklyIncome: (base * 1.3).round(),
        yearsRemaining: 1,
      ),
    ];
  }
}
