import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:basketball_career/gm/draft_show.dart';
import 'package:flutter_test/flutter_test.dart';

Career _toDraft(int strength, int seed) {
  final c = careerAt(strength, seed);
  var guard = 0;
  while (c.phase != Phase.draft && guard++ < 400) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
  }
  return c;
}

void main() {
  test('くじの結果: くじに入ったチームの数だけ並び、5番目からは成績の悪い順のまま', () {
    final c = _toDraft(28, 5);
    expect(c.phase, Phase.draft);
    final rows = lotteryRows(c);
    expect(rows.length, c.lotteryPre.length);
    expect(rows.length, greaterThanOrEqualTo(lotteryPicks));
    // 1〜4番はくじ、残りはくじ前の順(上がったチームの分だけ下がる)
    final rest = rows.skip(lotteryPicks).map((r) => r.preRank).toList();
    expect(rest, [...rest]..sort());
    expect(rows.map((r) => r.odds).fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
    // 保存して読み直しても同じ
    final back = Career.fromJson(c.toJson());
    expect(back.lotteryPre, c.lotteryPre);
  });

  test('指名すると番号が付き、評価とまとめが作れる', () {
    final c = _toDraft(28, 5);
    while (c.phase == Phase.draft) {
      botStep(c);
    }
    final picked = [for (final i in c.draftLog) c.prospects[i]];
    expect(picked.every((p) => p.pickNo != null), isTrue);
    // 指名の番号は増えていく
    final nos = picked.map((p) => p.pickNo!).toList();
    expect(nos, [...nos]..sort());
    expect(nos.first, 1);
    for (final p in picked) {
      expect(['A+', 'A', 'B', 'C', 'D'], contains(pickGrade(c.prospects, p).grade));
      expect(revealOf(p), isNotEmpty);
    }
    final s = draftSummary(c);
    expect(s.top.length, 5);
    expect(s.mine.every((p) => p.pickedBy == c.mine), isTrue);
    expect(Prospect.fromJson(picked.first.toJson()).pickNo, picked.first.pickNo);
  });

  test('本当の力の順位は1から候補の数まで、重ならない', () {
    final c = _toDraft(15, 9);
    final ranks = {for (final p in c.prospects) trueRankOf(c.prospects, p)};
    expect(ranks.length, c.prospects.length);
    expect(ranks.reduce((a, b) => a < b ? a : b), 1);
  });
}
