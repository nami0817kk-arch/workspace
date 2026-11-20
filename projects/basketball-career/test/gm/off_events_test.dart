import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/career.dart';
import 'package:basketball_career/gm/inbox.dart';
import 'package:flutter_test/flutter_test.dart';

Career _atContracts(int seed, {int season = 12}) {
  final c = careerAt(seed, season);
  var guard = 0;
  while (c.phase != Phase.contracts) {
    if (c.phase == Phase.seasonEnd) c.fired = false;
    botStep(c);
    if (guard++ > 5000) fail('契約の場面に着かない');
  }
  return c;
}

Message? _of(Career c, MsgKind k) => c.inbox.where((m) => m.kind == k && m.season == c.season).firstOrNull;

void main() {
  test('合宿の場所: 毎オフ届き、答えで人気・相性・気持ちが動く', () {
    for (final (i, choice) in [0, 1, 2].indexed) {
      final c = _atContracts(10 + i);
      final m = _of(c, MsgKind.offCamp);
      expect(m, isNotNull);
      final (hype, chem, mood) = (c.hype, c.me.chem, [for (final p in c.me.roster) p.morale]);
      c.answer(m!.id, choice);
      switch (choice) {
        case 0:
          expect(c.hype, (hype + 3).clamp(0, 100));
        case 1:
          expect(c.me.chem, (chem + 4).clamp(0, 100));
        default:
          for (final (j, p) in c.me.roster.indexed) {
            expect(p.morale, (mood[j] + 3).clamp(0, 100));
          }
      }
    }
  });

  test('代表: 2年ごとに力のある選手が呼ばれる。送り出すと人気と気持ち、断ると気持ちが下がる', () {
    var seen = 0;
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final c = _atContracts(seed, season: 3);
      // 1年目(奇数)のオフは呼ばれない
      expect(c.season.isEven, isFalse);
      expect(_of(c, MsgKind.offNational), isNull);
      // 次のオフ(2年目)まで進める
      var guard = 0;
      while (!(c.phase == Phase.contracts && c.season.isEven)) {
        if (c.phase == Phase.seasonEnd) c.fired = false;
        botStep(c);
        if (guard++ > 5000) fail('2年目のオフに着かない');
      }
      final m = _of(c, MsgKind.offNational);
      if (m == null) continue;
      seen++;
      final p = c.me.roster.firstWhere((p) => p.id == m.player);
      final (hype, mood) = (c.hype, p.morale);
      if (seed.isEven) {
        c.answer(m.id, 0);
        expect(c.hype, (hype + 3).clamp(0, 100));
        expect(p.morale, greaterThanOrEqualTo((mood + 6).clamp(0, 100) - 0));
        expect(c.inbox.first.title, '${p.name}が代表から戻った');
      } else {
        c.answer(m.id, 1);
        expect(p.morale, (mood - 6).clamp(0, 100));
      }
    }
    expect(seen, greaterThan(0), reason: '代表に呼ばれる場面が1度はある');
  });

  test('答えないままオフを終えると、出来事は閉じる', () {
    final c = _atContracts(9);
    expect(c.inbox.where((m) => m.kind == MsgKind.offCamp && m.needsAnswer), isNotEmpty);
    c.finishContracts();
    expect(c.inbox.where((m) => const [MsgKind.offCamp, MsgKind.offNational, MsgKind.offRetire].contains(m.kind) && m.needsAnswer), isEmpty);
  });

  test('長く在籍した選手の引退で、送り出し方を聞かれる。永久欠番で人気と相性が上がる', () {
    // 30歳を超えた主力を5シーズン在籍に見せて、引退するまでオフを回す
    for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
      final c = careerAt(seed, 20);
      var guard = 0;
      Message? m;
      while (m == null && guard++ < 20000) {
        if (c.phase == Phase.seasonEnd) {
          c.fired = false;
          for (final p in c.me.roster) {
            if (p.tenure < 5) p.tenure = 5;
          }
        }
        botStep(c);
        if (c.phase == Phase.over) break;
        m = c.inbox.where((x) => x.kind == MsgKind.offRetire && x.needsAnswer).firstOrNull;
      }
      if (m == null) continue;
      final (hype, chem) = (c.hype, c.me.chem);
      c.answer(m.id, 0);
      expect(c.hype, (hype + 4).clamp(0, 100));
      expect(c.me.chem, (chem + 2).clamp(0, 100));
      expect(m.choices.first, contains('永久欠番'));
      return;
    }
    fail('引退の送り出しの場面が来ない');
  });
}
