import '../models/league_theme.dart';

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
}
