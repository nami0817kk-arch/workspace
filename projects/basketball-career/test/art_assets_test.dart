// 絵の置き忘れ・名前の食い違いを止める(読み込めないと黙って空白になる)。
import 'dart:io';

import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/ui/team_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const arts = ['title', 'scene_national', 'scene_final'];

  test('アプリ内の絵がすべて assets にあり、pubspec.yaml に宣言されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    var total = 0;
    for (final n in arts) {
      final f = File('assets/art/$n.jpg');
      expect(f.existsSync(), isTrue, reason: '$n.jpg が無い');
      expect(f.lengthSync(), lessThan(400 * 1024), reason: '$n.jpg が重い');
      expect(pubspec, contains('assets/art/$n.jpg'), reason: '$n.jpg が pubspec.yaml に無い');
      total += f.lengthSync();
    }
    expect(total, lessThan(2 * 1024 * 1024), reason: '絵の合計でアプリを重くしない');
    expect(pubspec, contains('assets/art/players/'));
  });

  test('コードで使っている jpg の名前が、置いてある絵と一致する', () {
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in RegExp(r"assets/art/([a-z_]+)\.jpg").allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, arts.toSet());
  });

  test('選手の絵(4つの姿勢×ユニフォームの色)がそろう', () {
    for (final pose in ['adult', 'adult_shoot', 'adult_dunk', 'adult_defense']) {
      for (final c in TeamColor.values.map((t) => t.sprite)) {
        expect(File('assets/art/players/${pose}_$c.png').existsSync(), isTrue, reason: '${pose}_$c');
      }
    }
  });

  test('リーグの30チームすべての色に、選手の絵がある', () {
    final sprites = TeamColor.values.map((c) => c.sprite).toSet();
    for (final d in teamDefs) {
      expect(sprites, contains(d.color), reason: d.nick);
    }
  });
}
