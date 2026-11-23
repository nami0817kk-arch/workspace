import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../gm/potential_view.dart';
import '../../gm/trade_ledger.dart';
import '../../gm/situation.dart';
import '../../gm/combos.dart';
import '../../gm/gm_people.dart';
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
                    // 相手チームの調書(トレード画面の向上 2)。たためば今までの1行
                    _dossier(car),
                    _blockLine(context, car),
                    if (_give.length == 1) _suitorLine(context, car, suitors),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('絞り込み ', style: TextStyle(fontSize: 11, color: GmColors.sub)),
                      Expanded(child: _posChips()),
                      TextButton.icon(
                        onPressed: o.give.isEmpty && o.get.isEmpty ? null : () => _showAfter(context, car),
                        icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                        label: const Text('交換後を見る', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
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
                    _Reaction(verdict: verdict, spread: _spread(car), shift: _shiftOf(o), face: car.gmPerson(_partner).name),
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
                        // 「何を足せば受ける?」は、申し込んだあとのやり取り(言い返す)に含めた。出すものを選ぶ前だけ「相手に聞く」
                        onPressed: (_get.isEmpty && _getPicks.isEmpty) || _give.isNotEmpty || _givePicks.isNotEmpty || !car.canTrade || c.busy ? null : () => _ask(context, verdict),
                        icon: const Icon(Icons.forum_rounded, size: 18),
                        label: const FittedBox(fit: BoxFit.scaleDown, child: Text('相手に聞く')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                        // 申し込むと、相手とのやり取りになる(受ける・逆の案・打ち切り。T-3・トレード画面の向上 1)
                        onPressed: verdict != null && verdict.ratio > 0 && !c.busy ? () => _talk(context) : null,
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
                                    // 事情のうわさが届いている・こちらを警戒している(トレード画面の向上 2)
                                    if (car.rumorsOf(t).isNotEmpty)
                                      const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.campaign_rounded, size: 11, color: GmColors.gold)),
                                    if (car.trustOf(t) <= -25)
                                      const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.warning_amber_rounded, size: 11, color: GmColors.bad)),
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
        if ((!mine || !car.expiring.contains(p.id)) && (_pos == null || p.pos == _pos || chosen.contains(p.id))) p,
    ];
    // 並べ替え(トレード画面の向上 3)
    switch (_sort) {
      case 1:
        players.sort((a, b) => b.ovr.compareTo(a.ovr));
      case 2:
        players.sort((a, b) => a.age.compareTo(b.age));
      case 3:
        players.sort((a, b) => b.salary.compareTo(a.salary));
      case 4:
        players.sort((a, b) => a.years.compareTo(b.years));
      case 5:
        players.sort((a, b) => roleOf(a).index.compareTo(roleOf(b).index));
    }
    GmCol col(String label, int sort, {double? width, int flex = 1, TextAlign align = TextAlign.center}) =>
        GmCol(label, width: width, flex: flex, align: align, sorted: _sort == sort, onTap: () => setState(() => _sort = _sort == sort ? 0 : sort));
    return GmTable(
      title: title,
      trailing: Text('${chosen.length}人を選択', style: TextStyle(fontSize: 11, color: chosen.isEmpty ? GmColors.sub : color)),
      // 横画面では表が左右に2つ並ぶので、名前の欄が狭くなっていた(2026-11-23「名前が見えない」)。
      // 型と位置は名前の下の小さな字に移し、名前の欄を広げる
      rowHeight: 38,
      cols: [
        const GmCol('', width: 22),
        col('選手・型', 5, flex: 1, align: TextAlign.left),
        col('歳', 2, width: 24),
        col('OVR', 1, width: 32),
        const GmCol('伸', width: 34),
        col('年俸', 3, width: 74, align: TextAlign.right),
        col('残', 4, width: 22),
      ],
      rows: [
        for (final p in players)
          GmRow(
            [
              Icon(chosen.contains(p.id) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  key: Key('trade-pick-${p.id}'), size: 16, color: chosen.contains(p.id) ? color : GmColors.sub),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 名前を押すと選手のカードを開く(行のほかの所は選ぶ・外す)
                      Flexible(
                        child: GestureDetector(
                          key: Key('trade-name-${p.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showPlayerCard(context, car, p, team),
                          child: fitText(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: GmColors.sub)),
                        ),
                      ),
                      if (p.injured > 0) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.healing_rounded, size: 12, color: GmColors.bad)),
                      if (car.tradeBlock.contains(p.id)) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.campaign_rounded, size: 12, color: GmColors.ball)),
                    ],
                  ),
                  Text('${p.pos.short}・${roleOf(p).label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: GmColors.sub, height: 1.2)),
                ],
              ),
              numCell('${p.age}'),
              numCell('${shown(p.ovr)}', color: GmColors.ovr(p.ovr), bold: true),
              () {
                final pv = car.potentialOf(p);
                return numCell(pv.worthShowing ? pv.shortText : '', color: pv.bright ? GmColors.gold : GmColors.sub);
              }(),
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
              '${switch (car.swapFrom + k - car.season) {
                0 => '今年',
                1 => '来年',
                final d => '$d年後',
              }}の1巡目',
              style: const TextStyle(fontSize: 12),
            ),
            tooltip: note,
            selected: chosen.contains(car.swapFrom + k),
            onSelected: (v) => setState(() => v ? chosen.add(car.swapFrom + k) : chosen.remove(car.swapFrom + k)),
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

  /// 表の並べ替え(0 先発の順・1 力・2 年齢・3 年俸・4 契約の残り・5 型)と、ポジションの絞り込み。
  int _sort = 0;
  Pos? _pos;

  /// 調書を開いているか。
  bool _dossierOpen = true;

  /// 相手チームの調書(トレード画面の向上 2)。GM・事情・欲しい型と弱いポジション・税の線までの空き・この相手との取引。分からないものは「？」。
  Widget _dossier(Career car) {
    final them = car.teams[_partner];
    final pr = car.gmPerson(_partner);
    final rumors = car.rumorsOf(_partner);
    final hole = holeOf(them);
    final have = {for (final p in them.order.take(8)) roleOf(p)};
    final want = [for (final r in Role.values) if (!have.contains(r)) r.label];
    final room = taxLine - them.payroll;
    final deals = [for (var i = 0; i < car.myTrades.length; i++) if (car.myTrades[i].partner == _partner) i];
    final verdicts = [
      for (final i in deals)
        switch (tradeVerdict(car, car.myTrades[i])) { null => 'まだ', 1 => '勝ち', 0 => '五分', _ => '負け' },
    ];
    final trust = car.trustLabel(_partner);
    final head = Row(
      children: [
        TeamBadge(team: _partner, size: 26),
        const SizedBox(width: 6),
        Flexible(child: fitText('${them.name}(${them.mode.label})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        const SizedBox(width: 6),
        Icon(trust == '信頼している' ? Icons.sentiment_very_satisfied_rounded : trust == '警戒している' ? Icons.sentiment_very_dissatisfied_rounded : Icons.sentiment_neutral_rounded,
            size: 16, color: trust == '信頼している' ? GmColors.good : trust == '警戒している' ? GmColors.bad : GmColors.sub),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: _dossierOpen ? '調書をたたむ' : '調書を開く',
          icon: Icon(_dossierOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
          onPressed: () => setState(() => _dossierOpen = !_dossierOpen),
        ),
      ],
    );
    if (!_dossierOpen) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        head,
        Text('${them.mode.wants}・GM ${pr.name}(${pr.style.label})・年俸 ${money(them.payroll)}・${them.roster.length}人',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
      ]);
    }
    Widget line(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 62, child: Text(k, style: const TextStyle(fontSize: 11, color: GmColors.sub))),
            Expanded(child: Text(v, style: TextStyle(fontSize: 11.5, color: color))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 4, 6),
      decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: GmColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        head,
        line('GM', '${pr.name}・${pr.style.label}・話し方 ${temperOf(pr).label}・見る目 ${car.eyeKnown(_partner) ? eyeOf(pr).label : '？'}・こちらを$trust'),
        line('事情', rumors.isEmpty ? '？(うわさが届くと分かる)・${them.mode.wants}' : rumors.map((r) => '${r.text}(うわさ)').join('・'),
            color: rumors.isEmpty ? null : GmColors.gold),
        line('欲しい型', want.isEmpty ? 'そろっている' : want.take(3).join('・')),
        line('弱い位置', hole == null ? 'なし' : '${hole.label}(けが人を除いて1人以下)'),
        line('税の線まで', room >= 0 ? 'あと${money(room)}' : '${money(-room)}超えている', color: room < 0 ? GmColors.bad : null),
        line('この相手と', deals.isEmpty ? 'まだ取引していない' : '${deals.length}回(${verdicts.join('・')})'),
      ]),
    );
  }

  /// 交換の前と後の、自分のチーム(先発と控え・年俸・分かっている組み合わせ。トレード画面の向上 3)。
  void _showAfter(BuildContext context, Career car) {
    final o = _offer;
    final now = lineup(car.me.roster);
    final gets = [for (final id in o.get) ...car.teams[_partner].roster.where((p) => p.id == id)];
    final after = lineup([...car.me.roster.where((p) => !o.give.contains(p.id)), ...gets]);
    final known = car.combosFound.toSet();
    List<String> combosOf(List<Player> top) => [for (final x in combosOfPlayers(top.take(5).toList())) if (known.contains(x)) '${x.good ? '◎' : '×'}${x.label}'];
    int pay(List<Player> ps) => ps.fold(0, (s, p) => s + p.salary);
    int next(List<Player> ps) => ps.where((p) => p.years >= 2).fold(0, (s, p) => s + (p.nextSalary ?? p.salary));
    Widget side(String title, List<Player> ps, {required bool before}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final (k, p) in ps.take(9).indexed)
              Text(
                '${k < 5 ? '先' : '控'} ${p.pos.short} ${p.name} ${shown(p.ovr)}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: before && o.give.contains(p.id)
                      ? GmColors.bad
                      : !before && o.get.contains(p.id)
                          ? GmColors.good
                          : GmColors.text,
                  fontWeight: k < 5 ? FontWeight.bold : null,
                ),
              ),
            const SizedBox(height: 6),
            Text('年俸の合計 ${money(pay(ps))}(税の線 ${money(taxLine)})', style: TextStyle(fontSize: 11.5, color: pay(ps) > taxLine ? GmColors.bad : GmColors.sub)),
            Text('来季の年俸 ${money(next(ps))}', style: const TextStyle(fontSize: 11.5, color: GmColors.sub)),
            if (combosOf(ps).isNotEmpty) Text('組み合わせ: ${combosOf(ps).join('・')}', style: const TextStyle(fontSize: 11.5, color: GmColors.gold)),
          ]),
        );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('交換の前と後', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('抜ける選手は赤、入る選手は緑。組み合わせは図鑑で見つけたものだけ。', style: TextStyle(fontSize: 11.5, color: GmColors.sub)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [side('今', now, before: true), const SizedBox(width: 12), side('交換後', after, before: false)]),
          ]),
        ),
      ),
    );
  }

  /// ポジションの絞り込みの札(全部・PG〜C)。
  Widget _posChips() => Wrap(spacing: 4, children: [
        for (final p in [null, ...Pos.values])
          ChoiceChip(
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            label: Text(p?.short ?? '全部', style: const TextStyle(fontSize: 11)),
            selected: _pos == p,
            onSelected: (_) => setState(() => _pos = p),
          ),
      ]);

  /// ゲージの幅(信頼している相手ほど、見る目を知っている相手ほど狭い。トレード画面の向上 1)。
  double _spread(Career car) => car.trustOf(_partner) >= 25
      ? 0.06
      : car.eyeKnown(_partner)
          ? 0.1
          : 0.18;

  /// ゲージの幅の中で、本当の値がどこにあるか(案ごとに決まる)。
  double _shiftOf(TradeOffer o) => (((_partner * 37 + o.give.length * 11 + o.get.length * 5 + o.givePicks.length * 3) % 7) - 3) / 3 * 0.5;

  /// 相手とのやり取り(T-3)。相手の返事を見て、受ける・言い返す(案を直す)・やめる を選ぶ。
  Future<void> _talk(BuildContext context) async {
    final car = widget.c.career!;
    final o = _offer;
    final reply = car.talk(o);
    final gm = car.gmPerson(_partner);
    final temper = temperOf(gm);
    if (!context.mounted) return;
    final pick = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${gm.name}(${car.teams[_partner].def.short}・${temper.label})', style: const TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('こちらの案: ${_names(car, o)}', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(reply.ok ? Icons.sentiment_very_satisfied_rounded : reply.ended ? Icons.sentiment_very_dissatisfied_rounded : Icons.sentiment_neutral_rounded,
                color: reply.ok ? GmColors.good : reply.ended ? GmColors.bad : GmColors.gold),
            const SizedBox(width: 8),
            Expanded(child: Text('「${reply.line}」', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4))),
          ]),
          if (reply.counter != null) ...[
            const SizedBox(height: 8),
            Text('相手の案: ${_names(car, reply.counter!)}', style: const TextStyle(fontSize: 12.5)),
          ],
          const SizedBox(height: 8),
          if (!reply.ok && !reply.ended)
            Text('話せるのは、あと${reply.roundsLeft.clamp(0, 9)}回(しつこく言い返すと機嫌が下がる)', style: const TextStyle(fontSize: 11.5, color: GmColors.sub)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'stop'), child: const Text('やめる')),
          if (reply.counter != null) TextButton(onPressed: () => Navigator.pop(ctx, 'edit'), child: const Text('言い返す(案を直す)')),
          if (reply.counter != null) FilledButton(onPressed: () => Navigator.pop(ctx, 'take'), child: const Text('相手の案で受ける')),
          if (reply.ok) FilledButton(onPressed: () => Navigator.pop(ctx, 'deal'), child: const Text('成立させる')),
        ],
      ),
    );
    if (!mounted || !context.mounted) return;
    final counter = reply.counter;
    switch (pick) {
      case 'deal':
        _propose(context);
      case 'take' when counter != null:
        setState(() => _setOffer(counter));
        _propose(context);
      case 'edit' when counter != null:
        // 相手の案を出す側に入れて、直してから申し込み直す
        setState(() => _setOffer(counter));
      default:
        break;
    }
  }

  /// 案の中身(「出す: ○○・2巡目 / 受け取る: △△」)。
  String _names(Career car, TradeOffer o) {
    final give = [
      for (final id in o.give) ...car.me.roster.where((p) => p.id == id).map((p) => p.name),
      for (final i in o.givePicks) car.picks[i].label(car.teams, car.season),
    ];
    final get = [
      for (final id in o.get) ...car.teams[o.partner].roster.where((p) => p.id == id).map((p) => p.name),
      for (final i in o.getPicks) car.picks[i].label(car.teams, car.season),
    ];
    return '出す ${give.join('・')} / 受け取る ${get.join('・')}';
  }

  /// 選んでいるものを [o] にする(出すもの・受け取るもの)。
  void _setOffer(TradeOffer o) {
    _give
      ..clear()
      ..addAll(o.give);
    _get
      ..clear()
      ..addAll(o.get);
    _givePicks
      ..clear()
      ..addAll(o.givePicks);
    _getPicks
      ..clear()
      ..addAll(o.getPicks);
  }

  void _propose(BuildContext context) {
    final o = _offer;
    if (tradeWithShow(context, widget.c, o, () => widget.c.propose(o))) {
      setState(() {
        _give.clear();
        _get.clear();
        _givePicks.clear();
        _getPicks.clear();
        _giveSwaps.clear();
        _getSwaps.clear();
        _protect.clear();
      });
    }
  }
}

/// 相手の反応の帯。
class _Reaction extends StatelessWidget {
  const _Reaction({required this.verdict, this.spread = 0.18, this.shift = 0, this.face = ''});
  final TradeVerdict? verdict;

  /// 見せる幅(片側)と、幅の中の本当の値の位置のずれ(-0.5〜0.5)。トレード画面の向上 1(ゲージは幅で見せる)。
  final double spread, shift;
  final String face;

  @override
  Widget build(BuildContext context) {
    final v = verdict;
    if (v == null) {
      return const Text('欲しい選手と出す選手の行をタップ(名前を押すと詳しく見られる)。相手の反応が出る', style: TextStyle(fontSize: 13, color: GmColors.sub));
    }
    if (v.ratio <= 0) {
      return Text(v.reason, style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.bad, fontSize: 13));
    }
    // 本当の見込みは幅のどこかにある(ぴったりは分からない)
    final lo = (v.ratio - spread * (1 + shift)).clamp(0.0, 1.5), hi = (v.ratio + spread * (1 - shift)).clamp(0.0, 1.5);
    final mid = (lo + hi) / 2;
    final color = lo >= 1
        ? GmColors.good
        : hi < 0.8
            ? GmColors.bad
            : GmColors.gold;
    final face = lo >= 1
        ? Icons.sentiment_very_satisfied_rounded
        : hi < 0.8
            ? Icons.sentiment_very_dissatisfied_rounded
            : Icons.sentiment_neutral_rounded;
    final word = lo >= 1
        ? '悪くない(受けてくれそう)'
        : hi < 0.5
            ? '話にならない'
            : hi < 0.8
                ? 'ふむ…(足りなそう)'
                : mid >= 0.95
                    ? 'ふむ…(あと一押しかも)'
                    : '五分五分';
    return Row(
      children: [
        Icon(face, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(word, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              const SizedBox(height: 4),
              LayoutBuilder(builder: (context, box) {
                final w = box.maxWidth;
                double x(double r) => w * (r / 1.5).clamp(0.0, 1.0);
                return SizedBox(
                  height: 8,
                  child: Stack(children: [
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: GmColors.line, borderRadius: BorderRadius.circular(4)))),
                    // 受けてもらえる線(1.0)
                    Positioned(left: x(1.0) - 1, top: 0, bottom: 0, child: Container(width: 2, color: GmColors.text)),
                    Positioned(
                      left: x(lo),
                      width: math.max(4, x(hi) - x(lo)),
                      top: 1,
                      bottom: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4))),
                    ),
                  ]),
                );
              }),
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
