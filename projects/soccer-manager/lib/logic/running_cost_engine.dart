import '../models/league_theme.dart';
import 'economy_scale.dart';

/// クラブの運営費(試合運営・遠征・事務・施設の維持)。
///
/// 2026-11-23 まで、収支に運営費が無かった。人件費のほかは施設・合宿・
/// スカウトなど選んで使う費用だけで、1部の真ん中のクラブは人件費率
/// 65% でも年収の3割以上が黒字に残っていた(economy_scale_test の実測:
/// イングランド1部 年収378億・人件費247億)。年収の目安
/// [typicalAnnualIncome] も、収入だけの目安で運営費は織り込んでいない。
///
/// 実際の欧州のクラブは、人件費のほかに年収の2〜3割ほどの運営費が
/// かかり、人件費率70%前後でほぼ釣り合う。部ごとの年収の目安に割合を
/// 掛け、施設が大きいほど維持費が増える形にする。毎月末に記帳する。
class RunningCostEngine {
  const RunningCostEngine._();

  /// 年収の目安に対する運営費の割合。2部・3部は人件費率がもともと
  /// 100%前後と高い(年俸の水準は wageCountryFactor で合わせてある)ので、
  /// 小さめ。3部を 0.12 にすると、スペインの3部から始めたオーナーが
  /// 2季の赤字で株主に手放させられた(economy_scale_test の4シーズン)。
  static double shareForTier(int tier) => switch (tier.clamp(1, 3)) {
        1 => 0.25,
        2 => 0.15,
        _ => 0.06,
      };

  /// 施設の維持の倍率。施設のLvの合計が1つ上がるごとに2%。
  /// [facilityLevels] は施設ごとのLv(1〜)。
  static double facilityFactor(Iterable<int> facilityLevels) =>
      1 + 0.02 * facilityLevels.fold<int>(0, (s, l) => s + (l - 1));

  /// 1年の運営費(万円)。
  static int annual({
    required int tier,
    required LeagueTheme theme,
    required Iterable<int> facilityLevels,
  }) =>
      (typicalAnnualIncome(tier, theme) *
              shareForTier(tier) *
              facilityFactor(facilityLevels))
          .round();

  /// 毎月末に払う額(1年の12分の1)。
  static int monthly({
    required int tier,
    required LeagueTheme theme,
    required Iterable<int> facilityLevels,
  }) =>
      (annual(tier: tier, theme: theme, facilityLevels: facilityLevels) / 12)
          .round();
}
