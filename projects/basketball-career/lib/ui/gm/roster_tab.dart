import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'coaches_screen.dart';
import 'box_score.dart';
import 'common.dart';
import 'minutes_screen.dart';
import 'negotiate_dialog.dart';
import 'player_card.dart';
import 'policy_screen.dart';
import 'rotation_screen.dart';
import 'stats_screen.dart';
import 'style.dart';
import 'training_screen.dart';

/// チームのタブ。先発と控え、年俸。選手を押すと詳しく見て、放せる。
class RosterTab extends StatelessWidget {
  const RosterTab({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final me = car.me;
    final order = me.order;
    final rank = car.strengthRank(car.mine) + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                PlayerAvatar(team: car.mine, size: 52, pose: 'dunk'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(me.name, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Text('戦力 ${me.strength.toStringAsFixed(1)}(30チーム中$rank位)・${me.roster.length}人',
                        style: const TextStyle(color: GmColors.sub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              PayrollBar(payroll: me.payroll),
              const SizedBox(height: 6),
              Text(
                  '上限 ${money(salaryCap)}・ぜいたく税 ${money(taxLine)}から・第1の壁 ${money(firstApron)}・第2の壁 ${money(secondApron)}'
                  '${me.deadCap > 0 ? '\n放した選手の年俸 ${money(me.deadCap)}が今季の合計に残っている' : ''}${me.deadLater.any((x) => x > 0) ? '(来季以降にも${me.deadLater.length}年分が残る)' : ''}',
                  style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // チームの設定は2列の小さな札にまとめる(先発が1画面目に見えるように)
        LayoutBuilder(builder: (context, cons) {
          final w = (cons.maxWidth - 8) / 2;
          void go(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
          return Wrap(spacing: 8, runSpacing: 8, children: [
            _tile(w, Icons.swap_vert_rounded, '先発と控えの順', me.rotation.isEmpty ? 'いまは自動' : '自分で決めた順', () => go(RotationScreen(c: c))),
            _tile(w, Icons.timer_outlined, '出場時間', me.minutes.isEmpty ? 'いまは自動' : '自分で決めた時間', () => go(MinutesScreen(c: c))),
            _tile(w, Icons.badge_rounded, 'コーチ陣', 'HC ${me.coachOf(Staff.coach)?.name ?? coachLevelLabels[me.staffLevel(Staff.coach) - 1]}',
                () => go(CoachesScreen(c: c))),
            _tile(w, Icons.fitness_center_rounded, '練習', '強さ ${trainingLabels[me.training]}・重点 ${me.roster.where((p) => p.focus != null).length}人',
                () => go(TrainingScreen(c: c))),
            _tile(w, Icons.groups_rounded, 'チームの相性', '${me.chem}(強さ ${me.chemEffect >= 0 ? '+' : ''}${me.chemEffect.toStringAsFixed(1)})', () => _chemSheet(context, car)),
            _tile(w, Icons.tune_rounded, 'チームの方針', me.policy.every((x) => x == 1) ? 'いまは全部ふつう' : '強さ ${me.policyEffect >= 0 ? '+' : ''}${me.policyEffect.toStringAsFixed(1)}',
                () => go(PolicyScreen(c: c))),
            _tile(w, Icons.table_chart_rounded, 'チームの成績', 'シュート・スティールなど', () => go(StatsScreen(c: c))),
          ]);
        }),
        const SectionTitle('先発'),
        // PG・SG・SF・PF・C の順に。本来と違う位置で出る選手には、その位置を添える
        for (final (slot, p) in bySlot(order.take(5).toList())) _row(context, car, p, slot: slot),
        const SectionTitle('控え'),
        for (final p in order.skip(5)) _row(context, car, p),
        SectionTitle('2ウェイ契約(${me.twoWay.length}/$twoWayMax人)'),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
              '若手(リーグ$twoWayMaxExp年目まで)を、登録の$maxRoster人と年俸の合計に数えずに抱える契約。試合には出ないが、育って、登録に空きがあれば上げられる。年俸は${money(twoWaySalary)}。',
              style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
        ),
        if (me.twoWay.isEmpty) const Text('いない(補強の画面で、自由契約の若手から取れる)', style: TextStyle(fontSize: 12, color: GmColors.sub)),
        for (final p in me.twoWay) _twoWayRow(context, car, p),
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

  Widget _tile(double w, IconData icon, String title, String sub, VoidCallback onTap) => SizedBox(
        width: w,
        child: Material(
          color: GmColors.panel,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: GmColors.line)),
              child: Row(children: [
                Icon(icon, size: 20, color: GmColors.ball),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _row(BuildContext context, Career car, Player p, {Pos? slot}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: PlayerRow(
          p: p,
          team: car.mine,
          showDelta: true,
          showMorale: true,
          extra: slot != null && slot != p.pos
              ? Tag('${slot.short}で出る(本来は${p.pos.short})', color: GmColors.gold)
              : car.draftedIds.contains(p.id)
                  ? const Tag('生え抜き', color: GmColors.good)
                  : null,
          onTap: () => _detail(context, car, p),
        ),
      );

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
