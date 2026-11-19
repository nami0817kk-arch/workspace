import 'package:flutter/material.dart';
import '../art/title_art.dart';

import '../../gm/career.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'style.dart';

/// 契約の交渉。年数を選び、求める額・1割安く・1割高くのどれかで申し出る。
/// 1割安くは受けてくれるとは限らない(断られると気持ちが下がり、このオフはもう値切れない)。
Future<void> negotiate(BuildContext context, GmController c, Player p, {required bool freeAgent}) async {
  final car = c.career!;
  final ask = car.askOf(p, car.me);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showDialog<(int, double)>(
    context: context,
    builder: (ctx) => _NegotiateDialog(car: car, p: p, ask: ask, freeAgent: freeAgent),
  );
  if (picked == null) {
    car.partialNext = false; // やめたら、一部保証のスイッチは持ち越さない
    c.touch(); // 代理人との往復は残す
    return;
  }
  final (years, rawFactor) = picked;
  // 代理人とまとまった額は、求める額に掛ける数を負の数で受け取る
  final agreed = rawFactor < 0;
  final factor = rawFactor.abs();
  final ok = c.offer(p.id, years, factor, agreed: agreed);
  messenger.showSnackBar(
    SnackBar(
      content: Row(children: [
        if (ok) ...[const EventArt('assets/art/event_signing.jpg', width: 64, height: 36), const SizedBox(width: 10)],
        Expanded(
          child: Text(
        ok
            ? '${p.name}と$years年 ${money(p.salary)}で契約した'
            : factor < 1 && !agreed
            ? '${p.name}は値下げを断った(気持ちが下がった)'
            : '契約できなかった(年俸の上限を確かめる)',
          ),
        ),
      ]),
    ),
  );
}

/// 大物に申し込む(オフの自由契約)。返事は日が進むと来る。
Future<void> negotiateBid(BuildContext context, GmController c, Player p) async {
  final car = c.career!;
  final ask = car.askOf(p, car.me);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showDialog<(int, double)>(
    context: context,
    builder: (ctx) => _NegotiateDialog(car: car, p: p, ask: ask, freeAgent: true, bid: true),
  );
  if (picked == null) return;
  final (years, factor) = picked;
  final problem = car.bidProblem(p, factor: factor);
  final ok = problem == null && c.bid(p.id, years, factor);
  messenger.showSnackBar(SnackBar(content: Text(ok ? '${p.name}に申し込んだ。日を進めると返事が来る' : problem ?? '申し込めなかった')));
}

/// 契約の延長を申し出る(残り1年の選手)。来季からの年俸と、足す年数を決める。
Future<void> negotiateExtension(BuildContext context, GmController c, Player p) async {
  final car = c.career!;
  final ask = car.extensionAsk(p);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showDialog<(int, double)>(
    context: context,
    builder: (ctx) => _NegotiateDialog(car: car, p: p, ask: ask, freeAgent: false, extension: true),
  );
  if (picked == null) return;
  final (years, factor) = picked;
  final ok = c.extend(p.id, years, factor);
  messenger.showSnackBar(SnackBar(content: Text(ok ? '${p.name}と$years年延長した(来季から${money(p.nextSalary ?? ask.salary)})' : '${p.name}は延長を断った(今季はもう申し出られない)')));
}

/// 関心の段階の言葉。
String interestLabel(int v) => v >= 70
    ? '高い($v)'
    : v >= 45
    ? 'ふつう($v)'
    : '低い($v)';

class _NegotiateDialog extends StatefulWidget {
  const _NegotiateDialog({required this.car, required this.p, required this.ask, required this.freeAgent, this.extension = false, this.bid = false});
  final Career car;
  final Player p;
  final Ask ask;
  final bool freeAgent;

  /// 契約の延長(年数は今の契約のあとに足す。値下げは延長でも一度だけ)。
  final bool extension;

  /// 大物への申し込み(すぐには決まらない。高いほど選ばれやすい)。
  final bool bid;

  @override
  State<_NegotiateDialog> createState() => _NegotiateDialogState();
}

class _NegotiateDialogState extends State<_NegotiateDialog> {
  bool _partial = false;
  late int _years = (widget.bid ? widget.car.myBid(widget.p.id)?.years : null) ?? widget.ask.maxYears.clamp(1, 3);

  @override
  Widget build(BuildContext context) {
    final car = widget.car, p = widget.p, ask = widget.ask;
    final rounds = car.haggleRounds(p.id);
    final canHaggle = (widget.extension ? !car.extAsked.contains(p.id) : rounds < car.haggleLimit) && ask.salary > minSalary;
    final chance = ((car.discountChance(p, freeAgent: widget.freeAgent) - (widget.extension ? 0 : 0.1 * rounds)).clamp(0.05, 0.85) * 100).round();
    int at(double f) => (ask.salary * f).round().clamp(minSalary, maxSalary);
    return AlertDialog(
      title: Text(
        widget.bid
            ? '${p.name}に申し込む'
            : widget.extension
            ? '${p.name}と延長の交渉'
            : '${p.name}と交渉',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.extension ? '来季から' : ''}求める年俸 ${money(ask.salary)}・最長${ask.maxYears}年・気持ち ${p.moraleLabel}',
              style: const TextStyle(color: GmColors.sub),
            ),
            if (widget.bid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '関心 ${interestLabel(car.interest(p, car.mine))}・ほかの申し込み ${car.rivalBids(p.id)}チーム。'
                  '代理人の話では、いちばん重く見るのは「${car.faPriority(p)}」'
                  '(${switch (car.faPriority(p)) {
                    '年俸の額' => '額を上げると大きく効く',
                    '勝てるチーム' => '昨季の勝率が大きく効く',
                    _ => '前のチームに残りたがる',
                  }})。'
                  '日が進むたびに、いちばん良い申し込みを選ぶことがある。',
                  style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4),
                ),
              ),
            if (widget.extension)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('年数は、今の契約(残り1年)のあとに足す。求める額でも断られることがある。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
              ),
            const SizedBox(height: 10),
            const Text('年数', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (var y = 1; y <= ask.maxYears; y++) ChoiceChip(label: Text('$y年'), selected: _years == y, onSelected: (_) => setState(() => _years = y)),
              ],
            ),
            if (!widget.bid && !widget.extension && car.partialOk(p, _years))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('一部保証にする', style: TextStyle(fontSize: 13)),
                subtitle: const Text('2年目以降の年俸は半分だけ保証(放しても半分しか残らない)。選手は年俸+8%を求める。', style: TextStyle(fontSize: 11, color: GmColors.sub)),
                value: _partial,
                onChanged: (v) => setState(() {
                  _partial = v;
                  widget.car.partialNext = v;
                }),
              ),
            const SizedBox(height: 12),
            if (widget.bid) ...[
              _option(context, '1割高く', '${money(at(1.1))}・選ばれやすい', 1.1),
              _option(context, '求める額で', money(ask.salary), 1.0),
              _option(context, '1割安く', '${money(at(0.9))}・選ばれにくい', 0.9),
            ] else ...[
              _option(context, '求める額で', '${money(ask.salary)}・${widget.extension ? 'たいてい受ける' : '必ず受ける'}', 1.0),
              _option(context, '1割高く', '${money(at(1.1))}・気持ちが上がる', 1.1),
              if (!widget.extension && ask.salary > minSalary)
                _AgentTalk(car: car, p: p, years: _years, ask: ask.salary)
              else if (canHaggle)
                _option(context, '1割安く', '${money(at(0.9))}・受ける見込み$chance%${widget.extension ? '' : '(あと${car.haggleLimit - rounds}回)'}', 0.9)
              else
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('値下げは、もう申し出られない', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                ),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('やめる'))],
    );
  }

  Widget _option(BuildContext context, String label, String sub, double factor) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft),
      onPressed: () => Navigator.pop(context, (_years, factor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
        ],
      ),
    ),
  );
}

/// 代理人と額を往復する(求める額より安く結ぶ)。まとまったら、ダイアログを (年数, -掛ける数) で閉じる。
class _AgentTalk extends StatefulWidget {
  const _AgentTalk({required this.car, required this.p, required this.years, required this.ask});
  final Career car;
  final Player p;
  final int years, ask;

  @override
  State<_AgentTalk> createState() => _AgentTalkState();
}

class _AgentTalkState extends State<_AgentTalk> {
  final log = <String>[];
  int? _pick;

  @override
  Widget build(BuildContext context) {
    final car = widget.car, p = widget.p, ask = widget.ask;
    final now = car.agentAskOf(p);
    final left = car.haggleLimit - car.haggleRounds(p.id);
    final steps = [
      for (final f in const [0.8, 0.85, 0.9, 0.95])
        if ((ask * f).round() < now && (ask * f).round() >= minSalary) (ask * f).round(),
    ];
    return Container(
      key: const Key('agent-talk'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('代理人と値切る(あと$left回)', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('代理人の言い値 ${money(now)}。低すぎる額は気を悪くさせる(気持ちが下がる)。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
          for (final l in log) Text(l, style: const TextStyle(fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 6),
          if (left > 0 && steps.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final s in steps)
                  ChoiceChip(
                    label: Text(money(s), style: const TextStyle(fontSize: 12)),
                    selected: _pick == s,
                    onSelected: (_) => setState(() => _pick = s),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (left > 0 && steps.isNotEmpty)
                Expanded(
                  child: OutlinedButton(onPressed: _pick == null ? null : () => _talk(_pick!), child: const Text('この額を申し出る')),
                ),
              if (now < ask) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (widget.years, -now / ask)),
                    child: FittedBox(child: Text('言い値${money(now)}で結ぶ')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _talk(int salary) {
    final car = widget.car, p = widget.p;
    final r = car.talkAgent(p.id, widget.years, salary);
    if (r.mood == AgentMood.agreed) {
      Navigator.pop(context, (widget.years, -r.salary / widget.ask));
      return;
    }
    setState(() {
      _pick = null;
      log.add(
        '${money(salary)} → ${switch (r.mood) {
          AgentMood.counter => '「間を取って${money(r.salary)}でどうだ」',
          AgentMood.low => '「まだ低い。${money(r.salary)}までなら」',
          AgentMood.last => '「${money(r.salary)}。これが最後だ」',
          AgentMood.insulted => '「話にならない」(気持ちが下がった)',
          AgentMood.closed => '「もう話すことはない。${money(r.salary)}だ」',
          AgentMood.agreed => '',
        }}',
      );
    });
  }
}
