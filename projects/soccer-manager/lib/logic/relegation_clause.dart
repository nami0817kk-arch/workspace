import 'dart:math';

import '../models/league_theme.dart';
import 'economy_scale.dart';

/// 選手の契約の降格の条項。
///
/// 実際の欧州のクラブは、選手の契約に「降格したら年俸を下げる」条項を
/// 入れるのがふつう(プレミアは4〜5割減が多く、ほかの国は3割前後)。
/// 入れていないと、放映権が数分の1になった下の部で上の部の年俸を払い
/// 続けることになる。2026-11-23 から、自クラブも CPU のクラブも既定で
/// 付いている扱いにする。スポンサー・命名権の昇格・降格の条項は
/// SponsorEngine.divisionChangeFactor。
class RelegationClause {
  const RelegationClause._();

  /// 降格したときに年俸に掛ける倍率。イングランドは上下の部の放映権の
  /// 差が飛び抜けて大きいので強め。
  static double wageFactor(LeagueTheme theme) => switch (theme) {
        LeagueTheme.england => 0.6,
        LeagueTheme.spain => 0.7,
        LeagueTheme.italy => 0.7,
        LeagueTheme.france => 0.7,
        LeagueTheme.germany => 0.75,
      };

  /// [fromTier] 部から [toTier] 部へ降格したときに、実際に年俸に掛ける倍率。
  ///
  /// 降格の条項は、年俸を「新しい部で妥当な額」まで下げるもの。部ごとの
  /// 年俸の水準([wageCountryFactor])の比より下げると、見合う額
  /// (Player.fairWeeklyWage。今いる部の水準で決まる)の7割を割り、降格した
  /// クラブの選手が一斉に「年俸が安い」と不満を持っていた(2026-11-23。
  /// 例: フランスは1部の水準0.45・2部0.55で、0.7倍にすると見合う額の0.57)。
  /// そのため、条項の倍率と水準の比の大きいほうにする。水準が下がらない
  /// 降格(下の部のほうが水準が高い国)では下げない(1倍。上げはしない)。
  static double wageFactorFor(LeagueTheme theme,
      {required int fromTier, required int toTier}) {
    final ratio =
        wageCountryFactor(theme, toTier) / wageCountryFactor(theme, fromTier);
    return min(1.0, max(wageFactor(theme), ratio));
  }
}
