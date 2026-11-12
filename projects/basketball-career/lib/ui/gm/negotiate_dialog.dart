import 'package:flutter/material.dart';

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
  if (picked == null) return;
  final (years, factor) = picked;
  final ok = c.offer(p.id, years, factor);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? '${p.name}と$years年 ${money(p.salary)}で契約した'
            : factor < 1
            ? '${p.name}は値下げを断った(気持ちが下がった)'
            : '契約できなかった(年俸の上限を確かめる)',
      ),
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
  late int _years = (widget.bid ? widget.car.myBid(widget.p.id)?.years : null) ?? widget.ask.maxYears.clamp(1, 3);

  @override
  Widget build(BuildContext context) {
    final car = widget.car, p = widget.p, ask = widget.ask;
    final rounds = car.haggleRounds(p.id);
    final canHaggle = (widget.extension ? !car.extAsked.contains(p.id) : rounds < Career.maxHaggle) && ask.salary > minSalary;
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
      content: Column(
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
          const SizedBox(height: 12),
          if (widget.bid) ...[
            _option(context, '1割高く', '${money(at(1.1))}・選ばれやすい', 1.1),
            _option(context, '求める額で', money(ask.salary), 1.0),
            _option(context, '1割安く', '${money(at(0.9))}・選ばれにくい', 0.9),
          ] else ...[
            _option(context, '求める額で', '${money(ask.salary)}・${widget.extension ? 'たいてい受ける' : '必ず受ける'}', 1.0),
            _option(context, '1割高く', '${money(at(1.1))}・気持ちが上がる', 1.1),
            if (canHaggle)
              _option(context, '1割安く', '${money(at(0.9))}・受ける見込み$chance%${widget.extension ? '' : '(あと${Career.maxHaggle - rounds}回)'}', 0.9)
            else
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('値下げは、もう申し出られない', style: TextStyle(fontSize: 12, color: GmColors.sub)),
              ),
          ],
        ],
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
