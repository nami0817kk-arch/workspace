import 'dart:math';

import 'league_theme.dart';

/// 警告の累積と出場停止を数える大会の区分(2026-11-23)。
///
/// 実際のサッカーでは、警告の累積と出場停止は大会ごとに数える(リーグ戦で
/// 受けた出場停止はリーグ戦で消化し、カップ戦には出られる)。以前は全大会
/// 共通で5枚1試合、季が変わっても消えなかった。
enum CardCompetition {
  /// リーグ戦。
  league,

  /// 国内のカップ戦(国内カップ・リーグカップ・スーパーカップ)。
  cup,

  /// 大陸大会。
  continental,
}

/// 警告の累積で何試合の出場停止になるか、退場で何試合か(大会と国ごと)。
///
/// 試合の後の処理(MatchEngine.applyPostMatchEffects・
/// BackgroundMatchEngine.applyPlayerEffects)は[current]の決まりで数え、
/// 選手が出られるか(Player.isSuspended)も[current]の大会の出場停止で見る。
/// 試合を行う側(GameState)が試合の間だけ[run]で切り替える。
class CardRules {
  /// どの大会の決まりか。
  final CardCompetition competition;

  /// 国(リーグ戦の段階・国内カップの枚数が国で違う)。分からなければ null
  /// (5枚ごとに1試合)。
  final LeagueTheme? theme;

  /// 試合のある節(リーグ戦。イングランドは節で段階が変わる)。0 は不明。
  final int matchday;

  /// 季の節の数(0 は不明。節で変わる段階は数えない)。
  final int totalMatchdays;

  const CardRules.league({
    this.theme,
    this.matchday = 0,
    this.totalMatchdays = 0,
  }) : competition = CardCompetition.league;

  const CardRules.cup({this.theme})
      : competition = CardCompetition.cup,
        matchday = 0,
        totalMatchdays = 0;

  const CardRules.continental()
      : competition = CardCompetition.continental,
        theme = null,
        matchday = 0,
        totalMatchdays = 0;

  /// 国の分からないリーグ戦(5枚ごとに1試合)。
  static const CardRules generic = CardRules.league();

  /// いま行っている試合の決まり。試合の外ではリーグ戦(既定)。
  static CardRules current = generic;

  /// [rules]を[current]にして[body]を行い、終わったら元に戻す。
  static T run<T>(CardRules rules, T Function() body) {
    final before = current;
    current = rules;
    try {
      return body();
    } finally {
      current = before;
    }
  }

  /// 一発退場のうち、暴力行為などで3試合の出場停止になる割合。2枚目の警告
  /// による退場は1試合。一発退場はこのゲームの退場の6〜7割なので、全退場の
  /// 3割ほどが3試合になる。
  static const double violentConductShare = 0.45;

  /// 暴力行為などの重い退場の出場停止の試合数。
  static const int violentConductBan = 3;

  /// 退場の出場停止の試合数。[secondYellow](2枚目の警告での退場)は1試合、
  /// 一発退場は[violentConductShare]の割合で[violentConductBan]試合。
  static int redCardBan({required bool secondYellow, Random? random}) {
    if (secondYellow) return 1;
    final rng = random ?? _rng;
    return rng.nextDouble() < violentConductShare ? violentConductBan : 1;
  }

  static final Random _rng = Random();

  /// この大会で[count]枚目の警告を受けたときの出場停止の試合数(0 なら無し)。
  ///
  /// - リーグ戦:
  ///   - イングランド: 5枚で1試合(季の半ば=38節の19節まで)、10枚で2試合
  ///     (38節の32節まで)、15枚で3試合(以降5枚ごとに3試合)。
  ///   - ドイツ・スペイン: 5枚ごとに1試合。
  ///   - イタリア: 5枚目で1試合、その後は4枚ごとに1試合。
  ///   - フランス: 3枚ごとに1試合(実際は「10試合以内に3枚」。簡略)。
  /// - 国内カップ: イングランドは5枚ごと(実際はリーグ戦などと合わせて
  ///   数える)、ほかの国は2枚ごとに1試合。
  /// - 大陸大会: 3枚目で1試合、その後は2枚ごと(5・7・9枚目)に1試合。
  int banForYellow(int count) {
    if (count <= 0) return 0;
    switch (competition) {
      case CardCompetition.continental:
        return count >= 3 && count.isOdd ? 1 : 0;
      case CardCompetition.cup:
        final every = theme == LeagueTheme.england ? 5 : 2;
        return count % every == 0 ? 1 : 0;
      case CardCompetition.league:
        return _leagueBan(count);
    }
  }

  int _leagueBan(int count) {
    switch (theme) {
      case LeagueTheme.england:
        if (count == 5) return _beforeFraction(19 / 38) ? 1 : 0;
        if (count == 10) return _beforeFraction(32 / 38) ? 2 : 0;
        if (count >= 15 && count % 5 == 0) return 3;
        return 0;
      case LeagueTheme.italy:
        if (count == 5) return 1;
        return count > 5 && (count - 5) % 4 == 0 ? 1 : 0;
      case LeagueTheme.france:
        return count % 3 == 0 ? 1 : 0;
      case LeagueTheme.germany:
      case LeagueTheme.spain:
      case null:
        return count % 5 == 0 ? 1 : 0;
    }
  }

  /// いまの節が、季の[fraction]の節(38節なら19節など)までか。節が
  /// 分からなければ true(段階を外さない)。
  bool _beforeFraction(double fraction) {
    if (matchday <= 0 || totalMatchdays <= 0) return true;
    return matchday <= (totalMatchdays * fraction).round();
  }

  /// いま[count]枚のとき、次に出場停止になる枚数(画面の「あと◯枚」用)。
  /// 季の残りでもう出場停止にならなければ null。
  int? nextBanAt(int count) {
    for (var c = count + 1; c <= count + 20; c++) {
      if (banForYellow(c) > 0) return c;
    }
    return null;
  }
}
