import 'package:flutter/material.dart';
import '../logic/transfer_window.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../logic/investment_engine.dart';
import '../logic/loan_engine.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/budget_plan_card.dart';
import '../widgets/ledger_card.dart';
import '../widgets/economy_card.dart';
import '../widgets/club_policy_card.dart';
import '../widgets/advisor_card.dart';
import '../widgets/club_ranking_card.dart';
import '../widgets/club_timeline_card.dart';
import '../widgets/club_value_card.dart';
import '../widgets/auto_columns.dart';
import '../widgets/trend_chart.dart';
import '../widgets/projection_card.dart';
import '../widgets/owner_career_card.dart';
import '../widgets/club_culture_card.dart';
import '../widgets/rival_owners_card.dart';
import '../widgets/owner_wealth_card.dart';
import '../widgets/equity_card.dart';
import '../widgets/media_deals_card.dart';
import '../widgets/project_card.dart';
import '../widgets/proposal_card.dart';
import '../widgets/risk_card.dart';
import '../widgets/rival_card.dart';
import '../widgets/rules_card.dart';
import '../widgets/reward_funds_card.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';
import '../l10n/tr.dart';
import '../widgets/screen_bar.dart';
import '../widgets/sponsor_slots_card.dart';
import '../logic/economy_scale.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, this.embedded = false});

  /// 下タブの一員として表示するか。true なら戻るボタンを出さない。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final team = gameState.userTeam;
    final income = gameState.weeklyIncomeFor(team.id);
    // 毎節払う人件費(年俸を節の数で割った額)。給与の枠は週俸の合計で見る。
    final wageBill =
        gameState.matchdayPlayerWageCost + gameState.matchdayStaffWageCost;
    final weeklyBill = gameState.weeklyWageBill;
    final loanRepayment = gameState.bankLoans.fold<int>(
      0,
      (s, l) => s + l.weeklyRepayment,
    );
    final net = income - wageBill - loanRepayment;

    final sortedByExpiry = team.players.where((p) => !p.isLoan).toList()
      ..sort(
        (a, b) => a.contractYearsRemaining.compareTo(b.contractYearsRemaining),
      );
    final loanPlayers = team.players.where((p) => p.isLoan).toList();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
      appBar: screenBar(
        context,
        title: Tr.pick('クラブ経営', 'Club finances'),
        leading: embedded ? null : const BackButton(),
        actions: const [QuickAccessMenuButton()],
        scrollable: true,
        tabs: [
          Tr.pick('概要', 'Overview'),
          Tr.pick('収支・契約', 'Accounts'),
          Tr.pick('資金・取引', 'Funding'),
          Tr.pick('投資・規則', 'Projects'),
          Tr.pick('記録', 'Records'),
        ],
      ),
      drawer: const QuickAccessDrawer(),
      body: TabBarView(
        children: [
          ResponsiveBody(
            // 広い画面(iPad の横向きなど)では2列に並べる。
            child: AutoColumns(
              children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Tr.pick('資金: ${formatMoney(save.budget)}', 'Funds: ${formatMoney(save.budget)}'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(Tr.pick('週間収入: +${formatMoney(income)}（観客動員・スポンサー・グッズ・放映権込み）',
                              'Weekly income: +${formatMoney(income)} (gate, sponsorship, merchandise and broadcasting)')),
                          Text(Tr.pick('週間人件費: -${formatMoney(wageBill)}（年俸を節の数で割った額・スタッフ込み）',
                              'Weekly wages: -${formatMoney(wageBill)} (annual salaries spread over the matchdays, staff included)')),
                          Text(
                            Tr.pick(
                                '給与は毎月末に年俸の12分の1(${formatMoney(gameState.monthlyPlayerWageCost + gameState.monthlyStaffWageCost)})を払い、放映権は年4回(8/1・11/1・2/1・5/1)に入ります。上の週の額は1節あたりに直した目安です。',
                                'Wages are paid at the end of each month, one twelfth of the annual bill (${formatMoney(gameState.monthlyPlayerWageCost + gameState.monthlyStaffWageCost)}). Broadcast money arrives four times a year (1 Aug, 1 Nov, 1 Feb, 1 May). The weekly figures above are per-matchday averages.'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (loanRepayment > 0)
                            Text(Tr.pick('週間融資返済: -${formatMoney(loanRepayment)}',
                                'Weekly loan repayment: -${formatMoney(loanRepayment)}')),
                          const SizedBox(height: 8),
                          _CashFlowBar(
                            income: income,
                            expenses: wageBill + loanRepayment,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Tr.pick('週間収支: ${net >= 0 ? '+' : ''}${formatMoney(net)}',
                                "Weekly balance: ${net >= 0 ? '+' : ''}${formatMoney(net)}"),
                            style: TextStyle(
                              color: net >= 0
                                  ? SemanticColors.positive(context)
                                  : SemanticColors.negative(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 理事会が設定する週給予算。上限を超える新規獲得は
                          // ブロックされるため、残り枠を常に確認できるようにする。
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
                                    color: over
                                        ? SemanticColors.negative(context)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: usage,
                                    minHeight: 6,
                                    color: over
                                        ? SemanticColors.negative(context)
                                        : null,
                                    backgroundColor: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const _MoneyCalendarCard(),
                  const ProposalCard(),
                  const RewardFundsCard(),
                  const BudgetPlanCard(),

              ],
            ),
          ),
          ResponsiveBody(
            // 広い画面(iPad の横向きなど)では2列に並べる。
            child: AutoColumns(
              children: [
                  const LedgerCard(),
                  const ProjectionCard(),
                  const TrendsCard(),
                  if (save.pendingInstallments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(Tr.pick('分割払い残金', 'Instalments outstanding'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final inst in save.pendingInstallments)
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          onTap: inst.playerId == null
                              ? null
                              : () => _openPlayer(context, inst.playerId!),
                          title: Text(inst.description),
                          subtitle: Text(Tr.pick('残り${inst.weeksRemaining}週',
                              '${Tr.plural(inst.weeksRemaining, 'week')} left')),
                          trailing: Text(Tr.pick('-${formatMoney(inst.weeklyAmount)}/週',
                              '-${formatMoney(inst.weeklyAmount)} per week')),
                        ),
                      ),
                  ],
                  if (loanPlayers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(Tr.pick('ローン加入中の選手', 'Players on loan at your club'),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final p in loanPlayers)
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          onTap: () => _openPlayer(context, p.id),
                          title: Text(p.name),
                          subtitle: Text(Tr.pick(
                              '${p.position.label} / 年俸 ${formatMoney(annualFromWeekly(p.wage))}',
                              '${p.position.label} / salary ${formatMoney(annualFromWeekly(p.wage))}')),
                          trailing: Text(p.loanEndDate != null
                              ? Tr.pick(
                                  '${TransferWindowCalendar.formatMonthDay(p.loanEndDate!)}まで',
                                  'until ${TransferWindowCalendar.formatMonthDay(p.loanEndDate!)}')
                              : Tr.pick('残り${p.loanWeeksRemaining}週',
                                  '${Tr.plural(p.loanWeeksRemaining, 'week')} left')),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    Tr.pick('契約状況（残り年数が少ない順）', 'Contracts, shortest remaining first'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final (i, p) in sortedByExpiry.indexed)
                  InkWell(
                    onTap: () => _openPlayer(context, p.id),
                    child: Container(
                      height: 40,
                      color: i.isOdd
                          ? Theme.of(context).colorScheme.surfaceContainerLow
                          : null,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(p.position.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                                formatMoney(annualFromWeekly(p.wage)),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              ContractEngine.untilShortLabel(
                                  p.contractEndYear),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.contractYearsRemaining <= 1
                                    ? SemanticColors.negative(context)
                                    : null,
                                fontWeight: p.contractYearsRemaining <= 1
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ResponsiveBody(
            // 広い画面(iPad の横向きなど)では2列に並べる。
            child: AutoColumns(
              children: [
                  const SizedBox(height: 16),
                  Text(Tr.pick('資金調達（銀行融資）', 'Raise money (bank loan)'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _LoanSection(gameState: gameState),
                  const SizedBox(height: 16),
                  Text(Tr.pick('資金運用（定期預金）', 'Invest (fixed deposit)'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _InvestmentSection(gameState: gameState),
                  const SizedBox(height: 16),
                  Text(Tr.pick('スポンサー契約', 'Sponsorship'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SponsorSection(gameState: gameState),
                  const SponsorSlotsCard(),
                  const EquityCard(),
                  const OwnerWealthCard(),
                  const FiveYearPlanCard(),
                  const ClubCultureCard(),
                  const OwnerCareerCard(),
                  const RivalOwnersCard(),
                  const MediaDealsCard(),

              ],
            ),
          ),
          ResponsiveBody(
            // 広い画面(iPad の横向きなど)では2列に並べる。
            child: AutoColumns(
              children: [
                  const RulesCard(),
                  const ClubPolicyCard(),
                  const EconomyCard(),
                  const ProjectCard(),
                  const AdvisorCard(),
                  const RiskCard(),

              ],
            ),
          ),
          ResponsiveBody(
            // 広い画面(iPad の横向きなど)では2列に並べる。
            child: AutoColumns(
              children: [
                  const ClubValueCard(),
                  const ClubRankingCard(),
                  const RivalCard(),
                  const ClubTimelineCard(),

              ],
            ),
          ),
        ],
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
                      child: Text(e.label, style: const TextStyle(fontSize: 12)),
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

class _SponsorSection extends StatelessWidget {
  final GameState gameState;

  const _SponsorSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final deal = gameState.save!.sponsorDeal;
    final offers = gameState.pendingSponsorOffers;

    if (deal != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.handshake),
          title: Text(deal.name),
          subtitle: Text(ContractEngine.yearsShortLabel(deal.yearsRemaining)),
          trailing: Text(
            Tr.pick(
                '+${formatMoney(deal.weeklyIncome)}/週', '+${formatMoney(deal.weeklyIncome)} per week'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (offers.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_empty),
          title: Text(Tr.pick('現在スポンサーはついていません', 'You have no sponsor')),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Tr.pick('週間収入が高いほど契約期間は短くなる。契約する候補を選んでください。',
                  'The more it pays weekly, the shorter the deal. Choose which offer to take.'),
              style: TextStyle(
                  fontSize: 12, color: SemanticColors.subtleText(context)),
            ),
          ),
        ),
        for (int i = 0; i < offers.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: Text(offers[i].name),
              subtitle: Text(
                Tr.pick(
                    '契約期間: ${ContractEngine.yearsShortLabel(offers[i].yearsRemaining)}',
                    'Length: ${ContractEngine.yearsShortLabel(offers[i].yearsRemaining)}'),
              ),
              trailing: FilledButton(
                onPressed: () => _choose(context, i),
                child: Text(Tr.pick('+${formatMoney(offers[i].weeklyIncome)}/週',
                    '+${formatMoney(offers[i].weeklyIncome)} per week')),
              ),
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
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
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
                title: Text(Tr.pick(
                    '借入可能額: ${formatMoney(maxAmount)}', 'You can borrow up to ${formatMoney(maxAmount)}')),
                subtitle: Text(Tr.pick('スタジアムの規模・オーナーの評判が高いほど上限が上がる',
                    'A bigger stadium and a better reputation raise the ceiling')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton(
                  onPressed:
                      maxAmount <= 0 ? null : () => _showLoanSheet(context),
                  child: Text(Tr.pick('融資を申し込む', 'Apply for a loan')),
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
              Tr.pick('借入可能額: ${formatMoney(maxAmount)}', 'You can borrow up to ${formatMoney(maxAmount)}'),
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
            const SizedBox(height: 12),
            for (final term in LoanEngine.terms)
              ListTile(
                leading: Icon(
                  term.weeks <= 12 ? Icons.speed : Icons.hourglass_bottom,
                ),
                title: Text(
                  Tr.pick(
                      '${term.label}（${term.weeks}週・利率${term.interestRatePercent.toStringAsFixed(0)}%）',
                      '${term.label} (${Tr.plural(term.weeks, 'week')}, ${term.interestRatePercent.toStringAsFixed(0)}% interest)'),
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
              ? Tr.pick('${formatMoney(amount)}を借り入れました', 'You borrowed ${formatMoney(amount)}')
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
            title: Text(Tr.pick(
                '運用可能な資金: ${formatMoney(available)}', 'Available to invest: ${formatMoney(available)}')),
            subtitle: Text(Tr.pick('満期まで引き出せない代わりに、満期時にまとまった利息を受け取れる',
                'Locked away until it matures, and pays a lump of interest when it does')),
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
              Tr.pick(
                  '運用可能な資金: ${formatMoney(maxAmount)}', 'Available to invest: ${formatMoney(maxAmount)}'),
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
            const SizedBox(height: 12),
            for (final term in InvestmentEngine.terms)
              ListTile(
                leading: Icon(
                  term.weeks <= 12 ? Icons.speed : Icons.hourglass_bottom,
                ),
                title: Text(
                  Tr.pick(
                      '${term.label}（${term.weeks}週・利回り${term.interestRatePercent.toStringAsFixed(0)}%）',
                      '${term.label} (${Tr.plural(term.weeks, 'week')}, ${term.interestRatePercent.toStringAsFixed(0)}% return)'),
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
              ? Tr.pick('${formatMoney(amount)}を預け入れました', 'You deposited ${formatMoney(amount)}')
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
