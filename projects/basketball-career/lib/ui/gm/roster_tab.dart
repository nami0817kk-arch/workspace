import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'coaches_screen.dart';
import 'box_score.dart';
import 'common.dart';
import 'gm_table.dart';
import 'player_face.dart';
import 'minutes_screen.dart';
import 'negotiate_dialog.dart';
import 'player_card.dart';
import 'policy_screen.dart';
import 'rotation_screen.dart';
import 'stats_screen.dart';
import 'style.dart';
import 'training_screen.dart';

/// 選手の並べ方。
enum RosterSort {
  lineup('先発の順'),
  ovr('力'),
  salary('年俸'),
  years('残り年数'),
  morale('気持ち'),
  age('年齢');

  const RosterSort(this.label);
  final String label;
}

/// チームのタブ。先発と控え、年俸。選手を押すと詳しく見て、放せる。
class RosterTab extends StatefulWidget {
  const RosterTab({super.key, required this.c});
  final GmController c;

  @override
  State<RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends State<RosterTab> {
  GmController get c => widget.c;
  RosterSort _sort = RosterSort.lineup;

  List<Player> _sorted(List<Player> list) {
    final out = [...list];
    switch (_sort) {
      case RosterSort.lineup:
        break;
      case RosterSort.ovr:
        out.sort((a, b) => b.ovr.compareTo(a.ovr));
      case RosterSort.salary:
        out.sort((a, b) => b.salary.compareTo(a.salary));
      case RosterSort.years:
        out.sort((a, b) => a.years.compareTo(b.years));
      case RosterSort.morale:
        out.sort((a, b) => a.morale.compareTo(b.morale));
      case RosterSort.age:
        out.sort((a, b) => a.age.compareTo(b.age));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final me = car.me;
    final order = me.order;
    final rank = car.strengthRank(car.mine) + 1;
    void go(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    // 左: チームの要点と設定。右: 選手の表(2026-11-14、詰めた表に)
    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            TeamBadge(team: car.mine, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('戦力 ${me.strength.toStringAsFixed(1)}・$rank位・${me.roster.length}人', style: const TextStyle(fontSize: 11, color: GmColors.sub)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          PayrollBar(payroll: me.payroll, compact: true),
          const SizedBox(height: 4),
          Text(
              '上限 ${money(salaryCap)}・税 ${money(taxLine)}・第1の壁 ${money(firstApron)}・第2の壁 ${money(secondApron)}'
              '${me.deadCap > 0 ? '\n放した選手の年俸 ${money(me.deadCap)}が今季に残る' : ''}${me.deadLater.any((x) => x > 0) ? '(来季以降も${me.deadLater.length}年分)' : ''}',
              style: const TextStyle(fontSize: 10, color: GmColors.sub, height: 1.4)),
        ]),
      ),
      const SizedBox(height: 6),
      _tile(Icons.swap_vert_rounded, '先発と控えの順', me.rotation.isEmpty ? 'いまは自動' : '自分で決めた順', () => go(RotationScreen(c: c))),
      _tile(Icons.timer_outlined, '出場時間', me.minutes.isEmpty ? 'いまは自動' : '自分で決めた時間', () => go(MinutesScreen(c: c))),
      _tile(Icons.badge_rounded, 'コーチ陣', 'HC ${me.coachOf(Staff.coach)?.name ?? coachLevelLabels[me.staffLevel(Staff.coach) - 1]}', () => go(CoachesScreen(c: c))),
      _tile(Icons.fitness_center_rounded, '練習', '強さ ${trainingLabels[me.training]}・重点 ${me.roster.where((p) => p.focus != null).length}人', () => go(TrainingScreen(c: c))),
      _tile(Icons.groups_rounded, 'チームの相性', '${me.chem}(強さ ${me.chemEffect >= 0 ? '+' : ''}${me.chemEffect.toStringAsFixed(1)})', () => _chemSheet(context, car)),
      _tile(Icons.tune_rounded, 'チームの方針', me.policy.every((x) => x == 1) ? 'いまは全部ふつう' : '強さ ${me.policyEffect >= 0 ? '+' : ''}${me.policyEffect.toStringAsFixed(1)}', () => go(PolicyScreen(c: c))),
      _tile(Icons.table_chart_rounded, 'チームの成績', 'シュート・スティールなど', () => go(StatsScreen(c: c))),
    ]);
    final lineup = _sort == RosterSort.lineup;
    final starters = lineup ? bySlot(order.take(5).toList()) : <(Pos, Player)>[];
    final rows = <(Pos?, Player)>[
      if (lineup) ...[for (final x in starters) (x.$1, x.$2), for (final p in order.skip(5)) (null, p)] else for (final p in _sorted(order)) (null, p),
    ];
    final table = _rosterTable(context, car, rows, lineup ? 5 : -1);
    final twoWay = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      if (me.twoWay.isEmpty)
        Text('2ウェイ契約(0/$twoWayMax人): いない。若手(リーグ$twoWayMaxExp年目まで)を登録と年俸の合計に数えずに抱えられる(補強の画面で取れる)。',
            style: const TextStyle(fontSize: 11, color: GmColors.sub))
      else ...[
        SectionTitle('2ウェイ契約(${me.twoWay.length}/$twoWayMax人)'),
        for (final p in me.twoWay) _twoWayRow(context, car, p),
      ],
    ]);
    return LayoutBuilder(builder: (context, cons) {
      final wide = cons.maxWidth >= 720;
      return ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
        children: [
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 216, child: side),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [table, twoWay])),
            ])
          else ...[
            side,
            const SizedBox(height: 8),
            table,
            twoWay,
          ],
        ],
      );
    });
  }

  /// 選手の表。[split] 行目の前に先発と控えの区切り(-1 なら区切らない)。見出しを押すと並べ替え。
  Widget _rosterTable(BuildContext context, Career car, List<(Pos?, Player)> rows, int split) {
    GmCol col(String label, RosterSort? sort, {double? width, int flex = 1, TextAlign align = TextAlign.center}) => GmCol(label,
        width: width,
        flex: flex,
        align: align,
        sorted: sort != null && _sort == sort,
        onTap: sort == null ? null : () => setState(() => _sort = _sort == sort ? RosterSort.lineup : sort));
    String one(double v) => v.toStringAsFixed(1);
    return GmTable(
      title: _sort == RosterSort.lineup ? '先発と控え' : '全員(${_sort.label}の順)',
      trailing: const Text('見出しで並べ替え・選手を押すと詳しく', style: TextStyle(fontSize: 10, color: GmColors.sub)),
      cols: [
        col('位置', RosterSort.lineup, width: 34),
        col('選手', null, flex: 6, align: TextAlign.left),
        col('歳', RosterSort.age, width: 26),
        col('OVR', RosterSort.ovr, width: 40),
        col('伸', null, width: 22),
        col('点', null, width: 36),
        col('リ', null, width: 34),
        col('ア', null, width: 32),
        col('分', null, width: 30),
        col('年俸', RosterSort.salary, width: 74, align: TextAlign.right),
        col('残', RosterSort.years, width: 24),
        col('気', RosterSort.morale, width: 24),
      ],
      rows: [
        for (final (i, (slot, p)) in rows.indexed)
          () {
            final s = p.stats.gp > 0 ? p.stats : p.prev;
            final last = p.stats.gp == 0 && p.prev.gp > 0;
            final grade = p.grade;
            final d = shownDelta(p.ovr, p.lastDelta);
            final off = slot != null && slot != p.pos;
            return GmRow(
              [
                numCell(slot == null ? (split >= 0 ? '控' : p.pos.short) : slot.short, bold: slot != null, color: off ? GmColors.gold : slot != null ? GmColors.text : GmColors.sub),
                Row(children: [
                  PlayerFace(p: p, team: car.mine, size: 20),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, color: p.injured > 0 ? GmColors.bad : null)),
                  ),
                  const SizedBox(width: 4),
                  Text(p.pos.short, style: const TextStyle(fontSize: 9.5, color: GmColors.sub)),
                  for (final (txt, color) in _marks(car, p, slot))
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Text(txt, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
                    ),
                ]),
                numCell('${p.age}'),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  numCell('${shown(p.ovr)}', bold: true, color: GmColors.ovr(p.ovr)),
                  if (d != 0) Text(d > 0 ? '+$d' : '$d', style: TextStyle(fontSize: 9, color: d > 0 ? GmColors.good : GmColors.bad)),
                ]),
                numCell(grade == '-' ? '' : grade, color: grade == 'S' || grade == 'A' ? GmColors.gold : GmColors.sub),
                numCell(s.gp == 0 ? '-' : one(s.ppg), color: last ? GmColors.sub : null),
                numCell(s.gp == 0 ? '-' : one(s.rpg), color: last ? GmColors.sub : null),
                numCell(s.gp == 0 ? '-' : one(s.apg), color: last ? GmColors.sub : null),
                numCell(s.gp == 0 ? '-' : s.mpg.round().toString(), color: last ? GmColors.sub : null),
                numCell(money(p.salary)),
                numCell(p.years <= 0 ? '切' : '${p.years}', color: p.years == 1 ? GmColors.gold : null),
                MoraleIcon(p: p, size: 14),
              ],
              divider: i == split,
              dim: p.injured > 0,
              onTap: () => _detail(context, car, p),
            );
          }(),
      ],
    );
  }

  /// 相性の中身(何で上がり下がりするか)。
  void _chemSheet(BuildContext context, Career car) {
    final f = car.chemFactors;
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('チームの相性 ${car.me.chem}'),
        content: Text(
            '選手どうしの相性。50がふつうで、強さに足される。仲が良くても少し(最大 +0.2)だが、悪いと大きく下がる(最大 -1.5)。区切りごとに目標へ寄っていく。\n\n'
            '・今のチームに1年以上いる主力 ${(f.continuity * 100).round()}%(新しい選手が多いと下がる)\n'
            '・気持ちが高い主力 ${f.happy}人(多いと上がる)\n'
            '・不満を持つ主力 ${f.unhappy}人(1人ごとに下がる)\n'
            '・勝ち(勝率が高いと上がる)\n\n'
            '自由契約の選手が、このチームを選びやすいかにも効く。',
            style: const TextStyle(height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('閉じる'))],
      ),
    );
  }

  Widget _twoWayRow(BuildContext context, Career car, Player p) {
    final problem = car.promoteProblem(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PlayerRow(
        p: p,
        team: car.mine,
        showDelta: true,
        salaryText: '2ウェイ ${money(p.salary)}(残り${p.years}年)',
        extra: Wrap(spacing: 8, children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: problem != null || c.busy ? null : () => c.promoteTwoWay(p.id),
            child: Text(problem ?? '登録に上げる(${money(minSalary)}・2年)', style: const TextStyle(fontSize: 12)),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 6), foregroundColor: GmColors.bad),
            onPressed: c.busy ? null : () => c.waiveTwoWay(p.id),
            child: const Text('放す', style: TextStyle(fontSize: 12)),
          ),
        ]),
        onTap: () => _detail(context, car, p),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: GmColors.panel,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.line)),
              child: Row(children: [
                Icon(icon, size: 16, color: GmColors.ball),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, color: GmColors.sub))),
                const Icon(Icons.chevron_right_rounded, size: 16, color: GmColors.sub),
              ]),
            ),
          ),
        ),
      );

  /// 選手の印(けが・不満・今季で契約切れ・トレードブロック・生え抜き)を短い字で。
  List<(String, Color)> _marks(Career car, Player p, Pos? slot) => [
        if (p.injured > 0) ('負傷${p.injured}', GmColors.bad),
        if (p.morale < 20) ('不満', GmColors.bad) else if (p.morale < 45) ('不満ぎみ', GmColors.gold),
        if (p.years == 1 && car.phase != Phase.contracts) ('今季まで', GmColors.gold),
        if (car.tradeBlock.contains(p.id)) ('ブロック', GmColors.ball),
        if (p.wear >= wearRestLine && p.injured == 0) ('疲れ${p.wear}', p.wear > wearSlumpLine ? GmColors.bad : GmColors.gold),
        if (car.restIds.contains(p.id)) ('休ませる', GmColors.sub),
        if (car.draftedIds.contains(p.id)) ('生え抜き', GmColors.good),
      ];

  Future<void> _detail(BuildContext context, Career car, Player p) => showGmSheet<void>(
        context,
        builder: (ctx) {
          final canRelease = !car.expiring.contains(p.id) &&
              (car.phase == Phase.preseason || car.phase == Phase.season || car.phase == Phase.contracts);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PlayerCardHeader(p: p, team: car.mine),
                RatingsPanel(p: p),
                const SizedBox(height: 10),
                // シーズン前とオフは、今季の成績がまだ前のシーズンのもの
                if (p.stats.gp > 0) _line(car.seasonStarted ? '今季' : '昨季', '${p.stats.line}(${p.stats.gp}試合)'),
                if (p.stats.fga > 0)
                  _line('シュート', 'FG ${(p.stats.fgPct * 100).toStringAsFixed(1)}%・3P ${p.stats.tpa == 0 ? '-' : '${(p.stats.tpPct * 100).toStringAsFixed(1)}%'}・FT ${p.stats.fta == 0 ? '-' : '${(p.stats.ftPct * 100).toStringAsFixed(1)}%'}'),
                if (p.prev.gp > 0) _line(car.seasonStarted ? '昨季' : '2季前', '${p.prev.line}(${p.prev.gp}試合)'),
                if (awardsSummary(car, p).isNotEmpty) _line('表彰', awardsSummary(car, p)),
                if (p.allStars > 0) _line('オールスター', '${p.allStars}回'),
                _line('気持ち', '${p.moraleLabel}(${p.morale})'),
                if (car.me.roster.contains(p) && (p.wear > 0 || car.restIds.contains(p.id)))
                  _line('疲れ', '${p.wear}(${p.wear > wearSlumpLine ? 'シュートが落ちている' : p.wear >= wearRestLine ? 'けがしやすい' : 'ふつう'})${car.restIds.contains(p.id) ? '・疲れたら休ませる(今季${p.restGames}試合)' : ''}'),
                _line('年俸', '${money(p.salary)}(残り${p.years}年)'),
                _line('力に見合う年俸', money(fairSalary(p.ovr, p.age))),
                _line('伸びしろ', switch (p.grade) {
                  'S' => 'S(大きく伸びる見込み)',
                  'A' => 'A(まだ伸びる)',
                  'B' => 'B(少し伸びる)',
                  'C' => 'C(あまり伸びない)',
                  _ => p.age >= 30 ? 'なし(これから落ちていく)' : 'なし',
                }),
                if (p.drafted != null) _line('ドラフト', p.drafted!),
                RecentGames(car: car, p: p),
                if (p.career.isNotEmpty) CareerTable(p: p),
                const SizedBox(height: 14),
                if (car.extendProblem(p) == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await negotiateExtension(context, c, p);
                      },
                      icon: const Icon(Icons.edit_document),
                      label: const Text('契約の延長を申し出る'),
                    ),
                  )
                else if (p.years == 1 && car.me.roster.contains(p))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('延長: ${car.extendProblem(p)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                  ),
                if (p.nextSalary != null) _line('延長', '来季から${money(p.nextSalary!)}(残り${p.years}年)'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final on = car.tradeBlock.contains(p.id);
                      c.toggleTradeBlock(p.id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(on ? '${p.name}をトレードブロックから外した' : '${p.name}をトレードブロックに載せた。申し込みが届きやすくなる(本人の気持ちは少し下がる)')));
                    },
                    icon: Icon(car.tradeBlock.contains(p.id) ? Icons.remove_circle_outline_rounded : Icons.campaign_rounded),
                    label: Text(car.tradeBlock.contains(p.id) ? 'トレードブロックから外す' : 'トレードブロックに載せる'),
                  ),
                ),
                if (car.me.roster.contains(p))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final on = car.restIds.contains(p.id);
                        c.toggleRest(p.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(on ? '${p.name}は疲れても出し続ける' : '${p.name}は、疲れが$wearRestLineに届いたら次の試合を休ませる(その試合はチームが少し弱くなる)')));
                      },
                      icon: Icon(car.restIds.contains(p.id) ? Icons.directions_run_rounded : Icons.battery_charging_full_rounded),
                      label: Text(car.restIds.contains(p.id) ? '疲れても出し続ける' : '疲れたら休ませる'),
                    ),
                  ),
                if (car.me.roster.contains(p) && car.toTwoWayProblem(p) == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        c.toTwoWay(p.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name}を2ウェイ契約に下げた(登録に1人空く)')));
                      },
                      icon: const Icon(Icons.south_rounded),
                      label: const Text('2ウェイ契約に下げる'),
                    ),
                  ),
                if (canRelease && car.me.roster.contains(p))
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: GmColors.bad),
                    onPressed: () async {
                      final mode = await showDialog<ReleaseMode>(
                        context: ctx,
                        builder: (d) => SimpleDialog(
                          title: Text('${p.name}を放す(年俸 ${money(p.salary)}・残り${p.years}年)'),
                          children: [
                            for (final m in ReleaseMode.values)
                              if (car.releaseProblem(p, m) == null)
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(d, m),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(m.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                        '${m.text}\n今季 ${money(car.releaseCost(p, m).now)}・来季以降 合計 ${money(car.releaseCost(p, m).later.fold(0, (a, b) => a + b))}',
                                        style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                                  ]),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                  child: Text('${m.label}: ${car.releaseProblem(p, m)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                                ),
                            SimpleDialogOption(onPressed: () => Navigator.pop(d), child: const Text('やめる')),
                          ],
                        ),
                      );
                      if (mode != null) {
                        c.release(p.id, mode: mode);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('この選手を放す'),
                  ),
              ]),
            ),
          );
        },
      );

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: GmColors.sub))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
      );
}
