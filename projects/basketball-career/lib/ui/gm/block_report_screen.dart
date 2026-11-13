import 'package:flutter/material.dart';

import '../../gm/block_report.dart';
import '../../gm/career.dart';
import '../../gm/league.dart';
import '../gm_controller.dart';
import 'box_score.dart';
import 'common.dart';
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
      appBar: AppBar(title: Text('${r.fromGame}〜${r.toGame}試合目の結果')),
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

class _PlayoffRunScreenState extends State<PlayoffRunScreen> {
  int _series = 0;
  int _shown = 0;

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
                    won ? '${s.label}を勝ち抜いた!' : '${s.label}で敗れた…',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: won ? GmColors.gold : GmColors.bad),
                  ),
                ),
              for (final (i, g) in games.indexed)
                InkWell(
                  onTap: () => showBoxScore(context, g, mine),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text('第${i + 1}戦', style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                    Expanded(child: GameRow(g: g, mine: mine)),
                  ]),
                ),
              if (games.isNotEmpty) ...[
                for (final h in car.highlightsOf([games.last]))
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('・$h', style: const TextStyle(fontSize: 13, color: GmColors.gold))),
                const SizedBox(height: 4),
                const Text('試合を押すと、ボックススコアが見られる。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
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
                    onPressed: () => setState(() => _shown = s.games.length),
                    child: const Text('シリーズの結果まで'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () => setState(() {
                    if (!done) {
                      _shown++;
                    } else {
                      _series++;
                      _shown = 0;
                    }
                  }),
                  icon: Icon(done ? Icons.arrow_forward_rounded : Icons.sports_basketball_rounded),
                  label: Text(!done
                      ? (_shown == 0 ? '第1戦を見る' : '第${_shown + 1}戦へ')
                      : won && _series < mySeries.length - 1
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
