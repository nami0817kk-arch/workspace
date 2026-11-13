import 'package:flutter/material.dart';

import '../../gm/block_report.dart';
import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/rating.dart';
import '../../monetization/monetization.dart';
import '../art/title_art.dart';
import '../gm_controller.dart';
import 'block_report_screen.dart';
import 'box_score.dart';
import 'coaches_screen.dart';
import 'common.dart';
import 'draft_show_screen.dart';
import 'inbox_screen.dart';
import 'negotiate_dialog.dart';
import 'player_card.dart';
import 'skills_screen.dart';
import 'style.dart';

/// 進行のタブ。いまやること・試合の結果・届いた申し込み・オフの知らせ。
class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key, required this.c, required this.goTab});
  final GmController c;
  final void Function(int) goTab;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final list = ListView(
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
    if (car.phase != Phase.contracts) return list;
    // オフの契約は長い一覧なので、「オフを終える」を下に固定して、いつでも押せるようにする
    final left = car.expiring.length;
    return Column(children: [
      Expanded(child: list),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(color: GmColors.panelHi, border: Border(top: BorderSide(color: GmColors.line))),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: c.busy ? null : () => _finish(context, left),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('オフを終えて、シーズン前へ'),
        ),
      ),
    ]);
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
        _kv('登録', '${car.me.roster.length}人($minRoster〜$maxRoster人)', color: car.me.roster.length > maxRoster ? GmColors.bad : null),
        if (problem != null) ...[
          const SizedBox(height: 8),
          Text(problem, style: const TextStyle(color: GmColors.bad, fontWeight: FontWeight.bold)),
        ],
        _todo(_preseasonTodo(car, problem)),
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
      _ownerCard(car),
      ..._offerCard(context, car),
      _goalsCard(car),
      _moneyCard(car),
      _staffCard(context, car),
    ];
  }

  /// オーナーの性格と、シーズン前の面談(予算を決める)。
  Widget _ownerCard(Career car) => _card([
        _head('オーナー(${car.ownerType.label})', icon: Icons.business_center_rounded),
        const SizedBox(height: 6),
        Text(car.ownerType.text, style: const TextStyle(color: GmColors.sub, fontSize: 12, height: 1.4)),
        const SizedBox(height: 8),
        _kv('今季の予算', '${budgetLabels[car.budgetLevel]}(${money(car.budgetCap)})'),
        if (car.meetingOpen) ...[
          const SizedBox(height: 6),
          const Text('面談: 予算を決める。低く約束して守ると、シーズンの終わりに信頼が上がる(上限まで +6、ぜいたく税の手前まで +3)。約束を超える補強やトレードはできなくなる。',
              style: TextStyle(color: GmColors.sub, fontSize: 12, height: 1.4)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (var i = 0; i < budgetLabels.length; i++)
              OutlinedButton(
                onPressed: c.busy ? null : () => c.ownerMeeting(i),
                child: Text('${budgetLabels[i]}(${money(const [salaryCap, taxLine, secondApron][i])})', style: const TextStyle(fontSize: 12)),
              ),
          ]),
        ] else
          const Text('今季の面談は済んだ。', style: TextStyle(color: GmColors.sub, fontSize: 12)),
      ]);

  /// 「やること」の一行(金色の太字)。
  Widget _todo(String t) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_rounded, size: 18, color: GmColors.gold),
          const SizedBox(width: 6),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GmColors.gold, height: 1.4))),
        ]),
      );

  /// シーズン前のやること。
  String _preseasonTodo(Career car, String? problem) {
    if (car.meetingOpen) return 'やること: まず下の「オーナー」で今季の予算を決める。';
    if (car.me.roster.length < minRoster) return 'やること: 登録が$minRoster人に足りない。「補強」で選手を取る。';
    if (car.me.roster.length > maxRoster) return 'やること: 登録が$maxRoster人を超えている。「チーム」で選手を放すか、トレードに出す。';
    if (problem != null) return 'やること: $problem';
    return 'やること: 準備ができていれば「開幕する」。補強やトレードをしてからでもよい。';
  }

  /// シーズン中のやること。
  String _seasonTodo(Career car) {
    if (car.incoming != null) return 'やること: トレードの申し込みが届いている。下で受けるか断る。';
    if (car.inbox.any((m) => m.needsAnswer)) return 'やること: 受信箱に返事を待つ知らせがある。';
    if (car.block < tradeDeadlineBlock && car.block == tradeDeadlineBlock - 1) {
      return 'やること: 次の区切りでトレードの締め切り。補強するならいま。済んだら試合を進める。';
    }
    return 'やること: 「次の試合へ」で試合を進める。けが人や不調があれば「チーム」で先発を見直す。';
  }

  /// 直近10試合の○●と、この区切りの見どころ。
  Widget _formCard(BuildContext context, Career car) {
    final hl = car.highlightsOf(car.lastGames).take(4).toList();
    final w = car.form.where((d) => d > 0).length;
    return _card([
      Row(children: [
        Text('直近${car.form.length}試合 $w勝${car.form.length - w}敗', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 3, runSpacing: 3, children: [
            for (final d in car.form)
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: d > 0 ? GmColors.good : GmColors.bad, shape: BoxShape.circle),
                child: Text(d > 0 ? '勝' : '負', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
          ]),
        ),
      ]),
      if (hl.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final h in hl)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text('・$h', style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
      ],
    ]);
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
    final played = car.roundAt;
    final next = car.block < blocksPerSeason ? blockStart(car.block + 1) - played : 0;
    final week = next < Career.daysPerWeek ? next : Career.daysPerWeek;
    final last = car.lastGames.length;
    final conf = me.east ? '東地区' : '西地区';
    final deadline = car.block < tradeDeadlineBlock;
    final blockWins = car.lastGames.where((g) => g.winner == car.mine).length;
    return [
      _card([
        _head(played == 0 ? '開幕' : '$played試合を終えて'),
        const SizedBox(height: 8),
        _kv('成績', '${me.wins}勝${me.losses}敗($conf ${car.confRank}位)'),
        _kv('オーナーの目標', '${car.target}勝', color: me.wins + (gamesPerSeason - played) < car.target ? GmColors.bad : null),
        _kv('トレード', deadline ? 'あと${tradeDeadlineBlock - car.block}区切りで締め切り' : '締め切りを過ぎた', color: deadline ? null : GmColors.sub),
        _todo(_seasonTodo(car)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: c.busy || next <= week ? null : () => _run(context, () => c.playWeek()),
              // 文字が折り返さないように、狭い画面では縮める
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(week == Career.daysPerWeek ? '1週間' : '$week試合')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: c.busy ? null : () => _run(context, () => c.playBlock()),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('次の$next試合へ'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // まとめて進める(申し込みが届いたら、そこで止まる)
        Row(children: [
          if (deadline) ...[
            Expanded(
              child: TextButton.icon(
                onPressed: c.busy ? null : () => _run(context, () => c.simAhead(toDeadline: true)),
                icon: const Icon(Icons.fast_forward_rounded, size: 18),
                label: const Text('締め切りまで', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
          Expanded(
            child: TextButton.icon(
              onPressed: c.busy ? null : () => _run(context, () => c.simAhead(toDeadline: false)),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('シーズン終わりまで', maxLines: 1, style: TextStyle(fontSize: 13)),
            ),
          ),
        ]),
      ]),
      if (car.form.isNotEmpty) _formCard(context, car),
      ..._offerCard(context, car),
      ..._inboxCard(context, car),
      ..._scheduleCard(car),
      _pressCard(car),
      _goalsCard(car),
      ..._injuryCard(car),
      // 試合の結果を先に見せ、経営はそのあと
      if (car.lastGames.isNotEmpty)
        _card([
          Text('この$last試合: $blockWins勝${last - blockWins}敗', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          for (final g in car.lastGames)
            InkWell(onTap: () => showBoxScore(context, g, car.mine), child: GameRow(g: g, mine: car.mine)),
          const Text('試合を押すと、ボックススコアが見られる。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
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

  /// 返事を待っている知らせがあれば、受信箱への案内を出す。
  List<Widget> _inboxCard(BuildContext context, Career car) {
    final waiting = car.inbox.where((m) => m.needsAnswer).toList();
    if (waiting.isEmpty) return const [];
    return [
      _card(edge: GmColors.gold, [
        _head('返事を待っている知らせ ${waiting.length}件', icon: Icons.mail_rounded, color: GmColors.gold),
        const SizedBox(height: 4),
        for (final m in waiting.take(3)) Text('・${m.title}', style: const TextStyle(height: 1.6)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InboxScreen(c: c))),
          child: const Text('受信箱を開く'),
        ),
      ]),
    ];
  }

  /// これからの日程(次の5試合)。
  List<Widget> _scheduleCard(Career car) {
    final next = car.upcoming();
    if (next.isEmpty) return const [];
    return [
      _card([
        _head('これからの日程', icon: Icons.event_rounded),
        const SizedBox(height: 4),
        for (final (i, (opp, home)) in next.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 44, child: Text('${car.roundAt + i + 1}戦目', style: const TextStyle(fontSize: 12, color: GmColors.sub))),
              SizedBox(width: 22, child: Text(home ? 'vs' : '@', style: const TextStyle(fontSize: 12, color: GmColors.sub))),
              TeamBadge(team: opp, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(car.teams[opp].name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(record(car.teams[opp]), style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            ]),
          ),
      ]),
    ];
  }

  /// けがで休んでいる自分の選手。
  List<Widget> _injuryCard(Career car) {
    final hurt = [for (final p in car.me.roster) if (p.injured > 0) p];
    if (hurt.isEmpty) return const [];
    return [
      _card([
        _head('けが人', icon: Icons.healing_rounded, color: GmColors.bad),
        const SizedBox(height: 4),
        for (final p in hurt) Text('・${p.name}(${p.pos.short}・OVR${shown(p.ovr)}) あと${p.injured}試合', style: const TextStyle(height: 1.6)),
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

  /// コーチ陣(シーズン前とオフの契約のときに入れ替えられる)。
  Widget _staffCard(BuildContext context, Career car) {
    if (!car.canChangeStaff) return const SizedBox.shrink();
    return _card([
      _head('コーチ陣', icon: Icons.groups_2_rounded),
      const SizedBox(height: 6),
      for (final s in Staff.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 104, child: Text(s.label, style: const TextStyle(fontSize: 13, color: GmColors.sub))),
            Expanded(
              child: Text(
                  car.me.coachOf(s) == null
                      ? coachLevelLabels[car.me.staffLevel(s) - 1]
                      : '${car.me.coachOf(s)!.name}(${car.me.coachOf(s)!.rating})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      const SizedBox(height: 6),
      Text('給料 1シーズン ${money(car.me.staffCost)}(収支の支出に入る)。いまなら入れ替えられる。', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CoachesScreen(c: c))),
        icon: const Icon(Icons.badge_rounded),
        label: const Text('コーチを見る・雇う'),
      ),
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
        const Text('売店の値段', style: TextStyle(color: GmColors.sub, fontSize: 13)),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var i = 0; i < concessionPrices.length; i++)
              ButtonSegment(value: i, label: Text('${concessionLabels[i]}\n\$${concessionPrices[i]}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
          ],
          selected: {car.concessionLevel},
          onSelectionChanged: (v) => c.setConcession(v.first),
        ),
        const SizedBox(height: 8),
        _kv('観客の入り', '${(car.attendance * 100).round()}%(1試合 入場 ${money(car.gatePerGame)}・売店 ${money(car.concessionPerGame)})'),
        _kv('人気', '${car.hype}'),
        _kv('市場の大きさ', '${car.market.toStringAsFixed(2)}倍(スポンサーとグッズに掛かる)'),
        const SizedBox(height: 4),
        const Text('今季の収入', style: TextStyle(color: GmColors.sub, fontSize: 13)),
        for (final i in Income.values) _kv(i.label, money(car.incomeBy[i.index])),
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
          onPressed: c.busy ? null : () => _playoffs(context),
          icon: const Icon(Icons.emoji_events_rounded),
          label: Text(rank <= playInSeeds ? 'プレーオフを戦う' : 'プレーオフの結果を見る'),
        ),
      ]),
    ];
  }

  /// 試合を進め、終わったら報告を画面いっぱいに出す。
  Future<void> _run(BuildContext context, Future<BlockReport?> Function() play) async {
    final nav = Navigator.of(context);
    await showBlockReport(nav, c, await play());
  }

  /// プレーオフを戦い、自分のシリーズを1試合ずつ見せる。
  Future<void> _playoffs(BuildContext context) async {
    final nav = Navigator.of(context);
    await c.playPlayoffs();
    if (c.career?.phase != Phase.seasonEnd) return;
    await nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PlayoffRunScreen(c: c)));
  }

  /// オフへ。指名権が無くドラフトがその場で終わったときも、くじとドラフトのまとめは見せる。
  Future<void> _offseason(BuildContext context) async {
    final nav = Navigator.of(context);
    c.toOffseason();
    final car = c.career;
    if (car == null || car.phase != Phase.contracts || car.lotteryPre.isEmpty) return;
    c.lotteryShownSeason = car.season;
    await nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => LotteryScreen(c: c)));
    if (!nav.mounted) return;
    await nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => DraftSummaryScreen(c: c)));
  }

  // ------------------------------------------------------------ シーズン終了

  List<Widget> _seasonEnd(BuildContext context, Career car) {
    final h = car.history.last;
    final champ = h.champion;
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
      _ratingCard(context, car),
      if (car.awardsOf(car.season).isNotEmpty)
        _card([
          _head('表彰', icon: Icons.military_tech_rounded, color: GmColors.gold),
          const SizedBox(height: 6),
          // オールリーグは15人いるので、自分の選手だけ(全員はリーグの歴史で見る)
          for (final a in car.awardsOf(car.season).where((a) => !a.kind.allLeague || a.team == car.mine))
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
          onPressed: c.busy ? null : () => _offseason(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('オフへ(ドラフト・契約)'),
        ),
      if (!car.fired) ...[
        const SizedBox(height: 8),
        // 任期に上限は無い。やめたいときは、ここで自分から終える
        OutlinedButton(onPressed: c.busy ? null : () => _confirmEnd(context), child: const Text('ここで任期を終える')),
      ],
    ];
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('任期を終える?'),
        content: const Text('ここまでの成績と GM の格が記録に残り、はじめの画面に戻る。続きはできない。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('続ける')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('終える')),
        ],
      ),
    );
    if (ok == true) c.endCareer();
  }

  /// 見出しとファンの声。
  Widget _pressCard(Career car) => _card([
        _head('報道', icon: Icons.newspaper_rounded),
        const SizedBox(height: 6),
        if (car.headlines.isEmpty) const Text('区切りを終えると、見出しが出る。', style: TextStyle(color: GmColors.sub, fontSize: 12)),
        for (final h in car.headlines.take(3)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('・$h', style: const TextStyle(fontSize: 13, height: 1.4))),
        const SizedBox(height: 6),
        Text('ファンの声: 「${car.fanVoice}」', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      ]);

  /// GM の格。このシーズンの点の内訳と、通算・次の段階。
  Widget _ratingCard(BuildContext context, Career car) {
    final total = car.lastRating.fold(0, (n, x) => n + x.points);
    final next = nextRatingFloor(car.gmPoints);
    return _card([
      _head('GMの格 Lv${car.gmLevel}(${ratingNameOf(car.gmLevel)})', icon: Icons.workspace_premium_rounded, color: GmColors.gold),
      const SizedBox(height: 6),
      if (car.levelBefore != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('格が上がった! Lv${car.levelBefore} → Lv${car.gmLevel}', style: const TextStyle(color: GmColors.gold, fontWeight: FontWeight.bold)),
        ),
      if (car.lastRating.isEmpty)
        const Text('このシーズンは点が入らなかった。', style: TextStyle(color: GmColors.sub))
      else
        for (final x in car.lastRating)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(x.label, style: const TextStyle(color: GmColors.sub))),
              Text('+${x.points}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
      const Divider(height: 18),
      _kv('このシーズン', '+$total点'),
      _kv('通算', next == null ? '${car.gmPoints}点(最高の段階)' : '${car.gmPoints}点(次の段階まで ${next - car.gmPoints}点)'),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SkillsScreen(c: c))),
        icon: const Icon(Icons.account_tree_rounded),
        label: Text('GMの技能(使える点 ${car.skillPoints})'),
      ),
    ]);
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
        const Text('来シーズンに向けて、選手の入れ替えをする時期。下の「やること」を上から順にこなして、最後に「オフを終えて、シーズン前へ」を押す。',
            style: TextStyle(color: GmColors.sub, height: 1.5)),
        if (car.news.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('このオフの知らせ', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final n in car.news) Text('・$n', style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ]),
      _contractsGuide(car, exp.length),
      if (car.growth.isNotEmpty) _growthCard(car),
      if (car.sheetPlayer != null) _sheetCard(context, car),
      if (car.optionPending.isNotEmpty) ...[
        SectionTitle('チームの選択権(${car.optionPending.length}人)'),
        const Text('新人の契約の最後の年。使えば次の年も少し高い年俸で契約が続き、使わなければ契約が切れて、再契約か自由契約になる。',
            style: TextStyle(color: GmColors.sub, fontSize: 12, height: 1.4)),
        const SizedBox(height: 6),
        for (final id in car.optionPending) ...[
          _optionRow(context, car, car.me.roster.firstWhere((p) => p.id == id)),
          const SizedBox(height: 6),
        ],
      ],
      SectionTitle('契約が切れた選手(${exp.length}人)'),
      if (exp.isEmpty) const Text('いない', style: TextStyle(color: GmColors.sub)),
      for (final p in exp) ...[
        _expiringRow(context, car, p),
        const SizedBox(height: 6),
      ],
      _staffCard(context, car),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () => goTab(3), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('自由契約の選手を見る')),
    ];
  }

  /// オフの「やること」の一覧。済んだものにはチェックが付き、いま手を付けるものが太字で出る。
  Widget _contractsGuide(Career car, int expiringCount) {
    final steps = <(bool, String, String)>[
      if (car.sheetPlayer != null) (false, 'オファーシートに答える', '下の「同じ条件で残す」か「見送る」を押す'),
      if (car.optionPending.isNotEmpty)
        (false, '新人の選択権を決める(${car.optionPending.length}人)', '「使う」なら契約が1年続く。「使わない」なら契約切れ'),
      if (expiringCount > 0)
        (false, '契約が切れた選手を決める($expiringCount人)', '残したい選手は「再契約」、いらない選手は「放す」。そのままだと出ていく')
      else
        (true, '契約が切れた選手は決め終わった', ''),
      (false, 'お好みで: 自由契約の選手を取って補強する', '左のメニューの「補強」か、下の「自由契約の選手を見る」(しなくてもよい)'),
      (false, '終わったら「オフを終えて、シーズン前へ」を押す', '画面の下に固定してあるボタン。次はトレードをして、開幕する'),
    ];
    final firstTodo = steps.indexWhere((s) => !s.$1);
    return _card([
      _head('オフの「やること」', icon: Icons.checklist_rounded, color: GmColors.gold),
      const SizedBox(height: 8),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(steps[i].$1 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 20, color: steps[i].$1 ? GmColors.good : (i == firstTodo ? GmColors.ball : GmColors.sub)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i + 1}. ${steps[i].$2}',
                    style: TextStyle(fontWeight: i == firstTodo ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                if (steps[i].$3.isNotEmpty) Text(steps[i].$3, style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.3)),
              ]),
            ),
          ]),
        ),
    ], edge: GmColors.gold);
  }

  /// ほかのチームから届いたオファーシート(同じ条件で残すか、見送るか)。
  Widget _sheetCard(BuildContext context, Career car) {
    final p = car.sheetPlayer!;
    final s = car.sheet!;
    final problem = car.matchProblem();
    return Card(
      color: GmColors.panelHi,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('オファーシートが届いた', style: TextStyle(fontWeight: FontWeight.bold, color: GmColors.gold)),
          const SizedBox(height: 4),
          Text('${car.teams[s[1]].name}が${p.name}に${s[3]}年 ${money(s[2])}を出した。同じ条件で残せば、上限を超えていても契約できる。見送ると、そのチームへ行く。答えないまま日が進むと、見送りになる。',
              style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4)),
          const SizedBox(height: 6),
          PlayerRow(p: p, team: car.mine, onLongPress: () => showPlayerCard(context, car, p, car.mine)),
          if (problem != null) Text(problem, style: const TextStyle(fontSize: 12, color: GmColors.bad)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                onPressed: c.busy ? null : c.declineSheet,
                child: const Text('見送る'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                onPressed: problem != null || c.busy ? null : c.matchSheet,
                child: Text('同じ条件で残す(${money(s[2])}・${s[3]}年)'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _optionRow(BuildContext context, Career car, Player p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PlayerRow(p: p, team: car.mine, onLongPress: () => showPlayerCard(context, car, p, car.mine)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  onPressed: c.busy ? null : () => c.declineOption(p.id),
                  child: const Text('使わない'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                  onPressed: c.busy ? null : () => c.exerciseOption(p.id),
                  child: Text('使う(年俸 ${money(car.optionSalary(p))})'),
                ),
              ),
            ]),
          ]),
        ),
      );

  /// オフの成長の報告(伸びた順)。
  Widget _growthCard(Career car) {
    final list = [...car.growth]..sort((a, b) => b.delta.compareTo(a.delta));
    return _card([
      _head('オフの成長', icon: Icons.trending_up_rounded),
      const SizedBox(height: 6),
      for (final g in list)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
              child: Text('${g.name}(${g.age}歳)${g.focus == null ? '' : '・重点 ${g.focus!.label}'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            Text('${shown(g.before)} → ${shown(g.after)}', style: const TextStyle(fontSize: 13, color: GmColors.sub)),
            SizedBox(
              width: 40,
              child: Text(
                shown(g.after) - shown(g.before) == 0 ? '±0' : '${shown(g.after) > shown(g.before) ? '+' : ''}${shown(g.after) - shown(g.before)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: g.delta > 0
                        ? GmColors.good
                        : g.delta < 0
                            ? GmColors.bad
                            : GmColors.sub),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _expiringRow(BuildContext context, Career car, Player p) {
    final ask = car.askOf(p, car.me);
    final problem = car.resignProblem(p);
    return PlayerRow(
      p: p,
      team: car.mine,
      salaryText: '求める年俸 ${money(ask.salary)}(最長${ask.maxYears}年)・${car.birdOf(p).label}',
      showDelta: true,
      extra: Row(children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
            onPressed: problem != null
                ? null
                : () => negotiate(context, c, p, freeAgent: false),
            child: const Text('再契約'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
            onPressed: car.signAndTradeProblem(p) != null || c.busy ? null : () => c.signAndTrade(p.id),
            child: const FittedBox(fit: BoxFit.scaleDown, child: Text('サイン＆トレード')),
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
        _kv('GMの格', 'Lv${car.gmLevel}(${ratingNameOf(car.gmLevel)})・通算${car.gmPoints}点', color: GmColors.gold),
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
