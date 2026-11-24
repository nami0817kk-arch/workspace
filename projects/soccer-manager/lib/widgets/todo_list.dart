import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../logic/first_days_guide.dart';
import '../logic/todo_advisor.dart';
import '../screens/todo_navigation.dart';
import '../state/game_state.dart';
import 'fm_panel.dart';

/// 「やること」の一覧を、下の画面に渡す。
///
/// シェル(MainShell)が状態の変わるたびに1回だけ作って渡す。左メニューの印・
/// タブの印・進むボタン・状況の一覧が、同じ一覧を見る。
class TodoScope extends InheritedWidget {
  const TodoScope({super.key, required this.items, required super.child});

  final List<TodoItem> items;

  /// いまの「やること」。シェルの外(重ねて開いた画面・単体のテスト)では、
  /// その場で作る。
  static List<TodoItem> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TodoScope>()?.items ??
      TodoAdvisor.build(context.watch<GameState>());

  @override
  bool updateShouldNotify(TodoScope oldWidget) => true;
}

/// 件数の印。必須は赤い数字、おすすめだけなら青い点。どちらも無ければ何も
/// 出さない。色だけに頼らないよう、形も変えてある(数字と点)。
class TodoMark extends StatelessWidget {
  const TodoMark({
    super.key,
    required this.must,
    required this.recommended,
    this.onPrimary = false,
  });

  final int must;
  final int recommended;

  /// 主役の色で塗った地(選んでいる左メニューの項目)の上に置くか。青い点が
  /// 地に溶けるので、色を入れ替える。
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (must > 0) {
      return Semantics(
        label: Tr.pick('必ず決めること $must件', '$must to decide'),
        child: Container(
          key: const ValueKey('todo-mark-must'),
          constraints: const BoxConstraints(minWidth: 16),
          height: 16,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExcludeSemantics(
            child: Text(
              must > 99 ? '99+' : '$must',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.bold,
                color: scheme.onError,
              ),
            ),
          ),
        ),
      );
    }
    if (recommended > 0) {
      return Semantics(
        label: Tr.pick('おすすめ $recommended件', '$recommended suggested'),
        child: Container(
          key: const ValueKey('todo-mark-recommended'),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: onPrimary ? scheme.onPrimary : scheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// [menu](と [tab])の印を、いまの「やること」から作る。無ければ null。
Widget? todoMarkFor(BuildContext context, TodoMenu menu,
    {int? tab, bool onPrimary = false}) {
  final items = TodoScope.of(context);
  final must = items.mustAt(menu, tab);
  final rec = items.recommendedAt(menu, tab);
  if (must == 0 && rec == 0) return null;
  return TodoMark(must: must, recommended: rec, onPrimary: onPrimary);
}

/// タブの帯に付ける印の一覧([count] 個。無いタブは null)。
List<Widget?> todoTabMarks(BuildContext context, TodoMenu menu, int count) =>
    [for (var i = 0; i < count; i++) todoMarkFor(context, menu, tab: i)];

IconData todoIcon(TodoKind kind) => switch (kind) {
      TodoKind.ultimatum => Icons.campaign,
      TodoKind.rolloverShortfall => Icons.savings_outlined,
      TodoKind.budgetNegative => Icons.money_off,
      TodoKind.ruleBreach => Icons.gavel_outlined,
      TodoKind.wageBudgetOver => Icons.payments_outlined,
      TodoKind.supporterFalling => Icons.trending_down,
      TodoKind.boardReview => Icons.gavel,
      TodoKind.ownerEvent => Icons.report_gmailerrorred,
      TodoKind.agmDemand => Icons.groups_2_outlined,
      TodoKind.rumor => Icons.mic_none,
      TodoKind.surgery => Icons.healing,
      TodoKind.incomingOffers => Icons.mark_email_unread_outlined,
      TodoKind.sponsor => Icons.handshake_outlined,
      TodoKind.youthIntake => Icons.emoji_people,
      TodoKind.preseasonTour => Icons.flight_takeoff,
      TodoKind.counterOffers => Icons.reply,
      TodoKind.agreedTalks => Icons.draw_outlined,
      TodoKind.staffOffers => Icons.person_remove_outlined,
      TodoKind.firstSteps => Icons.school_outlined,
      TodoKind.transferDeadline => Icons.timer_outlined,
      TodoKind.staffVacant => Icons.person_add_alt,
      TodoKind.ownerGoal => Icons.flag_outlined,
      TodoKind.seasonTickets => Icons.confirmation_number_outlined,
      TodoKind.clubPolicy => Icons.tune,
      TodoKind.budgetPlan => Icons.pie_chart_outline,
      TodoKind.managerProposals => Icons.assignment_outlined,
      TodoKind.signingProposals => Icons.person_search_outlined,
      TodoKind.sponsorSlots => Icons.sell_outlined,
      TodoKind.youthAtRisk => Icons.directions_walk,
      TodoKind.contractRenewals => Icons.description_outlined,
      TodoKind.monthlyPr => Icons.record_voice_over_outlined,
      TodoKind.matchdayEvent => Icons.celebration_outlined,
      TodoKind.preContracts => Icons.edit_calendar_outlined,
      TodoKind.facilities => Icons.construction,
      TodoKind.ownerWorks => Icons.work_outline,
    };

/// 状況の右の欄の見出し。「やること 必須2・おすすめ3」。
class TodoHeader extends StatelessWidget {
  const TodoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final items = TodoScope.of(context);
    final must = items.mustCount;
    final rec = items.recommendedCount;
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (must > 0 && rec > 0) {
      text = Tr.pick(
          'やること  必須$must・おすすめ$rec', 'To do  $must to decide, $rec suggested');
    } else if (must > 0) {
      text = Tr.pick('やること  必須$must', 'To do  $must to decide');
    } else if (rec > 0) {
      text = Tr.pick('やること  おすすめ$rec', 'To do  $rec suggested');
    } else {
      text = Tr.pick('やること', 'To do');
    }
    return Padding(
      key: const ValueKey('todo-header'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.checklist, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 必須のうち、行き先へ行って片付けるもの(1行ずつ)。その場で答える札は
/// 状況の画面がこの下に並べる。
class TodoMustRows extends StatelessWidget {
  const TodoMustRows({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final t in TodoScope.of(context))
        if (t.isMust && !t.inline) t,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [for (final t in rows) TodoRow(item: t)],
    );
  }
}

/// おすすめの一覧。多いときは上の数件だけ出し、残りは「ほか N件」でたたむ。
///
/// 何も無いとき(必須もおすすめも0)は、進むボタンで進めばよいことを1行で。
class TodoRecommendedList extends StatefulWidget {
  const TodoRecommendedList({super.key});

  /// たたんだときに出す行の数。
  static const int foldAt = 3;

  @override
  State<TodoRecommendedList> createState() => _TodoRecommendedListState();
}

class _TodoRecommendedListState extends State<TodoRecommendedList> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final items = TodoScope.of(context);
    final rec = items.recommended.toList();
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Padding(
        key: const ValueKey('todo-empty'),
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          Tr.pick('いま決めることはありません。進むボタンで次へ進めます。',
              'Nothing needs you right now. Use the advance button to move on.'),
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }
    if (rec.isEmpty) return const SizedBox(height: 4);
    const fold = TodoRecommendedList.foldAt;
    // 1件だけを隠すくらいなら、そのまま出す。
    final folded = !_open && rec.length > fold + 1;
    final shown = folded ? rec.take(fold).toList() : rec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.mustCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
            child: Text(
              Tr.pick('おすすめ(やれば得)', 'Suggested (worth doing)'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final t in shown) TodoRow(item: t),
        if (rec.length > fold + 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('todo-more'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
              label: Text(_open
                  ? Tr.pick('たたむ', 'Show fewer')
                  : Tr.pick(
                      'ほか ${rec.length - fold}件', '${rec.length - fold} more')),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// 「やること」の1行。印・題・一言・「›」。行全体を押すと行き先へ移る。
class TodoRow extends StatelessWidget {
  const TodoRow({super.key, required this.item});

  final TodoItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = item.isMust ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        key: ValueKey('todo-${item.id}'),
        color: Color.alphaBlend(
            accent.withValues(alpha: item.isMust ? 0.10 : 0.05),
            scheme.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(fmRadius(context, 12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // 最初の数日の案内は、押したら次の段に替える。
            if (item.kind == TodoKind.firstSteps && item.tag != null) {
              FirstDaysGuide.markSeen(context.read<GameState>(), item.tag!);
            }
            openTodoPlace(context, item.place);
          },
          child: ConstrainedBox(
            // 横画面は全体を約0.93倍で描く。52 なら実寸で48pt を超える。
            constraints: const BoxConstraints(minHeight: 52),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // 左の柱。必須かおすすめかを色で出す。
                  Container(width: 4, color: accent),
                  const SizedBox(width: 10),
                  Icon(todoIcon(item.kind), size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          if (item.note.isNotEmpty)
                            Text(
                              item.note,
                              // 必須は読み切れるように長めに出す。おすすめは
                              // 1行(状況を開いたときに上位が見えるように。
                              // 2026-11-25)。
                              maxLines: item.isMust ? 4 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
