import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/widgets/player_face_avatar.dart';

const _black = {
  'base', 'round', 'longface', 'westafrica', 'veteran', 'babyface',
  'senegal', 'ghana',
};

void main() {
  group('選手の顔', () {
    test('表から選べる部品の絵が、すべて assets/faces にある', () {
      var count = 0;
      for (final t in faceTypes) {
        for (var e = 0; e < t.eyes; e++) {
          for (var b = 0; b < faceBeardCount; b++) {
            for (final tone in t.tones) {
              final path = 'assets/faces/body/${t.name}_e${e}_b${b}_t$tone.webp';
              expect(File(path).existsSync(), isTrue, reason: path);
              count++;
            }
          }
        }
        for (final h in t.hairs) {
          for (final g in const ['', 'g']) {
            final path = 'assets/faces/hair/${t.name}_h$h$g.webp';
            expect(File(path).existsSync(), isTrue, reason: path);
          }
        }
      }
      expect(count, greaterThan(300));
      expect(faceTypes.length, 34);
    });

    test('国の表に出てくる型は、すべて型の一覧にある', () {
      final names = {for (final t in faceTypes) t.name};
      for (final table in [
        ...faceWeightsByNation.values,
        faceWeightsAfrican,
      ]) {
        for (final n in table.keys) {
          expect(names, contains(n));
        }
      }
      expect(faceWeightsByNation.keys.toSet(), LeagueTheme.values.toSet());
    });

    test('どの組み合わせでも、選ばれた絵が実在する(抜けた髪を選ばない)', () {
      final nations = [null, ...LeagueTheme.values];
      for (var i = 0; i < 600; i++) {
        final id = 'pl$i';
        for (final nation in nations) {
          for (final african in const [false, true]) {
            for (final age in const [16, 22, 27, 33, 38]) {
              final f = faceOf(id, nation: nation, age: age, african: african);
              expect(File(f.bodyAsset).existsSync(), isTrue,
                  reason: f.bodyAsset);
              final hair = f.hairAsset;
              if (hair != null) {
                expect(File(hair).existsSync(), isTrue, reason: hair);
              }
            }
          }
        }
      }
    });

    test('同じ id なら同じ顔', () {
      for (var i = 0; i < 200; i++) {
        final a = faceOf('x-$i', nation: LeagueTheme.italy, age: 28);
        final b = faceOf('x-$i', nation: LeagueTheme.italy, age: 28);
        expect(a, b);
      }
      // 実行ごとに変わらない(String.hashCode に頼っていない)。
      expect(faceHash('pl1', 1), faceHash('pl1', 1));
      expect(faceHash('abc', 0), isNot(faceHash('abd', 0)));
    });

    test('国の重みが効いている', () {
      Map<String, int> tally(LeagueTheme? nation, {bool african = false}) {
        final m = <String, int>{};
        for (var i = 0; i < 1000; i++) {
          final n = faceOf('pl$i', nation: nation, age: 25, african: african)
              .type
              .name;
          m[n] = (m[n] ?? 0) + 1;
        }
        return m;
      }

      final fr = tally(LeagueTheme.france);
      final frMain = fr.entries
          .where((e) => e.key == 'french' || _black.contains(e.key))
          .fold(0, (a, e) => a + e.value);
      expect(frMain, greaterThan(550));

      final en = tally(LeagueTheme.england);
      final top = en.entries.reduce((a, b) => a.value >= b.value ? a : b);
      expect(top.key, 'english');

      for (final (nation, main) in const [
        (LeagueTheme.spain, 'spanish'),
        (LeagueTheme.germany, 'german'),
        (LeagueTheme.italy, 'italian'),
      ]) {
        final t = tally(nation);
        expect(t.entries.reduce((a, b) => a.value >= b.value ? a : b).key,
            main);
      }

      final af = tally(LeagueTheme.france, african: true);
      for (final n in af.keys) {
        expect(faceWeightsAfrican.keys, contains(n));
      }
      // 国が分からなくても顔が出る。
      expect(tally(null).length, greaterThan(15));
    });

    test('33歳未満は白髪なし、22歳未満はひげなし、白髪は年で戻らない', () {
      for (var i = 0; i < 1000; i++) {
        final id = 'pl$i';
        for (var age = 15; age < 22; age++) {
          expect(faceOf(id, nation: LeagueTheme.spain, age: age).beard, 0);
        }
        for (var age = 15; age < 33; age++) {
          expect(faceOf(id, nation: LeagueTheme.spain, age: age).gray, isFalse);
        }
        var wasGray = false;
        for (var age = 30; age <= 42; age++) {
          final g = faceOf(id, nation: LeagueTheme.spain, age: age).gray;
          if (wasGray) expect(g, isTrue);
          wasGray = g;
        }
      }
      var grays = 0;
      for (var i = 0; i < 500; i++) {
        if (faceOf('pl$i', nation: LeagueTheme.germany, age: 37).gray) grays++;
      }
      expect(grays, greaterThan(100));
    });

    test('童顔の型は無精ひげまで', () {
      for (var i = 0; i < 3000; i++) {
        final f = faceOf('pl$i', nation: LeagueTheme.france, age: 34);
        if (f.type.lightBeard) expect(f.beard, lessThanOrEqualTo(1));
      }
    });
  });
}
