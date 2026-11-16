import '../l10n/tr.dart';

/// オーナーが自分で選ぶ、長い目で見た目標。
///
/// 達成すると殿堂に残り、売却後も消えない。期限を過ぎると目標は消え、
/// 別の目標を選び直せる。
enum OwnerGoal {
  /// 1部でリーグ優勝する。
  leagueTitle,

  /// 1部へ上がる(すでに1部なら選べない)。
  reachTopDivision,

  /// 国内カップで優勝する。
  winCup,

  /// 資金を大きく増やす。
  richClub,

  /// クラブ価値を、目標を選んだときの2倍にする。
  clubValue,

  /// 1部で、3シーズン以上4位以内に入る。
  topFour,

  /// 負けなしでシーズンを終える。
  unbeaten,

  /// スタジアムをレベル5まで育てる。
  bigStadium,

  /// 経営診断で A を取る(80点以上)。
  healthA,

  /// サポーターの期待を90以上にする。
  fanFavorite,

  /// 株主の期待を85以上にする。
  investorFavorite,
}

extension OwnerGoalInfo on OwnerGoal {
  String get label => switch (this) {
        OwnerGoal.leagueTitle => Tr.pick('1部でリーグ優勝', 'Win the top-flight league'),
        OwnerGoal.reachTopDivision => Tr.pick('1部へ昇格', 'Reach the top division'),
        OwnerGoal.winCup => Tr.pick('国内カップ優勝', 'Win the domestic cup'),
        OwnerGoal.richClub =>
          Tr.pick('資金を${OwnerGoalRules.richTarget}万円に', 'Build funds to ${OwnerGoalRules.richTarget}'),
        OwnerGoal.clubValue => Tr.pick('クラブ価値を2倍に', 'Double the club value'),
        OwnerGoal.topFour => Tr.pick('1部で3シーズン4位以内', 'Finish top four three times'),
        OwnerGoal.unbeaten => Tr.pick('無敗でシーズンを終える', 'Go a season unbeaten'),
        OwnerGoal.bigStadium => Tr.pick('スタジアムをレベル${OwnerGoalRules.stadiumTarget}に', 'Grow the stadium to level ${OwnerGoalRules.stadiumTarget}'),
        OwnerGoal.healthA => Tr.pick('経営診断でAを取る', 'Earn an A in the club health check'),
        OwnerGoal.fanFavorite => Tr.pick('サポーターの期待を${OwnerGoalRules.fanTarget}以上に', 'Lift fan expectation to ${OwnerGoalRules.fanTarget}'),
        OwnerGoal.investorFavorite => Tr.pick('株主の期待を${OwnerGoalRules.investorTarget}以上に', 'Lift shareholder expectation to ${OwnerGoalRules.investorTarget}'),
      };

  /// 期限(選んだシーズンから数えて何シーズン以内か)。
  int get deadlineSeasons => switch (this) {
        OwnerGoal.leagueTitle => 10,
        OwnerGoal.reachTopDivision => 5,
        OwnerGoal.winCup => 8,
        OwnerGoal.richClub => 6,
        OwnerGoal.clubValue => 8,
        OwnerGoal.topFour => 8,
        OwnerGoal.unbeaten => 10,
        OwnerGoal.bigStadium => 8,
        OwnerGoal.healthA => 6,
        OwnerGoal.fanFavorite => 6,
        OwnerGoal.investorFavorite => 6,
      };
}

/// 目標の達成・期限切れの判定。画面にも保存にも依らない計算だけ。
class OwnerGoalRules {
  const OwnerGoalRules._();

  /// 「資金を増やす」の目標額(万円)。
  static const int richTarget = 18000;

  /// 「クラブ価値を増やす」の倍率。
  static const double valueTarget = 2.0;

  /// 「1部で4位以内」に要るシーズン数。
  static const int topFourSeasons = 3;

  /// 「スタジアムを育てる」の目標レベル。
  static const int stadiumTarget = 5;

  /// 経営診断の A の下限(点)。
  static const int healthTarget = 80;

  /// サポーター・株主の期待の目標値。
  static const int fanTarget = 90;
  static const int investorTarget = 85;

  /// 達成済みか。[wonTopLeague]=選んでから1部でリーグ優勝した、
  /// [promotedOrTop]=選んでから昇格した/いま1部にいる、[wonCup]=選んでから
  /// 国内カップで優勝した、[budget]=いまの資金。
  static bool isMet(
    OwnerGoal goal, {
    required bool wonTopLeague,
    required bool promotedOrTop,
    required bool wonCup,
    required int budget,
    double valueRatio = 0,
    int topFourCount = 0,
    bool unbeaten = false,
    int stadiumLevel = 0,
    int healthScore = 0,
    int supporter = 0,
    int shareholder = 0,
  }) =>
      switch (goal) {
        OwnerGoal.leagueTitle => wonTopLeague,
        OwnerGoal.reachTopDivision => promotedOrTop,
        OwnerGoal.winCup => wonCup,
        OwnerGoal.richClub => budget >= richTarget,
        OwnerGoal.clubValue => valueRatio >= valueTarget,
        OwnerGoal.topFour => topFourCount >= topFourSeasons,
        OwnerGoal.unbeaten => unbeaten,
        OwnerGoal.bigStadium => stadiumLevel >= stadiumTarget,
        OwnerGoal.healthA => healthScore >= healthTarget,
        OwnerGoal.fanFavorite => supporter >= fanTarget,
        OwnerGoal.investorFavorite => shareholder >= investorTarget,
      };

  /// 期限を過ぎたか。[season]は終えたばかりのシーズン、[startSeason]は目標を選んだシーズン。
  static bool isExpired(OwnerGoal goal, {required int startSeason, required int season}) =>
      season - startSeason + 1 >= goal.deadlineSeasons;
}
