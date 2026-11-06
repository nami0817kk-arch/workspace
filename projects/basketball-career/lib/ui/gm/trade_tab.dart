import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/trade.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// トレードのタブ。相手を選び、出すものと受け取るものを選んで申し込む。相手の反応は申し込む前から見える。
class TradeTab extends StatefulWidget {
  const TradeTab({super.key, required this.c, this.initialPartner});
  final GmController c;
  final int? initialPartner;

  @override
  State<TradeTab> createState() => _TradeTabState();
}

class _TradeTabState extends State<TradeTab> {
  late int _partner = widget.initialPartner ?? widget.c.career?.incoming?.partner ?? 1;
  final _give = <int>{};
  final _get = <int>{};
  final _givePicks = <int>{};
  final _getPicks = <int>{};

  void _setPartner(int t) => setState(() {
        _partner = t;
        _get.clear();
        _getPicks.clear();
      });

  TradeOffer get _offer => TradeOffer(
        partner: _partner,
        give: [..._give],
        get: [..._get],
        givePicks: [..._givePicks],
        getPicks: [..._getPicks],
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final car = c.career!;
    // 成立や放出で、選んでいた選手がいなくなっていたら外す
    _give.removeWhere((id) => !car.me.roster.any((p) => p.id == id));
    _get.removeWhere((id) => !car.teams[_partner].roster.any((p) => p.id == id));
    _givePicks.removeWhere((i) => i >= car.picks.length || car.picks[i].owner != Career.mine);
    _getPicks.removeWhere((i) => i >= car.picks.length || car.picks[i].owner != _partner);
    final them = car.teams[_partner];
    final o = _offer;
    final verdict = o.isEmpty ? null : car.judge(o);
    final gs = car.me.roster.where((p) => _give.contains(p.id)).fold(0, (s, p) => s + p.salary);
    final ts = them.roster.where((p) => _get.contains(p.id)).fold(0, (s, p) => s + p.salary);
    return Column(children: [
      // 相手を選ぶ
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          children: [
            for (var t = 1; t < teamDefs.length; t++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: TeamBadge(team: t, size: 20),
                  label: Text(teamDefs[t].short),
                  selected: _partner == t,
                  onSelected: (_) => _setPartner(t),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          children: [
            if (!car.canTrade)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('今はトレードできない(シーズン中は締め切りまで。オフの契約・シーズン前はできる)。', style: TextStyle(color: GmColors.bad)),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  TeamBadge(team: _partner, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${them.name}(${them.mode.label})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(them.mode.wants, style: const TextStyle(fontSize: 13, color: GmColors.gold)),
                      Text('年俸 ${money(them.payroll)}・${them.roster.length}人', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                    ]),
                  ),
                ]),
              ),
            ),
            SectionTitle('受け取る(${them.def.short})'),
            for (final p in lineup(them.roster))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: PlayerRow(
                  p: p,
                  team: _partner,
                  selected: _get.contains(p.id),
                  onTap: () => setState(() => _get.contains(p.id) ? _get.remove(p.id) : _get.add(p.id)),
                ),
              ),
            _pickChips(car, _partner, _getPicks),
            const SectionTitle('出す(自分のチーム)'),
            for (final p in lineup(car.me.roster))
              if (!car.expiring.contains(p.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: PlayerRow(
                    p: p,
                    team: Career.mine,
                    selected: _give.contains(p.id),
                    onTap: () => setState(() => _give.contains(p.id) ? _give.remove(p.id) : _give.add(p.id)),
                  ),
                ),
            _pickChips(car, Career.mine, _givePicks),
          ],
        ),
      ),
      // 申し込みの欄(いつも下に見える)
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(color: GmColors.panelHi, border: Border(top: BorderSide(color: GmColors.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('出す ${_give.length + _givePicks.length}件(年俸 ${money(gs)})', style: const TextStyle(fontSize: 12, color: GmColors.bad))),
            Expanded(child: Text('受け取る ${_get.length + _getPicks.length}件(年俸 ${money(ts)})', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: GmColors.good))),
          ]),
          const SizedBox(height: 6),
          _Reaction(verdict: verdict),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: verdict != null && verdict.ok && !c.busy ? () => _propose(context) : null,
            icon: const Icon(Icons.handshake_rounded),
            label: const Text('申し込む'),
          ),
        ]),
      ),
    ]);
  }

  Widget _pickChips(Career car, int team, Set<int> chosen) {
    final list = car.picksOf(team);
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final i in list)
          FilterChip(
            label: Text('指名権 ${car.picks[i].label(car.teams, car.season)}', style: const TextStyle(fontSize: 12)),
            selected: chosen.contains(i),
            onSelected: (v) => setState(() => v ? chosen.add(i) : chosen.remove(i)),
          ),
      ]),
    );
  }

  void _propose(BuildContext context) {
    final names = widget.c.career!.teams[_partner].name;
    if (widget.c.propose(_offer)) {
      setState(() {
        _give.clear();
        _get.clear();
        _givePicks.clear();
        _getPicks.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$namesとのトレードが成立した')));
    }
  }
}

/// 相手の反応の帯。
class _Reaction extends StatelessWidget {
  const _Reaction({required this.verdict});
  final TradeVerdict? verdict;

  @override
  Widget build(BuildContext context) {
    final v = verdict;
    if (v == null) {
      return const Text('受け取る選手と出す選手(指名権)を選ぶと、相手の反応が分かる。', style: TextStyle(fontSize: 13, color: GmColors.sub));
    }
    final f = v.ratio.clamp(0.0, 1.0);
    final color = v.ok ? GmColors.good : f >= 0.8 ? GmColors.gold : GmColors.bad;
    final face = v.ok
        ? Icons.sentiment_very_satisfied_rounded
        : f >= 0.8
            ? Icons.sentiment_neutral_rounded
            : Icons.sentiment_very_dissatisfied_rounded;
    return Row(children: [
      Icon(face, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.ok ? '受けてくれそう' : v.reason, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: v.ratio > 0 ? f : 0, minHeight: 7, color: color, backgroundColor: GmColors.line),
          ),
        ]),
      ),
    ]);
  }
}
