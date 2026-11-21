import 'package:flutter/material.dart';

import '../../gm/trade_ledger.dart';
import '../../gm/career.dart';
import '../../gm/league.dart';
import '../../gm/player.dart';
import '../../gm/records.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'gm_table.dart';
import 'player_card.dart';
import 'style.dart';

/// リーグの歴史。歴代の優勝・年ごとの表彰・殿堂・現役の通算成績の上位。
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.c});
  final GmController c;

  Widget _tradeRow(BuildContext context, Career car, int i) {
    final t = car.myTrades[i];
    final v = tradeVerdict(car, t);
    final grade = switch (v) { null => 'まだ', 1 => '勝ち', 0 => '五分', _ => '負け' };
    final color = switch (v) { null => GmColors.sub, 1 => GmColors.good, 0 => GmColors.gold, _ => GmColors.bad };
    // 名前は描くたびに読み直す(付けたらすぐ出るように)
    return StatefulBuilder(builder: (context, setRow) => _tradeRowBody(context, car, i, t, grade, color, car.tradeNames[i], setRow));
  }

  Widget _tradeRowBody(BuildContext context, Career car, int i, MyTrade t, String grade, Color color, String? name, StateSetter setRow) {
    String side(List<(int, String, int)> ps, int picks) => [
          for (final x in ps) '${x.$2}(${shown(x.$3)}→${car.ovrNow(x.$1) == null ? '引退' : shown(car.ovrNow(x.$1)!)})',
          if (picks > 0) '指名権$picks',
        ].join('・');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 44,
          child: Text(grade, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (name != null) Text('「$name」', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GmColors.gold)),
            Text('${t.season}年目・${car.teams[t.partner].def.short}と', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            Text('出: ${side(t.give, t.givePicks)}', style: const TextStyle(fontSize: 12.5)),
            Text('入: ${side(t.get, t.getPicks)}', style: const TextStyle(fontSize: 12.5)),
          ]),
        ),
        IconButton(
          tooltip: '名前を付ける',
          icon: const Icon(Icons.edit_rounded, size: 18, color: GmColors.sub),
          onPressed: () async {
            final ctl = TextEditingController(text: name ?? '');
            final got = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('このトレードに名前を付ける'),
                content: TextField(controller: ctl, maxLength: 20, autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('やめる')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('付ける')),
                ],
              ),
            );
            if (got != null) {
              car.nameTrade(i, got);
              // 保存して、この行を描き直す
              c.touch();
              setRow(() {});
            }
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final seasons = {for (final a in car.awards) a.season}.toList()..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(title: const Text('リーグの歴史')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              children: [
                // GM の経歴(受け持ったチームごと)
                const SectionTitle('GMの経歴'),
                _card([
                  for (final r in car.gmCareer())
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        TeamBadge(team: r.team, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            car.teams[r.team].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, color: r.team == car.mine ? GmColors.ball : null),
                          ),
                        ),
                        Text(
                          '${r.from}〜${r.to}年目・${r.wins}勝${r.losses}敗・PO${r.playoffs}回${r.titles > 0 ? '・優勝${r.titles}回' : ''}',
                          style: TextStyle(fontSize: 12, color: r.titles > 0 ? GmColors.gold : GmColors.sub),
                        ),
                      ]),
                    ),
                  Text('GM の格 Lv${car.gmLevel}(通算${car.gmPoints}点)', style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                ]),
                if (car.myTrades.isNotEmpty) ...[
                  const SectionTitle('トレードの記録帳'),
                  _card([
                    () {
                      final (w, d, l) = car.tradeRecord;
                      final (best, worst) = car.tradeBestWorst;
                      String nm(int? i) => i == null ? '-' : car.tradeNames[i] ?? '${car.myTrades[i].season}年目・${car.teams[car.myTrades[i].partner].def.short}と';
                      return Text('通算 $w勝$d分$l敗・いちばんの勝ち ${nm(best)}・いちばんの負け ${nm(worst)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold));
                    }(),
                    const Text('出した選手ともらった選手の、今の値打ちで比べる(指名権は1本12)。1年たつまでは「まだ」。判定は年とともに変わる。', style: TextStyle(fontSize: 12, color: GmColors.sub)),
                    const SizedBox(height: 4),
                    for (var i = car.myTrades.length - 1; i >= 0; i--) _tradeRow(context, car, i),
                  ]),
                ],
                const SectionTitle('歴代の優勝'),
                _card([
                  if (car.champs.isEmpty) const Text('まだ優勝したチームはない。', style: TextStyle(color: GmColors.sub)),
                  for (final r in car.champs.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(width: 50, child: Text('${r[0]}年目', style: const TextStyle(color: GmColors.sub))),
                        TeamBadge(team: r[1], size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(teamDefs[r[1]].short,
                                style: TextStyle(fontWeight: FontWeight.bold, color: r[1] == car.mine ? GmColors.gold : null)),
                            Text(
                                '相手 ${teamDefs[r[2]].short}${_finalsMvp(car, r[0]) == null ? '' : '・ファイナルMVP ${_finalsMvp(car, r[0])}'}',
                                maxLines: 2,
                                style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                          ]),
                        ),
                        if (r[1] == car.mine) const Icon(Icons.emoji_events_rounded, color: GmColors.gold, size: 20),
                      ]),
                    ),
                ]),
                const SectionTitle('殿堂'),
                _card([
                  if (car.hall.isEmpty)
                    const Text('まだ殿堂に入った選手はいない。表彰やオールスターを重ねた選手が、引退すると入る。', style: TextStyle(color: GmColors.sub, height: 1.4)),
                  for (final h in car.hall.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 8),
                          child: Icon(Icons.account_balance_rounded, color: GmColors.gold, size: 20),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${h.name}(${h.pos.short})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${h.season}年目に殿堂入り・${h.seasons}シーズン${h.team < 0 ? '' : '・最後は${teamDefs[h.team].short}'}',
                                style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                            Text('通算 ${h.line}', style: const TextStyle(fontSize: 13)),
                            if (h.honors.isNotEmpty) Text(h.honors, style: const TextStyle(fontSize: 12, color: GmColors.gold)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
                const SectionTitle('カップ戦(41試合のあと、地区の上位4チームずつ)'),
                _card([
                  if (car.cupHistory.isEmpty) const Text('41試合を終えると行われる。優勝は賞金と人気。', style: TextStyle(color: GmColors.sub)),
                  for (final r in car.cupHistory.reversed.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        SizedBox(width: 56, child: Text('${r[0]}年目', style: const TextStyle(color: GmColors.sub, fontSize: 13))),
                        TeamBadge(team: r[1], size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${teamDefs[r[1]].short}(準優勝 ${teamDefs[r[2]].short})',
                              style: TextStyle(fontSize: 13, color: r[1] == car.mine ? GmColors.ball : null)),
                        ),
                      ]),
                    ),
                ]),
                const SectionTitle('永久欠番'),
                _card([
                  if (car.retiredNumbers.isEmpty) const Text('自分のチームで4シーズン以上プレーした選手が殿堂に入ると、背番号が永久欠番になる。', style: TextStyle(color: GmColors.sub, fontSize: 12)),
                  for (var i = 0; i < car.retiredNumbers.length && i < car.retiredNames.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        SizedBox(width: 44, child: Text('#${car.retiredNumbers[i][0]}', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.gold))),
                        Expanded(child: Text('${car.retiredNames[i]}(${car.retiredNumbers[i][2]}シーズン・${car.retiredNumbers[i][1]}年目に引退)', style: const TextStyle(fontSize: 13))),
                      ]),
                    ),
                ]),
                const SectionTitle('宿敵'),
                _card([
                  if (car.rival == null)
                    const Text('対戦を重ね、プレーオフで当たると決まる。', style: TextStyle(color: GmColors.sub))
                  else
                    Row(children: [
                      TeamBadge(team: car.rival!, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(car.teams[car.rival!].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(car.rivalLine(car.rival!), style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                        ]),
                      ),
                    ]),
                ]),
                const SectionTitle('記録帳'),
                _card([
                  if (car.records.isEmpty) const Text('試合を重ねると出る。破ると知らせる。', style: TextStyle(color: GmColors.sub)),
                  for (final e in recordLabels.entries)
                    if (car.records[e.key] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
                          Text('${recordText(e.key, car.records[e.key]!.value)}  ${car.records[e.key]!.name}(${car.records[e.key]!.season}年目)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                ]),
                const SectionTitle('通算成績の上位(現役)'),
                _card([
                  for (final (label, key) in <(String, int Function(Stats))>[('得点', (s) => s.pts), ('リバウンド', (s) => s.reb), ('アシスト', (s) => s.ast)]) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Text(label, style: const TextStyle(color: GmColors.ball, fontWeight: FontWeight.bold)),
                    ),
                    for (final (p, team) in car.careerLeaders(key, count: 3))
                      InkWell(
                        onTap: () => showPlayerCard(context, car, p, team),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            TeamBadge(team: team, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('${p.name}(${p.career.length}シーズン)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: team == car.mine ? GmColors.ball : null)),
                            ),
                            Text('${key(p.careerTotals)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                  ],
                  if (car.careerLeaders((s) => s.pts).isEmpty) const Text('1シーズン終えると出る。', style: TextStyle(color: GmColors.sub)),
                ]),
                for (final s in seasons) ...[
                  SectionTitle('$s年目の表彰'),
                  _card([
                    for (final a in car.awardsOf(s).where((a) => !a.kind.allLeague))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          SizedBox(width: 108, child: Text(a.kind.label, style: const TextStyle(fontSize: 12, color: GmColors.sub))),
                          TeamBadge(team: a.team, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: fitText(a.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: a.team == car.mine ? GmColors.gold : null)),
                          ),
                        ]),
                      ),
                    for (final k in AwardKind.values.where((k) => k.allLeague))
                      if (car.awardsOf(s).any((a) => a.kind == k))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(k.label, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
                            Text(
                              car.awardsOf(s).where((a) => a.kind == k).map((a) => '${a.name}(${teamDefs[a.team].short})').join('・'),
                              style: const TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ]),
                        ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _finalsMvp(Career car, int season) =>
      car.awardsOf(season).where((a) => a.kind == AwardKind.finalsMvp).map((a) => a.name).firstOrNull;

  Widget _card(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}
