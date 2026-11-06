// 絵の置き忘れ・名前の食い違いを止める(読み込めないと黙って空白になる)。
import 'dart:io';

import 'package:basketball_career/deck/cards.dart';
import 'package:basketball_career/deck/mates.dart';
import 'package:basketball_career/ui/deck/battle_screen.dart';
import 'package:basketball_career/ui/team_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const arts = ['title', 'scene_high', 'scene_university', 'scene_national', 'scene_final'];

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
    expect(pubspec, contains('assets/art/icons/'));
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

  test('どの大会・決勝でも会場の絵が決まり、その絵が置いてある', () {
    for (var s = 0; s < 3; s++) {
      for (final boss in [false, true]) {
        final path = ArenaView.sceneFor(s, boss: boss);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('選手の絵(4つの姿勢×ユニフォーム12色)がそろう', () {
    for (final pose in ['adult', 'adult_shoot', 'adult_dunk', 'adult_defense']) {
      for (final c in [...TeamColor.values.map((t) => t.sprite), 'dark']) {
        expect(File('assets/art/players/${pose}_$c.png').existsSync(), isTrue, reason: '${pose}_$c');
      }
    }
  });

  test('仲間の絵の姿勢が、置いてある絵の名前と合う', () {
    for (final m in allMates) {
      expect(File('assets/art/players/${m.sprite}_orange.png').existsSync(), isTrue, reason: m.id);
    }
  });

  test('カードの絵がすべてある', () {
    for (final c in allCards) {
      expect(File('assets/art/icons/${c.icon}.png').existsSync(), isTrue, reason: c.id);
    }
  });

  test('自分の学校(朝日)の色が決まっている', () {
    expect(teamPrefixColors['朝日'], isNotNull);
  });
}
