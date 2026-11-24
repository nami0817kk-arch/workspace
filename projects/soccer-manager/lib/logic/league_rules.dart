import 'dart:math';

import '../l10n/tr.dart';
import '../models/ledger.dart';
import '../models/league_theme.dart';
import 'economy_scale.dart';

/// 国(リーグ)ごとの財務規則。2026-11-22 に実際の制度へ寄せた。
///
/// 以前はイタリアに「3季連続の赤字で勝ち点-6」(日本のクラブライセンス)、
/// フランスに「贅沢税」(米国のサラリーキャップ)を当てていて、実際の制度と
/// 別物だった。いまは次の通り(実在の名前は使わず「〜式」と呼ぶ)。
///
/// | 国 | 実際の制度 | ここでの形 |
/// |---|---|---|
/// | イングランド | 収益性と持続性の規則(3季で損失の上限) | 3季の損失の合計が上限を超えると、勝ち点の減点 |
/// | スペイン | 人件費の上限(squad cost limit) | 選手の人件費(年俸+移籍金の償却)が上限を超えると、新加入を登録できない |
/// | ドイツ | ライセンスの審査(自己資本・流動性) | 季の終わりに満たさないと、条件付きで勝ち点の減点 |
/// | イタリア | 流動性の指標 | 指標が基準を下回っている間は、移籍市場で獲得できない |
/// | フランス | DNCG(財務の監督機関) | 赤字・債務が大きいと人件費の上限・補強禁止、ひどければ降格処分 |
///
/// どの国でも、大陸大会に出たクラブには UEFA の人件費比率(選手の人件費と
/// 移籍金の償却 ÷ 収入 が70%まで)が掛かり、超えると罰金。
///
/// 判定に使う損益は [SeasonLedger.ruleProfit](移籍金は償却で数え、施設・
/// アカデミーへの投資は赤字に数えない。借入・出資は損益に入らない)。
///
/// 名前(name)はセーブに残すので、変えない。2026-11-22 より前のセーブの
/// `japan`(イタリアに当てていた)と `usa`(フランス)は、[fromName] で
/// それぞれ [italy] と [france] に読み替える。
enum RuleSet {
  /// イングランド式(収支規則)。
  britain,

  /// ドイツ式(ライセンスの審査)。
  ///
  /// 50+1(クラブの会員が議決権の過半を持つ決まり)は、オーナーの持ち分に
  /// 関わる。このゲームではオーナーが持ち分を売っても議決権は手放さない
  /// 前提なので、規則としては扱わない。
  germany,

  /// スペイン式(人件費の上限)。
  spain,

  /// イタリア式(流動性の指標)。
  italy,

  /// フランス式(DNCG)。
  france;

  /// 国風のテーマから、その国の規則の式を引く。
  static RuleSet forTheme(LeagueTheme theme) => switch (theme) {
        LeagueTheme.england => RuleSet.britain,
        LeagueTheme.germany => RuleSet.germany,
        LeagueTheme.spain => RuleSet.spain,
        LeagueTheme.italy => RuleSet.italy,
        LeagueTheme.france => RuleSet.france,
      };

  /// 保存された名前から引く。2026-11-22 より前の名前も読める。
  static RuleSet? fromName(String? name) => switch (name) {
        'japan' => RuleSet.italy,
        'usa' => RuleSet.france,
        _ => RuleSet.values.where((r) => r.name == name).firstOrNull,
      };

  String get label => switch (this) {
        britain => Tr.pick('イングランド式(収支規則)', 'English style (profit rule)'),
        germany => Tr.pick('ドイツ式(ライセンスの審査)', 'German style (licensing)'),
        spain => Tr.pick('スペイン式(人件費の上限)', 'Spanish style (squad cost limit)'),
        italy => Tr.pick('イタリア式(流動性の指標)', 'Italian style (liquidity index)'),
        france =>
          Tr.pick('フランス式(財務の監督機関)', 'French style (financial watchdog)'),
      };

  String get summary => switch (this) {
        britain => Tr.pick(
            '直近3季の損失の合計に上限があります(部の規模で決まる額)。超えると勝ち点を引かれます。移籍金は契約の年数で割って毎季の費用に数え、施設・アカデミーへの投資は損失に数えません。',
            'Your losses over the last three seasons have a ceiling set by your division. Go over it and you are docked points. Transfer fees count spread over the contract; spending on facilities and the academy does not count.'),
        germany => Tr.pick(
            '季の終わりにライセンスの審査があります。資金(流動性)がマイナス、または自己資本(資金と選手の簿価から借りを引いた額)がマイナスだと、条件付きのライセンスになり勝ち点を引かれます。',
            'Each season ends with a licence review. If your cash is negative, or your equity (cash and player book values minus debts) is negative, the licence comes with conditions and points are docked.'),
        spain => Tr.pick(
            '選手の人件費(年俸と移籍金の償却)に、見込みの収入から決まる上限があります。上限を超える補強は登録できません(獲得できません)。',
            'Player costs (wages plus transfer amortisation) are capped by your projected income. You cannot register signings that would take you over the cap.'),
        italy => Tr.pick(
            '流動性の指標(手元の資金 ÷ 1年以内に払う給与4か月分・分割払い・返済)が${(RulesEngine.liquidityThreshold * 100).round()}%を下回っている間は、移籍市場で選手を獲得できません。売るか資金を入れて戻します。',
            'While your liquidity index (cash divided by four months of wages plus instalments and loan repayments due) is below ${(RulesEngine.liquidityThreshold * 100).round()}%, you cannot sign players. Sell or add funds to get back above it.'),
        france => Tr.pick(
            '季の終わりに財務の監督機関が審査します。赤字や借りが大きいと人件費の上限(年俸の総額を増やせない)、資金がマイナスなら補強禁止、両方ひどければ降格処分です。',
            'A financial watchdog reviews you at the end of each season. Big losses or debts bring a wage cap (no increase to the wage bill); negative cash brings a signing ban; both at once can mean administrative relegation.'),
      };
}

/// 判定の時期と、違反したときの罰(財務規則の札に出す。2026-11-25 の第7段)。
extension RuleSetConsequence on RuleSet {
  /// いつ判定されるか。
  String get checkTiming => switch (this) {
        RuleSet.britain ||
        RuleSet.germany ||
        RuleSet.france =>
          Tr.pick('季の終わり(最終節のあと)', 'At the end of the season'),
        RuleSet.spain ||
        RuleSet.italy =>
          Tr.pick('選手を獲るたび', 'Every time you sign a player'),
      };

  /// 違反するとどうなるか。
  String get consequence => switch (this) {
        RuleSet.britain => Tr.pick(
            '来季の勝ち点を4〜10引かれます(超えた幅が大きいほど多い)。サポーターの期待も-10。',
            'You are docked 4 to 10 points next season (more the further over), and supporters drop 10.'),
        RuleSet.germany => Tr.pick(
            '資金か自己資本の片方がマイナスなら勝ち点-3、両方なら-6。サポーターの期待も下がります。',
            'If cash or equity is negative you lose 3 points; both, 6 points. Supporters drop too.'),
        RuleSet.spain => Tr.pick(
            '上限を超える新加入は登録できません(獲得できません)。勝ち点は引かれません。',
            'You cannot register a signing that takes you over the cap. No points are docked.'),
        RuleSet.italy => Tr.pick(
            '基準を下回っている間は選手を獲得できません。勝ち点は引かれません。',
            'While you are below the threshold you cannot sign players. No points are docked.'),
        RuleSet.france => Tr.pick(
            '赤字か借りが大きいと1季の人件費の上限。資金がマイナスなら1季の補強禁止。大きな赤字で資金もマイナスなら降格処分。',
            'Big losses or debts: a wage cap for a season. Negative cash: a signing ban for a season. Heavy losses with negative cash: administrative relegation.'),
      };
}

/// 規則違反に対する罰。
class RulePenalty {
  const RulePenalty({
    this.fine = 0,
    this.trustLoss = 0,
    this.banSeasons = 0,
    this.pointsDeduction = 0,
    this.wageFreezeSeasons = 0,
    this.adminRelegation = false,
    required this.reason,
  });

  /// 罰金(万円)。
  final int fine;

  /// サポーターの期待の低下。
  final int trustLoss;

  /// 補強の禁止(季数)。
  final int banSeasons;

  /// 来季の勝ち点の剥奪。
  final int pointsDeduction;

  /// 人件費の上限(季数)。この間は年俸の総額を増やす補強ができない。
  final int wageFreezeSeasons;

  /// 降格処分(フランス式)。今季の順位にかかわらず1つ下の部へ。
  final bool adminRelegation;

  /// 理由(ニュースに出す)。
  final String reason;

  /// 2つの罰を合わせる。
  RulePenalty merge(RulePenalty other) => RulePenalty(
        fine: fine + other.fine,
        trustLoss: trustLoss + other.trustLoss,
        banSeasons: max(banSeasons, other.banSeasons),
        pointsDeduction: pointsDeduction + other.pointsDeduction,
        wageFreezeSeasons: max(wageFreezeSeasons, other.wageFreezeSeasons),
        adminRelegation: adminRelegation || other.adminRelegation,
        reason: '$reason / ${other.reason}',
      );
}

/// 規則の現在の状況(画面に出す1行)。
class RuleStatus {
  const RuleStatus({
    required this.label,
    required this.detail,
    required this.level,
    this.now,
    this.limit,
    this.gap,
  });

  final String label;

  /// 1行にまとめた中身(「今 / 上限」)。
  final String detail;

  /// 0=問題なし、1=注意、2=違反。
  final int level;

  /// 今の値(表の「今」の欄)。無ければ [detail] を出す。
  final String? now;

  /// 上限・基準(表の「上限」の欄)。
  final String? limit;

  /// あといくらか。違反なら「あと○○△△と違反を外れます」、そうでなければ
  /// 「余裕 ○○」。
  final String? gap;
}

/// 「あといくら」の字。[over] なら違反を外れるまで、でなければ余裕。
String _gapText(
        {required bool over,
        required String amount,
        required String Function(String amount) fix}) =>
    over ? fix(amount) : Tr.pick('余裕 $amount', '$amount of room');


class RuleReport {
  const RuleReport({required this.statuses, this.penalty});

  final List<RuleStatus> statuses;

  /// 今シーズンを終えた時点で受ける罰。無ければ null。
  final RulePenalty? penalty;
}

/// 規則の判定に使う、いまのクラブのお金の様子(帳簿の外の数字)。
class ClubFinanceSnapshot {
  const ClubFinanceSnapshot({
    this.projectedIncome = 0,
    this.squadCost = 0,
    this.equity = 0,
    this.liquidity = 99,
    this.debt = 0,
    this.inContinental = false,
    this.dueWithinYear = 0,
    this.seasonOver = true,
  });

  /// 1年の収入の見込み(万円)。今の週の収入を1シーズン分。
  final int projectedIncome;

  /// いまの選手の人件費(年俸の合計 + 移籍金の1年分の償却。万円/年)。
  final int squadCost;

  /// 自己資本(資金・預金・基金・選手の簿価 − 融資・分割払い・オーナーからの借り)。
  final int equity;

  /// 流動性の指標(手元の資金 ÷ 1年以内に払う額)。
  final double liquidity;

  /// 借り(融資・分割払いの残り。万円)。
  final int debt;

  /// 今季、大陸大会に出ているか。
  final bool inContinental;

  /// 流動性の指標の分母(1年以内に払う額。万円)。0なら分からない。
  final int dueWithinYear;

  /// 季を締めるときの判定か。false(季の途中)なら、大陸大会の比率は
  /// 見込みで出し、違反・罰にしない。
  final bool seasonOver;

  ClubFinanceSnapshot copyWith({bool? seasonOver}) => ClubFinanceSnapshot(
        projectedIncome: projectedIncome,
        squadCost: squadCost,
        equity: equity,
        liquidity: liquidity,
        debt: debt,
        inContinental: inContinental,
        dueWithinYear: dueWithinYear,
        seasonOver: seasonOver ?? this.seasonOver,
      );
}

/// 規則の判定。画面とシーズン終了の処理の両方がここを使う。
class RulesEngine {
  const RulesEngine._();

  /// 新しいオーナーに猶予を与えるシーズン数。最初のシーズンは、引き継いだ
  /// 人件費や借金のせいで、何をしても違反になりやすい(測定で、何も操作
  /// しない1年目に英国式の上限を超えた)。この間は警告だけで罰は科さない。
  static const int graceSeasons = 1;

  /// 損失を数える季数(イングランド式)。
  static const int lossWindowSeasons = 3;

  /// イングランド式の、3季の損失の合計の上限(万円)。プレミアの £105m
  /// (約200億円)を1部に当て、下の部は規模に合わせて小さくする
  /// (2部はチャンピオンシップの £39m 相当、3部はその規模に合わせた額)。
  static int lossLimitForTier(int tier) => switch (tier.clamp(1, 3)) {
        1 => 2000000, // 200億
        2 => 750000, // 75億
        _ => 100000, // 10億
      };

  /// スペイン式の上限の、収入の見込みに対する割合(1部)。
  static const double squadCostShare = 0.7;

  /// 部ごとのスペイン式の上限のゆるさ。下の部は収入に対して人件費が
  /// 重くなりやすい(選手の価値は能力で決まり、部の収入ほど下がらない)。
  static double looseness(int tier) => switch (tier) {
        <= 1 => 1.0,
        2 => 1.3,
        _ => 1.6,
      };

  /// イタリア式の流動性の指標の基準。実際のセリエAでは 0.7〜0.8。
  static const double liquidityThreshold = 0.7;

  /// 大陸大会の人件費比率の罰(財務規則の札に出す)。
  static String get uefaConsequence => Tr.pick(
      '季の終わりに判定。上限を超えた人件費の${(uefaFineShare * 100).round()}%が罰金になり、サポーターの期待も-3。',
      'Checked at the end of the season. ${(uefaFineShare * 100).round()}% of the excess becomes a fine, and supporters drop 3.');

  /// UEFA の人件費比率の上限。
  static const double uefaSquadCostRatio = 0.7;

  /// UEFA で上限を超えた分のうち、罰金になる割合。
  static const double uefaFineShare = 0.2;

  /// フランス式: 赤字が収入のこの割合を超えると人件費の上限。
  static const double dncgLossShare = 0.15;

  /// フランス式: 借りが収入のこの割合を超えると人件費の上限。
  static const double dncgDebtShare = 0.5;

  /// フランス式: 赤字が収入のこの割合を超え、資金もマイナスなら降格処分。
  static const double dncgSevereLossShare = 0.3;

  /// [ledgers]はシーズン順。最後が今季。[tier]は今いる部(1〜3)。
  /// [lowestTier] より下へは降格処分にできない(勝ち点の剥奪に替える)。
  static RuleReport evaluate({
    required RuleSet ruleSet,
    required List<SeasonLedger> ledgers,
    required int budget,
    int tier = 1,
    int lowestTier = 3,
    ClubFinanceSnapshot snapshot = const ClubFinanceSnapshot(),
  }) {
    final national = switch (ruleSet) {
      RuleSet.britain => _britain(ledgers, tier),
      RuleSet.germany => _germany(budget, snapshot),
      RuleSet.spain => _spain(tier, snapshot),
      RuleSet.italy => _italy(snapshot),
      RuleSet.france =>
        _france(ledgers, budget, snapshot, canRelegate: tier < lowestTier),
    };
    if (!snapshot.inContinental) return national;
    final uefa = _uefa(ledgers, snapshot);
    final p1 = national.penalty;
    final p2 = uefa.penalty;
    return RuleReport(
      statuses: [...national.statuses, ...uefa.statuses],
      penalty: p1 == null ? p2 : (p2 == null ? p1 : p1.merge(p2)),
    );
  }

  /// スペイン式: 上限を超えている間に人件費が減ったとき(売却・放出・満了・
  /// 減俸)、減った分のうち新加入に使える割合。実際の LaLiga は時期で
  /// 1:4〜1:1(減らした4のうち1〜全部)。ゲームでは 1:2(半分)にする
  /// (2026-11-22。以前は上限の下に戻るまで1人も登録できなかった)。
  static const double saleSpendShare = 0.5;

  /// スペイン式の「売った分の一部だけ使える額」(万円/年)を、人件費の動きで
  /// 更新する。[previousCost]は前に見た人件費、[cost]は今の人件費、
  /// [limit]は今の上限。
  ///
  /// - 人件費が減ったら、減った分のうち上限を上回っていた部分の
  ///   [saleSpendShare]を足す(上限の下まで減った分は、そのまま上限の
  ///   空きとして使える)
  /// - 人件費が増えて上限を上回る分が増えたら、その分を使ったとして引く
  ///
  /// [previousCost]が0(まだ見ていない)なら何もしない。
  static int trackSaleAllowance({
    required int allowance,
    required int previousCost,
    required int cost,
    required int limit,
  }) {
    if (previousCost <= 0 || cost == previousCost) return allowance;
    if (cost < previousCost) {
      final overPart = max(0, previousCost - max(limit, cost));
      return allowance + (overPart * saleSpendShare).round();
    }
    final int used = max(0, cost - limit) - max(0, previousCost - limit);
    return max(0, allowance - max(0, used));
  }

  /// スペイン式で、いま新加入に使える人件費(万円/年): 上限までの空きと、
  /// 売った分から使える額([trackSaleAllowance])の合計。
  static int spendableSquadCost({
    required int limit,
    required int cost,
    required int allowance,
  }) =>
      max(0, limit - cost) + allowance;

  /// 補強を止める理由(止めなければ null)。スペイン式は人件費の上限、
  /// イタリア式は流動性の指標。[addedSquadCost] は新加入の年俸と移籍金の
  /// 1年分の償却の合計(万円/年)。[saleAllowance]はスペイン式で、上限を
  /// 超えている間に売った分から使える額([trackSaleAllowance])。
  static String? signingBlock({
    required RuleSet ruleSet,
    required int tier,
    required ClubFinanceSnapshot snapshot,
    int addedSquadCost = 0,
    int saleAllowance = 0,
  }) {
    switch (ruleSet) {
      case RuleSet.spain:
        final limit = squadCostLimit(snapshot.projectedIncome, tier);
        final after = snapshot.squadCost + addedSquadCost;
        if (after <= limit) return null;
        // 上限を上回る分が増える額が、売った分から使える額に収まれば登録できる。
        final extra = (after - limit) - max(0, snapshot.squadCost - limit);
        if (extra <= saleAllowance) return null;
        final spendable = spendableSquadCost(
            limit: limit, cost: snapshot.squadCost, allowance: saleAllowance);
        return Tr.pick(
            '人件費の上限を超えるので、この選手は登録できません(選手の人件費 年${formatMoney(after)} / 上限 年${formatMoney(limit)}・いま使える額 年${formatMoney(spendable)})。上限を超えている間は、売って空いた人件費の${(saleSpendShare * 100).round()}%だけ新加入に使えます。',
            'You cannot register this player: player costs would be ${formatMoney(after)} a year against a limit of ${formatMoney(limit)} (you can add ${formatMoney(spendable)} a year now). While over the limit, only ${(saleSpendShare * 100).round()}% of the costs you shed can go on new signings.');
      case RuleSet.italy:
        if (snapshot.liquidity >= liquidityThreshold) return null;
        return Tr.pick(
            '流動性の指標が${(snapshot.liquidity * 100).round()}%で、基準の${(liquidityThreshold * 100).round()}%を下回っているため、移籍市場で選手を獲得できません。選手を売るか資金を入れて指標を戻してください。',
            'Your liquidity index is ${(snapshot.liquidity * 100).round()}%, below the ${(liquidityThreshold * 100).round()}% threshold, so you cannot sign players. Sell someone or add funds to get it back up.');
      case RuleSet.britain:
      case RuleSet.germany:
      case RuleSet.france:
        return null;
    }
  }

  /// スペイン式の選手の人件費の上限(万円/年)。
  static int squadCostLimit(int projectedIncome, int tier) =>
      (projectedIncome * squadCostShare * looseness(tier)).round();

  static List<SeasonLedger> _window(List<SeasonLedger> ledgers) =>
      ledgers.length <= lossWindowSeasons
          ? ledgers
          : ledgers.sublist(ledgers.length - lossWindowSeasons);

  static RuleReport _britain(List<SeasonLedger> ledgers, int tier) {
    final window = _window(ledgers);
    final cumulative = window.fold<int>(0, (s, l) => s + l.ruleProfit);
    final loss = max(0, -cumulative);
    final limit = lossLimitForTier(tier);
    final level = loss > limit ? 2 : (loss > limit * 0.8 ? 1 : 0);
    final status = RuleStatus(
      label: Tr.pick('直近${window.length}季の損失の合計',
          'Losses over ${Tr.plural(window.length, 'season')}'),
      detail: Tr.pick('${formatMoney(loss)} / 上限${formatMoney(limit)}',
          '${formatMoney(loss)} / limit ${formatMoney(limit)}'),
      level: level,
      now: formatMoney(loss),
      limit: formatMoney(limit),
      gap: _gapText(
          over: loss > limit,
          amount: formatMoney((loss - limit).abs()),
          fix: (a) => Tr.pick('今季あと$aの利益で外れます', 'A profit of $a this season clears it')),
    );
    if (level < 2) return RuleReport(statuses: [status]);
    final excess = loss - limit;
    // 実際の減点は 4〜10(エヴァートン・フォレスト)。超えた幅で増やす。
    final points = min(10, 4 + 2 * (excess * 4 ~/ max(1, limit)));
    return RuleReport(
      statuses: [status],
      penalty: RulePenalty(
        trustLoss: 10,
        pointsDeduction: points,
        reason: Tr.pick('3季の損失の合計が上限を${formatMoney(excess)}超えました',
            'Losses over three seasons passed the limit by ${formatMoney(excess)}'),
      ),
    );
  }

  static RuleReport _spain(int tier, ClubFinanceSnapshot snap) {
    final limit = squadCostLimit(snap.projectedIncome, tier);
    final over = snap.squadCost > limit;
    return RuleReport(statuses: [
      RuleStatus(
        label: Tr.pick('選手の人件費の上限', 'Squad cost limit'),
        detail: Tr.pick(
            '年${formatMoney(snap.squadCost)} / 上限 年${formatMoney(limit)}',
            '${formatMoney(snap.squadCost)} a year / limit ${formatMoney(limit)}'),
        level: over ? 2 : (snap.squadCost > limit * 0.9 ? 1 : 0),
        now: Tr.pick('年${formatMoney(snap.squadCost)}',
            '${formatMoney(snap.squadCost)}/yr'),
        limit: Tr.pick('年${formatMoney(limit)}', '${formatMoney(limit)}/yr'),
        gap: _gapText(
            over: over,
            amount: Tr.pick('年${formatMoney((snap.squadCost - limit).abs())}',
                '${formatMoney((snap.squadCost - limit).abs())}/yr'),
            fix: (a) => Tr.pick('人件費をあと$a減らすと外れます', 'Cut player costs by $a to clear it')),
      ),
    ]);
  }

  static RuleReport _italy(ClubFinanceSnapshot snap) {
    final pct = (snap.liquidity * 100).round();
    final level = snap.liquidity < liquidityThreshold
        ? 2
        : (snap.liquidity < liquidityThreshold + 0.2 ? 1 : 0);
    return RuleReport(statuses: [
      RuleStatus(
        label: Tr.pick('流動性の指標', 'Liquidity index'),
        detail: Tr.pick(
            '${min(pct, 999)}% / 基準${(liquidityThreshold * 100).round()}%',
            '${min(pct, 999)}% / threshold ${(liquidityThreshold * 100).round()}%'),
        level: level,
        now: '${min(pct, 999)}%',
        limit: Tr.pick('${(liquidityThreshold * 100).round()}%以上',
            '${(liquidityThreshold * 100).round()}% or more'),
        // 指標を基準へ戻すのに要る手元の資金(1年以内に払う額 × 差)。
        // 分母が分からなければ出さない。
        gap: snap.dueWithinYear <= 0
            ? null
            : _gapText(
                over: snap.liquidity < liquidityThreshold,
                amount: formatMoney(
                    ((snap.liquidity - liquidityThreshold).abs() *
                            snap.dueWithinYear)
                        .round()),
                fix: (a) => Tr.pick('資金をあと$a増やすと外れます', 'Add $a of cash to clear it')),
      ),
    ]);
  }

  static RuleReport _germany(int budget, ClubFinanceSnapshot snap) {
    final liquid = budget >= 0;
    final equityOk = snap.equity >= 0;
    final statuses = [
      RuleStatus(
        label: Tr.pick('流動性(資金)', 'Liquidity (cash)'),
        detail: formatMoney(budget),
        level: liquid ? 0 : 2,
        now: formatMoney(budget),
        limit: Tr.pick('0以上', '0 or more'),
        gap: _gapText(
            over: !liquid,
            amount: formatMoney(budget.abs()),
            fix: (a) => Tr.pick('資金をあと$a増やすと外れます', 'Add $a of cash to clear it')),
      ),
      RuleStatus(
        label: Tr.pick('自己資本', 'Equity'),
        detail: formatMoney(snap.equity),
        level: equityOk ? 0 : 2,
        now: formatMoney(snap.equity),
        limit: Tr.pick('0以上', '0 or more'),
        gap: _gapText(
            over: !equityOk,
            amount: formatMoney(snap.equity.abs()),
            fix: (a) => Tr.pick('自己資本をあと$a増やすと外れます', 'Raise equity by $a to clear it')),
      ),
    ];
    if (liquid && equityOk) return RuleReport(statuses: statuses);
    final failed = (liquid ? 0 : 1) + (equityOk ? 0 : 1);
    return RuleReport(
      statuses: statuses,
      penalty: RulePenalty(
        trustLoss: 5 * failed,
        pointsDeduction: 3 * failed,
        reason: !liquid && !equityOk
            ? Tr.pick('資金も自己資本もマイナスで、ライセンスに条件が付きました',
                'Both cash and equity were negative, so the licence came with conditions')
            : (!liquid
                ? Tr.pick('資金がマイナスで、ライセンスに条件が付きました',
                    'Cash was negative, so the licence came with conditions')
                : Tr.pick('自己資本がマイナスで、ライセンスに条件が付きました',
                    'Equity was negative, so the licence came with conditions')),
      ),
    );
  }

  static RuleReport _france(
      List<SeasonLedger> ledgers, int budget, ClubFinanceSnapshot snap,
      {required bool canRelegate}) {
    final l = ledgers.isEmpty ? null : ledgers.last;
    final ledgerIncome = l?.operatingIncome ?? 0;
    final income =
        max(1, ledgerIncome > 0 ? ledgerIncome : snap.projectedIncome);
    final loss = max(0, -(l?.ruleProfit ?? 0));
    final lossShare = loss / income;
    final debtShare = snap.debt / income;
    final negative = budget < 0;
    final heavy = lossShare > dncgLossShare || debtShare > dncgDebtShare;
    final severe = negative && lossShare > dncgSevereLossShare;
    final statuses = [
      RuleStatus(
        label: Tr.pick('今季の赤字', 'Loss this season'),
        detail: Tr.pick(
            '${formatMoney(loss)}(収入の${(lossShare * 100).round()}%・目安${(dncgLossShare * 100).round()}%)',
            '${formatMoney(loss)} (${(lossShare * 100).round()}% of income, guide ${(dncgLossShare * 100).round()}%)'),
        level: lossShare > dncgLossShare ? 2 : (loss > 0 ? 1 : 0),
        now: formatMoney(loss),
        limit: Tr.pick('${formatMoney((income * dncgLossShare).round())}まで',
            'up to ${formatMoney((income * dncgLossShare).round())}'),
        gap: _gapText(
            over: lossShare > dncgLossShare,
            amount:
                formatMoney((loss - (income * dncgLossShare).round()).abs()),
            fix: (a) => Tr.pick('赤字をあと$a減らすと外れます', 'Cut the loss by $a to clear it')),
      ),
      RuleStatus(
        label: Tr.pick('借り', 'Debt'),
        detail: Tr.pick(
            '${formatMoney(snap.debt)}(収入の${(debtShare * 100).round()}%・目安${(dncgDebtShare * 100).round()}%)',
            '${formatMoney(snap.debt)} (${(debtShare * 100).round()}% of income, guide ${(dncgDebtShare * 100).round()}%)'),
        level: debtShare > dncgDebtShare ? 2 : 0,
        now: formatMoney(snap.debt),
        limit: Tr.pick('${formatMoney((income * dncgDebtShare).round())}まで',
            'up to ${formatMoney((income * dncgDebtShare).round())}'),
        gap: _gapText(
            over: debtShare > dncgDebtShare,
            amount: formatMoney(
                (snap.debt - (income * dncgDebtShare).round()).abs()),
            fix: (a) => Tr.pick('借りをあと$a減らすと外れます', 'Pay down $a of debt to clear it')),
      ),
      RuleStatus(
        label: Tr.pick('資金', 'Cash'),
        detail: formatMoney(budget),
        level: negative ? 2 : 0,
        now: formatMoney(budget),
        limit: Tr.pick('0以上', '0 or more'),
        gap: _gapText(
            over: negative,
            amount: formatMoney(budget.abs()),
            fix: (a) => Tr.pick('資金をあと$a増やすと外れます', 'Add $a of cash to clear it')),
      ),
    ];
    if (severe) {
      return RuleReport(
        statuses: statuses,
        penalty: canRelegate
            ? RulePenalty(
                trustLoss: 15,
                banSeasons: 1,
                wageFreezeSeasons: 1,
                adminRelegation: true,
                reason: Tr.pick('大きな赤字で資金もマイナスのため、降格処分を受けました',
                    'Heavy losses and negative cash brought administrative relegation'),
              )
            : RulePenalty(
                trustLoss: 15,
                banSeasons: 1,
                wageFreezeSeasons: 1,
                pointsDeduction: 6,
                reason: Tr.pick('大きな赤字で資金もマイナスのため、補強禁止と勝ち点の剥奪を受けました',
                    'Heavy losses and negative cash brought a signing ban and a points deduction'),
              ),
      );
    }
    if (negative) {
      return RuleReport(
        statuses: statuses,
        penalty: RulePenalty(
          trustLoss: 8,
          banSeasons: 1,
          wageFreezeSeasons: 1,
          reason: Tr.pick(
              '資金がマイナスのため、補強禁止を受けました', 'Negative cash brought a signing ban'),
        ),
      );
    }
    if (heavy) {
      return RuleReport(
        statuses: statuses,
        penalty: RulePenalty(
          trustLoss: 4,
          wageFreezeSeasons: 1,
          reason: Tr.pick('赤字・借りが大きいため、人件費に上限が付きました',
              'Big losses or debts brought a cap on the wage bill'),
        ),
      );
    }
    return RuleReport(statuses: statuses);
  }

  /// UEFA の人件費比率。選手の給与・出場手当・移籍金の償却 ÷ (営業収入 +
  /// 選手の売却)。大陸大会に出たクラブだけ。
  ///
  /// 判定は季の終わりだけ([ClubFinanceSnapshot.seasonOver])。季の途中は、
  /// 季の途中の帳簿だと試合の少ない時期に比率が跳ねて「違反」と出ていた
  /// (2026-11-25 の第7段)ので、1年の人件費 ÷ 1年の収入の見込み(+ 今季
  /// ここまでの売却)で「見込み」を出し、注意どまりにする(罰は出さない)。
  static RuleReport _uefa(
      List<SeasonLedger> ledgers, ClubFinanceSnapshot snap) {
    final l = ledgers.isEmpty ? null : ledgers.last;
    if (l == null && snap.seasonOver) return const RuleReport(statuses: []);
    final sales = max(0, l?.of(LedgerCategory.playerSales) ?? 0);
    final projected = !snap.seasonOver;
    final revenue = projected
        ? snap.projectedIncome + sales
        : l!.operatingIncome + sales;
    final cost = projected ? snap.squadCost : l!.squadCost;
    final ratio = revenue <= 0 ? 0.0 : cost / revenue;
    final over = ratio > uefaSquadCostRatio;
    final level = over
        ? (projected ? 1 : 2)
        : (ratio > uefaSquadCostRatio - 0.1 ? 1 : 0);
    final room = (revenue * uefaSquadCostRatio).round() - cost;
    final status = RuleStatus(
      label: projected
          ? Tr.pick('大陸大会の人件費比率(季末の見込み)',
              'Continental squad cost ratio (season forecast)')
          : Tr.pick('大陸大会の人件費比率', 'Continental squad cost ratio'),
      detail: Tr.pick(
          '${(ratio * 100).round()}% / 上限${(uefaSquadCostRatio * 100).round()}%',
          '${(ratio * 100).round()}% / limit ${(uefaSquadCostRatio * 100).round()}%'),
      level: level,
      now: '${(ratio * 100).round()}%',
      limit: Tr.pick('${(uefaSquadCostRatio * 100).round()}%まで',
          'up to ${(uefaSquadCostRatio * 100).round()}%'),
      gap: projected && room < 0
          ? Tr.pick(
              'このままだと季末に超えます。1年の人件費をあと${formatMoney(-room)}減らすと収まります',
              'On course to go over at season end. Cut ${formatMoney(-room)} a year of player costs to stay under')
          : _gapText(
              over: room < 0,
              amount: formatMoney(room.abs()),
              fix: (a) => Tr.pick('人件費をあと$a減らすと外れます',
                  'Cut player costs by $a to clear it')),
    );
    if (level < 2) return RuleReport(statuses: [status]);
    final excess = cost - (revenue * uefaSquadCostRatio).round();
    return RuleReport(
      statuses: [status],
      penalty: RulePenalty(
        fine: (excess * uefaFineShare).round(),
        trustLoss: 3,
        reason: Tr.pick('大陸大会の人件費比率が${(ratio * 100).round()}%で上限を超えました',
            'The continental squad cost ratio was ${(ratio * 100).round()}%, over the limit'),
      ),
    );
  }
}
