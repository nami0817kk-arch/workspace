import 'dart:math';

import '../l10n/tr.dart';
import '../models/sponsor.dart';
import 'sponsor_engine.dart';

/// 放映権の分配金の受け取り方。
enum TvDeal {
  /// 毎季、決まった額。安定している。
  fixed,

  /// 順位で変わる。上位なら多く、下位だと少ない。
  performance;

  String get label => switch (this) {
        fixed => Tr.pick('固定', 'Fixed'),
        performance => Tr.pick('成績連動', 'Performance-linked'),
      };

  String get summary => switch (this) {
        fixed => Tr.pick('順位に関わらず毎季同じ額(基準額の0.95倍)',
            'The same every season (0.95x the base)'),
        performance => Tr.pick('1位で基準額の1.5倍、最下位で0.6倍',
            '1.5x the base for 1st, 0.6x for last'),
      };
}

/// 命名権(スタジアム)と放映権の分配金。どちらも契約の選び方に損得がある。
class MediaDealsEngine {
  const MediaDealsEngine._();

  /// 放映権の基準額(万円/季)。上の部ほど大きい。
  static int tvBase(int tier) => (600 * SponsorEngine.tierFactor(tier)).round();

  /// その季に受け取る分配金。[rank]は最終順位(1が最上位)。
  static int tvPayout({
    required TvDeal deal,
    required int tier,
    required int rank,
    required int teamCount,
  }) {
    final base = tvBase(tier);
    switch (deal) {
      case TvDeal.fixed:
        return (base * 0.95).round();
      case TvDeal.performance:
        final spread = max(1, teamCount - 1);
        final k = 1.5 - 0.9 * ((rank - 1).clamp(0, spread) / spread);
        return (base * k).round();
    }
  }

  /// 前払いで受け取る額と、そのあと分配金が出ない季数。
  static int advanceAmount(int tier) => (tvBase(tier) * 1.4).round();
  static const int advanceHolidaySeasons = 2;

  /// 命名権の候補を3件。スタジアムが大きいほど、上の部ほど高い。
  /// 年数が長いほど週あたりは低い(固定されるぶん)。
  static List<SponsorDeal> namingOffers({
    required int stadiumLevel,
    required int tier,
    required int managerReputation,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final base = ((20 + stadiumLevel * 12) *
            SponsorEngine.tierFactor(tier) *
            SponsorEngine.reputationFactor(managerReputation))
        .round();
    final names = [
      Tr.pick('蒼海銀行スタジアム', 'Bluewater Bank Stadium'),
      Tr.pick('白鷺自動車アリーナ', 'Heron Motors Arena'),
      Tr.pick('紅葉飲料パーク', 'Maple Drinks Park'),
      Tr.pick('北斗テック・グラウンド', 'Northstar Tech Ground'),
      Tr.pick('旭丘保険フィールド', 'Sunhill Insurance Field'),
      Tr.pick('常盤エナジー・ドーム', 'Evergreen Energy Dome'),
    ]..shuffle(r);
    return [
      SponsorDeal(
          name: names[0], weeklyIncome: (base * 0.8).round(), yearsRemaining: 4),
      SponsorDeal(name: names[1], weeklyIncome: base, yearsRemaining: 2),
      SponsorDeal(
          name: names[2], weeklyIncome: (base * 1.3).round(), yearsRemaining: 1),
    ];
  }
}
