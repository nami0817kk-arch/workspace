import 'package:flutter/material.dart';
import '../theme/semantic_colors.dart';

import '../l10n/tr.dart';
import '../logic/contract_engine.dart';
import '../logic/rating_words.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import 'player_stat_chips.dart';
import 'table_sort.dart';
import '../logic/economy_scale.dart';

/// 選手の一覧を、情報の密な表で見せる(Football Manager の選手画面に寄せる)。
///
/// 1行1人。位置・年齢・総合・伸びしろ・調子・疲れ/けが・年俸・満了・
/// 市場価値・今季の出場/得点/採点を並べる(2026-11-25 に列を増やした。
/// それまでは疲労・満了・年俸まで)。見出しを押すと並べ替え、行を押すと
/// 詳しい画面、右端の「…」で操作の一覧。
///
/// 今季の成績と調子は[stats]・[form]で渡す(表は GameState を読まない。
/// 試合の結果をなめるのは呼ぶ側で1回だけ)。
class SquadTable extends StatefulWidget {
  const SquadTable({
    super.key,
    required this.players,
    required this.startingIds,
    required this.onTap,
    this.stats = const {},
    this.form = const {},
    this.selectedIds = const {},
    this.onMenu,
  });

  final List<Player> players;
  final Set<String> startingIds;
  final void Function(Player) onTap;

  /// 今季のリーグ戦の成績(選手の id → 成績)。
  final Map<String, PlayerSeasonStats> stats;

  /// 調子(直近の採点の平均。出ていなければ null)。
  final Map<String, double?> form;

  /// 比較に選んでいる選手(行の色を変える)。
  final Set<String> selectedIds;

  /// 行の右端の「…」を押したとき(操作の一覧)。null なら「…」を出さない。
  final void Function(Player)? onMenu;

  @override
  State<SquadTable> createState() => _SquadTableState();
}

/// 表の1列。
class _Col {
  const _Col(this.key, this.label, this.width, {this.tip});

  /// 並べ替えの鍵(null なら並べ替えない)。
  final String? key;
  final String label;
  final double width;

  /// 見出しを長押ししたときの説明(略した見出しの元の言葉)。
  final String? tip;
}

/// 見出しを押すと並べ替える(TableSort)。
class _SquadTableState extends State<SquadTable> {
  String? _sortKey;
  bool _asc = true;

  void _sortBy(String k) => setState(() {
        if (_sortKey == k) {
          _asc = !_asc;
        } else {
          _sortKey = k;
          _asc = TableSort.startsAscending(k);
        }
      });

  PlayerSeasonStats _st(Player p) =>
      widget.stats[p.id] ?? const PlayerSeasonStats();

  /// 疲れ/けがの列の並べ替えの値(出られないほど大きい)。
  static int _conditionKey(Player p) => p.isInjured
      ? 1000 + p.injuryWeeks
      : (p.isSuspended ? 900 : (p.isOnInternationalDuty ? 800 : p.fatigue));

  int? _extraCmp(Player a, Player b, String key) => switch (key) {
        'form' => (widget.form[a.id] ?? 0).compareTo(widget.form[b.id] ?? 0),
        'cond' => _conditionKey(a).compareTo(_conditionKey(b)),
        'apps' => _st(a).appearances.compareTo(_st(b).appearances),
        'goals' => _st(a).goals.compareTo(_st(b).goals),
        'rating' =>
          (_st(a).averageRating ?? 0).compareTo(_st(b).averageRating ?? 0),
        'pot' => RatingWords.growthRoomLevel(a.overall, a.potential)
            .compareTo(RatingWords.growthRoomLevel(b.overall, b.potential)),
        _ => null,
      };

  List<Player> get players => TableSort.sort(widget.players, _sortKey, _asc,
      extra: _extraCmp);

  static const double _rowHeight = 34;

  /// 名前の列の最小の幅。表全体がこれより狭い画面では、横に送れるようにする。
  static const double _nameMin = 120;

  List<_Col> get _cols => [
        const _Col(null, '#', 22),
        _Col('pos', Tr.pick('位置', 'Pos'), 38),
        _Col('age', Tr.pick('年齢', 'Age'), 30),
        _Col('ovr', Tr.pick('総合', 'OVR'), 34),
        _Col('pot', Tr.pick('伸び', 'Pot'), 34,
            tip: Tr.pick('伸びしろ(見立て)', 'Room to grow (estimate)')),
        _Col('form', Tr.pick('調子', 'Form'), 44,
            tip: Tr.pick('調子(直近5試合の採点)', 'Form (last 5 ratings)')),
        _Col('cond', Tr.pick('疲れ', 'Fit'), 44,
            tip: Tr.pick('疲れ/けが・出場停止', 'Fatigue / injury / ban')),
        _Col('wage', Tr.pick('年俸', 'Salary'), 54),
        // 列の中身は満了の年(2030 なら 2030年6月まで)。「契約」だと
        // 年数に読めるので「満了」にする(2026-11-23)。
        _Col('term', Tr.pick('満了', 'Ends'), 36),
        _Col('fee', Tr.pick('価値', 'Value'), 54,
            tip: Tr.pick('市場価値', 'Market value')),
        _Col('apps', Tr.pick('出場', 'Apps'), 32,
            tip: Tr.pick('今季のリーグ戦の出場', 'League appearances this season')),
        _Col('goals', Tr.pick('得点', 'Gls'), 32,
            tip: Tr.pick('今季のリーグ戦の得点', 'League goals this season')),
        _Col('rating', Tr.pick('採点', 'Rat'), 34,
            tip: Tr.pick('今季の平均採点', 'Average rating this season')),
      ];

  @override
  Widget build(BuildContext context) {
    final cols = _cols;
    final menuWidth = widget.onMenu == null ? 0.0 : 32.0;
    final fixed =
        cols.fold<double>(0, (s, c) => s + c.width) + menuWidth + 16;
    return LayoutBuilder(builder: (context, c) {
      final fits = c.maxWidth >= fixed + _nameMin;
      final nameWidth = fits ? c.maxWidth - fixed : _nameMin;
      final table = SizedBox(
        width: fixed + nameWidth,
        child: Column(
          children: [
            _header(context, cols, nameWidth, menuWidth),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemExtent: _rowHeight,
                itemBuilder: (context, i) =>
                    _row(context, players[i], i, nameWidth, menuWidth),
              ),
            ),
          ],
        ),
      );
      if (fits) return table;
      // 狭い画面(英語の見出し・文字を大きくしたとき)は横に送る。
      return SingleChildScrollView(
          scrollDirection: Axis.horizontal, child: table);
    });
  }

  Widget _header(BuildContext context, List<_Col> cols, double nameWidth,
      double menuWidth) {
    final scheme = Theme.of(context).colorScheme;
    final headStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: scheme.onSurfaceVariant,
    );
    Widget head(String s,
        {required double width,
        TextAlign align = TextAlign.center,
        String? key,
        String? tip}) {
      final cell = TableSort.header(
        key: key,
        onSort: _sortBy,
        child: SizedBox(
          width: width,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align == TextAlign.left
                ? Alignment.centerLeft
                : Alignment.center,
            child: Text(TableSort.label(s, key, _sortKey, _asc),
                style: headStyle, textAlign: align, maxLines: 1),
          ),
        ),
      );
      return tip == null ? cell : Tooltip(message: tip, child: cell);
    }

    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          head('#', width: cols.first.width),
          head(Tr.pick('名前', 'Name'),
              width: nameWidth, align: TextAlign.left, key: 'name'),
          for (final c in cols.skip(1))
            head(c.label, width: c.width, key: c.key, tip: c.tip),
          if (menuWidth > 0) SizedBox(width: menuWidth),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Player p, int index, double nameWidth,
      double menuWidth) {
    final scheme = Theme.of(context).colorScheme;
    final unavailable = p.isInjured ||
        p.isSuspended ||
        p.isOnInternationalDuty ||
        p.isLoanedOut ||
        p.notRegistered;
    final expiring = !p.isLoan && p.contractYearsRemaining <= 1;
    final starting = widget.startingIds.contains(p.id);
    final selected = widget.selectedIds.contains(p.id);
    const small = TextStyle(fontSize: 12);
    final base = unavailable ? scheme.error : null;
    final subtle = SemanticColors.subtleText(context);
    final st = _st(p);

    Widget cell(double width, String text,
            {Color? color,
            Key? key,
            Alignment align = Alignment.center,
            FontWeight? weight}) =>
        SizedBox(
          width: width,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align,
            child: Text(text,
                key: key,
                maxLines: 1,
                textAlign: align == Alignment.centerRight
                    ? TextAlign.right
                    : TextAlign.center,
                style: small.copyWith(color: color ?? base, fontWeight: weight)),
          ),
        );

    // 疲れ/けがの列: 出られない理由があればそれ、なければ疲労の数字。
    final (condText, condColor) = p.isInjured
        ? (Tr.pick('負傷${p.injuryWeeks}週', 'Inj ${p.injuryWeeks}w'), scheme.error)
        : p.isSuspended
            ? (Tr.pick('停止', 'Ban'), scheme.error)
            : p.isLoanedOut
                ? (Tr.pick('貸出', 'Away'), subtle)
                : p.isOnInternationalDuty
                    ? (Tr.pick('代表', 'Intl'), scheme.error)
                    : (
                        '${p.fatigue}',
                        p.fatigue >= 70 ? scheme.error : null,
                      );
    final formLevel = RatingWords.formLevel(widget.form[p.id]);
    final formColor = switch (formLevel) {
      null => subtle,
      3 => SemanticColors.ink(context, Colors.green),
      2 => SemanticColors.ink(context, Colors.green),
      1 => null,
      _ => scheme.error,
    };
    final potLevel = RatingWords.growthRoomLevel(p.overall, p.potential);

    return InkWell(
      onTap: () => widget.onTap(p),
      onLongPress: widget.onMenu == null ? null : () => widget.onMenu!(p),
      child: Container(
        color: selected
            ? scheme.secondaryContainer
            : starting
                ? scheme.primaryContainer.withValues(alpha: 0.35)
                : (index.isOdd
                    ? scheme.surfaceContainerLow
                    : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(p.squadNumber == null ? '' : '${p.squadNumber}',
                  textAlign: TextAlign.center,
                  style: small.copyWith(color: scheme.onSurfaceVariant)),
            ),
            SizedBox(
              width: nameWidth,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: small.copyWith(
                          fontWeight: FontWeight.w700, color: base),
                    ),
                  ),
                  // 移籍リストの印。縦画面の一覧(squad_screen)と同じ。
                  if (p.isTransferListed) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: Tr.pick('移籍リストに登録済み', 'On the transfer list'),
                      child: Icon(
                        Icons.sell_outlined,
                        key: const ValueKey('squad-table-listed'),
                        size: 14,
                        color: SemanticColors.ink(context, Colors.orange),
                      ),
                    ),
                  ],
                  if (p.isLoan) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: Tr.pick('ローンで加入中', 'On loan here'),
                      child: Icon(Icons.swap_horiz,
                          size: 14,
                          color: SemanticColors.ink(context, Colors.indigo)),
                    ),
                  ],
                  if (p.wantsTransfer) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: Tr.pick('移籍を希望している', 'Wants a move away'),
                      child: Icon(Icons.sentiment_dissatisfied,
                          size: 14,
                          color: SemanticColors.ink(context, Colors.redAccent)),
                    ),
                  ],
                ],
              ),
            ),
            cell(38, p.position.label),
            cell(30, '${p.age}'),
            SizedBox(
                width: 34,
                child: Center(child: OverallBadge(overall: p.overall))),
            cell(34, RatingWords.growthRoomShort(p.overall, p.potential),
                color: potLevel >= 3
                    ? SemanticColors.ink(context, Colors.green)
                    : (potLevel == 0 ? subtle : null)),
            cell(44, RatingWords.form(widget.form[p.id]), color: formColor),
            cell(44, condText, color: condColor),
            cell(54, formatMoney(annualFromWeekly(p.wage)),
                align: Alignment.centerRight),
            cell(
              36,
              p.isLoan
                  ? Tr.pick('借', 'Loan')
                  : ContractEngine.untilTinyLabel(p.contractEndYear),
              key: ValueKey('squad-table-term-${p.id}'),
              color: expiring
                  ? SemanticColors.ink(context, Colors.orange)
                  : null,
            ),
            cell(54, formatMoney(p.marketValue), align: Alignment.centerRight),
            cell(32, '${st.appearances}',
                color: st.appearances == 0 ? subtle : null),
            cell(32, '${st.goals}', color: st.goals == 0 ? subtle : null),
            cell(34, st.averageRating?.toStringAsFixed(1) ?? '—',
                color: st.averageRating == null ? subtle : null,
                weight: FontWeight.w600),
            if (menuWidth > 0)
              SizedBox(
                width: menuWidth,
                child: IconButton(
                  key: ValueKey('squad-table-menu-${p.id}'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: Tr.pick('操作', 'Actions'),
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => widget.onMenu!(p),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
