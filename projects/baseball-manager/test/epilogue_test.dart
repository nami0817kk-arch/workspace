import 'dart:math';

import 'package:baseball_manager/game/epilogue.dart';
import 'package:baseball_manager/game/game.dart';
import 'package:baseball_manager/game/life.dart';
import 'package:baseball_manager/game/path.dart';
import 'package:baseball_manager/game/player.dart';
import 'package:flutter_test/flutter_test.dart';

Ending _e({
  String title = '一流選手',
  bool madePro = true,
  int proYears = 15,
  bool twoWay = false,
  int rw = 0,
  int rl = 0,
  String? partner,
}) =>
    Ending(
      title: title,
      madePro: madePro,
      proYears: proYears,
      peakOverall: 70,
      championships: 1,
      wasTwoWay: twoWay,
      rivalWins: rw,
      rivalLosses: rl,
      partnerName: partner,
    );

void main() {
  test('プロになれなかった場合は、新しい道へ', () {
    final t = epilogueOf(_e(madePro: false, proYears: 0), 'ユウタ');
    expect(t, contains('新しい道'));
    expect(t, isNot(contains('ユニフォームを脱いだ')));
  });

  test('称号ごとに文が変わる', () {
    final legend = epilogueOf(_e(title: 'レジェンド'), 'ユウタ');
    final regular = epilogueOf(_e(title: 'レギュラー'), 'ユウタ');
    expect(legend, contains('語り継がれる'));
    expect(regular, contains('支えた'));
    expect(legend, isNot(regular));
  });

  test('二刀流・ライバル・結婚の一文が足される', () {
    final t =
        epilogueOf(_e(twoWay: true, rw: 8, rl: 2, partner: '宮坂 葵'), 'ユウタ');
    expect(t, contains('二刀流'));
    expect(t, contains('勝ち越し'));
    expect(t, contains('宮坂 葵'));
    final lost = epilogueOf(_e(rw: 1, rl: 9), 'ユウタ');
    expect(lost, contains('負け越した'));
  });

  test('同じ一生なら同じ文(乱数を使わない)', () {
    expect(epilogueOf(_e(), 'ユウタ'), epilogueOf(_e(), 'ユウタ'));
  });

  test('どの一生でも、空でなく、英語の識別子が出ない', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = Game.newGame(
          name: 'テスト', role: Role.values[seed % 3], rng: Random(seed));
      var n = 0;
      while (g.phase != Phase.retired && n++ < 3000) {
        g.autoSpend();
        switch (g.phase) {
          case Phase.term:
            g.choose(Plan.train, abilitiesOf(g.player.role).first);
          case Phase.event:
            g.resolveEvent(0);
          case Phase.pathChoice:
            g.chooseRoute(Course.corporate);
          case Phase.retired:
            break;
        }
      }
      final t = epilogueOf(g.ending!, g.player.name);
      expect(t.trim(), isNotEmpty);
      expect(RegExp(r'[a-z]{3,}').hasMatch(t), isFalse, reason: t);
    }
  });

  test('幼いころの憧れ・夢が、結果とつながる', () {
    final t = epilogueOf(_e(title: '一流選手'), 'ユウタ',
        childhood: {'kid-idol': 0, 'kid-dream': 1}, worldChampion: 1);
    expect(t, contains('幼いころ、豪快な選手に憧れた'));
    expect(t, contains('「世界一」という夢を、ユウタは本当に叶えた'));
    // 夢が叶っていなければ、夢の一文は出さない
    final no =
        epilogueOf(_e(title: '一流選手'), 'ユウタ', childhood: {'kid-dream': 1});
    expect(no, isNot(contains('という夢')));
    // 分かれ道を選んでいない古い記録では、何も足さない
    expect(epilogueOf(_e(), 'ユウタ'), isNot(contains('幼いころ')));
  });

  test('レア特性を持っていた一生には、その才能のひとことが出る', () {
    final t = epilogueOf(_e(title: '一流選手'), 'ユウタ',
        rareTraitLabels: const ['怪物', '強運']);
    expect(t, contains('「怪物」「強運」'));
    expect(epilogueOf(_e(title: '一流選手'), 'ユウタ'), isNot(contains('天性')));
    expect(
        epilogueOf(_e(madePro: false, proYears: 0), 'ユウタ',
            rareTraitLabels: const ['怪物']),
        isNot(contains('天性')));
  });
}
