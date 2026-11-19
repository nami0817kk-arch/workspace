import 'package:flutter/material.dart';

import '../../gm/block_report.dart';
import '../../gm/career.dart';
import '../../gm/inbox.dart';
import '../../gm/league.dart';
import '../../gm/personality.dart';
import '../../gm/player.dart';
import '../../gm/rating.dart';
import '../../gm/summer.dart';
import '../../monetization/monetization.dart';
import '../art/title_art.dart';
import '../gm_controller.dart';
import 'block_report_screen.dart';
import 'box_score.dart';
import 'calendar_screen.dart';
import 'coaches_screen.dart';
import 'common.dart';
import 'draft_show_screen.dart';
import 'gm_table.dart';
import 'inbox_screen.dart';
import 'live_game_screen.dart';
import 'negotiate_dialog.dart';
import 'offseason_show_screen.dart';
import 'opponent_card.dart';
import 'player_card.dart';
import 'skills_screen.dart';
import 'trade_show_screen.dart';
import 'style.dart';

/// 進行のタブ。いまやること・試合の結果・届いた申し込み・オフの知らせ。
class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key, required this.c, required this.goTab});
  final GmController c;
  final void Function(int) goTab;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final scene = _sceneOf(car);
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        if (scene != null) ...[SceneStrip(scene.$1, scene.$2, key: Key(scene.$1)), const SizedBox(height: 8)],
        ...switch (car.phase) {
        Phase.preseason => _preseason(context, car),
        Phase.season => _season(context, car),
        Phase.playoffs => _beforePlayoffs(context, car),
        Phase.seasonEnd => _seasonEnd(context, car),
        Phase.contracts => _contracts(context, car),
        Phase.over => _over(context, car),
        Phase.draft => const [],
      },
      ],
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

  /// いまの時期の場面の絵と名前(プレーオフ・シーズンの終わりは、それぞれの画面の絵があるので出さない)。
  (String, String)? _sceneOf(Career car) => switch (car.phase) {
        Phase.preseason => ('assets/art/scene_preseason.jpg', '${car.season}年目・開幕前'),
        Phase.season when car.block == tradeDeadlineBlock - 1 => ('assets/art/scene_deadline.jpg', 'トレードの締め切りが近い'),
        Phase.season => ('assets/art/scene_season.jpg', '${car.season}年目・シーズン ${car.roundAt}/$gamesPerSeason試合'),
        Phase.contracts => ('assets/art/scene_offseason.jpg', '${car.season}年目・オフ'),
        _ => null,
      };

  Widget _card(List<Widget> children, {Color? edge, Key? key}) => Card(
        key: key,
        shape: edge == null
            ? null
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: edge, width: 1.5)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );

  Widget _head(String t, {IconData icon = Icons.flag_rounded, Color color = GmColors.ball}) => Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
      ]);

  // ------------------------------------------------------------ シーズン前

  /// シナリオのお題と、いまの様子。
  List<Widget> _scenarioCard(Career car) {
    final s = car.scenarioOf;
    if (s == null) return const [];
    final left = s.years - car.season;
    final (text, color) = switch (car.scenarioResult) {
      1 => ('達成した', GmColors.good),
      -1 => ('果たせなかった', GmColors.bad),
      _ => (left > 0 ? '期限まであと$left年(今季を入れて${left + 1}シーズン)' : '今季が期限', GmColors.gold),
    };
    return [
      _card(edge: color, [
        _head('シナリオ: ${s.label}', icon: Icons.flag_rounded, color: color),
        const SizedBox(height: 4),
        Text(s.goal, style: const TextStyle(fontSize: 13, height: 1.4)),
        Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
      ]),
    ];
  }

  List<Widget> _preseason(BuildContext context, Career car) {
    final problem = car.startProblem;
    final rank = car.strengthRank(car.mine) + 1;
    return [
      ..._scenarioCard(car),
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
        if (car.declaredNow > 0) _kv('方針の宣言', Career.declareLabels[car.declaredNow], color: GmColors.gold),
        if (car.forecastRank > 0)
          _kv('記者の予想', '${car.me.east ? '東' : '西'}地区 ${car.forecastRank}位${switch (car.forecastBet) { 1 => '(覆すと答えた)', 2 => '(妥当と答えた)', _ => '(受信箱で答えられる)' }}'),
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
      _card(key: const Key('mentor-card'), [..._mentorSection(context, car)]),
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
          SizedBox(width: 100, child: Text(k, style: const TextStyle(fontSize: 12.5, color: GmColors.sub))),
          Expanded(child: Text(v, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color))),
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
      ..._scenarioCard(car),
      _card([
        _head(played == 0 ? '開幕' : '$played試合を終えて'),
        const SizedBox(height: 8),
        _kv('成績', '${me.wins}勝${me.losses}敗($conf ${car.confRank}位)'),
        _kv('オーナーの目標', '${car.target}勝', color: me.wins + (gamesPerSeason - played) < car.target ? GmColors.bad : null),
        _kv('トレード', deadline ? 'あと${tradeDeadlineBlock - car.block}区切りで締め切り' : '締め切りを過ぎた', color: deadline ? null : GmColors.sub),
        _todo(_seasonTodo(car)),
        const SizedBox(height: 12),
        // 進めるのは大きいボタン1つ。采配と、まとめて進める方法は横に寄せる
        Row(children: [
          if (car.nextMyGame != null) ...[
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('live-game'),
                onPressed: c.busy ? null : () => _live(context, car),
                icon: const Icon(Icons.sports_basketball_rounded, size: 18),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('1試合を采配')),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: c.busy ? null : () => _run(context, () => c.playBlock()),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('次の$next試合へ'),
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            key: const Key('sim-more'),
            tooltip: 'ほかの進め方',
            enabled: !c.busy,
            icon: const Icon(Icons.more_horiz_rounded, color: GmColors.sub),
            onSelected: (v) {
              switch (v) {
                case 'week':
                  _run(context, () => c.playWeek());
                case 'deadline':
                  _run(context, () => c.simAhead(toDeadline: true));
                case 'season':
                  _run(context, () => c.simAhead(toDeadline: false));
                case 'stops':
                  _stopsDialog(context);
              }
            },
            itemBuilder: (_) => [
              if (next > week)
                PopupMenuItem(value: 'week', child: _menuRow(Icons.calendar_view_week_rounded, week == Career.daysPerWeek ? '1週間だけ進める' : '$week試合だけ進める')),
              if (deadline) PopupMenuItem(value: 'deadline', child: _menuRow(Icons.fast_forward_rounded, 'トレードの締め切りまで')),
              PopupMenuItem(value: 'season', child: _menuRow(Icons.skip_next_rounded, 'シーズンの終わりまで')),
              const PopupMenuDivider(),
              PopupMenuItem(key: const Key('sim-stops'), value: 'stops', child: _menuRow(Icons.tune_rounded, 'まとめて進めるときに止まる場面')),
            ],
          ),
        ]),
      ]),
      if (car.form.isNotEmpty) _formCard(context, car),
      ..._offerCard(context, car),
      ..._inboxCard(context, car),
      ..._scheduleCard(context, car),
      if (car.phase == Phase.season) NextOpponentCard(car: car),
      ..._columnCard(car),
      _pressCard(car),
      ..._fanCard(car),
      _goalsCard(car),
      ..._injuryCard(car),
      ..._wearCard(car),
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
          Expanded(
            child: FilledButton(
              onPressed: () => tradeWithShow(context, c, o, () {
                final before = car.tradesDone;
                c.acceptIncoming();
                return car.tradesDone > before;
              }),
              child: const Text('受ける'),
            ),
          ),
        ]),
      ]),
    ];
  }

  /// オフにほかの GM から電話で届いたトレードの申し込み。
  List<Widget> _callCards(BuildContext context, Career car) {
    return [
      for (var i = 0; i < car.calls.length; i++)
        if (car.callValid(car.calls[i]))
          Builder(builder: (context) {
            final o = car.calls[i];
            final them = car.teams[o.partner];
            final give = car.me.roster.where((p) => o.give.contains(p.id)).toList();
            final get = them.roster.where((p) => o.get.contains(p.id)).toList();
            return _card(key: Key('call-$i'), edge: GmColors.gold, [
              _head('他チームからの電話: ${them.name}', icon: Icons.phone_in_talk_rounded, color: GmColors.gold),
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
                Expanded(child: OutlinedButton(key: Key('call-decline-$i'), onPressed: c.busy ? null : () => c.declineCall(i), child: const Text('断る'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: Key('call-accept-$i'),
                    onPressed: c.busy ? null : () => tradeWithShow(context, c, o, () => c.acceptCall(i)),
                    child: const Text('受ける'),
                  ),
                ),
              ]),
            ]);
          }),
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
  List<Widget> _scheduleCard(BuildContext context, Career car) {
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('open-calendar'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CalendarScreen(c: c))),
            icon: const Icon(Icons.calendar_month_rounded, size: 16),
            label: const Text('日程表(82試合)を見る', style: TextStyle(fontSize: 12.5)),
          ),
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

  /// 疲れがたまっている自分の選手。休ませるかをその場で決められる。
  List<Widget> _wearCard(Career car) {
    final tired = car.tiredPlayers.where((p) => p.injured == 0).take(5).toList();
    if (tired.isEmpty || car.phase != Phase.season) return const [];
    return [
      _card(edge: tired.any((p) => p.wear > wearSlumpLine) ? GmColors.bad : null, [
        _head('疲れがたまっている', icon: Icons.battery_alert_rounded, color: GmColors.gold),
        const SizedBox(height: 2),
        const Text('疲れが多いほどけがしやすく、$wearSlumpLineを超えるとシュートも落ちる。休ませると、疲れが$wearRestLineに届いた試合を1つ休む。', style: TextStyle(fontSize: 11, color: GmColors.sub, height: 1.4)),
        for (final p in tired)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Expanded(child: Text('${p.name}(${p.pos.short}・${p.age}歳)', maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('疲れ${p.wear}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p.wear > wearSlumpLine ? GmColors.bad : GmColors.gold)),
              const SizedBox(width: 8),
              FilterChip(
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(car.restIds.contains(p.id) ? '休ませる(今季${p.restGames}試合)' : '休ませる', style: const TextStyle(fontSize: 11)),
                selected: car.restIds.contains(p.id),
                onSelected: (_) => c.toggleRest(p.id),
              ),
            ]),
          ),
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
        const SizedBox(height: 10),
        const Text('施設', style: TextStyle(color: GmColors.sub, fontSize: 13)),
        for (final f in Facility.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${f.label}  ${'★' * car.facilityLevel(f)}${'☆' * (3 - car.facilityLevel(f))}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(f.text, style: const TextStyle(fontSize: 11, color: GmColors.sub, height: 1.3)),
                ]),
              ),
              const SizedBox(width: 8),
              if (car.facilityLevel(f) < 3)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: car.facilityProblem(f) != null || c.busy ? null : () => c.upgradeFacility(f),
                  child: Text('上げる ${money(facilityUpgradeCost[car.facilityLevel(f) + 1])}', style: const TextStyle(fontSize: 12)),
                ),
            ]),
          ),
        Text(
          '上げた費用は次の開幕の支出に入る(この先の分 ${money(car.facilityDebt)})。維持費 1シーズン ${money(car.facilityUpkeepTotal)}。'
          '${car.phase == Phase.preseason || car.phase == Phase.contracts ? '' : '上げられるのはシーズン前とオフの契約のとき。'}',
          style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4),
        ),
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
      const SceneStrip('assets/art/scene_playoffs.jpg', 'プレーオフ', height: 110),
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

  /// 次の自分の試合を、区切りごとに見ながら采配する。確定したら、その節を進めてボックススコアを見せる。
  Future<void> _live(BuildContext context, Career car) async {
    final calls = await showLiveGame(context, car);
    if (calls == null || !context.mounted) return;
    final before = car.lastGames.length;
    final blockBefore = car.block;
    await _run(context, () => c.playLive(calls));
    if (!context.mounted || car.block != blockBefore || car.lastGames.length <= before) return;
    await showBoxScore(context, car.lastGames.last, car.mine);
  }
  /// まとめて進めるときに止まる場面を選ぶ。
  Future<void> _stopsDialog(BuildContext context) => showDialog<void>(
        context: context,
        builder: (ctx) => ListenableBuilder(
          listenable: c,
          builder: (ctx, _) => AlertDialog(
            title: const Text('まとめて進めるときに止まる場面'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final s in SimStop.values)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.label, style: const TextStyle(fontSize: 13.5)),
                      value: c.career!.stopsOn(s),
                      onChanged: (_) => c.toggleSimStop(s),
                    ),
                  const Text('区切り(20試合ほど)ごとに見て、当てはまれば止まる。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                ]),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
          ),
        ),
      );

  /// 試合を進め、終わったら報告を画面いっぱいに出す。
  Widget _menuRow(IconData icon, String text) => Row(children: [
        Icon(icon, size: 18, color: GmColors.sub),
        const SizedBox(width: 10),
        Text(text),
      ]);

  Future<void> _run(BuildContext context, Future<BlockReport?> Function() play) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await showBlockReport(nav, c, await play());
    final why = c.simStopReason;
    if (why != null) {
      c.simStopReason = null;
      messenger.showSnackBar(SnackBar(content: Text('止まった: ${why.label}')));
    }
    final hurt = c.injuryStop;
    if (hurt == null || !nav.mounted) return;
    // 先発がけがをした: 組み直すかを聞く
    final auto = await showDialog<bool>(
      context: nav.context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.healing_rounded, color: GmColors.bad, size: 36),
        title: Text('${hurt.name}がけが'),
        content: SizedBox(
          width: 460,
          child: Text(
            '先発の${hurt.name}(${hurt.pos.short}・OVR${shown(hurt.ovr)})が${hurt.injuryText.isEmpty ? 'けがで、あと${hurt.injured}試合休む' : hurt.injuryText}。\n'
            '自動で組み直すと、けが人を順の後ろへ回し、出場時間を自動に戻す。今のままなら、決めた順と出場時間を残し、休む分は上の選手から足す。',
            style: const TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('今のまま')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('自動で組み直す')),
        ],
      ),
    );
    if (auto == true) {
      c.benchInjured();
    } else {
      c.keepRotation();
    }
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
          // ほかのチームからの誘い(2026-11-16。受けると、格と実績を持ってそのチームの GM になる)
          if (car.canTakeJob) ...[
            const SizedBox(height: 12),
            _head('ほかのチームからの誘い', icon: Icons.mark_email_unread_rounded, color: GmColors.gold),
            const SizedBox(height: 4),
            Text('GM の格 Lv${car.gmLevel}を見て、声がかかった。受けると、そのチームの GM としてオフから続ける(信頼は40から)。',
                style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
            for (final t in car.jobOffers)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  TeamBadge(team: t, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(car.teams[t].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${record(car.teams[t])}・強さ${car.strengthRank(t) + 1}位・${Outlook.of(car.strengthRank(t)).label}',
                          style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                    ]),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
                    onPressed: c.busy ? null : () => c.takeJob(t),
                    child: const Text('このチームへ'),
                  ),
                ]),
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

  /// 週ごとのリーグの話題。
  List<Widget> _columnCard(Career car) {
    final items = car.leagueColumn;
    if (items.isEmpty) return const [];
    return [
      _card([
        _head('リーグの話題', icon: Icons.campaign_rounded),
        const SizedBox(height: 6),
        for (final n in items) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('・$n', style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    ];
  }

  /// 自分の動きへのファンの反応(SNS 風)。
  List<Widget> _fanCard(Career car) {
    if (car.fanPosts.isEmpty) return const [];
    return [
      _card([
        _head('ファンの反応', icon: Icons.forum_rounded),
        const SizedBox(height: 6),
        for (final f in car.fanPosts.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.account_circle_rounded, size: 18, color: GmColors.sub),
              const SizedBox(width: 6),
              Expanded(child: Text(f.substring(f.indexOf('|') + 1), style: const TextStyle(fontSize: 13, height: 1.4))),
              const SizedBox(width: 6),
              const Icon(Icons.favorite_rounded, size: 13, color: GmColors.bad),
              Text(' ${f.substring(0, f.indexOf('|'))}', style: const TextStyle(fontSize: 11.5, color: GmColors.sub)),
            ]),
          ),
      ]),
    ];
  }

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
      _summerCard(context, car),
      ..._callCards(context, car),
      ..._fanCard(car),
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

  /// 夏の過ごし方(サマーリーグ)。
  Widget _summerCard(BuildContext context, Career car) {
    final problem = car.summerProblem;
    final players = car.summerPlayers;
    return _card(key: const Key('summer-card'), [
      _head('夏の過ごし方', icon: Icons.wb_sunny_rounded, color: GmColors.gold),
      const SizedBox(height: 6),
      if (!car.summerDone) ...[
        const Text('サマーリーグに若手(24歳まで・2年目まで)を出す。$summerGames試合で、出来が良いと少し伸びて気持ちが上がる。出た選手は性格が分かる。',
            style: TextStyle(color: GmColors.sub, fontSize: 12.5, height: 1.5)),
        if (players.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('出る選手: ${[for (final p in players) p.name].join('・')}', style: const TextStyle(fontSize: 12.5, height: 1.4)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('summer-play'),
            onPressed: c.busy || problem != null ? null : c.playSummerLeague,
            icon: const Icon(Icons.sports_basketball_rounded),
            label: const Text('サマーリーグを開く'),
          ),
        ),
        if (problem != null && players.isEmpty) Text(problem, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
      ] else ...[
        Text('サマーリーグ ${car.summerWins}勝${summerGames - car.summerWins}敗', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (final x in car.summer)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: fitText(x.name, style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 10),
              SizedBox(width: 112, child: Text('${x.pts}点 ${x.reb}リ ${x.ast}ア', style: const TextStyle(fontSize: 12.5, color: GmColors.sub))),
              SizedBox(
                width: 72,
                child: Text(summerGradeText(x.grade),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: x.grade == 'A' ? GmColors.gold : x.grade == 'D' ? GmColors.bad : GmColors.text)),
              ),
              SizedBox(width: 44, child: Text(x.delta > 0 ? 'OVR+${x.delta}' : '', style: const TextStyle(fontSize: 12, color: GmColors.good))),
            ]),
          ),
      ],
      const Divider(height: 22),
      Text('個人練習(${car.camp.length}/${car.campSlots}人)', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      const Text('オフを終えるときに、選んだ能力が上がる。若手は伸びやすく、30歳を過ぎた選手は衰えを取り戻すことがある。枠は練習施設を上げると増える。',
          style: TextStyle(color: GmColors.sub, fontSize: 12.5, height: 1.5)),
      for (final e in car.camp.entries)
        if ([...car.me.roster, ...car.me.twoWay].where((p) => p.id == e.key).firstOrNull case final p?)
          Row(children: [
            Expanded(child: fitText('${p.name}(${p.age}歳・OVR${shown(p.ovr)})', style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Text(e.value.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GmColors.gold)),
            IconButton(
              key: Key('camp-remove-${p.id}'),
              tooltip: '外す',
              visualDensity: VisualDensity.compact,
              onPressed: c.busy ? null : () => c.setCamp(p.id, null),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ]),
      if (car.camp.length < car.campSlots) ...[
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('camp-add'),
            onPressed: c.busy ? null : () => _pickCamp(context, car),
            icon: const Icon(Icons.fitness_center_rounded),
            label: const Text('練習する選手を選ぶ'),
          ),
        ),
      ],
      const Divider(height: 22),
      ..._mentorSection(context, car),
    ]);
  }

  /// 若手の指導役(ベテラン1人を若手1人に付ける)。
  List<Widget> _mentorSection(BuildContext context, Career car) {
    final pair = car.mentor.length == 2
        ? (car.me.roster.where((p) => p.id == car.mentor[0]).firstOrNull, car.me.roster.where((p) => p.id == car.mentor[1]).firstOrNull)
        : (null, null);
    final (vet, young) = pair;
    return [
      const Text('若手の指導役', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      const Text('ベテラン(29歳から)を1人、若手(24歳まで)に付ける。次のオフに若手が伸びやすくなり、ベテランは頼られて気持ちが上がる。リーダーや練習の虫だと効きやすく、問題児だと逆効果。',
          style: TextStyle(color: GmColors.sub, fontSize: 12.5, height: 1.5)),
      const SizedBox(height: 4),
      if (vet != null && young != null)
        Row(children: [
          Expanded(child: fitText('${vet.name}(${vet.age}歳) → ${young.name}(${young.age}歳)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          IconButton(
            key: const Key('mentor-clear'),
            tooltip: '外す',
            visualDensity: VisualDensity.compact,
            onPressed: c.busy ? null : c.clearMentor,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ])
      else
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('mentor-add'),
            onPressed: c.busy ? null : () => _pickMentor(context, car),
            icon: const Icon(Icons.handshake_rounded),
            label: const Text('指導役を決める'),
          ),
        ),
    ];
  }

  Future<void> _pickMentor(BuildContext context, Career car) async {
    final vets = [for (final p in car.me.roster) if (car.mentorVet(p) && !(car.phase == Phase.contracts && car.expiring.contains(p.id))) p]
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
    final youngs = [for (final p in car.me.roster) if (car.mentorYoung(p)) p]..sort((a, b) => (b.pot - b.ovr).compareTo(a.pot - a.ovr));
    if (vets.isEmpty || youngs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(vets.isEmpty ? '29歳からの選手がいない' : '24歳までの選手がいない')));
      return;
    }
    String traits(Player p) => personalityKnown(p) ? '・${personalityOf(p).traits.map((t) => t.label).join('・')}' : '・性格はまだ分からない';
    final vet = await showDialog<Player>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('指導役にするベテラン'),
        children: [
          for (final p in vets)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, p), child: Text('${p.name}(${p.pos.short}・${p.age}歳・OVR${shown(p.ovr)}${traits(p)})')),
        ],
      ),
    );
    if (vet == null || !context.mounted) return;
    final young = await showDialog<Player>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${vet.name}が教える若手'),
        children: [
          for (final p in youngs)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, p), child: Text('${p.name}(${p.pos.short}・${p.age}歳・OVR${shown(p.ovr)}・伸びしろ${p.grade})')),
        ],
      ),
    );
    if (young == null) return;
    c.setMentor(vet.id, young.id);
  }

  /// 個人練習に呼ぶ選手と、伸ばす能力を選ぶ。
  Future<void> _pickCamp(BuildContext context, Career car) async {
    final options = [
      for (final p in [...car.me.roster, ...car.me.twoWay])
        if (!car.camp.containsKey(p.id) && car.campProblem(p) == null) p
    ]..sort((a, b) => a.age.compareTo(b.age));
    final p = await showDialog<Player>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('個人練習に呼ぶ選手'),
        children: [
          if (options.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('選べる選手がいない')),
          for (final p in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text('${p.name}(${p.pos.short}・${p.age}歳・OVR${shown(p.ovr)})${p.age <= 25 && p.ovr < p.pot ? '・伸びやすい' : p.age >= 31 ? '・衰えを取り戻す' : ''}'),
            ),
        ],
      ),
    );
    if (p == null || !context.mounted) return;
    final a = await showDialog<Attr>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${p.name}に伸ばしてほしい所'),
        children: [
          for (final a in Attr.values)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, a), child: Text('${a.label}(いま${shown(p.attr(a))})')),
        ],
      ),
    );
    if (a == null) return;
    c.setCamp(p.id, a);
  }

  /// オフの「やること」の一覧。済んだものにはチェックが付き、いま手を付けるものが太字で出る。
  Widget _contractsGuide(Career car, int expiringCount) {
    final steps = <(bool, String, String)>[
      if (car.sheetPlayer != null) (false, 'オファーシートに答える', '下の「同じ条件で残す」か「見送る」を押す'),
      if (car.inbox.where((m) => m.kind == MsgKind.offTalk && m.needsAnswer).length case final n when n > 0)
        (false, '選手との面談に答える($n人)', '受信箱に、話をしたい選手から知らせが来ている。答えないままオフを終えると、考えを説明したことになる'),
      if (car.inbox.where((m) => const [MsgKind.offCamp, MsgKind.offNational, MsgKind.offRetire].contains(m.kind) && m.needsAnswer).length case final n when n > 0)
        (false, 'オフの出来事に答える($n件)', '合宿の場所・代表・引退した選手の送り出しなど。受信箱で選ぶ。答えないままオフを終えると、効き目なしで閉じる'),
      if (car.optionPending.isNotEmpty)
        (false, '新人の選択権を決める(${car.optionPending.length}人)', '「使う」なら契約が1年続く。「使わない」なら契約切れ'),
      if (expiringCount > 0)
        (false, '契約が切れた選手を決める($expiringCount人)', '残したい選手は「再契約」、いらない選手は「放す」。そのままだと出ていく')
      else
        (true, '契約が切れた選手は決め終わった', ''),
      (car.summerDone, car.summerDone ? 'サマーリーグは済んだ' : 'お好みで: サマーリーグで若手を試す', car.summerDone ? '' : '下の「夏の過ごし方」。出来が良い若手は少し伸びる'),
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
      const Text('伸びは年齢で大きく決まり、育成コーチ・練習・出場時間・性格で上下します', style: TextStyle(fontSize: 11, color: GmColors.sub)),
      const SizedBox(height: 4),
      for (final g in list)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${g.name}(${g.age}歳)${g.focus == null ? '' : '・重点 ${g.focus!.label}'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                if (g.parts.isNotEmpty)
                  Text.rich(
                    TextSpan(children: [
                      for (final (i, (l, v)) in g.parts.indexed)
                        TextSpan(
                          text: '${i == 0 ? '' : '・'}$l${v > 0 ? '+' : ''}$v',
                          style: TextStyle(color: i == 0 ? GmColors.sub : v > 0 ? GmColors.good : GmColors.bad),
                        ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
              ]),
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
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    c.finishContracts();
    if (c.career?.phase == Phase.preseason) await nav.push(MaterialPageRoute<void>(builder: (_) => OffSummaryScreen(c: c)));
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
