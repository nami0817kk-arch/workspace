import 'dart:math';

import '../l10n/tr.dart';
import '../models/league_theme.dart';
import '../models/sponsor.dart';
import 'sponsor_engine.dart';
import 'economy_scale.dart';

/// 国ごとの放映権の配分の割合(均等割・順位・中継回数。合計1)。
typedef TvShares = ({double equal, double merit, double facility});

/// 命名権と放映権。
///
/// **放映権はリーグが配る。** 実際の欧州の放映権は、リーグがまとめて売り、
/// 決まった式でクラブに配る(クラブが受け取り方を選んだり、前払いを
/// 受けたりはしない)。以前は「固定/成績連動」をクラブが選べ、前払いも
/// 受けられたが、2026-11-23 に国ごとの配分式へ一本化した。
///
/// 1クラブあたりの平均の年額は、旧来の受け取りの平均(4回の入金
/// [annualBroadcast] と、季末の分配金 その4分の1×0.95)とほぼ同じ
/// [annualBroadcast]×[poolMultiplier] にしてある(経済の釣り合いは
/// test/economy_scale_test.dart で合わせてある)。
class MediaDealsEngine {
  const MediaDealsEngine._();

  /// 1クラブあたりの平均の年額が、[annualBroadcast] の何倍か。
  static const double poolMultiplier = 1.25;

  /// 国ごとの配分の割合(目安)。
  ///
  /// - イングランド(プレミア): 均等50%・順位25%・中継25%
  /// - スペイン: 均等50%・成績25%・視聴と会員(中継の目安)25%
  /// - ドイツ: 均等50%・成績43%・関心(中継の目安)7%
  /// - イタリア: 均等50%・成績30%・視聴(中継の目安)20%
  /// - フランス: 均等45%・成績35%・中継20%
  static TvShares sharesFor(LeagueTheme theme) => switch (theme) {
        LeagueTheme.england => (equal: 0.50, merit: 0.25, facility: 0.25),
        LeagueTheme.spain => (equal: 0.50, merit: 0.25, facility: 0.25),
        LeagueTheme.germany => (equal: 0.50, merit: 0.43, facility: 0.07),
        LeagueTheme.italy => (equal: 0.50, merit: 0.30, facility: 0.20),
        LeagueTheme.france => (equal: 0.45, merit: 0.35, facility: 0.20),
      };

  /// 順位の配分の倍率(平均1)。プレミアと同じく、1位が[teamCount]口、
  /// 最下位が1口。
  static double meritFactor(int rank, int teamCount) {
    final n = max(1, teamCount);
    final r = rank.clamp(1, n);
    return (n - r + 1) / ((n + 1) / 2);
  }

  /// 中継回数の目安の倍率(平均1)。上位ほど中継に選ばれる。実際の中継の
  /// 回数は数えていないので、順位から見積もる(最下位0.6・1位1.4)。
  static double facilityFactor(int rank, int teamCount) {
    final n = max(2, teamCount);
    final r = rank.clamp(1, n);
    return 0.6 + 0.8 * (n - r) / (n - 1);
  }

  /// [rank]位で終えたクラブが、その季に受け取る放映権の総額(万円)。
  /// [eraFactor] は時代の倍率(EraEngine の tvFactor)。
  static int seasonTotal({
    required int tier,
    required int rank,
    required int teamCount,
    LeagueTheme theme = LeagueTheme.england,
    double eraFactor = 1.0,
  }) {
    final s = sharesFor(theme);
    final pool = annualBroadcast(tier, theme) * poolMultiplier * eraFactor;
    final k = s.equal +
        s.merit * meritFactor(rank, teamCount) +
        s.facility * facilityFactor(rank, teamCount);
    return (pool * k).round();
  }

  /// 最下位でも受け取る額(万円/季)。季の間に4回に分けて入金する
  /// (均等割と、順位・中継の最低の分)。
  static int guaranteedAnnual({
    required int tier,
    required int teamCount,
    LeagueTheme theme = LeagueTheme.england,
    double eraFactor = 1.0,
  }) =>
      seasonTotal(
          tier: tier,
          rank: teamCount,
          teamCount: teamCount,
          theme: theme,
          eraFactor: eraFactor);

  /// 季末に配られる、順位と中継の上乗せ(総額から4回の入金を引いた額)。
  static int seasonEndPayout({
    required int tier,
    required int rank,
    required int teamCount,
    LeagueTheme theme = LeagueTheme.england,
    double eraFactor = 1.0,
  }) =>
      max(
          0,
          seasonTotal(
                  tier: tier,
                  rank: rank,
                  teamCount: teamCount,
                  theme: theme,
                  eraFactor: eraFactor) -
              guaranteedAnnual(
                  tier: tier,
                  teamCount: teamCount,
                  theme: theme,
                  eraFactor: eraFactor));

  /// 命名権の契約の年数の候補。実際の命名権は5〜10年の長い契約。
  static const List<int> namingYears = [5, 7, 10];

  /// 命名権の年額の、年数による倍率。長く結ぶほど年額がわずかに大きい
  /// (企業は長い露出に払う)。5年で1倍、1年延びるごとに2%。
  static double namingYearsFactor(int years) => 1 + (years - 5) * 0.02;

  /// 命名権の候補を3件(5・7・10年)。スタジアムが大きいほど、上の部ほど
  /// 高い。長いほど週額がわずかに大きい。
  static List<SponsorDeal> namingOffers({
    required int stadiumLevel,
    required int tier,
    required int managerReputation,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final base = (20 + stadiumLevel * 12) *
        incomeScale(tier) *
        SponsorEngine.reputationFactor(managerReputation);
    final names = [
      Tr.pick('蒼海銀行スタジアム', 'Bluewater Bank Stadium'),
      Tr.pick('白鷺自動車アリーナ', 'Heron Motors Arena'),
      Tr.pick('紅葉飲料パーク', 'Maple Drinks Park'),
      Tr.pick('北斗テック・グラウンド', 'Northstar Tech Ground'),
      Tr.pick('旭丘保険フィールド', 'Sunhill Insurance Field'),
      Tr.pick('常盤エナジー・ドーム', 'Evergreen Energy Dome'),
    ]..shuffle(r);
    return [
      for (var i = 0; i < namingYears.length; i++)
        SponsorDeal(
          name: names[i],
          weeklyIncome: (base * namingYearsFactor(namingYears[i])).round(),
          yearsRemaining: namingYears[i],
        ),
    ];
  }
}
