import 'dart:math';

import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/pre_contract.dart';
import '../models/team.dart';
import 'contract_engine.dart';
import 'economy_scale.dart';

/// 仮契約(ボスマン)の決まり。純粋な関数だけ。
///
/// - 満了の年(今のシーズン末で契約が切れる年)の1月1日から6月30日まで、
///   その選手と移籍金なしで来季の契約を結べる。加入は7月1日。
/// - 1月1日に、他のクラブ(AI)は自分の選手のうち満了の年の選手を
///   更新するかを決める。更新しなかった選手の一部は、別のクラブ(AI)が
///   その場で仮契約を結ぶ。残りが自クラブの狙える相手になる。
/// - 自クラブの満了の年の選手にも、他のクラブ(AI)が仮契約を持ちかける。
///   延長オプションが残っている間(3月31日まで)は取られない。
class PreContractEngine {
  const PreContractEngine._();

  /// 今のシーズンの、仮契約を結べるようになる日(1月1日)。
  static DateTime opensOn() => DateTime(Player.contractClockYear, 1, 1);

  /// 今のシーズンの、仮契約を結べる最後の日(6月30日)。
  static DateTime closesOn() => DateTime(Player.contractClockYear, 6, 30);

  /// 今日[today]、仮契約を結べる時期か。
  static bool isOpen(DateTime today) {
    final d = DateTime(today.year, today.month, today.day);
    return !d.isBefore(opensOn()) && !d.isAfter(closesOn());
  }

  /// 選手の契約が今のシーズン末で切れるか(仮契約の相手になりうるか)。
  static bool inFinalYear(Player p) =>
      !p.isLoan && p.contractEndYear == Player.contractClockYear;

  /// 1月1日に、他のクラブ(AI)が満了の年の選手を更新する確率。
  /// ベテランほど更新されにくい。
  static double aiRenewChance(Player p) {
    if (p.age >= 33) return 0.35;
    if (p.age >= 30) return 0.55;
    return 0.7;
  }

  /// 更新されなかった選手に、別のクラブ(AI)が1月1日に仮契約を結ぶ確率。
  static const double aiPreContractChance = 0.3;

  /// 自クラブの満了の年の選手に、他のクラブ(AI)が1週のうちに仮契約を
  /// 結ぶ確率。「延長しない」と言っている選手は、ほかへ行くつもりなので高い。
  static double userPlayerPoachChance(Player p) {
    if (p.refusesRenewal) return 0.2;
    return p.overall >= 70 ? 0.08 : 0.05;
  }

  /// 仮契約で選手が求める週俸。移籍金が要らないぶん、選手は今より
  /// 高い週俸を求める(価値に見合う額と今の週俸の高い方の1割増し)。
  /// 延長オプションを付けるとさらに5%上がる。
  static int wageDemand(Player p, {bool option = false}) {
    final base = max(p.wage, weeklyWageForValue(p.marketValue));
    final factor = 1.1 * (option ? ContractEngine.optionWageFactor : 1.0);
    return max(minWeeklyWage, (base * factor).round());
  }

  /// 仮契約で選べる満了の年(短い順)。7月1日から数えて1年〜上限
  /// (5年、18歳未満は3年)。
  static List<int> endYearChoices(Player p) => [
        for (var y = Player.contractClockYear + 1;
            y <= ContractEngine.maxEndYearFromNextSeason(p.age);
            y++)
          y,
      ];

  /// 既定の満了の年(年齢に応じた年数。上限に収める)。
  static int defaultEndYear(Player p) => min(
        Player.contractClockYear + ContractEngine.negotiatedYears(p),
        ContractEngine.maxEndYearFromNextSeason(p.age),
      );

  /// 国内のクラブの選手と仮契約を結べるようになる日(今のシーズン)。
  ///
  /// 契約の最後の6か月に他のクラブと話せる決まり(ボスマン)は、国をまたぐ
  /// 移籍のためのもので、国内のクラブ同士の扱いは国で違う(2026-11-22)。
  /// - イングランド: 国内のクラブの選手には、シーズンが終わるまで声を
  ///   かけられない(6月1日から)。
  /// - イタリア: 国内の選手とも2月1日から結べる。
  /// - スペイン・ドイツ・フランス: 国内の選手とも1月1日から結べる。
  static DateTime domesticOpensOn(LeagueTheme country) => switch (country) {
        LeagueTheme.england => DateTime(Player.contractClockYear, 6, 1),
        LeagueTheme.italy => DateTime(Player.contractClockYear, 2, 1),
        _ => opensOn(),
      };

  /// 自クラブが仮契約を結べる相手か。
  ///
  /// [fromForeignLeague]は選手が他国のクラブにいるとき true。18歳未満は
  /// 国をまたいで移れない(移籍の窓と同じ決まり)。[minorBlocked]を渡すと、
  /// その判定(EU の中の16〜17歳の例外を含む)を使う。国内のクラブの選手は
  /// [domesticOpensOn]より前には結べない。
  static String? blockReason(
    Player p, {
    required DateTime today,
    required bool fromForeignLeague,
    required bool alreadyPreContracted,
    bool? minorBlocked,
    DateTime? domesticOpensOn,
  }) {
    if (!isOpen(today)) {
      return 'closed';
    }
    if (!inFinalYear(p)) return 'notFinalYear';
    if (alreadyPreContracted) return 'taken';
    if (minorBlocked ?? (fromForeignLeague && p.age < 18)) return 'minor';
    if (!fromForeignLeague && domesticOpensOn != null) {
      final d = DateTime(today.year, today.month, today.day);
      if (d.isBefore(domesticOpensOn)) return 'domesticNotYet';
    }
    return null;
  }

  /// 7月1日に仮契約の選手を加入させるときの契約。
  static void applyOnJoin(Player p, PreContract c) {
    p.wage = c.wage;
    p.contractEndYear = c.endYear;
    p.contractOption = c.option;
    p.refusesRenewal = false;
    p.isTransferListed = false;
    p.releaseClause = null;
    p.appearanceFee = ContractEngine.appearanceFeeFor(p);
    p.wageStatus = null;
    ContractEngine.resetContractStyle(p);
  }

  /// 1月1日の解禁で、他のクラブ(AI)の満了の年の選手をどうするか決める。
  ///
  /// 更新した選手は満了が延びる(年齢に応じた年数)。更新しなかった選手の
  /// 一部には、[teams]の中の別のクラブがその場で仮契約を結ぶ。返すのは
  /// AI 同士で結ばれた仮契約。自クラブ([userTeamId])の選手は対象外。
  static List<PreContract> openSeasonForAi(
    List<Team> teams,
    String userTeamId,
    Random rng, {
    required DateTime today,
    Set<String> alreadyTaken = const {},
  }) {
    final made = <PreContract>[];
    final cpuTeams = teams.where((t) => t.id != userTeamId).toList();
    if (cpuTeams.length < 2) return made;
    for (final team in cpuTeams) {
      for (final p in team.players) {
        if (!inFinalYear(p) || alreadyTaken.contains(p.id)) continue;
        if (rng.nextDouble() < aiRenewChance(p)) {
          ContractEngine.renewContract(p);
          continue;
        }
        // 18歳未満は行き先が他国になりうるので、AI 同士では結ばない
        // (国をまたぐ移籍の決まり)。
        if (p.age < 18) continue;
        if (rng.nextDouble() >= aiPreContractChance) continue;
        Team to;
        do {
          to = cpuTeams[rng.nextInt(cpuTeams.length)];
        } while (to.id == team.id);
        made.add(
          PreContract(
            playerId: p.id,
            playerName: p.name,
            fromClubId: team.id,
            fromClubName: team.name,
            toClubId: to.id,
            toClubName: to.name,
            wage: wageDemand(p),
            endYear: defaultEndYear(p),
            option: false,
            signedOn: today,
          ),
        );
      }
    }
    return made;
  }

  /// 自クラブの満了の年の選手のうち、今週ほかのクラブ(AI)と仮契約を結ぶ
  /// 選手と、その行き先。延長オプションを行使できる間(3月31日まで)の
  /// 選手、すでに仮契約を結んだ選手は除く。
  static List<PreContract> poachFromUser(
    Team userTeam,
    List<Team> cpuTeams,
    Random rng, {
    required DateTime today,
    double weeks = 1,
    Set<String> alreadyTaken = const {},
  }) {
    if (!isOpen(today) || cpuTeams.isEmpty || weeks <= 0) return const [];
    final made = <PreContract>[];
    for (final p in userTeam.players) {
      if (!inFinalYear(p) || alreadyTaken.contains(p.id)) continue;
      if (ContractEngine.canExerciseOption(p, today)) continue;
      // [weeks]週ぶんの確率(1週の確率を週の数だけ重ねる)。
      final chance = 1 - pow(1 - userPlayerPoachChance(p), weeks).toDouble();
      if (rng.nextDouble() >= chance) continue;
      // 実力に見合うクラブ(平均総合力が近いか上)を優先する。
      final fitting =
          cpuTeams.where((t) => t.overallRating >= p.overall - 5).toList();
      final pool = fitting.isNotEmpty ? fitting : cpuTeams;
      final to = pool[rng.nextInt(pool.length)];
      made.add(
        PreContract(
          playerId: p.id,
          playerName: p.name,
          fromClubId: userTeam.id,
          fromClubName: userTeam.name,
          toClubId: to.id,
          toClubName: to.name,
          wage: wageDemand(p),
          endYear: defaultEndYear(p),
          option: false,
          signedOn: today,
        ),
      );
    }
    return made;
  }
}
