import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/player.dart';
import 'package:basketball_career/gm/potential_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-21 の作り込み A-1: 伸びしろを幅で見せ、知るほど絞れる。
void main() {
  final c = careerAt(4, 12);
  final everyone = [for (final t in c.teams) ...t.roster];

  test('見立ての幅は、いつも本当の等級と伸びきったときの力を含む', () {
    for (final p in everyone) {
      final g = potentialGrades.indexOf(p.grade);
      for (final k in [0, 20, 35, 59, 60, 89, 90, 100]) {
        final v = potentialViewOf(p, k);
        expect(v.lo, lessThanOrEqualTo(g), reason: '${p.name} k=$k');
        expect(v.hi, greaterThanOrEqualTo(g), reason: '${p.name} k=$k');
        expect(v.potLo, lessThanOrEqualTo(shown(p.pot)));
        expect(v.potHi, greaterThanOrEqualTo(shown(p.pot)));
      }
    }
  });

  test('知るほど幅は狭くなり、前に見せた幅からはみ出さない', () {
    for (final p in everyone.where((p) => p.age < 28)) {
      PotentialView? wider;
      for (final k in [0, 30, 60, 90]) {
        final v = potentialViewOf(p, k);
        expect(v.hi - v.lo, lessThanOrEqualTo(potentialSpan(k)));
        if (wider != null) {
          expect(v.lo, greaterThanOrEqualTo(wider.lo), reason: p.name);
          expect(v.hi, lessThanOrEqualTo(wider.hi), reason: p.name);
        }
        wider = v;
      }
      expect(potentialViewOf(p, 90).exact, isTrue);
    }
  });

  test('28歳以上は、いつも正確(伸びしろなし)', () {
    for (final p in everyone.where((p) => p.age >= 28)) {
      final v = c.potentialOf(p);
      expect(v.exact, isTrue);
      expect(v.lo, 0);
    }
  });

  test('ほかのチームの若手は、はじめ幅が広く、対戦するほど絞れる(それでも正確にはならない)', () {
    final x = careerAt(5, 12)..startSeason();
    final other = [
      for (var t = 0; t < x.teams.length; t++)
        if (t != x.mine) ...x.teams[t].roster.where((p) => p.age < 24),
    ];
    expect(other, isNotEmpty);
    final young = other.first;
    expect(x.potentialOf(young).hi - x.potentialOf(young).lo, greaterThanOrEqualTo(2));
    x.seenGames[young.id] = 6;
    expect(potentialSpan(x.knowledgeOf(young)), lessThanOrEqualTo(2));
    x.seenGames[young.id] = 99;
    expect(x.potentialOf(young).exact, isFalse);
  });

  test('自分のチームの若手は、在籍と出場で正確になる', () {
    final x = careerAt(6, 12);
    final p = x.me.roster.firstWhere((p) => p.age < 28, orElse: () => x.me.roster.first);
    if (p.age >= 28) return;
    p.tenure = 0;
    final before = x.knowledgeOf(p);
    p.tenure = 2;
    expect(x.knowledgeOf(p), greaterThan(before));
    expect(x.potentialOf(p).exact, isTrue);
  });

  test('自分の試合の相手の選手を見たことにし、保存して読み直しても残る', () {
    final x = careerAt(7, 12)..startSeason();
    expect(x.seenGames, isEmpty);
    x.playBlock();
    expect(x.seenGames, isNotEmpty);
    // 自分の選手は数えない
    for (final p in x.me.roster) {
      expect(x.seenGames.containsKey(p.id), isFalse);
    }
    final y = Career.fromJson(x.toJson());
    expect(y.seenGames, x.seenGames);
  });
  test('A-2: 5人に1人くらいは見立てが外れ、外れても1段。正確に分かるときは外れない', () {
    final young = everyone.where((p) => p.age < 28).toList();
    final missed = young.where((p) => c.potentialMissOf(p) != 0).toList();
    final rate = missed.length / young.length;
    expect(rate, inInclusiveRange(0.05, 0.3));
    for (final p in missed) {
      final g = potentialGrades.indexOf(p.grade);
      final m = c.potentialMissOf(p);
      for (final k in [0, 30, 60]) {
        final v = potentialViewOf(p, k, miss: m);
        if (m > 0) {
          expect(v.lo, g + 1, reason: '${p.name} k=$k');
        } else {
          expect(v.hi, g - 1, reason: '${p.name} k=$k');
        }
      }
      final sure = potentialViewOf(p, 95, miss: m);
      expect((sure.lo, sure.hi), (g, g));
    }
  });

  test('A-2: 外れていた見立てが正確に分かったら、1度だけ知らせ、保存しても残る', () {
    // 見立てが外れている若手のいるリーグを探す
    late Career x;
    Player? p;
    for (var seed = 8; seed < 40 && p == null; seed++) {
      x = careerAt(seed, 12);
      p = x.me.roster.where((q) => q.age < 28 && x.potentialMissOf(q) != 0).firstOrNull;
    }
    if (p == null) fail('見立てが外れている若手が見つからない');
    final pl = p;
    pl.tenure = 3;
    final before = x.inbox.length;
    x.startSeason();
    expect(x.potentialRevealed, contains(pl.id));
    final mails = x.inbox.skip(before).where((m) => m.title.contains(pl.name) && m.title.contains('見立て')).toList();
    expect(mails.length, 1);
    final y = Career.fromJson(x.toJson());
    expect(y.potentialRevealed, contains(pl.id));
  });
}
