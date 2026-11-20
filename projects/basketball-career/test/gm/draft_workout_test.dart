import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/draft.dart';
import 'package:flutter_test/flutter_test.dart';

Career _myTurn(int seed) {
  final c = careerAt(seed, 27);
  var guard = 0;
  while (!(c.phase == Phase.draft && c.myTurn) && guard++ < 400) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
  }
  expect(c.myTurn, isTrue);
  return c;
}

void main() {
  test('ワークアウトに呼ぶと力が正確に分かり、2回まで。保存される', () {
    final c = _myTurn(7);
    expect(c.workoutsLeft, Career.workoutsPerDraft);
    final open = c.prospects.where((p) => p.pickedBy == null).toList();
    final p = open[3];
    c.workout(p);
    expect((p.ovrLo, p.ovrHi, p.potLo, p.potHi), (p.player.ovr, p.player.ovr, p.player.pot, p.player.pot));
    expect(p.scouted, isTrue);
    c.workout(open[4]);
    c.workout(open[5]);
    expect(c.workedOut.length, 2);
    expect(c.workoutsLeft, 0);
    final back = Career.fromJson(c.toJson());
    expect(back.workedOut, c.workedOut);
    expect(back.workoutsLeft, 0);
  });

  test('うわさは自分の次の指名までのほかのチームの番を並べ、ワークアウトした候補は狙われやすくなる', () {
    final c = _myTurn(7);
    final before = c.draftRumors();
    for (final (no, team, _) in before) {
      expect(team, isNot(c.mine));
      expect(no, greaterThan(c.draftAt + 1));
    }
    // 見ても何も変わらない(乱数を使わない)
    expect(c.draftRumors().map((x) => x.$3.player.id).toList(), before.map((x) => x.$3.player.id).toList());
    if (before.isEmpty) return;
    // うわさに出ていない候補をワークアウトすると、その候補が高く見られる
    final rumored = {for (final x in before) x.$3.player.id};
    final open = c.prospects.where((p) => p.pickedBy == null && !rumored.contains(p.player.id)).toList();
    final target = open.first;
    final scoreBefore = aiDraftGuess([target], c.teams[before.first.$2].mode)!;
    expect(scoreBefore, target);
    c.workout(target);
    final after = c.draftRumors();
    expect(after.length, before.length);
  });

  test('ワークアウトの印は、ほかのチームの見込みを上げる(僅差の2番手が1番手になる)', () {
    final c = _myTurn(9);
    final open = c.prospects.where((p) => p.pickedBy == null).toList();
    final t = c.teams.firstWhere((t) => t.index != c.mine);
    final ranked = [...open]..sort((a, b) => aiDraftScore(b, t.mode).compareTo(aiDraftScore(a, t.mode)));
    final top = ranked[0];
    final close = ranked.skip(1).firstWhere((p) => aiDraftScore(top, t.mode) - aiDraftScore(p, t.mode) < wantedBonus);
    expect(aiDraftGuess(open, t.mode), top);
    expect(aiDraftGuess(open, t.mode, wanted: {close.player.id}), close);
  });
}
