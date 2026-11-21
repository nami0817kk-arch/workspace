import 'package:flutter/material.dart';
import '../art/title_art.dart';

import '../../gm/calendar.dart';
import '../../gm/block_report.dart';
import '../../gm/career.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import 'box_score.dart';
import 'champion_screen.dart';
import 'common.dart';
import 'motion.dart';
import 'inbox_screen.dart';
import 'style.dart';

/// 試合を進めたあとの報告を画面いっぱいに出す。閉じるまで次へ進めない(流れていかないように)。
Future<void> showBlockReport(NavigatorState nav, GmController c, BlockReport? r) async {
  if (r == null || r.played == 0 || !nav.mounted) return;
  await nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => BlockReportScreen(c: c, r: r)));
}

/// 区切りの報告。この間の勝ち負け・順位の上下・見どころ・エース・起きた出来事・届いた知らせ。
class BlockReportScreen extends StatelessWidget {
  const BlockReportScreen({super.key, required this.c, required this.r});
  final GmController c;
  final BlockReport r;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final up = r.rankBefore - r.rankAfter;
    final conf = r.east ? '東地区' : '西地区';
    final waiting = r.newMail.where((m) => m.needsAnswer).length;
    final good = r.wins > r.losses;
    final mood = r.wins == r.losses
        ? '五分の成績'
        : good
            ? (r.wins >= r.played * 0.7 ? '好調!' : '勝ち越し')
            : (r.losses >= r.played * 0.7 ? '不調…' : '負け越し');
    return Scaffold(
      appBar: AppBar(
          title: Text('${dateShort(roundDate(car.season, r.fromGame - 1))}〜${dateShort(roundDate(car.season, r.toGame - 1))}の結果(${r.fromGame}〜${r.toGame}試合目)')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: [
              // いちばん大事なこと: 勝ち負けと順位
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: good ? GmColors.good : GmColors.bad, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(mood, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: good ? GmColors.good : GmColors.bad)),
                        Text('${r.wins}勝${r.losses}敗', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                        Text('通算 ${r.totalWins}勝${r.totalLosses}敗', style: const TextStyle(color: GmColors.sub)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(conf, style: const TextStyle(color: GmColors.sub, fontSize: 12)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${r.rankBefore}位', style: const TextStyle(color: GmColors.sub, fontSize: 16)),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: GmColors.sub),
                        Text('${r.rankAfter}位', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      ]),
                      Text(
                        up > 0
                            ? '$upつ上がった'
                            : up < 0
                                ? '${-up}つ下がった'
                                : '変わらず',
                        style: TextStyle(fontWeight: FontWeight.bold, color: up > 0 ? GmColors.good : up < 0 ? GmColors.bad : GmColors.sub),
                      ),
                    ]),
                  ]),
                ),
              ),
              // オーナーの目標
              _line(
                Icons.flag_rounded,
                r.pace >= r.target ? GmColors.good : GmColors.bad,
                'オーナーの目標 ${r.target}勝 → いまの勢いだと ${r.pace}勝${r.pace >= r.target ? '(届きそう)' : '(このままだと届かない)'}',
              ),
              if (r.hasChances)
                _line(
                  Icons.calculate_rounded,
                  GmColors.sub,
                  '試合前の見込みどおりなら ${r.expectedWinsOf(car.mine).toStringAsFixed(1)}勝 → 実際は ${r.wins}勝'
                  '${r.upsetWinsOf(car.mine) > 0 ? '・番狂わせの勝ち${r.upsetWinsOf(car.mine)}' : ''}'
                  '${r.letdownsOf(car.mine) > 0 ? '・取りこぼし${r.letdownsOf(car.mine)}' : ''}',
                ),
              if (r.star != null)
                _line(Icons.star_rounded, GmColors.gold, 'この間のエース: ${r.star!.$1}(${r.star!.$3}試合で平均${r.star!.$2.toStringAsFixed(1)}点)'),
              if (r.deadlinePassed) _line(Icons.lock_clock_rounded, GmColors.bad, 'トレードの締め切りを過ぎた。今季はもうトレードできない'),
              if (r.seasonOver) _line(Icons.emoji_events_rounded, GmColors.gold, 'レギュラーシーズンが終わった。次はプレーオフ'),
              if (r.deadlinePassed) ...[
                SectionTitle('締め切りまでの今季のトレード(${r.deadlineTrades.length}件)'),
                if (r.deadlineTrades.isEmpty) const Text('今季はトレードがなかった。', style: TextStyle(color: GmColors.sub)),
                for (final t in r.deadlineTrades.reversed.take(8)) _bullet(t, bold: t.contains(c.career!.me.def.short)),
                if (r.deadlineTrades.length > 8)
                  Text('ほか${r.deadlineTrades.length - 8}件(受信箱の「締め切り日のまとめ」に時間順で)', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              ],
              if (r.highlights.isNotEmpty) ...[
                const SectionTitle('見どころ'),
                for (final h in r.highlights) _bullet(h),
              ],
              if (r.myNews.isNotEmpty) ...[
                const SectionTitle('チームの出来事'),
                if (r.myNews.any((n) => n.contains('けが')))
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const EventArt('assets/art/event_injury.jpg', key: Key('event-injury')),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final n in r.myNews) _bullet(n, bold: true)])),
                  ])
                else
                  for (final n in r.myNews) _bullet(n, bold: true),
              ],
              if (r.leagueNews.isNotEmpty) ...[
                const SectionTitle('リーグの出来事'),
                for (final n in r.leagueNews.take(6)) _bullet(n),
                if (r.leagueNews.length > 6)
                  Text('ほか${r.leagueNews.length - 6}件(「リーグ」のニュースで見られる)', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
              ],
              if (r.newMail.isNotEmpty) ...[
                SectionTitle('届いた知らせ(${r.newMail.length}件)'),
                for (final m in r.newMail.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(m.needsAnswer ? Icons.mark_email_unread_rounded : Icons.mail_outline_rounded,
                          size: 18, color: m.needsAnswer ? GmColors.gold : senderColor(m.from)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (m.needsAnswer) const Tag('返事が要る'),
                    ]),
                  ),
              ],
              if (r.hasOffer)
                _line(Icons.swap_horiz_rounded, GmColors.gold, 'トレードの申し込みが届いている。閉じると、進行の画面で受けるか断るかを選べる'),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('試合ごとの結果(${r.games.length}試合)', style: const TextStyle(fontSize: 14)),
                  children: [
                    for (final g in r.games)
                      InkWell(onTap: () => showBoxScore(context, g, car.mine), child: GameRow(g: g, mine: car.mine)),
                  ],
                ),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: const BoxDecoration(color: GmColors.panelHi, border: Border(top: BorderSide(color: GmColors.line))),
            child: Row(children: [
              if (waiting > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => InboxScreen(c: c))),
                    icon: const Icon(Icons.mail_rounded),
                    label: Text('返事をする($waiting件)'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(r.seasonOver ? 'プレーオフへ' : '閉じる'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _line(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.4))),
        ]),
      );

  Widget _bullet(String t, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('・$t', style: TextStyle(fontSize: 13, height: 1.4, fontWeight: bold ? FontWeight.bold : null)),
      );
}

/// プレーオフを、自分のシリーズは1試合ずつめくって見る。自分が敗れたら、残りは結果だけ出す。
class PlayoffRunScreen extends StatefulWidget {
  const PlayoffRunScreen({super.key, required this.c});
  final GmController c;

  @override
  State<PlayoffRunScreen> createState() => _PlayoffRunScreenState();
}

class _PlayoffRunScreenState extends State<PlayoffRunScreen> with SingleTickerProviderStateMixin {
  int _series = 0;
  int _shown = 0;

  /// 流して見ている(1試合ずつ自動で出す)。接戦で止まる(2026-11-16、2K のプレーオフは1試合1行で流れ、接戦だけ入って見る)。
  bool _auto = false;

  /// 開いている試合(流れのグラフと終盤を出す)。
  int? _open;

  late final AnimationController _tick = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))
    ..addStatusListener((st) {
      if (st != AnimationStatus.completed || !mounted || !_auto) return;
      _step();
    });

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  /// 接戦(5点差以内・延長・第7戦)。
  static bool close(GameResult g, int index) => (g.homePts - g.awayPts).abs() <= 5 || g.overtimes > 0 || index == 6;

  List<Series> _mine() => [
    for (final s in widget.c.career!.playoffs)
      if (s.high == widget.c.career!.mine || s.low == widget.c.career!.mine) s,
  ];

  void _step() {
    final list = _mine();
    if (_series >= list.length) return;
    final s = list[_series];
    if (_shown >= s.games.length) {
      setState(() => _auto = false);
      return;
    }
    final i = _shown;
    setState(() {
      _shown++;
      if (close(s.games[i], i)) {
        // 接戦は止めて、流れを開いて見せる
        _auto = false;
        _open = i;
      }
    });
    if (_auto && _shown < s.games.length) _tick.forward(from: 0);
    if (_shown >= s.games.length) setState(() => _auto = false);
  }

  void _play() {
    setState(() {
      _auto = true;
      _open = null;
    });
    _step();
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    final mine = car.mine;
    final mySeries = [for (final s in car.playoffs) if (s.high == mine || s.low == mine) s];
    if (mySeries.isEmpty) return _summary(context, car, null);
    if (_series >= mySeries.length) return _summary(context, car, mySeries.last);
    final s = mySeries[_series];
    final opp = s.high == mine ? s.low : s.high;
    final games = s.games.take(_shown).toList();
    final myW = games.where((g) => g.winner == mine).length;
    final oppW = games.length - myW;
    final done = _shown >= s.games.length;
    final won = s.winner == mine;
    return Scaffold(
      appBar: AppBar(title: Text('${s.label}  vs ${car.teams[opp].name}'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    TeamBadge(team: mine, size: 40),
                    Expanded(
                      child: Column(children: [
                        Text('$myW - $oppW', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                        Text(s.need == 1 ? '1試合勝負' : '${s.need}勝で勝ち抜け', style: const TextStyle(color: GmColors.sub, fontSize: 12)),
                      ]),
                    ),
                    TeamBadge(team: opp, size: 40),
                  ]),
                ),
              ),
              if (done)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    won
                        ? '${s.label}を勝ち抜いた!'
                        : _series < mySeries.length - 1
                            ? '${s.label}で敗れた。まだもう1試合ある'
                            : '${s.label}で敗れた…',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: won ? GmColors.gold : GmColors.bad),
                  ),
                ),
              for (final (i, g) in games.indexed) ...[
                // 1試合1行。新しく出た行は横から滑り込む
                TweenAnimationBuilder<double>(
                  key: ValueKey('${_series}_$i'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(24 * (1 - t), 0), child: child),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _open = _open == i ? null : i),
                    onLongPress: () => showBoxScore(context, g, mine),
                    child: Row(children: [
                      SizedBox(width: 50, child: Text('第${i + 1}戦', style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                      Expanded(child: GameRow(g: g, mine: mine)),
                      if (close(g, i))
                        const Padding(padding: EdgeInsets.only(left: 4), child: Tag('接戦', color: GmColors.gold)),
                      Icon(_open == i ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: GmColors.sub),
                    ]),
                  ),
                ),
                if (_open == i)
                  Padding(
                    padding: const EdgeInsets.only(left: 50, bottom: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GameFlowCard(g: g, mine: mine),
                      for (final pl in g.plays.reversed.take(4).toList().reversed)
                        Text('・$pl', style: const TextStyle(fontSize: 11, height: 1.5)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => showBoxScore(context, g, mine), child: const Text('ボックススコア', style: TextStyle(fontSize: 12))),
                      ),
                    ]),
                  ),
              ],
              if (games.isNotEmpty) ...[
                for (final h in car.highlightsOf([games.last]))
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('・$h', style: const TextStyle(fontSize: 13, color: GmColors.gold))),
                const SizedBox(height: 4),
                const Text('試合を押すと流れのグラフと終盤、長押しでボックススコア。「流して見る」は接戦で止まる。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
              ],
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: const BoxDecoration(color: GmColors.panelHi, border: Border(top: BorderSide(color: GmColors.line))),
            child: Row(children: [
              if (!done) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => setState(() {
                      _auto = false;
                      _shown = s.games.length;
                    }),
                    child: const Text('シリーズの結果まで'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: _auto ? null : _play,
                    icon: const Icon(Icons.fast_forward_rounded, size: 18),
                    label: Text(_auto ? '流している…' : '流して見る'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () => setState(() {
                    _auto = false;
                    if (!done) {
                      _open = close(s.games[_shown], _shown) ? _shown : null;
                      _shown++;
                    } else {
                      _series++;
                      _shown = 0;
                      _open = null;
                    }
                  }),
                  icon: Icon(done ? Icons.arrow_forward_rounded : Icons.sports_basketball_rounded),
                  label: Text(!done
                      ? (_shown == 0 ? '第1戦を見る' : '第${_shown + 1}戦へ')
                      : _series < mySeries.length - 1
                          ? '次の戦いへ'
                          : '結果を見る'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// 最後: ファイナルの結果と、自分のチームの行き着いた所。
  Widget _summary(BuildContext context, Career car, Series? last) {
    final f = car.finals;
    final champ = car.champion == car.mine;
    return Scaffold(
      appBar: AppBar(title: const Text('プレーオフの結果'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(
            champ
                ? '優勝!'
                : last == null
                    ? 'プレーオフには出られなかった'
                    : '${last.label}で敗退',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: champ ? GmColors.gold : null),
          ),
          if (champ) ...[
            const SizedBox(height: 10),
            // 優勝の祝い(紙吹雪・ファイナルMVP・勝ち上がりの道・オーナーの言葉)
            PopIn(
              ms: 900,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: GmColors.gold, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ChampionScreen(car: car))),
                icon: const Icon(Icons.celebration_rounded),
                label: const Text('優勝パレードへ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (f != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  const Text('ファイナル', style: TextStyle(color: GmColors.sub)),
                  const SizedBox(height: 6),
                  for (final t in [f.high, f.low])
                    Row(children: [
                      TeamBadge(team: t, size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: Text(car.teams[t].name, style: TextStyle(fontWeight: f.winner == t ? FontWeight.bold : null))),
                      Text('${t == f.high ? f.highWins : f.lowWins}勝',
                          style: TextStyle(fontWeight: FontWeight.bold, color: f.winner == t ? GmColors.good : GmColors.sub)),
                    ]),
                  const SizedBox(height: 6),
                  Text('優勝: ${car.teams[f.winner].name}', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.gold)),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('シーズンの終わりへ(オーナーの評価)'),
          ),
        ]),
      ),
    );
  }
}
