import 'dart:io';

import 'package:basketball_career/gm/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('30チームのロゴの絵がそろっていて、256px の PNG で、合計が小さい', () {
    var total = 0;
    for (var i = 0; i < teamDefs.length; i++) {
      final f = File('assets/art/logos/team_${i.toString().padLeft(2, '0')}.png');
      expect(f.existsSync(), isTrue, reason: '${teamDefs[i].short} のロゴ');
      final bytes = f.readAsBytesSync();
      total += bytes.length;
      // PNG の頭と、横・縦の大きさ(256)
      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect([w, h], [256, 256], reason: teamDefs[i].short);
    }
    expect(total, lessThan(3 * 1024 * 1024), reason: 'アプリが重くならない');
  });
}
