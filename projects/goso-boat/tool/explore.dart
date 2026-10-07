// 面の候補を総当たりで解き、難しさの材料を CSV で出す。
//   dart run tool/explore.dart > build/candidates.csv
// ignore_for_file: avoid_print
import 'package:goso_boat/engine/puzzle.dart';
import 'package:goso_boat/engine/rules.dart';

void main() {
  print('police,chief,dog,prisoner,boss,cuffed,cap,island,people,par,reachable,optimal');
  for (final island in [false, true]) {
    for (var cap = 2; cap <= 4; cap++) {
      for (var p = 0; p <= 6; p++) {
        for (var k = 0; k <= 2; k++) {
          if (p + k == 0) continue;
          for (var d = 0; d <= 2; d++) {
            for (var c = 0; c <= 6; c++) {
              for (var bo = 0; bo <= 2; bo++) {
                for (var h = 0; h <= 2; h++) {
                  final people = p + k + d + c + bo + 2 * h;
                  if (people > 12 || c + bo + h == 0) continue;
                  // 1面に新しい要素は2種類まで
                  final extras = [k, d, bo, h].where((n) => n > 0).length;
                  if (extras > 2) continue;
                  if (h > 0 && cap < 3) continue; // 手錠の2人＋漕ぎ手で3席要る
                  final cast = {
                    Role.police: p, Role.chief: k, Role.dog: d,
                    Role.prisoner: c, Role.boss: bo, Role.cuffed: h,
                  };
                  final a = analyze(Board.start(cast), capacity: cap, island: island);
                  if (a.par == null || a.par! < 3) continue;
                  print('$p,$k,$d,$c,$bo,$h,$cap,${island ? 1 : 0},$people,${a.par},${a.reachable},${a.optimalCount}');
                }
              }
            }
          }
        }
      }
    }
  }
}
