import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'negotiate_dialog.dart';
import 'offseason_show_screen.dart';
import 'style.dart';

/// 自由契約の選手の並べ方。
enum _FaSort { ovr, salary, age }

/// 補強のタブ。自由契約の選手と契約する。
class MarketTab extends StatefulWidget {
  const MarketTab({super.key, required this.c});
  final GmController c;

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  GmController get c => widget.c;
  Pos? _pos;
  bool _onlyAvailable = false;
  _FaSort _sort = _FaSort.ovr;

  /// いま取れる(契約・申し込み・2ウェイ・10日契約のどれかができる)か。
  bool _available(Career car, Player p) {
    if (car.isBigFa(p)) return car.bidProblem(p) == null;
    if (car.signProblem(p) == null) return true;
    if (p.exp <= twoWayMaxExp && car.canSign && car.twoWayProblem(p) == null) return true;
    return car.phase == Phase.season && car.tenDayProblem(p) == null;
  }

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final askCache = <int, int>{};
    int askOf(Player p) => askCache.putIfAbsent(p.id, () => car.askOf(p, car.me).salary);
    final fa = [
      for (final p in car.freeAgents)
        if ((_pos == null || p.pos == _pos) && (!_onlyAvailable || _available(car, p))) p,
    ]..sort(switch (_sort) {
        _FaSort.ovr => (a, b) => b.ovr.compareTo(a.ovr),
        _FaSort.salary => (a, b) => askOf(a).compareTo(askOf(b)),
        _FaSort.age => (a, b) => a.age.compareTo(b.age),
      });
    final (maxOffer, maxFrom) = car.maxOfferNow;
    final note = switch (car.phase) {
      Phase.contracts => '大物(最低年俸より高く求める選手)は、ほかのチームと競り合う。申し込むと、日が進むたびに行き先を決める。'
          '最低年俸(${money(minSalary)})の選手は、上限を超えていてもすぐ取れる。',
      Phase.preseason => '年俸の上限まで空きがあれば、誰とでも契約できる。最低年俸(${money(minSalary)})の選手は、上限を超えていても取れる。',
      Phase.season => 'シーズン中は、最低年俸の選手だけ取れる。',
      _ => '今は契約できない(シーズン前・シーズン中・オフの契約で取れる)。',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('自由契約の選手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(note, style: const TextStyle(color: GmColors.sub, height: 1.5)),
              const SizedBox(height: 10),
              PayrollBar(payroll: car.me.payroll),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'いま出せる年俸: ', style: TextStyle(color: GmColors.sub)),
                    TextSpan(text: '最大 ${money(maxOffer)}', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.gold, fontSize: 15)),
                    TextSpan(text: '($maxFrom)', style: const TextStyle(color: GmColors.sub, fontSize: 12)),
                  ])),
                ),
                IconButton(
                  tooltip: '例外枠の決まり',
                  icon: const Icon(Icons.info_outline_rounded, size: 20, color: GmColors.sub),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('例外枠'),
                      content: Text(
                          '年俸の上限を超えていても、例外枠を使えば自由契約の選手を取れる。\n\n'
                          '・中くらい: ${money(mleSalary)}まで(1年に1回)${car.mleUsed ? '…今年は使用済み' : ''}\n'
                          '・課税者用: ${money(taxMleSalary)}まで(第1の壁 ${money(firstApron)} を超えるとき)\n'
                          '・2年ごと: ${money(biennialSalary)}まで${car.biennialReady ? '' : '…去年使った'}\n\n'
                          '第2の壁(${money(secondApron)})を超えると、どれも使えない。最低年俸(${money(minSalary)})の選手はいつでも取れる。',
                          style: const TextStyle(height: 1.5)),
                      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('閉じる'))],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('登録 ${car.me.roster.length - car.expiring.length}人 / $maxRoster人・2ウェイ ${car.me.twoWay.length}人 / $twoWayMax人', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              if (car.phase == Phase.contracts) ...[
                const Divider(height: 20),
                Row(children: [
                  Expanded(
                    child: Text(car.faDay < faDays ? '自由契約 ${car.faDay + 1}日目 / $faDays日' : '自由契約の日程は終わった',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball)),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: car.faDay >= faDays || c.busy ? null : () => nextFaDayWithReport(context, c),
                    icon: const Icon(Icons.wb_sunny_rounded, size: 18),
                    label: const Text('次の日へ'),
                  ),
                ]),
                if (car.faDay < faDays)
                  const Text('オフを終えると、残りの日は自動で進む。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
              ],
            ]),
          ),
        ),
        if (car.phase == Phase.contracts && car.faLog.isNotEmpty) ...[
          const SectionTitle('このオフの移籍'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final n in car.faLog.take(8)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(n, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 8),
        // 絞り込みと並べ替え
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final p in <Pos?>[null, ...Pos.values])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(p == null ? '全員' : p.short, style: const TextStyle(fontSize: 12)),
                  selected: _pos == p,
                  onSelected: (_) => setState(() => _pos = p),
                ),
              ),
            const SizedBox(width: 6),
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: const Text('いま取れる選手だけ', style: TextStyle(fontSize: 12)),
              selected: _onlyAvailable,
              onSelected: (v) => setState(() => _onlyAvailable = v),
            ),
            const SizedBox(width: 10),
            for (final (s, label) in const [(_FaSort.ovr, '力の順'), (_FaSort.salary, '安い順'), (_FaSort.age, '若い順')])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: _sort == s,
                  onSelected: (_) => setState(() => _sort = s),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        if (fa.isEmpty) const Text('いない', style: TextStyle(color: GmColors.sub)),
        for (final p in fa) ...[
          _row(context, car, p),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Career car, Player p) {
    final ask = car.askOf(p, car.me);
    if (car.isBigFa(p)) return _bigRow(context, car, p, ask);
    final problem = car.signProblem(p);
    return PlayerRow(
      p: p,
      team: car.mine,
      salaryText: '求める年俸 ${money(ask.salary)}',
      trailing: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: problem != null || c.busy
              ? null
              : () => negotiate(context, c, p, freeAgent: true),
          child: const Text('契約'),
        ),
      ),
      extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (problem != null && car.canSign) Text(problem, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
        _twoWayButton(car, p),
        _tenDayButton(car, p),
      ]),
    );
  }

  /// シーズン中、最低年俸の選手を5試合だけ取る(日割りの年俸・2回まで)。
  Widget _tenDayButton(Career car, Player p) {
    if (car.phase != Phase.season) return const SizedBox.shrink();
    final problem = car.tenDayProblem(p);
    if (problem != null && !problem.contains('2回まで')) return const SizedBox.shrink();
    return TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
      onPressed: problem != null || c.busy ? null : () => c.signTenDay(p.id),
      child: Text(problem ?? '10日契約で取る($tenDayRounds試合・${money(tenDaySalary)})', style: const TextStyle(fontSize: 12)),
    );
  }

  /// 若手には「2ウェイで」の札を出す(登録の人数に数えない)。
  Widget _twoWayButton(Career car, Player p) {
    if (p.exp > twoWayMaxExp || !car.canSign) return const SizedBox.shrink();
    final problem = car.twoWayProblem(p);
    return TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
      onPressed: problem != null || c.busy ? null : () => c.signTwoWay(p.id),
      child: Text(problem ?? '2ウェイで取る(${money(twoWaySalary)}・登録に数えない)', style: const TextStyle(fontSize: 12)),
    );
  }

  /// 大物の行。関心・ほかの申し込み・自分の申し込みを見せる。
  Widget _bigRow(BuildContext context, Career car, Player p, Ask ask) {
    final mine = car.myBid(p.id);
    final problem = car.bidProblem(p);
    final rivals = car.rivalBids(p.id);
    return PlayerRow(
      p: p,
      team: car.mine,
      salaryText: '求める年俸 ${money(ask.salary)}(最長${ask.maxYears}年)',
      trailing: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
          onPressed: (problem != null && mine == null) || c.busy ? null : () => negotiateBid(context, c, p),
          child: Text(mine == null ? '申し込む' : '変える'),
        ),
      ),
      extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('関心 ${interestLabel(car.interest(p, car.mine))}・重く見る ${car.faPriority(p)}・ほかの申し込み ${rivals == 0 ? 'なし' : '$rivalsチーム'}',
            style: TextStyle(fontSize: 12, color: rivals > 0 ? GmColors.gold : GmColors.sub)),
        _twoWayButton(car, p),
        if (mine != null) ...[
          Text('申し込み中 ${mine.years}年 ${money(mine.salary)}・選ばれる見込み ${(car.winChanceOf(p) * 100).round()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.good)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: c.busy ? null : () => c.withdrawBid(p.id),
            child: const Text('申し込みを取り下げる', style: TextStyle(fontSize: 12)),
          ),
        ] else if (problem != null && car.faDay < faDays)
          Text(problem, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
      ]),
    );
  }
}
