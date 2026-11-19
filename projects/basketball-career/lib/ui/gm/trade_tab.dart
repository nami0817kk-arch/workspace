import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/trade.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'gm_table.dart';
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

  /// 相手のチームの一覧。選んでいるチームが見える所まで送る。
  final _teamScroll = ScrollController();
  static const _teamRowH = 34.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealPartner(animate: false));
  }

  @override
  void dispose() {
    _teamScroll.dispose();
    super.dispose();
  }

  /// 選んでいるチームの行が一覧の外にあれば、真ん中あたりまで送る。
  void _revealPartner({bool animate = true}) {
    if (!mounted || !_teamScroll.hasClients) return;
    final mine = widget.c.career!.mine;
    final i = _partner > mine ? _partner - 1 : _partner;
    final pos = _teamScroll.position;
    final top = i * _teamRowH, bottom = top + _teamRowH;
    if (top >= pos.pixels && bottom <= pos.pixels + pos.viewportDimension) return;
    final to = (top - (pos.viewportDimension - _teamRowH) / 2).clamp(0.0, pos.maxScrollExtent);
    if (animate) {
      _teamScroll.animateTo(to, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _teamScroll.jumpTo(to);
    }
  }

  /// 選んだ自分の選手1人を欲しがっているチーム(相手が出してくれるもの)。選び直すまで覚えておく。
  List<TradeOffer> _suitors = const [];
  String _suitorKey = '';

  List<TradeOffer> _suitorsOf(Career car) {
    if (_give.length != 1 || !car.canTrade) return const [];
    final key = '${_give.first}-${car.season}-${car.phase.index}-${car.roundAt}-${car.tradesDone}-${car.me.roster.length}';
    if (key != _suitorKey) {
      _suitorKey = key;
      _suitors = car.blockOffers(_give.first);
    }
    return _suitors;
  }

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
    protections: {
      for (final i in _givePicks)
        if ((_protect[i] ?? 0) > 0) i: _protect[i]!,
    },
    getPicks: [..._getPicks],
    giveSwaps: [..._giveSwaps],
    getSwaps: [..._getSwaps],
  );

  Future<void> _showBlockOffers(BuildContext context, Career car, Player p) {
    final offers = car.blockOffers(p.id);
    String what(TradeOffer o) => [
      for (final id in o.get) ...car.teams[o.partner].roster.where((x) => x.id == id).map((x) => '${x.name}(OVR ${shown(x.ovr)}・${x.age}歳・${money(x.salary)})'),
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
            Text(offers.isEmpty ? 'いまは、出してくれるチームがない。' : '${offers.length}チームが、これなら出すという。上ほどこちらに値打ちが高い。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            const SizedBox(height: 8),
            for (final o in offers.take(10))
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(
                    children: [
                      TeamBadge(team: o.partner, size: 30),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teamDefs[o.partner].short, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(what(o), style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _partner = o.partner;
                            _give
                              ..clear()
                              ..addAll(o.give);
                            _get
                              ..clear()
                              ..addAll(o.get);
                            _getPicks
                              ..clear()
                              ..addAll(o.getPicks);
                            _givePicks.clear();
                            _giveSwaps.clear();
                            _getSwaps.clear();
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) => _revealPartner());
                        },
                        child: const Text('並べる'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final ok = tradeWithShow(context, widget.c, o, () => widget.c.acceptBlockOffer(o));
                          if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('成立しなかった(状況が変わった)')));
                        },
                        child: const Text('受ける'),
                      ),
                    ],
                  ),
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
    final suitors = _suitorsOf(car);
    final o = _offer;
    final verdict = o.isEmpty ? null : car.judge(o);
    // 選手が動くときは、両チームの強さと勝ち数の見込みがどう変わるか
    final impact = o.give.isEmpty && o.get.isEmpty ? null : car.tradeImpact(o);
    final gs = car.me.roster.where((p) => _give.contains(p.id)).fold(0, (s, p) => s + p.salary);
    final ts = them.roster.where((p) => _get.contains(p.id)).fold(0, (s, p) => s + p.salary);
    final pr = car.gmPerson(_partner);
    // 選んだものの名前(下の欄に並べる)
    String names(Iterable<Player> ps, Iterable<int> picks) => [
      for (final p in ps) p.name,
      for (final i in picks) car.picks[i].label(car.teams, car.season),
    ].join('・');
    final giveNames = names(car.me.roster.where((p) => _give.contains(p.id)), _givePicks);
    final getNames = names(them.roster.where((p) => _get.contains(p.id)), _getPicks);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左: 相手のチーム(縦に一覧。2026-11-16、ユーザー「トレードがやりにくい」。横に流すチップから変えた)
              SizedBox(width: 176, child: _partnerList(context, car, {for (final s in suitors) s.partner})),
              const VerticalDivider(width: 1, color: GmColors.line),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  children: [
                    if (!car.canTrade)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text('今はトレードできない(シーズン中は締め切りまで。オフの契約・シーズン前はできる)。', style: TextStyle(color: GmColors.bad, fontSize: 12)),
                      ),
                    // 相手の要点(1行)
                    Row(
                      children: [
                        TeamBadge(team: _partner, size: 26),
                        const SizedBox(width: 6),
                        Flexible(
                          child: fitText('${them.name}(${them.mode.label})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${them.mode.wants}・GM ${pr.name}(${pr.style.label})・年俸 ${money(them.payroll)}・${them.roster.length}人',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: GmColors.sub),
                          ),
                        ),
                      ],
                    ),
                    _blockLine(context, car),
                    if (_give.length == 1) _suitorLine(context, car, suitors),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _rosterTable(context, car, _partner, '受け取る(${them.def.short})', _get, color: GmColors.good),
                              const SizedBox(height: 6),
                              _pickTable(car, _partner, _getPicks, give: false),
                              _swapChips(car, _getSwaps, '相手の1巡目と入れ替えられる権利を受け取る'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _rosterTable(context, car, car.mine, '出す(自分のチーム)', _give, color: GmColors.bad),
                              const SizedBox(height: 6),
                              _pickTable(car, car.mine, _givePicks, give: true),
                              _swapChips(car, _giveSwaps, '自分の1巡目と入れ替えられる権利を渡す'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 申し込みの欄(いつも下に見える)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          decoration: const BoxDecoration(
            color: GmColors.panelHi,
            border: Border(top: BorderSide(color: GmColors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            giveNames.isEmpty ? '出す: まだ選んでいない' : '出す: $giveNames(${money(gs)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: GmColors.bad, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(Icons.swap_horiz_rounded, size: 16, color: GmColors.sub),
                        Expanded(
                          child: Text(
                            getNames.isEmpty ? '受け取る: まだ選んでいない' : '受け取る: $getNames(${money(ts)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: GmColors.good, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _Reaction(verdict: verdict),
                    if (impact != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '強さ ${impact.myBefore.toStringAsFixed(1)}→${impact.myAfter.toStringAsFixed(1)}'
                        '(見込み ${impact.winsBefore.round()}→${impact.winsAfter.round()}勝)・'
                        '相手 ${impact.theirBefore.toStringAsFixed(1)}→${impact.theirAfter.toStringAsFixed(1)}'
                        '${verdict != null && verdict.notes.isNotEmpty ? '・${verdict.notes.first}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: impact.myAfter > impact.myBefore + 0.05
                              ? GmColors.good
                              : impact.myAfter < impact.myBefore - 0.05
                              ? GmColors.bad
                              : GmColors.sub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 330,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '選んだものを全部外す',
                      onPressed: o.isEmpty
                          ? null
                          : () => setState(() {
                              _give.clear();
                              _get.clear();
                              _givePicks.clear();
                              _getPicks.clear();
                              _giveSwaps.clear();
                              _getSwaps.clear();
                            }),
                      icon: const Icon(Icons.clear_all_rounded),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        onPressed: (_get.isEmpty && _getPicks.isEmpty) || !car.canTrade || c.busy ? null : () => _ask(context, verdict),
                        icon: const Icon(Icons.forum_rounded, size: 18),
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(_give.isEmpty && _givePicks.isEmpty ? '相手に聞く' : '何を足せば受ける?')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        onPressed: verdict != null && verdict.ok && !c.busy ? () => _propose(context) : null,
                        icon: const Icon(Icons.handshake_rounded),
                        label: const Text('申し込む'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 相手のチームの一覧(縦)。上に「選手から探す」。
  Widget _partnerList(BuildContext context, Career car, Set<int> wants) {
    final teams = [for (var t = 0; t < teamDefs.length; t++) if (t != car.mine) t];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(32), padding: EdgeInsets.zero),
            onPressed: () => _findPlayer(context, car),
            icon: const Icon(Icons.person_search_rounded, size: 16, color: GmColors.ball),
            label: const Text('選手から探す', style: TextStyle(fontSize: 12)),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _teamScroll,
            children: [
              for (final t in teams)
                Material(
                  color: t == _partner ? GmColors.ball.withValues(alpha: 0.18) : Colors.transparent,
                  child: InkWell(
                    onTap: () => _setPartner(t),
                    child: Container(
                      height: _teamRowH,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: t == _partner ? GmColors.ball : Colors.transparent, width: 3)),
                      ),
                      child: Row(
                        children: [
                          TeamBadge(team: t, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: fitText(teamDefs[t].short, style: TextStyle(fontSize: 12, fontWeight: t == _partner ? FontWeight.bold : null),
                                      ),
                                    ),
                                    if (wants.contains(t))
                                      const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.favorite_rounded, size: 11, color: GmColors.good)),
                                  ],
                                ),
                                Text(
                                  '${record(car.teams[t])}・${car.teams[t].mode.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9, color: GmColors.sub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 選んだ自分の選手を欲しがっているチーム(1行)。押すと、それぞれが出してくれるものの一覧。
  Widget _suitorLine(BuildContext context, Career car, List<TradeOffer> suitors) {
    final p = car.me.roster.where((x) => x.id == _give.first).firstOrNull;
    if (p == null || !car.canTrade) return const SizedBox.shrink();
    final names = [for (final s in suitors.take(3)) teamDefs[s.partner].short].join('・');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: GmColors.good, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              suitors.isEmpty ? '${p.name}を欲しがるチームは、いまは無い' : '${p.name}を欲しがるチーム: ${suitors.length}チーム($names${suitors.length > 3 ? 'ほか' : ''})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: suitors.isEmpty ? GmColors.sub : GmColors.good, fontWeight: FontWeight.bold),
            ),
          ),
          if (suitors.isNotEmpty)
            ActionChip(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: const Text('出してくれるものを見る', style: TextStyle(fontSize: 11)),
              onPressed: widget.c.busy ? null : () => _showBlockOffers(context, car, p),
            ),
        ],
      ),
    );
  }

  /// トレードブロック(1行。載せた選手ごとに「申し込みを集める」)。
  Widget _blockLine(BuildContext context, Career car) {
    final onBlock = [for (final id in car.tradeBlock) ...car.me.roster.where((p) => p.id == id)];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.campaign_rounded, color: GmColors.ball, size: 15),
          Text(onBlock.isEmpty ? 'トレードブロック: 出してよい選手を、チームの画面で押して載せる' : 'トレードブロック:', style: const TextStyle(fontSize: 11, color: GmColors.sub)),
          for (final p in onBlock)
            ActionChip(
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text('${p.name}の申し込みを集める', style: const TextStyle(fontSize: 11)),
              onPressed: !car.canTrade || widget.c.busy ? null : () => _showBlockOffers(context, car, p),
            ),
        ],
      ),
    );
  }

  /// 選手の表(先発の順)。行を押すと選ぶ、長押しで選手のカード。
  Widget _rosterTable(BuildContext context, Career car, int team, String title, Set<int> chosen, {required Color color}) {
    final mine = team == car.mine;
    final players = [
      for (final p in lineup(car.teams[team].roster))
        if (!mine || !car.expiring.contains(p.id)) p,
    ];
    return GmTable(
      title: title,
      trailing: Text('${chosen.length}人を選択', style: TextStyle(fontSize: 11, color: chosen.isEmpty ? GmColors.sub : color)),
      rowHeight: 28,
      cols: const [
        GmCol('', width: 22),
        GmCol('選手', flex: 1, align: TextAlign.left),
        GmCol('位', width: 26),
        GmCol('歳', width: 24),
        GmCol('OVR', width: 32),
        GmCol('年俸', width: 80, align: TextAlign.right),
        GmCol('残', width: 22),
      ],
      rows: [
        for (final p in players)
          GmRow(
            [
              Icon(chosen.contains(p.id) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16, color: chosen.contains(p.id) ? color : GmColors.sub),
              Row(
                children: [
                  Flexible(
                    child: fitText(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (p.injured > 0) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.healing_rounded, size: 12, color: GmColors.bad)),
                  if (car.tradeBlock.contains(p.id)) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.campaign_rounded, size: 12, color: GmColors.ball)),
                ],
              ),
              Text(p.pos.short, style: const TextStyle(fontSize: 10, color: GmColors.sub)),
              numCell('${p.age}'),
              numCell('${shown(p.ovr)}', color: GmColors.ovr(p.ovr), bold: true),
              numCell(money(p.salary), color: GmColors.salary(p.salary, fairSalary(p.ovr, p.age))),
              numCell('${p.years}', color: GmColors.sub),
            ],
            highlight: chosen.contains(p.id),
            onTap: () => setState(() => chosen.contains(p.id) ? chosen.remove(p.id) : chosen.add(p.id)),
            onLongPress: () => showPlayerCard(context, car, p, team),
          ),
      ],
    );
  }

  /// 指名権の表(近い4年。先の年は開いて出す)。自分の1巡目は保護をその場で選べる。
  Widget _pickTable(Career car, int team, Set<int> chosen, {required bool give}) {
    final all = car.picksOf(team);
    if (all.isEmpty) return const SizedBox.shrink();
    final near = [
      for (final i in all)
        if (_farPicks || car.picks[i].season - car.season < 4 || chosen.contains(i)) i,
    ];
    return GmTable(
      title: '指名権(${all.length}本)',
      trailing: near.length < all.length || _farPicks
          ? InkWell(
              onTap: () => setState(() => _farPicks = !_farPicks),
              child: Text(_farPicks ? '先の年を閉じる' : '先の年も(${all.length - near.length}本)', style: const TextStyle(fontSize: 11, color: GmColors.ball)),
            )
          : null,
      rowHeight: 26,
      cols: const [
        GmCol('', width: 22),
        GmCol('指名権', flex: 1, align: TextAlign.left),
        GmCol('保護', width: 132, align: TextAlign.right),
      ],
      rows: [
        for (final i in near)
          GmRow(
            [
              Icon(chosen.contains(i) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16, color: chosen.contains(i) ? GmColors.ball : GmColors.sub),
              Text(car.picks[i].label(car.teams, car.season), maxLines: 1, overflow: TextOverflow.ellipsis),
              give && chosen.contains(i) && car.picks[i].round == 1 && car.picks[i].protect == 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final n in const [0, 5, 10, 14])
                          InkWell(
                            onTap: () => setState(() => _protect[i] = n),
                            child: Container(
                              margin: const EdgeInsets.only(left: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: (_protect[i] ?? 0) == n ? GmColors.ball.withValues(alpha: 0.3) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: GmColors.line),
                              ),
                              child: Text(n == 0 ? 'なし' : '上位$n', style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                      ],
                    )
                  : Text(car.picks[i].protect > 0 ? '上位${car.picks[i].protect}' : '', style: const TextStyle(fontSize: 10, color: GmColors.sub)),
            ],
            highlight: chosen.contains(i),
            onTap: () => setState(() => chosen.contains(i) ? chosen.remove(i) : chosen.add(i)),
          ),
      ],
    );
  }

  /// 入れ替え権のチップ(今年から3年先まで)。
  Widget _swapChips(Career car, Set<int> chosen, String note) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('入れ替え権:', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
        for (var k = 0; k < 3; k++)
          FilterChip(
            label: Text(
              '${k == 0
                  ? '今年'
                  : k == 1
                  ? '来年'
                  : '$k年後'}の1巡目',
              style: const TextStyle(fontSize: 12),
            ),
            tooltip: note,
            selected: chosen.contains(car.season + k),
            onSelected: (v) => setState(() => v ? chosen.add(car.season + k) : chosen.remove(car.season + k)),
          ),
      ],
    ),
  );

  /// 先の年の指名権まで出すか(指名権は7年先まである。ふだんは近い4年だけ並べる)。
  bool _farPicks = false;

  /// リーグ全体の選手から探す。選ぶと、その選手のチームを相手にして、受け取る側に入れる。
  Future<void> _findPlayer(BuildContext context, Career car) async {
    final picked = await Navigator.of(context).push<(int, int)>(MaterialPageRoute(builder: (_) => _PlayerFinder(car: car)));
    if (picked == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealPartner());
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
        final what = newP.isNotEmpty ? car.me.roster.firstWhere((p) => p.id == newP.first).name : '${car.picks[newK.first].when(car.season)}の${car.picks[newK.first].round}巡目';
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
    final color = v.ok
        ? GmColors.good
        : f >= 0.8
        ? GmColors.gold
        : GmColors.bad;
    final face = v.ok
        ? Icons.sentiment_very_satisfied_rounded
        : f >= 0.8
        ? Icons.sentiment_neutral_rounded
        : Icons.sentiment_very_dissatisfied_rounded;
    return Row(
      children: [
        Icon(face, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.ok ? '受けてくれそう' : v.reason,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: v.ratio > 0 ? f : 0, minHeight: 7, color: color, backgroundColor: GmColors.line),
              ),
            ],
          ),
        ),
      ],
    );
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
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  for (final p in <Pos?>[null, ...Pos.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(visualDensity: VisualDensity.compact, label: Text(p == null ? '全ポジション' : p.short), selected: _pos == p, onSelected: (_) => setState(() => _pos = p)),
                    ),
                  const SizedBox(width: 10),
                  for (final a in const [0, 25, 29])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(visualDensity: VisualDensity.compact, label: Text(a == 0 ? '年齢は問わない' : '$a歳まで'), selected: _maxAge == a, onSelected: (_) => setState(() => _maxAge = a)),
                    ),
                ],
              ),
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
                        extra: Row(
                          children: [
                            TeamBadge(team: t, size: 18),
                            const SizedBox(width: 4),
                            Text('${car.teams[t].def.short}(${car.teams[t].mode.label})', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                          ],
                        ),
                        onTap: () => Navigator.pop(context, (t, p.id)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
