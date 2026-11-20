// ignore_for_file: avoid_print
// 試合の進め方(game_sim.dart)を測る: 強さの差ごとの勝率が winChance と合うか、チームの数字が本物のリーグに近いか。
// dart run tool/sim_check.dart
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/game_sim.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/rng.dart';

void main() {
  final c = Career.start(seed: 7);
  final teams = c.teams;
  final rng = Rng(99);
  final buckets = <int, List<double>>{}; // 差(丸め) → [勝ち, 試合, 見込みの和]
  var m0 = 0, m0n = 0;
  var n = 0, pts = 0, fga = 0, fgm = 0, tpa = 0, tpm = 0, fta = 0, reb = 0, ast = 0, tov = 0, stl = 0, blk = 0, ot = 0, margin = 0;
  for (var k = 0; k < 6000; k++) {
    final h = teams[rng.nextInt(30)];
    var a = teams[rng.nextInt(30)];
    if (a == h) a = teams[(h.index + 1) % 30];
    final hs = h.strength, as_ = a.strength;
    final s = simulateGame(h, a, Rng(rng.next()), homeStr: hs, awayStr: as_);
    final d = (hs - as_ + 1).round().clamp(-12, 12);
    final b = buckets.putIfAbsent(d, () => [0, 0, 0]);
    b[0] += s.home.pts > s.away.pts ? 1 : 0;
    b[1] += 1;
    b[2] += winChance(hs, as_);
    for (final t in [s.home, s.away]) {
      n++;
      pts += t.pts;
      for (final l in boxLinesOf(t)) {
        fga += l.fga;
        fgm += l.fgm;
        tpa += l.tpa;
        tpm += l.tpm;
        fta += l.fta;
        reb += l.reb;
        ast += l.ast;
        tov += l.tov;
        stl += l.stl;
        blk += l.blk;
      }
    }
    if (s.overtimes > 0) ot++;
    margin += (s.home.pts - s.away.pts).abs();
    if (d == 1) {
      m0n++;
      m0 += (s.home.pts - s.away.pts).abs();
    }
  }
  String f(num x) => (x / n).toStringAsFixed(1);
  print(
    '1チーム1試合: 点${f(pts)} FG${f(fgm)}/${f(fga)}(${(fgm / fga * 100).toStringAsFixed(1)}%) 3P${f(tpm)}/${f(tpa)}(${(tpm / tpa * 100).toStringAsFixed(1)}%) FT試投${f(fta)} リ${f(reb)} ア${f(ast)} ミス${f(tov)} 奪${f(stl)} ブ${f(blk)}',
  );
  print('延長 ${(ot / 6000 * 100).toStringAsFixed(1)}%  平均点差 ${(margin / 6000).toStringAsFixed(1)}');
  print('差1(互角)の平均点差 ${(m0 / m0n).toStringAsFixed(1)}');
  for (final d in buckets.keys.toList()..sort()) {
    final b = buckets[d]!;
    if (b[1] < 60) continue;
    print(
      '差${d.toString().padLeft(3)}  実際${(b[0] / b[1] * 100).toStringAsFixed(0).padLeft(3)}%  見込み${(b[2] / b[1] * 100).toStringAsFixed(0).padLeft(3)}%  (${b[1].toInt()}試合)',
    );
  }
}
