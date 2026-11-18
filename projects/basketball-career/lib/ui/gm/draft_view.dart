import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/draft.dart';
import '../../gm/draft_show.dart';
import '../../gm/league.dart';
import '../../gm/personality.dart';
import '../../gm/player.dart';
import '../../monetization/monetization.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'draft_show_screen.dart';
import 'gm_table.dart';
import 'motion.dart';
import 'style.dart';

/// 候補の並べ方。
enum _Sort { mock, mid, board }

/// ドラフト。候補の力は幅でしか見えない。スカウトを送ると幅が狭まる。
/// 模擬ドラフトの予想順位・経歴・身体測定を見て、自分のボード(注目の印)を作る。
/// 左に候補の表、右に選んだ候補の詳しい情報とここまでの指名(2026-11-15、表の形に組み直した)。
class DraftView extends StatefulWidget {
  const DraftView({super.key, required this.c});
  final GmController c;

  @override
  State<DraftView> createState() => _DraftViewState();
}

class _DraftViewState extends State<DraftView> {
  _Sort _sort = _Sort.mock;

  /// 右の欄に出す候補(選手の id)。
  int? _sel;

  GmController get c => widget.c;

  @override
  void initState() {
    super.initState();
    // ドラフトが始まったら、まずくじの結果を見せる(シーズンごとに1度)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final car = c.career;
      if (!mounted || car == null || car.lotteryPre.isEmpty || c.lotteryShownSeason == car.season) return;
      c.lotteryShownSeason = car.season;
      Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => LotteryScreen(c: c)));
    });
  }

  /// 指名して、答え合わせと次の番までの指名を見せる。最後の指名ならドラフトのまとめへ。
  Future<void> _pick(Prospect p) async {
    final nav = Navigator.of(context);
    final car = c.career!;
    final before = car.draftLog.length;
    c.pickProspect(p);
    final since = picksSince(car, before);
    if (since.isEmpty || since.first != p) return;
    await showPickIntro(nav, p);
    if (!nav.mounted) return;
    await showPickReveal(nav, c, p, since.skip(1).toList());
    await _summaryIfOver(nav);
  }

  Future<void> _pass() async {
    final nav = Navigator.of(context);
    c.passPick();
    await _summaryIfOver(nav);
  }

  Future<void> _summaryIfOver(NavigatorState nav) async {
    if (c.career!.phase == Phase.draft || !nav.mounted) return;
    await nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => DraftSummaryScreen(c: c)));
  }

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final ranks = mockRanks(car.prospects);
    final before = car.picksBeforeMine();
    final all = car.prospects.where((p) => p.pickedBy == null).toList();
    final open = switch (_sort) {
      _Sort.mock => all..sort((a, b) => ranks[a]!.compareTo(ranks[b]!)),
      _Sort.mid => all..sort((a, b) => b.mid.compareTo(a.mid)),
      _Sort.board => [
        for (final id in car.board)
          for (final p in all)
            if (p.player.id == id) p,
      ],
    };
    // 選んでいた候補が取られたら、表の先頭へ
    final sel = all.where((p) => p.player.id == _sel).firstOrNull ?? (open.isNotEmpty ? open.first : (all.isNotEmpty ? all.first : null));
    final taken = [for (var k = car.draftLog.length - 1; k >= 0; k--) (k + 1, car.prospects[car.draftLog[k]])];
    final wide = MediaQuery.sizeOf(context).width >= 940;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(car),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _table(car, open, all.length, ranks, before, sel, wide)),
                const SizedBox(width: 8),
                SizedBox(
                  width: wide ? 270 : 220,
                  child: ListView(
                    children: [
                      if (sel != null)
                        SlideInSwitcher(
                          id: sel.player.id,
                          child: _ProspectPanel(c: c, p: sel, rank: ranks[sel]!, onPick: _pick),
                        ),
                      if (taken.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GmTable(
                          title: 'ここまでの指名(${taken.length})',
                          rowHeight: 24,
                          cols: const [
                            GmCol('順', width: 26),
                            GmCol('', width: 24),
                            GmCol('選手', flex: 1, align: TextAlign.left),
                            GmCol('位', width: 30),
                          ],
                          rows: [
                            for (final (k, p) in taken)
                              GmRow([
                                numCell('$k', color: GmColors.sub),
                                TeamBadge(team: p.pickedBy!, size: 16),
                                Text(p.player.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(p.player.pos.short, style: const TextStyle(fontSize: 10, color: GmColors.sub)),
                              ], highlight: p.pickedBy == car.mine),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ドラフトのうわさ(次の自分の指名までに取られそうな候補)。押すと全部見られる。
  List<Widget> _rumorLine(Career car) {
    final r = car.draftRumors();
    if (r.isEmpty) return const [];
    String line((int, int, Prospect) x) => '${x.$1}番 ${car.teams[x.$2].def.short}→${x.$3.player.name}${car.workedOut.contains(x.$3.player.id) ? '(ワークアウトの話が漏れた)' : ''}';
    return [
      InkWell(
        key: const Key('draft-rumors'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ドラフトのうわさ'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('次のこちらの指名までに、ほかのチームが狙っているらしい候補(当たるとは限らない)。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                  const SizedBox(height: 6),
                  for (final x in r) Text('・${line(x)}', style: const TextStyle(fontSize: 13, height: 1.5)),
                ]),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('うわさ: ${r.take(3).map(line).join('、')}${r.length > 3 ? ' ほか' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: GmColors.gold)),
        ),
      ),
    ];
  }

  /// 上の欄(指名の番・スカウトの残り・やること)。候補の表を広く見せるため細くする。知らせはたたんでおく。
  Widget _header(Career car) {
    final pick = car.currentPick;
    final before = car.picksBeforeMine();
    final myPicks = [
      for (var k = car.draftAt; k < car.order.length; k++)
        if (car.picks[car.order[k]].owner == car.mine) k + 1,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_reg_rounded, color: GmColors.ball, size: 18),
                const SizedBox(width: 6),
                Text(pick == null ? 'ドラフト' : '${car.draftAt + 1}番目の指名(${pick.round}巡目)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    myPicks.isEmpty ? 'もう指名権がない。他チームの指名が終わるまで進める' : 'こちらの番: ${myPicks.map((k) => '$k番目').join('・')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.gold),
                  ),
                ),
                const Icon(Icons.travel_explore_rounded, size: 15, color: GmColors.sub),
                const SizedBox(width: 4),
                Text('スカウト 残り${car.scoutsLeft}・ワークアウト 残り${car.workoutsLeft}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                if (car.lotteryPre.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => LotteryScreen(c: c))),
                    child: const Text('くじ', style: TextStyle(fontSize: 12)),
                  ),
                if (car.canAddScouts)
                  TextButton.icon(
                    onPressed: c.busy ? null : () => _moreScouts(context),
                    icon: Icon(c.needsAd ? Icons.smart_display_rounded : Icons.add_rounded, size: 15),
                    label: Text(c.needsAd ? '動画で+2' : '+2', style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            Text(
              [
                if (myPicks.isNotEmpty) '欲しい選手の「指名」を押す(迷ったら予想順位が高い選手)',
                if (before != null && before > 0) '次の指名までに$before人取られる(予想順位が赤い選手)',
                if (car.prepScouted > 0) 'シーズン中の下調べで${car.prepScouted}人を調査済み',
                '契約中 ${car.signedCount}人(オフは$offseasonRoster人まで・開幕までに$maxRoster人)',
              ].join('・'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: GmColors.sub, height: 1.4),
            ),
            ..._rumorLine(car),
            if (car.myTurn && car.draftProblem != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(car.draftProblem!, style: const TextStyle(color: GmColors.bad, fontSize: 12)),
                    ),
                    OutlinedButton(onPressed: _pass, child: const Text('この指名を見送る')),
                  ],
                ),
              ),
            if (car.news.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  dense: true,
                  tilePadding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(vertical: -4),
                  minTileHeight: 26,
                  title: Text('このオフの知らせ(${car.news.length})', style: const TextStyle(fontSize: 12)),
                  children: [
                    for (final n in car.news)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('・$n', style: const TextStyle(fontSize: 12, height: 1.5)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 候補の表。行を押すと右の欄に詳しく出る。☆は自分のボード。
  Widget _table(Career car, List<Prospect> open, int total, Map<Prospect, int> ranks, int? before, Prospect? sel, bool wide) {
    final canPick = car.canDraftPick && !c.busy;
    GmCol sortCol(String label, _Sort s, {double? width, int flex = 1, TextAlign align = TextAlign.center}) =>
        GmCol(label, width: width, flex: flex, align: align, sorted: _sort == s, onTap: () => setState(() => _sort = s));
    return ListView(
      children: [
        GmTable(
          title: _sort == _Sort.board ? '自分のボード(${open.length}人)' : '候補($total人)',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (s, label) in [(_Sort.mock, '予想順'), (_Sort.mid, '見込み順'), (_Sort.board, '注目だけ(${car.board.length})')])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    showCheckmark: false,
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: _sort == s,
                    onSelected: (_) => setState(() => _sort = s),
                  ),
                ),
            ],
          ),
          rowHeight: 30,
          cols: [
            sortCol('予想', _Sort.mock, width: 30),
            sortCol('☆', _Sort.board, width: 24),
            const GmCol('選手', flex: 3, align: TextAlign.left),
            const GmCol('位', width: 28),
            const GmCol('歳', width: 24),
            if (wide) const GmCol('去年 点-リ-ア', width: 86),
            sortCol('OVR', _Sort.mid, width: wide ? 82 : 66),
            GmCol('POT', width: wide ? 82 : 66),
            GmCol('', width: car.myTurn ? 124 : 70, align: TextAlign.right),
          ],
          rows: [
            for (final p in open)
              () {
                final pl = p.player;
                final rank = ranks[p]!;
                final gone = before != null && rank <= before;
                final starred = car.board.contains(pl.id);
                final st = amateurStatsOf(p);
                return GmRow(
                  [
                    numCell('$rank', color: gone ? GmColors.bad : null, bold: true),
                    InkWell(
                      onTap: c.busy ? null : () => c.toggleBoard(p),
                      child: PopIcon(
                        on: starred,
                        onIcon: Icons.star_rounded,
                        offIcon: Icons.star_border_rounded,
                        size: 18,
                        onColor: GmColors.gold,
                        offColor: GmColors.sub,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (p.scouted) ...[const SizedBox(width: 4), const PopIn(child: Tag('調査済', color: GmColors.gold))],
                      ],
                    ),
                    Text(pl.pos.short, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                    numCell('${pl.age}'),
                    if (wide) Text('${st.ppg}-${st.rpg}-${st.apg}', maxLines: 1, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
                    _RangeCell(key: ValueKey(pl.id), lo: p.ovrLo, hi: p.ovrHi),
                    _RangeCell(key: ValueKey(pl.id), lo: p.potLo, hi: p.potHi),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!p.scouted) miniButton('スカウト', car.scoutsLeft > 0 && !c.busy ? () => c.scoutProspect(p) : null),
                          if (car.myTurn) ...[const SizedBox(width: 4), miniButton('指名', canPick ? () => _pick(p) : null, filled: true)],
                        ],
                      ),
                    ),
                  ],
                  highlight: p == sel,
                  onTap: () => setState(() => _sel = pl.id),
                );
              }(),
          ],
        ),
        if (_sort == _Sort.board && open.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('候補の☆を押すと、ここに並ぶ(押した順)。', style: TextStyle(color: GmColors.sub, fontSize: 12)),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('OVR・POT は見えている幅(スカウトで狭まる)。行を押すと右に経歴・身体測定・見立て。', style: TextStyle(fontSize: 10, color: GmColors.sub)),
        ),
      ],
    );
  }

  Future<void> _moreScouts(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final g = await c.scoutsWithAd(onWaiting: () => messenger.showSnackBar(const SnackBar(content: Text('動画を読み込んでいます…'))));
    if (g == RecoverGate.unavailable) {
      messenger.showSnackBar(const SnackBar(content: Text('動画の準備ができていません。少し待ってからもう一度。')));
    }
  }
}

/// 見えている幅(数字と細い帯)。
class _RangeCell extends StatelessWidget {
  const _RangeCell({super.key, required this.lo, required this.hi});
  final int lo, hi;

  /// スカウトで幅が狭まると、数字と帯が寄っていく。
  @override
  Widget build(BuildContext context) => AnimatedRange(lo: lo, hi: hi, builder: (context, l, h) => _bar(l, h));

  Widget _bar(double lo, double hi) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${shown(lo.round())}〜${shown(hi.round())}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GmColors.ovr(hi.round())),
      ),
      LayoutBuilder(
        builder: (context, cons) {
          final w = cons.maxWidth;
          double x(double v) => w * ((v - 35) / 65).clamp(0.0, 1.0);
          return SizedBox(
            height: 4,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: GmColors.line)),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: x(lo),
                  width: (x(hi) - x(lo)).clamp(3.0, w),
                  child: Container(color: GmColors.ovr(hi.round())),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

/// 選んだ候補の詳しい情報(経歴・身体測定・去年の成績・見立て)と、注目・スカウト・指名。
class _ProspectPanel extends StatelessWidget {
  const _ProspectPanel({required this.c, required this.p, required this.rank, required this.onPick});
  final GmController c;
  final Prospect p;
  final int rank;
  final void Function(Prospect) onPick;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final pl = p.player;
    final (h, w, span) = physicalOf(pl);
    final cb = combineOf(p);
    final st = amateurStatsOf(p);
    final (good, bad) = strengthsOf(pl);
    final starred = car.board.contains(pl.id);
    Widget head(String s) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 1),
      child: Text(
        s,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GmColors.ball),
      ),
    );
    Widget line(String k, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(k, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
    Widget range(String k, int lo, int hi) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(k, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
          ),
          Expanded(
            child: AnimatedRange(
              lo: lo,
              hi: hi,
              builder: (context, l, h) => Text(
                '${shown(l.round())}〜${shown(h.round())}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GmColors.ovr(h.round())),
              ),
            ),
          ),
        ],
      ),
    );
    // スカウトすると枠が金色に光り、得意・苦手・性格が開く
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: GmColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.scouted ? GmColors.gold.withValues(alpha: 0.6) : GmColors.line, width: p.scouted ? 1.5 : 1),
        boxShadow: [if (p.scouted) BoxShadow(color: GmColors.gold.withValues(alpha: 0.18), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Tag(pl.pos.short),
            ],
          ),
          Text('${pl.age}歳・${backgroundOf(p)}・予想$rank位', maxLines: 2, style: const TextStyle(fontSize: 11, color: GmColors.sub)),
          // 媒体ごとの模擬ドラフト(同じ候補でも順位が違う)
          Text(
            '各社の予想: ${[for (var m = 0; m < mockMedia.length; m++) '${mockMedia[m]}${mediaRanks(car.prospects, m)[p] ?? '-'}位'].join('・')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: GmColors.sub),
          ),
          head('見立て'),
          range('OVR', p.ovrLo, p.ovrHi),
          range('POT', p.potLo, p.potHi),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              // 前の中身はすぐ消し、新しい中身だけを浮かび上がらせる(重なって読めなくならないように)
              switchOutCurve: const Threshold(1),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: Column(
                key: ValueKey(p.scouted),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (p.scouted) ...[
                    line('得意', good.map((a) => a.label).join('・'), color: GmColors.good),
                    line('苦手', bad.label, color: GmColors.bad),
                    line('性格', personalityOf(pl).line, color: GmColors.gold),
                    Text(
                      '${personalityOf(pl).value.text}。${personalityOf(pl).traits.map((t) => t.text).join('。')}。',
                      style: const TextStyle(fontSize: 10, color: GmColors.sub, height: 1.4),
                    ),
                  ] else ...[
                    line('得意・苦手・性格', 'スカウトで分かる'),
                    Builder(
                      builder: (_) {
                        final k = (car.me.staffLevel(Staff.scout) - 1).clamp(0, 2);
                        final om = (p.ovrLo + p.ovrHi) ~/ 2, pm = (p.potLo + p.potHi) ~/ 2;
                        return Text(
                          'いまのスカウト(段階${k + 1})なら OVR ±${shown(om + scoutOvrHalf[k]) - shown(om)}・POT ±${shown(pm + scoutPotHalf[k]) - shown(pm)} ほどまで狭まる',
                          style: const TextStyle(fontSize: 10, color: GmColors.sub, height: 1.4),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          head('コンバイン(身体測定)'),
          line('身長・体重', '${h}cm・${w}kg'),
          line('ウイングスパン', '${span}cm'),
          line('垂直跳び', '${cb.vertical}cm'),
          line('4分の3コート', '${cb.sprint}秒'),
          head('去年の成績(1試合あたり)'),
          line('得点・リバ・アシ', '${st.ppg}点 ${st.rpg}リ ${st.apg}ア'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(30), padding: EdgeInsets.zero),
                  onPressed: c.busy ? null : () => c.toggleBoard(p),
                  icon: PopIcon(on: starred, onIcon: Icons.star_rounded, offIcon: Icons.star_border_rounded, size: 16, onColor: GmColors.gold),
                  label: Text(starred ? '注目を外す' : '注目する', style: const TextStyle(fontSize: 12)),
                ),
              ),
              if (!p.scouted) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(30), padding: EdgeInsets.zero),
                    onPressed: car.scoutsLeft > 0 && !c.busy ? () => c.scoutProspect(p) : null,
                    child: Text('スカウト(残り${car.scoutsLeft})', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
          if (p.pickedBy == null && !car.workedOut.contains(p.player.id)) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              key: const Key('workout'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(30), padding: EdgeInsets.zero),
              onPressed: car.workoutsLeft > 0 && !c.busy ? () => c.workout(p) : null,
              icon: const Icon(Icons.fitness_center_rounded, size: 15),
              label: Text('ワークアウトに呼ぶ(残り${car.workoutsLeft})・正確に分かるが狙いが漏れる', style: const TextStyle(fontSize: 11.5)),
            ),
          ] else if (car.workedOut.contains(p.player.id))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('ワークアウト済み: 力は正確。ほかのチームもこの候補を高く見ている', style: TextStyle(fontSize: 11.5, color: GmColors.gold)),
            ),
          if (car.myTurn && p.pickedBy == null) ...[
            const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(34)),
              onPressed: car.canDraftPick && !c.busy ? () => onPick(p) : null,
              child: const Text('指名する', style: TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }
}
