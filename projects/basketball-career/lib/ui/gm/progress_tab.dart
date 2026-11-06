import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../monetization/monetization.dart';
import '../art/title_art.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// 進行のタブ。いまやること・試合の結果・届いた申し込み・オフの知らせ。
class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key, required this.c, required this.goTab});
  final GmController c;
  final void Function(int) goTab;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: switch (car.phase) {
        Phase.preseason => _preseason(context, car),
        Phase.season => _season(context, car),
        Phase.playoffs => _beforePlayoffs(context, car),
        Phase.seasonEnd => _seasonEnd(context, car),
        Phase.contracts => _contracts(context, car),
        Phase.over => _over(context, car),
        Phase.draft => const [],
      },
    );
  }

  Widget _card(List<Widget> children, {Color? edge}) => Card(
        shape: edge == null
            ? null
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: edge, width: 1.5)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );

  Widget _head(String t, {IconData icon = Icons.flag_rounded, Color color = GmColors.ball}) => Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      ]);

  // ------------------------------------------------------------ シーズン前

  List<Widget> _preseason(BuildContext context, Career car) {
    final problem = car.startProblem;
    final rank = car.strengthRank(car.mine) + 1;
    return [
      _card([
        _head('${car.season}年目のシーズン前'),
        const SizedBox(height: 8),
        Text(
            car.season == 1
                ? '${car.outlook.text}\nトレードと補強で、勝てるチームを作ろう。準備ができたら開幕する。'
                : 'トレードと補強ができる。準備ができたら開幕する。',
            style: const TextStyle(color: GmColors.sub, height: 1.5)),
        const SizedBox(height: 10),
        _kv('いまの戦力', '30チーム中 $rank位'),
        _kv('登録', '${car.me.roster.length}人($minRoster〜$maxRoster人)'),
        if (problem != null) ...[
          const SizedBox(height: 8),
          Text(problem, style: const TextStyle(color: GmColors.bad, fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: problem == null && !c.busy ? c.startSeason : null,
          icon: const Icon(Icons.sports_basketball_rounded),
          label: const Text('開幕する'),
        ),
        if (problem != null && car.me.roster.length < minRoster) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => goTab(3), child: const Text('補強で選手を取る')),
        ],
      ]),
      ..._offerCard(context, car),
      _goalsCard(car),
      _moneyCard(car),
    ];
  }

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: GmColors.sub))),
          Expanded(child: Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
        ]),
      );

  // ------------------------------------------------------------ シーズン中

  List<Widget> _season(BuildContext context, Career car) {
    final me = car.me;
    final played = blockStart(car.block);
    final next = car.block < blocksPerSeason ? blockSizes[car.block] : 0;
    final last = car.lastGames.length;
    final conf = me.east ? '東地区' : '西地区';
    final deadline = car.block < tradeDeadlineBlock;
    final blockWins = car.lastGames.where((g) => g.winner == car.mine).length;
    return [
      _card([
        _head(car.block == 0 ? '開幕' : '$played試合を終えて'),
        const SizedBox(height: 8),
        _kv('成績', '${me.wins}勝${me.losses}敗($conf ${car.confRank}位)'),
        _kv('オーナーの目標', '${car.target}勝', color: me.wins + (gamesPerSeason - played) < car.target ? GmColors.bad : null),
        _kv('トレード', deadline ? 'あと${tradeDeadlineBlock - car.block}区切りで締め切り' : '締め切りを過ぎた', color: deadline ? null : GmColors.sub),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: c.busy ? null : c.playBlock,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('次の$next試合を進める'),
        ),
      ]),
      ..._offerCard(context, car),
      _goalsCard(car),
      // 試合の結果を先に見せ、経営はそのあと
      if (car.lastGames.isNotEmpty)
        _card([
          Text('この$last試合: $blockWins勝${last - blockWins}敗', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          for (final g in car.lastGames) GameRow(g: g, mine: car.mine),
        ]),
      _moneyCard(car),
    ];
  }

  List<Widget> _offerCard(BuildContext context, Career car) {
    final o = car.incoming;
    if (o == null || !car.canTrade) return const [];
    final them = car.teams[o.partner];
    final give = car.me.roster.where((p) => o.give.contains(p.id)).toList();
    final get = them.roster.where((p) => o.get.contains(p.id)).toList();
    return [
      const SizedBox(height: 4),
      _card(edge: GmColors.gold, [
        _head('${them.name}から申し込み', icon: Icons.mail_rounded, color: GmColors.gold),
        const SizedBox(height: 4),
        Text('相手の考え: ${them.mode.label}。${them.mode.wants}。', style: const TextStyle(color: GmColors.sub, fontSize: 13)),
        const SizedBox(height: 8),
        const Text('出す', style: TextStyle(color: GmColors.bad, fontWeight: FontWeight.bold)),
        for (final p in give) Padding(padding: const EdgeInsets.only(top: 4), child: PlayerRow(p: p, team: car.mine)),
        const SizedBox(height: 8),
        const Text('受け取る', style: TextStyle(color: GmColors.good, fontWeight: FontWeight.bold)),
        for (final p in get) Padding(padding: const EdgeInsets.only(top: 4), child: PlayerRow(p: p, team: o.partner)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: c.declineIncoming, child: const Text('断る'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: c.acceptIncoming, child: const Text('受ける'))),
        ]),
      ]),
    ];
  }

  /// オーナーの目標(シーズン中は、いまの見込みで印を付ける)。
  Widget _goalsCard(Career car) {
    if (car.goals.isEmpty || car.phase != Phase.season) return const SizedBox.shrink();
    return _card([
      _head('オーナーの目標', icon: Icons.checklist_rounded),
      const SizedBox(height: 6),
      for (final g in car.goals)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(car.goalOk(g) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18, color: car.goalOk(g) ? GmColors.good : GmColors.sub),
            const SizedBox(width: 8),
            Expanded(child: Text(g.kind == GoalKind.wins ? '${car.target}勝する(いま${car.me.wins}勝)' : g.kind.label)),
          ]),
        ),
      const SizedBox(height: 4),
      Text('果たすと信頼が+$goalTrust、外すと-$goalTrust(勝ち数は差の1.5倍)。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
    ]);
  }

  /// 入場料・観客の入り・人気・収支。
  Widget _moneyCard(Career car) => _card([
        _head('経営', icon: Icons.account_balance_rounded),
        const SizedBox(height: 8),
        const Text('入場料', style: TextStyle(color: GmColors.sub, fontSize: 13)),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var i = 0; i < ticketPrices.length; i++)
              ButtonSegment(value: i, label: Text('${ticketLabels[i]}\n\$${ticketPrices[i]}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          ],
          selected: {car.priceLevel},
          onSelectionChanged: (v) => c.setPrice(v.first),
        ),
        const SizedBox(height: 8),
        _kv('観客の入り', '${(car.attendance * 100).round()}%(1試合 ${money(car.gatePerGame)})'),
        _kv('人気', '${car.hype}'),
        _kv('今季の収支', '${car.profit >= 0 ? '+' : ''}${money(car.profit)}(見込み ${car.projectedProfit >= 0 ? '+' : ''}${money(car.projectedProfit)})',
            color: car.projectedProfit >= 0 ? GmColors.good : GmColors.bad),
        const Text('人気が高いほど、入場料が安いほど客が入る。人気は勝ちとプレーオフで上がる。ぜいたく税は超えた分の1.5倍を払う。',
            style: TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
      ]);

  // ------------------------------------------------------------ プレーオフ

  List<Widget> _beforePlayoffs(BuildContext context, Career car) {
    final me = car.me;
    final st = standings(car.teams, east: me.east);
    final rank = car.confRank;
    final text = rank <= directSeeds
        ? '地区$rank位。そのままプレーオフに出る。どの回戦も4勝で勝ち抜け。'
        : rank <= playInSeeds
            ? '地区$rank位。プレーイン(1試合勝負)を勝ち抜けば、プレーオフに出られる。'
            : '地区$rank位。プレーオフには届かなかった。';
    return [
      const ArtBanner('assets/art/scene_final.jpg', height: 130),
      const SizedBox(height: 8),
      _card([
        _head('レギュラーシーズン終了', icon: Icons.emoji_events_rounded, color: GmColors.gold),
        const SizedBox(height: 8),
        _kv('成績', '${record(me)}(${me.east ? '東' : '西'}地区 $rank位)'),
        _kv('オーナーの目標', '${car.target}勝', color: me.wins >= car.target ? GmColors.good : GmColors.bad),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: rank <= playInSeeds ? GmColors.good : GmColors.sub)),
        const SizedBox(height: 8),
        for (var i = 0; i < playInSeeds; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(color: i < directSeeds ? GmColors.gold : GmColors.sub))),
              TeamBadge(team: st[i].index, size: 20),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(st[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: st[i].index == car.mine ? FontWeight.bold : FontWeight.normal, color: st[i].index == car.mine ? GmColors.ball : null))),
              if (i == directSeeds) const Padding(padding: EdgeInsets.only(right: 6), child: Tag('プレーイン')),
              Text(record(st[i])),
            ]),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: c.busy ? null : c.playPlayoffs,
          icon: const Icon(Icons.emoji_events_rounded),
          label: Text(rank <= playInSeeds ? 'プレーオフを戦う' : 'プレーオフの結果を見る'),
        ),
      ]),
    ];
  }

  // ------------------------------------------------------------ シーズン終了

  List<Widget> _seasonEnd(BuildContext context, Career car) {
    final h = car.history.last;
    final champ = h.champion;
    final last = car.season >= careerSeasons;
    return [
      if (champ) ...[
        const ArtBanner('assets/art/scene_national.jpg', height: 130),
        const SizedBox(height: 8),
      ],
      _card(edge: champ ? GmColors.gold : null, [
        _head(champ ? '優勝!' : '${car.season}年目の結果', icon: champ ? Icons.emoji_events_rounded : Icons.flag_rounded, color: champ ? GmColors.gold : GmColors.ball),
        const SizedBox(height: 8),
        _kv('成績', '${h.wins}勝${h.losses}敗(${car.me.east ? '東' : '西'}地区 ${h.rank}位)'),
        _kv('プレーオフ', h.resultLabel, color: champ ? GmColors.gold : null),
        _kv('優勝', car.teams[car.champion].name),
      ]),
      _card([
        _head('オーナーの評価', icon: Icons.handshake_rounded),
        const SizedBox(height: 8),
        _kv('勝ち数', '${h.wins}勝(目標 ${h.target}勝)  ${_signed(((h.wins - h.target) * 1.5).round())}',
            color: h.wins >= h.target ? GmColors.good : GmColors.bad),
        _kv('プレーオフ', '${h.resultLabel}  ${_signed(resultTrust[h.result])}'),
        if (car.lastTax > 0) _kv('ぜいたく税', '年俸が${money(taxLine)}を超えた  ${_signed(-car.lastTax)}', color: GmColors.bad),
        for (final g in car.goals.where((g) => g.kind != GoalKind.wins))
          _kv(g.kind.label, '${g.met == true ? '果たした' : '果たせなかった'}  ${_signed(g.met == true ? goalTrust : -goalTrust)}',
              color: g.met == true ? GmColors.good : GmColors.bad),
        _kv('収支', '${car.lastProfit >= 0 ? '+' : ''}${money(car.lastProfit)}(人気 ${car.hype})', color: car.lastProfit >= 0 ? GmColors.good : GmColors.bad),
        const Divider(height: 18),
        _kv('信頼', '${car.trust}(${_signed(car.lastTrustDelta)})', color: car.trust >= 30 ? null : GmColors.bad),
      ]),
      if (car.awardsOf(car.season).isNotEmpty)
        _card([
          _head('表彰', icon: Icons.military_tech_rounded, color: GmColors.gold),
          const SizedBox(height: 6),
          for (final a in car.awardsOf(car.season))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 104, child: Text(a.kind.label, style: const TextStyle(color: GmColors.sub))),
                TeamBadge(team: a.team, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${a.name}  ${a.line}',
                      maxLines: 2,
                      style: TextStyle(fontWeight: FontWeight.bold, color: a.team == car.mine ? GmColors.gold : null)),
                ),
              ]),
            ),
        ]),
      // 自分のチームの戦いと、ファイナル
      for (final s in car.playoffs)
        if (s.high == car.mine || s.low == car.mine || s.round == 4) _seriesCard(car, s),
      const SizedBox(height: 8),
      if (car.fired) ...[
        _card(edge: GmColors.bad, [
          _head('解任', icon: Icons.gavel_rounded, color: GmColors.bad),
          const SizedBox(height: 6),
          const Text('オーナーの信頼がなくなった。このままでは任期はここで終わる。', style: TextStyle(height: 1.5)),
          if (car.canRescue) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: c.busy ? null : () => _rescue(context),
              icon: Icon(c.needsAd ? Icons.smart_display_rounded : Icons.handshake_rounded),
              label: Text(c.needsAd ? '動画を見て、オーナーを説得する(1回だけ)' : 'オーナーを説得する(1回だけ)'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(onPressed: c.busy ? null : c.toOffseason, child: const Text('任期を終える')),
        ]),
      ] else
        FilledButton.icon(
          onPressed: c.busy ? null : c.toOffseason,
          icon: Icon(last ? Icons.flag_rounded : Icons.arrow_forward_rounded),
          label: Text(last ? '10年の任期を終える' : 'オフへ(ドラフト・契約)'),
        ),
    ];
  }

  String _signed(int v) => v > 0 ? '+$v' : '$v';

  Widget _seriesCard(Career car, Series s) {
    final mineIn = s.high == car.mine || s.low == car.mine;
    return _card(edge: mineIn ? GmColors.ball : null, [
      Text(s.label, style: const TextStyle(color: GmColors.sub, fontSize: 12)),
      const SizedBox(height: 4),
      for (final t in [s.high, s.low])
        Row(children: [
          TeamBadge(team: t, size: 20),
          const SizedBox(width: 6),
          Expanded(
              child: Text(car.teams[t].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: s.winner == t ? FontWeight.bold : FontWeight.normal))),
          Text('${t == s.high ? s.highWins : s.lowWins}勝',
              style: TextStyle(fontWeight: FontWeight.bold, color: s.winner == t ? GmColors.good : GmColors.sub)),
        ]),
    ]);
  }

  Future<void> _rescue(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final g = await c.rescueWithAd(onWaiting: () => messenger.showSnackBar(const SnackBar(content: Text('動画を読み込んでいます…'))));
    if (g == RecoverGate.unavailable) {
      messenger.showSnackBar(const SnackBar(content: Text('動画の準備ができていません。少し待ってからもう一度。')));
    }
  }

  // ------------------------------------------------------------ 契約

  List<Widget> _contracts(BuildContext context, Career car) {
    final exp = [for (final id in car.expiring) car.me.roster.firstWhere((p) => p.id == id)];
    return [
      _card([
        _head('オフ・契約'),
        const SizedBox(height: 6),
        const Text('契約が切れた選手と、残すか放すかを話し合う。自分の選手との再契約は、年俸の上限を超えてもできる(合計の上限まで)。',
            style: TextStyle(color: GmColors.sub, height: 1.5)),
        if (car.news.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('このオフの知らせ', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final n in car.news) Text('・$n', style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ]),
      SectionTitle('契約が切れた選手(${exp.length}人)'),
      if (exp.isEmpty) const Text('いない', style: TextStyle(color: GmColors.sub)),
      for (final p in exp) ...[
        _expiringRow(context, car, p),
        const SizedBox(height: 6),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () => goTab(3), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('自由契約の選手を見る')),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: c.busy ? null : () => _finish(context, exp.length),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('オフを終えて、シーズン前へ'),
      ),
    ];
  }

  Widget _expiringRow(BuildContext context, Career car, Player p) {
    final ask = car.askOf(p, car.me);
    final problem = car.resignProblem(p);
    return PlayerRow(
      p: p,
      team: car.mine,
      salaryText: '求める年俸 ${money(ask.salary)}(最長${ask.maxYears}年)',
      showDelta: true,
      extra: Row(children: [
        Expanded(
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
            onPressed: problem != null
                ? null
                : () async {
                    final y = await pickYears(context,
                        title: '${p.name}と再契約', body: '年俸 ${money(ask.salary)}。何年にする?', maxYears: ask.maxYears);
                    if (y != null) c.resign(p.id, y);
                  },
            child: const Text('再契約'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
            onPressed: () => c.letGo(p.id),
            child: const Text('放す'),
          ),
        ),
      ]),
    );
  }

  Future<void> _finish(BuildContext context, int left) async {
    if (left > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('オフを終える?'),
          content: Text('話し合っていない$left人は、自由契約になって出ていく。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('終える')),
          ],
        ),
      );
      if (ok != true) return;
    }
    c.finishContracts();
  }

  // ------------------------------------------------------------ 任期の終わり

  List<Widget> _over(BuildContext context, Career car) {
    final titles = car.titles;
    final wins = car.history.fold(0, (s, h) => s + h.wins);
    final losses = car.history.fold(0, (s, h) => s + h.losses);
    return [
      _card(edge: titles > 0 ? GmColors.gold : null, [
        _head(car.fired ? '解任された' : '任期を終えた', icon: titles > 0 ? Icons.emoji_events_rounded : Icons.flag_rounded, color: titles > 0 ? GmColors.gold : GmColors.ball),
        const SizedBox(height: 8),
        _kv('任されたとき', '${car.outlook.label}(戦力${car.startRank + 1}位)'),
        _kv('務めた年数', '${car.history.length}年'),
        _kv('優勝', '$titles回', color: titles > 0 ? GmColors.gold : null),
        _kv('通算', '$wins勝$losses敗'),
        _kv('トレード', '${car.tradesDone}回'),
      ]),
      SectionTitle('年ごとの成績'),
      for (final h in car.history)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 50, child: Text('${h.season}年目', style: const TextStyle(color: GmColors.sub))),
            SizedBox(width: 80, child: Text('${h.wins}勝${h.losses}敗')),
            Expanded(child: Text(h.resultLabel, style: TextStyle(color: h.champion ? GmColors.gold : null, fontWeight: h.champion ? FontWeight.bold : null))),
          ]),
        ),
      const SizedBox(height: 16),
      FilledButton(onPressed: c.closeCareer, child: const Text('はじめの画面へ')),
    ];
  }
}
