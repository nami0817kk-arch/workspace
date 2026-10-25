// アプリ内の絵(Gemini で生成)の置き忘れを止める。
// pubspec.yaml の assets に無いと、実機では読み込めず代替の絵に戻るだけで気づきにくい。
import 'dart:io';

import 'package:basketball_career/game/life.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const arts = [
    'title',
    'ending_glory',
    'ending_quiet',
    'path',
    'hall',
    // 段階ごとの会場(育成画面の上の絵。`sceneAsset` が選ぶ)。
    'scene_minibasket',
    'scene_junior',
    'scene_high',
    'scene_university',
    'scene_corporate',
    'scene_pro',
    'scene_abroad',
    'scene_national',
  ];

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
    expect(total, lessThan(4 * 1024 * 1024), reason: '絵の合計でアプリを重くしない');
  });

  test('コードで使っている絵の名前が、置いてある絵と一致する', () {
    final used = <String>{};
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in RegExp(r"assets/art/([a-z_]+)\.jpg")
          .allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    // 会場の絵は名前を組み立てて読む(`scene_$name`)ので、別のテストで全段階を確かめる。
    used.remove('scene_');
    expect(used, arts.where((n) => !n.startsWith('scene_')).toSet());
  });

  test('どの段階でも会場の絵が決まり、その絵が置いてある', () {
    for (final lg in League.values) {
      expect(
          File('assets/art/scene_${switch (lg) {
            League.minibasket => 'minibasket',
            League.juniorHigh => 'junior',
            League.highSchool => 'high',
            League.university => 'university',
            League.corporate => 'corporate',
            League.proDomestic => 'pro',
            League.proAbroad => 'abroad',
            League.national => 'national',
          }}.jpg')
              .existsSync(),
          isTrue,
          reason: '${lg.name} の会場の絵が無い');
    }
  });

  test('ボタンのアイコンが、過ごし方・勝負どころ・ハーフタイムの全種類にある', () {
    final names = <String>[
      for (final a in Action.values) 'act_${a.name}',
      for (final c in Clutch.values) 'clutch_${c.name}',
      for (final h in Halftime.values) 'half_${h.name}',
    ];
    expect(names.length, 15);
    for (final n in names) {
      final f = File('assets/art/icons/$n.png');
      expect(f.existsSync(), isTrue, reason: '$n.png が無い');
      expect(f.lengthSync(), lessThan(60 * 1024), reason: '$n.png が重い');
    }
    expect(File('pubspec.yaml').readAsStringSync(), contains('assets/art/icons/'));
  });

  test('アイコンの元の絵は 1024x1024', () {
    final bytes = File('tool/icon_source.png').readAsBytesSync();
    // PNG の IHDR: 幅と高さは 16〜23 バイト目(ビッグエンディアン)。
    int be(int o) => (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];
    expect(be(16), 1024);
    expect(be(20), 1024);
  });
}
