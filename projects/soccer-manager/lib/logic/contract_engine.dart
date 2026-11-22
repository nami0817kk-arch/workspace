import 'dart:math';

import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../l10n/tr.dart';

class ContractEngine {
  /// 週俸総額。他クラブへローン放出中の選手は放出先が週俸を負担するため含めない。
  static int weeklyWageBill(Team team) => team.players
      .where((p) => !p.isLoanedOut)
      .fold<int>(0, (s, p) => s + p.wage);

  /// 契約の満了日の表示。「2028年6月まで」/ "until Jun 2028"。
  /// 満了済み(フリーエージェント)は「契約なし」。
  static String untilLabel(int endYear) {
    if (endYear < Player.contractClockYear) {
      return Tr.pick('契約なし', 'No contract');
    }
    return Tr.pick('$endYear年6月まで', 'until Jun $endYear');
  }

  /// [untilLabel]の短い形(表の列など)。「2028/6」/ "Jun 2028"。
  static String untilShortLabel(int endYear) {
    if (endYear < Player.contractClockYear) return Tr.pick('なし', 'None');
    return Tr.pick('$endYear/6', 'Jun $endYear');
  }

  /// ごく狭い列向けの満了の年(「28年」/ "'28")。
  static String untilTinyLabel(int endYear) {
    if (endYear < Player.contractClockYear) return Tr.pick('なし', '-');
    final yy = (endYear % 100).toString().padLeft(2, '0');
    return Tr.pick('$yy年', "'$yy");
  }

  /// 選手の契約の表示(延長オプション・「延長しない」の印つき)。
  static String contractLabel(Player p) {
    final base = untilLabel(p.contractEndYear);
    final marks = [
      if (p.contractOption) Tr.pick('延長オプション付き', '1-year option'),
      if (p.refusesRenewal) Tr.pick('延長しない', 'will not renew'),
    ];
    return marks.isEmpty ? base : '$base (${marks.join(Tr.pick('・', ', '))})';
  }

  /// 契約の長さの上限(年)。実在の決まりに寄せる: 最長5年、18歳未満は3年。
  static const int maxContractYears = 5;
  static const int maxMinorContractYears = 3;

  /// スペインの契約の上限(年)。スペインでは法律で5年を超える契約を結べる
  /// (リリース条項と組み合わせて長い契約が多い)。ゲームでは8年まで。
  static const int maxSpanishContractYears = 8;

  /// いま遊んでいる国の、18歳以上の契約の上限(年)。選手は国を知らないので、
  /// ゲームの側が読み込み・新規開始・季の切り替えのたびに合わせる
  /// ([Player.contractClockYear]と同じ。GameState._syncContractClock)。
  static int adultContractYearsCap = maxContractYears;

  /// [country]の18歳以上の契約の上限(年)。スペインだけ長い。
  static int adultCapFor(LeagueTheme country) =>
      country == LeagueTheme.spain ? maxSpanishContractYears : maxContractYears;

  /// プロ契約を結べる年齢。ユースの選手はこの年齢になるまで一軍の契約を
  /// 結べない。
  static const int minProfessionalAge = 16;

  /// [age]歳の選手と結べる契約の長さの上限(年)。
  static int capYears(int age) =>
      age < 18 ? maxMinorContractYears : adultContractYearsCap;

  /// 今日結ぶ契約で選べる最も遅い満了の年。契約は結んだ日から数えて上限の
  /// 年数以内に終わる。シーズン中(7/1〜翌6/30)のどの日に結んでも、
  /// 5年なら今のシーズン末の4年後の6月30日が最後になる。
  static int maxEndYearNow(int age) =>
      Player.contractClockYear + capYears(age) - 1;

  /// 7月1日に始まる契約(仮契約)で選べる最も遅い満了の年。
  static int maxEndYearFromNextSeason(int age) =>
      Player.contractClockYear + capYears(age);

  /// 今日結ぶ契約で選べる満了の年(短い順)。最短は来季末(今のシーズン末で
  /// 切れる契約を結び直しても意味がない)。
  static List<int> endYearChoicesNow(int age) => [
        for (var y = Player.contractClockYear + 1; y <= maxEndYearNow(age); y++)
          y,
      ];

  /// 延長オプションを付けられるか。行使して1年延びても上限の年数に
  /// 収まるときだけ([nextSeasonStart]は7月1日に始まる仮契約のとき true)。
  static bool canAttachOption(int endYear, int age,
          {bool nextSeasonStart = false}) =>
      endYear + 1 <=
      (nextSeasonStart ? maxEndYearFromNextSeason(age) : maxEndYearNow(age));

  /// 延長オプションを付けると、選手は少し高い週俸を求める(行使されれば
  /// 同じ週俸のまま1年縛られるので、その分を先に求める)。
  static const double optionWageFactor = 1.05;

  /// 延長オプションを行使できる期限(満了の年の3月31日)。
  static DateTime optionDeadline(int endYear) => DateTime(endYear, 3, 31);

  /// 今日[today]、選手の延長オプションを行使できるか。
  static bool canExerciseOption(Player p, DateTime today) =>
      p.contractOption &&
      !p.isLoan &&
      p.contractEndYear == Player.contractClockYear &&
      !today.isAfter(optionDeadline(p.contractEndYear));

  /// 延長オプションを行使する。満了が1年延び、年俸はそのまま。
  static void exerciseOption(Player p) {
    p.contractEndYear += 1;
    p.contractOption = false;
    p.refusesRenewal = false;
  }

  /// 残り契約年数の表示ラベル(スポンサー契約など、年数で持つ契約の表示)。
  static String yearsLabel(int yearsRemaining) {
    if (yearsRemaining <= 0) return Tr.pick('契約満了間近', 'Contract almost up');
    return Tr.pick(
        '契約残り$yearsRemaining年', '${Tr.plural(yearsRemaining, 'year')} left');
  }

  /// [yearsLabel]の短縮版(トレーリング領域など表示幅が限られる箇所向け)。
  static String yearsShortLabel(int yearsRemaining) {
    if (yearsRemaining <= 0) return Tr.pick('契約満了間近', 'Contract almost up');
    return Tr.pick('残り$yearsRemaining年', Tr.plural(yearsRemaining, 'year'));
  }

  /// ローン期間(週単位)を1週分消化させ、ローン満了となった選手を
  /// チームから除外して返す(元クラブへ復帰するため、フリーエージェントには
  /// 加えない)。契約(年単位)自体はシーズン開始時に[advanceSeason]でまとめて
  /// 処理する。
  ///
  /// ローンの終わりは日付([Player.loanEndDate])で持つ。[today]がその日に
  /// 届いたら戻す。日付の無いローン(旧セーブ・テストで作った選手)だけ、
  /// 週数を1つ減らして数える。
  static List<Player> advanceLoanWeek(Team team, {DateTime? today}) {
    final expired = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (!p.isLoan) continue;
      final end = p.loanEndDate;
      if (end != null) {
        if (today != null && !today.isBefore(end)) expired.add(p);
        continue;
      }
      if (p.loanWeeksRemaining > 0) {
        p.loanWeeksRemaining -= 1;
      }
      if (p.loanWeeksRemaining <= 0) {
        expired.add(p);
      }
    }
    for (final p in expired) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return expired;
  }

  /// 7月1日に新しいシーズンへ入ったときの契約の処理。満了日(6月30日)を
  /// 過ぎた選手をチームから外し、外した選手と、満了の年(最終年)に入った
  /// 選手(事前の知らせ用)を返す。ローン選手は対象外(ローンは日付で持ち、
  /// [advanceLoanWeek]で扱う)。
  ///
  /// 契約は満了の年で持つので、ここで年数を減らすことはしない。呼ぶ前に
  /// [Player.contractClockYear]を新しいシーズンに合わせておくこと。
  static ({List<Player> expired, List<Player> nearingExpiry}) advanceSeason(
    Team team,
  ) {
    final expired = <Player>[];
    final nearingExpiry = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (p.isLoan) continue;
      if (p.contractEndYear < Player.contractClockYear) {
        expired.add(p);
      } else if (p.contractEndYear == Player.contractClockYear) {
        nearingExpiry.add(p);
      }
    }
    for (final p in expired) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return (expired: expired, nearingExpiry: nearingExpiry);
  }

  /// 契約更新にかかる基本費用(万円)。代理人への手数料にあたる。
  /// ローン選手には適用されない。
  ///
  /// 以前は市場価値の50%だった。総合90の選手で2,038万円で、サインボーナスと
  /// 合わせて2,527万円。**契約を更新するのに移籍金の半額を払う**形になっていて、
  /// 選手が育つほど手元に残せなくなっていた(実際にそう遊びづらいという声が
  /// 出た)。移籍で獲るのと更新で残すのが同じ値段では、育てる意味が薄い。
  ///
  /// 手数料は週俸に紐づける。3か月分(12週)を目安にした。価値ではなく
  /// 待遇に応じた額になるので、高給の主力ほど高く、若手は安い。
  /// 市場価値に応じた大きな出費はサインボーナス(signingBonusFor)が担う。
  static int renewalCost(Player p) {
    final agentFee = p.wage * agentFeeWeeks;
    // 週俸だけに紐づけると、更新のたびに要求週俸が上がる(最低希望額は
    // 現在の週俸の1.05〜1.20倍)ぶん手数料も膨らむ。何度も更新した主力ほど
    // 残しにくくなり、元の問題が形を変えて戻ってくる。
    //
    // 市場価値に対する上限を置く。サインボーナス(12%)と合わせても
    // 市場価値の3割に届かないので、**残す方が買い直すより必ず安い**。
    final cap = (p.marketValue * maxRenewalShareOfValue).round();
    return agentFee < cap ? agentFee : cap;
  }

  /// 代理人手数料の週数。
  static const int agentFeeWeeks = 12;

  /// 代理人手数料が市場価値に対して占めてよい上限。
  static const double maxRenewalShareOfValue = 0.15;

  /// 放出(売却)で手に入る額(万円)。市場価値の7割。
  ///
  /// 以前はここから「残りの契約の違約金」を差し引いていた。売却では契約を
  /// 買い手が引き継ぐので、売り手が残りの年俸を払うのはつじつまが合わない
  /// (高年俸の長期契約の選手を売ると持ち出しになっていた)。残りの年俸を
  /// 払うのは、合意して契約を解除するとき([mutualTerminationCost])だけ。
  static int salePrice(Player p) => (p.marketValue * 0.7).round();

  /// 新しい契約を結んだときに、契約の型を「固定」へ戻す(出来高・段階昇給の
  /// 取り決めは、その契約かぎり)。
  ///
  /// 以前は更新・移籍のあとも残り、段階昇給は新しい契約の週俸からさらに
  /// 毎季上がり続けていた。
  static void resetContractStyle(Player p) {
    p.goalBonus = 0;
    p.raisePct = 0;
  }

  /// 他のクラブ(AI)へ移った選手に、新しいクラブとの契約を結ばせる。
  /// [years]は今のシーズンを含めた年数で、18歳未満は3年までに収める
  /// ([capYears])。売却先・AI 同士の移籍のどちらにも使う。
  static void applyCpuClubContract(Player p, int years) {
    p.contractYearsRemaining = max(1, min(years, capYears(p.age)));
    p.contractOption = false;
    p.refusesRenewal = false;
    p.wageStatus = null;
    resetContractStyle(p);
  }

  /// 契約更新時に一括で要求されるサインボーナス（万円）。野心家など要求水準が
  /// 高い性格ほど高額になる。
  static int signingBonusFor(Player p) =>
      (p.marketValue * 0.12 * p.personality.wageSensitivity).round();

  /// リーグ公式戦にスタメン出場するたびに支払われる出場手当（万円）。
  static int appearanceFeeFor(Player p) =>
      (p.overall * 0.5 * p.personality.wageSensitivity).round().clamp(1, 60);

  /// 新規契約・更新時に結ばれる契約年数。若い選手ほど長期契約を結びやすく、
  /// ベテランほど短期契約になる(現実のクラブ経営に合わせた簡易モデル)。
  static int negotiatedYears(Player p) {
    if (p.age <= 23) return 4;
    if (p.age <= 27) return 3;
    if (p.age <= 31) return 2;
    return 1;
  }

  /// [years]を指定しない場合は[negotiatedYears]で年齢に応じた契約年数を結ぶ。
  ///
  /// 結んだ年数に**今シーズンぶんを1年足す**。契約はシーズン境界で1年
  /// 消化される(advanceSeason)ので、足さないと「今シーズンぶん」を結んだ
  /// ことになり、その場で消えてしまう。
  ///
  /// 実際に壊れていた。32歳以上の契約年数は1年なので、更新しても境界で
  /// 1→0となり**同じシーズン末に退団する**。更新が何の効果も持たず、
  /// 「30歳を超えると更新してくれない」ように見えていた。
  ///
  /// 足したあとは、更新した時点から数えて[negotiatedYears]シーズンぶん
  /// 在籍する。32歳なら今季＋来季。
  ///
  /// 満了の年は[endYear]で直接選ぶこともできる。どちらも契約の長さの上限
  /// ([maxEndYearNow]: 最長5年、18歳未満は3年)に収める。
  static void renewContract(
    Player p, {
    int? years,
    int? endYear,
    bool option = false,
  }) {
    final wanted =
        endYear ?? Player.contractClockYear + (years ?? negotiatedYears(p));
    final lo = Player.contractClockYear + 1;
    final end = min(max(wanted, lo), max(lo, maxEndYearNow(p.age)));
    p.contractEndYear = end;
    p.contractOption = option && canAttachOption(end, p.age);
    p.refusesRenewal = false;
    p.appearanceFee = appearanceFeeFor(p);
    resetContractStyle(p);
  }

  /// 年数を選ばずに更新したときの満了の年([renewContract]の既定)。
  static int defaultRenewalEndYear(Player p) => min(
        Player.contractClockYear + negotiatedYears(p),
        max(Player.contractClockYear + 1, maxEndYearNow(p.age)),
      );

  /// 移籍で獲得した選手に、新しいクラブとの契約を結ばせる。
  ///
  /// 元のクラブでの残り年数のまま引き継いでいたため、残り1年の選手を買うと
  /// 次のシーズンの切り替わりでその場で退団していた。[renewContract]と同じく
  /// 今シーズンぶんの1年を足した年数を最低限とし、それより長く残っている
  /// 契約は縮めない。
  ///
  /// 満了の年は上限([maxEndYearNow])より先にはしない。元のクラブとの
  /// 延長オプション・「延長しない」は引き継がない([option]で新しく付ける)。
  static void applyTransferContract(Player p, {bool option = false}) {
    final cap = maxEndYearNow(p.age);
    final minimum = Player.contractClockYear + negotiatedYears(p);
    var end = p.contractEndYear;
    if (end < minimum) end = minimum;
    if (end > cap) end = cap;
    if (end <= Player.contractClockYear) end = Player.contractClockYear + 1;
    p.contractEndYear = end;
    p.contractOption = option && canAttachOption(end, p.age);
    p.refusesRenewal = false;
    // 週俸は元のクラブのまま(序列で決めた額ではない)。
    p.wageStatus = null;
    resetContractStyle(p);
  }

  // ---- 113. 「延長しない」と言い出す選手 ----

  /// 満了の年(残り1年)に入ったとき、更新に応じない選手になる確率。
  ///
  /// - 土台 8%。
  /// - 性格: 野心家・成り上がり志向は +12%、忠誠心の強い選手・模範選手は -6%。
  /// - 不満: 満足度が50未満なら +25%、65未満なら +10%(出番が少ないと下がる)。
  /// - 年俸の不満: 価値に見合う週俸の 3/4 に届かなければ +10%。
  /// - 上限 60%。
  static double refuseRenewalChance(Player p) {
    var chance = 0.08;
    switch (p.personality) {
      case PlayerPersonality.ambitious:
      case PlayerPersonality.driven:
        chance += 0.12;
      case PlayerPersonality.loyal:
      case PlayerPersonality.modelCitizen:
        chance -= 0.06;
      default:
        break;
    }
    if (p.happiness < 50) {
      chance += 0.25;
    } else if (p.happiness < 65) {
      chance += 0.10;
    }
    if (p.wage * 4 < p.fairWeeklyWage() * 3) chance += 0.10;
    return chance.clamp(0.0, 0.6);
  }

  // ---- 114. 給料の未払いで契約を解除される ----

  /// 資金のマイナスがこの週数(約2か月)続くと、給料を2か月分払えていない
  /// ものとして選手に通告が届く(実在の決まり: 2か月分の未払いで、
  /// 15日の催告のあと選手は契約を解除できる)。
  static const int unpaidNoticeWeeks = 9;

  /// 催告から15日(約2週)たっても払えなければ、選手は契約を解除して
  /// 自由契約で出ていける。
  static const int unpaidTerminationWeeks = 11;

  /// 解除を考えるのは週俸の高い順にこの人数まで(行き先のある選手から出ていく)。
  static const int unpaidWalkoutCandidates = 6;

  /// 1人が1週のうちに解除する確率。
  static const double unpaidWalkoutChance = 0.3;

  /// 1週に出ていく人数の上限。
  static const int unpaidWalkoutsPerWeek = 2;

  /// 資金のマイナスが[negativeWeeks]週続いているとき、今週契約を解除して
  /// 出ていく選手。ローン選手と貸し出し中の選手は含めない。
  static List<Player> unpaidWageWalkouts(
    Team team,
    int negativeWeeks,
    Random rng,
  ) {
    if (negativeWeeks < unpaidTerminationWeeks) return const [];
    final candidates = team.players
        .where((p) => !p.isLoan && !p.isLoanedOut)
        .toList()
      ..sort((a, b) => b.wage.compareTo(a.wage));
    final leaving = <Player>[];
    for (final p in candidates.take(unpaidWalkoutCandidates)) {
      if (leaving.length >= unpaidWalkoutsPerWeek) break;
      if (rng.nextDouble() < unpaidWalkoutChance) leaving.add(p);
    }
    return leaving;
  }

  // ---- 115. 合意して契約を解除する ----

  /// 今日[today]から満了日(満了の年の6月30日)までの週数(切り上げ)。
  static int weeksUntilExpiry(Player p, DateTime today) {
    final end = DateTime.utc(p.contractEndYear, 6, 30);
    final from = DateTime.utc(today.year, today.month, today.day);
    final days = end.difference(from).inDays;
    if (days <= 0) return 0;
    return (days / 7).ceil();
  }

  /// 残りの年俸(満了までの週俸の合計、万円)。
  static int remainingWages(Player p, DateTime today) =>
      p.wage * weeksUntilExpiry(p, today);

  /// 合意解除で払う割合(残りの年俸に対して)。半分〜全額。
  ///
  /// 若い選手ほど次のクラブを見つけやすいので少なくて済み、年を取った
  /// 選手ほど残りを全部欲しがる(24歳で半分、34歳で全額へ、年齢でまっすぐ)。
  /// 市場価値が残りの年俸を上回る選手は引く手あまたなので、さらに1割下がる。
  static double mutualTerminationShare(Player p, DateTime today) {
    final ageShare = ((p.age - 24) / 10).clamp(0.0, 1.0);
    final inDemand = p.marketValue >= remainingWages(p, today);
    return (0.5 + 0.5 * ageShare - (inDemand ? 0.1 : 0.0)).clamp(0.5, 1.0);
  }

  /// 合意して契約を解除するときに払う額(万円)。
  static int mutualTerminationCost(Player p, DateTime today) =>
      (remainingWages(p, today) * mutualTerminationShare(p, today)).round();

  /// 契約交渉で選手が受け入れる最低週俸(万円)。要求水準が高い性格ほど、
  /// より大きな昇給を求める。
  /// スカッド・ステータス(出場機会の約束)が上の立場ほど、その立場に
  /// 見合った週給を求める(キープレイヤー扱いなら高く、育成枠なら控えめ)。
  static int minimumAcceptableWage(Player p) => (p.wage *
          (1.05 + p.personality.wageSensitivity * 0.15) *
          p.squadStatus.wageFactor)
      .round();

  /// 契約の途中で序列を[from](今の週俸を決めたときの序列)より上の[to]へ
  /// 上げたときに、選手が求める見直し後の週俸(万円)。上げた立場に見合う
  /// 分だけ週俸が上がる([SquadStatus.wageFactor]の比)。上げていなければ
  /// そのまま。
  ///
  /// これが無いと、育成枠で安く更新してすぐキープレイヤーに戻せた。
  static int reviewedWageForPromotion(
          int wage, SquadStatus from, SquadStatus to) =>
      to.index < from.index
          ? (wage * to.wageFactor / from.wageFactor).round()
          : wage;

  /// 交渉開始時に選手側がまず提示する要求額(万円)。本当の最低希望額を
  /// 開始直後にそのまま見せてしまうと駆け引きが成立しなくなるため、
  /// 実際の最低ラインより高めに構えさせる(以降の対案と同じ上乗せ率)。
  static int initialDemand(Player p) =>
      (minimumAcceptableWage(p) * 1.15).round();

  /// この回数を超えて折り合わない場合、選手は交渉から離脱する。
  static const int maxNegotiationRounds = 3;

  /// クラブの提示額を拒否した際に選手側が出す対案(万円)。
  /// 最低希望額よりやや高めに構え、徐々に譲歩していく。
  static int counterOffer(Player p, int rejectedOffer) {
    final minAcceptable = minimumAcceptableWage(p);
    final demand = ((rejectedOffer + minAcceptable * 1.15) / 2).round();
    return demand < minAcceptable ? minAcceptable : demand;
  }
}
