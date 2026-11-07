// ignore_for_file: avoid_print
import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
void main() {
  final c = careerAt(3, 12)..startSeason();
  while (c.phase == Phase.season) { c.playBlock(); }
  final all = [for (final t in c.teams) ...t.roster]..sort((a, b) => b.stats.ppg.compareTo(a.stats.ppg));
  for (final p in [...all.take(5), all[60], all[150], all.firstWhere((p) => p.pos.name == 'c')]) {
    final s = p.stats;
    print('${p.pos.short} ${s.ppg.toStringAsFixed(1)}点 ${s.mpg.toStringAsFixed(1)}分 FG ${(s.fgPct*100).toStringAsFixed(1)}% (${(s.fga/s.gp).toStringAsFixed(1)}本) 3P ${(s.tpPct*100).toStringAsFixed(1)}% (${(s.tpa/s.gp).toStringAsFixed(1)}本) FT ${(s.ftPct*100).toStringAsFixed(1)}% 奪${s.spg.toStringAsFixed(1)} ブ${s.bpg.toStringAsFixed(1)} 失${s.tpg.toStringAsFixed(1)}');
  }
  final g = c.lastGames.firstWhere((g) => g.box.isNotEmpty);
  print('box ${g.box.length} opp ${g.oppBox.length} sum pts ${g.box.fold(0, (a, b) => a + b.pts)} vs ${g.ptsOf(c.mine)}');
}
