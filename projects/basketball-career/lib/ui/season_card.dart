import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../game/game.dart';
import '../game/money.dart';
import 'art/court.dart';
import 'labels.dart';

/// その年(`age` 歳)の成績。大会が無かった年は null。
({List<YearRecord> records, int games, double ppg, double rpg, double apg, int titles, List<String> honors, int? overallFrom, int? overallTo, String bestGame})?
    seasonOf(Game g, int age) {
  final rs = g.records.where((r) => r.age == age).toList();
  if (rs.isEmpty) return null;
  final games = rs.fold(0, (s, r) => s + r.games);
  double avg(double Function(YearRecord r) f) =>
      games == 0 ? 0 : rs.fold(0.0, (s, r) => s + f(r) * r.games) / games;
  int? overallAt(int a) {
    for (final p in g.growthLog) {
      if (p.age == a) return p.overall.round();
    }
    return null;
  }

  return (
    records: rs,
    games: games,
    ppg: avg((r) => r.ppg),
    rpg: avg((r) => r.rpg),
    apg: avg((r) => r.apg),
    titles: rs.where((r) => r.champion).length,
    honors: [for (final r in rs) ...r.honors, for (final r in rs) if (r.award != null) r.award!],
    overallFrom: overallAt(age - 1),
    overallTo: overallAt(age),
    bestGame: rs.map((r) => r.bestGame).firstWhere((b) => b.isNotEmpty, orElse: () => ''),
  );
}

/// 1年の成績を、絵入りの1枚のカードにして見せる。画像にして共有(保存)もできる。
Future<void> showSeasonCard(BuildContext context, Game game, int age) async {
  if (seasonOf(game, age) == null) return;
  final key = GlobalKey();
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(key: key, child: SeasonCard(game: game, age: age)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(), child: const Text('閉じる')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (b) => FilledButton.icon(
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('画像で共有'),
                      onPressed: () => _share(b, key, game, age),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _share(BuildContext context, GlobalKey key, Game game, int age) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  try {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('画像にできなかった');
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'season_$age.png')],
      text: '${game.player.name} $age歳のシーズン #バスケ育成',
      // iPad では共有の吹き出しの位置が要る。
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('共有できなかった。')));
  }
}

/// その年の終わりの身長(成長の記録から。無ければ今の身長)。
double _heightAt(Game g, int age) {
  for (final p in g.growthLog) {
    if (p.age == age) return p.heightCm;
  }
  return g.player.heightCm;
}

/// 成績カードの本体(共有の画像にもなる)。
class SeasonCard extends StatelessWidget {
  const SeasonCard({super.key, required this.game, required this.age});
  final Game game;
  final int age;

  @override
  Widget build(BuildContext context) {
    final s = seasonOf(game, age)!;
    final first = s.records.first;
    final champion = s.titles > 0;
    const ink = Color(0xFF2B1A12);
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink)),
              ),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6D5A50))),
            ],
          ),
        );
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: champion ? const Color(0xFFFFA000) : const Color(0xFFE0C9B8), width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 絵: その年の会場と選手(得点が多ければシュート、リバウンドが多ければディフェンス)。
          CourtHeader(
            game: game,
            height: 150,
            season: (league: first.league, age: age, heightCm: _heightAt(game, age)),
            pose: s.ppg >= s.rpg * 2 ? Pose.shoot : (s.rpg > s.apg ? Pose.defense : Pose.dribble),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$age歳のシーズン',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6D5A50))),
                      Text('${game.player.name}${game.number > 0 ? '  #${game.number}' : ''}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)),
                      Text('${leagueLabel(first.league)}・${game.player.position.label}',
                          style: const TextStyle(fontSize: 12, color: ink)),
                    ],
                  ),
                ),
                if (champion)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.emoji_events, size: 18, color: Color(0xFF8D5A00)),
                      Text(s.titles > 1 ? ' 優勝×${s.titles}' : ' 優勝',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4200))),
                    ]),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              stat('${s.games}', '試合'),
              stat(s.ppg.toStringAsFixed(1), '得点'),
              stat(s.rpg.toStringAsFixed(1), 'リバウンド'),
              stat(s.apg.toStringAsFixed(1), 'アシスト'),
            ]),
          ),
          if (s.overallFrom != null && s.overallTo != null)
            _Line(
                icon: Icons.trending_up,
                text: '総合 ${s.overallFrom} → ${s.overallTo}'
                    '(${s.overallTo! - s.overallFrom! >= 0 ? '+' : ''}${s.overallTo! - s.overallFrom!})'),
          if (s.honors.isNotEmpty) _Line(icon: Icons.military_tech, text: s.honors.join('・'), strong: true),
          if (s.bestGame.isNotEmpty) _Line(icon: Icons.star, text: 'ベストゲーム ${s.bestGame}'),
          if (game.track == Track.pro && game.salary > 0 && game.player.age == age + 1)
            _Line(icon: Icons.payments_outlined, text: '年俸 ${moneyLabel(game.salary)}'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text('#バスケ育成',
                textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Color(0xFF9C8577))),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: strong ? const Color(0xFFB26A00) : const Color(0xFF6D5A50)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                      color: strong ? const Color(0xFFB26A00) : const Color(0xFF2B1A12))),
            ),
          ],
        ),
      );
}
