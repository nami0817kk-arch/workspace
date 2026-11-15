import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

/// **外した手が、失点を呼ぶ**（2026-11-15）。
///
/// 以前は手を外しても評価点が下がるだけで、失点は試合開始時に決まった
/// まま動かなかった。守る選手の3つの手は種類が揃っていて、状況の重みでも
/// 差が付かなかった。差を付けられるのは外したときに何が起きるかだけ。
final _low = Attributes(
  pace: 20,
  shooting: 20,
  passing: 20,
  dribbling: 20,
  defending: 20,
  physical: 20,
  goalkeeping: 20,
);

Club _club(String id) =>
    Club(id: id, name: id, strength: 60, tier: 1, countryId: 'yamato');

MatchInProgress _match(
  Scenario scenario, {
  int minute = 30,
  List<int> conceded = const [],
  int seed = 1,
  Position position = Position.cb,
}) => MatchInProgress(
  matchday: 1,
  opponent: _club('rival'),
  home: true,
  appearance: Appearance.start,
  scenarios: [scenario],
  minutes: [minute],
  player: Player(
    name: 'P',
    age: 24,
    position: position,
    attributes: _low,
    potential: 90,
  ),
  club: _club('mine'),
  concededMinutes: conceded,
  random: Random(seed),
);

final _all = [
  for (final family in ScenarioFamily.values) ...ScenarioPool.forFamily(family),
];

/// 失敗の文が「失点にはつながらない」ことを言っている言い回し。
const _harmless = ['スローイン', '警告', '時間だけが過ぎる', '誰にも合わなかった'];

/// 失敗の文が「ボールがゴールに入った」と言い切っている言い回し。
/// 危なさの段は確率なので、言い切ると決まらなかった回に文と結果が食い違う。
const _certain = ['ネットへ', 'ネットに', '決められた', '蹴り込まれた', '流し込まれた'];

void main() {
  group('データ', () {
    test('危なさが付くのは自陣の局面だけ', () {
      for (final s in _all) {
        for (final o in s.options) {
          if (o.exposure == Exposure.none) continue;
          expect(
            s.spot.isOwnHalf,
            isTrue,
            reason: '${s.id}「${o.label}」は敵陣なのに失点の危なさがある',
          );
        }
      }
    });

    test('失敗の文と危なさの段が食い違わない', () {
      for (final s in _all) {
        for (final o in s.options) {
          if (o.exposure != Exposure.none) {
            for (final w in _harmless) {
              expect(
                o.failureText.contains(w),
                isFalse,
                reason: '${s.id}「${o.label}」は失点しうるのに「$w」と書いてある',
              );
            }
          }
          for (final w in _certain) {
            expect(
              o.failureText.contains(w),
              isFalse,
              reason: '${s.id}「${o.label}」の失敗の文が失点を言い切っている（$w）',
            );
          }
        }
      }
    });

    test('守る選手の局面では、外したときの危なさで3つの手が分かれる', () {
      // 3つとも同じ段だと、危なさは並びを変えない。種類で掛ける倍率と同じ壁。
      final defence = ScenarioPool.neutralFor(ScenarioFamily.defence)
          .where((s) => s.spot.isOwnHalf)
          .toList();
      final split = defence.where(
        (s) => {
          for (final o in s.options)
            (o.exposure, o.preventsGoal),
        }.length > 1,
      );
      expect(split.length, greaterThanOrEqualTo(defence.length - 1));
    });

    test('危ない手には、通ったときの見返りも置く', () {
      // 「通れば1点防ぐ」が無いと、守る選手は一番安全な手を押すだけになる。
      for (final family in [ScenarioFamily.goalkeeper, ScenarioFamily.defence]) {
        final prevents = ScenarioPool.forFamily(family)
            .expand((s) => s.options)
            .where((o) => o.preventsGoal && !o.isTacticalFoul);
        expect(prevents.length, greaterThanOrEqualTo(6), reason: '$family');
      }
    });
  });

  group('判定', () {
    final duel = ScenarioPool.forFamily(ScenarioFamily.defence)
        .firstWhere((s) => s.id == 'df-duel');
    final dive = duel.options.firstWhere((o) => o.label == '飛び込んで奪いに行く');

    test('外すと、そのまま失点することがある', () {
      var caused = 0, tries = 0;
      for (var seed = 0; seed < 400; seed++) {
        final m = _match(duel, seed: seed);
        final r = m.choose(dive);
        if (r.success) continue;
        tries++;
        if (m.concededMinutes.contains(30)) {
          caused++;
          expect(m.goalsCaused, 1);
          expect(r.text, contains('失点'));
        }
      }
      expect(tries, greaterThan(100));
      final rate = caused / tries;
      expect(rate, closeTo(Formulas.concedeOnChance, 0.08));
    });

    test('通ったときと危なさの無い手では、失点は増えない', () {
      final distribution = ScenarioPool.forFamily(ScenarioFamily.goalkeeper)
          .firstWhere((s) => s.id == 'gk-distribution');
      final kick = distribution.options.firstWhere((o) => o.label == '大きく蹴り出す');
      expect(kick.exposure, Exposure.none);
      for (var seed = 0; seed < 100; seed++) {
        final m = _match(distribution, seed: seed, position: Position.gk);
        m.choose(kick);
        expect(m.concededMinutes, isEmpty);
      }
    });

    test('失点が入ると、その後の局面のスコアに乗る', () {
      for (var seed = 0; seed < 400; seed++) {
        final m = _match(duel, seed: seed, conceded: [80]);
        m.choose(dive);
        if (m.goalsCaused == 0) continue;
        expect(m.concededBy(30), 1);
        expect(m.concededMinutes, [30, 80]);
        return;
      }
      fail('一度も失点しなかった');
    });

    test('渡された失点の並びを書き換えない', () {
      const given = [80];
      for (var seed = 0; seed < 50; seed++) {
        _match(duel, seed: seed, conceded: given).choose(dive);
      }
      expect(given, [80]);
    });
  });

  group('物差しと画面', () {
    test('物差しは、外して失点するぶんを引く', () {
      final duel = ScenarioPool.forFamily(ScenarioFamily.defence)
          .firstWhere((s) => s.id == 'df-duel');
      final m = _match(duel);
      for (final o in duel.options) {
        final p = m.chanceFor(o);
        final caused = (1 - p) *
            MatchInProgress.concedeChanceOf(o) *
            Formulas.ratingPerGoalCaused;
        expect(caused, lessThanOrEqualTo(0));
        if (o.exposure != Exposure.none) expect(caused, lessThan(0));
      }
    });

    test('画面の札は判定と同じ確率を出す', () {
      for (final s in _all) {
        for (final o in s.options) {
          final note = MatchInProgress.concedeNoteFor(o);
          final q = MatchInProgress.concedeChanceOf(o);
          if (q == 0) {
            expect(note, isNull);
          } else {
            expect(note, '外すと失点${(q * 100).round()}%');
          }
        }
      }
    });

    test('奪う手が消すぶんは、反則で止めるより軽く、残り時間で減る', () {
      // 反則は必ず警告を払うので重く、奪う手は通れば何も払わないので軽い。
      expect(Formulas.ratingPerStop, lessThan(Formulas.ratingPerGoalPrevented));
      final duel = ScenarioPool.forFamily(ScenarioFamily.defence)
          .firstWhere((s) => s.id == 'df-duel');
      final early = _match(duel, minute: 20, conceded: [85]);
      final late = _match(duel, minute: 88, conceded: [89]);
      // 試合開始時の失点の予定は同じ1つでも、残り時間が短いほど見込みは小さい。
      expect(
        late.concedeLaterChance(88),
        lessThan(early.concedeLaterChance(20)),
      );
    });

    test('奪う手が通って失点を消すと、評価は反則のときより軽い', () {
      final duel = ScenarioPool.forFamily(ScenarioFamily.defence)
          .firstWhere((s) => s.id == 'df-duel');
      final dive = duel.options.firstWhere((o) => o.label == '飛び込んで奪いに行く');
      for (var seed = 0; seed < 200; seed++) {
        final m = _match(duel, seed: seed, conceded: [80]);
        final r = m.choose(dive);
        if (!r.success) continue;
        expect(m.concededMinutes, isEmpty);
        final plain = _match(duel, seed: seed).choose(dive);
        expect(plain.success, isTrue);
        expect(
          r.ratingDelta - plain.ratingDelta,
          closeTo(Formulas.ratingPerStop, 1e-9),
        );
        return;
      }
      fail('一度も通らなかった');
    });

    test('段が上がるほど、決まる確率が上がる', () {
      expect(Formulas.concedeOnShot, lessThan(Formulas.concedeOnChance));
      expect(Formulas.concedeOnChance, lessThan(Formulas.concedeOnPenalty));
      expect(Formulas.concedeOnPenalty, lessThan(1));
    });
  });
}
