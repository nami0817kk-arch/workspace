/// 切り札と、積み上げが試合を動かすこと。
///
/// 何が実際に試合を動かしているかを測った（`test/influence_sim.dart`、
/// 24キャリア・41944局面）。積み上げの側はどれも**常に少しだけ効く飾り**だった:
///
/// - 個人技: 1人あたり 2.83個（上限3）、局面の 70.2% に乗って平均 +3.1%。
///   **誰でも3つ揃い、選ぶ余地も使いどころの判断も無い。**
/// - 型: 局面の 98.2% に付いていて平均 +1.5%。
/// - 大一番: 平均 **−0.10%** ——経験が重圧を完全に打ち消していて、実質ゼロ。
/// - 相手への慣れ: 全部合わせて増減の 1.1%。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/game/scenarios.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/club.dart';
import 'package:soccer_career/models/development.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/models/season.dart';

const club = Club(id: 'a', name: 'A', strength: 60, tier: 1);
const away = Club(id: 'b', name: 'B', strength: 60, tier: 1);

MatchInProgress match({
  Development development = const Development(),
  int seed = 1,
  int scenarios = 3,
}) {
  final player = Player(
    name: 'テスト',
    age: 24,
    position: Position.cm,
    attributes: Attributes(
      pace: 70,
      shooting: 70,
      passing: 70,
      dribbling: 70,
      defending: 70,
      physical: 70,
      goalkeeping: 70,
    ),
    potential: 90,
  );
  final pool = ScenarioPool.forPosition(Position.cm).take(scenarios).toList();
  return MatchInProgress(
    matchday: 1,
    opponent: away,
    home: true,
    appearance: Appearance.start,
    scenarios: pool,
    minutes: [for (var i = 0; i < pool.length; i++) 20 + i * 20],
    player: player,
    club: club,
    development: development,
    random: Random(seed),
  );
}

/// その局面に出せる技を1つ選ぶ。
Signature? landing(MatchInProgress m) =>
    m.armable.isEmpty ? null : m.armable.first;

void main() {
  group('切り札', () {
    test('覚えていなければ構えられない', () {
      expect(match().armable, isEmpty);
    });

    test('局面に噛み合う技だけが候補になる', () {
      // どの技も持っているのに、目の前の局面に出せなければ構えられない。
      final m = match(
        development: Development(signatures: Signature.values.toList()),
      );
      final details = m.current.options.map((o) => o.detail).toSet();
      for (final signature in m.armable) {
        expect(
          details.contains(signature.detail),
          isTrue,
          reason: signature.label,
        );
      }
      expect(m.armable.length, lessThan(Signature.values.length));
    });

    test('構えると、その手だけが上がる', () {
      final m = match(
        development: Development(signatures: Signature.values.toList()),
      );
      final signature = landing(m)!;
      final option = m.current.options.firstWhere(
        (o) => o.detail == signature.detail,
      );
      final other = m.current.options.firstWhere(
        (o) => o.detail != signature.detail,
      );
      final beforeOption = m.chanceFor(option);
      final beforeOther = m.chanceFor(other);

      m.arm(signature);
      expect(
        m.chanceFor(option),
        closeTo(beforeOption + Formulas.signatureArmedBonus, 0.0001),
      );
      expect(m.chanceFor(other), beforeOther);
      // 画面に出す内訳にも、同じ値で出る。
      expect(
        m.factorsFor(option).where((f) => f.label.contains('切り札')).single.value,
        Formulas.signatureArmedBonus,
      );
    });

    test('持っていない技は構えられない', () {
      final m = match(
        development: const Development(signatures: [Signature.noLook]),
      );
      expect(m.armable.every((s) => s == Signature.noLook), isTrue);
      m.arm(Signature.knuckle);
      expect(m.armed, isNull);
    });

    test('1試合に1回だけ', () {
      final m = match(
        development: Development(signatures: Signature.values.toList()),
        seed: 5,
      );
      final signature = landing(m)!;
      m.arm(signature);
      final option = m.current.options.firstWhere(
        (o) => o.detail == signature.detail,
      );
      m.choose(option);
      expect(m.signatureSpent, isTrue);
      expect(m.armable, isEmpty, reason: '2枚目が切れてしまう');
      expect(m.armed, isNull);
    });

    test('乗らない手を選べば使わない', () {
      final m = match(
        development: Development(signatures: Signature.values.toList()),
        seed: 7,
      );
      final signature = landing(m)!;
      m.arm(signature);
      final other = m.current.options.firstWhere(
        (o) => o.detail != signature.detail,
      );
      m.choose(other);
      expect(m.signatureSpent, isFalse, reason: '選ばなかったのに使い切った');
      // 局面が変われば構えは外れる。
      expect(m.armed, isNull);
    });

    test('外すと、その試合の残りが重くなる', () {
      // 代償が無いと「乗る局面が来たら必ず構える」が正解になり、判断が消える。
      final m = match(
        development: Development(signatures: Signature.values.toList()),
        seed: 11,
      );
      m.signatureMissed = true;
      final option = m.current.options.first;
      expect(
        m.factorsFor(option).where((f) => f.label == '力んだ').single.value,
        -Formulas.signatureMissPenalty,
      );
    });

    test('自動進行も切り札を使う', () {
      // 見ないと、自動で進めるだけで個人技が飾りに戻る。
      final m = match(
        development: Development(signatures: Signature.values.toList()),
        seed: 3,
      );
      m.autoPlay(SimStyle.balanced);
      expect(m.signatureSpent, isTrue);
    });
  });

  group('積み上げが効く', () {
    test('型は上乗せではなく偏り', () {
      // +3%/−1% では「常に少しだけ効く飾り」だった（局面の98%に付いて平均+1.5%）。
      const development = Development(
        choices: {AttributeKey.passing: 40, AttributeKey.shooting: 5},
      );
      expect(development.identity, AttributeKey.passing);
      expect(development.identityBonusFor(AttributeKey.passing), 0.05);
      expect(development.identityBonusFor(AttributeKey.shooting), -0.04);
      // 何でも選ぶ選手は何者にもならない。
      const flat = Development(
        choices: {
          AttributeKey.passing: 15,
          AttributeKey.shooting: 15,
          AttributeKey.defending: 15,
          AttributeKey.dribbling: 15,
        },
      );
      expect(flat.identity, isNull);
      expect(flat.identityBonusFor(AttributeKey.passing), 0);
    });

    test('相手への慣れは、苦手を消しきれる', () {
      // 上限 0.04 では、苦手を薄めきる前にキャリアが終わっていた。
      const green = Development();
      expect(green.adaptationFor(ClubStyle.pressing), 0);
      final veteran = Development(
        choices: const {},
        faced: const {ClubStyle.pressing: 40},
      );
      expect(veteran.adaptationFor(ClubStyle.pressing), Formulas.styleMismatch);
      // 行き過ぎない（得意にはならない）。
      final ancient = Development(faced: const {ClubStyle.pressing: 400});
      expect(ancient.adaptationFor(ClubStyle.pressing), Formulas.styleMismatch);
    });

    test('慣れるのに何シーズンかかかる', () {
      // 最初の1年で消えると、「あそこは苦手だ」が成立しない。
      final oneSeason = Development(faced: const {ClubStyle.pressing: 10});
      expect(
        oneSeason.adaptationFor(ClubStyle.pressing),
        lessThan(Formulas.styleMismatch / 2),
      );
    });

    test('大一番の重圧は、経験で埋まる', () {
      // 実測で平均 −0.10% ＝ 実質ゼロだった。
      const green = Development();
      expect(green.composure, 0);
      const veteran = Development(experience: 2000);
      expect(veteran.composure, Formulas.bigMatchPressure);
      // 若い選手には、はっきり重い。
      expect(Formulas.bigMatchPressure, greaterThanOrEqualTo(0.08));
    });
  });
}
