import 'dart:math';

import '../models/club_infrastructure.dart';
import '../models/club_vision.dart';
import '../models/staff_member.dart';
import '../models/league.dart';
import '../models/league_theme.dart';
import '../models/team.dart';
import '../models/match_result.dart';
import '../l10n/tr.dart';
import 'economy_scale.dart';

class BoardEngine {
  // 理事会とオーナーの契約(managerContractAfterSeason: 満了時に信頼度が
  // 低いと解任)は 2026-11-23 に無くした。オーナーは雇われる立場ではなく、
  // クラブを手放すのは資金が尽きたときとサポーターの期待が尽きたときだけ。

  /// ディビジョンごとの給与予算の基準値(万円/週)。下位リーグほど
  /// 人件費に厳しく、昇格すると理事会が予算を引き上げる。
  ///
  /// その部の真ん中くらいのクラブの年収([typicalAnnualIncome])の
  /// [wageBudgetBaseIncomeShare] を、週あたりにした額。選手の給与は能力から
  /// 決まり、1部の主力は年俸で億の桁になるので、枠も同じ桁で持たないと
  /// 昇格した途端に誰も獲れなくなる。
  ///
  /// 年収の目安は国で違う(放映権の差。economy_scale の
  /// broadcastCountryFactor)ので、枠の基準も国で違う。
  static int wageBudgetBaseForTier(int tier,
          [LeagueTheme theme = LeagueTheme.england]) =>
      (typicalAnnualIncome(tier, theme) * wageBudgetBaseIncomeShare / 52)
          .round();

  /// 給与予算の基準が年収に占める割合。
  static const double wageBudgetBaseIncomeShare = 0.55;

  /// 理事会が設定する週給総額の上限(万円/週)。ティア基準値と
  /// 「現在の週給総額+基準値の25%の余裕」の大きい方を採用するため、
  /// シーズン開始時点で必ず補強の余地が残る。
  /// 理事会が人件費に回してよいと考える、週次収入の割合。
  ///
  /// 以前の上限はティアの基準値だけで決まっていた。スタジアムを広げても、
  /// 良いスポンサーと契約しても、実績を積んでも上限は動かない。クラブを
  /// 大きくしたぶんが返ってこないうえ、選手が育って要求週俸が上がると
  /// 枠に収まらなくなる(実測: 4シーズン目に給与予算211に対し、総合67の
  /// 選手1人が週俸41を要求)。
  ///
  /// 収入に紐づけると、伸ばした収入がそのまま枠になる。
  static const double wageBudgetIncomeShare = 0.6;

  /// 理事会がスタッフ5人ぶんに見込む人件費(週あたり)。
  ///
  /// 給与予算は選手とスタッフの合計に掛かる。スタッフのぶんを見込まないと、
  /// 「5つの役職があるのに1人しか雇えない」状態になる(実測: 5部で余裕64に
  /// 対しスタッフ1人が週俸57)。理事会は裏方を置く前提で予算を組む。
  ///
  /// 見積もりは、そのティアに実際に来る人材の相場から出す
  /// (StaffMember.expectedAbilityForTier)。willJoin と同じ式から導くので、
  /// 雇える人材と見積もりがずれない。
  static int staffWageAllowanceFor(int tier) => scaleMoneyForTier(
      tier,
      StaffMember.askingWage(StaffMember.expectedAbilityForTier(tier)) *
          StaffRole.values.length);

  static int wageBudgetFor({
    required int tier,
    required int currentWeeklyWageBill,
    int weeklyIncome = 0,
    LeagueTheme theme = LeagueTheme.england,
  }) {
    final base = max(
      wageBudgetBaseForTier(tier, theme),
      (weeklyIncome * wageBudgetIncomeShare).round(),
    );
    final headroom = max(scaleMoneyForTier(tier, 60), (base * 0.4).round());
    return max(base, currentWeeklyWageBill + headroom) +
        staffWageAllowanceFor(tier);
  }

  /// 理事会が期待する国内カップの到達ラウンド(そのラウンドの試合を
  /// 戦うところまで勝ち残ること)。リーグ内の戦力順位が高いクラブほど
  /// 深いラウンドまで期待される。
  static int estimateCupTargetRound({
    required int strengthRank,
    required int teamCount,
    required int totalRounds,
  }) {
    if (teamCount <= 0 || totalRounds <= 0) return 0;
    final ratio = strengthRank / teamCount;
    if (ratio <= 0.15) return totalRounds; // 優勝候補: 決勝進出
    if (ratio <= 0.35) return max(1, totalRounds - 1); // 準決勝進出
    if (ratio <= 0.6) return max(1, totalRounds - 2); // 準々決勝進出
    return max(1, totalRounds - 3);
  }

  /// スカッド総合力の順位に対して理事会が許容する余裕(順位いくつ分か)。
  /// 戦力通りの順位ちょうどを要求すると、達成できるかどうかが実質50%の
  /// コイン投げになり、何をしても運任せで解任される。少しの取りこぼしなら
  /// 許される幅を持たせる。
  static const int targetRankCushion = 2;

  /// 現在のスカッド総合力から見て妥当な目標順位（1が最高位）を見積もる。
  ///
  /// [relegationZone] はクラブのいる部の降格圏の広さ(いちばん下の部は 0)。
  /// 目標は [targetRankFloor] より下にはしない。
  static int estimateTargetRank(League league, String userTeamId,
      {int relegationZone = 0}) {
    final sorted = [...league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final idx = sorted.indexWhere((t) => t.id == userTeamId);
    final strengthRank = idx < 0 ? (league.teams.length / 2).ceil() : idx + 1;
    final n = league.teams.length;
    return min(strengthRank + targetRankCushion,
            targetRankFloor(teamCount: n, relegationZone: relegationZone))
        .clamp(1, n);
  }

  /// 理事会の目標の下限(これより下の順位は目標にしない)。
  ///
  /// 降格のある部は「降格圏の外」、いちばん下の部は「下位4分の1の上」。
  /// 以前は戦力の順位だけで決まり、戦力が最下位なら目標も最下位で、
  /// 最下位を続けても月末・季末の期待がほとんど下がらなかった。何もしない
  /// オーナーが手放すまで8〜10季かかっていた(2026-11-23)。
  static int targetRankFloor(
      {required int teamCount, required int relegationZone}) {
    final floor = relegationZone > 0
        ? teamCount - relegationZone
        : teamCount - teamCount ~/ 4;
    return floor.clamp(1, teamCount);
  }

  /// 新シーズン開幕時に、続投が決まった監督へ戻す信頼度の下限。
  /// 信頼度はシーズンをまたいで持ち越されるため、前シーズンをぎりぎり
  /// 生き延びた監督は開幕2節で解任され、立て直す機会すらなかった
  /// (実測で確認)。契約を更新された=理事会は続投を選んだということなので、
  /// 新シーズンの開幕時点では最低限の猶予を与える。
  static const int newSeasonConfidenceFloor = 40;

  /// 理事会の路線を守れているか。
  ///
  /// 判定は「いま守れているか」だけを見る。守っていれば少し加算、
  /// 破っていれば大きめに減算(satisfiedBonus / violatedPenalty)。
  static bool isVisionSatisfied({
    required ClubVision vision,
    required Team team,
    required int budget,
  }) =>
      switch (vision) {
        ClubVision.none => true,
        // 23歳以下がスタメンに規定人数いるか。
        ClubVision.developYouth => team.players
                .where((p) => team.startingXI.contains(p.id) && p.age <= 23)
                .length >=
            ClubVisionInfo.youthStartersRequired,
        // 守備的な姿勢で臨んでいないか。
        ClubVision.attackingFootball =>
          team.mentality != TeamMentality.defensive,
        // 資金が赤字でないか。
        ClubVision.financialProudence => budget >= 0,
      };

  /// 路線の達成状況による、節ごとの信頼度への増減。
  /// シーズン終了時に、路線を守れていたかの評価を返す。
  ///
  /// 節ごとに積むのではなく、年に一度だけ効く。節ごとに±1〜2を積むと
  /// 38節で±38〜76になり、試合結果(1試合±3)を上回って信頼度を支配する。
  static int confidenceDeltaForVisionSeason({
    required ClubVision vision,
    required int compliedMatchdays,
    required int checkedMatchdays,
  }) {
    if (vision == ClubVision.none || checkedMatchdays == 0) return 0;
    final ratio = compliedMatchdays / checkedMatchdays;
    return ratio >= ClubVisionInfo.complianceThreshold
        ? vision.satisfiedBonus
        : -vision.violatedPenalty;
  }

  /// 1試合の勝ち負けの向き(勝ち +3・引き分け 0・負け -3)。
  ///
  /// 2026-11-23 から、ふつうの試合ではサポーターの期待をその場で動かさない
  /// (月末に [monthlyResultDelta] でまとめる)。その場で動くのはダービーだけ
  /// ([derbyDeltaForMatch])。
  static int confidenceDeltaForMatch(MatchResult result, String userTeamId) {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    if (userGoals > oppGoals) return 3;
    if (userGoals == oppGoals) return 0;
    return -3;
  }

  /// ダービーの勝ち負けで、その場で動く期待の幅。
  static const int derbyDelta = 4;

  /// ダービーの結果による、その場の増減(勝ち +4・引き分け 0・負け -4)。
  static int derbyDeltaForMatch(MatchResult result, String userTeamId) =>
      confidenceDeltaForMatch(result, userTeamId).sign * derbyDelta;

  /// 月末のまとめで動く幅の上限(上下とも)。
  static const int monthlyResultCap = 6;

  /// 月末に、その月の試合の結果をまとめた増減(-6〜+6)。
  ///
  /// 以前は1試合ごとに勝ち +3・負け -3 で、連敗すると数週で崩れ、オーナーが
  /// 打つ手(広報 +3 など)は試合の波に埋もれていた。月ごとに「目標の順位
  /// との差」と「その月の勝点の取り方」をまとめて反映し、オーナーの手が
  /// 主な動かし手になるようにする(2026-11-23)。
  ///
  /// その月にリーグ戦が無ければ 0(夏の間や季の切り替え)。
  ///
  /// [teamCount] を渡すと、順位そのものの分([monthlyPositionPart])も混ぜる。
  static int monthlyResultDelta({
    required int rank,
    required int targetRank,
    required int points,
    required int games,
    int teamCount = 0,
  }) {
    if (games <= 0) return 0;
    return (monthlyRankPart(rank: rank, targetRank: targetRank) +
            monthlyFormPart(points: points, games: games) +
            monthlyPositionPart(rank: rank, teamCount: teamCount))
        .clamp(-monthlyResultCap, monthlyResultCap);
  }

  /// 月末のまとめのうち、順位そのものの分。下位4分の1にいる月は -1。
  ///
  /// 目標との差だけで見ると、目標が下限([targetRankFloor])に張り付いた
  /// 弱いクラブは、最下位でも月に -1 しか動かなかった。サポーターは目標
  /// よりも順位表そのものを見ている(2026-11-23)。
  static int monthlyPositionPart({required int rank, required int teamCount}) {
    if (teamCount <= 0 || rank <= 0) return 0;
    return rank > teamCount - teamCount ~/ 4 ? -1 : 0;
  }

  /// 月末のまとめのうち、目標の順位との差の分(-3〜+3)。目標ちょうどは
  /// 0。目標は戦力の順位に [targetRankCushion] の余裕を足したものなので、
  /// 戦力どおりの順位なら +1 になる。
  static int monthlyRankPart({required int rank, required int targetRank}) {
    final gap = targetRank - rank;
    if (gap >= 6) return 3;
    if (gap >= 3) return 2;
    if (gap >= 1) return 1;
    if (gap >= -3) return 0;
    if (gap >= -7) return -1;
    if (gap >= -11) return -2;
    return -3;
  }

  /// 月末のまとめのうち、その月の成績(1試合あたりの勝点)の分(-3〜+3)。
  static int monthlyFormPart({required int points, required int games}) {
    if (games <= 0) return 0;
    final ppg = points / games;
    if (ppg >= 2.2) return 3;
    if (ppg >= 1.8) return 2;
    if (ppg >= 1.4) return 1;
    if (ppg >= 0.9) return 0;
    if (ppg >= 0.6) return -1;
    if (ppg >= 0.3) return -2;
    return -3;
  }

  /// チケットの値段による、毎月の増減(安い +2・普通 0・高い -2)。
  /// 高いほど1人あたりの収入は増える(TicketPricing の収入の倍率)。
  static int ticketMonthlyDelta(TicketPricing pricing) => switch (pricing) {
        TicketPricing.budget => 2,
        TicketPricing.standard => 0,
        TicketPricing.premium => -2,
      };

  /// 地域活動(地域貢献 Lv1 以上)を続けている間の、毎月の増減。
  static const int communityMonthlyDelta = 1;

  /// 主力級(チームの上位3人に入る選手)を獲ったときの増減。
  static const int bigSigningDelta = 3;

  /// 主力級とみなす順位(チームの総合力の上から何人目まで)。
  static const int keyPlayerRank = 3;

  /// 長く在籍したとみなす、自クラブでの公式戦の出場数。
  static const int longServingApps = 100;

  /// 人気の選手を売ったときの増減。人気の印(上位3人・長く在籍・生え抜き)の
  /// 数で -3〜-6。どれにも当たらなければ 0。
  static int saleDelta({
    required bool topPlayer,
    required bool longServing,
    required bool academy,
  }) {
    final marks = [topPlayer, longServing, academy].where((b) => b).length;
    return switch (marks) {
      0 => 0,
      1 => -3,
      2 => -5,
      _ => -6,
    };
  }

  /// スタジアムの増築が完成したときの増減。
  static const int stadiumCompletedDelta = 5;

  /// この値を超えた分の一部を、シーズン終了時に失う(期待への慣れ)。
  static const int adaptationLine = 75;

  /// 慣れで失う割合(%)。
  static const int adaptationPercent = 40;

  /// シーズン終了時の慣れを反映した信頼度。[adaptationLine] 以下は変わらない。
  static int afterAdaptation(int confidence) {
    if (confidence <= adaptationLine) return confidence;
    final lost = ((confidence - adaptationLine) * adaptationPercent / 100).round();
    return (confidence - lost).clamp(0, 100);
  }

  /// 理事会の評価で下がる幅の上限(中間レビュー・季末とも)。
  static const int boardReviewMaxDrop = 10;

  /// シーズン終了時の順位評価による増減。目標との差に比例する
  /// (目標ちょうどで +3、1つ上回るごとに +3、上限 +15。1つ下回るごとに
  /// -3、下限 -10)。以前は目標以内で +15・3つ以上下で -20 の段差だった
  /// (2026-11-23)。
  static int confidenceDeltaForSeasonEnd({
    required int finalRank,
    required int targetRank,
  }) =>
      (3 * (targetRank - finalRank) + 3).clamp(-boardReviewMaxDrop, 15);

  /// シーズン中盤(折り返し地点)の理事会レビューによる増減。目標との差に
  /// 比例する(目標ちょうどで +2、1つにつき ±2、上限 +8・下限 -10)。
  static int midSeasonReviewDelta({
    required int currentRank,
    required int targetRank,
  }) =>
      (2 * (targetRank - currentRank) + 2).clamp(-boardReviewMaxDrop, 8);

  /// シーズン中盤レビューで理事会から届く講評文。
  static String midSeasonReviewMessage({
    required int currentRank,
    required int targetRank,
  }) {
    if (currentRank <= targetRank) {
      return Tr.pick(
          '理事会からシーズン中盤レビュー: 現在$currentRank位と好調な滑り出しです。このまま$targetRank位以内を目指してください。',
          'Mid-season review from the board: ${Tr.ordinal(currentRank)} is a strong start. Keep it up and ${targetRank <= 1 ? 'win the league' : 'finish in the top $targetRank'}.');
    }
    if (currentRank > targetRank + 3) {
      return Tr.pick(
          '理事会からシーズン中盤レビュー: 現在$currentRank位と目標の$targetRank位を大きく下回っています。残り試合での早急な立て直しを求めます。',
          'Mid-season review from the board: ${Tr.ordinal(currentRank)} is well short of the target (${Tr.topTarget(targetRank)}). They want it turned around, quickly.');
    }
    return Tr.pick(
        '理事会からシーズン中盤レビュー: 現在$currentRank位。目標の$targetRank位以内に向けて、引き続き注視しています。',
        'Mid-season review from the board: ${Tr.ordinal(currentRank)}. They are still watching, with ${targetRank <= 1 ? 'the title' : 'the top $targetRank'} as the target.');
  }

  /// 資金がマイナスのまま連続した週数がこの値に達するたびに信頼度が下がる。
  static const int negativeBudgetPenaltyThresholdWeeks = 8;

  /// 資金マイナスが続いている週数を受けて信頼度の増減量を返す。
  /// 閾値に達するたびに(閾値の倍数ごとに)ペナルティが発生する。
  static int negativeBudgetConfidenceDelta(int consecutiveNegativeWeeks) {
    if (consecutiveNegativeWeeks <= 0) return 0;
    if (consecutiveNegativeWeeks % negativeBudgetPenaltyThresholdWeeks != 0) {
      return 0;
    }
    return -8;
  }

  /// 昇格時の理事会からの補強予算(万円)。金額は新ティアの週給予算基準の
  /// [promotionBonusWeeks]週分で、上のディビジョンほど大きい。
  ///
  /// これがないと、昇格しても戦力差(ティアあたり総合力で約10)を埋める
  /// 資金がなく、昇格→即降格の往復から抜け出せない(長期実測で確認)。
  ///
  /// 2026-11-23 に6週→2週。以前は「放映権料・スポンサー収入の増加分」と
  /// して6週分(新しい部の年収の目安の約6%)を渡していたが、放映権は昇格
  /// した季の最初の入金(8月)から上の部の額で入り、スポンサーも昇格の
  /// 条項で上がる。同じ増加を二重に渡していたので、理事会のぶんは夏の
  /// 補強の手付け(最初の入金までのつなぎ)に絞った。
  static const int promotionBonusWeeks = 2;

  /// 最終順位に応じた賞金（万円）。

  static int promotionBonusFor(int newTier,
          [LeagueTheme theme = LeagueTheme.england]) =>
      wageBudgetBaseForTier(newTier, theme) * promotionBonusWeeks;

  static int seasonPrizeMoney({
    required int finalRank,
    required int teamCount,
  }) {
    final worst = teamCount;
    final ratio = worst <= 1 ? 1.0 : 1 - (finalRank - 1) / (worst - 1);
    return (300 + ratio * 2700).round();
  }
}
