import 'dart:math';

import 'package:basketball_career/game/advice.dart';
import 'package:basketball_career/game/dream.dart';
import 'package:basketball_career/game/epilogue.dart';
import 'package:basketball_career/game/game.dart';
import 'package:basketball_career/game/match.dart';
import 'package:basketball_career/game/path.dart';
import 'package:basketball_career/game/life.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1つの季節を進める(出来事・ハーフタイム・勝負どころは決まった選択で)。
void _step(Game g) {
  switch (g.phase) {
    case Phase.season:
      g.choose(recommendedAction(g), recommendedFocus(g.player));
    case Phase.halftime:
      g.resolveHalftime(bestHalftime(g.player, g.halftimeInfo!));
    case Phase.clutch:
      g.resolveClutch(Clutch.drive);
    case Phase.event:
      g.resolveEvent(0);
    case Phase.path:
      if (!g.chooseRoute(Route.pro) && !g.retired) g.chooseRoute(Route.university);
    case Phase.retired:
      break;
  }
}

void main() {
  const none = DreamStats(turnedPro: false, points: 0, titles: 0, honors: 0, caps: 0);

  group('夢の判定', () {
    test('数字が目標に届くとかなう。目標を超えても進み具合は1まで', () {
      expect(Dream.pro.achieved(none), isFalse);
      expect(
          Dream.pro.achieved(const DreamStats(
              turnedPro: true, points: 0, titles: 0, honors: 0, caps: 0)),
          isTrue);
      const s = DreamStats(turnedPro: false, points: 3000, titles: 9, honors: 9, caps: 5);
      for (final d in [Dream.scorer, Dream.champion, Dream.honors, Dream.national]) {
        expect(d.achieved(s), isTrue, reason: d.label);
        expect(d.progress(s), 1.0, reason: d.label);
      }
      expect(Dream.scorer.progress(const DreamStats(
          turnedPro: false, points: 750, titles: 0, honors: 0, caps: 0)), 0.5);
    });

    test('名前から読み戻せる。知らない名前はプロの舞台へ', () {
      for (final d in Dream.values) {
        expect(Dream.parse(d.name), d);
      }
      expect(Dream.parse('nonsense'), Dream.pro);
      expect(Dream.parse(null), Dream.pro);
    });

    test('かなった年齢があればそれを語り、無ければ追い続けた日々を語る', () {
      expect(dreamLine(Dream.scorer, achievedAge: 27), contains('27歳でかなった'));
      expect(dreamLine(Dream.scorer, achievedAge: 0), contains('届かなかった'));
    });

    test('どの夢にもラベル・説明・目標値がある', () {
      for (final d in Dream.values) {
        expect(d.label, isNotEmpty);
        expect(d.goalText, isNotEmpty);
        expect(d.target, greaterThan(0));
      }
    });
  });

  group('ゲームの中の夢', () {
    test('始めるときに決めた夢が保存で残り、かなった年齢も残る', () {
      final g = Game.start('x', rng: Random(3), events: false, dream: Dream.honors);
      g.dreamAge = 31;
      final back = Game.fromJson(g.toJson());
      expect(back.dream, Dream.honors);
      expect(back.dreamAge, 31);
    });

    test('古いセーブ(夢の項目なし)は「プロの舞台へ」・未達成で読める', () {
      final j = Game.start('x', rng: Random(3), events: false).toJson()
        ..remove('dream')
        ..remove('dreamAge');
      final g = Game.fromJson(j);
      expect(g.dream, Dream.pro);
      expect(g.dreamAge, 0);
    });

    test('プロ契約で夢がかなうと、1度だけ全能力+1と気持ちのごほうび。知らせは1度だけ出る', () {
      var checked = 0;
      for (var seed = 0; seed < 40 && checked < 3; seed++) {
        final g = Game.start('x', rng: Random(seed), events: false, dream: Dream.pro);
        var notes = 0;
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 600) {
          final before = g.dreamAge;
          _step(g);
          if (g.lastDreamNote != null) {
            notes++;
            expect(before, 0, reason: 'かなった瞬間だけ知らせる');
            expect(g.lastDreamNote, contains('かなった'));
          }
        }
        final turnedPro = g.records.any((r) => r.league.name.startsWith('pro'));
        if (!turnedPro) continue;
        checked++;
        expect(g.dreamAge, greaterThan(0));
        expect(notes, 1, reason: '知らせは人生で1度だけ');
        expect(g.dreamProgress, 1.0);
      }
      expect(checked, greaterThan(0), reason: 'プロ入りした人生が試した中にある');
    });

    test('かなわなかった夢はエンディングで「届かなかった」と語られる', () {
      for (var seed = 0; seed < 60; seed++) {
        final g = Game.start('x', rng: Random(seed), events: false, dream: Dream.honors);
        var guard = 0;
        while (g.phase != Phase.retired && guard++ < 600) {
          _step(g);
        }
        final text = epilogueLines(g).join('\n');
        expect(text, contains(Dream.honors.label));
        expect(text.contains('届かなかった'), g.dreamAge == 0);
        if (g.dreamAge == 0) return;
      }
    });
  });

  group('今年の成長', () {
    test('年末に「今年の成長」が出て、年のはじめの能力が保存で残る', () {
      final g = Game.start('x', rng: Random(5), events: false);
      expect(g.yearStart, isNotEmpty);
      final back = Game.fromJson(g.toJson());
      expect(back.yearStart, g.yearStart);
      var guard = 0;
      String? seen;
      while (g.phase != Phase.retired && guard++ < 80 && seen == null) {
        _step(g);
        seen = g.lastYearSummary;
      }
      expect(seen, isNotNull);
      expect(seen, startsWith('今年の成長: 総合'));
      expect(seen, contains(' → '));
    });

    test('古いセーブ(年のはじめの記録なし)でも落ちず、まとめは出さない', () {
      final j = Game.start('x', rng: Random(5), events: false).toJson()
        ..remove('yearStart');
      final g = Game.fromJson(j);
      expect(g.yearStart, isEmpty);
      var guard = 0;
      while (g.phase == Phase.season && guard++ < 4) {
        _step(g);
      }
      expect(g.lastYearSummary, isNull);
    });
  });
}
