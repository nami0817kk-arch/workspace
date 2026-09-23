/// **怪我からの戻し方。**
///
/// 実測（14キャリアずつ）で「慎重に」は選ぶ理由が無かった——標準より
/// 離脱が68試合増えるのに、怪我は 18.6 → 21.4 と減りもせず、重傷の数も同じ。
/// 「後を引かない」と書いてあるのに、後を引かない仕組みが無かった。
///
/// しかも**離脱の長さは怪我をした瞬間に決まっていた**ので、画面に3択が
/// 出ている時点ではもう動かせなかった。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_career/data/save_repository.dart';
import 'package:soccer_career/game/career_engine.dart';
import 'package:soccer_career/game/formulas.dart';
import 'package:soccer_career/game/match_engine.dart';
import 'package:soccer_career/models/agent.dart';
import 'package:soccer_career/models/attributes.dart';
import 'package:soccer_career/models/career.dart';
import 'package:soccer_career/models/entourage.dart';
import 'package:soccer_career/models/injury.dart';
import 'package:soccer_career/models/player.dart';
import 'package:soccer_career/state/career_controller.dart';

class _Repo implements SaveRepository {
  @override
  Future<CareerState?> load() async => null;
  @override
  Future<void> save(CareerState state) async {}
  @override
  Future<void> clear() async {}
}

Future<CareerController> _started() async {
  final c = CareerController(
    repository: _Repo(),
    careerEngine: CareerEngine(random: Random(4)),
    matchEngine: MatchEngine(random: Random(4)),
    random: Random(4),
  );
  await c.startCareer(
    name: 'T',
    position: Position.cm,
    age: 24,
    agent: Agent.pool.first,
  );
  return c;
}

void main() {
  group('戻し方を変えたら、残りもその場で動く', () {
    test('慎重にすれば延び、強行すれば縮む', () async {
      final c = await _started();
      c.state!.injury = const Injury(
        name: '肉離れ',
        severity: InjurySeverity.moderate,
        matchesOut: 10,
      );
      c.state!.rehab = RehabPlan.standard;

      await c.setRehab(RehabPlan.cautious);
      final longer = c.state!.injury!.matchesOut;
      expect(longer, greaterThan(10));

      await c.setRehab(RehabPlan.rush);
      // 慎重のぶんを戻して、強行の倍率を掛け直す。
      expect(
        c.state!.injury!.matchesOut,
        (longer * RehabPlan.rush.lengthFactor / RehabPlan.cautious.lengthFactor)
            .round(),
      );
      expect(c.state!.injury!.matchesOut, lessThan(10));
    });

    test('離脱していなければ、何も起きない', () async {
      final c = await _started();
      c.state!.injury = null;
      await c.setRehab(RehabPlan.rush);
      expect(c.state!.rehab, RehabPlan.rush);
      expect(c.state!.injury, isNull);
    });

    test('同じものを選び直しても縮まない', () async {
      final c = await _started();
      c.state!.injury = const Injury(
        name: '肉離れ',
        severity: InjurySeverity.moderate,
        matchesOut: 10,
      );
      c.state!.rehab = RehabPlan.rush;
      await c.setRehab(RehabPlan.rush);
      expect(c.state!.injury!.matchesOut, 10);
    });
  });

  group('重傷が身体に残すぶん', () {
    test('戻し方で削られ方が変わる', () {
      final engine = MatchEngine(random: Random(9));
      const injury = Injury(
        name: '靭帯損傷',
        severity: InjurySeverity.severe,
        matchesOut: 20,
      );
      final player = Player(
        name: 'P',
        age: 24,
        position: Position.cm,
        attributes: Attributes(
          pace: 70,
          shooting: 70,
          passing: 70,
          dribbling: 70,
          defending: 70,
          physical: 70,
          goalkeeping: 30,
        ),
        potential: 90,
      );

      final (_, cautious) = engine.applySevereInjury(
        player,
        injury,
        factor: RehabPlan.cautious.damageFactor,
      );
      final (_, standard) = engine.applySevereInjury(player, injury);
      final (_, rush) = engine.applySevereInjury(
        player,
        injury,
        factor: RehabPlan.rush.damageFactor,
      );

      expect(standard, player.potential - Formulas.severeInjuryPotentialLoss);
      expect(cautious, greaterThan(standard));
      expect(rush, lessThan(standard));
    });

    test('軽い怪我は何も残さない', () {
      final engine = MatchEngine(random: Random(9));
      final player = Player(
        name: 'P',
        age: 24,
        position: Position.cm,
        attributes: Attributes(
          pace: 70,
          shooting: 70,
          passing: 70,
          dribbling: 70,
          defending: 70,
          physical: 70,
          goalkeeping: 30,
        ),
        potential: 90,
      );
      final (_, potential) = engine.applySevereInjury(
        player,
        const Injury(name: '打撲', severity: InjurySeverity.light, matchesOut: 2),
        factor: RehabPlan.rush.damageFactor,
      );
      expect(potential, player.potential);
    });
  });

  group('衰え始めは戻らない', () {
    test('戻し方で、早まる年数が違う', () {
      expect(RehabPlan.cautious.declineYears, 0);
      expect(
        RehabPlan.rush.declineYears,
        greaterThan(RehabPlan.standard.declineYears),
      );
    });

    test('能力値の目減りより、こちらを重くしてある', () {
      // 能力値は19シーズンかけて伸び直されるので、厚くしてもピークが動かない
      // （0.5 でも 0.25 でも 75.5 のまま）。効き目の中心は衰えのほうに置く。
      expect(RehabPlan.cautious.damageFactor, greaterThan(0));
      expect(RehabPlan.cautious.declineYears, 0);
    });
  });

  test('シーズンを跨いで消えた重傷も、残すものは残す', () async {
    final c = await _started();
    // 残り4試合以下の怪我は、オフの間に消える（復帰の処理を通らない）。
    c.state!.injury = const Injury(
      name: '靭帯損傷',
      severity: InjurySeverity.severe,
      matchesOut: 3,
    );
    c.state!.pendingSevere = true;
    c.state!.rehab = RehabPlan.rush;
    final potentialBefore = c.state!.player.potential;

    await c.advanceSeason(accepted: c.renewalOffer!);

    expect(c.state!.injury, isNull);
    expect(c.state!.pendingSevere, isFalse);
    expect(c.state!.player.potential, lessThan(potentialBefore));
    expect(c.state!.declineYearsLost, RehabPlan.rush.declineYears);
  });

  test('早まった衰えは保存を往復しても残り、無い保存データは 0', () async {
    final c = await _started();
    c.state!.declineYearsLost = 3;
    final back = CareerState.fromJson(c.state!.toJson());
    expect(back.declineYearsLost, 3);

    final legacy = CareerState.fromJson(
      c.state!.toJson()..remove('declineYearsLost'),
    );
    expect(legacy.declineYearsLost, 0);
  });

  test('抱えている重傷は保存を往復しても残り、無い保存データは false', () async {
    final c = await _started();
    c.state!.pendingSevere = true;
    final back = CareerState.fromJson(c.state!.toJson());
    expect(back.pendingSevere, isTrue);

    final legacy = CareerState.fromJson(
      c.state!.toJson()..remove('pendingSevere'),
    );
    expect(legacy.pendingSevere, isFalse);
  });
}
