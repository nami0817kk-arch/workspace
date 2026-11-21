import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/gm_people.dart';
import 'package:basketball_career/gm/league.dart';
import 'package:basketball_career/gm/trade.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み T-1: 相手の GM にも見る目がある。
void main() {
  test('見る目の割合(鋭い・ふつう・甘い)', () {
    final n = {for (final e in GmEye.values) e: 0};
    for (var s = 1; s <= 40; s++) {
      for (var t = 0; t < 30; t++) {
        final e = eyeOf(gmOf(s, t));
        n[e] = n[e]! + 1;
      }
    }
    expect(n[GmEye.sharp]! / 1200, closeTo(0.3, 0.07));
    expect(n[GmEye.normal]! / 1200, closeTo(0.45, 0.07));
    expect(n[GmEye.loose]! / 1200, closeTo(0.25, 0.07));
  });

  test('見立てのずれで、選手の値打ちが変わる(高く見れば高い)', () {
    final c = careerAt(3, 12);
    final p = c.me.roster.firstWhere((p) => p.age <= 23, orElse: () => c.me.roster.first);
    final base = playerValue(p, TeamMode.rebuild);
    if (p.age <= 23 && p.pot - p.ovr >= 3) {
      expect(playerValue(p, TeamMode.rebuild, potShift: 6), greaterThan(base));
      expect(playerValue(p, TeamMode.rebuild, potShift: -6), lessThan(base));
    }
    expect(playerValue(p, TeamMode.rebuild, potShift: 0), base);
  });

  test('甘い GM ほど、こちらの若手を見るずれが大きい。相手は自分の選手と28歳以上を正しく見る', () {
    final c = careerAt(4, 12);
    final young = c.me.roster.where((p) => p.age < 28).toList();
    expect(young, isNotEmpty);
    final spread = {for (final e in GmEye.values) e: <int>[]};
    for (var t = 0; t < c.teams.length; t++) {
      if (t == c.mine) continue;
      final e = eyeOf(c.gmPerson(t));
      for (final p in young) {
        final s = c.eyeShift(t, p);
        expect(s.abs(), lessThanOrEqualTo(e.noise));
        spread[e]!.add(s.abs());
      }
      for (final p in c.teams[t].roster) {
        expect(c.eyeShift(t, p), 0);
      }
      for (final p in c.me.roster.where((p) => p.age >= 28)) {
        expect(c.eyeShift(t, p), 0);
      }
    }
    double avg(List<int> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
    if (spread[GmEye.loose]!.isNotEmpty && spread[GmEye.sharp]!.isNotEmpty) {
      expect(avg(spread[GmEye.loose]!), greaterThan(avg(spread[GmEye.sharp]!)));
    }
    expect(c.eyeKnown((c.mine + 1) % 30), isFalse);
  });
}
