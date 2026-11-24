import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../logic/investment_engine.dart';
import '../logic/loan_engine.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/amount_nudger.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/budget_plan_card.dart';
import '../widgets/economy_card.dart';
import '../widgets/advisor_card.dart';
import '../widgets/auto_columns.dart';
import '../widgets/owner_career_card.dart';
import '../widgets/equity_card.dart';
import '../widgets/media_deals_card.dart';
import '../widgets/business_card.dart';
import '../widgets/proposal_card.dart';
import '../widgets/risk_card.dart';
import '../widgets/place_link.dart';
import '../widgets/owner_wealth_card.dart';
import '../logic/todo_advisor.dart';
import '../logic/sponsor_slots.dart';
import '../widgets/shell_nav.dart';
import '../widgets/todo_list.dart';
import '../widgets/rules_card.dart';
import '../widgets/reward_funds_card.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';
import '../l10n/tr.dart';
import '../widgets/screen_bar.dart';
import '../widgets/sponsor_slots_card.dart';
import '../widgets/help_button.dart';
import '../logic/economy_scale.dart';
import '../widgets/disabled_reason.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, this.embedded = false, this.initialTab = 0});

  /// タブの数(概要・お金を集める・事業と規則)。
  static const int tabCount = 3;

  /// 最初に開くタブ(単独で開くとき)。番号は [TodoPlaces] と同じ。
  final int initialTab;

  /// 下タブの一員として表示するか。true なら戻るボタンを出さない。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;

    return DefaultTabController(
      length: tabCount,
      initialIndex: initialTab.clamp(0, tabCount - 1),
      // 左メニューの中にあるときは、「やること」の行き先からタブを選べる。
      child: ShellTabSync(
        menu: TodoMenu.finance,
        enabled: embedded,
        child: Scaffold(
        appBar: screenBar(
          context,
          title: Tr.pick('クラブ経営', 'Club finances'),
          leading: embedded ? null : const BackButton(),
          actions: const [QuickAccessMenuButton()],
          scrollable: true,
          tabMarks:
              embedded
                  ? todoTabMarks(context, TodoMenu.finance, tabCount)
                  : const [],
          // 2026-11-25 の第7段: 「方針と投資」を「事業と規則」に改めた。
          // 方針はオーナー室へ移り(第2段)、投資案件は事業になり、財務規則と
          // 顧問・定期預金(本当の投資)をここに集めた。
          tabs: [
            Tr.pick('概要', 'Overview'),
            Tr.pick('お金を集める', 'Raise money'),
            Tr.pick('事業と規則', 'Business & rules'),
          ],
        ),
        drawer: const QuickAccessDrawer(),
        body: TabBarView(
          children: [
            // 概要: 今年のお金だけ。押す所(提案の承認・営業の強化・予算の
            // 配り方)を上に置き、数字はその下(2026-11-25 の第7段)。
            ResponsiveBody(
              // 広い画面(iPad の横向きなど)では2列に並べる。
              child: AutoColumns(
                children: [
                  // 監督からの提案(承認待ち)は先頭に。提案が無ければ何も出ない。
                  const ProposalCard(),
                  const _RuleAlertLink(),
                  const RewardFundsCard(),
                  const _YearMoneyCard(),
                  const BudgetPlanCard(),
                  const _PolicyLine(),
                  const _MoneyCalendarCard(),
                  if (save.pendingInstallments.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Tr.pick('分割払い残金', 'Instalments outstanding'),
                                style: Theme.of(context).textTheme.titleMedium),
                            for (final inst in save.pendingInstallments)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: inst.playerId == null
                                    ? null
                                    : () => _openPlayer(context, inst.playerId!),
                                title: Text(inst.description),
                                subtitle: Text(inst.annual
                                    ? Tr.pick('残り${inst.weeksRemaining}回(季の締めに払う)',
                                        '${Tr.plural(inst.weeksRemaining, 'payment')} left (at each season end)')
                                    : Tr.pick('残り${inst.weeksRemaining}週',
                                        '${Tr.plural(inst.weeksRemaining, 'week')} left')),
                                trailing: Text(inst.annual
                                    ? Tr.pick('-${formatMoney(inst.weeklyAmount)}/年',
                                        '-${formatMoney(inst.weeklyAmount)} a year')
                                    : Tr.pick('-${formatMoney(inst.weeklyAmount)}/週',
                                        '-${formatMoney(inst.weeklyAmount)} per week')),
                              ),
                          ],
                        ),
                      ),
                    ),
                  // 契約の更新の操作は「選手 > 登録と契約」の1か所。経営の
                  // 概要からの入口(「契約状況は『登録と契約』へ」の札)は
                  // 利用者と決めて外した(2026-11-25「不要」)。ローンで
                  // 来ている選手の一覧も、今年のお金ではないので外した
                  // (スカッドの表に「ローン加入中」の印がある)。
                ],
              ),
            ),
            // お金を集める: 3つの手に分けて並べる(2026-11-25 の第7段)。
            // ①稼ぐ(スポンサー・命名権) ②借りる(銀行・社債) ③出資を
            // 受ける(オーナー・株主)。定期預金はお金を増やす投資なので、
            // 「事業と規則」の投資の札へ移した。
            ResponsiveBody(
              child: AutoColumns(
                children: [
                  const _FundingSummary(),
                  _GroupHeading(
                      Tr.pick('稼ぐ: スポンサーと命名権', 'Earn: sponsors and naming rights')),
                  SponsorSlotsCard(
                      chest: _SponsorSection(gameState: gameState)),
                  const MediaDealsCard(),
                  _GroupHeading(Tr.pick('借りる: 銀行の融資', 'Borrow: bank loans')),
                  _LoanSection(gameState: gameState),
                  _GroupHeading(
                      Tr.pick('出資を受ける: オーナーと株主', 'Bring in capital: you and shareholders')),
                  // オーナーの財布(出資・貸す/返してもらう)。以前は
                  // 「オーナー室 > オーナーと世界」にあった。
                  const OwnerWealthCard(),
                  const EquityCard(),
                  PlaceLink(
                    key: const ValueKey('finance-to-owner-finance-works'),
                    icon: Icons.work_outline,
                    title: Tr.pick('社債・特別配当・経費の見直しは「オーナーの仕事」へ',
                        "Bonds, special dividends and cost reviews: open Owner's work"),
                    note: Tr.pick('財務・資本の手(1シーズンに1回ずつ)は、オーナー室にまとめてあります。',
                        "Finance & capital moves (once a season each) are in the owner's office."),
                    place: TodoPlaces.ownerFinanceWorks,
                  ),
                ],
              ),
            ),
            // 事業と規則: 財務規則(違反の「やること」の行き先)を先頭に、
            // 事業・顧問・投資・備え・景気・5か年計画。
            ResponsiveBody(
              child: AutoColumns(
                children: [
                  const RulesCard(),
                  const BusinessCard(),
                  const AdvisorCard(),
                  Card(
                    key: const ValueKey('finance-investments'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleWithHelp(
                            title: Tr.pick('投資(定期預金)', 'Investments (fixed deposits)'),
                            help: Tr.pick('資金を預けて増やします。満期まで引き出せない代わりに、満期のときにまとまった利息を受け取れます。',
                                'Put money away to grow it. Locked until it matures, and pays a lump of interest when it does.'),
                          ),
                          _InvestmentSection(gameState: gameState),
                        ],
                      ),
                    ),
                  ),
                  const RiskCard(),
                  const EconomyCard(),
                  const FiveYearPlanCard(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, String playerId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: playerId)),
    );
  }
}

/// 「お金を集める」の手のまとまりの見出し。
class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

/// お金を集める手の、いま使える量を3つ並べる(稼ぐ・借りる・出資)。
class _FundingSummary extends StatelessWidget {
  const _FundingSummary();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save!;
    final offers = (save.sponsorDeal == null
            ? gs.pendingSponsorOffers.length
            : 0) +
        SponsorSlot.values
            .where((s) => gs.slotSponsor(s) == null && gs.slotSponsorOffer(s) != null)
            .length +
        (save.namingDeal == null && save.pendingNamingOffers.isNotEmpty ? 1 : 0);
    return Card(
      key: const ValueKey('funding-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('いま集められるお金', 'What you can raise now'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BigFigure(
                  label: Tr.pick('返事を待つ契約', 'Offers waiting'),
                  value: Tr.pick('$offers件', '$offers'),
                  color: offers > 0 ? SemanticColors.positive(context) : null,
                ),
                _BigFigure(
                  label: Tr.pick('借りられる額', 'You can borrow'),
                  value: formatMoney(gs.maxLoanAmount),
                ),
                _BigFigure(
                  label: Tr.pick('オーナーの個人資産', 'Your own wealth'),
                  value: formatMoney(gs.ownerWealth),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 財務規則に注意・違反があるときだけ出す入口(押すと「事業と規則」へ)。
/// 違反は状況の必須の「やること」にも出る。
class _RuleAlertLink extends StatelessWidget {
  const _RuleAlertLink();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final bad = gs.ruleReport.statuses.where((s) => s.level >= 1).toList();
    if (bad.isEmpty) return const SizedBox.shrink();
    final breach = bad.any((s) => s.level >= 2);
    return PlaceLink(
      key: const ValueKey('finance-rule-alert'),
      icon: breach ? Icons.gavel : Icons.warning_amber_outlined,
      title: breach
          ? Tr.pick('財務規則に違反しています', 'You are breaking the financial rules')
          : Tr.pick('財務規則の上限に近づいています', 'You are close to a financial rule limit'),
      note: [
        for (final s in bad) '${s.label}: ${s.gap ?? s.detail}',
      ].join(Tr.pick('・', ' • ')),
      place: TodoPlaces.financeRules,
    );
  }
}

/// クラブの方針(オフシーズンだけ変えられる)を1行で。押すとオーナー室の
/// 「文化と方針」へ。
class _PolicyLine extends StatelessWidget {
  const _PolicyLine();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return PlaceLink(
      key: const ValueKey('finance-policy-line'),
      icon: gs.canChangeClubPolicy ? Icons.tune : Icons.lock_clock_outlined,
      title: gs.canChangeClubPolicy
          ? Tr.pick('方針: ${gs.nextClubPolicy.label}(開幕前まで変えられます)',
              'Policy: ${gs.nextClubPolicy.label} (can change until kick-off)')
          : Tr.pick('方針: ${gs.clubPolicy.label}(変えられるのは来季の開幕前)',
              'Policy: ${gs.clubPolicy.label} (can change before next season)'),
      note: '',
      place: TodoPlaces.ownerWorld,
    );
  }
}

/// 今年のお金(収入・支出・収支、季末の資金の見込み、給与予算)。
class _YearMoneyCard extends StatelessWidget {
  const _YearMoneyCard();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    // 大きな数字は1年あたり(1節あたりの額 × 1季の節の数)で見せる
    // (2026-11-22「週報ではなくて年報に」)。
    final md = gameState.matchdaysPerSeason;
    // 放映権は今の順位での配分式の見込み、運営費も引く(記帳と同じ額)。
    final income = gameState.projectedMatchdayIncome * md;
    final weeklyBill = gameState.weeklyWageBill;
    final hasLoan = gameState.bankLoans.isNotEmpty;
    // 支出は人件費・運営費・返済の合計。以前は真ん中の列に人件費と返済
    // だけを出し、収支からは運営費も引いていたので、収入−支出が収支と
    // 合わなかった(2026-11-23)。
    final expenses = gameState.annualExpenseForecast;
    final net = gameState.annualNetForecast;
    // 季末の資金の見込み: 今の資金に、残りの節のぶんの収支を足す。
    final uid = save.userTeamId;
    final played = save.league.fixtures
        .where((f) =>
            f.result != null && (f.homeTeamId == uid || f.awayTeamId == uid))
        .length;
    final left = (md - played).clamp(0, md);
    final seasonEnd =
        save.budget + (md <= 0 ? 0 : (net * left / md).round());
    return Card(
      key: const ValueKey('finance-year-money'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文章ではなく、数字を3つ大きく並べる。資金の額は上の段に出て
            // いるので、ここには出さない(横画面では埋め込みのため。2026-11-21)。
            if (!EmbeddedInShell.of(context))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  Tr.pick('資金: ${formatMoney(save.budget)}',
                      'Funds: ${formatMoney(save.budget)}'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            TitleWithHelp(
              title: Tr.pick('今年のお金(見込み)', "This year's money (forecast)"),
              style: Theme.of(context).textTheme.titleSmall,
              help: Tr.pick(
                  '収入は観客動員・スポンサー・グッズ・放映権を合わせた額、支出は人件費(選手とスタッフの年俸)・施設の運営費・融資の返済です。\n\n給与は毎月末に年俸の12分の1(${formatMoney(gameState.monthlyPlayerWageCost + gameState.monthlyStaffWageCost)})を払い、放映権は年4回(8/1・11/1・2/1・5/1)に入ります。ここの額は、いまの1節あたりの額を1季の節の数($md節)だけ積んだ1年の見込みです。季末の資金は、今の資金に残りの$left節ぶんの収支を足した見込みです。',
                  'Income is gate, sponsorship, merchandise and broadcasting together. Spending is wages (players and staff), the running costs of your facilities and any loan repayments.\n\nWages are paid at the end of each month, one twelfth of the annual bill (${formatMoney(gameState.monthlyPlayerWageCost + gameState.monthlyStaffWageCost)}). Broadcast money arrives four times a year (1 Aug, 1 Nov, 1 Feb, 1 May). The figures here are the current per-matchday amounts times the $md matchdays of a season. Funds at season end adds the balance of the $left matchdays left to what you have now.'),
            ),
            // 列の頭をそろえ、列の間をあける。英語では3つの金額がくっついて
            // 1つの数に見えていた(2026-11-23)。
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BigFigure(
                  label: Tr.pick('収入', 'Income'),
                  value: '+${formatMoney(income)}',
                ),
                _BigFigure(
                  key: const ValueKey('finance-expenses'),
                  label: hasLoan
                      ? Tr.pick('人件費・運営費・返済', 'Wages, costs & loan')
                      : Tr.pick('人件費・運営費', 'Wages & costs'),
                  value: '-${formatMoney(expenses)}',
                ),
                _BigFigure(
                  label: Tr.pick('収支', 'Balance'),
                  value: '${net >= 0 ? '+' : ''}${formatMoney(net)}',
                  color: net >= 0
                      ? SemanticColors.positive(context)
                      : SemanticColors.negative(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CashFlowBar(income: income, expenses: expenses),
            const SizedBox(height: 8),
            Text(
              Tr.pick('季末の資金(見込み): ${formatMoney(seasonEnd)}',
                  'Funds at season end (forecast): ${formatMoney(seasonEnd)}'),
              key: const ValueKey('finance-season-end'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: seasonEnd < 0 ? SemanticColors.negative(context) : null,
              ),
            ),
            const SizedBox(height: 8),
            // 理事会が設定する給与予算。上限を超える新規獲得はブロックされる
            // ため、残り枠を常に確認できるようにする。超えていれば状況の
            // 必須の「やること」にも出る(2026-11-25 の第7段)。
            Builder(builder: (context) {
              final cap = gameState.wageBudgetCap;
              final usage =
                  cap > 0 ? (weeklyBill / cap).clamp(0.0, 1.0) : 0.0;
              final over = weeklyBill > cap;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.pick(
                        '給与予算(理事会設定・年額): ${formatMoney(annualFromWeekly(weeklyBill))} / ${formatMoney(annualFromWeekly(cap))}${over ? '(超過中: 新規獲得は不可)' : ''}',
                        "Wage budget set by the board (a year): ${formatMoney(annualFromWeekly(weeklyBill))} / ${formatMoney(annualFromWeekly(cap))}${over ? ' (over budget: no new signings)' : ''}"),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: over ? SemanticColors.negative(context) : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: usage,
                      minHeight: 6,
                      color: over ? SemanticColors.negative(context) : null,
                      // 暗い表示でほぼ白の帯が浮いていたので、テーマの色にする。
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 小さな見出しと大きな数字の1組(概要の「1週あたりのお金」)。
class _BigFigure extends StatelessWidget {
  const _BigFigure(
      {super.key, required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          // 列の間の余白。右端の列にも付くが、カードの内側なので目立たない。
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: SemanticColors.subtleText(context))),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),
        ),
      );
}

/// 週間収入と支出(人件費+融資返済)の比率を視覚化する内訳バー。
/// これから先のお金の予定(給与日・放映権の入金日・試合の日)。
class _MoneyCalendarCard extends StatelessWidget {
  const _MoneyCalendarCard();

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final items = gameState.upcomingMoneyDates();
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick('入出金の予定', 'Upcoming money dates'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text('${e.date.month}/${e.date.day}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child:
                          Text(e.label, style: const TextStyle(fontSize: 12)),
                    ),
                    Text(
                      formatMoneySigned(e.amount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: e.amount >= 0
                            ? SemanticColors.positive(context)
                            : SemanticColors.negative(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowBar extends StatelessWidget {
  final int income;
  final int expenses;

  const _CashFlowBar({required this.income, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final total = income + expenses;
    if (total <= 0) return const SizedBox.shrink();
    final incomeFlex = ((income / total) * 100).round().clamp(1, 99);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: incomeFlex,
              child: Container(color: SemanticColors.positive(context)),
            ),
            Expanded(
              flex: 100 - incomeFlex,
              child: Container(color: SemanticColors.negative(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 胸のスポンサー(契約中・提示・なし)。「スポンサー契約」の札の先頭に入る。
class _SponsorSection extends StatelessWidget {
  final GameState gameState;

  const _SponsorSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final deal = gameState.save!.sponsorDeal;
    final offers = gameState.pendingSponsorOffers;
    final md = gameState.matchdaysPerSeason;
    final head = Text(Tr.pick('胸', 'Shirt'),
        style: const TextStyle(fontWeight: FontWeight.bold));

    if (deal != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.handshake),
            title: Text(deal.name),
            subtitle:
                Text(ContractEngine.yearsShortLabel(deal.yearsRemaining)),
            trailing: Text(
              Tr.pick('+${formatMoney(deal.weeklyIncome * md)}/年',
                  '+${formatMoney(deal.weeklyIncome * md)} a year'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    if (offers.isEmpty) {
      return Text(Tr.pick('胸: 空き(次の季の始めに提示が来ます)',
          'Shirt: empty (offers come next season)'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Tr.pick('胸: 提示が${offers.length}件。1つ選んで結びます',
                'Shirt: ${Tr.plural(offers.length, 'offer')}. Pick one to sign'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        for (int i = 0; i < offers.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.handshake_outlined),
            title: Text(offers[i].name),
            subtitle: Text(
              Tr.pick(
                  '契約期間: ${ContractEngine.yearsShortLabel(offers[i].yearsRemaining)}',
                  'Length: ${ContractEngine.yearsShortLabel(offers[i].yearsRemaining)}'),
            ),
            trailing: FilledButton(
              onPressed: () => _choose(context, i),
              child: Text(Tr.pick(
                  '+${formatMoney(offers[i].weeklyIncome * md)}/年',
                  '+${formatMoney(offers[i].weeklyIncome * md)} a year')),
            ),
          ),
      ],
    );
  }

  Future<void> _choose(BuildContext context, int index) async {
    await gameState.chooseSponsor(index);
    FeedbackService.success();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.pick('スポンサー契約を結んだ', 'Sponsorship deal signed'))));
    }
  }
}

class _LoanSection extends StatelessWidget {
  final GameState gameState;

  const _LoanSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final loans = gameState.bankLoans;
    final maxAmount = gameState.maxLoanAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loans.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(Tr.pick('借入元本', 'Principal'),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
                      _LoanCell(Tr.pick('残り週', 'Weeks'), bold: true),
                      _LoanCell(Tr.pick('返済残額', 'To repay'), bold: true),
                      _LoanCell(Tr.pick('週返済', 'Weekly'), bold: true),
                    ],
                  ),
                  for (final loan in loans)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(formatMoney(loan.principal),
                                  style: const TextStyle(fontSize: 13))),
                          _LoanCell('${loan.weeksRemaining}'),
                          _LoanCell('${loan.totalRemaining}'),
                          _LoanCell('-${loan.weeklyRepayment}',
                              color: SemanticColors.negative(context)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: Text(Tr.pick('借入可能額: ${formatMoney(maxAmount)}',
                    'You can borrow up to ${formatMoney(maxAmount)}')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton(
                  onPressed:
                      maxAmount <= 0 ? null : () => _showLoanSheet(context),
                  child: Text(Tr.pick('融資を申し込む', 'Apply for a loan')),
                ),
              ),
              // 借りられる額が0のとき。枠は借入の残りを引いた額なので、
              // 返すと戻ることまで書く。
              if (maxAmount <= 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DisabledReason(
                    Tr.pick('いまは借りられる枠がありません。返済が進むと、また借りられます',
                        'You have no borrowing room right now. It comes back as you repay'),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLoanSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LoanRequestSheet(gameState: gameState),
    );
  }
}

class _LoanRequestSheet extends StatefulWidget {
  final GameState gameState;

  const _LoanRequestSheet({required this.gameState});

  @override
  State<_LoanRequestSheet> createState() => _LoanRequestSheetState();
}

class _LoanRequestSheetState extends State<_LoanRequestSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.gameState.maxLoanAmount.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.gameState.maxLoanAmount;
    final amount = int.tryParse(_controller.text)?.clamp(0, maxAmount) ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('融資を申し込む', 'Apply for a loan'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('借入可能額: ${formatMoney(maxAmount)}',
                  'You can borrow up to ${formatMoney(maxAmount)}'),
              style: TextStyle(
                  color: SemanticColors.subtleText(context), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: Tr.pick('借入額(万円)', 'Amount to borrow'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AmountNudger(
              controller: _controller,
              target: maxAmount,
              targetLabel: Tr.pick('上限まで', 'Maximum'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            for (final term in LoanEngine.terms)
              ListTile(
                leading: Icon(
                  term.weeks <= 12 ? Icons.speed : Icons.hourglass_bottom,
                ),
                title: Text(
                  Tr.pick(
                      '${term.label}（${term.weeks}週・年利${term.annualRatePercent.toStringAsFixed(1)}%）',
                      '${term.label} (${Tr.plural(term.weeks, 'week')}, ${term.annualRatePercent.toStringAsFixed(1)}% a year)'),
                ),
                subtitle: Text(
                  amount <= 0
                      ? Tr.pick('借入額を入力してください', 'Enter an amount to borrow')
                      : Tr.pick(
                          '週${formatMoney(LoanEngine.weeklyRepaymentFor(amount, term))} × ${term.weeks}週 = 返済総額${formatMoney(LoanEngine.totalRepaymentFor(amount, term))}',
                          '${formatMoney(LoanEngine.weeklyRepaymentFor(amount, term))} a week x ${Tr.plural(term.weeks, 'week')} = ${formatMoney(LoanEngine.totalRepaymentFor(amount, term))} repaid in total'),
                ),
                enabled: amount > 0,
                onTap:
                    amount <= 0 ? null : () => _confirm(context, amount, term),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, int amount, LoanTerm term) async {
    // シートを閉じる前にScaffoldMessengerを確保しておく。閉じた後のcontextで
    // 取得・mounted判定すると、閉じるアニメーションと非同期処理の完了が
    // 競合し、成否のフィードバックが表示されないことがあるため。
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final ok = await widget.gameState.takeLoan(amount, term);
    ok ? FeedbackService.success() : FeedbackService.error();
    messenger.showSnackBar(
      SnackBar(
          content: Text(ok
              ? Tr.pick('${formatMoney(amount)}を借り入れました',
                  'You borrowed ${formatMoney(amount)}')
              : Tr.pick('融資を申し込めませんでした', 'The loan was not approved'))),
    );
  }
}

class _InvestmentSection extends StatelessWidget {
  final GameState gameState;

  const _InvestmentSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final deposits = gameState.fixedDeposits;
    final available = gameState.save!.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final deposit in deposits)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.savings),
              title: Text(Tr.pick('預入元本 ${formatMoney(deposit.principal)}',
                  'Principal ${formatMoney(deposit.principal)}')),
              subtitle: Text(
                Tr.pick(
                    '残り${deposit.weeksRemaining}週 / 満期時+${formatMoney(deposit.interestEarned)}',
                    '${Tr.plural(deposit.weeksRemaining, 'week')} left / +${formatMoney(deposit.interestEarned)} at maturity'),
              ),
              trailing: Text(
                Tr.pick('満期${formatMoney(deposit.maturityValue)}',
                    'Matures at ${formatMoney(deposit.maturityValue)}'),
                style: TextStyle(color: SemanticColors.positive(context)),
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(Tr.pick('運用可能な資金: ${formatMoney(available)}',
                'Available to invest: ${formatMoney(available)}')),
            // 資金が0以下のときは預けられない。
            subtitle: available <= 0
                ? DisabledReason(
                    Tr.pick('預けられる資金がありません',
                        'You have no funds to deposit'),
                    padding: EdgeInsets.zero,
                  )
                : null,
            trailing: FilledButton(
              onPressed:
                  available <= 0 ? null : () => _showDepositSheet(context),
              child: Text(Tr.pick('定期預金を組む', 'Open a deposit')),
            ),
          ),
        ),
      ],
    );
  }

  void _showDepositSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DepositRequestSheet(gameState: gameState),
    );
  }
}

class _DepositRequestSheet extends StatefulWidget {
  final GameState gameState;

  const _DepositRequestSheet({required this.gameState});

  @override
  State<_DepositRequestSheet> createState() => _DepositRequestSheetState();
}

class _DepositRequestSheetState extends State<_DepositRequestSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.gameState.save!.budget.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.gameState.save!.budget;
    final amount = int.tryParse(_controller.text)?.clamp(0, maxAmount) ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('定期預金を組む', 'Open a deposit'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('運用可能な資金: ${formatMoney(maxAmount)}',
                  'Available to invest: ${formatMoney(maxAmount)}'),
              style: TextStyle(
                  color: SemanticColors.subtleText(context), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: Tr.pick('預入額(万円)', 'Amount to deposit'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AmountNudger(
              controller: _controller,
              target: maxAmount,
              targetLabel: Tr.pick('全額', 'All of it'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            for (final term in InvestmentEngine.terms)
              ListTile(
                leading: Icon(
                  term.weeks <= 12 ? Icons.speed : Icons.hourglass_bottom,
                ),
                title: Text(
                  Tr.pick(
                      '${term.label}（${term.weeks}週・年利${term.annualRatePercent.toStringAsFixed(1)}%）',
                      '${term.label} (${Tr.plural(term.weeks, 'week')}, ${term.annualRatePercent.toStringAsFixed(1)}% a year)'),
                ),
                subtitle: Text(
                  amount <= 0
                      ? Tr.pick('預入額を入力してください', 'Enter an amount to deposit')
                      : Tr.pick(
                          '満期時 ${formatMoney(InvestmentEngine.maturityValueFor(amount, term))}(利息+${formatMoney(InvestmentEngine.interestFor(amount, term))})',
                          'Matures at ${formatMoney(InvestmentEngine.maturityValueFor(amount, term))} (interest +${formatMoney(InvestmentEngine.interestFor(amount, term))})'),
                ),
                enabled: amount > 0,
                onTap:
                    amount <= 0 ? null : () => _confirm(context, amount, term),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    int amount,
    DepositTerm term,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final ok = await widget.gameState.openFixedDeposit(amount, term);
    ok ? FeedbackService.success() : FeedbackService.error();
    messenger.showSnackBar(
      SnackBar(
          content: Text(ok
              ? Tr.pick('${formatMoney(amount)}を預け入れました',
                  'You deposited ${formatMoney(amount)}')
              : Tr.pick('定期預金を組めませんでした', 'The deposit could not be opened'))),
    );
  }
}

/// 融資の表の1列(右寄せの数字)。
class _LoanCell extends StatelessWidget {
  const _LoanCell(this.text, {this.bold = false, this.color});

  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 68,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            text,
            style: TextStyle(
              fontSize: bold ? 11 : 12,
              fontWeight: bold ? FontWeight.bold : null,
              color: color,
            ),
          ),
        ),
      );
}
