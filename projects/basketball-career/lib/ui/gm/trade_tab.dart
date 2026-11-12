import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/trade.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'player_card.dart';
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
  late int _partner = widget.initialPartner ?? widget.c.career?.incoming?.partner ?? (widget.c.career!.mine == 0 ? 1 : 0);
  final _give = <int>{};
  final _get = <int>{};
  final _givePicks = <int>{};
  final _getPicks = <int>{};

  /// 出す1巡目の指名権に付ける保護(指名権の番号 → 上位いくつ)。
  final _protect = <int, int>{};

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
        protections: {for (final i in _givePicks) if ((_protect[i] ?? 0) > 0) i: _protect[i]!},
        getPicks: [..._getPicks],
      );

  /// トレードブロック。載せた選手ごとに、いま届く申し込みを集めて見られる。
  Widget _blockCard(BuildContext context, Career car) {
    final onBlock = [for (final id in car.tradeBlock) ...car.me.roster.where((p) => p.id == id)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.campaign_rounded, color: GmColors.ball, size: 20),
            SizedBox(width: 6),
            Text('トレードブロック', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          if (onBlock.isEmpty)
            const Text('出してもよい選手を、チームの画面で選手を押して載せる。載せた選手には申し込みが届きやすくなる。', style: TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4))
          else
            for (final p in onBlock)
              Row(children: [
                Expanded(child: Text('${p.name}(OVR ${shown(p.ovr)})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                TextButton(
                  onPressed: !car.canTrade || widget.c.busy ? null : () => _showBlockOffers(context, car, p),
                  child: const Text('申し込みを集める'),
                ),
              ]),
        ]),
      ),
    );
  }

  Future<void> _showBlockOffers(BuildContext context, Career car, Player p) {
    final offers = car.blockOffers(p.id);
    String what(TradeOffer o) => [
          for (final id in o.get)
            ...car.teams[o.partner].roster.where((x) => x.id == id).map((x) => '${x.name}(OVR ${shown(x.ovr)}・${x.age}歳・${money(x.salary)})'),
          for (final i in o.getPicks) car.picks[i].label(car.teams, car.season),
        ].join('・');
    return showGmSheet<void>(
      context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          children: [
            Text('${p.name}への申し込み', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(offers.isEmpty ? 'いまは、出してくれるチームがない。' : '${offers.length}チームが、これなら出すという。上ほどこちらに値打ちが高い。',
                style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            const SizedBox(height: 8),
            for (final o in offers.take(10))
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(children: [
                    TeamBadge(team: o.partner, size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(teamDefs[o.partner].short, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(what(o), style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                      ]),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final ok = widget.c.acceptBlockOffer(o);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'トレードが成立した' : '成立しなかった(状況が変わった)')));
                      },
                      child: const Text('受ける'),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final car = c.career!;
    // 成立や放出で、選んでいた選手がいなくなっていたら外す
    _give.removeWhere((id) => !car.me.roster.any((p) => p.id == id));
    _get.removeWhere((id) => !car.teams[_partner].roster.any((p) => p.id == id));
    _givePicks.removeWhere((i) => i >= car.picks.length || car.picks[i].owner != car.mine);
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
            for (var t = 0; t < teamDefs.length; t++)
              if (t != car.mine)
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
            _blockCard(context, car),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  TeamBadge(team: _partner, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${them.name}(${them.mode.label})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(them.mode.wants, style: const TextStyle(fontSize: 13, color: GmColors.gold)),
                      Text('GM ${car.gmPerson(_partner).name}(${car.gmPerson(_partner).style.label}): ${car.gmPerson(_partner).style.text}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
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
                  onLongPress: () => showPlayerCard(context, car, p, _partner),
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
                    team: car.mine,
                    selected: _give.contains(p.id),
                    onTap: () => setState(() => _give.contains(p.id) ? _give.remove(p.id) : _give.add(p.id)),
                    onLongPress: () => showPlayerCard(context, car, p, car.mine),
                  ),
                ),
            _pickChips(car, car.mine, _givePicks),
            for (final i in _givePicks.where((i) => car.picks[i].round == 1 && car.picks[i].protect == 0))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: Text('${car.picks[i].when(car.season)}の1巡目の保護',
                        style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                  ),
                  for (final n in const [0, 5, 10, 14])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(n == 0 ? 'なし' : '上位$n', style: const TextStyle(fontSize: 12)),
                        selected: (_protect[i] ?? 0) == n,
                        onSelected: (_) => setState(() => _protect[i] = n),
                      ),
                    ),
                ]),
              ),
          ],
        ),
      ),
      // 申し込みの欄(いつも下に見える)
      Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(color: GmColors.panelHi, border: Border(top: BorderSide(color: GmColors.line))),
        // 横画面は縦が短いので、左に件数と相手の反応、右にボタンを並べて、欄の高さを抑える
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text('出す ${_give.length + _givePicks.length}件(年俸 ${money(gs)})', style: const TextStyle(fontSize: 12, color: GmColors.bad))),
                Expanded(child: Text('受け取る ${_get.length + _getPicks.length}件(年俸 ${money(ts)})', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: GmColors.good))),
              ]),
              const SizedBox(height: 4),
              _Reaction(verdict: verdict),
            ]),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 300,
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  onPressed: (_get.isEmpty && _getPicks.isEmpty) || !car.canTrade || c.busy ? null : () => _ask(context),
                  icon: const Icon(Icons.forum_rounded, size: 20),
                  label: const Text('相手に聞く'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  onPressed: verdict != null && verdict.ok && !c.busy ? () => _propose(context) : null,
                  icon: const Icon(Icons.handshake_rounded),
                  label: const Text('申し込む'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  /// 先の年の指名権まで出すか(指名権は7年先まである。ふだんは近い4年だけ並べる)。
  bool _farPicks = false;

  Widget _pickChips(Career car, int team, Set<int> chosen) {
    final all = car.picksOf(team);
    if (all.isEmpty) return const SizedBox.shrink();
    final near = [for (final i in all) if (_farPicks || car.picks[i].season - car.season < 4 || chosen.contains(i)) i];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final i in near)
          FilterChip(
            label: Text('指名権 ${car.picks[i].label(car.teams, car.season)}', style: const TextStyle(fontSize: 12)),
            selected: chosen.contains(i),
            onSelected: (v) => setState(() => v ? chosen.add(i) : chosen.remove(i)),
          ),
        if (near.length < all.length || _farPicks)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 32), visualDensity: VisualDensity.compact),
            onPressed: () => setState(() => _farPicks = !_farPicks),
            child: Text(_farPicks ? '先の年を閉じる' : '先の年の指名権(${all.length - near.length}本)', style: const TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }

  /// 受け取るものだけ選んだ状態で、相手が受けてくれる出し方を聞く。見つかったら、出すものの選択をそれに置き換える。
  void _ask(BuildContext context) {
    final car = widget.c.career!;
    final o = car.askPartner(_partner, get: [..._get], getPicks: [..._getPicks]);
    final messenger = ScaffoldMessenger.of(context);
    if (o == null) {
      messenger.showSnackBar(SnackBar(content: Text('${car.teams[_partner].def.short}は、この組み合わせではどう出されても受けない')));
      return;
    }
    setState(() {
      _give
        ..clear()
        ..addAll(o.give);
      _givePicks
        ..clear()
        ..addAll(o.givePicks);
    });
    messenger.showSnackBar(SnackBar(content: Text('${car.teams[_partner].def.short}の答え: 「これなら受ける」(出す${o.give.length + o.givePicks.length}件を選んだ)')));
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
      return const Text('受け取る選手と出す選手(指名権)を選ぶと、相手の反応が分かる。長押しで選手のカード。', style: TextStyle(fontSize: 13, color: GmColors.sub));
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
