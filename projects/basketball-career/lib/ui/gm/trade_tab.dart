import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/trade.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'player_card.dart';
import 'style.dart';
import 'trade_show_screen.dart';

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

  /// 入れ替え権(その年の1巡目)。出す・受け取る。
  final _giveSwaps = <int>{};
  final _getSwaps = <int>{};

  /// 出す1巡目の指名権に付ける保護(指名権の番号 → 上位いくつ)。
  final _protect = <int, int>{};

  void _setPartner(int t) => setState(() {
        _partner = t;
        _get.clear();
        _getPicks.clear();
        _getSwaps.clear();
      });

  TradeOffer get _offer => TradeOffer(
        partner: _partner,
        give: [..._give],
        get: [..._get],
        givePicks: [..._givePicks],
        protections: {for (final i in _givePicks) if ((_protect[i] ?? 0) > 0) i: _protect[i]!},
        getPicks: [..._getPicks],
        giveSwaps: [..._giveSwaps],
        getSwaps: [..._getSwaps],
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
            SizedBox(width: 10),
            Expanded(
              child: Text('出してよい選手を、チームの画面で押して載せる', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: GmColors.sub)),
            ),
          ]),
          if (onBlock.isNotEmpty)
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
                        final ok = tradeWithShow(context, widget.c, o, () => widget.c.acceptBlockOffer(o));
                        if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('成立しなかった(状況が変わった)')));
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
    // 選手が動くときは、両チームの強さと勝ち数の見込みがどう変わるか
    final impact = o.give.isEmpty && o.get.isEmpty ? null : car.tradeImpact(o);
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
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.person_search_rounded, size: 18, color: GmColors.ball),
                label: const Text('選手から探す'),
                onPressed: () => _findPlayer(context, car),
              ),
            ),
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
            _swapChips(car, _getSwaps, '相手の1巡目と入れ替えられる権利を受け取る'),
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
            _swapChips(car, _giveSwaps, '自分の1巡目と入れ替えられる権利を渡す'),
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
              if (impact != null) ...[
                const SizedBox(height: 3),
                Text(
                  '強さ ${impact.myBefore.toStringAsFixed(1)}→${impact.myAfter.toStringAsFixed(1)}'
                  '(見込み ${impact.winsBefore.round()}→${impact.winsAfter.round()}勝)・'
                  '相手 ${impact.theirBefore.toStringAsFixed(1)}→${impact.theirAfter.toStringAsFixed(1)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: impact.myAfter > impact.myBefore + 0.05
                          ? GmColors.good
                          : impact.myAfter < impact.myBefore - 0.05
                              ? GmColors.bad
                              : GmColors.sub),
                ),
              ],
              if (verdict != null && verdict.notes.isNotEmpty)
                Text(verdict.notes.first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GmColors.gold)),
            ]),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 300,
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  onPressed: (_get.isEmpty && _getPicks.isEmpty) || !car.canTrade || c.busy ? null : () => _ask(context, verdict),
                  icon: const Icon(Icons.forum_rounded, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_give.isEmpty && _givePicks.isEmpty ? '相手に聞く' : '何を足せば受ける?'),
                  ),
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

  /// 入れ替え権のチップ(今年から3年先まで)。
  Widget _swapChips(Career car, Set<int> chosen, String note) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('入れ替え権:', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
          for (var k = 0; k < 3; k++)
            FilterChip(
              label: Text('${k == 0 ? '今年' : k == 1 ? '来年' : '$k年後'}の1巡目', style: const TextStyle(fontSize: 12)),
              tooltip: note,
              selected: chosen.contains(car.season + k),
              onSelected: (v) => setState(() => v ? chosen.add(car.season + k) : chosen.remove(car.season + k)),
            ),
        ]),
      );

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

  /// リーグ全体の選手から探す。選ぶと、その選手のチームを相手にして、受け取る側に入れる。
  Future<void> _findPlayer(BuildContext context, Career car) async {
    final picked = await Navigator.of(context).push<(int, int)>(MaterialPageRoute(builder: (_) => _PlayerFinder(car: car)));
    if (picked == null || !mounted) return;
    setState(() {
      _partner = picked.$1;
      _get
        ..clear()
        ..add(picked.$2);
      _getPicks.clear();
      _getSwaps.clear();
    });
  }

  /// 受け取るものだけ選んだ状態で、相手が受けてくれる出し方を聞く。見つかったら、出すものの選択をそれに置き換える。
  /// すでに出すものを選んでいて足りないときは、1つ足せば受けてもらえるものを探す。
  void _ask(BuildContext context, TradeVerdict? verdict) {
    final car = widget.c.career!;
    final messenger = ScaffoldMessenger.of(context);
    if ((_give.isNotEmpty || _givePicks.isNotEmpty) && verdict != null && !verdict.ok) {
      final add = car.suggestAddition(_offer);
      if (add != null) {
        final newP = add.give.where((id) => !_give.contains(id)).toList();
        final newK = add.givePicks.where((i) => !_givePicks.contains(i)).toList();
        final what = newP.isNotEmpty
            ? car.me.roster.firstWhere((p) => p.id == newP.first).name
            : '${car.picks[newK.first].when(car.season)}の${car.picks[newK.first].round}巡目';
        setState(() {
          _give.addAll(newP);
          _givePicks.addAll(newK);
        });
        messenger.showSnackBar(SnackBar(content: Text('${car.teams[_partner].def.short}の答え: 「$whatも付けてくれるなら受ける」(出す側に足した)')));
        return;
      }
    }
    final o = car.askPartner(_partner, get: [..._get], getPicks: [..._getPicks]);
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
    final o = _offer;
    if (tradeWithShow(context, widget.c, o, () => widget.c.propose(o))) {
      setState(() {
        _give.clear();
        _get.clear();
        _givePicks.clear();
        _getPicks.clear();
      });
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
      return const Text('欲しい選手と出す選手をタップ。相手の反応が出る', style: TextStyle(fontSize: 13, color: GmColors.sub));
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

/// リーグ全体の選手を探す画面(ポジションと年齢で絞り、力の順に並べる)。選ぶと (チーム, 選手の id) を返す。
class _PlayerFinder extends StatefulWidget {
  const _PlayerFinder({required this.car});
  final Career car;

  @override
  State<_PlayerFinder> createState() => _PlayerFinderState();
}

class _PlayerFinderState extends State<_PlayerFinder> {
  Pos? _pos;
  int _maxAge = 0;

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final all = <(int, Player)>[
      for (var t = 0; t < car.teams.length; t++)
        if (t != car.mine)
          for (final p in car.teams[t].roster)
            if ((_pos == null || p.pos == _pos) && (_maxAge == 0 || p.age <= _maxAge)) (t, p),
    ]..sort((a, b) => b.$2.ovr.compareTo(a.$2.ovr));
    final list = all.take(60).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('選手から探す')),
      body: SafeArea(
        child: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              for (final p in <Pos?>[null, ...Pos.values])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(p == null ? '全ポジション' : p.short),
                    selected: _pos == p,
                    onSelected: (_) => setState(() => _pos = p),
                  ),
                ),
              const SizedBox(width: 10),
              for (final a in const [0, 25, 29])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(a == 0 ? '年齢は問わない' : '$a歳まで'),
                    selected: _maxAge == a,
                    onSelected: (_) => setState(() => _maxAge = a),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              children: [
                Text('力の高い順に${list.length}人。押すと、その選手を受け取る形でトレードの画面に戻る。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                const SizedBox(height: 6),
                for (final (t, p) in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PlayerRow(
                      p: p,
                      team: t,
                      extra: Row(children: [
                        TeamBadge(team: t, size: 18),
                        const SizedBox(width: 4),
                        Text('${car.teams[t].def.short}(${car.teams[t].mode.label})', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                      ]),
                      onTap: () => Navigator.pop(context, (t, p.id)),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
