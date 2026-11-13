import 'package:flutter/material.dart';

import '../../gm/career.dart';
import '../../gm/draft.dart';
import '../../gm/draft_show.dart';
import '../../gm/player.dart';
import '../gm_controller.dart';
import 'common.dart';
import 'style.dart';

/// ドラフトくじの発表。1巡目の上位(くじで決まる4つ)を、4番目から1つずつ開ける。
class LotteryScreen extends StatefulWidget {
  const LotteryScreen({super.key, required this.c});
  final GmController c;

  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen> {
  /// 開けた数(下から)。
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final car = widget.c.career!;
    final rows = lotteryRows(car);
    final hidden = rows.length < lotteryPicks ? 0 : lotteryPicks - _open;
    final done = hidden <= 0;
    final mineRow = rows.where((r) => r.owner == car.mine).toList();
    final next = lotteryPicks - _open;
    return Scaffold(
      appBar: AppBar(title: Text('${car.season}年目 ドラフトくじ')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: [
              Text(
                'プレーオフに出なかった${rows.length}チームで、1〜$lotteryPicks番目の指名をくじで決める。残りは成績の悪い順。',
                style: const TextStyle(color: GmColors.sub, fontSize: 12, height: 1.5),
              ),
              if (mineRow.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('自分のチームはくじに入っていない(プレーオフに出たか、1巡目の指名権を手放している)。', style: TextStyle(color: GmColors.gold, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              for (final r in rows)
                _row(car, r, covered: r.slot <= hidden),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              if (!done)
                Expanded(
                  child: OutlinedButton(onPressed: () => setState(() => _open = lotteryPicks), child: const Text('全部開ける')),
                ),
              if (!done) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => done ? Navigator.of(context).pop() : setState(() => _open++),
                  child: Text(done ? 'ドラフトへ' : '$next番目を開ける'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(Career car, LotteryRow r, {required bool covered}) {
    final mine = r.owner == car.mine;
    final short = car.teams[r.from].def.short;
    final owner = car.teams[r.owner].def.short;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: mine && !covered ? GmColors.ball.withValues(alpha: 0.18) : GmColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mine && !covered ? GmColors.ball : (r.slot <= lotteryPicks ? GmColors.gold.withValues(alpha: 0.5) : GmColors.line)),
      ),
      child: Row(children: [
        SizedBox(width: 44, child: Text('${r.slot}番', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        if (covered) ...[
          const Icon(Icons.help_outline_rounded, color: GmColors.gold, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('まだ開けていない', style: TextStyle(color: GmColors.sub))),
        ] else ...[
          TeamBadge(team: r.from, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.owner == r.from ? short : '$short(権利は$owner)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, color: mine ? GmColors.ball : null),
            ),
          ),
          if (r.jump > 0) Tag('${r.jump}つ上がった', color: GmColors.good),
          if (r.jump < 0) Tag('${-r.jump}つ下がった', color: GmColors.bad),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              'くじ前${r.preRank}位・${(r.odds * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: GmColors.sub, fontSize: 11),
            ),
          ),
        ],
      ]),
    );
  }
}

/// 自分の指名のあと: 本当の力の答え合わせと、次の自分の番までの他チームの指名。
Future<void> showPickReveal(NavigatorState nav, GmController c, Prospect mine, List<Prospect> others) {
  final car = c.career!;
  final board = car.board.toSet();
  final g = pickGrade(car.prospects, mine);
  final pl = mine.player;
  final lost = others.where((p) => board.contains(p.player.id)).toList();
  return showDialog<void>(
    context: nav.context,
    builder: (ctx) => AlertDialog(
      title: Text('${mine.pickNo}番目で ${pl.name} を指名'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _gradeBadge(g.grade),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${pl.pos.short}・${pl.age}歳 ${revealOf(mine)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '本当の力 OVR ${shown(pl.ovr)}・POT ${shown(pl.pot)}(見えていた幅 ${shown(mine.ovrLo)}〜${shown(mine.ovrHi)}・${shown(mine.potLo)}〜${shown(mine.potHi)})',
                    style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.4),
                  ),
                  Text('評価: ${g.label}(今年の候補の中で力は${trueRankOf(car.prospects, mine)}番目)', style: const TextStyle(fontSize: 12, height: 1.4)),
                ]),
              ),
            ]),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                car.phase == Phase.draft ? '次の自分の番までに${others.length}人が指名された' : 'このあと${others.length}人が指名されてドラフトが終わった',
                style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.ball),
              ),
              if (lost.isNotEmpty)
                Text('注目していた ${lost.map((p) => p.player.name).join('・')} は取られた', style: const TextStyle(color: GmColors.bad, fontSize: 12)),
              const SizedBox(height: 4),
              for (final p in others.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(children: [
                    SizedBox(width: 36, child: Text('${p.pickNo}', style: const TextStyle(color: GmColors.sub))),
                    TeamBadge(team: p.pickedBy!, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${p.player.name}(${p.player.pos.short})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: board.contains(p.player.id) ? GmColors.bad : null),
                      ),
                    ),
                    if (board.contains(p.player.id)) const Icon(Icons.star_rounded, size: 16, color: GmColors.gold),
                  ]),
                ),
              if (others.length > 12) Text('ほか${others.length - 12}人', style: const TextStyle(color: GmColors.sub, fontSize: 12)),
            ],
          ]),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('続ける'))],
    ),
  );
}

Widget _gradeBadge(String g) {
  final color = g.startsWith('A')
      ? GmColors.good
      : g == 'B'
          ? GmColors.gold
          : GmColors.bad;
  return Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
    child: Text(g, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
  );
}

/// ドラフトが終わったときのまとめ。自分の指名の評価・上位・掘り出し物。
class DraftSummaryScreen extends StatelessWidget {
  const DraftSummaryScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) {
    final car = c.career!;
    final s = draftSummary(car);
    Widget pickLine(Prospect p, {bool grade = false, String? note}) {
      final pl = p.player;
      final g = pickGrade(car.prospects, p);
      return Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: GmColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: GmColors.line)),
        child: Row(children: [
          SizedBox(width: 44, child: Text('${p.pickNo}番', style: const TextStyle(fontWeight: FontWeight.bold))),
          TeamBadge(team: p.pickedBy!, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${pl.name}(${pl.pos.short}・${pl.age}歳)', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                note ?? 'OVR ${shown(pl.ovr)}・POT ${shown(pl.pot)}・${revealOf(p)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: GmColors.sub),
              ),
            ]),
          ),
          if (grade) ...[
            Text(g.label, style: const TextStyle(fontSize: 12, color: GmColors.sub)),
            const SizedBox(width: 8),
            Text(g.grade, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: g.grade.startsWith('A') ? GmColors.good : g.grade == 'B' ? GmColors.gold : GmColors.bad)),
          ],
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${car.season}年目 ドラフトのまとめ'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: [
              SectionTitle('自分の指名(${s.mine.length}人)'),
              if (s.mine.isEmpty)
                const Text('今年は指名しなかった。', style: TextStyle(color: GmColors.sub))
              else
                for (final p in s.mine) pickLine(p, grade: true),
              const SectionTitle('上位の指名'),
              for (final p in s.top) pickLine(p),
              if (s.steal != null || s.bust != null) const SectionTitle('今年のドラフトの話題'),
              if (s.steal != null)
                pickLine(s.steal!, note: '掘り出し物: 力は今年${trueRankOf(car.prospects, s.steal!)}番目なのに${s.steal!.pickNo}番目まで残っていた'),
              if (s.bust != null)
                pickLine(s.bust!, note: '早すぎた指名: 力は今年${trueRankOf(car.prospects, s.bust!)}番目'),
              if (s.undrafted > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('指名されなかった${s.undrafted}人は、最低年俸の自由契約に出た(補強の画面で取れる)。', style: const TextStyle(color: GmColors.sub, fontSize: 12)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('契約へ')),
            ),
          ),
        ]),
      ),
    );
  }
}
