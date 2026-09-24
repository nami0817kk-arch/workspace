import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/squads.dart';
import 'package:soccer_career/game/world.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';

Club clubOf(String id, {int strength = 60, String country = 'japan'}) =>
    Club(id: id, name: 'テスト', strength: strength, tier: 1, countryId: country);

void main() {
  group('クラブの名簿', () {
    test('保存しないので、同じクラブと年なら必ず同じ顔ぶれになる', () {
      final a = Squad.of(clubOf('albion-t1-c3'), year: 2030);
      final b = Squad.of(clubOf('albion-t1-c3'), year: 2030);
      expect(a.players.map((p) => p.name), b.players.map((p) => p.name));
      expect(a.players.map((p) => p.overall), b.players.map((p) => p.overall));
    });

    test('クラブが違えば別の顔ぶれになる', () {
      final a = Squad.of(clubOf('albion-t1-c3'), year: 2030);
      final b = Squad.of(clubOf('albion-t1-c4'), year: 2030);
      expect(
        a.players.map((p) => p.name).toSet(),
        isNot(b.players.map((p) => p.name).toSet()),
      );
    });

    test('25人で、どのポジションにも人が居る', () {
      final squad = Squad.of(clubOf('albion-t1-c3'), year: 2030);
      expect(squad.players, hasLength(Squad.size));
      for (final position in Position.values) {
        expect(
          squad.players.where((p) => p.position == position),
          isNotEmpty,
          reason: '${position.label} が居ない',
        );
      }
    });

    test('主力11人の平均が、クラブの強さの近くに来る', () {
      // `club.strength` は「そこで主力を張る選手の総合力」なので、
      // ここがずれると登録の判定も移籍の判定も嘘になる。
      for (final strength in [38, 55, 72, 85]) {
        final squad = Squad.of(
          clubOf('albion-t1-c3', strength: strength),
          year: 2030,
        );
        final starters = squad.starters;
        final average =
            starters.map((p) => p.overall).reduce((a, b) => a + b) /
            starters.length;
        expect(
          (average - strength).abs(),
          lessThan(6),
          reason: '強さ $strength のクラブの主力平均が $average',
        );
      }
    });

    test('歳を取ると入れ替わる。同じ選手が20年居続けない', () {
      final club = clubOf('albion-t1-c3');
      final now = Squad.of(club, year: 2030);
      final later = Squad.of(club, year: 2050);
      // **枠ごとに見る。** 名前だけで集合を比べると、
      // 別人が偶然同名になっただけで落ちる（実際に落ちた）。
      for (var i = 0; i < Squad.size; i++) {
        expect(
          later.players[i].name,
          isNot(now.players[i].name),
          reason: '$i 番目の枠に20年同じ選手が居る',
        );
      }
      // 1年では、ほとんど入れ替わらない。
      final next = Squad.of(club, year: 2031);
      var kept = 0;
      for (var i = 0; i < Squad.size; i++) {
        if (next.players[i].name == now.players[i].name) kept++;
      }
      expect(kept, greaterThan(Squad.size - 4));
    });

    test('37歳以上は名簿に残らない', () {
      for (var year = 2026; year < 2060; year++) {
        final squad = Squad.of(clubOf('albion-t1-c3'), year: year);
        for (final p in squad.players) {
          expect(p.age, inInclusiveRange(17, 36), reason: '$year 年に ${p.age}歳');
        }
      }
    });

    test('1つの名簿に同じ名前が2人入らない', () {
      for (var i = 0; i < 40; i++) {
        final squad = Squad.of(clubOf('albion-t1-c$i'), year: 2030 + i);
        final names = squad.players.map((p) => p.name).toSet();
        expect(names, hasLength(Squad.size));
      }
    });

    test('外国人は、その国の枠を超えない', () {
      for (final country in World.countries) {
        final limit = country.foreignRule.squadLimit;
        if (limit == null) continue;
        for (var i = 0; i < 6; i++) {
          final squad = Squad.of(
            clubOf(
              '${country.id}-t1-c$i',
              strength: 40 + i * 9,
              country: country.id,
            ),
            year: 2030,
          );
          expect(
            squad.foreignCount,
            lessThanOrEqualTo(limit),
            reason: '${country.name} の枠 $limit を超えている',
          );
        }
      }
    });

    test('外国人の使用数は、クラブごとに違う', () {
      // 見積もりの頃は強さから一意に決まっていたので、同じ強さなら必ず同じ数だった。
      final counts = {
        for (var i = 0; i < 12; i++)
          Squad.of(
            clubOf('albion-t1-c$i', strength: 62),
            year: 2030,
          ).foreignCount,
      };
      expect(counts.length, greaterThan(1), reason: 'どのクラブも同じ数');
    });
  });
}
